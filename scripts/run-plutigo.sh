#!/bin/bash
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/plutigo"

echo "Plutigo (Go / testing.B)"

BENCHTIME=5s
if [[ "${BENCH_QUICK:-0}" == 1 ]]; then
    BENCHTIME=1s
fi

# Our harness (images/plutigo/pvb_bench_test.go): PlutusV3, protocol version 11, the mainnet
# PlutusV3 cost model through cek.NewEvalContext, counting mode, flat decode + eval per iteration.
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
    PVB_CHECK_OUT="$RUN_DIR/plutigo-check.csv" ./plutigo-bench \
        -test.run='^TestPvbCheck$' -test.v -test.count=1 \
        2>&1 | tee "$RUN_DIR/plutigo-check.log"
    echo "Wrote $RUN_DIR/plutigo-check.csv"
}

if [[ "${PVB_CHECK_ONLY:-0}" == 1 ]]; then
    run_check
    exit 0
fi

./plutigo-bench \
    -test.bench='^BenchmarkPvbFlatFiles$' \
    -test.benchmem \
    -test.run='^$' \
    -test.count=1 \
    -test.benchtime="$BENCHTIME" \
    2>&1 | tee "$RUN_DIR/plutigo-raw.log" || true

# Parse into unified CSV
python3 /bench/parsers/parse_go_bench.py "$RUN_DIR/plutigo-raw.log" > "$RUN_DIR/plutigo.csv" || true

# Fill in -1 for any scripts that were given but produced no result
python3 /bench/parsers/fill_failures.py "$RUN_DIR/plutigo.csv" "$DATA_DIR" plutigo "$RUN_DIR/plutigo-raw.log"

run_check || echo "WARNING: plutigo check failed" >&2
