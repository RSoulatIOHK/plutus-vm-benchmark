#!/usr/bin/env python3
"""Parse JMH CSV benchmark output into unified CSV.

JMH CSV format (via -rff flag):
  "Benchmark","Mode","Threads","Samples","Score","Score Error (99.9%)","Unit","Param: file"

Score is in the unit specified (typically us/op).

Usage: parse_jmh.py <jmh-csv> [vm-filter] [--eval]
Without --eval: the D3 rows (flat decode + evaluation, <vm>.csv). With --eval: the eval-only rows
(program decoded once in setup, <vm>-eval.csv).
"""

import csv
import sys

HEADER = "vm,script,mean_ns,median_ns,min_ns,max_ns,stddev_ns,iterations"

# Map JMH benchmark Class.method to (VM name, kind). Kind "d3" goes to <vm>.csv, "eval" to
# <vm>-eval.csv. The Scalus JIT has one loop (evaluation of the compiled script); its run script
# copies <vm>.csv to <vm>-eval.csv.
BENCH_TO_VM = {
    "CekJVMBenchmark.bench": ("scalus-cek", "d3"),
    "CekJVMBenchmark.benchEval": ("scalus-cek", "eval"),
    "JITBenchmark.benchJIT": ("scalus-jit", "d3"),
    "CekJavaBenchmark.bench": ("julc-java", "d3"),
    "CekJavaBenchmark.benchEval": ("julc-java", "eval"),
}

# Unit conversion to nanoseconds
UNIT_TO_NS = {
    "us/op": 1_000,
    "ms/op": 1_000_000,
    "s/op": 1_000_000_000,
    "ns/op": 1,
}


def parse(csv_path: str, vm_filter: str | None = None, kind: str = "d3") -> None:
    print(HEADER)

    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            benchmark = row["Benchmark"]
            # Extract short benchmark name
            short = benchmark.split(".")[-2] + "." + benchmark.split(".")[-1]

            entry = BENCH_TO_VM.get(short)
            if entry is None or entry[1] != kind:
                continue
            vm_name = entry[0]
            if vm_filter and vm_name != vm_filter:
                continue

            file_param = row.get("Param: file", "")
            script = file_param.replace(".flat", "")
            if not script:
                continue

            score = float(row["Score"])
            error_str = row["Score Error (99.9%)"]
            error = float(error_str) if error_str != "NaN" else 0.0
            unit = row["Unit"]
            samples = int(row["Samples"])

            multiplier = UNIT_TO_NS.get(unit, 1)
            mean_ns = int(score * multiplier)
            # Use error as stddev approximation
            stddev_ns = int(error * multiplier)
            # JMH avgt doesn't give min/max directly
            min_ns = int((score - error) * multiplier)
            max_ns = int((score + error) * multiplier)
            median_ns = mean_ns

            print(
                f"{vm_name},{script},"
                f"{mean_ns},{median_ns},{min_ns},{max_ns},"
                f"{stddev_ns},{samples}"
            )


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--eval"]
    if not 1 <= len(args) <= 2:
        print(f"Usage: {sys.argv[0]} <jmh-csv> [vm-filter] [--eval]", file=sys.stderr)
        sys.exit(1)
    vm_filter = args[1] if len(args) > 1 else None
    parse(args[0], vm_filter, "eval" if "--eval" in sys.argv[1:] else "d3")
