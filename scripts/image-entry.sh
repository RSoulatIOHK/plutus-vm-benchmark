#!/bin/bash
# Default command of every VM image (docs/IMAGE_CONTRACT.md).
#
#   image-entry.sh [vm]      vm defaults to $PVB_VM, which each Dockerfile sets
#
# Reads /bench/data/plutus_use_cases/*.flat, runs /bench/scripts/run-<vm>.sh, which writes the
# files of the requested loops to /results.
#
# Switches (environment, docs/IMAGE_CONTRACT.md):
#   BENCH_SCRIPTS  extended regex, full match against the script name; empty = every script
#   BENCH_LOOPS    comma list of d3, eval, check            (default d3,eval,check)
#   BENCH_TIMING   normal | quick                           (default normal)
#   BENCH_QUICK=1  shortcut: BENCH_TIMING=quick and, when BENCH_SCRIPTS is empty, the first 5
#                  scripts (C sort order)
# The run script gets the selected scripts in $BENCH_DATA_DIR, and BENCH_LOOPS and BENCH_TIMING.
# A run script declares the loops it has in a header line "# pvb-loops: d3 eval check".
#
# Exit code: 2 on bad switches or no matching script. Else 0 when every requested loop the VM has
# wrote its file, the timing files have at least one timed row, and the check file (if requested)
# has at least one row. Non-zero means the VM could not run at all; a single failed script is a
# row with an error, not a failed container.
set -uo pipefail

VM="${1:-${PVB_VM:?set PVB_VM or pass the VM name}}"
RESULTS_DIR=/results
DATA_SRC=/bench/data/plutus_use_cases
RUN_SCRIPT="/bench/scripts/run-${VM}.sh"

mkdir -p "$RESULTS_DIR"

if ! compgen -G "$DATA_SRC/*.flat" >/dev/null; then
    echo "ERROR: no .flat files in $DATA_SRC. Mount the corpus: -v \"\$PWD/data:/bench/data:ro\"" >&2
    exit 2
fi

# --- switches ---------------------------------------------------------------------------
BENCH_QUICK="${BENCH_QUICK:-0}"
BENCH_SCRIPTS="${BENCH_SCRIPTS:-}"
BENCH_LOOPS="${BENCH_LOOPS:-d3,eval,check}"
BENCH_TIMING="${BENCH_TIMING:-normal}"
[[ "$BENCH_QUICK" == 1 ]] && BENCH_TIMING=quick

case "$BENCH_TIMING" in
    normal | quick) ;;
    *) echo "ERROR: BENCH_TIMING=$BENCH_TIMING: expected normal or quick" >&2; exit 2 ;;
esac

LOOPS=()
for loop in ${BENCH_LOOPS//,/ }; do
    case "$loop" in
        d3 | eval | check) LOOPS+=("$loop") ;;
        *) echo "ERROR: BENCH_LOOPS=$BENCH_LOOPS: unknown loop '$loop' (expected d3, eval, check)" >&2; exit 2 ;;
    esac
done
if [[ ${#LOOPS[@]} -eq 0 ]]; then
    echo "ERROR: BENCH_LOOPS is empty (expected a comma list of d3, eval, check)" >&2
    exit 2
fi
BENCH_LOOPS=$(IFS=,; echo "${LOOPS[*]}")

# --- script selection -------------------------------------------------------------------
# names <dir>: the script names of the .flat files in <dir>, C sort order.
names() { for f in "$1"/*.flat; do basename "$f" .flat; done | LC_ALL=C sort; }

if [[ -n "$BENCH_SCRIPTS" ]]; then
    # grep exits 1 for no match, 2 for a bad regex. scripts/run-images.sh selects the same way.
    rc=0
    matched=$(names "$DATA_SRC" | grep -E -- "^(${BENCH_SCRIPTS})\$") || rc=$?
    if [[ $rc -gt 1 ]]; then
        echo "ERROR: BENCH_SCRIPTS='$BENCH_SCRIPTS' is not a valid extended regex" >&2
        exit 2
    elif [[ -z "$matched" ]]; then
        echo "ERROR: BENCH_SCRIPTS='$BENCH_SCRIPTS' matches no script in $DATA_SRC" >&2
        exit 2
    fi
    BENCH_DATA_DIR=$(mktemp -d /tmp/pvb-data.XXXXXX)
    for name in $matched; do cp "$DATA_SRC/$name.flat" "$BENCH_DATA_DIR/"; done
elif [[ "$BENCH_QUICK" == 1 ]]; then
    BENCH_DATA_DIR=$(mktemp -d /tmp/pvb-data.XXXXXX)
    for name in $(names "$DATA_SRC" | head -5); do cp "$DATA_SRC/$name.flat" "$BENCH_DATA_DIR/"; done
else
    BENCH_DATA_DIR="$DATA_SRC"
fi
SELECTED=$(names "$BENCH_DATA_DIR")
echo "scripts ($(echo "$SELECTED" | wc -l | tr -d ' ')): $(echo "$SELECTED" | paste -sd' ' -)"
echo "loops: $BENCH_LOOPS, timing: $BENCH_TIMING"
unset BENCH_QUICK
export BENCH_DATA_DIR BENCH_LOOPS BENCH_TIMING

# --- the loops this VM has --------------------------------------------------------------
HAS=$(sed -n 's/^# pvb-loops:[[:space:]]*//p' "$RUN_SCRIPT" | head -1)
[[ -n "$HAS" ]] || HAS="d3 eval check"
RUN=()
for loop in "${LOOPS[@]}"; do
    if [[ " $HAS " == *" $loop "* ]]; then
        RUN+=("$loop")
    else
        echo "NOTE: ${VM} has no '$loop' loop; skipped"
    fi
done
if [[ ${#RUN[@]} -eq 0 ]]; then
    echo "=== ${VM}: none of the requested loops ($BENCH_LOOPS) exists for this VM; nothing to run"
    exit 0
fi

# Highest priority needs --cap-add SYS_NICE. Without it, run at normal priority.
NICE=()
if [[ -z "$(nice -n -20 true 2>&1)" ]]; then
    NICE=(nice -n -20)
else
    echo "WARNING: cannot raise priority (run the container with --cap-add SYS_NICE)" >&2
fi

echo "=== ${VM} ($(date -Iseconds), $(nproc) CPUs)"
start=$(date +%s)
${NICE[@]+"${NICE[@]}"} bash "$RUN_SCRIPT" "$RESULTS_DIR"
rc=$?
echo "=== ${VM}: run script exited with ${rc} after $(( $(date +%s) - start )) s"

# The VM ran if every requested loop wrote its file, at least one script has a timing (when a
# timing loop was requested), and the check has a row (when the check was requested).
python3 - "$RESULTS_DIR" "$VM" "${RUN[@]}" <<'EOF'
import csv, os, sys
results, vm, loops = sys.argv[1], sys.argv[2], sys.argv[3:]
files = {"d3": f"{vm}.csv", "eval": f"{vm}-eval.csv", "check": f"{vm}-check.csv"}
ok, timed = True, None
for loop in loops:
    path = os.path.join(results, files[loop])
    try:
        rows = list(csv.DictReader(open(path)))
    except FileNotFoundError:
        print(f"ERROR: {path} was not written", file=sys.stderr)
        ok = False
        continue
    if loop == "check":
        print(f"{path}: {len(rows)} scripts checked")
        ok = ok and len(rows) > 0
    else:
        n = sum(1 for r in rows if float(r["mean_ns"]) > 0)
        print(f"{path}: {n} of {len(rows)} scripts timed")
        timed = (timed or 0) + n
if timed == 0:
    print("ERROR: no script has a timing", file=sys.stderr)
    ok = False
sys.exit(0 if ok else 1)
EOF
