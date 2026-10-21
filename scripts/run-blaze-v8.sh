#!/bin/bash
# blaze-v8: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-blaze-v8.sh <results-dir>
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing (read by pvb.bench.ts and pvb-eval.bench.ts). The check covers the same scripts.
set -euo pipefail

VM=blaze-v8
RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }
BENCH_DIR="/bench/blaze-plutus"

echo "blaze-v8 (TypeScript / Node.js / V8)"

# Our harness (images/blaze/pvb.bench.ts, pvb-eval.bench.ts, pvb-check.test.ts): counting mode,
# the mainnet PlutusV3 cost model mapped into blaze's cost table (pvb-costs.ts).
export PVB_DATA_DIR="$DATA_DIR"
export PVB_COSTMODEL_JSON=/bench/mainnet-plutusv3-costmodel.json
export PVB_PARAM_NAMES=/bench/plutusv3-param-names.txt

cd "$BENCH_DIR/packages/blaze-plutus"

run_check() {
    # Spec D4: one evaluation per script, with the timed loop's parameters, on the same engine.
    PVB_VM=$VM PVB_DATA_DIR="$DATA_DIR" PVB_CHECK_OUT="$RUN_DIR/$VM-check.csv" \
        npx vitest run pvb-check 2>&1 | tee "$RUN_DIR/$VM-check.log"
    echo "Wrote $RUN_DIR/$VM-check.csv"
}

# timing: vitest bench on Node.js (V8). $1 = bench file filter, $2 = output name.
run_bench() {
    local raw="$RUN_DIR/$2-raw.log"
    npx vitest bench --run "$1" 2>&1 | tee "$raw" || true
    python3 /bench/parsers/parse_vitest.py "$VM" "$raw" > "$RUN_DIR/$2.csv" || true
    # Fill in -1 for any scripts that were given but produced no result
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/$2.csv" "$DATA_DIR" "$VM" "$raw"
}

# D3: flat decode + eval per iteration.
if loop d3; then run_bench pvb.bench "$VM"; fi
# Eval only: the program decoded once, fresh machine and budget per iteration.
if loop eval; then run_bench pvb-eval.bench "$VM-eval"; fi

if loop check; then run_check || echo "WARNING: $VM check failed" >&2; fi
