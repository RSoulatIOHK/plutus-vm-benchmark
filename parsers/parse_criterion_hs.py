#!/usr/bin/env python3
"""Parse Haskell Criterion CSV benchmark output into unified CSV.

Usage: parse_criterion_hs.py [--group <group>] <criterion-csv> [criterion-json ...]

Criterion's --csv flag produces:
  Name,Mean,MeanLB,MeanUB,Stddev,StddevLB,StddevUB
where Mean/Stddev are in seconds. mean_ns and stddev_ns are Criterion's Mean and Stddev.
Criterion reports no median, minimum or maximum, so median_ns, min_ns and max_ns are empty.
(MeanLB and MeanUB are the bounds of the bootstrap confidence interval of the mean, not the
fastest and slowest sample.)

iterations is the number of Criterion samples (as for Criterion.rs in parse_criterion.py). The CSV
and the text log do not have it: only Criterion's --json report has it (reportMeasured, one entry
per sample). scripts/run-haskell.sh runs one process per script, so it passes one JSON report per
script. A script without a JSON report gets iterations 0 (unknown).

--group: keep only the benchmarks named "<group>/<script>". pvb-bench runs the D3 loop as group
"d3" and the eval-only loop as group "eval" in the same process, so one CSV and one JSON report
hold both loops; the run script parses them once per group.
"""

import csv
import json
import os
import sys
from collections import OrderedDict

VM_NAME = "haskell"
HEADER = "vm,script,mean_ns,median_ns,min_ns,max_ns,stddev_ns,iterations"


def script_name(name: str) -> str:
    # "validation/script-name" -> "script-name"
    return name.split("/")[-1]


def sample_counts(json_paths: list[str]) -> dict[str, int]:
    """Samples per benchmark name from Criterion's --json reports: ["criterion", <version>, [report]]."""
    counts: dict[str, int] = {}
    for path in json_paths:
        if not os.path.isfile(path):  # an unmatched glob, or a process that wrote no report
            continue
        with open(path) as f:
            reports = json.load(f)[2]
        counts.update({r["reportName"]: len(r["reportMeasured"]) for r in reports})
    return counts


def parse(csv_path: str, json_paths: list[str], group: str | None = None) -> None:
    samples = sample_counts(json_paths)
    # Use OrderedDict to deduplicate — last occurrence wins (handles aborted reruns)
    results: OrderedDict[str, str] = OrderedDict()

    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row["Name"]
            # Skip the header rows of later processes (Criterion appends to the CSV)
            if name == "Name":
                continue
            if group is not None and not name.startswith(group + "/"):
                continue
            script = script_name(name)

            mean_ns = int(float(row["Mean"]) * 1e9)
            stddev_ns = int(float(row["Stddev"]) * 1e9)
            iterations = samples.get(name, 0)

            results[script] = f"{VM_NAME},{script},{mean_ns},,,,{stddev_ns},{iterations}"

    print(HEADER)
    for line in results.values():
        print(line)


if __name__ == "__main__":
    args = sys.argv[1:]
    group = None
    if args[:1] == ["--group"]:
        group = args[1] if len(args) > 1 else ""
        args = args[2:]
    if len(args) < 1 or group == "":
        print(f"Usage: {sys.argv[0]} [--group <group>] <criterion-csv-file> [criterion-json-file ...]",
              file=sys.stderr)
        sys.exit(1)
    parse(args[0], args[1:], group)
