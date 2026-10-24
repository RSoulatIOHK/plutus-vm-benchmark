#!/bin/bash
# scalus-js-140: the scalus npm package 1.4.0, the "before" row of the Scalus 1.4.1 preparation
# (TEMPORARY, revert after the run). The same harness as scalus-js (run-scalus-js.sh); 1.4.0 has no
# PlutusVM and cannot evaluate a decoded program, so there is no eval loop.
#
# pvb-loops: d3 check
set -uo pipefail

# image-entry.sh passes the requested loops on as they are: drop eval.
BENCH_LOOPS=$(echo ",${BENCH_LOOPS:-d3,eval,check}," | sed 's/,eval,/,/g; s/^,//; s/,$//')
export BENCH_LOOPS
PVB_JS_VM=scalus-js-140 exec bash /bench/scripts/run-scalus-js.sh "$@"
