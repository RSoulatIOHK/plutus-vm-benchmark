#!/usr/bin/env bash
# Create a bench server (up.sh) and keep it only if it is not slow (qualify.sh). Hetzner servers of
# one type differ: one ccx43 ran every VM 2.1x slower than another. A server more than 15 % slower
# than the reference of its type is deleted and a new one is created, up to QUALIFY_ATTEMPTS
# (default 3) servers. Each new attempt starts at the next location of BENCH_LOCATIONS.
#
#   HCLOUD_TOKEN=... scripts/hetzner/up-qualified.sh <run-id>
#
# Writes to $BENCH_STATE/<run-id>/:
#   qualify.txt         one line for environment.txt (run-remote.sh passes it as PVB_QUALIFY)
#   qualify-summary.md  the attempts, for the job summary
# Exit 0: a server passed (or there is no reference for the type: qualification skipped).
# Exit 1: no server passed, or a step failed. The last server is deleted only when it was too slow.
#
# Tests replace the steps: UP_CMD, DOWN_CMD and QUALIFY_CMD (each gets the run id).
set -euo pipefail

RUN_ID="${1:?usage: up-qualified.sh <run-id>}"
SERVER_TYPE="${BENCH_SERVER_TYPE:-ccx43}"
export BENCH_SERVER_TYPE="$SERVER_TYPE"
STATE="${BENCH_STATE:-${TMPDIR:-/tmp}/bench-hetzner}/$RUN_ID"
DIR="$(cd "$(dirname "$0")" && pwd)"
UP_CMD="${UP_CMD:-$DIR/up.sh}"
DOWN_CMD="${DOWN_CMD:-$DIR/down.sh}"
QUALIFY_CMD="${QUALIFY_CMD:-$DIR/qualify.sh}"
ATTEMPTS="${QUALIFY_ATTEMPTS:-3}"
read -r -a LOCS <<< "${BENCH_LOCATIONS:-nbg1 fsn1 hel1}"

mkdir -p "$STATE"
OUT="$STATE/qualify.txt"
SUMMARY="$STATE/qualify-summary.md"
rm -f "$OUT"
{
  echo "### Server qualification ($SERVER_TYPE)"
  echo ""
  echo "| attempt | location | ip | result |"
  echo "|---|---|---|---|"
} > "$SUMMARY"

rejected=""
for attempt in $(seq 1 "$ATTEMPTS"); do
  # Rotate the locations: attempt 2 tries the second location first, and so on.
  shift_by=$(( (attempt - 1) % ${#LOCS[@]} ))
  locs="${LOCS[*]:$shift_by} ${LOCS[*]:0:$shift_by}"
  BENCH_LOCATIONS="$(echo "$locs" | xargs)" "$UP_CMD" "$RUN_ID" > /dev/null
  loc="$(cat "$STATE/location" 2>/dev/null || echo unknown)"
  ip="$(cat "$STATE/ip" 2>/dev/null || echo unknown)"
  rc=0
  line="$("$QUALIFY_CMD" "$RUN_ID")" || rc=$?
  echo "attempt $attempt ($loc, $ip): $line" >&2
  # line = "<verdict> <ratio> <text>"
  ratio="$(echo "$line" | awk '{print $2}')"
  text="$(echo "$line" | cut -d' ' -f3-)"
  echo "| $attempt | $loc | $ip | ${line%% *}: $text |" >> "$SUMMARY"
  case $rc in
    0)
      echo "pass, ratio $ratio, attempt $attempt of $ATTEMPTS, $loc; rejected:${rejected:- none}; $text" > "$OUT"
      cat "$OUT" >&2
      exit 0 ;;
    2)
      echo "skipped, $text" > "$OUT"
      echo "::warning::server qualification skipped: $text"
      exit 0 ;;
    1)
      rejected="$rejected $loc $ip ratio $ratio;"
      "$DOWN_CMD" "$RUN_ID" ;;
    *)
      echo "error, attempt $attempt, $loc: $text" > "$OUT"
      echo "::error::server qualification failed to measure: $line"
      exit 1 ;;
  esac
done
echo "fail, $ATTEMPTS servers were too slow (more than 15 % over the reference); rejected:$rejected" > "$OUT"
echo "::error::no $SERVER_TYPE server passed the qualification in $ATTEMPTS attempts:$rejected (Hetzner gave slow hosts; try again later or check check/reference/host-reference.json)"
exit 1
