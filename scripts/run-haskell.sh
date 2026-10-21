#!/bin/bash
# Haskell row (docs/IMAGE_CONTRACT.md): pvb-bench from images/haskell/pvb-bench.
# Mainnet PlutusV3 cost model, protocol version 11, counting mode (spec D3, D11).
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/haskell"
COST_MODEL="$BENCH_DIR/mainnet-plutusv3-costmodel.json"

echo "plutus-core (Haskell / GHC / Criterion)"

# Each script runs for at least 20 s; -L sets that time limit.
TIMING=()
if [[ "${BENCH_QUICK:-0}" == 1 ]]; then
    TIMING=(-L 1)
fi

# Check (spec D4): one evaluation per script with the same parameters as the timed loop.
"$BENCH_DIR/bin/pvb-bench" check "$COST_MODEL" "$DATA_DIR" > "$RUN_DIR/haskell-check.csv"

# Clean any leftover from aborted runs (Criterion appends, causing duplicate headers)
rm -f "$RUN_DIR/haskell-criterion.csv"

# Timed loop: flat decode + evaluation per iteration. A failed script gets a -1 row below.
"$BENCH_DIR/bin/pvb-bench" bench "$COST_MODEL" "$DATA_DIR" \
    --csv "$RUN_DIR/haskell-criterion.csv" ${TIMING[@]+"${TIMING[@]}"} \
    2>&1 | tee "$RUN_DIR/haskell-raw.log" || true

# Parse Criterion CSV into unified CSV format
python3 /bench/parsers/parse_criterion_hs.py "$RUN_DIR/haskell-criterion.csv" > "$RUN_DIR/haskell.csv" || true

# Fill in -1 for any scripts that were given but produced no result
python3 /bench/parsers/fill_failures.py "$RUN_DIR/haskell.csv" "$DATA_DIR" haskell "$RUN_DIR/haskell-raw.log"
