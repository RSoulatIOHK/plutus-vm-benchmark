#!/usr/bin/env python3
"""Parse the PVB_RESULT lines of the Plutuz harness into the unified timing CSV.

Usage: parse_plutuz_json.py <plutuz-raw.log> <loop>

images/plutuz/pvb_bench.zig prints one line per script and timed loop:
  PVB_RESULT {"name": ..., "loop": "d3" | "eval", "iterations", "mean_ns", "median_ns",
              "min_ns", "max_ns", "stddev_ns"}
Writes the rows of <loop> to stdout.
"""

import json
import sys

VM_NAME = "plutuz"
HEADER = "vm,script,mean_ns,median_ns,min_ns,max_ns,stddev_ns,iterations"
PREFIX = "PVB_RESULT "


def parse(log_path: str, loop: str) -> None:
    print(HEADER)
    with open(log_path) as f:
        for line in f:
            if not line.startswith(PREFIX):
                continue
            r = json.loads(line[len(PREFIX):])
            if r["loop"] != loop:
                continue
            print(
                f"{VM_NAME},{r['name']},"
                f"{r['mean_ns']},{r['median_ns']},{r['min_ns']},{r['max_ns']},"
                f"{r['stddev_ns']},{r['iterations']}"
            )


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[2] not in ("d3", "eval"):
        print(f"Usage: {sys.argv[0]} <plutuz-raw.log> d3|eval", file=sys.stderr)
        sys.exit(1)
    parse(sys.argv[1], sys.argv[2])
