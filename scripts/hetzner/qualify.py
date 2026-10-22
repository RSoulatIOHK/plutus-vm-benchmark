#!/usr/bin/env python3
"""Server qualification: compare the Haskell timing of a new bench server with a stored reference.

Hetzner servers of one type differ: one ccx43 ran every VM 2.1x slower than another ccx43 (same
CPU model, 0 % steal). So each run first times the Haskell image (the reference VM) on a few
scripts and compares the geometric mean of measured/reference with check/reference/host-reference.json.

    qualify.py decide <haskell.csv> <server-type> [--reference FILE] [--max-ratio 1.15]
        Prints one line, "<verdict> <ratio> <text>". Exit 0 pass, 1 too slow, 2 no reference for
        the server type (skip qualification), 3 bad input (a script is missing from the CSV).
    qualify.py reference <haskell.csv> <server-type> --harness SHA [--measured DATE] [--reference FILE]
        Prints host-reference.json with the entry of <server-type> taken from <haskell.csv> (the
        haskell.csv of a full run on a good server, or of a qualification run). Use it to refresh
        the reference when the Haskell harness or the pins change.

The CSV is the d3 file of the Haskell image (haskell.csv: vm,script,mean_ns,...). The reference
entry is {"<script>": <mean_ns>, ..., "harness": "<sha>", "measured": "<date>"}: every numeric
key is a script.
"""

from __future__ import annotations

import argparse
import csv
import datetime
import json
import math
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_REFERENCE = os.path.join(REPO_ROOT, "check", "reference", "host-reference.json")
DEFAULT_MAX_RATIO = 1.15
# The scripts a qualification times, when the reference does not name them (reference command).
SCRIPTS = ("auction_1-1", "coop-6", "uniswap-1")

PASS, SLOW, NO_REFERENCE, BAD_INPUT = 0, 1, 2, 3


def read_means(path: str) -> dict[str, float]:
    """mean_ns per script of a haskell.csv."""
    with open(path, newline="") as f:
        return {row["script"]: float(row["mean_ns"]) for row in csv.DictReader(f)}


def reference_scripts(entry: dict) -> dict[str, float]:
    return {k: float(v) for k, v in entry.items() if isinstance(v, (int, float))}


def decide(means: dict[str, float], reference: dict, server_type: str,
           max_ratio: float = DEFAULT_MAX_RATIO) -> tuple[int, float | None, str]:
    """(exit code, geo ratio or None, text). Ratio > max_ratio is too slow; faster always passes."""
    entry = reference.get(server_type)
    if not entry or not reference_scripts(entry):
        measured = ", ".join(f"{s} {means[s]:.0f}" for s in sorted(means))
        return NO_REFERENCE, None, f"no reference for server type {server_type}; measured ns: {measured or 'none'}"
    ref = reference_scripts(entry)
    missing = sorted(s for s in ref if s not in means or means[s] <= 0)
    if missing:
        return BAD_INPUT, None, f"no timing for {', '.join(missing)}"
    # Rounded to the printed precision, so the verdict and the printed ratio agree at the limit.
    ratio = round(math.exp(sum(math.log(means[s] / ref[s]) for s in ref) / len(ref)), 3)
    detail = ", ".join(f"{s} {means[s] / ref[s]:.2f}" for s in sorted(ref))
    source = f"{server_type} reference (harness {entry.get('harness', '?')}, {entry.get('measured', '?')})"
    if ratio > max_ratio:
        return SLOW, ratio, f"haskell geo ratio {ratio:.3f} > {max_ratio} vs {source}: {detail}"
    return PASS, ratio, f"haskell geo ratio {ratio:.3f} <= {max_ratio} vs {source}: {detail}"


def load_reference(path: str) -> dict:
    if not os.path.exists(path):
        return {}
    with open(path) as f:
        return json.load(f)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("decide")
    d.add_argument("csv")
    d.add_argument("server_type")
    d.add_argument("--reference", default=DEFAULT_REFERENCE)
    d.add_argument("--max-ratio", type=float, default=DEFAULT_MAX_RATIO)
    r = sub.add_parser("reference")
    r.add_argument("csv")
    r.add_argument("server_type")
    r.add_argument("--harness", required=True)
    r.add_argument("--measured", default=datetime.date.today().isoformat())
    r.add_argument("--reference", default=DEFAULT_REFERENCE)
    a = p.parse_args(argv)

    if a.cmd == "decide":
        # A missing reference skips the qualification even when the timing failed.
        try:
            means = read_means(a.csv)
        except (OSError, KeyError, ValueError) as e:
            print(f"cannot read {a.csv}: {e}", file=sys.stderr)
            means = {}
        code, ratio, text = decide(means, load_reference(a.reference), a.server_type, a.max_ratio)
        verdict = {PASS: "pass", SLOW: "slow", NO_REFERENCE: "skip", BAD_INPUT: "error"}[code]
        print(f"{verdict} {'-' if ratio is None else f'{ratio:.3f}'} {text}")
        return code

    means = read_means(a.csv)
    missing = [s for s in SCRIPTS if s not in means]
    if missing:
        print(f"{a.csv} has no timing for {', '.join(missing)}", file=sys.stderr)
        return BAD_INPUT
    reference = load_reference(a.reference)
    reference[a.server_type] = {**{s: round(means[s]) for s in SCRIPTS},
                                "harness": a.harness, "measured": a.measured}
    print(json.dumps(reference, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
