#!/bin/bash
# opshin: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-opshin.sh <results-dir>
#
# Times the scripts in $BENCH_DATA_DIR (5 with BENCH_QUICK=1). The check covers every script of
# the corpus, also with BENCH_QUICK=1, so the gate always sees all of them.
set -euo pipefail

VM=opshin
RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
CHECK_DATA_DIR=/bench/data/plutus_use_cases
BENCH_DIR="/bench/opshin"

echo "opshin-uplc (Python)"

cd "$BENCH_DIR"

# Our harness (scripts/opshin_bench.py): mainnet PlutusV3 cost model, counting mode, evaluation
# result checked.
export BENCH_DATA_DIR="$DATA_DIR"
export PVB_COSTMODEL_JSON=/bench/mainnet-plutusv3-costmodel.json
export PVB_PARAM_NAMES=/bench/plutusv3-param-names.txt

run_check() {
    # Spec D4: one evaluation per script of the whole corpus, with the timed loop's parameters.
    BENCH_DATA_DIR="$CHECK_DATA_DIR" python3 bench_plutus_use_cases.py --check "$RUN_DIR/$VM-check.csv" \
        2>&1 | tee "$RUN_DIR/$VM-check.log"
    echo "Wrote $RUN_DIR/$VM-check.csv"
}

if [[ "${PVB_CHECK_ONLY:-0}" == 1 ]]; then
    run_check
    exit 0
fi

if [[ "${BENCH_QUICK:-0}" == 1 ]]; then
    export OPSHIN_TIME_BUDGET_S=0.2 OPSHIN_MIN_ITERS=3
fi

# timing with the image's Python (python:${PYTHON_VERSION} base image).
# $1 = output name, then the bench_plutus_use_cases.py arguments.
run_bench() {
    local out="$1" raw="$RUN_DIR/$1-raw.log"
    shift
    python3 bench_plutus_use_cases.py "$@" 2>&1 | tee "$raw" || true

    # Parse into unified CSV
    python3 /bench/parsers/parse_opshin.py "$raw" > "$RUN_DIR/$out.csv" || true

    # Append failures from log as -1 entries
    { grep "SKIP (eval error)" "$raw" || true; } | while read -r line; do
        script=$(echo "$line" | awk '{print $1}')
        echo "$VM,$script,-1,-1,-1,-1,-1,0" >> "$RUN_DIR/$out.csv"
    done

    # Fill in -1 for any scripts that were given but produced no result
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/$out.csv" "$DATA_DIR" "$VM" "$raw"
}

# D3: flat decode + eval per iteration.
run_bench "$VM"
# Eval only: the program decoded once, fresh Machine and budget per iteration.
run_bench "$VM-eval" --eval

run_check || echo "WARNING: $VM check failed" >&2
