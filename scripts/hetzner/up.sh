#!/usr/bin/env bash
# Create a bench server on Hetzner Cloud and install the NixOS config nix/runner.nix on it.
#
#   HCLOUD_TOKEN=... scripts/hetzner/up.sh <run-id>
#
# Prints the server IPv4 on the last line. Writes the per-run SSH key to $BENCH_STATE/<run-id>.
# Always pair with scripts/hetzner/down.sh <run-id>: a forgotten server is billed until deleted.
set -euo pipefail

RUN_ID="${1:?usage: up.sh <run-id>}"
SERVER_TYPE="${BENCH_SERVER_TYPE:-ccx33}"
LOCATION="${BENCH_LOCATION:-nbg1}"
STATE="${BENCH_STATE:-${TMPDIR:-/tmp}/bench-hetzner}/$RUN_ID"
NAME="bench-$RUN_ID"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

: "${HCLOUD_TOKEN:?HCLOUD_TOKEN must be set}"
export HCLOUD_TOKEN

mkdir -p "$STATE"
KEY="$STATE/id_ed25519"
[ -f "$KEY" ] || ssh-keygen -q -t ed25519 -N "" -C "$NAME" -f "$KEY"
SSH_OPTS=(-i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10)

hcloud ssh-key create --name "$NAME" --public-key-from-file "$KEY.pub" --label bench-run="$RUN_ID" >/dev/null

# The labels let sweep.yml find and delete servers that outlived their run.
hcloud server create \
  --name "$NAME" \
  --type "$SERVER_TYPE" \
  --location "$LOCATION" \
  --image ubuntu-24.04 \
  --ssh-key "$NAME" \
  --label bench-run="$RUN_ID" \
  --label created="$(date +%s)" >/dev/null

IP="$(hcloud server ip "$NAME")"
echo "$IP" > "$STATE/ip"

wait_ssh() {
  for _ in $(seq 1 60); do
    ssh "${SSH_OPTS[@]}" -o BatchMode=yes "root@$IP" true 2>/dev/null && return 0
    sleep 5
  done
  echo "ssh to $IP did not come up" >&2
  return 1
}

wait_ssh
# --build-on remote: the server builds its own system, so the caller needs no x86_64-linux builder.
nix run github:nix-community/nixos-anywhere -- \
  --flake "$REPO_ROOT#bench-runner" \
  --build-on remote \
  -i "$KEY" \
  --ssh-option StrictHostKeyChecking=no \
  --ssh-option UserKnownHostsFile=/dev/null \
  "root@$IP" >&2
wait_ssh

# The self-destruct timer needs the token. Send it over SSH so it never sits in the public config.
printf '%s' "$HCLOUD_TOKEN" | ssh "${SSH_OPTS[@]}" "root@$IP" \
  'umask 077 && cat > /var/lib/bench/hcloud-token && chmod 400 /var/lib/bench/hcloud-token'

echo "$IP"
