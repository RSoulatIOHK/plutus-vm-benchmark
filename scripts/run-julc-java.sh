#!/bin/bash
# julc-java: JMH pvb.CekJavaBenchmark (images/julc-java/pvb/), PlutusV3 at protocol version 11 with
# the mainnet cost model, counting mode:
#   bench      per invocation flat decode + evaluation (spec D3)          -> julc-java.csv
#   benchEval  per invocation evaluation of the program decoded in setup  -> julc-java-eval.csv
# Then the check: one evaluation per script.
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts.
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }
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
    /opt/jdk-25/bin/java -cp julc-benchmark-jmh.jar pvb.Check "$DATA_DIR" "$RUN_DIR/julc-java-check.csv" \
        2>&1 | tee "$RUN_DIR/julc-java-check.log"
    echo "Wrote $RUN_DIR/julc-java-check.csv"
}

# JMH timing: one 20 s warm-up iteration (docs/IMAGE_CONTRACT.md); BENCH_TIMING=quick shortens
# warm-up and measurement.
WARMUP=20s
MEASURE=5s
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    WARMUP=1s
    MEASURE=1s
fi

# Build file list for JMH -p parameter
FILE_LIST=$(for f in data/*.flat; do basename "$f"; done | LC_ALL=C sort | paste -sd, -)

# JMH methods of the requested loops: bench (d3), benchEval (eval).
PATTERN=""
if loop d3 && loop eval; then PATTERN='^pvb\.CekJavaBenchmark\.bench(Eval)?$'
elif loop d3; then PATTERN='^pvb\.CekJavaBenchmark\.bench$'
elif loop eval; then PATTERN='^pvb\.CekJavaBenchmark\.benchEval$'
fi

if [[ -n "$PATTERN" ]]; then
    # Run JMH benchmark with our pvb.CekJavaBenchmark (not the upstream class of the same name), CSV output
    /opt/jdk-25/bin/java \
        -jar julc-benchmark-jmh.jar \
        -i 1 -wi 1 -w "$WARMUP" -r "$MEASURE" -f 1 -t 1 \
        -rff "$RUN_DIR/julc-java-jmh.csv" \
        -p "file=$FILE_LIST" \
        "$PATTERN" \
        2>&1 | tee "$RUN_DIR/julc-java-raw.log" || true
fi

# Parse JMH CSV into the D3 and the eval-only CSV; fill in -1 for any scripts that were given but
# produced no result.
if loop d3; then
    python3 /bench/parsers/parse_jmh.py "$RUN_DIR/julc-java-jmh.csv" julc-java > "$RUN_DIR/julc-java.csv" || true
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/julc-java.csv" "$DATA_DIR" julc-java "$RUN_DIR/julc-java-raw.log"
fi
if loop eval; then
    python3 /bench/parsers/parse_jmh.py "$RUN_DIR/julc-java-jmh.csv" julc-java --eval > "$RUN_DIR/julc-java-eval.csv" || true
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/julc-java-eval.csv" "$DATA_DIR" julc-java "$RUN_DIR/julc-java-raw.log"
fi

if loop check; then run_check || echo "WARNING: julc-java check failed" >&2; fi
