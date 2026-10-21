#!/bin/bash
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/julc"

echo "Julc Java VM CEK (Java / GraalVM / JMH)"

# Copy canonical flat files into data/ (benchmark loads from filesystem first)
rm -rf "$BENCH_DIR/data"
mkdir -p "$BENCH_DIR/data"
cp "$DATA_DIR"/*.flat "$BENCH_DIR/data/"

cd "$BENCH_DIR"

# JMH timing; BENCH_QUICK=1 shortens warm-up and measurement.
WARMUP=5s
MEASURE=5s
if [[ "${BENCH_QUICK:-0}" == 1 ]]; then
    WARMUP=1s
    MEASURE=1s
fi

# Build file list for JMH -p parameter
FILE_LIST=$(ls data/*.flat | xargs -I{} basename {} | paste -sd, -)

# Run JMH benchmark with CekJavaBenchmark, CSV output
/opt/jdk-25/bin/java \
    -jar julc-benchmark-jmh.jar \
    -i 1 -wi 1 -w "$WARMUP" -r "$MEASURE" -f 1 -t 1 \
    -rff "$RUN_DIR/julc-java-jmh.csv" \
    -p "file=$FILE_LIST" \
    ".*CekJavaBenchmark" \
    2>&1 | tee "$RUN_DIR/julc-java-raw.log" || true

# Parse JMH CSV into unified CSV
python3 /bench/parsers/parse_jmh.py "$RUN_DIR/julc-java-jmh.csv" julc-java > "$RUN_DIR/julc-java.csv" || true

# Fill in -1 for any scripts that were given but produced no result
python3 /bench/parsers/fill_failures.py "$RUN_DIR/julc-java.csv" "$DATA_DIR" julc-java "$RUN_DIR/julc-java-raw.log"

# ---------------------------------------------------------------------------
# CHECK HOOK (spec D4): the correctness check runs here, one evaluation per script with
# the same parameters as the timed loop, and writes "$RUN_DIR/julc-java-check.csv"
# (vm,script,status,cpu,mem). Implemented by check/, not yet wired in.
# ---------------------------------------------------------------------------
