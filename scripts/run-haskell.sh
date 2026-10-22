#!/bin/bash
# Haskell row (docs/IMAGE_CONTRACT.md): pvb-bench from images/haskell/pvb-bench.
# Mainnet PlutusV3 cost model, protocol version 11, counting mode (spec D3, D11).
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts.
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
BENCH_DIR="/bench/haskell"
COST_MODEL="$BENCH_DIR/mainnet-plutusv3-costmodel.json"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }

echo "plutus-core (Haskell / GHC / Criterion)"

# RTS options (spec D16): the GC and heap options of the cardano-node executable.
# cardano-node 11.0.1 (97036a6, plutus 1.63.0.0, GHC 9.6.7 from nix/haskell.nix:45) links with
# -threaded and sets, on x86_64 and aarch64 (cardano-node/cardano-node.cabal:220-226):
#   -with-rtsopts=-T -I0 -A16m -qg1 -qb1 -N2 --disable-delayed-os-memory-return
# (unchanged in 11.1.3). pvb-bench is not threaded: the benchmark is one Haskell thread, and the
# Plutus `validation` benchmark is not threaded either. So we use the options that act on a single
# thread: -A16m (16 MB nursery: fewer minor GCs, the option that changes the timing), -T (RTS
# statistics, as the node collects them), -I0 (no idle GC) and --disable-delayed-os-memory-return.
# -N2 -qg1 -qb1 need the threaded RTS (the non-threaded RTS rejects them). In the node they give a
# second capability for other node threads and run only the major GC in parallel on 2 threads.
# Running the literal node set needs -threaded in pvb-bench.cabal and a rebuild.
RTS=(+RTS -T -I0 -A16m --disable-delayed-os-memory-return -RTS)

# Each script runs for about 5 s per loop (Criterion's warm-up, then its default time limit of 5 s,
# set in Main.hs; spec D13). Two loops: flat decode + evaluation (Criterion group d3, haskell.csv,
# spec D3) and evaluation of a program decoded once (group eval, haskell-eval.csv).
TIMING=()
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    TIMING=(-L 1)
fi

# Check (spec D4): one evaluation per script with the same parameters as the timed loop.
if loop check; then
    "$BENCH_DIR/bin/pvb-bench" check "$COST_MODEL" "$DATA_DIR" "${RTS[@]}" > "$RUN_DIR/haskell-check.csv"
fi

# The timed loops. One process per script (spec D14), so no heap or GC state carries from one
# script to the next. The process runs the requested loops of its script, d3 first, then eval
# (Main.hs). It gets a data dir with only its script, because pvb-bench evaluates every file of its
# data dir once before timing; the Criterion name filter (--match glob <group>/<name>) selects the
# loops. Criterion appends every process's results to one CSV; each process writes its own JSON
# report. A failed script gets a -1 row.
time_loops() {
    local raw="$RUN_DIR/haskell-raw.log" criterion="$RUN_DIR/haskell-criterion.csv" reports="$RUN_DIR/haskell-criterion"
    # Clean any leftover from aborted runs (Criterion appends, causing duplicate headers)
    rm -rf "$criterion" "$reports"
    mkdir -p "$reports"
    : > "$raw"
    echo "RTS options: ${RTS[*]}" | tee -a "$raw"
    local work flat name loops=()
    if loop d3; then loops+=(d3); fi
    if loop eval; then loops+=(eval); fi
    work=$(mktemp -d /tmp/haskell-one.XXXXXX)
    for flat in "$DATA_DIR"/*.flat; do
        name=$(basename "$flat" .flat)
        mkdir -p "$work/$name"
        ln -sf "$flat" "$work/$name/"
        # $BASHPID is the pid of the subshell, which exec turns into the benchmark process.
        ( echo "--- $name: process $BASHPID"
          exec "$BENCH_DIR/bin/pvb-bench" bench "$COST_MODEL" "$work/$name" \
              --csv "$criterion" --json "$reports/$name.json" ${TIMING[@]+"${TIMING[@]}"} \
              --match glob "${loops[@]/%//$name}" "${RTS[@]}" ) 2>&1 | tee -a "$raw" || true
    done
    rm -rf "$work"
    local l out
    for l in "${loops[@]}"; do
        out="$RUN_DIR/haskell.csv"
        [[ "$l" == eval ]] && out="$RUN_DIR/haskell-eval.csv"
        python3 /bench/parsers/parse_criterion_hs.py --group "$l" "$criterion" "$reports"/*.json > "$out" || true
        python3 /bench/parsers/fill_failures.py "$out" "$DATA_DIR" haskell "$raw" --loop "$l"
    done
}

# D3: flat decode + evaluation per iteration. Eval only: same Criterion settings.
if loop d3 || loop eval; then time_loops; fi
