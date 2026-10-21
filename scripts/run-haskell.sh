#!/bin/bash
# Haskell row (docs/IMAGE_CONTRACT.md): pvb-bench from images/haskell/pvb-bench.
# Mainnet PlutusV3 cost model, protocol version 11, counting mode (spec D3, D11).
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts.
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/haskell"
COST_MODEL="$BENCH_DIR/mainnet-plutusv3-costmodel.json"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }

echo "plutus-core (Haskell / GHC / Criterion)"

# Each script runs for at least 20 s per loop; -L sets that time limit. Two loops: flat decode +
# evaluation (haskell.csv, spec D3) and evaluation of a program decoded once (haskell-eval.csv).
TIMING=()
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    TIMING=(-L 1)
fi

# Check (spec D4): one evaluation per script with the same parameters as the timed loop.
if loop check; then
    "$BENCH_DIR/bin/pvb-bench" check "$COST_MODEL" "$DATA_DIR" > "$RUN_DIR/haskell-check.csv"
fi

# One Criterion loop: time_loop <pvb-bench command> <output name>. A failed script gets a -1 row.
time_loop() {
    local raw="$RUN_DIR/$2-raw.log" criterion="$RUN_DIR/$2-criterion.csv"
    # Clean any leftover from aborted runs (Criterion appends, causing duplicate headers)
    rm -f "$criterion"
    "$BENCH_DIR/bin/pvb-bench" "$1" "$COST_MODEL" "$DATA_DIR" \
        --csv "$criterion" ${TIMING[@]+"${TIMING[@]}"} \
        2>&1 | tee "$raw" || true
    python3 /bench/parsers/parse_criterion_hs.py "$criterion" > "$RUN_DIR/$2.csv" || true
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/$2.csv" "$DATA_DIR" haskell "$raw"
}

# D3: flat decode + evaluation per iteration.
if loop d3; then time_loop bench haskell; fi
# Eval only, same Criterion settings.
if loop eval; then time_loop bench-eval haskell-eval; fi
