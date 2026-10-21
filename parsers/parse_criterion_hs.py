#!/usr/bin/env python3
"""Parse Haskell Criterion CSV benchmark output into unified CSV.

Usage: parse_criterion_hs.py <criterion-csv> [criterion-json ...]

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
    """Samples per script from Criterion's --json reports: ["criterion", <version>, [report]]."""
    counts: dict[str, int] = {}
    for path in json_paths:
        if not os.path.isfile(path):  # an unmatched glob, or a process that wrote no report
            continue
        with open(path) as f:
            reports = json.load(f)[2]
        counts.update({script_name(r["reportName"]): len(r["reportMeasured"]) for r in reports})
    return counts


def parse(csv_path: str, json_paths: list[str]) -> None:
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
            script = script_name(name)

            mean_ns = int(float(row["Mean"]) * 1e9)
            stddev_ns = int(float(row["Stddev"]) * 1e9)
            iterations = samples.get(script, 0)

            results[script] = f"{VM_NAME},{script},{mean_ns},,,,{stddev_ns},{iterations}"

    print(HEADER)
    for line in results.values():
        print(line)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <criterion-csv-file> [criterion-json-file ...]", file=sys.stderr)
        sys.exit(1)
    parse(sys.argv[1], sys.argv[2:])
