#!/bin/bash
# Runs the aiken timing and check per docs/IMAGE_CONTRACT.md.
set -euo pipefail

VM=aiken
RESULTS=/results
DATA_DIR=/bench/data/plutus_use_cases
export DATA_DIR
export CRITERION_HOME=/tmp/criterion

mkdir -p "$RESULTS"
RAW="$RESULTS/$VM-raw.log"

if ! ls "$DATA_DIR"/*.flat >/dev/null 2>&1; then
    echo "ERROR: no .flat files in $DATA_DIR" >&2
    exit 1
fi

{
    echo "aiken uplc (Rust / Criterion) aiken-lang/aiken@${AIKEN_SHA:-unknown}"
    echo "BENCH_QUICK=${BENCH_QUICK:-0}"
} | tee "$RAW"

# Correctness: one evaluation per script.
aiken-check > "$RESULTS/$VM-check.csv" 2> >(tee -a "$RAW" >&2)

# Timing. A crash of the bench binary must not kill the run: missing scripts
# become -1 rows below.
rm -rf "$CRITERION_HOME"
aiken-bench --bench 2>&1 | tee -a "$RAW" || true

FAILED=$(grep '^EVAL_FAIL:' "$RAW" | sed 's/^EVAL_FAIL: //; s/ .*//' | sort -u || true)

python3 /bench/parsers/parse_criterion.py "$CRITERION_HOME" "$VM" > "$RESULTS/$VM.csv.tmp"
FAILED="$FAILED" python3 - "$RESULTS/$VM.csv.tmp" "$RESULTS/$VM.csv" "$VM" <<'PY'
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
rm -f "$RESULTS/$VM.csv.tmp"

# In quick mode only 5 scripts run; do not pad the other 84 with -1 rows.
if [[ "${BENCH_QUICK:-0}" != "1" ]]; then
    python3 /bench/parsers/fill_failures.py "$RESULTS/$VM.csv" "$DATA_DIR" "$VM" "$RAW"
fi
