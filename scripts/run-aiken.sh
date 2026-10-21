#!/bin/bash
# aiken: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-aiken.sh <results-dir>
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts.
set -uo pipefail

VM=aiken
RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }
RAW="$RUN_DIR/$VM-raw.log"
export CRITERION_HOME=/tmp/criterion

{
    echo "aiken uplc (Rust / Criterion) aiken-lang/aiken@${AIKEN_SHA:-unknown}"
    echo "BENCH_LOOPS=${BENCH_LOOPS:-d3,eval,check} BENCH_TIMING=${BENCH_TIMING:-normal}"
} | tee "$RAW"

# Correctness: one evaluation per script.
if loop check; then
    DATA_DIR="$DATA_DIR" aiken-check > "$RUN_DIR/$VM-check.csv" 2> >(tee -a "$RAW" >&2)
fi

# Timing, twice with the same Criterion settings: flat decode + eval per iteration (aiken.csv, the
# D3 ranking), then eval of a program decoded once before timing (PVB_EVAL_ONLY=1, aiken-eval.csv).
# A crash of the bench binary must not kill the run: missing scripts become -1 rows below.
#
# Criterion settings (spec D13), the same as scripts/run-uplc-turbo.sh: Criterion.rs 0.7.0 with
# its default warm-up (3 s) and measurement time (5 s), 100 samples, no plots.
TIMING=(--warm-up-time 3 --measurement-time 5)
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    TIMING=(--warm-up-time 1 --measurement-time 1)
fi
echo "Criterion options: ${TIMING[*]} --noplot" | tee -a "$RAW"

# One process per script (spec D14), so no allocator state carries from one script to the next.
# The process gets a data dir with only its script, because aiken-bench evaluates every file of
# its data dir once before timing; the Criterion filter (--exact <name>) selects it too.
#
#   time_loop <csv> <raw log> [VAR=value ...]
time_loop() {
    local csv="$1" raw="$2"
    shift 2
    rm -rf "$CRITERION_HOME"
    local work flat name
    work=$(mktemp -d /tmp/aiken-one.XXXXXX)
    for flat in "$DATA_DIR"/*.flat; do
        name=$(basename "$flat" .flat)
        mkdir -p "$work/$name"
        ln -sf "$flat" "$work/$name/"
        # $BASHPID is the pid of the subshell, which exec turns into the benchmark process.
        ( echo "--- $name: process $BASHPID"
          exec env "$@" DATA_DIR="$work/$name" aiken-bench --bench --noplot "${TIMING[@]}" --exact "$name" ) \
            2>&1 | tee -a "$raw" || true
    done
    rm -rf "$work"

    local failed
    failed=$(grep '^EVAL_FAIL:' "$raw" | sed 's/^EVAL_FAIL: //; s/ .*//' | sort -u || true)

    python3 /bench/parsers/parse_criterion.py "$CRITERION_HOME" "$VM" > "$csv.tmp"
    FAILED="$failed" python3 - "$csv.tmp" "$csv" "$VM" <<'PY'
import os, sys
src, dst, vm = sys.argv[1:4]
failed = set(os.environ.get("FAILED", "").split())
with open(src) as f:
    lines = f.readlines()
with open(dst, "w") as out:
    out.write(lines[0])
    for line in lines[1:]:
        if line.split(",")[1] not in failed:
            out.write(line)
    for s in sorted(failed):
        out.write(f"{vm},{s},-1,-1,-1,-1,-1,0\n")
PY
    rm -f "$csv.tmp"
    python3 /bench/parsers/fill_failures.py "$csv" "$DATA_DIR" "$VM" "$raw"
}

if loop d3; then
    time_loop "$RUN_DIR/$VM.csv" "$RAW"
fi
if loop eval; then
    : > "$RUN_DIR/$VM-eval-raw.log"
    time_loop "$RUN_DIR/$VM-eval.csv" "$RUN_DIR/$VM-eval-raw.log" PVB_EVAL_ONLY=1
fi
