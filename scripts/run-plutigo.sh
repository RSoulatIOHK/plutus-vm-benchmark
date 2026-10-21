#!/bin/bash
# plutigo: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-plutigo.sh <results-dir>
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts.
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }
BENCH_DIR="/bench/plutigo"

echo "Plutigo (Go / testing.B)"

BENCHTIME=5s
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    BENCHTIME=1s
fi

# Our harness (images/plutigo/pvb_bench_test.go): PlutusV3, protocol version 11, the mainnet
# PlutusV3 cost model through cek.NewEvalContext, counting mode. BenchmarkPvbFlatFiles: flat decode
# + eval per iteration (plutigo.csv). BenchmarkPvbEval: eval of a program decoded once (plutigo-eval.csv).
export PVB_DATA_DIR="$DATA_DIR"
export PVB_COSTMODEL=/tmp/plutigo-costmodel.txt
python3 -c "
import json, sys
values = json.load(open('/bench/mainnet-plutusv3-costmodel.json'))['PlutusV3']
open(sys.argv[1], 'w').write('\n'.join(map(str, values)) + '\n')
" "$PVB_COSTMODEL"

cd "$BENCH_DIR"

run_check() {
    # Spec D4: one evaluation per script with the timed loop's parameters.
    PVB_DATA_DIR="$DATA_DIR" PVB_CHECK_OUT="$RUN_DIR/plutigo-check.csv" ./plutigo-bench \
        -test.run='^TestPvbCheck$' -test.v -test.count=1 \
        2>&1 | tee "$RUN_DIR/plutigo-check.log"
    echo "Wrote $RUN_DIR/plutigo-check.csv"
}

# One testing.B loop: run_bench <benchmark> <output name>. A failed script gets a -1 row.
run_bench() {
    local raw="$RUN_DIR/$2-raw.log"
    ./plutigo-bench \
        -test.bench="^$1\$" \
        -test.benchmem \
        -test.run='^$' \
        -test.count=1 \
        -test.benchtime="$BENCHTIME" \
        2>&1 | tee "$raw" || true
    python3 /bench/parsers/parse_go_bench.py "$raw" > "$RUN_DIR/$2.csv" || true
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/$2.csv" "$DATA_DIR" plutigo "$raw"
}

# D3: flat decode + eval per iteration.
if loop d3; then run_bench BenchmarkPvbFlatFiles plutigo; fi
# Eval only: same testing.B settings, the program is decoded before timing.
if loop eval; then run_bench BenchmarkPvbEval plutigo-eval; fi

if loop check; then run_check || echo "WARNING: plutigo check failed" >&2; fi
