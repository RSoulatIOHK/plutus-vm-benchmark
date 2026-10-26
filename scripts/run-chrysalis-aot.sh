#!/bin/bash
# chrysalis-aot: the chrysalis harness compiled with NativeAOT. Same loops, outputs and parameters as
# scripts/run-chrysalis.sh, which this script runs; only the warm-up rules differ (see there).
#
# pvb-loops: d3 eval check
set -euo pipefail
CHRYSALIS_VM=chrysalis-aot exec bash "$(dirname "$0")/run-chrysalis.sh" "$@"
