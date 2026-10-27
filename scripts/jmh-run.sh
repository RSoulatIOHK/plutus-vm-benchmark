# Shared JMH settings of the JVM rows (scalus-cek, scalus-jit, julc-java). Not a run script: the
# run scripts source it. images/jvm-base copies it to /bench/scripts/jmh-run.sh.
#
#   JAVA=...           optional, before sourcing: the java binary (default Oracle GraalVM of the
#                      base image, /opt/jdk-25/bin/java). It is the JMH launcher and the forked JVM.
#   source /bench/scripts/jmh-run.sh
#   jmh_command "<launcher flags>" "<fork flags>"
#   "${JMH_CMD[@]}" -rf json -rff out.json -p file=... <benchmark regex>
#
# Timing (METHODOLOGY.md, D13): one 30 s warm-up iteration, then 3 measurement iterations of 5 s
# each, so the CSV has a standard deviation over the iteration means; one fork (-f 1), one thread.
# The JS rows use an adaptive warm-up with a 30 s cap; the JMH rows keep JMH's own warm-up
# iterations at that cap.
# BENCH_TRACE=1: the same 30 s of warm-up as 30 iterations of 1 s (-wi 30 -w 1s), so the log has
# a score per second; parse_warmup.py writes them to $VM-warmup.csv. The measurement settings stay
# the same (the measured time can differ, METHODOLOGY.md).
# BENCH_TIMING=quick: one 1 s warm-up iteration and one 1 s measurement iteration.
# shellcheck shell=bash

WARMUP=30s
WARMUP_ITERATIONS=1
MEASURE=5s
ITERATIONS=3
if [[ "${BENCH_TRACE:-0}" == 1 ]]; then
    WARMUP=1s
    WARMUP_ITERATIONS=30
fi
if [[ "${BENCH_TIMING:-normal}" == quick ]]; then
    WARMUP=1s
    WARMUP_ITERATIONS=1
    MEASURE=1s
    ITERATIONS=1
fi

# Heap of the forked benchmark JVM, pre-touched. Lower it only on small machines.
HEAP="${PVB_BENCH_HEAP:-4g}"

JAVA="${JAVA:-/opt/jdk-25/bin/java}"
[[ -x "$JAVA" ]] || { echo "ERROR: java binary $JAVA is not there" >&2; exit 1; }

# JMH_CMD: the JMH launcher with the common options. $1: flags of the launcher JVM (for example
# -Xss64m); $2: flags of the forked JVM, before the heap flags.
jmh_command() {
    # $1 and $2 are flag lists: split them on purpose.
    # shellcheck disable=SC2206
    JMH_CMD=("$JAVA" $1 -Xmx4g -cp "$CP" org.openjdk.jmh.Main
        -i "$ITERATIONS" -wi "$WARMUP_ITERATIONS" -w "$WARMUP" -r "$MEASURE" -f 1 -t 1
        -jvm "$JAVA" -jvmArgsAppend "${2:+$2 }-XX:+AlwaysPreTouch -Xms$HEAP")
}
