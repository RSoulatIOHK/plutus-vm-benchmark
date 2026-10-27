#!/bin/bash
# llvm-uplc-jit: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-llvm-uplc-jit.sh <results-dir>
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. Like the Scalus JIT (spec D15, D21) the VM compiles each script before it runs it,
# so it has one timed loop: evaluation of the compiled script (decode and compile excluded). It
# runs when d3 or eval is requested and writes llvm-uplc-jit.csv for d3 and llvm-uplc-jit-eval.csv
# for eval. The check writes llvm-uplc-jit-check.csv and llvm-uplc-jit-compile.csv.
#
# Parameters: llvm-uplc has no API for a cost model. It runs with its compiled-in model, the
# plutus variant C numbers (spec D10, check/README.md "Badge"). Costing on, budget INT64_MAX.
# Harness: images/llvm-uplc/pvb_main.cc.
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/llvm-uplc"
VM=llvm-uplc-jit
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }

echo "llvm-uplc JIT (C++ / LLVM $(cat "$BENCH_DIR/llvm-version.txt") LLJIT)"

# Timing of upstream uplcbench (the framework's own rules): 5 warm-up iterations, then at least
# 50 iterations and 5 s, at most 30 s. BENCH_TIMING=quick: at least 1 s, at most 2 s. The check
# compiles each script once: one compile takes 1.9 to 36 s, so the median of 3 costs too much.
MIN_TIME=5
MAX_TIME=30
COMPILE_RUNS=1
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    MIN_TIME=1
    MAX_TIME=2
fi

RAW="$RUN_DIR/$VM-raw.log"
: > "$RAW"

# The timed loop. One process per script (spec D14): it compiles the script, then times it.
if loop d3 || loop eval; then
    work=$(mktemp -d /tmp/llvm-uplc.XXXXXX)
    for flat in "$DATA_DIR"/*.flat; do
        name=$(basename "$flat" .flat)
        # $BASHPID is the pid of the subshell, which exec turns into the benchmark process.
        ( echo "--- $name: process $BASHPID"
          exec "$BENCH_DIR/pvb-llvm-uplc" time "$flat" "$work/$name.json" "$MIN_TIME" "$MAX_TIME" ) \
            2>&1 | tee -a "$RAW" || true
    done

    TIMING_CSV="$RUN_DIR/$VM-timing.tmp"
    python3 /bench/parsers/parse_llvm_uplc_json.py "$VM" "$work"/*.json > "$TIMING_CSV" || true
    python3 /bench/parsers/fill_failures.py "$TIMING_CSV" "$DATA_DIR" "$VM" "$RAW"
    rm -rf "$work"

    # The loop evaluates the compiled script: it is the D3 and the eval-only timing.
    if loop d3; then cp "$TIMING_CSV" "$RUN_DIR/$VM.csv"; fi
    if loop eval; then cp "$TIMING_CSV" "$RUN_DIR/$VM-eval.csv"; fi
    rm -f "$TIMING_CSV"
fi

# Check (spec D4): one evaluation per script with the same parameters -> $VM-check.csv, and the
# compile time (flat decode + compile) -> $VM-compile.csv
if loop check; then
    echo "=== check" | tee -a "$RAW"
    "$BENCH_DIR/pvb-llvm-uplc" check "$DATA_DIR" "$RUN_DIR/$VM-check.csv" "$RUN_DIR/$VM-compile.csv" \
        "$COMPILE_RUNS" 2>&1 | tee -a "$RAW" || echo "WARNING: $VM check failed" >&2
fi
