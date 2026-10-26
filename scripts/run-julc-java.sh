#!/bin/bash
# julc-java: JMH CekJavaBenchmark of images/julc-java/harness, on the Julc Java CEK machine with
# PlutusV3 at protocol version 11, the mainnet cost model and a restricting budget too large to run
# out (check/README.md):
#   bench      per invocation flat decode + CEK evaluation (spec D3)  -> julc-java.csv
#   benchEval  per invocation CEK evaluation of the program decoded in setup -> julc-java-eval.csv
# Then the check: one evaluation per script.
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts.
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/julc"
VM=julc-java
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }

echo "Julc Java CEK (Java / JVM / JMH)"

# JMH timing as the Scalus rows (scripts/run-scalus-cek.sh, METHODOLOGY.md, D13): one 30 s warm-up
# iteration, then 3 measurement iterations of 5 s each. BENCH_TRACE=1: the 30 s of warm-up as
# 30 iterations of 1 s. BENCH_TIMING=quick: one 1 s iteration each.
WARMUP=30s
WARMUP_ITERATIONS=1
MEASURE=5s
ITERATIONS=3
if [[ "${BENCH_TRACE:-0}" == 1 ]]; then
    WARMUP=1s
    WARMUP_ITERATIONS=30
fi
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    WARMUP=1s
    WARMUP_ITERATIONS=1
    MEASURE=1s
    ITERATIONS=1
fi
# Heap of the benchmark JVM (pre-touched). Lower it only on small machines.
HEAP="${JULC_BENCH_HEAP:-4g}"

# The benchmarks read $BENCH_DATA_DIR/<file> and the cost model next to the harness.
export BENCH_DATA_DIR="$DATA_DIR"
export JULC_COST_MODEL="$BENCH_DIR/mainnet-plutusv3-costmodel.json"
CP="$(cat "$BENCH_DIR/jmh-classpath.txt")"

# Oracle GraalVM at /opt/jdk-25 (images/julc-java/Dockerfile), the JVM of the Scalus rows. Julc
# documents no JVM settings, so no tuning flags (spec D16): only the heap flags.
JAVA=/opt/jdk-25/bin/java

# JMH methods of the requested loops: bench (d3), benchEval (eval).
PATTERN=""
if loop d3 && loop eval; then PATTERN='pvb.julc.CekJavaBenchmark.bench(Eval)?$'
elif loop d3; then PATTERN='pvb.julc.CekJavaBenchmark.bench$'
elif loop eval; then PATTERN='pvb.julc.CekJavaBenchmark.benchEval$'
fi

# One JMH launcher per script (spec D14), and JMH forks a fresh JVM (-f 1) for each method, as the
# Scalus rows.
cd "$BENCH_DIR"
RAW="$RUN_DIR/$VM-raw.log"
: > "$RAW"
echo "julc: $(grep -o "julc-vm-java-[^/]*\.jar" "$BENCH_DIR/jmh-classpath.txt")" | tee -a "$RAW"
echo "jvm: $JAVA ($("$JAVA" -version 2>&1 | sed -n 2p)), flags: <none>" | tee -a "$RAW"
if [[ -n "$PATTERN" ]]; then
    jsons=$(mktemp -d /tmp/julc-java-jmh.XXXXXX)
    for f in $(cd "$DATA_DIR" && ls -- *.flat | LC_ALL=C sort); do
        # $BASHPID is the pid of the subshell, which exec turns into the JMH launcher of this script.
        ( echo "--- ${f%.flat}: process $BASHPID"
          exec "$JAVA" -Xmx4g -cp "$CP" org.openjdk.jmh.Main \
              -i "$ITERATIONS" -wi "$WARMUP_ITERATIONS" -w "$WARMUP" -r "$MEASURE" -f 1 -t 1 \
              -jvm "$JAVA" -jvmArgsAppend "-XX:+AlwaysPreTouch -Xms$HEAP" \
              -rf json -rff "$jsons/${f%.flat}.json" -p "file=$f" "$PATTERN" ) \
            2>&1 | tee -a "$RAW" || true
    done
    # One JSON array for the run.
    python3 - "$RUN_DIR/$VM-jmh.json" "$jsons"/*.json <<'PY' || true
import json, sys
out, parts = sys.argv[1], sys.argv[2:]
results = []
for p in parts:
    try:
        results += json.load(open(p))
    except (OSError, ValueError):
        pass  # a JVM that died wrote no or half a file: its scripts get -1 rows
json.dump(results, open(out, "w"), indent=2)
PY
    rm -rf "$jsons"
fi

# Parse the JMH JSON into the D3 and the eval-only CSV; fill in -1 for any scripts that were given
# but produced no result.
if loop d3; then
    python3 /bench/parsers/parse_jmh.py "$RUN_DIR/$VM-jmh.json" "$VM" > "$RUN_DIR/$VM.csv" || true
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/$VM.csv" "$DATA_DIR" "$VM" "$RAW"
fi
if loop eval; then
    python3 /bench/parsers/parse_jmh.py "$RUN_DIR/$VM-jmh.json" "$VM" --eval > "$RUN_DIR/$VM-eval.csv" || true
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/$VM-eval.csv" "$DATA_DIR" "$VM" "$RAW"
fi

# The warm-up of each script and loop -> $VM-warmup-used.csv; BENCH_TRACE=1: also the score of
# each 1 s warm-up iteration -> $VM-warmup.csv
if loop d3 || loop eval; then
    python3 /bench/parsers/parse_warmup.py --used "$VM" "$RAW" > "$RUN_DIR/$VM-warmup-used.csv" || true
    if [[ "${BENCH_TRACE:-0}" == 1 ]]; then
        python3 /bench/parsers/parse_warmup.py "$VM" "$RAW" > "$RUN_DIR/$VM-warmup.csv" || true
    fi
fi

# Check (spec D4): one evaluation per script, same code and parameters -> $VM-check.csv
if loop check; then
    echo "=== check" | tee -a "$RAW"
    "$JAVA" -Xmx4g -cp "$CP" pvb.julc.Check "$RUN_DIR" 2>&1 | tee -a "$RAW" || true
fi
