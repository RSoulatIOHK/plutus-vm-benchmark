#!/usr/bin/env bash
# Rebuild the Haskell reference image and regenerate check/reference/haskell-check.csv.
# Usage: check/reference/regenerate.sh   (from anywhere; needs Docker)
# Env: CABAL_JOBS (default 2), IMAGE (default pvb-gate-ref:1.63.0.0)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
image="${IMAGE:-pvb-gate-ref:1.63.0.0}"

docker build --build-arg CABAL_JOBS="${CABAL_JOBS:-2}" -t "$image" "$here"

# stdout is the csv; stderr has the mainnet vs compiled-in cost model cross-check.
# Exit code 2 means the two cost models disagree on some script (see stderr).
docker run --rm -v "$repo/data:/bench/data:ro" "$image" > "$here/haskell-check.csv.tmp"
mv "$here/haskell-check.csv.tmp" "$here/haskell-check.csv"
echo "wrote $here/haskell-check.csv ($(($(wc -l < "$here/haskell-check.csv") - 1)) scripts)"
