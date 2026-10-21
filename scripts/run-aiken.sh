#!/bin/bash
# aiken: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-aiken.sh <results-dir>
#
# Times the scripts in $BENCH_DATA_DIR (5 with BENCH_QUICK=1). The check covers every script of
# the corpus, also with BENCH_QUICK=1, so the gate always sees all of them.
set -uo pipefail

VM=aiken
RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
CHECK_DATA_DIR=/bench/data/plutus_use_cases
RAW="$RUN_DIR/$VM-raw.log"
export CRITERION_HOME=/tmp/criterion

{
    echo "aiken uplc (Rust / Criterion) aiken-lang/aiken@${AIKEN_SHA:-unknown}"
    echo "BENCH_QUICK=${BENCH_QUICK:-0}"
} | tee "$RAW"

# Correctness: one evaluation per script of the whole corpus.
BENCH_QUICK=0 DATA_DIR="$CHECK_DATA_DIR" aiken-check > "$RUN_DIR/$VM-check.csv" 2> >(tee -a "$RAW" >&2)

# Timing, twice with the same Criterion settings: flat decode + eval per iteration (aiken.csv, the
# D3 ranking), then eval of a program decoded once before timing (PVB_EVAL_ONLY=1, aiken-eval.csv).
# A crash of the bench binary must not kill the run: missing scripts become -1 rows below.
#
#   time_loop <csv> <raw log> [VAR=value ...]
time_loop() {
    local csv="$1" raw="$2"
    shift 2
    rm -rf "$CRITERION_HOME"
    env "$@" DATA_DIR="$DATA_DIR" aiken-bench --bench 2>&1 | tee -a "$raw" || true

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

time_loop "$RUN_DIR/$VM.csv" "$RAW"
: > "$RUN_DIR/$VM-eval-raw.log"
time_loop "$RUN_DIR/$VM-eval.csv" "$RUN_DIR/$VM-eval-raw.log" PVB_EVAL_ONLY=1
