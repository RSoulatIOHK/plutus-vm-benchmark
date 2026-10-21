#!/usr/bin/env python3
"""Correctness gate: compare <vm>-check.csv files with the Haskell reference.

A VM passes when, for every script in the reference, its row has the same status, cpu and mem.
A VM with an empty cpu or mem fails as "no costing". See check/README.md.

Usage:
    python3 check/gate.py [--reference check/reference/haskell-check.csv]
                          [--json verdict.json] VM_CHECK_CSV [VM_CHECK_CSV ...]

Exit code: 0 if every VM passes, 1 if any VM fails, 2 on bad input.
Python 3.10+ (stdlib only).
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys

FIELDS = ("vm", "script", "status", "cpu", "mem")
DEFAULT_REFERENCE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reference", "haskell-check.csv")


class InputError(Exception):
    pass


def read_check_csv(path: str) -> tuple[str, dict[str, dict[str, str]]]:
    """Return (vm name, {script: row}) for a check csv."""
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        missing = [c for c in FIELDS if c not in (reader.fieldnames or [])]
        if missing:
            raise InputError(f"{path}: missing columns {missing}, expected {','.join(FIELDS)}")
        rows: dict[str, dict[str, str]] = {}
        vms = set()
        for row in reader:
            row = {k: (row[k] or "").strip() for k in FIELDS}
            if not row["script"]:
                continue
            if row["script"] in rows:
                raise InputError(f"{path}: duplicate script {row['script']}")
            vms.add(row["vm"])
            rows[row["script"]] = row
    if len(vms) != 1:
        raise InputError(f"{path}: expected exactly one vm name, found {sorted(vms)}")
    return vms.pop(), rows


def parse_int(s: str) -> int | None:
    try:
        return int(s)
    except ValueError:
        return None


def compare(reference: dict[str, dict[str, str]], rows: dict[str, dict[str, str]]) -> dict:
    """Compare one VM's rows with the reference. Returns a verdict dict."""
    mismatches = []
    no_costing = False
    for script in sorted(reference):
        ref = reference[script]
        row = rows.get(script)
        if row is None:
            mismatches.append({"script": script, "reason": "missing"})
            continue
        if row["cpu"] == "" or row["mem"] == "":
            no_costing = True
        diff = {}
        if row["status"] != ref["status"]:
            diff["status"] = {"expected": ref["status"], "actual": row["status"]}
        for col in ("cpu", "mem"):
            if parse_int(row[col]) is None or parse_int(row[col]) != parse_int(ref[col]):
                diff[col] = {"expected": ref[col], "actual": row[col]}
        if diff:
            mismatches.append({"script": script, "reason": "mismatch", **diff})
    extra = sorted(set(rows) - set(reference))
    passed = not mismatches and not no_costing
    return {
        "verdict": "pass" if passed else "fail",
        "no_costing": no_costing,
        "scripts": len(reference),
        "matching": len(reference) - len(mismatches),
        "mismatches": mismatches,
        "extra_scripts": extra,
    }


def describe(m: dict) -> str:
    if m["reason"] == "missing":
        return f"{m['script']}: missing"
    parts = [f"{c} {m[c]['actual'] or '<empty>'} != {m[c]['expected']}" for c in ("status", "cpu", "mem") if c in m]
    return f"{m['script']}: " + ", ".join(parts)


def summary(verdicts: dict[str, dict], limit: int = 10) -> str:
    lines = []
    for vm, v in verdicts.items():
        head = f"{vm}: {v['verdict'].upper()} ({v['matching']}/{v['scripts']} scripts match)"
        if v["no_costing"]:
            head += " - no costing (empty cpu/mem)"
        lines.append(head)
        for m in v["mismatches"][:limit]:
            lines.append("    " + describe(m))
        if len(v["mismatches"]) > limit:
            lines.append(f"    ... {len(v['mismatches']) - limit} more")
        if v["extra_scripts"]:
            lines.append(f"    warning: {len(v['extra_scripts'])} scripts not in the reference: "
                         + ", ".join(v["extra_scripts"][:limit]))
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Compare <vm>-check.csv files with the Haskell reference.")
    p.add_argument("--reference", default=DEFAULT_REFERENCE, help="reference csv (default: %(default)s)")
    p.add_argument("--json", help="write the machine-readable verdict to this file ('-' for stdout)")
    p.add_argument("checks", nargs="+", help="<vm>-check.csv files")
    args = p.parse_args(argv)

    try:
        _, reference = read_check_csv(args.reference)
        verdicts: dict[str, dict] = {}
        for path in args.checks:
            vm, rows = read_check_csv(path)
            if vm in verdicts:
                raise InputError(f"{path}: vm {vm} given twice")
            verdicts[vm] = compare(reference, rows)
    except (OSError, InputError) as e:
        print(f"gate: {e}", file=sys.stderr)
        return 2

    result = {"reference": args.reference, "pass": all(v["verdict"] == "pass" for v in verdicts.values()),
              "vms": verdicts}
    if args.json == "-":
        json.dump(result, sys.stdout, indent=2)
        print()
        print(summary(verdicts), file=sys.stderr)
    else:
        if args.json:
            with open(args.json, "w") as f:
                json.dump(result, f, indent=2)
                f.write("\n")
        print(summary(verdicts))
    return 0 if result["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
