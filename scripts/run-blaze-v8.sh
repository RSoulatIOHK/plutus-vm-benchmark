#!/bin/bash
# blaze-v8: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-blaze-v8.sh <results-dir>
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts.
set -euo pipefail

VM=blaze-v8
RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }
BENCH_DIR="/bench/blaze-plutus"
VITEST=(npx vitest)
vitest() { "${VITEST[@]}" "$@"; }

echo "blaze-v8 (TypeScript / Node.js / V8)"

# Our harness (images/blaze/pvb-time.test.ts, pvb-check.test.ts): counting mode, the mainnet
# PlutusV3 cost model mapped into blaze's cost table (pvb-costs.ts).
export PVB_DATA_DIR="$DATA_DIR"
export PVB_COSTMODEL_JSON=/bench/mainnet-plutusv3-costmodel.json
export PVB_PARAM_NAMES=/bench/plutusv3-param-names.txt

# Timing (spec D13): the JMH shape of the JVM rows, one 20 s warm-up round and 3 measured rounds of
# 5 s (pvb-time.test.ts). BENCH_TIMING=quick: 0.5 s warm-up, one 0.5 s round.
export PVB_WARMUP_MS=20000 PVB_ROUND_MS=5000 PVB_ROUNDS=3
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    export PVB_WARMUP_MS=500 PVB_ROUND_MS=500 PVB_ROUNDS=1
fi

cd "$BENCH_DIR/packages/blaze-plutus"

run_check() {
    # Spec D4: one evaluation per script, with the timed loop's parameters, on the same engine.
    PVB_VM=$VM PVB_DATA_DIR="$DATA_DIR" PVB_CHECK_OUT="$RUN_DIR/$VM-check.csv" \
        vitest run pvb-check 2>&1 | tee "$RUN_DIR/$VM-check.log"
    echo "Wrote $RUN_DIR/$VM-check.csv"
}

# The timed loops. A new vitest process per script (spec D14), so no JIT profile or GC state
# carries over from another script. The process runs the requested loops of its script, d3 first,
# then eval, each with its own warm-up and rounds (pvb-time.test.ts). The "--- <name>: process"
# line ties a crash in the log to its script (fill_failures.py); a script without a PVB_RESULT line
# for a loop gets -1 in that loop's file.
RAW="$RUN_DIR/$VM-raw.log"
LOOPS=()
if loop d3; then LOOPS+=(d3); fi
if loop eval; then LOOPS+=(eval); fi

# parse_loop <loop> <csv>
parse_loop() {
    python3 /bench/parsers/parse_vitest.py "$VM" "$RAW" "$1" > "$2" || true
    python3 /bench/parsers/fill_failures.py "$2" "$DATA_DIR" "$VM" "$RAW" --loop "$1"
}

if [[ ${#LOOPS[@]} -gt 0 ]]; then
    : > "$RAW"
    for f in $(cd "$DATA_DIR" && ls -- *.flat | LC_ALL=C sort); do
        name="${f%.flat}"
        # $BASHPID is the pid of the subshell, which exec turns into the launcher process.
        ( echo "--- $name: process $BASHPID"
          export PVB_LOOPS="$(IFS=,; echo "${LOOPS[*]}")" PVB_SCRIPT="$name"
          exec "${VITEST[@]}" run pvb-time ) 2>&1 \
            | tee -a "$RAW" || true
    done
    # D3: flat decode + eval per operation. Eval only: the program decoded once, fresh machine and
    # budget per operation.
    if loop d3; then parse_loop d3 "$RUN_DIR/$VM.csv"; fi
    if loop eval; then parse_loop eval "$RUN_DIR/$VM-eval.csv"; fi
    # BENCH_TRACE=1: the warm-up in 1 s slices -> $VM-warmup.csv
    if [[ "${BENCH_TRACE:-0}" == 1 ]]; then
        python3 /bench/parsers/parse_warmup.py "$VM" "$RAW" > "$RUN_DIR/$VM-warmup.csv" || true
    fi
fi

if loop check; then run_check || echo "WARNING: $VM check failed" >&2; fi
