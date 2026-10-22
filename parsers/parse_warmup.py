#!/usr/bin/env python3
"""Write the warm-up of the JIT rows as CSV (docs/IMAGE_CONTRACT.md).

Usage: parse_warmup.py [--used] <vm-name> <raw-log>

The JIT rows (scalus-cek, scalus-jit, blaze-v8, scalus-js, aiken-wasm) warm up in slices of 1 s
until the time per operation is steady, 30 s at most (METHODOLOGY.md, D13). After the warm-up of a
script and loop, the harness prints one line
  PVB_WARMUP {"script", "loop", "slices": [{"ops", "ns"}, ...], "capped": true|false}
The JMH rows print it from the forked JVM (AdaptiveWarmup.scala in images/scalus/harness), the JS
rows from their timing loop. With BENCH_TIMING=quick the warm-up is one fixed slice.

Output on stdout:
- default (BENCH_TRACE=1, <vm>-warmup.csv): one row per slice, vm,script,loop,second,ns_per_op.
  second counts the slices from 1. ns_per_op is the mean time per operation in that slice.
- --used (<vm>-warmup-used.csv): one row per script and loop, vm,script,loop,seconds,capped.
  seconds is the length of the warm-up (the sum of its slices, one decimal). capped is 1 when the
  warm-up stopped at the cap, not because it was steady.
"""

import json
import re
import sys

TRACE_HEADER = "vm,script,loop,second,ns_per_op"
USED_HEADER = "vm,script,loop,seconds,capped"

ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
WARMUP_RE = re.compile(r"PVB_WARMUP (\{.*\})\s*$")


def records(log_path: str):
    """The PVB_WARMUP records of the log, in order."""
    with open(log_path, errors="replace") as f:
        for line in f:
            if m := WARMUP_RE.search(ANSI_RE.sub("", line)):
                try:
                    yield json.loads(m.group(1))
                except ValueError:
                    pass  # a line cut by a crash


def trace(vm: str, log_path: str) -> None:
    print(TRACE_HEADER)
    for r in records(log_path):
        for i, s in enumerate(r["slices"], 1):
            if s["ops"] > 0:
                print(f"{vm},{r['script']},{r['loop']},{i},{s['ns'] / s['ops']:.0f}")


def used(vm: str, log_path: str) -> None:
    print(USED_HEADER)
    for r in records(log_path):
        seconds = sum(s["ns"] for s in r["slices"]) / 1e9
        print(f"{vm},{r['script']},{r['loop']},{seconds:.1f},{1 if r.get('capped') else 0}")


if __name__ == "__main__":
    args = sys.argv[1:]
    mode = trace
    if args[:1] == ["--used"]:
        mode, args = used, args[1:]
    if len(args) != 2:
        print(f"Usage: {sys.argv[0]} [--used] <vm-name> <raw-log>", file=sys.stderr)
        sys.exit(1)
    mode(*args)
