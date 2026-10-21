#!/usr/bin/env python3
"""Parse JMH JSON benchmark output (-rf json -rff <file>) into unified CSV.

Usage: parse_jmh.py <jmh-json> [vm-filter] [--eval]
Without --eval: the D3 rows (flat decode + evaluation, <vm>.csv). With --eval: the eval-only rows
(program decoded once in setup, <vm>-eval.csv).

The benchmarks run in JMH's average-time mode: each measurement iteration reports the mean time
per operation over that iteration. JMH does not report single operations or the number of
operations per iteration. So the columns are statistics over the measurement iterations:
  mean_ns     JMH's score: the mean of the iteration means
  median_ns   median of the iteration means
  min_ns      fastest iteration mean
  max_ns      slowest iteration mean
  stddev_ns   sample standard deviation (n - 1) of the iteration means; 0 for one iteration
  iterations  number of measurement iterations (JMH's "Cnt"), over all forks
JMH's "Score Error" is the half-width of a 99.9% confidence interval, not a standard deviation:
it is not used.
"""

from __future__ import annotations

import json
import statistics
import sys

HEADER = "vm,script,mean_ns,median_ns,min_ns,max_ns,stddev_ns,iterations"

# Map JMH benchmark Class.method to (VM name, kind). Kind "d3" goes to <vm>.csv, "eval" to
# <vm>-eval.csv. The Scalus JIT has one loop (evaluation of the compiled script); its run script
# copies <vm>.csv to <vm>-eval.csv.
BENCH_TO_VM = {
    "CekJVMBenchmark.bench": ("scalus-cek", "d3"),
    "CekJVMBenchmark.benchEval": ("scalus-cek", "eval"),
    "JITBenchmark.benchJIT": ("scalus-jit", "d3"),
}

# Unit conversion to nanoseconds
UNIT_TO_NS = {
    "us/op": 1_000,
    "ms/op": 1_000_000,
    "s/op": 1_000_000_000,
    "ns/op": 1,
}


def parse(json_path: str, vm_filter: str | None = None, kind: str = "d3") -> None:
    print(HEADER)

    with open(json_path) as f:
        results = json.load(f)
    for result in results:
        # Extract short benchmark name
        short = ".".join(result["benchmark"].split(".")[-2:])
        entry = BENCH_TO_VM.get(short)
        if entry is None or entry[1] != kind:
            continue
        vm_name = entry[0]
        if vm_filter and vm_name != vm_filter:
            continue

        script = result.get("params", {}).get("file", "").replace(".flat", "")
        if not script:
            continue

        metric = result["primaryMetric"]
        ns = UNIT_TO_NS.get(metric["scoreUnit"], 1)
        # rawData: one list of iteration scores per fork.
        scores = [float(s) * ns for fork in metric["rawData"] for s in fork]
        if not scores:
            continue
        stddev = statistics.stdev(scores) if len(scores) > 1 else 0.0

        print(
            f"{vm_name},{script},"
            f"{int(float(metric['score']) * ns)},{int(statistics.median(scores))},"
            f"{int(min(scores))},{int(max(scores))},"
            f"{int(stddev)},{len(scores)}"
        )


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--eval"]
    if not 1 <= len(args) <= 2:
        print(f"Usage: {sys.argv[0]} <jmh-json> [vm-filter] [--eval]", file=sys.stderr)
        sys.exit(1)
    vm_filter = args[1] if len(args) > 1 else None
    parse(args[0], vm_filter, "eval" if "--eval" in sys.argv[1:] else "d3")
