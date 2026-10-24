#!/bin/bash
# scalus-js: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-scalus-js.sh <results-dir>
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts. The eval loop evaluates a program decoded
# before the timing (uplc.decodeProgram).
set -uo pipefail

VM=scalus-js
RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
RAW="$RUN_DIR/$VM-raw.log"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }

cd /bench/scalus-js || exit 1
echo "$VM (Scala.js / Node.js $(node --version) / V8), scalus $(node -p 'require("./node_modules/scalus/package.json").version')" \
    | tee "$RAW"

# Correctness: one evaluation per script.
if loop check; then
    DATA_DIR="$DATA_DIR" node check.mjs > "$RUN_DIR/$VM-check.csv" 2> >(tee -a "$RAW" >&2)
fi

# Timing (spec D3, D13): the JMH shape of the JVM rows, the adaptive warm-up and 3 measured rounds
# of 5 s (time.mjs). Adaptive: rounds of 1 s until at least 5 s have passed and the last 5 are
# within 3 % of their median, 30 s at most. BENCH_TIMING=quick: a fixed 0.5 s warm-up, one 0.5 s
# round.
# A new node process per script (spec D14), so no JIT profile or GC state carries over from
# another script. The "--- <name>: process <pid>" line ties a crash in the log to its script
# (fill_failures.py); a script without a PVB_RESULT line gets -1. A crash must not kill the run.
export PVB_WARMUP_MS=adaptive PVB_ROUND_MS=5000 PVB_ROUNDS=3
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    export PVB_WARMUP_MS=500 PVB_ROUND_MS=500 PVB_ROUNDS=1
fi
# time_loop <loop>: one node process per script, then the CSV of that loop.
time_loop() {
    local csv="$RUN_DIR/$VM.csv"
    [[ "$1" == eval ]] && csv="$RUN_DIR/$VM-eval.csv"
    for f in $(cd "$DATA_DIR" && ls -- *.flat | LC_ALL=C sort); do
        name="${f%.flat}"
        # $BASHPID is the pid of the subshell, which exec turns into the node process.
        ( echo "--- $name: process $BASHPID"
          DATA_DIR="$DATA_DIR" PVB_SCRIPT="$name" PVB_LOOP="$1" exec node time.mjs ) 2>&1 | tee -a "$RAW" || true
    done
    python3 /bench/parsers/parse_vitest.py "$VM" "$RAW" "$1" > "$csv"
    python3 /bench/parsers/fill_failures.py "$csv" "$DATA_DIR" "$VM" "$RAW"
}
if loop d3; then time_loop d3; fi
if loop eval; then time_loop eval; fi
if loop d3 || loop eval; then
    # The length of each warm-up and whether it hit the cap -> $VM-warmup-used.csv.
    # BENCH_TRACE=1: also the warm-up in 1 s slices -> $VM-warmup.csv
    python3 /bench/parsers/parse_warmup.py --used "$VM" "$RAW" > "$RUN_DIR/$VM-warmup-used.csv" || true
    if [[ "${BENCH_TRACE:-0}" == 1 ]]; then
        python3 /bench/parsers/parse_warmup.py "$VM" "$RAW" > "$RUN_DIR/$VM-warmup.csv" || true
    fi
fi
