#!/usr/bin/env python3
"""Generate markdown and HTML comparison reports from unified.csv.

Usage: generate_report.py [--write-index] <run-dir>
Writes <run-dir>/report.md and <run-dir>/index.html. With --write-index, also writes the same page
to <repo>/docs/index.html, the published page: only run.yml sets it, for a published run.

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
import glob
import json
import math
import os
import sys
from collections import defaultdict

VM_ORDER = [
    "haskell", "scalus-jit", "scalus-cek", "scalus-js",
    "aiken", "aiken-wasm", "uplc-turbo",
    "plutigo", "blaze-jsc", "blaze-v8",
]

# The header logo in report/template.html, a file in docs/.
LOGO = "lantr-logo-dark.png"

DISCLOSURE = (
    "The 89 scripts are PlutusV1-era programs. Every VM evaluates them as PlutusV3 programs at "
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
    point for that run. An EXPERIMENTAL VM has no line, in any run.
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
        shown = [vm for vm in shown if vm not in EXPERIMENTAL]
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

    lines.append(f"*{DISCLOSURE}*")
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
            lines.append(f"| {VM_LABELS.get(vm, vm)} | " + " | ".join(cells) + " |")

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


def generate_html(run_dir: str, env_info: str, data, present_vms, experimental, gate, hidden, compile_ns,
                  eval_ns, history, drift, write_index: bool) -> None:
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
        "disclosure": DISCLOSURE,
        "notes": {vm: n for vm, n in VM_NOTES.items() if vm in shown},
        "compile_badge": COMPILE_BADGE,
        "badges": {vm: b for vm, b in VM_BADGES.items() if vm in shown},
        "experimental": {vm: EXPERIMENTAL[vm] for vm in experimental},
        "drift": drift_text(drift),
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

    docs_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs")
    if write_index:
        html_path = os.path.join(docs_dir, "index.html")
        with open(html_path, "w") as f:
            f.write(html)
        print(f"HTML report saved to: {html_path}", file=sys.stderr)

    # The run dir's copy has no docs/ next to it: embed the logo.
    with open(os.path.join(docs_dir, LOGO), "rb") as f:
        logo = "data:image/png;base64," + base64.b64encode(f.read()).decode()
    html_path = os.path.join(run_dir, "index.html")
    with open(html_path, "w") as f:
        f.write(html.replace(f'src="{LOGO}"', f'src="{logo}"'))
    print(f"HTML report saved to: {html_path}", file=sys.stderr)


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
    generate_html(run_dir, env_info, data, present_vms, experimental, gate, hidden, compile_ns,
                  eval_ns, history, drift, write_index)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--write-index"]
    if len(args) != 1:
        print(f"Usage: {sys.argv[0]} [--write-index] <run-dir>", file=sys.stderr)
        sys.exit(1)
    generate(args[0], "--write-index" in sys.argv[1:])
