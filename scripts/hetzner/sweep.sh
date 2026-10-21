#!/usr/bin/env bash
# Delete every bench server and SSH key older than MAX_AGE_HOURS (default 16).
# Third cleanup layer, after the workflow's always() step and the server's self-destruct timer.
#
#   HCLOUD_TOKEN=... scripts/hetzner/sweep.sh
set -euo pipefail

MAX_AGE_HOURS="${MAX_AGE_HOURS:-16}"
: "${HCLOUD_TOKEN:?HCLOUD_TOKEN must be set}"
export HCLOUD_TOKEN
cutoff=$(( $(date +%s) - MAX_AGE_HOURS * 3600 ))

hcloud server list -l bench-run -o json \
  | jq -r --argjson cutoff "$cutoff" \
      '.[] | select((.labels.created | tonumber) < $cutoff) | .labels["bench-run"]' \
  | while read -r run; do
      echo "deleting stale run $run"
      "$(dirname "$0")/down.sh" "$run"
    done

# Keys whose server is already gone (for example deleted by the self-destruct timer).
hcloud ssh-key list -l bench-run -o json \
  | jq -r '.[] | .name' \
  | while read -r key; do
      hcloud server describe "$key" >/dev/null 2>&1 || hcloud ssh-key delete "$key"
    done
