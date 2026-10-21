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

# Our harness (images/julc-java/pvb/): mainnet PlutusV3 cost model at protocol version 11,
# counting mode, flat decode + eval per call, result checked.
export PVB_COSTMODEL=/tmp/julc-costmodel.txt
python3 -c "
import json, sys
values = json.load(open('/bench/mainnet-plutusv3-costmodel.json'))['PlutusV3']
open(sys.argv[1], 'w').write('\\n'.join(map(str, values)) + '\\n')
" "$PVB_COSTMODEL"

run_check() {
    # Spec D4: one evaluation per script with the timed loop's parameters.
    /opt/jdk-25/bin/java -cp julc-benchmark-jmh.jar pvb.Check data "$RUN_DIR/julc-java-check.csv" \
        2>&1 | tee "$RUN_DIR/julc-java-check.log"
    echo "Wrote $RUN_DIR/julc-java-check.csv"
}

if [[ "${PVB_CHECK_ONLY:-0}" == 1 ]]; then
    run_check
    exit 0
fi

# JMH timing; BENCH_QUICK=1 shortens warm-up and measurement.
WARMUP=5s
MEASURE=5s
if [[ "${BENCH_QUICK:-0}" == 1 ]]; then
    WARMUP=1s
    MEASURE=1s
fi

# Build file list for JMH -p parameter
FILE_LIST=$(ls data/*.flat | xargs -I{} basename {} | paste -sd, -)

# Run JMH benchmark with our pvb.CekJavaBenchmark (not the upstream class of the same name), CSV output
/opt/jdk-25/bin/java \
    -jar julc-benchmark-jmh.jar \
    -i 1 -wi 1 -w "$WARMUP" -r "$MEASURE" -f 1 -t 1 \
    -rff "$RUN_DIR/julc-java-jmh.csv" \
    -p "file=$FILE_LIST" \
    '^pvb\.CekJavaBenchmark\.' \
    2>&1 | tee "$RUN_DIR/julc-java-raw.log" || true

# Parse JMH CSV into unified CSV
python3 /bench/parsers/parse_jmh.py "$RUN_DIR/julc-java-jmh.csv" julc-java > "$RUN_DIR/julc-java.csv" || true

# Fill in -1 for any scripts that were given but produced no result
python3 /bench/parsers/fill_failures.py "$RUN_DIR/julc-java.csv" "$DATA_DIR" julc-java "$RUN_DIR/julc-java-raw.log"

run_check || echo "WARNING: julc-java check failed" >&2
