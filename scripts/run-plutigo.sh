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

# testing.B settings (spec D13): b.Loop's own ramp-up of b.N serves as the warm-up, and the final
# round runs for at least 5 s.
BENCHTIME=5s
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    BENCHTIME=1s
fi

# Runtime settings (spec D16): those of Dingo, the node that ships plutigo. Dingo v0.86.0
# (b1e42b2) sets no GOGC and no GOMEMLIMIT, sizes GOMAXPROCS with go.uber.org/automaxprocs
# (cmd/dingo/main.go:38; without a CPU quota that is the Go default, the CPU count), and builds
# with CGO_ENABLED=0 and plain `go build` (Makefile:54-56,236-244). Its PGO profile
# (cmd/dingo/default.pgo) has no plutigo function, so it would not change our binary. So the
# Go defaults apply; the log records them.
echo "Go runtime: GOGC=${GOGC:-default} GOMEMLIMIT=${GOMEMLIMIT:-default} GOMAXPROCS=${GOMAXPROCS:-default} ($(nproc) CPUs)"

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
#
# One process per script (spec D14), so no heap or GC state carries from one script to the next.
# The process gets a data dir with only its script, because the benchmark evaluates every file of
# its data dir once before timing; the sub-benchmark filter (^<name>$) selects it too.
run_bench() {
    local raw="$RUN_DIR/$2-raw.log"
    : > "$raw"
    local work flat name
    work=$(mktemp -d /tmp/plutigo-one.XXXXXX)
    for flat in "$DATA_DIR"/*.flat; do
        name=$(basename "$flat" .flat)
        mkdir -p "$work/$name"
        ln -sf "$flat" "$work/$name/"
        # $BASHPID is the pid of the subshell, which exec turns into the benchmark process.
        ( echo "--- $name: process $BASHPID"
          exec env PVB_DATA_DIR="$work/$name" ./plutigo-bench \
              -test.bench="^$1\$/^$name\$" \
              -test.benchmem \
              -test.run='^$' \
              -test.count=1 \
              -test.benchtime="$BENCHTIME" ) 2>&1 | tee -a "$raw" || true
    done
    rm -rf "$work"
    python3 /bench/parsers/parse_go_bench.py "$raw" > "$RUN_DIR/$2.csv" || true
    python3 /bench/parsers/fill_failures.py "$RUN_DIR/$2.csv" "$DATA_DIR" plutigo "$raw"
}

# D3: flat decode + eval per iteration.
if loop d3; then run_bench BenchmarkPvbFlatFiles plutigo; fi
# Eval only: same testing.B settings, the program is decoded before timing.
if loop eval; then run_bench BenchmarkPvbEval plutigo-eval; fi

if loop check; then run_check || echo "WARNING: plutigo check failed" >&2; fi
