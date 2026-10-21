#!/usr/bin/env python3
"""Parse the PVB_RESULT lines of the JS timing harnesses into the timing CSV schema.

Usage: parse_vitest.py <vm-name> <raw-log>

The harnesses (images/blaze/pvb-time.test.ts, images/scalus-js/time.test.mjs) run under vitest,
one script per process, with the JMH shape of the JVM rows: one warm-up round, then measured
rounds. Each round runs operations back to back for a fixed time and scores elapsed / ops (JMH
avgt). Per script they print one line

    PVB_RESULT {"script": ..., "rounds": [{"ops": N, "ns": elapsed}, ...], ...}

The columns are computed as parsers/parse_jmh.py does over JMH iteration scores: mean_ns is the
mean of the round scores; median_ns, min_ns, max_ns and stddev_ns are over the round scores;
iterations is the number of rounds. With one round (BENCH_TIMING=quick) stddev_ns is empty: one
value has no standard deviation.
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


def parse(vm: str, log_path: str) -> None:
    print(HEADER)
    with open(log_path, errors="replace") as f:
        content = ANSI_RE.sub("", f.read())
    for m in RESULT_RE.finditer(content):
        result = json.loads(m.group(1))
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
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <vm-name> <raw-log>", file=sys.stderr)
        sys.exit(1)
    parse(sys.argv[1], sys.argv[2])
