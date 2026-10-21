#!/usr/bin/env bash
# Drive a benchmark run on a bench server that scripts/hetzner/up.sh created.
#
#   scripts/hetzner/run-remote.sh start   <run-id> <results-name> [vm ...]
#   scripts/hetzner/run-remote.sh status  <run-id>     # prints running | done:<exit code>
#   scripts/hetzner/run-remote.sh collect <run-id> <results-name>
#
# `start` copies the checked-out files (git archive HEAD) to the server and starts
# scripts/run-images.sh there as a detached systemd unit, so the run outlives the SSH session
# and the 6 h limit of a GitHub-hosted job. `collect` copies results/<name>, docs/index.html and
# the run log back into this checkout. BENCH_QUICK=1 is passed through.
set -euo pipefail

CMD="${1:?usage: run-remote.sh start|status|collect <run-id> ...}"
RUN_ID="${2:?run id missing}"
STATE="${BENCH_STATE:-${TMPDIR:-/tmp}/bench-hetzner}/$RUN_ID"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IP="$(cat "$STATE/ip")"
SSH=(ssh -i "$STATE/id_ed25519" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR -o ConnectTimeout=20 -o ServerAliveInterval=30 "root@$IP")
DONE=/var/lib/bench/done

case "$CMD" in
  start)
    NAME="${3:?results name missing}"
    shift 3
    VMS="$*"
    git -C "$REPO_ROOT" archive --format=tar HEAD \
      | "${SSH[@]}" 'rm -rf /root/repo && mkdir -p /root/repo && tar x -C /root/repo'
    # One string for the remote shell; VMS and NAME are plain words (no quotes needed).
    "${SSH[@]}" "rm -f $DONE && systemd-run --unit=pvb-bench --collect \
      --working-directory=/root/repo \
      --setenv=PULL=1 --setenv=IMAGE_TAG=auto \
      --setenv=BENCH_QUICK=${BENCH_QUICK:-0} \
      --setenv=PVB_HARNESS=$(git -C "$REPO_ROOT" rev-parse --short HEAD) \
      bash -c 'scripts/run-images.sh results/$NAME $VMS > /root/run.log 2>&1; echo \$? > $DONE'"
    echo "started run $NAME on $IP"
    ;;
  status)
    "${SSH[@]}" "if [ -f $DONE ]; then echo done:\$(cat $DONE); else echo running; fi; tail -n 3 /root/run.log >&2 || true"
    ;;
  collect)
    NAME="${3:?results name missing}"
    mkdir -p "$REPO_ROOT/results"
    "${SSH[@]}" "tar c -C /root/repo results/$NAME docs/index.html -C /root run.log" \
      | tar x -C "$REPO_ROOT"
    mv "$REPO_ROOT/run.log" "$REPO_ROOT/results/$NAME/run.log"
    echo "collected results/$NAME"
    ;;
  *)
    echo "unknown command $CMD" >&2
    exit 1
    ;;
esac
