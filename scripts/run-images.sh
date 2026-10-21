#!/usr/bin/env bash
# Runs the per-VM images one at a time (docs/IMAGE_CONTRACT.md), then builds unified.csv, runs
# the correctness gate (gate.json) and builds the report. This is what the bench server runs.
#
#   scripts/run-images.sh <results-dir> [vm ...]
#
# VMs are space- or comma-separated; the default is every VM in images/ (scripts/images.sh list).
#
# Environment:
#   IMAGE_PREFIX   image name prefix                 (default ghcr.io/lantr-io/pvb-)
#   IMAGE_TAG      tag to run                        (default latest)
#   PULL=1         docker pull each image first      (default 0: use local images)
#   BENCH_QUICK=1  passed to the images: first 5 scripts, short timing
#   DATA_DIR       corpus dir with plutus_use_cases/ (default <repo>/data)
#
# A VM that fails does not stop the run; the exit code is non-zero if any VM failed to run.
# A VM that fails the gate is hidden in the report; it does not change the exit code.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_PREFIX="${IMAGE_PREFIX:-ghcr.io/lantr-io/pvb-}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
PULL="${PULL:-0}"
BENCH_QUICK="${BENCH_QUICK:-0}"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/data}"
PYTHON_IMAGE="python:3.12-slim"

[[ $# -ge 1 ]] || { echo "usage: $0 <results-dir> [vm ...]" >&2; exit 1; }
mkdir -p "$1"
RUN_DIR="$(cd "$1" && pwd)"
shift
DATA_DIR="$(cd "$DATA_DIR" && pwd)"

VMS=$(echo "$*" | tr ',' ' ')
[[ -n "${VMS// /}" ]] || VMS=$("$REPO_ROOT/scripts/images.sh" list)

# --- environment.txt: hardware, software, images ---------------------------------------
{
    echo "date: $(date -Iseconds 2>/dev/null || date)"
    echo "kernel: $(uname -sr)"
    if [[ -r /proc/cpuinfo ]]; then
        echo "cpu: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
        echo "cores: $(nproc)"
        echo "memory: $(free -h | awk '/Mem:/ {print $2}')"
    else
        echo "cpu: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m)"
        echo "cores: $(sysctl -n hw.ncpu 2>/dev/null || echo unknown)"
        echo "memory: $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))G"
    fi
    echo "docker: $(docker version --format '{{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})' 2>/dev/null || echo unknown)"
    echo "docker cpus: $(docker info --format '{{.NCPU}}' 2>/dev/null || echo unknown)"
    echo "docker memory: $(( $(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0) / 1048576 )) MiB"
    echo "harness: $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "bench_quick: $BENCH_QUICK"
} > "$RUN_DIR/environment.txt"
cat "$RUN_DIR/environment.txt"

# --- run each VM ------------------------------------------------------------------------
FAILED=""
for vm in $VMS; do
    image="${IMAGE_PREFIX}${vm}:${IMAGE_TAG}"
    echo ""
    echo "---------------------------------------------"
    echo " ${vm}: ${image}"
    echo "---------------------------------------------"

    if [[ "$PULL" == 1 ]] && ! docker pull -q "$image" && ! docker pull -q "$image"; then
        echo "FAIL: ${vm}: cannot pull ${image}"
        FAILED="$FAILED $vm"
        echo "image ${vm}: ${image} (pull failed)" >> "$RUN_DIR/environment.txt"
        continue
    fi
    digest=$(docker image inspect --format '{{if .RepoDigests}}{{index .RepoDigests 0}}{{else}}{{.Id}}{{end}}' "$image" 2>/dev/null || echo missing)
    echo "image ${vm}: ${image} ${digest}" >> "$RUN_DIR/environment.txt"

    start=$(date +%s)
    if docker run --rm --cap-add SYS_NICE \
        -e BENCH_QUICK="$BENCH_QUICK" \
        -v "$DATA_DIR:/bench/data:ro" \
        -v "$RUN_DIR:/results" \
        "$image"; then
        echo "OK: ${vm} in $(( $(date +%s) - start )) s"
    else
        echo "FAIL: ${vm} exited with $? after $(( $(date +%s) - start )) s"
        FAILED="$FAILED $vm"
    fi
done

# --- unified.csv, gate, report ----------------------------------------------------------
echo ""
echo "---------------------------------------------"
echo " Normalizing results"
echo "---------------------------------------------"

# The images run as root. On a Linux host, give the results back to the calling user.
if [[ "$(uname -s)" == Linux && "$(id -u)" != 0 ]]; then
    docker run --rm -v "$RUN_DIR:/run-dir" "$PYTHON_IMAGE" chown -R "$(id -u):$(id -g)" /run-dir
fi

# The parsers need Python >= 3.10. Use the host's when it is new enough, else a container.
# PY runs python3; ROOT and RUN are the repo and the run dir as PY sees them.
if python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null; then
    PY=(python3)
    ROOT="$REPO_ROOT"
    RUN="$RUN_DIR"
else
    # Keep the run dir's name: the report uses it as the run date. Mount the parent dir, so the
    # report sees the earlier runs next to this one (history chart).
    ROOT=/repo
    RUN="/runs/$(basename "$RUN_DIR")"
    PY=(docker run --rm --user "$(id -u):$(id -g)" \
        -v "$REPO_ROOT:/repo" -v "$(dirname "$RUN_DIR"):/runs" "$PYTHON_IMAGE" python3)
fi

"${PY[@]}" "$ROOT/parsers/normalize.py" "$RUN"

# --- correctness gate (check/README.md) -------------------------------------------------
# Every <vm>-check.csv against the Haskell reference; the mode per VM comes from
# check/modes.conf. The verdicts go to gate.json, which the report reads: a VM that fails is
# hidden. A gate failure does not stop the report.
echo ""
echo "---------------------------------------------"
echo " Correctness gate"
echo "---------------------------------------------"
CHECKS=()
for f in "$RUN_DIR"/*-check.csv; do
    [[ -f "$f" ]] && CHECKS+=("$RUN/$(basename "$f")")
done
MODES=()
while read -r vm mode _; do
    [[ -z "$vm" || "$vm" == \#* ]] && continue
    # gate.py rejects a mode for a VM without a check file.
    [[ -f "$RUN_DIR/$vm-check.csv" ]] || continue
    [[ -n "$mode" ]] || mode=strict
    case "$mode" in
        badge:*) MODES+=(--mode "$vm=badge:$ROOT/${mode#badge:}") ;;
        *) MODES+=(--mode "$vm=$mode") ;;
    esac
done < "$REPO_ROOT/check/modes.conf"
GATE_FAILED=""
if [[ ${#CHECKS[@]} -eq 0 ]]; then
    echo "WARNING: no <vm>-check.csv in $RUN_DIR; every VM counts as failed check"
    echo '{"reference": null, "ok": false, "vms": {}}' > "$RUN_DIR/gate.json"
    GATE_FAILED=1
else
    gate_rc=0
    "${PY[@]}" "$ROOT/check/gate.py" --reference "$ROOT/check/reference/haskell-check.csv" \
        --json "$RUN/gate.json" ${MODES[@]+"${MODES[@]}"} "${CHECKS[@]}" || gate_rc=$?
    if [[ $gate_rc -eq 2 || ! -f "$RUN_DIR/gate.json" ]]; then
        echo "WARNING: the gate could not read its input (exit $gate_rc); every VM counts as failed check"
        echo '{"reference": null, "ok": false, "vms": {}}' > "$RUN_DIR/gate.json"
        GATE_FAILED=1
    elif [[ $gate_rc -ne 0 ]]; then
        GATE_FAILED=1
    fi
fi

# --- report -----------------------------------------------------------------------------
# generate_report.py also writes <repo>/docs/index.html.
"${PY[@]}" "$ROOT/report/generate_report.py" "$RUN"

echo ""
echo "Results: $RUN_DIR"
if [[ -n "$GATE_FAILED" ]]; then
    echo "Gate: at least one VM failed the check (gate.json); its row is hidden in the report"
fi
if [[ -n "$FAILED" ]]; then
    echo "Failed VMs:$FAILED"
    exit 1
fi
