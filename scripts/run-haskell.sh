#!/bin/bash
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/haskell"

echo "plutus-core (Haskell / GHC / Criterion)"

# The validation bench runs each script for at least 20 s; -L sets that time limit.
TIMING=()
if [[ "${BENCH_QUICK:-0}" == 1 ]]; then
    TIMING=(-L 1)
fi

# Symlink canonical flat files into the expected data location
rm -rf "$BENCH_DIR/validation/data"
mkdir -p "$BENCH_DIR/validation"
ln -sf "$DATA_DIR" "$BENCH_DIR/validation/data"

# Set Cabal Paths module data dir override
export plutus_benchmark_datadir="$BENCH_DIR"

# Clean any leftover from aborted runs (Criterion appends, causing duplicate headers)
rm -f "$RUN_DIR/haskell-criterion.csv"

# Run Criterion benchmark binary directly with CSV output
# The binary may exit non-zero after writing CSV (template file not found), so ignore exit code
"$BENCH_DIR/bin/validation" --csv "$RUN_DIR/haskell-criterion.csv" ${TIMING[@]+"${TIMING[@]}"} \
    2>&1 | tee "$RUN_DIR/haskell-raw.log" || true

# Parse Criterion CSV into unified CSV format
python3 /bench/parsers/parse_criterion_hs.py "$RUN_DIR/haskell-criterion.csv" > "$RUN_DIR/haskell.csv" || true

# Fill in -1 for any scripts that were given but produced no result
python3 /bench/parsers/fill_failures.py "$RUN_DIR/haskell.csv" "$DATA_DIR" haskell "$RUN_DIR/haskell-raw.log"

# ---------------------------------------------------------------------------
# CHECK HOOK (spec D4): the correctness check runs here, one evaluation per script with
# the same parameters as the timed loop, and writes "$RUN_DIR/haskell-check.csv"
# (vm,script,status,cpu,mem). Implemented by check/, not yet wired in.
# ---------------------------------------------------------------------------
