#!/usr/bin/env python3
"""Parse Haskell Criterion CSV benchmark output into unified CSV.

Usage: parse_criterion_hs.py <criterion-csv> [criterion-json]

Criterion's --csv flag produces:
  Name,Mean,MeanLB,MeanUB,Stddev,StddevLB,StddevUB
where Mean/Stddev are in seconds. mean_ns and stddev_ns are Criterion's Mean and Stddev.
min_ns and max_ns are MeanLB and MeanUB: the bounds of the bootstrap confidence interval of the
mean, not the fastest and slowest sample.

iterations is the number of Criterion samples (as for Criterion.rs in parse_criterion.py). The CSV
and the text log do not have it: only Criterion's --json report has it (reportMeasured, one entry
per sample). Without the JSON file, iterations is 0 (unknown).
"""

import csv
import json
import sys
from collections import OrderedDict

VM_NAME = "haskell"
HEADER = "vm,script,mean_ns,median_ns,min_ns,max_ns,stddev_ns,iterations"


def script_name(name: str) -> str:
    # "validation/script-name" -> "script-name"
    return name.split("/")[-1]


def sample_counts(json_path: str) -> dict[str, int]:
    """Samples per script from Criterion's --json report: ["criterion", <version>, [report]]."""
    with open(json_path) as f:
        reports = json.load(f)[2]
    return {script_name(r["reportName"]): len(r["reportMeasured"]) for r in reports}


def parse(csv_path: str, json_path: str | None = None) -> None:
    samples = sample_counts(json_path) if json_path else {}
    # Use OrderedDict to deduplicate — last occurrence wins (handles aborted reruns)
    results: OrderedDict[str, str] = OrderedDict()

    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row["Name"]
            # Skip duplicate header rows
            if name == "Name":
                continue
            script = script_name(name)

            mean_s = float(row["Mean"])
            stddev_s = float(row["Stddev"])
            mean_lb_s = float(row["MeanLB"])
            mean_ub_s = float(row["MeanUB"])

            mean_ns = int(mean_s * 1e9)
            stddev_ns = int(stddev_s * 1e9)
            min_ns = int(mean_lb_s * 1e9)
            max_ns = int(mean_ub_s * 1e9)
            median_ns = mean_ns
            iterations = samples.get(script, 0)

            results[script] = (
                f"{VM_NAME},{script},"
                f"{mean_ns},{median_ns},{min_ns},{max_ns},"
                f"{stddev_ns},{iterations}"
            )

    print(HEADER)
    for line in results.values():
        print(line)


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        print(f"Usage: {sys.argv[0]} <criterion-csv-file> [criterion-json-file]", file=sys.stderr)
        sys.exit(1)
    parse(sys.argv[1], sys.argv[2] if len(sys.argv) == 3 else None)
