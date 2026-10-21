"""Tests for check/gate.py. Run: python3 -m unittest discover -s check -p 'test_*.py'"""

from __future__ import annotations

import csv
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gate  # noqa: E402

REFERENCE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reference")
REFERENCE_CSV = os.path.join(REFERENCE_DIR, "haskell-check.csv")
VARIANT_C_CSV = os.path.join(REFERENCE_DIR, "haskell-check-variant-c.csv")
ROWS = [("a", "ok", "100", "10"), ("b", "ok", "200", "20"), ("c", "error", "300", "30")]
# The cost model a badge VM ships: same status, different cpu/mem.
OLD_MODEL_ROWS = [("a", "ok", "110", "11"), ("b", "ok", "220", "22"), ("c", "error", "330", "33")]


class GateTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.reference = self.write("reference.csv", "haskell", ROWS)
        self.old_reference = self.write("reference-old.csv", "haskell", OLD_MODEL_ROWS)

    def write(self, name, vm, rows):
        path = os.path.join(self.tmp.name, name)
        with open(path, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(gate.FIELDS)
            for r in rows:
                w.writerow((vm,) + tuple(r))
        return path

    def run_gate(self, *checks, modes=()):
        out_json = os.path.join(self.tmp.name, "verdict.json")
        mode_args = [a for m in modes for a in ("--mode", m)]
        with redirect_stdout(io.StringIO()) as out:
            code = gate.main(["--reference", self.reference, "--json", out_json, *mode_args, *checks])
        with open(out_json) as f:
            return code, json.load(f), out.getvalue()

    def test_identical_passes(self):
        vm = self.write("x-check.csv", "x", [("a", "ok", "100", "10"), ("b", "ok", "200", "20"),
                                             ("c", "error", "300", "30")])
        code, verdict, text = self.run_gate(vm)
        self.assertEqual(code, 0)
        self.assertTrue(verdict["ok"])
        self.assertEqual(verdict["vms"]["x"]["verdict"], "pass")
        self.assertEqual(verdict["vms"]["x"]["mode"], "strict")
        self.assertIn("x: PASS [strict]", text)
        self.assertIn("3/3 scripts match", text)

    def test_one_wrong_mem_fails(self):
        # The mutation the spec asks for: a single wrong ExUnits value must fail the gate.
        vm = self.write("x-check.csv", "x", [("a", "ok", "100", "10"), ("b", "ok", "200", "21"),
                                             ("c", "error", "300", "30")])
        code, verdict, text = self.run_gate(vm)
        self.assertEqual(code, 1)
        self.assertFalse(verdict["ok"])
        v = verdict["vms"]["x"]
        self.assertEqual(v["verdict"], "fail")
        self.assertEqual(v["mismatches"], [{"script": "b", "reason": "mismatch",
                                            "mem": {"expected": "20", "actual": "21"}}])
        self.assertIn("b: mem 21 != 20", text)

    def test_wrong_cpu_and_status_fail(self):
        vm = self.write("x-check.csv", "x", [("a", "ok", "101", "10"), ("b", "error", "200", "20"),
                                             ("c", "error", "300", "30")])
        code, verdict, _ = self.run_gate(vm)
        self.assertEqual(code, 1)
        scripts = {m["script"]: m for m in verdict["vms"]["x"]["mismatches"]}
        self.assertEqual(set(scripts), {"a", "b"})
        self.assertIn("cpu", scripts["a"])
        self.assertIn("status", scripts["b"])

    def test_empty_costing_fails_as_no_costing(self):
        vm = self.write("x-check.csv", "x", [("a", "ok", "", ""), ("b", "ok", "", ""), ("c", "error", "", "")])
        code, verdict, text = self.run_gate(vm)
        self.assertEqual(code, 1)
        self.assertTrue(verdict["vms"]["x"]["no_costing"])
        self.assertIn("no costing", text)

    def test_missing_script_fails_extra_script_warns(self):
        vm = self.write("x-check.csv", "x", [("a", "ok", "100", "10"), ("b", "ok", "200", "20"),
                                             ("zzz", "ok", "1", "1")])
        code, verdict, text = self.run_gate(vm)
        self.assertEqual(code, 1)
        v = verdict["vms"]["x"]
        self.assertEqual(v["mismatches"], [{"script": "c", "reason": "missing"}])
        self.assertEqual(v["extra_scripts"], ["zzz"])
        self.assertIn("warning", text)

    def test_one_failing_vm_fails_the_run_but_others_pass(self):
        good = self.write("g-check.csv", "g", [("a", "ok", "100", "10"), ("b", "ok", "200", "20"),
                                               ("c", "error", "300", "30")])
        bad = self.write("b-check.csv", "bad", [("a", "ok", "100", "10"), ("b", "ok", "200", "20"),
                                                ("c", "ok", "300", "30")])
        code, verdict, _ = self.run_gate(good, bad)
        self.assertEqual(code, 1)
        self.assertEqual(verdict["vms"]["g"]["verdict"], "pass")
        self.assertEqual(verdict["vms"]["bad"]["verdict"], "fail")

    # --- badge mode ---

    def test_badge_vm_matching_its_own_model_gets_badge(self):
        vm = self.write("x-check.csv", "x", OLD_MODEL_ROWS)
        code, verdict, text = self.run_gate(vm, modes=[f"x=badge:{self.old_reference}"])
        self.assertEqual(code, 0)
        self.assertTrue(verdict["ok"])
        v = verdict["vms"]["x"]
        self.assertEqual((v["verdict"], v["mode"], v["reference"]), ("badge", "badge", self.old_reference))
        self.assertIn("outdated cost model", v["reason"])
        self.assertIn("x: BADGE [badge]", text)

    def test_badge_mutation_one_wrong_mem_fails(self):
        rows = list(OLD_MODEL_ROWS)
        rows[1] = ("b", "ok", "220", "23")
        vm = self.write("x-check.csv", "x", rows)
        code, verdict, _ = self.run_gate(vm, modes=[f"x=badge:{self.old_reference}"])
        self.assertEqual(code, 1)
        v = verdict["vms"]["x"]
        self.assertEqual(v["verdict"], "fail")
        self.assertEqual(v["reference"], self.old_reference)
        self.assertEqual(v["mismatches"], [{"script": "b", "reason": "mismatch",
                                            "mem": {"expected": "22", "actual": "23"}}])

    def test_badge_wrong_status_fails(self):
        rows = list(OLD_MODEL_ROWS)
        rows[2] = ("c", "ok", "330", "33")
        vm = self.write("x-check.csv", "x", rows)
        code, verdict, _ = self.run_gate(vm, modes=[f"x=badge:{self.old_reference}"])
        self.assertEqual(code, 1)
        self.assertEqual([m["script"] for m in verdict["vms"]["x"]["mismatches"]], ["c"])
        self.assertIn("status", verdict["vms"]["x"]["mismatches"][0])

    def test_badge_vm_matching_strict_reference_passes(self):
        vm = self.write("x-check.csv", "x", ROWS)
        code, verdict, _ = self.run_gate(vm, modes=[f"x=badge:{self.old_reference}"])
        self.assertEqual(code, 0)
        self.assertEqual(verdict["vms"]["x"]["verdict"], "pass")

    def test_badge_no_costing_fails(self):
        vm = self.write("x-check.csv", "x", [(s, st, "", "") for s, st, _, _ in OLD_MODEL_ROWS])
        code, verdict, _ = self.run_gate(vm, modes=[f"x=badge:{self.old_reference}"])
        self.assertEqual(code, 1)
        self.assertTrue(verdict["vms"]["x"]["no_costing"])

    def test_strict_vm_with_old_model_fails(self):
        vm = self.write("x-check.csv", "x", OLD_MODEL_ROWS)
        code, verdict, _ = self.run_gate(vm)
        self.assertEqual(code, 1)
        self.assertEqual(verdict["vms"]["x"]["verdict"], "fail")

    def test_mixed_modes(self):
        strict_vm = self.write("s-check.csv", "s", ROWS)
        badge_vm = self.write("b-check.csv", "b", OLD_MODEL_ROWS)
        code, verdict, _ = self.run_gate(strict_vm, badge_vm, modes=[f"b=badge:{self.old_reference}", "s=strict"])
        self.assertEqual(code, 0)
        self.assertEqual({vm: v["verdict"] for vm, v in verdict["vms"].items()}, {"s": "pass", "b": "badge"})

    def test_bad_mode_is_input_error(self):
        vm = self.write("x-check.csv", "x", ROWS)
        for spec in ("x", "x=lenient", "x=badge:", "=strict", "y=strict"):
            with self.subTest(spec=spec), redirect_stdout(io.StringIO()):
                self.assertEqual(gate.main(["--reference", self.reference, "--mode", spec, vm]), 2)

    def test_bad_header_is_input_error(self):
        path = os.path.join(self.tmp.name, "bad.csv")
        with open(path, "w") as f:
            f.write("vm,script,mean_ns\nx,a,1\n")
        with redirect_stdout(io.StringIO()):
            self.assertEqual(gate.main(["--reference", self.reference, path]), 2)

    @unittest.skipUnless(os.path.exists(REFERENCE_CSV), "reference not generated")
    def test_real_reference_mutation(self):
        # The committed reference passes against itself, and one changed mem value fails it.
        _, ref = gate.read_check_csv(REFERENCE_CSV)
        self.assertEqual(len(ref), 89)
        self.assertTrue(all(r["status"] == "ok" and r["cpu"] and r["mem"] for r in ref.values()))
        self.assertEqual(gate.compare(ref, ref)["verdict"], "pass")
        script = sorted(ref)[0]
        mutated = {k: dict(v) for k, v in ref.items()}
        mutated[script]["mem"] = str(int(mutated[script]["mem"]) + 1)
        v = gate.compare(ref, mutated)
        self.assertEqual(v["verdict"], "fail")
        self.assertEqual([m["script"] for m in v["mismatches"]], [script])

    @unittest.skipUnless(os.path.exists(VARIANT_C_CSV), "variant C reference not generated")
    def test_real_variant_c_reference_badge_and_mutation(self):
        _, ref = gate.read_check_csv(REFERENCE_CSV)
        _, old = gate.read_check_csv(VARIANT_C_CSV)
        self.assertEqual(set(old), set(ref))
        # Same status everywhere; the old cost model changes the ExUnits of every script.
        self.assertTrue(all(old[s]["status"] == ref[s]["status"] for s in ref))
        self.assertTrue(all((old[s]["cpu"], old[s]["mem"]) != (ref[s]["cpu"], ref[s]["mem"]) for s in ref))
        self.assertEqual(gate.judge(ref, old, "badge", VARIANT_C_CSV, old)["verdict"], "badge")
        self.assertEqual(gate.judge(ref, old, "strict", None, None)["verdict"], "fail")
        mutated = {k: dict(v) for k, v in old.items()}
        script = sorted(old)[-1]
        mutated[script]["mem"] = str(int(mutated[script]["mem"]) + 1)
        v = gate.judge(ref, mutated, "badge", VARIANT_C_CSV, old)
        self.assertEqual(v["verdict"], "fail")
        self.assertEqual([m["script"] for m in v["mismatches"]], [script])


if __name__ == "__main__":
    unittest.main()
