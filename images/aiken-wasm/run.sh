#!/bin/bash
# Runs the aiken-wasm timing and check per docs/IMAGE_CONTRACT.md.
set -euo pipefail

VM=aiken-wasm
RESULTS=/results
DATA_DIR=/bench/data/plutus_use_cases
export DATA_DIR

mkdir -p "$RESULTS"
RAW="$RESULTS/$VM-raw.log"
cd /bench/aiken-wasm

if ! ls "$DATA_DIR"/*.flat >/dev/null 2>&1; then
    echo "ERROR: no .flat files in $DATA_DIR" >&2
    exit 1
fi

{
    echo "aiken-wasm (uplc crate -> WASM / Node $(node --version) / vitest bench)"
    echo "uplc crate: $(node --input-type=module -e 'import { buildInfo } from "./common.mjs"; console.log(buildInfo())')"
    echo "BENCH_QUICK=${BENCH_QUICK:-0}"
} | tee "$RAW"

# Correctness: one evaluation per script.
node check.mjs > "$RESULTS/$VM-check.csv" 2> >(tee -a "$RAW" >&2)

# Timing. A crash must not kill the run: missing scripts become -1 rows below.
npx vitest bench --run 2>&1 | tee -a "$RAW" || true

python3 /bench/parsers/parse_vitest.py "$VM" "$RAW" > "$RESULTS/$VM.csv"

# In quick mode only 5 scripts run; do not pad the other 84 with -1 rows.
if [[ "${BENCH_QUICK:-0}" != "1" ]]; then
    python3 /bench/parsers/fill_failures.py "$RESULTS/$VM.csv" "$DATA_DIR" "$VM" "$RAW"
fi
