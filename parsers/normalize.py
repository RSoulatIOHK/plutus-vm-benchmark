#!/usr/bin/env python3
"""Merge per-VM CSV files into a single unified.csv.

Every *.csv in the run dir whose header is the timing schema (HEADER) is a per-VM result, so a new
VM needs no change here. Other CSVs in the dir (<vm>-check.csv, <vm>-compile.csv, raw JMH or
Criterion CSVs, unified.csv itself) have a different header or name and are skipped.
<vm>-eval.csv (eval-only timing) has the timing schema but is not a D3 timing: it is skipped here
and read by report/generate_report.py.
"""

import csv
import os
import sys


HEADER = ["vm", "script", "mean_ns", "median_ns", "min_ns", "max_ns", "stddev_ns", "iterations"]


def normalize(run_dir: str) -> None:
    output_path = os.path.join(run_dir, "unified.csv")
    rows = []

    for vm_file in sorted(os.listdir(run_dir)):
        path = os.path.join(run_dir, vm_file)
        if (vm_file == "unified.csv" or vm_file.endswith("-eval.csv") or not vm_file.endswith(".csv")
                or not os.path.isfile(path)):
            continue

        with open(path) as f:
            reader = csv.DictReader(f)
            if reader.fieldnames != HEADER:
                continue
            count = 0
            for row in reader:
                rows.append(row)
                count += 1
            print(f"  loaded: {vm_file} ({count} scripts)", file=sys.stderr)

    # Sort by script name, then VM name
    rows.sort(key=lambda r: (r.get("script", ""), r.get("vm", "")))

    with open(output_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=HEADER)
        writer.writeheader()
        writer.writerows(rows)

    print(f"  wrote: {output_path} ({len(rows)} total rows)", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <run-dir>", file=sys.stderr)
        sys.exit(1)
    normalize(sys.argv[1])
