#!/bin/bash
# blaze-jsc: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-blaze-jsc.sh <results-dir>
#
# Times the scripts in $BENCH_DATA_DIR (5 with BENCH_QUICK=1). The check covers every script of
# the corpus, also with BENCH_QUICK=1, so the gate always sees all of them.
#
# Every vitest call runs as `bun --bun run vitest`: without --bun, bun runs the vitest bin with
# node (its #!/usr/bin/env node shebang), so the code ran on V8. pvb-costs.ts prints the engine
# ("engine: bun ... (JavaScriptCore)") in every log, from inside the vitest worker.
set -euo pipefail

VM=blaze-jsc
RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
CHECK_DATA_DIR=/bench/data/plutus_use_cases
BENCH_DIR="/bench/blaze-plutus"

echo "blaze-jsc (TypeScript / Bun / JavaScriptCore)"

# Our harness (images/blaze/pvb.bench.ts, pvb-eval.bench.ts, pvb-check.test.ts): counting mode,
# the mainnet PlutusV3 cost model mapped into blaze's cost table (pvb-costs.ts).
export PVB_DATA_DIR="$DATA_DIR"
export PVB_COSTMODEL_JSON=/bench/mainnet-plutusv3-costmodel.json
export PVB_PARAM_NAMES=/bench/plutusv3-param-names.txt
export BENCH_QUICK="${BENCH_QUICK:-0}"

cd "$BENCH_DIR/packages/blaze-plutus"

run_check() {
    # Spec D4: one evaluation per script of the whole corpus, with the timed loop's parameters,
    # on the same engine.
    PVB_VM=$VM PVB_DATA_DIR="$CHECK_DATA_DIR" PVB_CHECK_OUT="$RUN_DIR/$VM-check.csv" \
        bun --bun run vitest run pvb-check 2>&1 | tee "$RUN_DIR/$VM-check.log"
    echo "Wrote $RUN_DIR/$VM-check.csv"
}

if [[ "${PVB_CHECK_ONLY:-0}" == 1 ]]; then
    run_check
    exit 0
fi

# timing: vitest bench on Bun (JavaScriptCore). $1 = bench file filter, $2 = output name.
run_bench() {
    local raw="$RUN_DIR/$2-raw.log"
    bun --bun run vitest bench --run "$1" 2>&1 | tee "$raw" || true
    python3 /bench/parsers/parse_vitest.py "$VM" "$raw" > "$RUN_DIR/$2.csv" || true
    # Fill in -1 for any scripts that were given but produced no result
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/$2.csv" "$DATA_DIR" "$VM" "$raw"
}

# D3: flat decode + eval per iteration.
run_bench pvb.bench "$VM"
# Eval only: the program decoded once, fresh machine and budget per iteration.
run_bench pvb-eval.bench "$VM-eval"

run_check || echo "WARNING: $VM check failed" >&2
