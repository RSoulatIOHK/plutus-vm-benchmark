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
LOCATIONS="${BENCH_LOCATIONS:-nbg1 fsn1 hel1}"
STATE="${BENCH_STATE:-${TMPDIR:-/tmp}/bench-hetzner}/$RUN_ID"
NAME="bench-$RUN_ID"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

: "${HCLOUD_TOKEN:?HCLOUD_TOKEN must be set}"
export HCLOUD_TOKEN

mkdir -p "$STATE"
KEY="$STATE/id_ed25519"
[ -f "$KEY" ] || ssh-keygen -q -t ed25519 -N "" -C "$NAME" -f "$KEY"
SSH_OPTS=(-i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10)

# Hetzner allows each public key once per project. run.yml uses one key (BENCH_SSH_KEY) for every
# run, so a second run in parallel finds it already registered: reuse that entry. down.sh deletes
# only the key named after its own run, so a reused key stays for the run that registered it.
FINGERPRINT="$(ssh-keygen -E md5 -lf "$KEY.pub" | awk '{print $2}' | sed 's/^MD5://')"
KEY_NAME="$(hcloud ssh-key list -o json | jq -r --arg fp "$FINGERPRINT" '.[] | select(.fingerprint == $fp) | .name' | head -1)"
if [ -z "$KEY_NAME" ]; then
  KEY_NAME="$NAME"
  hcloud ssh-key create --name "$KEY_NAME" --public-key-from-file "$KEY.pub" --label bench-run="$RUN_ID" >/dev/null
else
  echo "SSH key already registered as $KEY_NAME; using it" >&2
fi

# A location can be out of capacity for a server type (resource_unavailable). Shortages are
# usually brief, so try every location, wait, and try again for up to ROUNDS rounds.
# The labels let sweep.sh find stale servers.
ROUNDS="${BENCH_CREATE_ROUNDS:-10}"
created=""
for round in $(seq 1 "$ROUNDS"); do
  for loc in $LOCATIONS; do
    if err=$(hcloud server create \
      --name "$NAME" \
      --type "$SERVER_TYPE" \
      --location "$loc" \
      --image ubuntu-24.04 \
      --ssh-key "$KEY_NAME" \
      --label bench-run="$RUN_ID" \
      --label created="$(date +%s)" 2>&1 >/dev/null); then
      created="$loc"
      break 2
    fi
    echo "$err" >&2
    # Only a capacity shortage passes by waiting. A project limit, a bad type or a bad token does not.
    case "$err" in
      *resource_unavailable*) ;;
      *resource_limit_exceeded*)
        echo "the Hetzner project limit does not allow a $SERVER_TYPE (raise it in the Console: Limits)" >&2
        exit 1 ;;
      *) exit 1 ;;
    esac
    echo "round $round: no $SERVER_TYPE in $loc" >&2
  done
  if [ "$round" -lt "$ROUNDS" ]; then sleep 60; fi
done
if [ -z "$created" ]; then
  echo "no $SERVER_TYPE in $LOCATIONS after $ROUNDS rounds" >&2
  exit 1
fi
echo "created $NAME ($SERVER_TYPE) in $created" >&2

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
