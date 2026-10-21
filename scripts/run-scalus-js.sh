#!/bin/bash
# scalus-js: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-scalus-js.sh <results-dir>
#
# pvb-loops: d3 check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts. No eval loop: the scalus npm API cannot evaluate
# an already decoded program (images/scalus-js/README.md, "No eval-only timing").
set -uo pipefail

VM=scalus-js
RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
RAW="$RUN_DIR/$VM-raw.log"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }

cd /bench/scalus-js || exit 1
echo "scalus-js (Scala.js / Node.js $(node --version) / V8), scalus $(node -p 'require("./node_modules/scalus/package.json").version')" \
    | tee "$RAW"

# Correctness: one evaluation per script.
if loop check; then
    DATA_DIR="$DATA_DIR" node check.mjs > "$RUN_DIR/$VM-check.csv" 2> >(tee -a "$RAW" >&2)
fi

# Timing (D3). A crash must not kill the run: missing scripts become -1 rows below.
if loop d3; then
    DATA_DIR="$DATA_DIR" npx vitest bench --run 2>&1 | tee -a "$RAW" || true
    python3 /bench/parsers/parse_vitest.py "$VM" "$RAW" > "$RUN_DIR/$VM.csv"
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/$VM.csv" "$DATA_DIR" "$VM" "$RAW"
fi
