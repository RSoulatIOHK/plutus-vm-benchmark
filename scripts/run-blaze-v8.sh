#!/bin/bash
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/blaze-plutus"

echo "blaze-v8 (TypeScript / Node.js / V8)"

# Symlink canonical flat files into expected location
rm -rf "$BENCH_DIR/packages/blaze-plutus/bench/plutus_use_cases"
ln -sf "$DATA_DIR" "$BENCH_DIR/packages/blaze-plutus/bench/plutus_use_cases"

cd "$BENCH_DIR/packages/blaze-plutus"

# Run vitest bench via Node.js (V8 engine)
npx vitest bench --run \
    2>&1 | tee "$RUN_DIR/blaze-v8-raw.log" || true

# Parse into unified CSV
python3 /bench/parsers/parse_vitest.py blaze-v8 "$RUN_DIR/blaze-v8-raw.log" > "$RUN_DIR/blaze-v8.csv" || true

# Fill in -1 for any scripts that were given but produced no result
python3 /bench/parsers/fill_failures.py "$RUN_DIR/blaze-v8.csv" "$DATA_DIR" blaze-v8 "$RUN_DIR/blaze-v8-raw.log"

# ---------------------------------------------------------------------------
# CHECK HOOK (spec D4): the correctness check runs here, one evaluation per script with
# the same parameters as the timed loop, and writes "$RUN_DIR/blaze-v8-check.csv"
# (vm,script,status,cpu,mem). Implemented by check/, not yet wired in.
# ---------------------------------------------------------------------------
