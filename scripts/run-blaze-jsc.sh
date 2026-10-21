#!/bin/bash
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/blaze-plutus"

echo "blaze-jsc (TypeScript / Bun / JavaScriptCore)"

# Our harness (images/blaze/pvb.bench.ts, pvb-check.test.ts): flat decode + eval per iteration,
# counting mode, the mainnet PlutusV3 cost model mapped into blaze's cost table (pvb-costs.ts).
export PVB_DATA_DIR="$DATA_DIR"
export PVB_COSTMODEL_JSON=/bench/mainnet-plutusv3-costmodel.json
export PVB_PARAM_NAMES=/bench/plutusv3-param-names.txt
export BENCH_QUICK="${BENCH_QUICK:-0}"

cd "$BENCH_DIR/packages/blaze-plutus"

run_check() {
    # Spec D4: one evaluation per script with the timed loop's parameters, on the same engine.
    PVB_VM=blaze-jsc PVB_CHECK_OUT="$RUN_DIR/blaze-jsc-check.csv" bun --bun run vitest run pvb-check \
        2>&1 | tee "$RUN_DIR/blaze-jsc-check.log"
    echo "Wrote $RUN_DIR/blaze-jsc-check.csv"
}

if [[ "${PVB_CHECK_ONLY:-0}" == 1 ]]; then
    run_check
    exit 0
fi

# Run vitest bench via Bun (JavaScriptCore engine). --bun: without it, bun runs the vitest bin
# with node (its #!/usr/bin/env node shebang), so the bench ran on V8.
bun --bun run vitest bench --run pvb.bench \
    2>&1 | tee "$RUN_DIR/blaze-jsc-raw.log" || true

# Parse into unified CSV
python3 /bench/parsers/parse_vitest.py blaze-jsc "$RUN_DIR/blaze-jsc-raw.log" > "$RUN_DIR/blaze-jsc.csv" || true

# Fill in -1 for any scripts that were given but produced no result
python3 /bench/parsers/fill_failures.py "$RUN_DIR/blaze-jsc.csv" "$DATA_DIR" blaze-jsc "$RUN_DIR/blaze-jsc-raw.log"

run_check || echo "WARNING: blaze-jsc check failed" >&2
