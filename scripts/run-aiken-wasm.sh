#!/bin/bash
# aiken-wasm: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-aiken-wasm.sh <results-dir>
#
# Times the scripts in $BENCH_DATA_DIR (5 with BENCH_QUICK=1). The check covers every script of
# the corpus, also with BENCH_QUICK=1, so the gate always sees all of them.
set -uo pipefail

VM=aiken-wasm
RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
CHECK_DATA_DIR=/bench/data/plutus_use_cases
RAW="$RUN_DIR/$VM-raw.log"

cd /bench/aiken-wasm

{
    echo "aiken-wasm (uplc crate -> WASM / Node $(node --version) / vitest bench)"
    echo "uplc crate: $(node --input-type=module -e 'import { buildInfo } from "./common.mjs"; console.log(buildInfo())')"
    echo "BENCH_QUICK=${BENCH_QUICK:-0}"
} | tee "$RAW"

# Correctness: one evaluation per script of the whole corpus.
BENCH_QUICK=0 DATA_DIR="$CHECK_DATA_DIR" node check.mjs > "$RUN_DIR/$VM-check.csv" 2> >(tee -a "$RAW" >&2)

# Timing. A crash must not kill the run: missing scripts become -1 rows below.
DATA_DIR="$DATA_DIR" npx vitest bench --run 2>&1 | tee -a "$RAW" || true

python3 /bench/parsers/parse_vitest.py "$VM" "$RAW" > "$RUN_DIR/$VM.csv"
python3 /bench/parsers/fill_failures.py "$RUN_DIR/$VM.csv" "$DATA_DIR" "$VM" "$RAW"
