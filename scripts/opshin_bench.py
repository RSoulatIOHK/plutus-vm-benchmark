"""Benchmark and check the OpShin uplc CEK machine on the plutus_use_cases flat scripts.

docs/IMAGE_CONTRACT.md, spec D3/D4/D11. Parameters (check/README.md, "Evaluation parameters"):
the mainnet PlutusV3 cost model, counting mode (no limit). opshin has no protocol version switch.

    python3 opshin_bench.py                 timing: flat decode + eval per iteration
    python3 opshin_bench.py --eval          timing: eval of a program decoded once before timing
    python3 opshin_bench.py --check OUT     one evaluation per script, write vm,script,status,cpu,mem

Both timing modes use the same loop and print the same lines (parsers/parse_opshin.py). --eval
decodes each program once; each iteration calls uplc.tools.eval on it, which makes a fresh Machine
(fresh budget and state) and runs opshin's own pre-pass (UniqueVariableTransformer, which copies
the nodes it renames and leaves the decoded program as it was). Before timing, --eval runs the
decoded program twice and requires the same cost both times; otherwise the script is skipped.

Environment: BENCH_DATA_DIR (the .flat files), PVB_COSTMODEL_JSON (the mainnet cost model file,
check/reference/mainnet-plutusv3-costmodel.json), PVB_PARAM_NAMES (images/opshin/
plutusv3-param-names.txt), OPSHIN_MIN_ITERS, OPSHIN_TIME_BUDGET_S, OPSHIN_RECURSION_LIMIT.

Cost model: opshin reads a name -> value map (updated_*_cost_model_from_network_config). The map
zips the on-chain PlutusV3 array with the plutus 1.63.0.0 parameter names, then removes
"-model-arguments-": opshin reads the old names of the parameters of the division builtins and
silently uses 3e10 for a name it does not find. The names do not come from PlutusV3Named in the
cost model file: that map has 11 wrong names (positions 139-149, quotientInteger memory to
remainderInteger memory, shifted by one), which gave quotientInteger a 3e10 memory minimum.

Recursion limit: opshin's visitors (decode, variable renaming) recurse over the term, so deep
programs need a limit above the Python default of 1000. The uplc CLI has --recursion-limit for this
("necessary for larger UPLC programs"); this harness sets OPSHIN_RECURSION_LIMIT (default 100000).

Machine.eval returns an error in ComputationResult.result instead of raising it, so every
evaluation here checks the result: a failing script is reported, never timed as a pass.
"""

import json
import os
import sys
import time

import cbor2
from uplc.cost_model import (
    Budget,
    default_builtin_cost_model_base,
    default_cek_machine_cost_model_base,
    updated_builtin_cost_model_from_network_config,
    updated_cek_machine_cost_model_from_network_config,
)
from uplc.tools import eval, unflatten

BENCH_DIR = os.environ.get("BENCH_DATA_DIR", "/bench/data/plutus_use_cases")
COSTMODEL_JSON = os.environ.get("PVB_COSTMODEL_JSON", "/bench/mainnet-plutusv3-costmodel.json")
PARAM_NAMES = os.environ.get("PVB_PARAM_NAMES", "/bench/plutusv3-param-names.txt")
WARMUP = 3
# BENCH_TIMING=quick lowers these through the environment (scripts/run-opshin.sh).
MIN_ITERS = int(os.environ.get("OPSHIN_MIN_ITERS", "20"))
TIME_BUDGET_S = float(os.environ.get("OPSHIN_TIME_BUDGET_S", "2.0"))
sys.setrecursionlimit(int(os.environ.get("OPSHIN_RECURSION_LIMIT", "100000")))
# Counting mode: a budget too large to run out.
COUNTING_BUDGET = Budget(cpu=2**63 - 1, memory=2**63 - 1)


class RecordingDict(dict):
    """Records the names opshin asks for, to report the ones it does not find."""

    def __init__(self, *args):
        super().__init__(*args)
        self.asked = set()

    def get(self, key, default=None):
        self.asked.add(key)
        return super().get(key, default)


def mainnet_cost_models():
    with open(COSTMODEL_JSON) as f:
        values = json.load(f)["PlutusV3"]
    with open(PARAM_NAMES) as f:
        names = [line.strip() for line in f if line.strip() and not line.startswith("#")]
    if len(names) != len(values):
        sys.exit(f"{PARAM_NAMES}: {len(names)} names for {len(values)} cost model values")
    renamed = RecordingDict({k.replace("-model-arguments-", "-"): v for k, v in zip(names, values)})
    cek = updated_cek_machine_cost_model_from_network_config(
        default_cek_machine_cost_model_base(), renamed
    )
    builtin = updated_builtin_cost_model_from_network_config(
        default_builtin_cost_model_base(), renamed
    )
    unused = sorted(set(renamed) - renamed.asked)
    missing = sorted(renamed.asked - set(renamed))
    print(f"cost model: {len(renamed)} mainnet parameters, {len(unused)} not read by opshin, "
          f"{len(missing)} opshin parameters not in the mainnet map (cost 3e10)")
    if unused:
        print("  not read: " + " ".join(unused))
    if missing:
        print("  missing: " + " ".join(missing))
    return cek, builtin


CEK_COSTS, BUILTIN_COSTS = mainnet_cost_models()


def eval_decoded(prog):
    """Evaluation of a decoded program with a fresh Machine. Returns the ComputationResult."""
    return eval(
        prog,
        budget=COUNTING_BUDGET,
        cek_machine_cost_model=CEK_COSTS,
        builtin_cost_model=BUILTIN_COSTS,
    )


def run_once(cbor_flat: bytes):
    """Flat decode + evaluation. Returns the ComputationResult."""
    return eval_decoded(unflatten(cbor_flat))


def failed(result) -> bool:
    return isinstance(result.result, Exception)


def fmt_ns(ns: int) -> str:
    if ns >= 1_000_000_000:
        return f"{ns / 1e9:.2f} s "
    if ns >= 1_000_000:
        return f"{ns / 1e6:.2f} ms"
    if ns >= 1_000:
        return f"{ns / 1e3:.2f} us"
    return f"{ns} ns"


files = sorted(f for f in os.listdir(BENCH_DIR) if f.endswith(".flat"))
if not files:
    print(f"No .flat files in {BENCH_DIR}", file=sys.stderr)
    sys.exit(1)

# CBOR-wrap raw flat bytes for unflatten()
scripts = {}
for f in files:
    with open(os.path.join(BENCH_DIR, f), "rb") as fh:
        scripts[f.removesuffix(".flat")] = cbor2.dumps(fh.read())


def check(out_path: str) -> None:
    lines = ["vm,script,status,cpu,mem"]
    for name, cbor_flat in scripts.items():
        try:
            r = run_once(cbor_flat)
            status = "error" if failed(r) else "ok"
            cpu, mem = r.cost.cpu, r.cost.memory
            if failed(r):
                print(f"CHECK_FAIL: {name}: {str(r.result)[:200]}")
        except Exception as e:  # decode error
            print(f"CHECK_FAIL: {name}: {str(e)[:200]}")
            status, cpu, mem = "error", 0, 0
        lines.append(f"opshin,{name},{status},{cpu},{mem}")
    with open(out_path, "w") as f:
        f.write("\n".join(lines) + "\n")


def timed_call(cbor_flat: bytes, eval_only: bool):
    """The call to time for one script: decode + eval, or eval of a program decoded here, once.

    Raises when the script does not decode or evaluate; with eval_only also when two evaluations
    of the decoded program cost differently.
    """
    if not eval_only:
        call = lambda: run_once(cbor_flat)  # noqa: E731
    else:
        prog = unflatten(cbor_flat)
        call = lambda: eval_decoded(prog)  # noqa: E731
    r = call()
    if failed(r):
        raise RuntimeError(r.result)
    if eval_only:
        again = call()
        if failed(again) or again.cost != r.cost:
            raise RuntimeError(
                f"second evaluation of the decoded program differs: {again.cost} != {r.cost}"
            )
    return call


def bench(eval_only: bool) -> None:
    # Interpreter warm-up
    first = list(scripts.values())[0]
    first_prog = unflatten(first)
    for _ in range(20):
        eval_decoded(first_prog) if eval_only else run_once(first)

    what = "eval of a decoded program" if eval_only else "flat decode + eval"
    print(f"Found {len(files)} benchmark files\n")
    print(f"plutus_use_cases benchmarks (Python / OpShin uplc), {what} per iteration")
    print("=" * 90)

    grand_total_ns = 0
    grand_total_iters = 0

    for name, cbor_flat in scripts.items():
        # Verify it works
        try:
            call = timed_call(cbor_flat, eval_only)
        except Exception as e:
            print(f"  {name:<35} SKIP (eval error)")
            print(f"    {str(e)[:200]}")
            continue

        # Warmup
        for _ in range(WARMUP):
            call()

        # Measured
        samples = []
        total_s = 0.0
        while len(samples) < MIN_ITERS or total_s < TIME_BUDGET_S:
            t0 = time.perf_counter_ns()
            r = call()
            elapsed = time.perf_counter_ns() - t0
            if failed(r):
                raise RuntimeError(f"{name}: evaluation failed during timing: {r.result}")
            samples.append(elapsed)
            total_s += elapsed / 1e9
            if len(samples) >= 10_000:
                break

        samples.sort()
        n = len(samples)
        mean = sum(samples) // n
        median = samples[n // 2] if n % 2 else (samples[n // 2 - 1] + samples[n // 2]) // 2
        mn, mx = samples[0], samples[-1]
        var = sum((s - mean) ** 2 for s in samples) / n
        stddev = int(var**0.5)

        grand_total_ns += sum(samples)
        grand_total_iters += n

        print(
            f"  {name:<35} {n:5} runs  {fmt_ns(mean):>12}  "
            f"+/- {fmt_ns(stddev):>10}  [{fmt_ns(mn):>10} .. {fmt_ns(mx):>10}]"
        )

    print("=" * 90)
    if grand_total_iters > 0:
        grand_mean = grand_total_ns // grand_total_iters
        print(f"  Grand total: {grand_total_iters} iterations, mean {fmt_ns(grand_mean)}/eval")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--check":
        check(sys.argv[2])
    elif len(sys.argv) == 1:
        bench(eval_only=False)
    elif sys.argv[1:] == ["--eval"]:
        bench(eval_only=True)
    else:
        print(f"usage: {sys.argv[0]} [--eval | --check OUT_CSV]", file=sys.stderr)
        sys.exit(2)
