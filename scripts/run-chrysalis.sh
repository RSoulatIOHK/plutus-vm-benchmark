#!/bin/bash
# chrysalis: Chrysalis.Plutus CEK machine on .NET (JIT), timed with BenchmarkDotNet in process
# (images/chrysalis/harness). PlutusV3 with the mainnet cost model, costing on with a restricting
# budget too large to run out (check/README.md):
#   D3    per operation flat decode + CEK evaluation (spec D3)         -> chrysalis.csv
#   Eval  per operation CEK evaluation of the program decoded once     -> chrysalis-eval.csv
# Then the check: one evaluation per script.
# scripts/run-chrysalis-aot.sh runs this script with CHRYSALIS_VM=chrysalis-aot: the same harness,
# compiled with NativeAOT.
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts.
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
VM="${CHRYSALIS_VM:-chrysalis}"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }

case "$VM" in
    chrysalis) BIN=/bench/chrysalis/jit/pvb-chrysalis; echo "Chrysalis (C# / .NET JIT / BenchmarkDotNet)" ;;
    chrysalis-aot) BIN=/bench/chrysalis/aot/pvb-chrysalis; echo "Chrysalis AOT (C# / .NET NativeAOT / BenchmarkDotNet)" ;;
    *) echo "ERROR: CHRYSALIS_VM=$VM: expected chrysalis or chrysalis-aot" >&2; exit 1 ;;
esac
COSTS=/bench/chrysalis/mainnet-plutusv3-costmodel.json
RAW="$RUN_DIR/$VM-raw.log"
: > "$RAW"
echo "chrysalis.plutus: $(cat /bench/chrysalis/version.txt), dotnet: $(cat /bench/chrysalis/dotnet-version.txt)" | tee -a "$RAW"

# Timing (METHODOLOGY.md, D13). The harness picks the BenchmarkDotNet job:
# - chrysalis (JIT): the JMH shape of the scalus rows: 30 s warm-up (6 iterations of 5 s), then 3
#   measurement iterations of 5 s. BENCH_TRACE=1: 30 warm-up and 15 measurement iterations of 1 s.
# - chrysalis-aot: BenchmarkDotNet's defaults (an ahead-of-time compiled VM keeps its framework's
#   warm-up rules): 500 ms iterations, warm-up and iteration count chosen by BenchmarkDotNet.
# - BENCH_TIMING=quick: one 1 s warm-up and one 1 s measurement iteration.
LOOPS=()
if loop d3; then LOOPS+=(d3); fi
if loop eval; then LOOPS+=(eval); fi

# parse_loop <loop> <csv>: the PVB_RESULT lines of one loop (parse_vitest.py reads the rounds line
# of every in-process harness), -1 for a script without a result or with an error in that loop.
parse_loop() {
    python3 /bench/parsers/parse_vitest.py "$VM" "$RAW" "$1" > "$2" || true
    python3 /bench/parsers/fill_failures.py "$2" "$DATA_DIR" "$VM" "$RAW" --loop "$1"
}

if [[ ${#LOOPS[@]} -gt 0 ]]; then
    # One process per script (spec D14). It runs the requested loops of its script, d3 first, then
    # eval, each with its own warm-up and measurement, and prints "PVB_LOOP <loop> <script>" when a
    # loop starts. "--- <name>: process" ties a crash in the log to its script (fill_failures.py).
    for f in $(cd "$DATA_DIR" && ls -- *.flat | LC_ALL=C sort); do
        # $BASHPID is the pid of the subshell, which exec turns into the harness process.
        ( echo "--- ${f%.flat}: process $BASHPID"
          exec "$BIN" time "$VM" "$DATA_DIR/$f" "$COSTS" "$(IFS=,; echo "${LOOPS[*]}")" \
              "${BENCH_TIMING:-normal}" "${BENCH_TRACE:-0}" ) 2>&1 \
            | tee -a "$RAW" || true
    done
    if loop d3; then parse_loop d3 "$RUN_DIR/$VM.csv"; fi
    if loop eval; then parse_loop eval "$RUN_DIR/$VM-eval.csv"; fi
    # The JIT row: the length of each warm-up (fixed) -> $VM-warmup-used.csv. BENCH_TRACE=1: also
    # the warm-up in 1 s slices -> $VM-warmup.csv
    if [[ "$VM" == chrysalis ]]; then
        python3 /bench/parsers/parse_warmup.py --used "$VM" "$RAW" > "$RUN_DIR/$VM-warmup-used.csv" || true
        if [[ "${BENCH_TRACE:-0}" == 1 ]]; then
            python3 /bench/parsers/parse_warmup.py "$VM" "$RAW" > "$RUN_DIR/$VM-warmup.csv" || true
        fi
    fi
fi

# Check (spec D4): one evaluation per script, same code and parameters -> $VM-check.csv
if loop check; then
    echo "=== check" | tee -a "$RAW"
    "$BIN" check "$VM" "$DATA_DIR" "$COSTS" "$RUN_DIR/$VM-check.csv" 2>&1 | tee -a "$RAW" || true
fi
