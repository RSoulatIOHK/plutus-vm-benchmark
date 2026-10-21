#!/bin/bash
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/blaze-plutus"

echo "blaze-v8 (TypeScript / Node.js / V8)"

# Our harness (images/blaze/pvb.bench.ts, pvb-check.test.ts): flat decode + eval per iteration,
# counting mode, the mainnet PlutusV3 cost model mapped into blaze's cost table (pvb-costs.ts).
export PVB_DATA_DIR="$DATA_DIR"
export PVB_COSTMODEL_JSON=/bench/mainnet-plutusv3-costmodel.json
export PVB_PARAM_NAMES=/bench/plutusv3-param-names.txt
export BENCH_QUICK="${BENCH_QUICK:-0}"

cd "$BENCH_DIR/packages/blaze-plutus"

run_check() {
    # Spec D4: one evaluation per script with the timed loop's parameters, on the same engine.
    PVB_VM=blaze-v8 PVB_CHECK_OUT="$RUN_DIR/blaze-v8-check.csv" npx vitest run pvb-check \
        2>&1 | tee "$RUN_DIR/blaze-v8-check.log"
    echo "Wrote $RUN_DIR/blaze-v8-check.csv"
}

if [[ "${PVB_CHECK_ONLY:-0}" == 1 ]]; then
    run_check
    exit 0
fi

# Run vitest bench via Node.js (V8 engine)
npx vitest bench --run pvb.bench \
    2>&1 | tee "$RUN_DIR/blaze-v8-raw.log" || true

# Parse into unified CSV
python3 /bench/parsers/parse_vitest.py blaze-v8 "$RUN_DIR/blaze-v8-raw.log" > "$RUN_DIR/blaze-v8.csv" || true

# Fill in -1 for any scripts that were given but produced no result
python3 /bench/parsers/fill_failures.py "$RUN_DIR/blaze-v8.csv" "$DATA_DIR" blaze-v8 "$RUN_DIR/blaze-v8-raw.log"

run_check || echo "WARNING: blaze-v8 check failed" >&2
