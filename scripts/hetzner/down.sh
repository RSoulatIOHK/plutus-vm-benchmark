#!/usr/bin/env bash
# Delete the bench server and SSH key of a run. Safe to call twice or after a failed up.sh.
#
#   HCLOUD_TOKEN=... scripts/hetzner/down.sh <run-id>
set -uo pipefail

RUN_ID="${1:?usage: down.sh <run-id>}"
NAME="bench-$RUN_ID"
: "${HCLOUD_TOKEN:?HCLOUD_TOKEN must be set}"
export HCLOUD_TOKEN

status=0
if hcloud server describe "$NAME" >/dev/null 2>&1; then
  hcloud server delete "$NAME" || status=1
fi
if hcloud ssh-key describe "$NAME" >/dev/null 2>&1; then
  hcloud ssh-key delete "$NAME" || status=1
fi
exit $status
