#!/bin/bash
# opshin: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-opshin.sh <results-dir>
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts.
set -euo pipefail

VM=opshin
RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }
BENCH_DIR="/bench/opshin"

echo "opshin-uplc (Python)"

cd "$BENCH_DIR"

# Our harness (scripts/opshin_bench.py): mainnet PlutusV3 cost model, counting mode, evaluation
# result checked.
export BENCH_DATA_DIR="$DATA_DIR"
export PVB_COSTMODEL_JSON=/bench/mainnet-plutusv3-costmodel.json
export PVB_PARAM_NAMES=/bench/plutusv3-param-names.txt

run_check() {
    # Spec D4: one evaluation per script, with the timed loop's parameters.
    python3 bench_plutus_use_cases.py --check "$RUN_DIR/$VM-check.csv" \
        2>&1 | tee "$RUN_DIR/$VM-check.log"
    echo "Wrote $RUN_DIR/$VM-check.csv"
}

if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
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
if loop d3; then run_bench "$VM"; fi
# Eval only: the program decoded once, fresh Machine and budget per iteration.
if loop eval; then run_bench "$VM-eval" --eval; fi

if loop check; then run_check || echo "WARNING: $VM check failed" >&2; fi
