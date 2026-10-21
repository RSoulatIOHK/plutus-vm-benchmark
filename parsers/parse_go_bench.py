#!/usr/bin/env python3
"""Parse Go testing.B benchmark output into unified CSV."""

import re
import sys

VM_NAME = "plutigo"
HEADER = "vm,script,mean_ns,median_ns,min_ns,max_ns,stddev_ns,iterations"

# BenchmarkPvbFlatFiles/auction_1-1-8    12345    98765 ns/op    4096 B/op    42 allocs/op
# (images/plutigo/pvb_bench_test.go; the upstream name BenchmarkFlatFiles also parses)
BENCH_RE = re.compile(
    r"Benchmark(?:Pvb)?FlatFiles/(\S+)-\d+\s+"  # name-GOMAXPROCS
    r"(\d+)\s+"                          # iterations
    r"([\d.]+)\s+ns/op"                  # ns/op
)


def parse(log_path: str) -> None:
    print(HEADER)

    with open(log_path) as f:
        for line in f:
            m = BENCH_RE.search(line)
            if not m:
                continue

            name = m.group(1)
            iterations = int(m.group(2))
            mean_ns = int(float(m.group(3)))

            # Go bench only reports mean ns/op; no median/min/max/stddev
            print(
                f"{VM_NAME},{name},"
                f"{mean_ns},{mean_ns},0,0,"
                f"0,{iterations}"
            )


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <plutigo-raw.log>", file=sys.stderr)
        sys.exit(1)
    parse(sys.argv[1])
