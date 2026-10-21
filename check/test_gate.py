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

REFERENCE_CSV = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reference", "haskell-check.csv")


class GateTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.reference = self.write("reference.csv", "haskell", [
            ("a", "ok", "100", "10"),
            ("b", "ok", "200", "20"),
            ("c", "error", "300", "30"),
        ])

    def write(self, name, vm, rows):
        path = os.path.join(self.tmp.name, name)
        with open(path, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(gate.FIELDS)
            for r in rows:
                w.writerow((vm,) + tuple(r))
        return path

    def run_gate(self, *checks):
        out_json = os.path.join(self.tmp.name, "verdict.json")
        with redirect_stdout(io.StringIO()) as out:
            code = gate.main(["--reference", self.reference, "--json", out_json, *checks])
        with open(out_json) as f:
            return code, json.load(f), out.getvalue()

    def test_identical_passes(self):
        vm = self.write("x-check.csv", "x", [("a", "ok", "100", "10"), ("b", "ok", "200", "20"),
                                             ("c", "error", "300", "30")])
        code, verdict, text = self.run_gate(vm)
        self.assertEqual(code, 0)
        self.assertTrue(verdict["pass"])
        self.assertEqual(verdict["vms"]["x"]["verdict"], "pass")
        self.assertIn("x: PASS (3/3", text)

    def test_one_wrong_mem_fails(self):
        # The mutation the spec asks for: a single wrong ExUnits value must fail the gate.
        vm = self.write("x-check.csv", "x", [("a", "ok", "100", "10"), ("b", "ok", "200", "21"),
                                             ("c", "error", "300", "30")])
        code, verdict, text = self.run_gate(vm)
        self.assertEqual(code, 1)
        self.assertFalse(verdict["pass"])
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


if __name__ == "__main__":
    unittest.main()
