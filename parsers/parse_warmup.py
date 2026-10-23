#!/usr/bin/env python3
"""Write the warm-up of the JIT rows as CSV (docs/IMAGE_CONTRACT.md).

Usage: parse_warmup.py [--used] <vm-name> <raw-log>

Output on stdout:
- default (BENCH_TRACE=1, <vm>-warmup.csv): one row per 1 s warm-up slice,
  vm,script,loop,second,ns_per_op. second counts the slices from 1. ns_per_op is the mean time per
  operation in that slice.
- --used (<vm>-warmup-used.csv): one row per script and loop, vm,script,loop,seconds,capped.
  seconds is the length of the warm-up (one decimal). capped is 1 when an adaptive warm-up stopped
  at the 30 s cap, 0 when it stopped because the time was steady, and "fixed" for a warm-up of
  fixed length (the JMH rows, and BENCH_TIMING=quick).

Two sources in the raw log:
- The JS harnesses (blaze, scalus-js, aiken-wasm) warm up adaptively in slices of 1 s
  (METHODOLOGY.md, D13). After the warm-up of a script and loop they print one line
    PVB_WARMUP {"script", "loop", "slices": [{"ops", "ns"}, ...], "capped", "end"}
  end is "steady", "capped" or "fixed" (one fixed slice, BENCH_TIMING=quick).
- JMH (scalus-cek, scalus-jit) uses its own warm-up iterations: "# Warmup: <n> iterations, <t> s
  each" gives the length. In trace mode it runs as iterations of 1 s (-wi 30 -w 1s); each
  "# Warmup Iteration N: <score> <unit>" line is one slice. The "# Benchmark:" and
  "# Parameters: (file = <script>.flat)" lines above them give the loop and the script.
"""

import json
import re
import sys

from parse_jmh import BENCH_TO_VM, UNIT_TO_NS

TRACE_HEADER = "vm,script,loop,second,ns_per_op"
USED_HEADER = "vm,script,loop,seconds,capped"

ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
JS_RE = re.compile(r"PVB_WARMUP (\{.*\})\s*$")
JMH_BENCH_RE = re.compile(r"^# Benchmark: (\S+)")
JMH_PARAMS_RE = re.compile(r"^# Parameters:.*file\s*=\s*(\S+?)(?:\.flat)?[,)]")
JMH_WARMUP_SPEC_RE = re.compile(r"^# Warmup: (\d+) iterations, ([\d.]+) (s|ms) each")
JMH_WARMUP_RE = re.compile(r"^# Warmup Iteration\s+(\d+):\s+([\d.,]+)\s+(\S+/op)")


def events(log_path: str):
    """The warm-ups of the log, in order: ("js", record) for a PVB_WARMUP line, and
    ("jmh", script, loop, iteration, ns_per_op, warm-up seconds) for a JMH warm-up iteration."""
    loop = script = None
    seconds = 0.0
    with open(log_path, errors="replace") as f:
        for line in f:
            line = ANSI_RE.sub("", line)
            if m := JS_RE.search(line):
                try:
                    yield ("js", json.loads(m.group(1)))
                except ValueError:
                    pass  # a line cut by a crash
            elif m := JMH_BENCH_RE.match(line):
                entry = BENCH_TO_VM.get(".".join(m.group(1).split(".")[-2:]))
                loop = entry[1] if entry else None
            elif m := JMH_PARAMS_RE.match(line):
                script = m.group(1)
            elif m := JMH_WARMUP_SPEC_RE.match(line):
                seconds = int(m.group(1)) * float(m.group(2)) / (1000 if m.group(3) == "ms" else 1)
            elif (m := JMH_WARMUP_RE.match(line)) and loop and script:
                ns = float(m.group(2).replace(",", "")) * UNIT_TO_NS.get(m.group(3), 1)
                yield ("jmh", script, loop, int(m.group(1)), ns, seconds)


def trace(vm: str, log_path: str) -> None:
    print(TRACE_HEADER)
    for e in events(log_path):
        if e[0] == "js":
            r = e[1]
            for i, s in enumerate(r["slices"], 1):
                if s["ops"] > 0:
                    print(f"{vm},{r['script']},{r['loop']},{i},{s['ns'] / s['ops']:.0f}")
        else:
            _, script, loop, i, ns, _ = e
            print(f"{vm},{script},{loop},{i},{ns:.0f}")


def used(vm: str, log_path: str) -> None:
    print(USED_HEADER)
    for e in events(log_path):
        if e[0] == "js":
            r = e[1]
            seconds = sum(s["ns"] for s in r["slices"]) / 1e9
            capped = "fixed" if r.get("end") == "fixed" else 1 if r.get("capped") else 0
            print(f"{vm},{r['script']},{r['loop']},{seconds:.1f},{capped}")
        elif e[3] == 1:  # one row per JMH warm-up, at its first iteration
            _, script, loop, _, _, seconds = e
            print(f"{vm},{script},{loop},{seconds:.1f},fixed")


if __name__ == "__main__":
    args = sys.argv[1:]
    mode = trace
    if args[:1] == ["--used"]:
        mode, args = used, args[1:]
    if len(args) != 2:
        print(f"Usage: {sys.argv[0]} [--used] <vm-name> <raw-log>", file=sys.stderr)
        sys.exit(1)
    mode(*args)
