#!/bin/bash
# Default command of every VM image (docs/IMAGE_CONTRACT.md).
#
#   image-entry.sh [vm]      vm defaults to $PVB_VM, which each Dockerfile sets
#
# Reads /bench/data/plutus_use_cases/*.flat, runs /bench/scripts/run-<vm>.sh, which writes
# /results/<vm>.csv and /results/<vm>-raw.log. BENCH_QUICK=1 runs only the first 5 scripts
# (C sort order) with short timing.
#
# Exit code: 0 when at least one script has a timing. Non-zero only when the VM could not run
# at all (no data, or every row of <vm>.csv is a failure).
set -uo pipefail

VM="${1:-${PVB_VM:?set PVB_VM or pass the VM name}}"
RESULTS_DIR=/results
DATA_SRC=/bench/data/plutus_use_cases

mkdir -p "$RESULTS_DIR"

if ! compgen -G "$DATA_SRC/*.flat" >/dev/null; then
    echo "ERROR: no .flat files in $DATA_SRC. Mount the corpus: -v \"\$PWD/data:/bench/data:ro\"" >&2
    exit 2
fi

export BENCH_QUICK="${BENCH_QUICK:-0}"
if [[ "$BENCH_QUICK" == 1 ]]; then
    BENCH_DATA_DIR=$(mktemp -d /tmp/pvb-data.XXXXXX)
    find "$DATA_SRC" -maxdepth 1 -name '*.flat' | LC_ALL=C sort | head -5 \
        | while read -r f; do cp "$f" "$BENCH_DATA_DIR/"; done
    echo "BENCH_QUICK=1: $(ls "$BENCH_DATA_DIR" | tr '\n' ' ')"
else
    BENCH_DATA_DIR="$DATA_SRC"
fi
export BENCH_DATA_DIR

# Highest priority needs --cap-add SYS_NICE. Without it, run at normal priority.
NICE=()
if [[ -z "$(nice -n -20 true 2>&1)" ]]; then
    NICE=(nice -n -20)
else
    echo "WARNING: cannot raise priority (run the container with --cap-add SYS_NICE)" >&2
fi

echo "=== ${VM} ($(date -Iseconds), $(nproc) CPUs)"
start=$(date +%s)
${NICE[@]+"${NICE[@]}"} bash "/bench/scripts/run-${VM}.sh" "$RESULTS_DIR"
rc=$?
echo "=== ${VM}: run script exited with ${rc} after $(( $(date +%s) - start )) s"

# The VM ran if at least one script has a positive mean.
python3 - "$RESULTS_DIR/${VM}.csv" <<'EOF'
import csv, sys
path = sys.argv[1]
try:
    rows = list(csv.DictReader(open(path)))
except FileNotFoundError:
    print(f"ERROR: {path} was not written", file=sys.stderr)
    sys.exit(1)
ok = sum(1 for r in rows if float(r["mean_ns"]) > 0)
print(f"{path}: {ok} of {len(rows)} scripts timed")
sys.exit(0 if ok > 0 else 1)
EOF
