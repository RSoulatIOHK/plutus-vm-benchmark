#!/bin/bash
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/opshin"

echo "opshin-uplc (Python)"

cd "$BENCH_DIR"

# Our harness (scripts/opshin_bench.py): mainnet PlutusV3 cost model, counting mode, flat decode +
# eval per iteration, evaluation result checked.
export BENCH_DATA_DIR="$DATA_DIR"
export PVB_COSTMODEL_JSON=/bench/mainnet-plutusv3-costmodel.json
export PVB_PARAM_NAMES=/bench/plutusv3-param-names.txt

run_check() {
    # Spec D4: one evaluation per script with the timed loop's parameters.
    python3 bench_plutus_use_cases.py --check "$RUN_DIR/opshin-check.csv" 2>&1 | tee "$RUN_DIR/opshin-check.log"
    echo "Wrote $RUN_DIR/opshin-check.csv"
}

if [[ "${PVB_CHECK_ONLY:-0}" == 1 ]]; then
    run_check
    exit 0
fi

# Run benchmark with the image's Python (python:${PYTHON_VERSION} base image)
if [[ "${BENCH_QUICK:-0}" == 1 ]]; then
    export OPSHIN_TIME_BUDGET_S=0.2 OPSHIN_MIN_ITERS=3
fi
python3 bench_plutus_use_cases.py 2>&1 | tee "$RUN_DIR/opshin-raw.log" || true

# Parse into unified CSV
python3 /bench/parsers/parse_opshin.py "$RUN_DIR/opshin-raw.log" > "$RUN_DIR/opshin.csv" || true

# Append failures from log as -1 entries
{ grep "SKIP (eval error)" "$RUN_DIR/opshin-raw.log" || true; } | while read -r line; do
    script=$(echo "$line" | awk '{print $1}')
    echo "opshin,$script,-1,-1,-1,-1,-1,0" >> "$RUN_DIR/opshin.csv"
done

# Fill in -1 for any scripts that were given but produced no result
python3 /bench/parsers/fill_failures.py "$RUN_DIR/opshin.csv" "$DATA_DIR" opshin "$RUN_DIR/opshin-raw.log"

run_check || echo "WARNING: opshin check failed" >&2
