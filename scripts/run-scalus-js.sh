#!/bin/bash
# scalus-js: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-scalus-js.sh <results-dir>
#
# pvb-loops: d3 check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts. No eval loop: the scalus npm API cannot evaluate
# an already decoded program (images/scalus-js/README.md, "No eval-only timing").
set -uo pipefail

VM=scalus-js
RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
RAW="$RUN_DIR/$VM-raw.log"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }

cd /bench/scalus-js || exit 1
echo "scalus-js (Scala.js / Node.js $(node --version) / V8), scalus $(node -p 'require("./node_modules/scalus/package.json").version')" \
    | tee "$RAW"

# Correctness: one evaluation per script.
if loop check; then
    DATA_DIR="$DATA_DIR" node check.mjs > "$RUN_DIR/$VM-check.csv" 2> >(tee -a "$RAW" >&2)
fi

# Timing (spec D3, D13): the JMH shape of the JVM rows, one 20 s warm-up round and 3 measured rounds
# of 5 s (time.mjs). BENCH_TIMING=quick: 0.5 s warm-up, one 0.5 s round.
# A new node process per script (spec D14), so no JIT profile or GC state carries over from
# another script. The "--- <name>: process <pid>" line ties a crash in the log to its script
# (fill_failures.py); a script without a PVB_RESULT line gets -1. A crash must not kill the run.
export PVB_WARMUP_MS=20000 PVB_ROUND_MS=5000 PVB_ROUNDS=3
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    export PVB_WARMUP_MS=500 PVB_ROUND_MS=500 PVB_ROUNDS=1
fi
if loop d3; then
    for f in $(cd "$DATA_DIR" && ls -- *.flat | LC_ALL=C sort); do
        name="${f%.flat}"
        # $BASHPID is the pid of the subshell, which exec turns into the node process.
        ( echo "--- $name: process $BASHPID"
          DATA_DIR="$DATA_DIR" PVB_SCRIPT="$name" exec node time.mjs ) 2>&1 | tee -a "$RAW" || true
    done
    python3 /bench/parsers/parse_vitest.py "$VM" "$RAW" > "$RUN_DIR/$VM.csv"
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/$VM.csv" "$DATA_DIR" "$VM" "$RAW"
    # BENCH_TRACE=1: the warm-up in 1 s slices -> $VM-warmup.csv
    if [[ "${BENCH_TRACE:-0}" == 1 ]]; then
        python3 /bench/parsers/parse_warmup.py "$VM" "$RAW" > "$RUN_DIR/$VM-warmup.csv" || true
    fi
fi
