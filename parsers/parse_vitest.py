#!/usr/bin/env python3
"""Parse the PVB_RESULT lines of the JS timing harnesses into the timing CSV schema.

Usage: parse_vitest.py <vm-name> <raw-log> [loop]

The harnesses (images/blaze/pvb-time.test.ts under vitest; images/scalus-js/time.mjs and
images/aiken-wasm/time.mjs under plain node) run one script per process, with the JMH shape of
the JVM rows: one warm-up round, then measured rounds. Each round runs operations back to back
for a fixed time and scores elapsed / ops (JMH avgt). Per script they print one line

    PVB_RESULT {"script": ..., "rounds": [{"ops": N, "ns": elapsed}, ...], ...}

The columns are computed as parsers/parse_jmh.py does over JMH iteration scores: mean_ns is the
mean of the round scores; median_ns, min_ns, max_ns and stddev_ns are over the round scores;
iterations is the number of rounds. With one round (BENCH_TIMING=quick) stddev_ns is empty: one
value has no standard deviation.

With a loop (d3 or eval), only the PVB_RESULT lines of that loop: the blaze harness runs both loops
in one process per script and prints one PVB_RESULT per loop. A line without a loop field is d3.
"""

import json
import re
import statistics
import sys

HEADER = "vm,script,mean_ns,median_ns,min_ns,max_ns,stddev_ns,iterations"

# Strip ANSI escape codes. vitest may put a prefix before a console line, so the token is not
# anchored at the line start.
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
RESULT_RE = re.compile(r"PVB_RESULT (\{.*\})\s*$", re.MULTILINE)


def parse(vm: str, log_path: str, loop: str | None = None) -> None:
    print(HEADER)
    with open(log_path, errors="replace") as f:
        content = ANSI_RE.sub("", f.read())
    for m in RESULT_RE.finditer(content):
        result = json.loads(m.group(1))
        if loop is not None and result.get("loop", "d3") != loop:
            continue
        scores = [r["ns"] / r["ops"] for r in result["rounds"] if r["ops"] > 0]
        if not scores:
            continue
        stddev = str(int(statistics.stdev(scores))) if len(scores) > 1 else ""
        print(
            f"{vm},{result['script']},"
            f"{int(statistics.fmean(scores))},{int(statistics.median(scores))},"
            f"{int(min(scores))},{int(max(scores))},"
            f"{stddev},{len(scores)}"
        )


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        print(f"Usage: {sys.argv[0]} <vm-name> <raw-log> [loop]", file=sys.stderr)
        sys.exit(1)
    parse(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) == 4 else None)
