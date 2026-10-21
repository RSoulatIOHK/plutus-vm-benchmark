#!/bin/bash
# Runs the scalus-js benchmark and check; see docs/IMAGE_CONTRACT.md.
set -uo pipefail

VM=scalus-js
DATA_DIR="${DATA_DIR:-/bench/data/plutus_use_cases}"
OUT="${RESULTS_DIR:-/results}"
if [ "${BENCH_QUICK:-0}" = "1" ]; then
    # Quick mode: the first 5 scripts by name, for the bench, the check and fill_failures alike.
    QUICK_DIR=$(mktemp -d)
    ls "$DATA_DIR"/*.flat | sort | head -n 5 | xargs -I{} ln -s {} "$QUICK_DIR/"
    DATA_DIR="$QUICK_DIR"
fi
export DATA_DIR

cd /bench/scalus-js
echo "scalus-js (Scala.js / Node.js $(node --version) / V8), scalus $(node -p 'require("./node_modules/scalus/package.json").version')" \
    | tee "$OUT/$VM-raw.log"

npx vitest bench --run 2>&1 | tee -a "$OUT/$VM-raw.log"

python3 /bench/parsers/parse_vitest.py "$VM" "$OUT/$VM-raw.log" > "$OUT/$VM.csv"
python3 /bench/parsers/fill_failures.py "$OUT/$VM.csv" "$DATA_DIR" "$VM" "$OUT/$VM-raw.log"

node check.mjs > "$OUT/$VM-check.csv" 2> >(tee -a "$OUT/$VM-raw.log" >&2)

# Exit non-zero only when the VM could not run at all: no timing and no check row.
timed=$(awk -F, 'NR > 1 && $3 != -1' "$OUT/$VM.csv" | wc -l)
checked=$(awk -F, 'NR > 1 && $3 == "ok"' "$OUT/$VM-check.csv" | wc -l)
echo "$VM: $timed scripts timed, $checked scripts ok in the check"
[ "$timed" -gt 0 ] || [ "$checked" -gt 0 ]
