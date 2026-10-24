#!/bin/bash
# scalus-jit: JMH JITBenchmark of images/scalus/harness. Per invocation: evaluation of the script
# compiled once in setup, with the machine parameters of PlutusV3 at protocol version 11 and the
# mainnet cost model and a counting budget spender (spec D3, check/README.md). This loop is
# eval-only already, so scalus-jit.csv and scalus-jit-eval.csv have the same rows. Then the check and
# the compile column (spec D5): per script, the median time of SCALUS_JIT_COMPILE_RUNS (default 3)
# flat decodes + JIT compiles, and one evaluation of the compiled script.
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The JIT loop runs when d3 or eval is requested; it writes scalus-jit.csv for d3 and
# scalus-jit-eval.csv for eval. The check writes scalus-jit-check.csv and scalus-jit-compile.csv.
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/scalus"
VM=scalus-jit
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }

echo "Scalus JIT (Scala / JVM / JMH)"

# JMH timing (METHODOLOGY.md, D13): one 30 s warm-up iteration, then 3 measurement iterations of
# 5 s each, so the CSV has a standard deviation over the iteration means. The JS rows use an
# adaptive warm-up with a 30 s cap; the JMH rows keep JMH's own warm-up iterations at that cap.
# BENCH_TIMING=quick shortens warm-up and measurement to one 1 s iteration each.
WARMUP=30s
WARMUP_ITERATIONS=1
MEASURE=5s
ITERATIONS=3
# BENCH_TRACE=1: the same 30 s of warm-up as 30 iterations of 1 s (-wi 30 -w 1s), so the log has
# a score per second; parse_warmup.py writes them to $VM-warmup.csv. The measurement settings stay
# the same (the measured time can differ, METHODOLOGY.md).
if [[ "${BENCH_TRACE:-0}" == 1 ]]; then
    WARMUP=1s
    WARMUP_ITERATIONS=30
fi
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    WARMUP=1s
    WARMUP_ITERATIONS=1
    MEASURE=1s
    ITERATIONS=1
    # The check compiles every selected script: one compile each instead of the median of 3.
    export SCALUS_JIT_COMPILE_RUNS="${SCALUS_JIT_COMPILE_RUNS:-1}"
fi
# Heap of the forked benchmark JVM (pre-touched). Lower it only on small machines.
HEAP="${SCALUS_BENCH_HEAP:-4g}"

# The benchmarks read $BENCH_DATA_DIR/<file> and the cost model next to the harness.
export BENCH_DATA_DIR="$DATA_DIR"
export SCALUS_COST_MODEL="$BENCH_DIR/mainnet-plutusv3-costmodel.json"
FILE_LIST=$(for f in "$DATA_DIR"/*.flat; do basename "$f"; done | LC_ALL=C sort | paste -sd, -)
CP="$(cat "$BENCH_DIR/jmh-classpath.txt")"

# The forked benchmark JVM. SCALUS_JAVA: 25.0.2 or 25.4.4 (the Oracle GraalVM releases in the
# image, images/scalus/Dockerfile), or the path of a java binary; default /opt/jdk-25 (25.0.2).
case "${SCALUS_JAVA:-}" in
    "") JAVA=/opt/jdk-25/bin/java ;;
    /*) JAVA="$SCALUS_JAVA" ;;
    *) JAVA="/opt/graalvm-$SCALUS_JAVA/bin/java" ;;
esac
[[ -x "$JAVA" ]] || { echo "ERROR: SCALUS_JAVA=$SCALUS_JAVA: $JAVA is not there" >&2; exit 1; }
# SCALUS_JVM_FLAGS: default = the flags below (compact object headers + Scala-friendly inlining gave
# ~14% geo-mean speedup on GraalVM 25 over the JDK 21 default); none = no extra flags, only the heap
# flags (-Xmx, -Xms, -XX:+AlwaysPreTouch).
# -Xss64m is in every case: the JIT's call-depth limit (25 000) assumes a 64 MB stack.
JIT_STACK="-Xss64m"
case "${SCALUS_JVM_FLAGS:-default}" in
    default) JVM_FLAGS="--enable-native-access=ALL-UNNAMED --sun-misc-unsafe-memory-access=allow -XX:+UseCompactObjectHeaders -XX:+UseG1GC -XX:+UseStringDeduplication -XX:MaxInlineLevel=15 -XX:MaxInlineSize=270 -XX:ReservedCodeCacheSize=512m -XX:InitialCodeCacheSize=64m" ;;
    none) JVM_FLAGS="" ;;
    *) echo "ERROR: SCALUS_JVM_FLAGS=$SCALUS_JVM_FLAGS: expected default or none" >&2; exit 1 ;;
esac
JVM_FLAGS="$JIT_STACK${JVM_FLAGS:+ $JVM_FLAGS}"

# JMH on the classpath the image build exported from sbt (images/scalus/Dockerfile), not through sbt.
# The launcher JVM flags (-Xss64m -Xmx4g) are passed on to the forked JVM, as by `sbt Jmh/run`.
cd "$BENCH_DIR"
: > "$RUN_DIR/$VM-raw.log"
echo "jvm: $JAVA ($("$JAVA" -version 2>&1 | sed -n 2p)), flags ${SCALUS_JVM_FLAGS:-default}: ${JVM_FLAGS:-<none>}" \
    | tee -a "$RUN_DIR/$VM-raw.log"
if loop d3 || loop eval; then
    java -Xss64m -Xmx4g -cp "$CP" org.openjdk.jmh.Main \
        -i "$ITERATIONS" -wi "$WARMUP_ITERATIONS" -w "$WARMUP" -r "$MEASURE" -f 1 -t 1 \
        -jvm "$JAVA" \
        -jvmArgsAppend "$JVM_FLAGS -XX:+AlwaysPreTouch -Xms$HEAP" \
        -rf json -rff "$RUN_DIR/$VM-jmh.json" -p "file=$FILE_LIST" 'pvb.scalus.JITBenchmark' \
        2>&1 | tee -a "$RUN_DIR/$VM-raw.log" || true

    # Parse the JMH JSON; fill in -1 for any scripts that were given but produced no result.
    TIMING_CSV="$RUN_DIR/$VM-jit-timing.tmp"
    python3 /bench/parsers/parse_jmh.py "$RUN_DIR/$VM-jmh.json" "$VM" > "$TIMING_CSV" || true
    python3 /bench/parsers/fill_failures.py "$TIMING_CSV" "$DATA_DIR" "$VM" "$RUN_DIR/$VM-raw.log"

    # The JIT loop evaluates the precompiled script: it is the D3 and the eval-only timing.
    if loop d3; then cp "$TIMING_CSV" "$RUN_DIR/$VM.csv"; fi
    if loop eval; then cp "$TIMING_CSV" "$RUN_DIR/$VM-eval.csv"; fi
    rm -f "$TIMING_CSV"
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

# Check (spec D4): one evaluation per script, same code and parameters -> $VM-check.csv,
# and the compile time (decode + compile) -> $VM-compile.csv
if loop check; then
    echo "=== check" | tee -a "$RUN_DIR/$VM-raw.log"
    # shellcheck disable=SC2086
    "$JAVA" $JVM_FLAGS -Xmx4g -cp "$CP" pvb.scalus.Check jit "$RUN_DIR" \
        2>&1 | tee -a "$RUN_DIR/$VM-raw.log" || true
fi
