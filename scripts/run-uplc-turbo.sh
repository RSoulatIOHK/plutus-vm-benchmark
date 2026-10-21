#!/bin/bash
# uplc-turbo: timing and check (docs/IMAGE_CONTRACT.md). Called by image-entry.sh.
#
#   run-uplc-turbo.sh <results-dir>
#
# pvb-loops: d3 eval check
# Runs the loops of $BENCH_LOOPS over the scripts in $BENCH_DATA_DIR; $BENCH_TIMING=quick shortens
# the timing. The check covers the same scripts.
set -euo pipefail

RUN_DIR="$1"
DATA_DIR="${BENCH_DATA_DIR:-/bench/data/plutus_use_cases}"
loop() { [[ ",${BENCH_LOOPS:-d3,eval,check}," == *",$1,"* ]]; }
BENCH_DIR="/bench/uplc-turbo"

echo "uplc-turbo AST (Rust / Criterion)"

# The bench binary is our harness (images/uplc-turbo/use_cases.rs): PlutusV3, protocol version 11,
# counting mode. Two Criterion loops with the same settings: flat decode + eval per iteration
# (uplc-turbo.csv) and, with PVB_EVAL_ONLY=1, eval of a program decoded once (uplc-turbo-eval.csv).
export PVB_COSTMODEL=/tmp/uplc-turbo-costmodel.txt
python3 -c "
import json, sys
values = json.load(open('/bench/mainnet-plutusv3-costmodel.json'))['PlutusV3']
open(sys.argv[1], 'w').write('\\n'.join(map(str, values)) + '\\n')
" "$PVB_COSTMODEL"

# Criterion flags override the measurement_time set in the harness's main().
TIMING=()
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    TIMING=(--warm-up-time 1 --measurement-time 1)
fi

# Symlink canonical flat files into expected location
rm -rf "$BENCH_DIR/crates/uplc/benches/use_cases/plutus_use_cases"
ln -sf "$DATA_DIR" "$BENCH_DIR/crates/uplc/benches/use_cases/plutus_use_cases"

# Binary expects benches/use_cases/plutus_use_cases relative to cwd
cd "$BENCH_DIR/crates/uplc"

# Run Criterion benchmark (binary already compiled in build stage)
BENCH_BIN=$(find "$BENCH_DIR/target/release/deps" -name 'use_cases-*' -type f ! -name '*.d' | head -1)
if [[ -z "$BENCH_BIN" ]]; then
    echo "ERROR: could not find use_cases benchmark binary" | tee "$RUN_DIR/uplc-turbo-raw.log"
    exit 1
fi

run_check() {
    # Spec D4: one evaluation per script with the timed loop's parameters.
    PVB_DATA_DIR="$DATA_DIR" PVB_CHECK_OUT="$RUN_DIR/uplc-turbo-check.csv" "$BENCH_BIN" 2>&1 \
        | tee "$RUN_DIR/uplc-turbo-check.log"
    echo "Wrote $RUN_DIR/uplc-turbo-check.csv"
}

# One Criterion loop: time_loop <csv> <raw log> <criterion copy dir> [VAR=value ...]
time_loop() {
    local csv="$1" raw="$2" copy="$3"
    shift 3

    # Clear previous criterion output to avoid stale results
    rm -rf target/criterion

    env "$@" UPLC_BENCH_MODE=ast "$BENCH_BIN" --bench ${TIMING[@]+"${TIMING[@]}"} 2>&1 | tee "$raw" || true

    # Collect failed scripts
    local failed
    failed=$(grep "^EVAL_FAIL:" "$raw" | sed 's/EVAL_FAIL: //' | sort -u || true)

    # Copy Criterion JSON output (remove old copy first to avoid cp -r nesting)
    rm -rf "$copy"
    cp -r target/criterion "$copy" 2>/dev/null || true

    # Parse criterion output, filtering out scripts that failed evaluation
    python3 /bench/parsers/parse_criterion.py "$copy" > "$csv.raw" || true

    # Filter: remove bogus timings for failed scripts, then add -1 entries
    FAILED="$failed" python3 - "$csv.raw" "$csv" <<'PY' || true
import os, sys
src, dst = sys.argv[1:3]
failed = set(os.environ.get("FAILED", "").split())
with open(src) as f:
    lines = f.readlines()
with open(dst, "w") as out:
    out.write(lines[0])  # header
    for line in lines[1:]:
        script = line.split(",")[1] if "," in line else ""
        if script not in failed:
            out.write(line)
    for script in sorted(failed):
        if script:
            out.write(f"uplc-turbo,{script},-1,-1,-1,-1,-1,0\n")
PY
    rm -f "$csv.raw"

    # Fill in -1 for any scripts that were given but produced no result
    python3 /bench/parsers/fill_failures.py "$csv" "$DATA_DIR" uplc-turbo "$raw"
}

if loop d3; then
    time_loop "$RUN_DIR/uplc-turbo.csv" "$RUN_DIR/uplc-turbo-raw.log" "$RUN_DIR/criterion-output-ast"
fi
if loop eval; then
    time_loop "$RUN_DIR/uplc-turbo-eval.csv" "$RUN_DIR/uplc-turbo-eval-raw.log" \
        "$RUN_DIR/criterion-output-eval" PVB_EVAL_ONLY=1
fi

if loop check; then run_check || echo "WARNING: uplc-turbo check failed" >&2; fi
