#!/usr/bin/env bash
# Drive a benchmark run on a bench server that scripts/hetzner/up.sh created.
#
#   scripts/hetzner/run-remote.sh start   <run-id> <results-name> [vm ...]
#   scripts/hetzner/run-remote.sh status  <run-id>     # prints running | done:<exit code>
#   scripts/hetzner/run-remote.sh collect <run-id> <results-name>
#
# `start` copies the checked-out files (git archive HEAD) to the server and starts
# scripts/run-images.sh there as a detached systemd unit, so the run outlives the SSH session
# and the 6 h limit of a GitHub-hosted job. `collect` copies results/<name> and
# the run log back into this checkout. BENCH_SCRIPTS, BENCH_LOOPS, BENCH_TIMING, BENCH_QUICK,
# BENCH_TRACE and LANES are passed through (scripts/run-images.sh).
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
    # One string for the remote shell; VMS and NAME are plain words (no quotes needed). The
    # switches can hold regex characters (BENCH_SCRIPTS='auction_.*|uniswap-1'): quote them with %q.
    # A transient unit gets a minimal PATH on NixOS (no bash, docker, git): give it the system one.
    SCRIPTS_Q=$(printf %q "${BENCH_SCRIPTS:-}")
    LOOPS_Q=$(printf %q "${BENCH_LOOPS:-d3,eval,check}")
    TIMING_Q=$(printf %q "${BENCH_TIMING:-normal}")
    TRACE_Q=$(printf %q "${BENCH_TRACE:-0}")
    LANES_Q=$(printf %q "${LANES:-1}")
    "${SSH[@]}" "rm -f $DONE /root/progress.txt && : > /root/progress.txt && systemd-run --unit=pvb-bench --collect \
      --working-directory=/root/repo \
      --setenv=PATH=/run/current-system/sw/bin \
      --setenv=PULL=1 --setenv=IMAGE_TAG=auto \
      --setenv=PVB_PROGRESS=/root/progress.txt \
      --setenv=BENCH_QUICK=${BENCH_QUICK:-0} \
      --setenv=BENCH_SCRIPTS=$SCRIPTS_Q \
      --setenv=BENCH_LOOPS=$LOOPS_Q \
      --setenv=BENCH_TIMING=$TIMING_Q \
      --setenv=BENCH_TRACE=$TRACE_Q \
      --setenv=LANES=$LANES_Q \
      --setenv=PVB_HARNESS=$(git -C "$REPO_ROOT" rev-parse HEAD) \
      /run/current-system/sw/bin/bash -c 'scripts/run-images.sh results/$NAME $VMS > /root/run.log 2>&1; echo \$? > $DONE'"
    echo "started run $NAME on $IP"
    ;;
  status)
    # stdout: the state the wait job acts on. stderr (shown in the job log): the last 2 progress
    # lines, or the end of run.log before the first VM starts.
    "${SSH[@]}" "if [ -f $DONE ]; then echo done:\$(cat $DONE); else echo running; fi; \
      if [ -s /root/progress.txt ]; then tail -n 2 /root/progress.txt; else tail -n 3 /root/run.log; fi >&2 || true"
    ;;
  collect)
    NAME="${3:?results name missing}"
    mkdir -p "$REPO_ROOT/results"
    "${SSH[@]}" "tar c -C /root/repo results/$NAME -C /root run.log progress.txt" \
      | tar x -C "$REPO_ROOT"
    mv "$REPO_ROOT/run.log" "$REPO_ROOT/results/$NAME/run.log"
    mv "$REPO_ROOT/progress.txt" "$REPO_ROOT/results/$NAME/progress.txt"
    echo "collected results/$NAME"
    ;;
  *)
    echo "unknown command $CMD" >&2
    exit 1
    ;;
esac
