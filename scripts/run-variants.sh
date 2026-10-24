#!/usr/bin/env bash
# TEMPORARY (Scalus 1.4.1 preparation, revert after the run).
# Runs scripts/run-images.sh once per line of a variants file, on the same server, one pass after
# the other, so the passes compare without a server-to-server difference.
#
#   scripts/run-variants.sh <variants-file> <results-dir> [vm ...]
#
# A line of the file: <name> [KEY=VALUE ...]. The pass writes to <results-dir>/<name>. Allowed
# keys: SCALUS_BUILD (base or perf), SCALUS_JAVA, SCALUS_JVM_FLAGS (the Scalus build and JVM), BENCH_LOOPS, BENCH_SCRIPTS
# (override the run's switches; an empty value = every script) and VMS (a comma list instead of
# the given VMs). Values have no spaces. Blank lines and lines starting with # are skipped.
# Exit code: non-zero when a pass failed; every pass runs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="${1:?usage: run-variants.sh <variants-file> <results-dir> [vm ...]}"
OUT="${2:?results dir missing}"
shift 2
[[ -f "$FILE" ]] || { echo "ERROR: no variants file $FILE" >&2; exit 2; }

# Check every line before the first pass.
names=" "
while read -r name assignments; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    [[ "$name" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "ERROR: $FILE: bad variant name '$name'" >&2; exit 2; }
    [[ "$names" != *" $name "* ]] || { echo "ERROR: $FILE: variant '$name' twice" >&2; exit 2; }
    names="$names$name "
    for a in $assignments; do
        [[ "$a" =~ ^(SCALUS_BUILD|SCALUS_JAVA|SCALUS_JVM_FLAGS|BENCH_LOOPS|BENCH_SCRIPTS|VMS)=[^[:space:]]*$ ]] \
            || { echo "ERROR: $FILE: variant $name: '$a' is not KEY=VALUE with an allowed key" >&2; exit 2; }
    done
done < "$FILE"
[[ "$names" != " " ]] || { echo "ERROR: $FILE has no variant" >&2; exit 2; }

rc=0
while read -r name assignments; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    env_args=()
    vms="$*"
    for a in $assignments; do
        if [[ "$a" == VMS=* ]]; then vms="${a#VMS=}"; else env_args+=("$a"); fi
    done
    echo ""
    echo "============================================="
    echo " variant $name: ${env_args[*]:-} vms: $vms"
    echo "============================================="
    [[ -z "${PVB_PROGRESS:-}" ]] || echo "$(date -u +%H:%M) variant $name: ${env_args[*]:-}" >> "$PVB_PROGRESS"
    # shellcheck disable=SC2086
    env ${env_args[@]+"${env_args[@]}"} "$REPO_ROOT/scripts/run-images.sh" "$OUT/$name" $vms </dev/null || rc=$?
    # The first pass pulled every image (PULL=1 from run-remote.sh); the later ones use them.
    export PULL=0
    # A pass that died can leave containers running: never start the next pass beside them.
    while bench=$(docker ps --format '{{.Image}}' | grep -F "${IMAGE_PREFIX:-ghcr.io/lantr-io/pvb-}"); do
        echo "variant $name: waiting for running containers: $(echo "$bench" | paste -sd' ' -)"
        sleep 30
    done
done < "$FILE"
exit $rc
