#!/usr/bin/env bash
# Time the Haskell image on a new bench server and compare it with the stored reference of the
# server type (check/reference/host-reference.json, scripts/hetzner/qualify.py).
#
#   scripts/hetzner/qualify.sh <run-id>
#
# Runs scripts/run-images.sh on the server with the docker flags, CPU set and host confinement of
# the real run: haskell only, the scripts of QUALIFY_SCRIPTS, d3 loop, normal timing, the run's
# lane count (the first value of a comma list). Copies haskell.csv to $BENCH_STATE/<run-id>/.
# Prints one line "<verdict> <ratio> <text>"; the exit code is the one of qualify.py decide
# (0 pass, 1 too slow, 2 no reference, 3 no timing).
set -euo pipefail

RUN_ID="${1:?usage: qualify.sh <run-id>}"
SERVER_TYPE="${BENCH_SERVER_TYPE:-ccx43}"
STATE="${BENCH_STATE:-${TMPDIR:-/tmp}/bench-hetzner}/$RUN_ID"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
QUALIFY_SCRIPTS="${QUALIFY_SCRIPTS:-auction_1-1|coop-6|uniswap-1}"
IP="$(cat "$STATE/ip")"
SSH=(ssh -i "$STATE/id_ed25519" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR -o ConnectTimeout=20 -o ServerAliveInterval=30 "root@$IP")
LANES_FIRST="${LANES:-1}"
LANES_FIRST="${LANES_FIRST%%,*}"

git -C "$REPO_ROOT" archive --format=tar HEAD \
  | "${SSH[@]}" 'rm -rf /root/repo && mkdir -p /root/repo && tar x -C /root/repo'
# The exit code of run-images.sh does not matter: haskell.csv has the timing or it does not.
"${SSH[@]}" "rm -rf /root/qualify && mkdir -p /root/qualify && cd /root/repo && \
  PULL=1 IMAGE_TAG=auto PVB_CONFINE_HOST=1 DRIFT=0 BENCH_QUICK=0 BENCH_TRACE=0 \
  BENCH_SCRIPTS=$(printf %q "$QUALIFY_SCRIPTS") BENCH_LOOPS=d3 BENCH_TIMING=normal \
  LANES=$(printf %q "$LANES_FIRST") PVB_PROGRESS=/root/qualify/progress.txt \
  scripts/run-images.sh /root/qualify/haskell haskell > /root/qualify/run.log 2>&1" || true
rm -f "$STATE/qualify-haskell.csv"
"${SSH[@]}" 'cat /root/qualify/haskell/haskell.csv' > "$STATE/qualify-haskell.csv" 2>/dev/null || true
rc=0
python3 "$REPO_ROOT/scripts/hetzner/qualify.py" decide "$STATE/qualify-haskell.csv" "$SERVER_TYPE" || rc=$?
if [[ $rc -eq 3 ]]; then
  echo "the qualification run gave no timing; the end of its log:" >&2
  "${SSH[@]}" 'tail -n 30 /root/qualify/run.log' >&2 || true
fi
exit $rc
