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

# Go test binary uses runtime.Caller(0) which hardcodes the source path /src/tests/bench
# We must place data at that exact path
mkdir -p /src/tests
rm -rf /src/tests/bench
ln -sf "$DATA_DIR" /src/tests/bench

cd "$BENCH_DIR"

# Run compiled Go test binary with benchmark flags
./plutigo-bench \
    -test.bench=BenchmarkFlatFiles \
    -test.benchmem \
    -test.run='^$' \
    -test.count=1 \
    -test.benchtime="$BENCHTIME" \
    2>&1 | tee "$RUN_DIR/plutigo-raw.log" || true

# Parse into unified CSV
python3 /bench/parsers/parse_go_bench.py "$RUN_DIR/plutigo-raw.log" > "$RUN_DIR/plutigo.csv" || true

# Fill in -1 for any scripts that were given but produced no result
python3 /bench/parsers/fill_failures.py "$RUN_DIR/plutigo.csv" "$DATA_DIR" plutigo "$RUN_DIR/plutigo-raw.log"

# ---------------------------------------------------------------------------
# CHECK HOOK (spec D4): the correctness check runs here, one evaluation per script with
# the same parameters as the timed loop, and writes "$RUN_DIR/plutigo-check.csv"
# (vm,script,status,cpu,mem). Implemented by check/, not yet wired in.
# ---------------------------------------------------------------------------
