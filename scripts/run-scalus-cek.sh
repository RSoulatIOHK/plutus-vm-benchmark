#!/bin/bash
# scalus-cek: JMH CekJVMBenchmark of images/scalus/harness, on a PlutusV3 machine at protocol
# version 11 with the mainnet cost model and a restricting budget spender with a budget too large to
# run out (check/README.md):
#   bench      per invocation flat decode + CEK evaluation (spec D3)  -> scalus-cek.csv
#   benchEval  per invocation CEK evaluation of the program decoded in setup -> scalus-cek-eval.csv
# Then the check: one evaluation per script.
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts.
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/scalus"
VM=scalus-cek
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }

echo "Scalus CEK (Scala / JVM / JMH)"

# JMH timing, heap and java binary: scripts/jmh-run.sh (images/jvm-base), shared with the other
# JMH rows. The JVM is Oracle GraalVM at /opt/jdk-25, or the java binary at the path SCALUS_JAVA.
JAVA="${SCALUS_JAVA:-}"
# shellcheck source=jmh-run.sh
source /bench/scripts/jmh-run.sh

# The benchmarks read $BENCH_DATA_DIR/<file> and the cost model next to the harness.
export BENCH_DATA_DIR="$DATA_DIR"
export SCALUS_COST_MODEL="$BENCH_DIR/mainnet-plutusv3-costmodel.json"
CP="$(cat "$BENCH_DIR/jmh-classpath.txt")"

# JVM flags (spec D16): none by default, only the heap flags (-Xmx, -Xms, -XX:+AlwaysPreTouch).
# SCALUS_JVM_FLAGS=tuned adds the flags used before 2026-10-24, for comparisons. On GraalVM 25 they
# gave no speed-up: CEK within +-2 %, JIT 2-5 % slower (results/partial-2026-10-24T1302).
case "${SCALUS_JVM_FLAGS:-none}" in
    none) JVM_FLAGS="" ;;
    tuned) JVM_FLAGS="--enable-native-access=ALL-UNNAMED --sun-misc-unsafe-memory-access=allow -XX:+UseCompactObjectHeaders -XX:+UseG1GC -XX:+UseStringDeduplication -XX:MaxInlineLevel=15 -XX:MaxInlineSize=270 -XX:ReservedCodeCacheSize=512m -XX:InitialCodeCacheSize=64m" ;;
    *) echo "ERROR: SCALUS_JVM_FLAGS=$SCALUS_JVM_FLAGS: expected none or tuned" >&2; exit 1 ;;
esac

# JMH on the classpath the image build exported from sbt (images/scalus/Dockerfile), not through sbt.
# JMH methods of the requested loops: bench (d3), benchEval (eval).
PATTERN=""
if loop d3 && loop eval; then PATTERN='pvb.scalus.CekJVMBenchmark.bench(Eval)?$'
elif loop d3; then PATTERN='pvb.scalus.CekJVMBenchmark.bench$'
elif loop eval; then PATTERN='pvb.scalus.CekJVMBenchmark.benchEval$'
fi

# One JMH launcher per script, and JMH forks a fresh JVM (-f 1) for each method: bench (d3), then
# benchEval (eval). A fork is JMH's standard isolation. Running both methods in one JVM without a
# fork (-f 0) made the d3 time of this row 3-6 % faster on some scripts, so the fork stays: a
# harness change must not move the numbers of one row only.
cd "$BENCH_DIR"
RAW="$RUN_DIR/$VM-raw.log"
: > "$RAW"
echo "scalus: $(grep -o "scalus_3-[^/]*\.jar" "$BENCH_DIR/jmh-classpath.txt")" | tee -a "$RUN_DIR/$VM-raw.log"
echo "jvm: $JAVA ($("$JAVA" -version 2>&1 | sed -n 2p)), flags ${SCALUS_JVM_FLAGS:-none}: ${JVM_FLAGS:-<none>}" \
    | tee -a "$RUN_DIR/$VM-raw.log"
if [[ -n "$PATTERN" ]]; then
    jsons=$(mktemp -d /tmp/scalus-cek-jmh.XXXXXX)
    for f in $(cd "$DATA_DIR" && ls -- *.flat | LC_ALL=C sort); do
        # $BASHPID is the pid of the subshell, which exec turns into the JMH launcher of this script.
        # shellcheck disable=SC2086
        ( echo "--- ${f%.flat}: process $BASHPID"
          jmh_command "" "$JVM_FLAGS"
          exec "${JMH_CMD[@]}" \
              -rf json -rff "$jsons/${f%.flat}.json" -p "file=$f" "$PATTERN" ) \
            2>&1 | tee -a "$RAW" || true
    done
    # One JSON array for the run, as one JMH run with every script wrote before.
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

# The warm-up of each script and loop (the "# Warmup:" lines of JMH): its length, with capped=fixed
# -> $VM-warmup-used.csv. BENCH_TRACE=1: also the score of each 1 s warm-up iteration ->
# $VM-warmup.csv
if loop d3 || loop eval; then
    python3 /bench/parsers/parse_warmup.py --used "$VM" "$RUN_DIR/$VM-raw.log" > "$RUN_DIR/$VM-warmup-used.csv" || true
    if [[ "${BENCH_TRACE:-0}" == 1 ]]; then
        python3 /bench/parsers/parse_warmup.py "$VM" "$RUN_DIR/$VM-raw.log" > "$RUN_DIR/$VM-warmup.csv" || true
    fi
fi

# Check (spec D4): one evaluation per script, same code and parameters -> $VM-check.csv
if loop check; then
    echo "=== check" | tee -a "$RUN_DIR/$VM-raw.log"
    # shellcheck disable=SC2086
    "$JAVA" $JVM_FLAGS -Xmx4g -cp "$CP" pvb.scalus.Check cek "$RUN_DIR" \
        2>&1 | tee -a "$RUN_DIR/$VM-raw.log" || true
fi
