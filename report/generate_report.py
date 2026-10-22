#!/usr/bin/env python3
"""Generate markdown and HTML comparison reports from unified.csv.

Usage: generate_report.py [--write-index] <run-dir>
Writes <run-dir>/report.md and <run-dir>/index.html. With --write-index, also writes the same page
to <repo>/docs/index.html, the published page: only run.yml sets it, for a published run. Then it
also writes docs/robots.txt, docs/sitemap.xml and docs/og.png (the link-preview image, a headless
Chrome screenshot; without Chrome the committed og.png stays).

Reads from the run dir:
- unified.csv            timings of every VM
- gate.json              correctness verdicts (check/gate.py). When present, a VM with verdict
                         "fail" or without a verdict is hidden and listed as "failed check"; a VM
                         with verdict "badge" is shown with an "outdated cost model" badge. Old runs
                         without gate.json are shown as they are
- <vm>-compile.csv       compile time per script (vm,script,compile_ns), for VMs that compile
                         before they run: "decode and compile excluded" badge and a
                         compile-time column
- <vm>-eval.csv          eval-only timing (program decoded once before the timed loop): an "eval
                         only" column next to the D3 time and its geometric mean. Not for a VM
                         with <vm>-compile.csv: its D3 time already is the eval time. The ranking
                         stays on the D3 time
A VM in EXPERIMENTAL that passes the gate is shown in its own "Experimental" section with its
numbers, but it is not ranked: not in the summary ranking, not a competitor in the penalty rule,
not in "vs fastest", the per-script fastest or the history chart.
- drift.json             the drift probe (parsers/normalize.py): Haskell at the end of the run
                         vs the start, shown as a note
- ../<date>/             earlier runs next to this one, for the history chart: each VM's geometric
                         mean divided by Haskell's from the same run. Only runs with gate.json count
"""

from __future__ import annotations

import base64
import csv
import datetime
import glob
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
from collections import defaultdict
from html import escape

VM_ORDER = [
    "haskell", "scalus-jit", "scalus-cek", "scalus-js",
    "aiken", "aiken-wasm", "uplc-turbo",
    "plutigo", "blaze-jsc", "blaze-v8",
]

# The header logo in report/template.html, a file in docs/.
LOGO = "lantr-logo-dark.png"
# The published site: docs/index.html and its static files.
DOCS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs")

# {n}: the number of scripts of the run.
DISCLOSURE = (
    "The {n} scripts are PlutusV1-era programs. Every VM evaluates them as PlutusV3 programs at "
    "protocol version 11 with the mainnet cost model, like Plutus's own `validation` CEK benchmark; "
    "the node would run them as PlutusV1."
)

# One note per VM, shown on its card and in report.md. Markdown links [text](url) only.
VM_NOTES = {
    "aiken": "Aiken v1.1.24 copies the CEK environment on every lambda application (quadratic in "
             "recursion depth). aiken main fixes it (PRs "
             "[#1451](https://github.com/aiken-lang/aiken/pull/1451), "
             "[#1452](https://github.com/aiken-lang/aiken/pull/1452): coop-6 92 ms -> 1.2 ms), "
             "but no release contains the fix yet.",
    "aiken-wasm": "Built from [colll78/aiken](https://github.com/colll78/aiken) (aiken main plus "
                  "fixes), which includes the CEK fixes that v1.1.24 lacks.",
}

# Badges for the way a VM is timed, besides the gate and compile badges: {vm: {text, title}}. The
# title explains the badge (HTML tooltip, a note in report.md).
VM_BADGES = {
    # images/aiken-wasm/README.md
    "aiken-wasm": {
        "text": "decode cached (by the library)",
        "title": "The library caches the decoded program by a hash of the flat bytes. After the first "
                 "call (in the warm-up), the timed loop runs hash + evaluation, without the decode. "
                 "Its eval-only time is the same loop.",
    },
}

# VMs that are run, gated and shown with their numbers, but not ranked (spec D17): {vm: reason}.
EXPERIMENTAL = {
    "scalus-jit": "not ranked: the JIT module is not published as a release artifact and has no "
                  "downstream users yet (spec D17)",
}

# The badge of a VM with <vm>-compile.csv (Scalus JIT): its timed loop runs the compiled script,
# so neither the flat decode nor the compile step is in its time.
COMPILE_BADGE = "decode and compile excluded"

VM_LABELS = {
    "uplc-turbo": "uplc-turbo AST walker (Rust)",
    "plutigo": "Plutigo CEK (Go)",
    "blaze-jsc": "blaze-plutus CEK (TypeScript / Bun JSC)",
    "blaze-v8": "blaze-plutus CEK (TypeScript / Node V8)",
    "haskell": "plutus-core CEK (Haskell / GHC)",
    "scalus-cek": "Scalus CEK (Scala / JVM)",
    "scalus-jit": "Scalus UPLC→JVM JIT (Scala / JVM)",
    "scalus-js": "Scalus CEK (Scala.js / Node V8)",
    "aiken": "Aiken uplc CEK (Rust)",
    "aiken-wasm": "Aiken uplc CEK (Rust → WASM / Node V8)",
}


def fmt_ns(ns: int) -> str:
    """Format nanoseconds into human-readable string."""
    if ns >= 1_000_000_000:
        return f"{ns / 1e9:.2f} s"
    if ns >= 1_000_000:
        return f"{ns / 1e6:.2f} ms"
    if ns >= 1_000:
        return f"{ns / 1e3:.2f} us"
    return f"{ns} ns"


def geometric_mean(values: list[float]) -> float:
    """Compute geometric mean of positive values."""
    if not values:
        return 0
    log_sum = sum(math.log(v) for v in values if v > 0)
    return math.exp(log_sum / len(values))


def load_data(run_dir: str):
    """Load unified.csv and return (data, scripts, present_vms, env_info)."""
    unified_path = os.path.join(run_dir, "unified.csv")
    if not os.path.isfile(unified_path):
        print("Error: unified.csv not found", file=sys.stderr)
        sys.exit(1)

    data: dict[str, dict[str, int]] = defaultdict(dict)
    with open(unified_path) as f:
        for row in csv.DictReader(f):
            vm = row["vm"]
            script = row["script"]
            mean_ns = int(row["mean_ns"])
            data[script][vm] = mean_ns

    scripts = sorted(data.keys())
    found = {vm for s in scripts for vm in data[s]}
    present_vms = [vm for vm in VM_ORDER if vm in found] + sorted(found - set(VM_ORDER))

    env_path = os.path.join(run_dir, "environment.txt")
    env_info = ""
    if os.path.isfile(env_path):
        with open(env_path) as f:
            env_info = f.read().strip()

    return data, scripts, present_vms, env_info


def load_gate(run_dir: str) -> dict | None:
    """The gate verdicts of the run, or None for a run without gate.json (old format)."""
    path = os.path.join(run_dir, "gate.json")
    if not os.path.isfile(path):
        return None
    with open(path) as f:
        gate = json.load(f)
    return gate if isinstance(gate.get("vms"), dict) else None


def gate_split(gate: dict | None, vms: list[str]) -> tuple[list[str], dict[str, str]]:
    """(shown VMs, {hidden VM: reason}). Without gate.json every VM is shown."""
    if gate is None:
        return list(vms), {}
    shown, hidden = [], {}
    for vm in vms:
        v = gate["vms"].get(vm)
        if v is None:
            hidden[vm] = f"no {vm}-check.csv"
        elif v.get("verdict") == "fail":
            hidden[vm] = v.get("reason", "failed")
        else:
            shown.append(vm)
    return shown, hidden


def load_compile(run_dir: str) -> dict[str, dict[str, int]]:
    """{vm: {script: compile_ns}} from every <vm>-compile.csv of the run."""
    out: dict[str, dict[str, int]] = {}
    for path in sorted(glob.glob(os.path.join(run_dir, "*-compile.csv"))):
        with open(path) as f:
            for row in csv.DictReader(f):
                try:
                    ns = int(float(row["compile_ns"]))
                except (KeyError, TypeError, ValueError):
                    continue
                if ns > 0:
                    out.setdefault(row["vm"], {})[row["script"]] = ns
    return out


def load_eval(run_dir: str) -> dict[str, dict[str, int]]:
    """{vm: {script: mean_ns}} from every <vm>-eval.csv of the run (successful rows only)."""
    out: dict[str, dict[str, int]] = {}
    for path in sorted(glob.glob(os.path.join(run_dir, "*-eval.csv"))):
        with open(path) as f:
            for row in csv.DictReader(f):
                try:
                    ns = int(float(row["mean_ns"]))
                except (KeyError, TypeError, ValueError):
                    continue
                if ns > 0:
                    out.setdefault(row["vm"], {})[row["script"]] = ns
    return out


def ratio_to_haskell(data: dict[str, dict[str, int]], vm: str) -> float | None:
    """Geometric mean of vm/haskell over the scripts where both have a timing."""
    logs = [math.log(t[vm] / t["haskell"]) for t in data.values()
            if t.get(vm, 0) > 0 and t.get("haskell", 0) > 0]
    return math.exp(sum(logs) / len(logs)) if logs else None


def load_drift(run_dir: str) -> dict | None:
    """drift.json of the run (parsers/normalize.py), or None."""
    path = os.path.join(run_dir, "drift.json")
    if not os.path.isfile(path):
        return None
    with open(path) as f:
        drift = json.load(f)
    return drift if isinstance(drift.get("percent"), (int, float)) else None


def drift_text(drift: dict | None) -> str:
    if drift is None:
        return ""
    vm = "Haskell" if drift.get("vm") == "haskell" else drift.get("vm", "?")
    return (f"Drift ({vm}, end vs start): {drift['percent']:+.1f} % over {len(drift.get('scripts', {}))} "
            f"scripts. The run timed Haskell again at its end; this is the change of its time.")


def load_history(run_dir: str) -> dict:
    """Ratio to Haskell per VM for every run next to run_dir that has gate.json (new format).

    A run counts only if Haskell passed its gate there; a VM that failed the gate in a run has no
    point for that run. An EXPERIMENTAL VM has a line too; the page draws it dashed and marks it.
    """
    parent = os.path.dirname(os.path.abspath(run_dir))
    runs: list[str] = []
    series: dict[str, list[float | None]] = {}
    for d in sorted(os.listdir(parent)):
        rd = os.path.join(parent, d)
        gate = load_gate(rd)
        unified = os.path.join(rd, "unified.csv")
        if gate is None or not os.path.isfile(unified):
            continue
        data: dict[str, dict[str, int]] = defaultdict(dict)
        with open(unified) as f:
            for row in csv.DictReader(f):
                data[row["script"]][row["vm"]] = int(row["mean_ns"])
        vms = sorted({vm for t in data.values() for vm in t})
        shown, _ = gate_split(gate, vms)
        if "haskell" not in shown:
            continue
        idx = len(runs)
        runs.append(d)
        for vm in shown:
            r = ratio_to_haskell(data, vm)
            if r is not None:
                series.setdefault(vm, [None] * idx)
        for vm in series:
            series[vm].append(ratio_to_haskell(data, vm) if vm in shown else None)
    order = {vm: i for i, vm in enumerate(VM_ORDER)}
    return {"runs": runs,
            "series": {vm: series[vm] for vm in sorted(series, key=lambda v: (order.get(v, 99), v))}}


def compute_geo_means(data, scripts, present_vms):
    """Compute geometric means with penalty for missing scripts.

    When a VM hasn't implemented a benchmark script, it gets assigned
    the score of the slowest competitor on that script. This prevents
    VMs from gaming the leaderboard by selectively skipping slow tests.
    """
    geo_means: dict[str, float] = {}

    for vm in present_vms:
        values = []
        for s in scripts:
            t = data[s].get(vm, 0)
            if t > 0:
                values.append(t)
            else:
                # Missing or failed: assign the slowest successful time
                # from any other VM on this script
                worst = max(
                    (data[s].get(other_vm, 0) for other_vm in present_vms if other_vm != vm),
                    default=0,
                )
                if worst > 0:
                    values.append(worst)
                # If no VM has a result for this script, skip it entirely

        geo_means[vm] = geometric_mean(values)

    return geo_means


def experimental_geo_mean(data, scripts, ranked: list[str], vm: str) -> float:
    """Geometric mean of an EXPERIMENTAL VM, with the penalty rule against the ranked VMs only."""
    return compute_geo_means(data, scripts, ranked + [vm])[vm]


def badge_text(vm: str) -> str:
    """The VM_BADGES text in parentheses, or ''."""
    return f" ({VM_BADGES[vm]['text']})" if vm in VM_BADGES else ""


def generate_markdown(run_dir: str, data, scripts, present_vms, experimental, env_info, gate, hidden,
                      compile_ns, eval_ns, history, drift) -> None:
    """Generate report.md. present_vms are the ranked VMs; experimental the shown, unranked ones."""
    geo_means = compute_geo_means(data, scripts, present_vms)
    all_vms = present_vms + experimental

    fastest_geo = min(geo_means.values()) if geo_means else 1

    lines = []
    lines.append("# Plutus VM Benchmark Results")
    lines.append("")
    date = os.path.basename(run_dir)
    lines.append(f"**Date:** {date}")
    lines.append("")

    if env_info:
        lines.append("## Environment")
        lines.append("```")
        lines.append(env_info)
        lines.append("```")
        lines.append("")

    lines.append(f"*{DISCLOSURE.format(n=len(scripts))}*")
    lines.append("")
    if drift:
        lines.append(f"*{drift_text(drift)}*")
        lines.append("")

    lines.append("## Summary (geometric mean across all scripts)")
    lines.append("")
    lines.append("*Note: VMs that fail or skip a script are assigned the slowest competitor's time for that script.*")
    if compile_ns:
        lines.append(f"*A compiling VM's timed loop runs the compiled script (\"{COMPILE_BADGE}\": the "
                     "decode and the compile run once per script, before timing). The Compile column "
                     "is the geometric mean of the compile time over the scripts.*")
    if eval_ns:
        lines.append("*Geo Mean: flat decode + evaluation (the ranking). Eval only: evaluation of a "
                     "program decoded before the timed loop, geometric mean over its scripts.*")
    for vm in all_vms:
        if vm in VM_BADGES:
            lines.append(f"*{VM_LABELS.get(vm, vm)}, \"{VM_BADGES[vm]['text']}\": {VM_BADGES[vm]['title']}*")
    lines.append("")
    lines.append("| VM | Language | Geo Mean | vs Fastest | Eval only | Compile | Check |")
    lines.append("|---|---|---|---|---|---|---|")

    sorted_vms = sorted(present_vms, key=lambda vm: geo_means.get(vm, float("inf")))
    for vm in sorted_vms:
        label = VM_LABELS.get(vm, vm)
        lang = label.split("(")[-1].rstrip(")") if "(" in label else ""
        geo = geo_means[vm]
        ratio = geo / fastest_geo if fastest_geo > 0 else 0
        comp = compile_ns.get(vm)
        comp_cell = f"{fmt_ns(int(geometric_mean(list(comp.values()))))} ({COMPILE_BADGE})" if comp else "-"
        ev = eval_ns.get(vm)
        eval_cell = fmt_ns(int(geometric_mean(list(ev.values())))) if ev else "-"
        geo_cell, ratio_cell = (fmt_ns(int(geo)), f"{ratio:.2f}x") if geo > 0 else ("-", "-")
        lines.append(f"| **{label}**{badge_text(vm)} | {lang} | {geo_cell} | {ratio_cell} | {eval_cell} | "
                     f"{comp_cell} | {check_label(gate, vm)} |")

    if experimental:
        lines.append("")
        lines.append("### Experimental")
        lines.append("")
        lines.append("Run, gated and shown, but not ranked: not in the table above, not a competitor "
                     "in the penalty rule, not in the history. Geo Mean uses the penalty rule against "
                     "the ranked VMs.")
        lines.append("")
        lines.append("| VM | Language | Geo Mean | Eval only | Compile | Check | Reason |")
        lines.append("|---|---|---|---|---|---|---|")
        for vm in experimental:
            label = VM_LABELS.get(vm, vm)
            lang = label.split("(")[-1].rstrip(")") if "(" in label else ""
            geo = experimental_geo_mean(data, scripts, present_vms, vm)
            comp = compile_ns.get(vm)
            comp_cell = f"{fmt_ns(int(geometric_mean(list(comp.values()))))} ({COMPILE_BADGE})" if comp else "-"
            ev = eval_ns.get(vm)
            eval_cell = fmt_ns(int(geometric_mean(list(ev.values())))) if ev else "-"
            geo_cell = fmt_ns(int(geo)) if geo > 0 else "-"
            lines.append(f"| **{label}**{badge_text(vm)} | {lang} | {geo_cell} | {eval_cell} | {comp_cell} | "
                         f"{check_label(gate, vm)} | {EXPERIMENTAL[vm]} |")

    if hidden:
        lines.append("")
        lines.append("### Failed check")
        lines.append("")
        lines.append("Not ranked: the result or the ExUnits differ from Haskell (check/README.md).")
        lines.append("")
        lines.append("| VM | Reason |")
        lines.append("|---|---|")
        for vm in sorted(hidden, key=lambda v: (VM_ORDER.index(v) if v in VM_ORDER else 99, v)):
            lines.append(f"| {VM_LABELS.get(vm, vm)} | {hidden[vm]} |")

    notes = [vm for vm in sorted_vms + experimental if vm in VM_NOTES]
    if notes:
        lines.append("")
        lines.append("### Notes")
        lines.append("")
        for vm in notes:
            lines.append(f"- **{VM_LABELS.get(vm, vm)}**: {VM_NOTES[vm]}")

    if history["runs"]:
        lines.append("")
        lines.append("### History (speed relative to Haskell plutus-core, same run; higher is faster)")
        lines.append("")
        lines.append("| VM | " + " | ".join(history["runs"]) + " |")
        lines.append("|---|" + "---|" * len(history["runs"]))
        for vm, values in history["series"].items():
            cells = [speed_text(v) if v is not None else "-" for v in values]
            tag = " (experimental)" if vm in EXPERIMENTAL else ""
            lines.append(f"| {VM_LABELS.get(vm, vm)}{tag} | " + " | ".join(cells) + " |")

    # Count scripts per VM
    lines.append("")
    lines.append("### Script Coverage")
    lines.append("")
    lines.append("| VM | Passed | Failed | Missing | Total |")
    lines.append("|---|---|---|---|---|")
    for vm in sorted_vms + experimental:
        success = sum(1 for s in scripts if data[s].get(vm, 0) > 0)
        fail = sum(1 for s in scripts if data[s].get(vm, 0) < 0)
        missing = len(scripts) - success - fail
        tag = " (experimental)" if vm in EXPERIMENTAL else ""
        lines.append(f"| {VM_LABELS.get(vm, vm)}{tag} | {success} | {fail} | {missing} | {len(scripts)} |")

    lines.append("")

    lines.append("## Per-Script Results")
    lines.append("")
    # Each VM's D3 column, followed by its eval-only column if it has <vm>-eval.csv. The experimental
    # VMs come last and are never the bold fastest.
    columns = [c for vm in all_vms for c in ([(vm, False), (vm, True)] if vm in eval_ns else [(vm, False)])]
    header = "| Script |" + "|".join(
        f" {VM_LABELS.get(vm, vm)}{' (experimental)' if vm in EXPERIMENTAL else ''}"
        f"{' (eval only)' if ev else ''} " for vm, ev in columns) + "|"
    separator = "|---|" + "|".join("---" for _ in columns) + "|"
    lines.append(header)
    lines.append(separator)

    for script in scripts:
        row = f"| {script} |"
        script_times = {vm: data[script].get(vm, 0) for vm in all_vms}
        ranked_times = [script_times[vm] for vm in present_vms if script_times[vm] > 0]
        fastest = min(ranked_times, default=0)

        for vm, ev in columns:
            if ev:
                e = eval_ns[vm].get(script, 0)
                row += f" {fmt_ns(e)} |" if e > 0 else " - |"
                continue
            t = script_times[vm]
            if t > 0:
                cell = fmt_ns(t)
                if vm not in EXPERIMENTAL and t == fastest and len(ranked_times) > 1:
                    cell = f"**{cell}**"
                row += f" {cell} |"
            elif t < 0:
                row += " FAIL |"
            else:
                row += " - |"
        lines.append(row)

    lines.append("")
    lines.append("---")
    harness = harness_commit(env_info)
    if harness:
        lines.append(f"Harness commit: [`{harness[:9]}`]({REPO_URL}/commit/{harness})")
        lines.append("")
    lines.append("*Plutus VM Benchmark – maintained by [Lantr](https://lantr.io) – Alexander Nemish. "
                 "Forked from [SAIB-Inc/cardano-plutus-vm-benchmark](https://github.com/SAIB-Inc/cardano-plutus-vm-benchmark) "
                 "by SAIB Inc. and contributors. MIT License, original work © 2025 SAIB Inc., © 2026 Lantr. "
                 "Source: [lantr-io/plutus-vm-benchmark](https://github.com/lantr-io/plutus-vm-benchmark)*")

    report = "\n".join(lines)
    report_path = os.path.join(run_dir, "report.md")
    with open(report_path, "w") as f:
        f.write(report)

    print(report)
    print(f"\nReport saved to: {report_path}", file=sys.stderr)


def check_label(gate: dict | None, vm: str) -> str:
    if gate is None:
        return "not checked"
    verdict = gate["vms"].get(vm, {}).get("verdict")
    return {"pass": "pass", "badge": "outdated cost model"}.get(verdict, "failed check")


REPO_URL = "https://github.com/lantr-io/plutus-vm-benchmark"


def speed_text(ratio):
    """Time ratio VM / Haskell as speed text: 0.25 -> '4.0x faster', 2.5 -> '2.5x slower'."""
    if ratio <= 0:
        return "-"
    if abs(ratio - 1) < 0.01:
        return "1x (Haskell)"
    s = 1 / ratio
    return f"{s:.1f}x faster" if s > 1 else f"{ratio:.1f}x slower"


def harness_commit(env_info):
    """The harness commit of the run (environment.txt "harness: <sha>"), or None."""
    for line in (env_info or "").split("\n"):
        key, _, value = line.strip().partition(":")
        value = value.strip()
        if key.lower() == "harness" and value and value != "unknown":
            return value
    return None


def generate_html(run_dir: str, env_info: str, data, scripts, present_vms, experimental, gate, hidden,
                  compile_ns, eval_ns, history, drift, write_index: bool) -> None:
    """Generate <run_dir>/index.html from template + the timings of the shown VMs (ranked and
    experimental; the page leaves the experimental ones out of the ranking).

    With write_index, also <repo>/docs/index.html, the published page (run.yml sets it).
    """
    template_path = os.path.join(os.path.dirname(__file__), "template.html")

    if not os.path.isfile(template_path):
        print("Warning: report/template.html not found, skipping HTML generation", file=sys.stderr)
        return

    with open(template_path) as f:
        template = f.read()

    # Only the shown VMs: a hidden VM must not be a competitor in the penalty rule either.
    shown = set(present_vms) | set(experimental)
    with open(os.path.join(run_dir, "unified.csv")) as f:
        lines = f.read().strip().split("\n")
    csv_data = "\n".join([lines[0]] + [l for l in lines[1:] if l.split(",", 1)[0] in shown])

    report = {
        "gate": None if gate is None else {
            vm: {"verdict": v.get("verdict"), "mode": v.get("mode"), "reason": v.get("reason")}
            for vm, v in gate["vms"].items()},
        "hidden": hidden,
        "compile": {vm: s for vm, s in compile_ns.items() if vm in shown},
        "eval": {vm: s for vm, s in eval_ns.items() if vm in shown},
        "history": history,
        "disclosure": DISCLOSURE.format(n=len(scripts)),
        "notes": {vm: n for vm, n in VM_NOTES.items() if vm in shown},
        "compile_badge": COMPILE_BADGE,
        "badges": {vm: b for vm, b in VM_BADGES.items() if vm in shown},
        "experimental": {vm: EXPERIMENTAL[vm] for vm in experimental},
        "drift": drift_text(drift),
        "drift_percent": drift["percent"] if drift else None,
        "run": os.path.basename(os.path.abspath(run_dir)),
    }
    # Safe inside <script>: no "</" can close the element.
    report_json = json.dumps(report, ensure_ascii=False).replace("</", "<\\/")

    # Build environment badge
    if env_info:
        env_badge = ""
        # environment.txt of run-images.sh has lowercase keys (cpu:, cores:, memory:).
        for line in env_info.split("\n"):
            key, _, value = line.strip().partition(":")
            key, value = key.lower(), value.strip()
            if key == "cpu":
                env_badge += f"<code>{value}</code>"
            elif key == "cores":
                env_badge += f" &middot; {value} cores"
            elif key in ("ram", "memory"):
                env_badge += f" &middot; {value}"
            elif key == "os":
                env_badge += f" &middot; {value}"
        date = os.path.basename(run_dir)
        env_badge += f" &middot; {date}"
    else:
        env_badge = os.path.basename(run_dir)

    harness = harness_commit(env_info)
    if harness:
        harness_link = f'<a href="{REPO_URL}/commit/{harness}"><code>{harness[:9]}</code></a>'
        env_badge += f' &middot; harness {harness_link}'
    else:
        harness_link = "unknown"

    html = (template.replace("{{CSV_DATA}}", csv_data).replace("{{ENV_BADGE}}", env_badge)
            .replace("{{HARNESS_LINK}}", harness_link)
            .replace("{{REPORT_JSON}}", report_json))
    seo = seo_parts(run_dir, data, scripts, present_vms, experimental, gate, eval_ns)
    html = html.replace("{{SEO_HEAD}}", seo["head"])
    for key in ("{{SEO_INTRO}}", "{{SEO_SUMMARY_SUB}}", "{{SEO_SUMMARY}}", "{{SEO_FAQ}}"):
        html = html.replace(key, seo[key])

    docs_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs")
    if write_index:
        html_path = os.path.join(docs_dir, "index.html")
        with open(html_path, "w") as f:
            f.write(html)
        print(f"HTML report saved to: {html_path}", file=sys.stderr)
        write_site_files(seo["rows"], seo["date"], len(scripts))

    # The run dir's copy has no docs/ next to it: embed the logo.
    with open(os.path.join(docs_dir, LOGO), "rb") as f:
        logo = "data:image/png;base64," + base64.b64encode(f.read()).decode()
    html_path = os.path.join(run_dir, "index.html")
    with open(html_path, "w") as f:
        f.write(html.replace(f'src="{LOGO}"', f'src="{logo}"').replace(seo["head"], seo["head_run"]))
    print(f"HTML report saved to: {html_path}", file=sys.stderr)


# --- Search engines and link previews --------------------------------------------------------
# Most numbers on the page are drawn by JavaScript. The helpers below add what a crawler reads
# without JavaScript: the <head> tags (description, canonical, Open Graph, JSON-LD), a static
# intro, a summary table and a FAQ. With --write-index, write_site_files also writes
# docs/robots.txt, docs/sitemap.xml and docs/og.png (the link-preview image).

SITE_URL = "https://plutus-vm-bench.lantr.io/"
RAW_URL = "https://raw.githubusercontent.com/lantr-io/plutus-vm-benchmark/main"
PAGE_TITLE = "Plutus VM Benchmark: Cardano smart contract evaluator speed"
# Committed static files in docs/. og.png is rewritten by write_site_files when Chrome is found.
FAVICON = "favicon.svg"
OG_IMAGE = "og.png"
OG_SIZE = (1200, 630)
KEYWORDS = [
    "Cardano", "Plutus", "UPLC", "Untyped Plutus Core", "Plutus VM", "smart contract",
    "CEK machine", "evaluator", "benchmark", "performance", "plutus-core", "Aiken", "Scalus",
    "blaze-plutus", "Plutigo", "uplc-turbo",
]


def run_date(run_dir: str) -> str:
    """YYYY-MM-DD of the run: the dir name (2026-03-16-0 -> 2026-03-16), else unified.csv's mtime."""
    name = os.path.basename(os.path.abspath(run_dir))[:10]
    try:
        return datetime.date.fromisoformat(name).isoformat()
    except ValueError:
        path = os.path.join(run_dir, "unified.csv")
        ts = os.path.getmtime(path) if os.path.isfile(path) else None
        return (datetime.date.fromtimestamp(ts) if ts else datetime.date.today()).isoformat()


def fmt_ns_html(ns: float) -> str:
    """fmt_ns with the page's micro sign."""
    return fmt_ns(int(ns)).replace(" us", " µs") if ns > 0 else "-"


def split_label(vm: str) -> tuple[str, str]:
    """VM_LABELS 'Scalus CEK (Scala / JVM)' -> ('Scalus CEK', 'Scala / JVM')."""
    label = VM_LABELS.get(vm, vm)
    if label.endswith(")") and " (" in label:
        name, _, lang = label[:-1].rpartition(" (")
        return name, lang
    return label, ""


def summary_rows(data, scripts, present_vms, experimental, gate, eval_ns) -> list[dict]:
    """One row per shown VM: the ranked ones fastest first (geo mean with the penalty rule, as in
    report.md and the page's overall ranking), then the experimental ones."""
    geo = compute_geo_means(data, scripts, present_vms)
    ranked = sorted((vm for vm in present_vms if geo.get(vm, 0) > 0), key=lambda vm: geo[vm])
    fastest = geo[ranked[0]] if ranked else 0
    rows = []
    for vm in ranked + experimental:
        exp = vm in experimental
        g = experimental_geo_mean(data, scripts, present_vms, vm) if exp else geo[vm]
        ev = eval_ns.get(vm)
        name, lang = split_label(vm)
        rows.append({
            "vm": vm, "name": name, "lang": lang, "experimental": exp,
            "rank": None if exp else len(rows) + 1,
            "geo": g, "eval": geometric_mean(list(ev.values())) if ev else 0,
            "ratio": g / fastest if (fastest > 0 and g > 0 and not exp) else None,
            "check": check_label(gate, vm),
        })
    return rows


def summary_html(rows: list[dict], n_scripts: int) -> str:
    """The static summary table (visible text, no JavaScript needed)."""
    out = ['    <div class="table-wrap"><table class="summary-table">',
           '      <thead><tr><th>#</th><th class="l">VM</th><th class="l">Language / runtime</th>'
           '<th>Decode + eval</th><th>Eval only</th><th>vs fastest</th><th class="l">Check</th></tr></thead>',
           '      <tbody>']
    for r in rows:
        check_cls = {"pass": "pass", "outdated cost model": "outdated"}.get(r["check"], "")
        rank = "–" if r["rank"] is None else str(r["rank"])
        ratio = "not ranked" if r["experimental"] else (f"{r['ratio']:.2f}×" if r["ratio"] else "-")
        name = escape(r["name"]) + (" (experimental)" if r["experimental"] else "")
        tr = '<tr class="exp">' if r["experimental"] else "<tr>"
        out.append(f'        {tr}<td>{rank}</td>'
                   f'<td class="l vm">{name}</td><td class="l lang">{escape(r["lang"])}</td>'
                   f'<td>{fmt_ns_html(r["geo"])}</td><td>{fmt_ns_html(r["eval"])}</td><td>{ratio}</td>'
                   f'<td class="l {check_cls}">{escape(r["check"])}</td></tr>')
    out += ['      </tbody>', '    </table></div>',
            f'    <p class="summary-caption">Geometric mean of the time per script over the {n_scripts} '
            'scripts. <em>Decode + eval</em> is the ranking metric. A VM that fails or skips a script '
            'gets the slowest competitor\'s time for it. <em>Eval only</em> times a program that was '
            'decoded before the timed loop. A dash means that the run has no eval-only time for the VM. '
            'For a VM that compiles a script before it runs it, the decode + eval column already is '
            'its eval time: neither the decode nor the compile is timed. The VMs use different execution models, so compare VMs of the same model too '
            '(<a href="#exec-model">Execution Model</a>). Experimental VMs are shown, but not ranked.</p>']
    return "\n".join(out)


def languages(rows: list[dict]) -> str:
    """'Haskell, Scala, Rust and Go': the first word of each row's language, in row order."""
    langs: list[str] = []
    for r in rows:
        first = r["lang"].replace("→", "/").split("/")[0].strip()
        if first and first not in langs:
            langs.append(first)
    return ", ".join(langs[:-1]) + " and " + langs[-1] if len(langs) > 1 else "".join(langs)


def intro_html(rows: list[dict], n_scripts: int, date: str) -> str:
    n = len(rows)
    langs = languages(rows)
    return ("This benchmark compares the speed of <strong>Plutus virtual machines</strong> (UPLC "
            "evaluators), the programs that run Cardano smart contracts. Each VM decodes and evaluates "
            f"the same {n_scripts} Plutus scripts. A correctness gate checks every result and its "
            "execution units (ExUnits) against plutus-core, the Haskell CEK machine of the Cardano node. "
            f"This run of {date} has {n} evaluators" + (f", written in {escape(langs)}" if langs else "")
            + ". The <a href=\"#method\">method</a> and the "
            "<a href=\"https://github.com/lantr-io/plutus-vm-benchmark\">source</a> are open.")


def faq_items(rows: list[dict], n_scripts: int, date: str) -> list[tuple[str, str]]:
    """(question, answer HTML). The page and the FAQPage JSON-LD both use this list."""
    ranked = [r for r in rows if not r["experimental"] and r["geo"] > 0]
    if ranked:
        top = ranked[0]
        hs = next((r for r in ranked if r["vm"] == "haskell"), None)
        fastest = (f"In the run of {date}, {escape(top['name'])} ({escape(top['lang'])}) has the lowest "
                   f"decode + eval geometric mean of the ranked VMs: {fmt_ns_html(top['geo'])}.")
        if hs and hs is not top:
            fastest += (f" plutus-core, the Haskell CEK machine of the Cardano node, takes "
                        f"{fmt_ns_html(hs['geo'])} ({hs['ratio']:.2f}× the fastest time).")
        fastest += (" The VMs use different execution models (CEK interpreter, AST walker, JIT "
                    "compiler), so compare VMs of the same model too. Experimental VMs are not ranked.")
    else:
        fastest = f"The run of {date} has no ranked VM with a decode + eval time."
    return [
        ("What is a Plutus VM?",
         "A Plutus VM, or UPLC evaluator, runs Untyped Plutus Core (UPLC), the language of Cardano "
         "smart contracts. The Cardano node uses the CEK machine of plutus-core (Haskell) to validate "
         "scripts. Wallets, SDKs, emulators and other tools use their own evaluators to compute the "
         "script result and its execution units (ExUnits) before they submit a transaction."),
        ("What does this benchmark measure?",
         f"Each VM flat-decodes and evaluates {n_scripts} Plutus scripts from the plutus-use-cases test "
         "suite (auction, escrow, uniswap, stablecoin and others). The page shows the mean time per "
         "script and the geometric mean over all scripts. Each VM runs in its own Docker image on the "
         "same server type, one VM at a time. A VM is ranked only if its results and ExUnits equal "
         "Haskell plutus-core on every script."),
        ("Which Plutus VM is the fastest?", fastest),
        ("Why does the ranking include the decode time?",
         "A node decodes a script from its flat encoding before it evaluates it. For a script that the "
         "node has not seen, both steps take time. For some VMs the decode is a large share of the "
         "time (about 66 % for Haskell plutus-core), so the page also shows an eval-only time."),
        ("How often is the benchmark updated?",
         "A GitHub Actions workflow runs the full benchmark on the 1st of each month, and the "
         "maintainers start extra runs when a VM release changes. The workflow skips a scheduled run "
         f"when nothing changed. This page shows the run of {date}."),
        ("How can a VM join the benchmark?",
         "A ranked VM has a published release, a downstream user today, and passes the correctness "
         "gate. Open a pull request that adds a Docker image for the VM. Follow "
         "<a href=\"https://github.com/lantr-io/plutus-vm-benchmark/blob/HEAD/CONTRIBUTING.md\">"
         "CONTRIBUTING.md</a> and the <a href=\"https://github.com/lantr-io/plutus-vm-benchmark/blob/HEAD/"
         "docs/IMAGE_CONTRACT.md\">image contract</a>."),
    ]


def faq_html(items: list[tuple[str, str]]) -> str:
    return "\n".join(['    <div class="faq">']
                     + [f'      <div class="faq-item"><h3>{escape(q)}</h3><p>{a}</p></div>' for q, a in items]
                     + ['    </div>'])


def meta_description(rows: list[dict], n_scripts: int, date: str) -> str:
    return (f"Cardano Plutus VM benchmark: {len(rows)} UPLC smart contract evaluators, decode + eval "
            f"speed on {n_scripts} scripts, checked against the Haskell CEK machine. Run {date}.")


def json_ld(rows, items, run_dir: str, date: str, description: str, n_scripts: int) -> str:
    """schema.org graph: Organization, Person, WebSite, WebPage, Dataset, FAQPage."""
    run = os.path.basename(os.path.abspath(run_dir))
    org = {"@type": "Organization", "@id": "https://lantr.io/#organization", "name": "Lantr",
           "url": "https://lantr.io"}
    person = {"@type": "Person", "@id": SITE_URL + "#alexander-nemish", "name": "Alexander Nemish",
              "affiliation": {"@id": org["@id"]}}
    files = [("unified.csv", "text/csv", "Mean time per VM and script (decode + eval), in nanoseconds"),
             ("gate.json", "application/json", "Correctness gate verdict per VM"),
             ("report.md", "text/markdown", "The report of the run as Markdown tables")]
    distribution = [{"@type": "DataDownload", "name": f, "description": d, "encodingFormat": t,
                     "contentUrl": f"{RAW_URL}/results/{run}/{f}"}
                    for f, t, d in files if os.path.isfile(os.path.join(run_dir, f))]
    graph = [
        org, person,
        {"@type": "WebSite", "@id": SITE_URL + "#website", "url": SITE_URL, "name": "Plutus VM Benchmark",
         "inLanguage": "en", "publisher": {"@id": org["@id"]}},
        {"@type": "WebPage", "@id": SITE_URL + "#webpage", "url": SITE_URL, "name": PAGE_TITLE,
         "description": description, "inLanguage": "en", "dateModified": date,
         "isPartOf": {"@id": SITE_URL + "#website"}, "about": {"@id": SITE_URL + "#dataset"},
         "primaryImageOfPage": {"@type": "ImageObject", "url": SITE_URL + OG_IMAGE,
                                "width": OG_SIZE[0], "height": OG_SIZE[1]}},
        {"@type": "Dataset", "@id": SITE_URL + "#dataset", "url": SITE_URL,
         "name": "Plutus VM Benchmark: Cardano UPLC evaluator timings",
         "description": (f"Timings of {len(rows)} Plutus (UPLC) virtual machines, the evaluators of "
                         f"Cardano smart contracts, on the same {n_scripts} Plutus scripts: mean "
                         "flat decode + evaluation time and eval-only time per script, with a correctness "
                         "gate against the Haskell plutus-core CEK machine. Run of " + date + "."),
         "keywords": KEYWORDS, "inLanguage": "en", "isAccessibleForFree": True,
         "creator": [{"@id": org["@id"]}, {"@id": person["@id"]}], "publisher": {"@id": org["@id"]},
         "license": "https://opensource.org/licenses/MIT", "dateModified": date,
         "isBasedOn": "https://github.com/SAIB-Inc/cardano-plutus-vm-benchmark",
         "sameAs": "https://github.com/lantr-io/plutus-vm-benchmark",
         "measurementTechnique": "Each VM runs in its own Docker image with its native benchmark "
                                 "framework, one VM at a time, on the same server type",
         "variableMeasured": ["decode + eval time per script (ns)", "eval-only time per script (ns)",
                              "correctness gate verdict"],
         "distribution": distribution},
        {"@type": "FAQPage", "@id": SITE_URL + "#faq", "url": SITE_URL + "#faq",
         "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}}
                        for q, a in items]},
    ]
    return json.dumps({"@context": "https://schema.org", "@graph": graph}, ensure_ascii=False).replace("</", "<\\/")


def seo_head(description: str, date: str, ld: str, published: bool, favicon: str) -> str:
    """The <head> tags after <title>. published: the page at SITE_URL (docs/index.html); else the
    copy in results/<run>/, which is not served on the site: noindex, no canonical."""
    og_image = f"{SITE_URL}{OG_IMAGE}?v={date}"
    alt = "Plutus VM Benchmark: decode + eval geometric mean of the fastest ranked Plutus VMs"
    d = escape(description)
    lines = [
        f'<meta name="description" content="{d}">',
        '<meta name="robots" content="index, follow">' if published else '<meta name="robots" content="noindex">',
    ]
    if published:
        lines.append(f'<link rel="canonical" href="{SITE_URL}">')
    lines += [
        '<meta name="author" content="Lantr, Alexander Nemish">',
        '<meta name="theme-color" content="#09090f">',
        f'<link rel="icon" type="image/svg+xml" href="{favicon}">',
        '<meta property="og:type" content="website">',
        '<meta property="og:site_name" content="Plutus VM Benchmark">',
        '<meta property="og:locale" content="en_US">',
        f'<meta property="og:title" content="{escape(PAGE_TITLE)}">',
        f'<meta property="og:description" content="{d}">',
        f'<meta property="og:url" content="{SITE_URL}">',
        f'<meta property="og:image" content="{og_image}">',
        f'<meta property="og:image:width" content="{OG_SIZE[0]}">',
        f'<meta property="og:image:height" content="{OG_SIZE[1]}">',
        f'<meta property="og:image:alt" content="{alt}">',
        '<meta name="twitter:card" content="summary_large_image">',
        f'<meta name="twitter:title" content="{escape(PAGE_TITLE)}">',
        f'<meta name="twitter:description" content="{d}">',
        f'<meta name="twitter:image" content="{og_image}">',
        f'<meta name="twitter:image:alt" content="{alt}">',
        f'<script type="application/ld+json">\n{ld}\n</script>',
    ]
    return "\n".join(lines)


def seo_parts(run_dir, data, scripts, present_vms, experimental, gate, eval_ns) -> dict:
    """The template placeholders, and the rows for write_site_files."""
    date = run_date(run_dir)
    rows = summary_rows(data, scripts, present_vms, experimental, gate, eval_ns)
    items = faq_items(rows, len(scripts), date)
    description = meta_description(rows, len(scripts), date)
    ld = json_ld(rows, items, run_dir, date, description, len(scripts))
    with open(os.path.join(DOCS_DIR, FAVICON), "rb") as f:
        favicon_uri = "data:image/svg+xml;base64," + base64.b64encode(f.read()).decode()
    return {
        "date": date, "rows": rows,
        "head": seo_head(description, date, ld, True, FAVICON),
        "head_run": seo_head(description, date, ld, False, favicon_uri),
        "{{SEO_INTRO}}": intro_html(rows, len(scripts), date),
        "{{SEO_SUMMARY_SUB}}": f"all VMs, geometric mean over {len(scripts)} scripts",
        "{{SEO_SUMMARY}}": summary_html(rows, len(scripts)),
        "{{SEO_FAQ}}": faq_html(items),
    }


def og_card_html(rows: list[dict], date: str, n_scripts: int) -> str:
    """The 1200x630 link-preview card: title and the five fastest ranked VMs. Without rows (the
    committed bootstrap image) a plain title card. System fonts only: no network."""
    ranked = [r for r in rows if not r["experimental"] and r["geo"] > 0][:5]
    bars = ""
    if ranked:
        fastest = ranked[0]["geo"]
        for r in ranked:
            w = max(4.0, 100 * fastest / r["geo"])  # speed relative to the fastest: longer is faster
            bars += (f'<div class="row"><div class="n">{escape(r["name"])}<span>{escape(r["lang"])}</span></div>'
                     f'<div class="t"><div class="b" style="width:{w:.1f}%"></div></div>'
                     f'<div class="v">{fmt_ns_html(r["geo"])}</div></div>')
        sub = f"Decode + eval geometric mean, {n_scripts} scripts, run {date}. Longer bar = faster."
    else:
        sub = "Cardano smart contract evaluators: decode + eval time, checked against plutus-core."
    logo = "file://" + os.path.join(DOCS_DIR, LOGO)
    return f"""<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
html, body {{ width:{OG_SIZE[0]}px; height:{OG_SIZE[1]}px; overflow:hidden; }}
body {{ background:#09090f; color:#e4e4ec; padding:56px 64px; display:flex; flex-direction:column;
  font-family:-apple-system,'Segoe UI','DejaVu Sans','Liberation Sans',Helvetica,Arial,sans-serif; }}
h1 {{ font-size:64px; font-weight:700; letter-spacing:-1px; }} h1 span {{ color:#8b78ef; }}
.sub {{ font-size:26px; color:#9494b0; margin:10px 0 36px; }}
.row {{ display:flex; align-items:center; gap:24px; height:62px; }}
.n {{ width:330px; font-size:28px; font-weight:600; white-space:nowrap; overflow:hidden; }}
.n span {{ display:block; font-size:18px; font-weight:400; color:#8484a2; }}
.t {{ flex:1; height:26px; }} .b {{ height:100%; background:#646FFF; border-radius:4px; }}
.v {{ width:150px; text-align:right; font-size:28px; font-variant-numeric:tabular-nums; }}
.big {{ font-size:34px; color:#AFAFE8; line-height:1.5; margin-top:20px; }}
.foot {{ margin-top:auto; display:flex; justify-content:space-between; align-items:center;
  font-size:24px; color:#8484a2; }} .foot img {{ height:44px; }}
</style></head><body>
<h1><span>Plutus</span> VM Benchmark</h1><div class="sub">{escape(sub)}</div>
{bars or '<div class="big">Haskell, Rust, Go, Scala and TypeScript UPLC evaluators,<br>timed on the same Plutus scripts.</div>'}
<div class="foot"><div>plutus-vm-bench.lantr.io</div><img src="{logo}" alt=""></div>
</body></html>"""


def find_chrome() -> str | None:
    for c in [os.environ.get("CHROME"), "google-chrome", "google-chrome-stable", "chromium",
              "chromium-browser", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"]:
        path = c and (shutil.which(c) or (c if os.path.isfile(c) else None))
        if path:
            return path
    return None


def png_size(path: str) -> tuple[int, int] | None:
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


def write_og_image(rows: list[dict], date: str, n_scripts: int) -> None:
    """docs/og.png from og_card_html with headless Chrome. Without Chrome (python:3.12-slim) or on
    any failure, keep the committed docs/og.png."""
    chrome = find_chrome()
    if not chrome:
        print("og.png: no Chrome found, docs/og.png not changed", file=sys.stderr)
        return
    with tempfile.TemporaryDirectory() as tmp:
        card, shot = os.path.join(tmp, "og.html"), os.path.join(tmp, "og.png")
        with open(card, "w") as f:
            f.write(og_card_html(rows, date, n_scripts))
        cmd = [chrome, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
               "--force-device-scale-factor=1", f"--window-size={OG_SIZE[0]},{OG_SIZE[1]}",
               f"--screenshot={shot}", "file://" + card]
        try:
            subprocess.run(cmd, check=True, timeout=120, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except (OSError, subprocess.SubprocessError) as e:
            print(f"og.png: Chrome failed ({e}), docs/og.png not changed", file=sys.stderr)
            return
        if not os.path.isfile(shot) or png_size(shot) != OG_SIZE:
            print(f"og.png: unexpected screenshot {png_size(shot) if os.path.isfile(shot) else None}, "
                  "docs/og.png not changed", file=sys.stderr)
            return
        shutil.copyfile(shot, os.path.join(DOCS_DIR, OG_IMAGE))
    print(f"og.png saved to: {os.path.join(DOCS_DIR, OG_IMAGE)}", file=sys.stderr)


def write_site_files(rows: list[dict], date: str, n_scripts: int) -> None:
    """docs/robots.txt, docs/sitemap.xml and docs/og.png for the published site. The sitemap lists
    the main page only: the per-run copies in results/ are not deployed (run.yml uploads docs/)."""
    with open(os.path.join(DOCS_DIR, "robots.txt"), "w") as f:
        f.write(f"User-agent: *\nAllow: /\n\nSitemap: {SITE_URL}sitemap.xml\n")
    with open(os.path.join(DOCS_DIR, "sitemap.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n'
                '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
                f"  <url>\n    <loc>{SITE_URL}</loc>\n    <lastmod>{date}</lastmod>\n  </url>\n"
                "</urlset>\n")
    write_og_image(rows, date, n_scripts)


def generate(run_dir: str, write_index: bool = False) -> None:
    data, scripts, all_vms, env_info = load_data(run_dir)
    # A run without the d3 loop (BENCH_LOOPS) has an empty unified.csv: take the VMs and scripts
    # of the eval-only files too, so their column is shown.
    eval_all = load_eval(run_dir)
    found = set(all_vms) | set(eval_all)
    all_vms = [vm for vm in VM_ORDER if vm in found] + sorted(found - set(VM_ORDER))
    scripts = sorted(set(scripts) | {s for v in eval_all.values() for s in v})
    gate = load_gate(run_dir)
    shown_vms, hidden = gate_split(gate, all_vms)
    for s in scripts:
        for vm in hidden:
            data[s].pop(vm, None)
    # The gate first: an experimental VM that fails it is listed as "failed check".
    present_vms = [vm for vm in shown_vms if vm not in EXPERIMENTAL]
    experimental = [vm for vm in shown_vms if vm in EXPERIMENTAL]
    compile_ns = {vm: v for vm, v in load_compile(run_dir).items() if vm in shown_vms}
    # A compiling VM's D3 time already is its eval time: no second column for it (unless the run
    # had no d3 loop).
    has_d3 = {vm for s in scripts for vm in data[s]}
    eval_ns = {vm: v for vm, v in eval_all.items()
               if vm in shown_vms and not (vm in compile_ns and vm in has_d3)}
    history = load_history(run_dir)
    drift = load_drift(run_dir)
    generate_markdown(run_dir, data, scripts, present_vms, experimental, env_info, gate, hidden,
                      compile_ns, eval_ns, history, drift)
    generate_html(run_dir, env_info, data, scripts, present_vms, experimental, gate, hidden,
                  compile_ns, eval_ns, history, drift, write_index)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--write-index"]
    if len(args) != 1:
        print(f"Usage: {sys.argv[0]} [--write-index] <run-dir>", file=sys.stderr)
        sys.exit(1)
    generate(args[0], "--write-index" in sys.argv[1:])
