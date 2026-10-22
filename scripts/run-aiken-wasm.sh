#!/bin/bash
# aiken-wasm: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-aiken-wasm.sh <results-dir>
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts. The package caches the decoded program after the
# first call, so the timed loop is eval-only already (images/aiken-wasm/README.md): it runs once
# when d3 or eval is requested and writes aiken-wasm.csv for d3 and aiken-wasm-eval.csv for eval,
# as scripts/run-scalus-jit.sh does.
set -uo pipefail

VM=aiken-wasm
RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
RAW="$RUN_DIR/$VM-raw.log"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }

cd /bench/aiken-wasm || exit 1
{
    echo "aiken-wasm (Aiken uplc -> WASM / Node.js $(node --version) / V8), @lucid-evolution/uplc $(node -p 'require("./node_modules/@lucid-evolution/uplc/package.json").version')"
    echo "uplc_build_info: $(node -p 'require("@lucid-evolution/uplc").uplc_build_info()')"
} | tee "$RAW"

# Correctness: one evaluation per script.
if loop check; then
    DATA_DIR="$DATA_DIR" node check.mjs > "$RUN_DIR/$VM-check.csv" 2> >(tee -a "$RAW" >&2)
fi

# Timing (spec D3, D13): the JMH shape of the JVM rows, one 20 s warm-up round and 3 measured rounds
# of 5 s (time.mjs). BENCH_TIMING=quick: 0.5 s warm-up, one 0.5 s round.
# A new node process per script (spec D14), so no JIT profile, GC state or decode cache carries
# over from another script. The "--- <name>: process <pid>" line ties a crash in the log to its
# script (fill_failures.py); a script without a PVB_RESULT line gets -1. A crash must not kill the
# run.
export PVB_WARMUP_MS=20000 PVB_ROUND_MS=5000 PVB_ROUNDS=3
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    export PVB_WARMUP_MS=500 PVB_ROUND_MS=500 PVB_ROUNDS=1
fi
if loop d3 || loop eval; then
    for f in $(cd "$DATA_DIR" && ls -- *.flat | LC_ALL=C sort); do
        name="${f%.flat}"
        # $BASHPID is the pid of the subshell, which exec turns into the node process.
        ( echo "--- $name: process $BASHPID"
          DATA_DIR="$DATA_DIR" PVB_SCRIPT="$name" exec node time.mjs ) 2>&1 | tee -a "$RAW" || true
    done
    TIMING_CSV="$RUN_DIR/$VM-timing.tmp"
    python3 /bench/parsers/parse_vitest.py "$VM" "$RAW" > "$TIMING_CSV"
    python3 /bench/parsers/fill_failures.py "$TIMING_CSV" "$DATA_DIR" "$VM" "$RAW"
    # One loop, two files: with the decode cached, the D3 time is the eval-only time.
    if loop d3; then cp "$TIMING_CSV" "$RUN_DIR/$VM.csv"; fi
    if loop eval; then cp "$TIMING_CSV" "$RUN_DIR/$VM-eval.csv"; fi
    rm -f "$TIMING_CSV"
    # BENCH_TRACE=1: the warm-up in 1 s slices -> $VM-warmup.csv
    if [[ "${BENCH_TRACE:-0}" == 1 ]]; then
        python3 /bench/parsers/parse_warmup.py "$VM" "$RAW" > "$RUN_DIR/$VM-warmup.csv" || true
    fi
fi
