#!/bin/bash
# plutuz: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-plutuz.sh <results-dir>
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts.
set -uo pipefail

VM=plutuz
RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }
RAW="$RUN_DIR/$VM-raw.log"
BENCH=/bench/plutuz/pvb-bench
COSTMODEL=/bench/mainnet-plutusv3-costmodel.json

{
    echo "Plutuz (Zig) utxo-company/plutuz@${PLUTUZ_SHA:-unknown}"
    echo "BENCH_LOOPS=${BENCH_LOOPS:-d3,eval,check} BENCH_TIMING=${BENCH_TIMING:-normal}"
} | tee "$RAW"

# Correctness (spec D4): one evaluation per script with the timed loops' parameters
# (images/plutuz/pvb_bench.zig). The cost model lines of the log list any builtin that kept
# Plutuz's built-in numbers.
if loop check; then
    "$BENCH" check "$COSTMODEL" "$RUN_DIR/$VM-check.csv" "$DATA_DIR" 2>&1 | tee "$RUN_DIR/$VM-check.log"
    echo "Wrote $RUN_DIR/$VM-check.csv"
fi

# Timing (spec D13): the rules of Plutuz's own bench (bench/bench.zig), an ahead-of-time
# compiled VM: 5 warm-up iterations, then at least 50 iterations and at least 5 s of measurement.
MEASURE_MS=5000
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    MEASURE_MS=1000
fi
echo "Plutuz bench: 5 warm-up iterations, >= 50 iterations, >= ${MEASURE_MS} ms" | tee -a "$RAW"

LOOPS=()
if loop d3; then LOOPS+=(d3); fi
if loop eval; then LOOPS+=(eval); fi

# One process per script (spec D14): d3 first, then eval. A crash does not stop the run; the
# script gets a -1 row below.
if [[ ${#LOOPS[@]} -gt 0 ]]; then
    for flat in "$DATA_DIR"/*.flat; do
        name=$(basename "$flat" .flat)
        # $BASHPID is the pid of the subshell, which exec turns into the benchmark process.
        ( echo "--- $name: process $BASHPID"
          exec "$BENCH" time "$COSTMODEL" "$flat" "$(IFS=,; echo "${LOOPS[*]}")" "$MEASURE_MS" ) \
            2>&1 | tee -a "$RAW" || true
    done

    # parse_loop <loop> <csv>: the PVB_RESULT lines of one loop -> <csv>, a -1 row for each
    # script without a result or with an error in the log.
    parse_loop() {
        python3 /bench/parsers/parse_plutuz_json.py "$RAW" "$1" > "$2" || true
        python3 /bench/parsers/fill_failures.py "$2" "$DATA_DIR" "$VM" "$RAW" --loop "$1"
    }
    if loop d3; then parse_loop d3 "$RUN_DIR/$VM.csv"; fi
    if loop eval; then parse_loop eval "$RUN_DIR/$VM-eval.csv"; fi
fi
