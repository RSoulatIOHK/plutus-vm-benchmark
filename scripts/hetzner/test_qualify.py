"""Tests for the server qualification (qualify.py and up-qualified.sh), with fake numbers.

Run: python3 -m unittest discover -s scripts/hetzner -p 'test_*.py'
"""

from __future__ import annotations

import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import qualify  # noqa: E402

REF = {"ccx43": {"auction_1-1": 360334, "coop-6": 699223, "uniswap-1": 527533,
                 "harness": "b0d8a22", "measured": "2026-10-22"}}
GOOD = {"auction_1-1": 370000, "coop-6": 710000, "uniswap-1": 530000}
# The slow ccx43 of 2026-10-22: 2.1x.
SLOW = {"auction_1-1": 704000, "coop-6": 1585000, "uniswap-1": 1102000}
FAST = {"auction_1-1": 300000, "coop-6": 600000, "uniswap-1": 450000}


def write_csv(path: str, means: dict[str, float]) -> None:
    with open(path, "w") as f:
        f.write("vm,script,mean_ns,median_ns,min_ns,max_ns,stddev_ns,iterations\n")
        for s, m in means.items():
            f.write(f"haskell,{s},{m},{m},{m},{m},0,0\n")


def read_file(path: str) -> str:
    if not os.path.exists(path):
        return ""
    with open(path) as f:
        return f.read()


class DecideTest(unittest.TestCase):
    def test_pass(self):
        code, ratio, _ = qualify.decide(GOOD, REF, "ccx43")
        self.assertEqual(code, qualify.PASS)
        self.assertAlmostEqual(ratio, 1.02, places=2)

    def test_faster_passes(self):
        code, ratio, _ = qualify.decide(FAST, REF, "ccx43")
        self.assertEqual(code, qualify.PASS)
        self.assertLess(ratio, 1.0)

    def test_slow_server(self):
        code, ratio, text = qualify.decide(SLOW, REF, "ccx43")
        self.assertEqual(code, qualify.SLOW)
        self.assertAlmostEqual(ratio, 2.099, places=3)
        self.assertIn("> 1.15", text)

    def test_threshold_is_inclusive(self):
        at_limit = {s: v * 1.15 for s, v in qualify.reference_scripts(REF["ccx43"]).items()}
        self.assertEqual(qualify.decide(at_limit, REF, "ccx43")[0], qualify.PASS)
        over = {s: v * 1.151 for s, v in qualify.reference_scripts(REF["ccx43"]).items()}
        self.assertEqual(qualify.decide(over, REF, "ccx43")[0], qualify.SLOW)

    def test_missing_reference(self):
        code, ratio, text = qualify.decide(GOOD, REF, "ccx53")
        self.assertEqual(code, qualify.NO_REFERENCE)
        self.assertIsNone(ratio)
        self.assertIn("auction_1-1 370000", text)

    def test_missing_script(self):
        code, _, text = qualify.decide({"auction_1-1": 1.0}, REF, "ccx43")
        self.assertEqual(code, qualify.BAD_INPUT)
        self.assertIn("coop-6", text)

    def test_stored_reference_is_well_formed(self):
        ref = qualify.load_reference(qualify.DEFAULT_REFERENCE)
        for server_type in ("ccx33", "ccx43"):
            self.assertEqual(sorted(qualify.reference_scripts(ref[server_type])), sorted(qualify.SCRIPTS))
            self.assertEqual(ref[server_type]["harness"], "b0d8a22")
        # The ccx43 reference itself passes; the slow ccx43 of 2026-10-22 does not.
        self.assertEqual(qualify.decide(SLOW, ref, "ccx43")[0], qualify.SLOW)


class CliTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.ref = os.path.join(self.tmp.name, "ref.json")
        with open(self.ref, "w") as f:
            json.dump(REF, f)

    def run_main(self, *args: str) -> tuple[int, str]:
        out = io.StringIO()
        with redirect_stdout(out):
            code = qualify.main(list(args))
        return code, out.getvalue()

    def test_decide_line(self):
        csv_path = os.path.join(self.tmp.name, "haskell.csv")
        write_csv(csv_path, SLOW)
        code, out = self.run_main("decide", csv_path, "ccx43", "--reference", self.ref)
        self.assertEqual(code, 1)
        self.assertTrue(out.startswith("slow 2.099 "), out)

    def test_no_csv_without_reference_skips(self):
        code, out = self.run_main("decide", os.path.join(self.tmp.name, "none.csv"), "ccx53",
                                  "--reference", self.ref)
        self.assertEqual(code, 2)
        self.assertTrue(out.startswith("skip - "), out)

    def test_no_csv_with_reference_is_an_error(self):
        code, out = self.run_main("decide", os.path.join(self.tmp.name, "none.csv"), "ccx43",
                                  "--reference", self.ref)
        self.assertEqual(code, 3)
        self.assertTrue(out.startswith("error - "), out)

    def test_reference_refresh(self):
        csv_path = os.path.join(self.tmp.name, "haskell.csv")
        write_csv(csv_path, {**GOOD, "other": 5})
        code, out = self.run_main("reference", csv_path, "ccx53", "--harness", "abc1234",
                                  "--measured", "2026-11-01", "--reference", self.ref)
        self.assertEqual(code, 0)
        new = json.loads(out)
        self.assertEqual(new["ccx43"], REF["ccx43"])
        self.assertEqual(new["ccx53"], {**GOOD, "harness": "abc1234", "measured": "2026-11-01"})


# up-qualified.sh with fake up/down/qualify steps. The fake qualify step writes the next fake
# haskell.csv of the list and runs the real qualify.py decide on it.
FAKE_UP = """#!/usr/bin/env bash
set -eu
s="$BENCH_STATE/$1"; mkdir -p "$s"
n=$(( $(cat "$s/n" 2>/dev/null || echo 0) + 1 )); echo $n > "$s/n"
echo "10.0.0.$n" > "$s/ip"; echo "${BENCH_LOCATIONS%% *}" > "$s/location"
echo "up $n $BENCH_SERVER_TYPE [$BENCH_LOCATIONS]" >> "$s/calls"
"""
FAKE_DOWN = """#!/usr/bin/env bash
echo "down" >> "$BENCH_STATE/$1/calls"
"""
FAKE_QUALIFY = """#!/usr/bin/env bash
set -eu
s="$BENCH_STATE/$1"; n=$(cat "$s/n")
cp "$FAKE_CSVS/$n.csv" "$s/q.csv" 2>/dev/null || rm -f "$s/q.csv"
exec python3 "$QUALIFY_PY" decide "$s/q.csv" "$BENCH_SERVER_TYPE" --reference "$FAKE_REF"
"""


class UpQualifiedTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        t = self.tmp.name
        self.state = os.path.join(t, "state")
        self.csvs = os.path.join(t, "csvs")
        os.makedirs(self.csvs)
        self.ref = os.path.join(t, "ref.json")
        with open(self.ref, "w") as f:
            json.dump(REF, f)
        self.cmds = {}
        for name, body in (("up", FAKE_UP), ("down", FAKE_DOWN), ("qualify", FAKE_QUALIFY)):
            path = os.path.join(t, name)
            with open(path, "w") as f:
                f.write(body)
            os.chmod(path, 0o755)
            self.cmds[name] = path

    def run_loop(self, servers: list[dict | None], server_type: str = "ccx43"):
        for i, means in enumerate(servers, 1):
            if means is not None:
                write_csv(os.path.join(self.csvs, f"{i}.csv"), means)
        env = {**os.environ, "BENCH_STATE": self.state, "BENCH_SERVER_TYPE": server_type,
               "BENCH_LOCATIONS": "nbg1 fsn1 hel1", "UP_CMD": self.cmds["up"],
               "DOWN_CMD": self.cmds["down"], "QUALIFY_CMD": self.cmds["qualify"],
               "QUALIFY_PY": os.path.join(HERE, "qualify.py"), "FAKE_CSVS": self.csvs,
               "FAKE_REF": self.ref}
        p = subprocess.run([os.path.join(HERE, "up-qualified.sh"), "run-1"], env=env,
                           capture_output=True, text=True)
        s = os.path.join(self.state, "run-1")

        def read(name):
            return read_file(os.path.join(s, name))
        return p, read("calls").splitlines(), read("qualify.txt").strip(), read("qualify-summary.md")

    def test_first_server_passes(self):
        p, calls, line, summary = self.run_loop([GOOD])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(calls, ["up 1 ccx43 [nbg1 fsn1 hel1]"])
        self.assertTrue(line.startswith("pass, ratio 1.016, attempt 1 of 3, nbg1; rejected: none;"), line)
        self.assertIn("| 1 | nbg1 | 10.0.0.1 | pass:", summary)

    def test_slow_server_is_replaced(self):
        p, calls, line, _ = self.run_loop([SLOW, GOOD])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(calls, ["up 1 ccx43 [nbg1 fsn1 hel1]", "down", "up 2 ccx43 [fsn1 hel1 nbg1]"])
        self.assertIn("attempt 2 of 3, fsn1; rejected: nbg1 10.0.0.1 ratio 2.099;", line)
        self.assertEqual(read_file(os.path.join(self.state, "run-1", "ip")).strip(), "10.0.0.2")

    def test_fails_after_three_slow_servers(self):
        p, calls, line, summary = self.run_loop([SLOW, SLOW, SLOW, GOOD])
        self.assertEqual(p.returncode, 1)
        self.assertEqual(calls, ["up 1 ccx43 [nbg1 fsn1 hel1]", "down", "up 2 ccx43 [fsn1 hel1 nbg1]",
                                 "down", "up 3 ccx43 [hel1 nbg1 fsn1]", "down"])
        self.assertTrue(line.startswith("fail, 3 servers were too slow"), line)
        self.assertIn("::error::no ccx43 server passed", p.stdout)
        self.assertEqual(summary.count("| slow:"), 3)

    def test_missing_reference_skips(self):
        p, calls, line, _ = self.run_loop([SLOW], server_type="ccx53")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(calls, ["up 1 ccx53 [nbg1 fsn1 hel1]"])
        self.assertTrue(line.startswith("skipped, no reference for server type ccx53"), line)
        self.assertIn("::warning::server qualification skipped", p.stdout)

    def test_no_timing_fails_the_run(self):
        p, calls, line, _ = self.run_loop([None])
        self.assertEqual(p.returncode, 1)
        self.assertEqual(calls, ["up 1 ccx43 [nbg1 fsn1 hel1]"])
        self.assertTrue(line.startswith("error, attempt 1, nbg1"), line)


if __name__ == "__main__":
    unittest.main()
