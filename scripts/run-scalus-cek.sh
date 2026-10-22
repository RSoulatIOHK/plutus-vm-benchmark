#!/bin/bash
# scalus-cek: JMH CekJVMBenchmark of images/scalus/harness, on a PlutusV3 machine at protocol
# version 11 with the mainnet cost model and a counting budget spender (check/README.md):
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

# JMH timing: one 20 s warm-up iteration (docs/IMAGE_CONTRACT.md), then 3 measurement iterations of
# 5 s each, so the CSV has a standard deviation over the iteration means. BENCH_TIMING=quick
# shortens warm-up and measurement to one 1 s iteration each.
WARMUP=20s
MEASURE=5s
ITERATIONS=3
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    WARMUP=1s
    MEASURE=1s
    ITERATIONS=1
fi
# Heap of the benchmark JVM (pre-touched). Lower it only on small machines.
HEAP="${SCALUS_BENCH_HEAP:-4g}"

# The benchmarks read $BENCH_DATA_DIR/<file> and the cost model next to the harness.
export BENCH_DATA_DIR="$DATA_DIR"
export SCALUS_COST_MODEL="$BENCH_DIR/mainnet-plutusv3-costmodel.json"
CP="$(cat "$BENCH_DIR/jmh-classpath.txt")"

# The benchmark JVM is GraalVM 25 at /opt/jdk-25. Compact object headers + Graal JIT +
# Scala-friendly inlining together give ~14% geo-mean speedup over the JDK 21 default.
JVM_FLAGS="-Xss64m --enable-native-access=ALL-UNNAMED --sun-misc-unsafe-memory-access=allow -XX:+UseCompactObjectHeaders -XX:+UseG1GC -XX:+UseStringDeduplication -XX:MaxInlineLevel=15 -XX:MaxInlineSize=270 -XX:ReservedCodeCacheSize=512m -XX:InitialCodeCacheSize=64m"

# JMH on the classpath the image build exported from sbt (images/scalus/Dockerfile), not through sbt.
# JMH methods of the requested loops: bench (d3), benchEval (eval).
PATTERN=""
if loop d3 && loop eval; then PATTERN='pvb.scalus.CekJVMBenchmark.bench(Eval)?$'
elif loop d3; then PATTERN='pvb.scalus.CekJVMBenchmark.bench$'
elif loop eval; then PATTERN='pvb.scalus.CekJVMBenchmark.benchEval$'
fi

# One JVM per script (spec D14) that runs both methods, bench (d3) first, then benchEval (eval),
# each with its own warm-up and measurement iterations. JMH forks one JVM per method and parameter
# value and cannot share a fork between two methods, so JMH runs without a fork (-f 0) in a
# launcher JVM per script. That launcher is the JVM a fork was before: GraalVM 25 with the flags
# JMH gives a fork. JMH 1.37 starts a fork with the launcher's -Xss64m -Xmx4g, then -jvmArgsAppend,
# then -XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions -DcompilerBlackholesEnabled=true
# (compiler blackholes) and -XX:CompileCommandFile with its compiler hints. A run without a fork
# does not add these itself, so the launcher gets them here; the log line "# Blackhole mode:
# compiler" shows that they work. JMH_HINTS is the hints file of a fork of this harness, as JMH 1.37
# writes it (its default hints plus one inline line per @Benchmark and @Setup method).
JMH_HINTS=/tmp/jmh-compilecommand
cat > "$JMH_HINTS" <<'HINTS'
quiet
inline,org/openjdk/jmh/infra/Blackhole.consume
dontinline,org/openjdk/jmh/infra/Blackhole.consumeCPU
blackhole,org/openjdk/jmh/infra/Blackhole.consumeCompiler
dontinline,*.*_all_jmhStub
dontinline,*.*_avgt_jmhStub
dontinline,*.*_sample_jmhStub
dontinline,*.*_ss_jmhStub
dontinline,*.*_thrpt_jmhStub
inline,pvb/scalus/CekJVMBenchmark.bench
inline,pvb/scalus/CekJVMBenchmark.benchEval
inline,pvb/scalus/CekJVMBenchmark.setup
inline,pvb/scalus/JITBenchmark.benchJIT
inline,pvb/scalus/JITBenchmark.setup
HINTS
FORK_FLAGS="-XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions -DcompilerBlackholesEnabled=true -XX:CompileCommandFile=$JMH_HINTS"

cd "$BENCH_DIR"
RAW="$RUN_DIR/$VM-raw.log"
: > "$RAW"
if [[ -n "$PATTERN" ]]; then
    jsons=$(mktemp -d /tmp/scalus-cek-jmh.XXXXXX)
    for f in $(cd "$DATA_DIR" && ls -- *.flat | LC_ALL=C sort); do
        # $BASHPID is the pid of the subshell, which exec turns into the benchmark JVM.
        # shellcheck disable=SC2086
        ( echo "--- ${f%.flat}: process $BASHPID"
          exec /opt/jdk-25/bin/java -Xss64m -Xmx4g $JVM_FLAGS -XX:+AlwaysPreTouch -Xms$HEAP $FORK_FLAGS \
              -cp "$CP" org.openjdk.jmh.Main \
              -i "$ITERATIONS" -wi 1 -w "$WARMUP" -r "$MEASURE" -f 0 -t 1 \
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

# Check (spec D4): one evaluation per script, same code and parameters -> $VM-check.csv
if loop check; then
    echo "=== check" | tee -a "$RUN_DIR/$VM-raw.log"
    # shellcheck disable=SC2086
    /opt/jdk-25/bin/java $JVM_FLAGS -Xmx4g -cp "$CP" pvb.scalus.Check cek "$RUN_DIR" \
        2>&1 | tee -a "$RUN_DIR/$VM-raw.log" || true
fi
