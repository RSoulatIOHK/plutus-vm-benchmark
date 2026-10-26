#!/usr/bin/env python3
"""Parse llvm-uplc JSON benchmark output (uplcbench format) into unified CSV.

Usage: parse_llvm_uplc_json.py <vm-name> <json> [<json> ...]

Each file is {"benchmarks": [{"name", "mean_ns", "median_ns", "min_ns", "max_ns", "stddev_ns",
"iterations"}, ...], "failures": [...]}. scripts/run-llvm-uplc-jit.sh writes one per script. A
failed script has no row; fill_failures.py adds its -1 row.
"""

import json
import sys

HEADER = "vm,script,mean_ns,median_ns,min_ns,max_ns,stddev_ns,iterations"


def parse(vm: str, paths: list[str]) -> None:
    print(HEADER)
    for path in paths:
        try:
            with open(path) as f:
                data = json.load(f)
        except (OSError, json.JSONDecodeError) as e:
            print(f"WARNING: {path}: {e}", file=sys.stderr)
            continue
        for b in data.get("benchmarks", []):
            print(
                f"{vm},{b['name']},{b['mean_ns']},{b['median_ns']},{b['min_ns']},"
                f"{b['max_ns']},{b['stddev_ns']},{b['iterations']}"
            )


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <vm-name> <json> [<json> ...]", file=sys.stderr)
        sys.exit(1)
    parse(sys.argv[1], sys.argv[2:])
