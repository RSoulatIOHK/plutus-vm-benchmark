#!/usr/bin/env python3
"""Merge per-VM CSV files into a single unified.csv.

Every *.csv in the run dir whose header is the timing schema (HEADER) is a per-VM result, so a new
VM needs no change here. Other CSVs in the dir (<vm>-check.csv, <vm>-compile.csv, raw JMH or
Criterion CSVs, unified.csv itself) have a different header or name and are skipped.
<vm>-eval.csv (eval-only timing) has the timing schema but is not a D3 timing: it is skipped here
and read by report/generate_report.py. <vm>-drift.csv (the drift probe of scripts/run-images.sh)
has the timing schema too and is skipped as well. <vm>-warmup.csv (BENCH_TRACE=1: the warm-up in
1 s slices) has its own schema and is skipped by name too.

Drift probe: when haskell-drift.csv and haskell.csv exist, drift() compares the scripts they share
and writes drift.json. The ratio is the geometric mean of end / start over the scripts with a
timing in both. The one-line summary goes to stdout; run-images.sh appends it to environment.txt.
"""

import csv
import json
import math
import os
import sys


HEADER = ["vm", "script", "mean_ns", "median_ns", "min_ns", "max_ns", "stddev_ns", "iterations"]


def normalize(run_dir: str) -> None:
    output_path = os.path.join(run_dir, "unified.csv")
    rows = []

    for vm_file in sorted(os.listdir(run_dir)):
        path = os.path.join(run_dir, vm_file)
        if (vm_file == "unified.csv" or vm_file.endswith(("-eval.csv", "-drift.csv", "-warmup.csv"))
                or not vm_file.endswith(".csv") or not os.path.isfile(path)):
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


def read_times(path: str) -> dict[str, float]:
    """{script: mean_ns} of the rows with a timing."""
    out = {}
    with open(path) as f:
        for row in csv.DictReader(f):
            try:
                ns = float(row["mean_ns"])
            except (KeyError, TypeError, ValueError):
                continue
            if ns > 0:
                out[row["script"]] = ns
    return out


def drift(run_dir: str, vm: str = "haskell") -> str | None:
    """Write drift.json from <vm>.csv (start) and <vm>-drift.csv (end); return the summary line."""
    start_path = os.path.join(run_dir, f"{vm}.csv")
    end_path = os.path.join(run_dir, f"{vm}-drift.csv")
    out_path = os.path.join(run_dir, "drift.json")
    if os.path.exists(out_path):
        os.remove(out_path)
    if not (os.path.isfile(start_path) and os.path.isfile(end_path)):
        return None
    start, end = read_times(start_path), read_times(end_path)
    common = sorted(set(start) & set(end))
    if not common:
        return f"drift ({vm}, end vs start): no script with a timing in both runs"
    per_script = {s: {"start_ns": start[s], "end_ns": end[s], "ratio": end[s] / start[s]} for s in common}
    ratio = math.exp(sum(math.log(v["ratio"]) for v in per_script.values()) / len(common))
    percent = (ratio - 1) * 100
    with open(out_path, "w") as f:
        json.dump({"vm": vm, "ratio": ratio, "percent": percent, "scripts": per_script}, f, indent=2)
        f.write("\n")
    print(f"  wrote: {out_path}", file=sys.stderr)
    return f"drift ({vm}, end vs start): {percent:+.1f} % over {len(common)} scripts"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <run-dir>", file=sys.stderr)
        sys.exit(1)
    normalize(sys.argv[1])
    line = drift(sys.argv[1])
    if line:
        print(line)
