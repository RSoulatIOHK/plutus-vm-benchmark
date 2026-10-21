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

# JMH timing: one 20 s warm-up iteration (docs/IMAGE_CONTRACT.md); BENCH_TIMING=quick shortens
# warm-up and measurement.
WARMUP=20s
MEASURE=5s
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    WARMUP=1s
    MEASURE=1s
fi
# Heap of the forked benchmark JVM (pre-touched). Lower it only on small machines.
HEAP="${SCALUS_BENCH_HEAP:-4g}"

# The benchmarks read $BENCH_DATA_DIR/<file> and the cost model next to the harness.
export BENCH_DATA_DIR="$DATA_DIR"
export SCALUS_COST_MODEL="$BENCH_DIR/mainnet-plutusv3-costmodel.json"
FILE_LIST=$(for f in "$DATA_DIR"/*.flat; do basename "$f"; done | LC_ALL=C sort | paste -sd, -)
CP="$(cat "$BENCH_DIR/jmh-classpath.txt")"

# The forked benchmark JVM is GraalVM 25 at /opt/jdk-25. Compact object headers + Graal JIT +
# Scala-friendly inlining together give ~14% geo-mean speedup over the JDK 21 default.
JVM_FLAGS="-Xss64m --enable-native-access=ALL-UNNAMED --sun-misc-unsafe-memory-access=allow -XX:+UseCompactObjectHeaders -XX:+UseG1GC -XX:+UseStringDeduplication -XX:MaxInlineLevel=15 -XX:MaxInlineSize=270 -XX:ReservedCodeCacheSize=512m -XX:InitialCodeCacheSize=64m"

# JMH on the classpath the image build exported from sbt (images/scalus/Dockerfile), not through sbt.
# The launcher JVM flags (-Xss64m -Xmx4g) are passed on to the forked JVM, as by `sbt Jmh/run`.
# JMH methods of the requested loops: bench (d3), benchEval (eval).
PATTERN=""
if loop d3 && loop eval; then PATTERN='pvb.scalus.CekJVMBenchmark.bench(Eval)?$'
elif loop d3; then PATTERN='pvb.scalus.CekJVMBenchmark.bench$'
elif loop eval; then PATTERN='pvb.scalus.CekJVMBenchmark.benchEval$'
fi
cd "$BENCH_DIR"
: > "$RUN_DIR/$VM-raw.log"
if [[ -n "$PATTERN" ]]; then
    java -Xss64m -Xmx4g -cp "$CP" org.openjdk.jmh.Main \
        -i 1 -wi 1 -w "$WARMUP" -r "$MEASURE" -f 1 -t 1 \
        -jvm /opt/jdk-25/bin/java \
        -jvmArgsAppend "$JVM_FLAGS -XX:+AlwaysPreTouch -Xms$HEAP" \
        -rff "$RUN_DIR/$VM-jmh.csv" -p "file=$FILE_LIST" "$PATTERN" \
        2>&1 | tee "$RUN_DIR/$VM-raw.log" || true
fi

# Parse JMH CSV into the D3 and the eval-only CSV; fill in -1 for any scripts that were given but
# produced no result.
if loop d3; then
    python3 /bench/parsers/parse_jmh.py "$RUN_DIR/$VM-jmh.csv" "$VM" > "$RUN_DIR/$VM.csv" || true
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/$VM.csv" "$DATA_DIR" "$VM" "$RUN_DIR/$VM-raw.log"
fi
if loop eval; then
    python3 /bench/parsers/parse_jmh.py "$RUN_DIR/$VM-jmh.csv" "$VM" --eval > "$RUN_DIR/$VM-eval.csv" || true
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/$VM-eval.csv" "$DATA_DIR" "$VM" "$RUN_DIR/$VM-raw.log"
fi

# Check (spec D4): one evaluation per script, same code and parameters -> $VM-check.csv
if loop check; then
    echo "=== check" | tee -a "$RUN_DIR/$VM-raw.log"
    # shellcheck disable=SC2086
    /opt/jdk-25/bin/java $JVM_FLAGS -Xmx4g -cp "$CP" pvb.scalus.Check cek "$RUN_DIR" \
        2>&1 | tee -a "$RUN_DIR/$VM-raw.log" || true
fi
