#!/usr/bin/env bash
# Print, per datacenter, the server types that Hetzner can place right now.
#
#   HCLOUD_TOKEN=... scripts/hetzner/capacity.sh
set -euo pipefail
: "${HCLOUD_TOKEN:?HCLOUD_TOKEN must be set}"
export HCLOUD_TOKEN

types="$(hcloud server-type list -o json)"
hcloud datacenter list -o json \
  | jq -r --argjson types "$types" '
      ($types | map({key: (.id | tostring), value: .name}) | from_entries) as $name
      | .[] | "\(.name): \([.server_types.available[] | $name[tostring] // tostring] | sort | join(" "))"'
