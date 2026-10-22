#!/usr/bin/env python3
"""Write the warm-up of the JIT rows in 1 s slices as CSV (BENCH_TRACE=1, docs/IMAGE_CONTRACT.md).

Usage: parse_warmup.py <vm-name> <raw-log>

Output on stdout, one row per slice: vm,script,loop,second,ns_per_op. second counts the slices
from 1. ns_per_op is the mean time per operation in that slice.

Two sources in the raw log:
- JMH (scalus-cek, scalus-jit): trace mode runs the 20 s warm-up as 20 warm-up iterations of 1 s
  (-wi 20 -w 1s). Each "# Warmup Iteration N: <score> <unit>" line is one slice; the "# Benchmark:"
  and "# Parameters: (file = <script>.flat)" lines above it give the loop and the script.
- The JS harnesses (blaze, scalus-js, aiken-wasm): trace mode runs the warm-up as rounds of 1 s
  and prints them after the warm-up as "PVB_WARMUP {"script", "loop", "slices": [{"ops", "ns"},
  ...]}". The last slice is shorter when the warm-up is not a whole number of seconds (quick).
"""

import json
import re
import sys

from parse_jmh import BENCH_TO_VM, UNIT_TO_NS

HEADER = "vm,script,loop,second,ns_per_op"

ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
JS_RE = re.compile(r"PVB_WARMUP (\{.*\})\s*$")
JMH_BENCH_RE = re.compile(r"^# Benchmark: (\S+)")
JMH_PARAMS_RE = re.compile(r"^# Parameters:.*file\s*=\s*(\S+?)(?:\.flat)?[,)]")
JMH_WARMUP_RE = re.compile(r"^# Warmup Iteration\s+(\d+):\s+([\d.,]+)\s+(\S+/op)")


def parse(vm: str, log_path: str) -> None:
    print(HEADER)
    loop = script = None
    with open(log_path, errors="replace") as f:
        for line in f:
            line = ANSI_RE.sub("", line)
            if m := JS_RE.search(line):
                r = json.loads(m.group(1))
                for i, s in enumerate(r["slices"], 1):
                    if s["ops"] > 0:
                        print(f"{vm},{r['script']},{r['loop']},{i},{s['ns'] / s['ops']:.0f}")
            elif m := JMH_BENCH_RE.match(line):
                entry = BENCH_TO_VM.get(".".join(m.group(1).split(".")[-2:]))
                loop = entry[1] if entry else None
            elif m := JMH_PARAMS_RE.match(line):
                script = m.group(1)
            elif (m := JMH_WARMUP_RE.match(line)) and loop and script:
                ns = float(m.group(2).replace(",", "")) * UNIT_TO_NS.get(m.group(3), 1)
                print(f"{vm},{script},{loop},{m.group(1)},{ns:.0f}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <vm-name> <raw-log>", file=sys.stderr)
        sys.exit(1)
    parse(sys.argv[1], sys.argv[2])
