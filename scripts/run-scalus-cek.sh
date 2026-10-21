#!/bin/bash
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/scalus"

echo "Scalus CEK (Scala / JVM / JMH)"

cd "$BENCH_DIR"

# JMH timing; BENCH_QUICK=1 shortens warm-up and measurement.
WARMUP=5s
MEASURE=5s
if [[ "${BENCH_QUICK:-0}" == 1 ]]; then
    WARMUP=1s
    MEASURE=1s
fi
# Heap of the forked benchmark JVM (pre-touched). Lower it only on small machines.
HEAP="${SCALUS_BENCH_HEAP:-4g}"

# Copy canonical flat files into Scalus resource dir
rm -rf bench/src/main/resources/data
mkdir -p bench/src/main/resources/data
cp "$DATA_DIR"/*.flat bench/src/main/resources/data/

# Build file list for JMH -p parameter
FILE_LIST=$(ls bench/src/main/resources/data/*.flat | xargs -I{} basename {} | paste -sd, -)

# Run JMH directly on the classpath that the image build exported from sbt
# (bench/Jmh/fullClasspath, images/scalus/Dockerfile). Running through sbt would recompile
# every module first: image layers keep file times in whole seconds, so zinc sees every class
# file as changed. The launcher JVM gets the bench project's Jmh / javaOptions (-Xss64m -Xmx4g),
# which JMH passes on to the forked benchmark JVM, as `sbt bench/Jmh/run` did.
#
# The forked benchmark JVM is GraalVM 25 at /opt/jdk-25. The -jvmArgsAppend flags target it.
# Compact object headers + Graal JIT + Scala-friendly inlining together give ~14% geo-mean
# speedup over the JDK 21 default.
# Benchmarks read src/main/resources/data/<file> relative to the bench project dir.
cd "$BENCH_DIR/bench"
java -Xss64m -Xmx4g -cp "$(cat "$BENCH_DIR/jmh-classpath.txt")" org.openjdk.jmh.Main \
    -i 1 -wi 1 -w "$WARMUP" -r "$MEASURE" -f 1 -t 1 \
    -jvm /opt/jdk-25/bin/java \
    -jvmArgsAppend "--enable-native-access=ALL-UNNAMED --sun-misc-unsafe-memory-access=allow -XX:+UseCompactObjectHeaders -XX:+UseG1GC -XX:+UseStringDeduplication -XX:MaxInlineLevel=15 -XX:MaxInlineSize=270 -XX:ReservedCodeCacheSize=512m -XX:InitialCodeCacheSize=64m -XX:+AlwaysPreTouch -Xms$HEAP" \
    -rff "$RUN_DIR/scalus-cek-jmh.csv" -p "file=$FILE_LIST" '.*CekJVMBenchmark' \
    2>&1 | tee "$RUN_DIR/scalus-cek-raw.log" || true

# Parse JMH CSV into unified CSV
python3 /bench/parsers/parse_jmh.py "$RUN_DIR/scalus-cek-jmh.csv" scalus-cek > "$RUN_DIR/scalus-cek.csv" || true

# Fill in -1 for any scripts that were given but produced no result
python3 /bench/parsers/fill_failures.py "$RUN_DIR/scalus-cek.csv" "$DATA_DIR" scalus-cek "$RUN_DIR/scalus-cek-raw.log"

# ---------------------------------------------------------------------------
# CHECK HOOK (spec D4): the correctness check runs here, one evaluation per script with
# the same parameters as the timed loop, and writes "$RUN_DIR/scalus-cek-check.csv"
# (vm,script,status,cpu,mem). Implemented by check/, not yet wired in.
# ---------------------------------------------------------------------------
