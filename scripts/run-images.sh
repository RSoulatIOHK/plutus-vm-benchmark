#!/usr/bin/env bash
# Runs the per-VM images one at a time (docs/IMAGE_CONTRACT.md), then builds unified.csv, runs
# the correctness gate (gate.json) and builds the report. This is what the bench server runs.
#
#   scripts/run-images.sh <results-dir> [vm ...]
#
# VMs are space- or comma-separated; the default is every VM in images/ (scripts/images.sh list).
#
# Environment:
#   IMAGE_PREFIX   image name prefix                 (default ghcr.io/lantr-io/pvb-)
#   IMAGE_TAG      tag to run                        (default latest; auto = scripts/images.sh tag <vm>,
#                  the exact image of the checked-out files)
#   PULL=1         docker pull each image first, up to 4 at a time (default 0: use local images)
#   BENCH_SCRIPTS  extended regex, full match against the script name (default: every script)
#   BENCH_LOOPS    comma list of d3, eval, check          (default d3,eval,check)
#   BENCH_TIMING   normal | quick                         (default normal)
#   BENCH_QUICK=1  shortcut: BENCH_TIMING=quick, and the first 5 scripts when BENCH_SCRIPTS is empty
#   DATA_DIR       corpus dir with plutus_use_cases/ (default <repo>/data)
#   CPUSET         --cpuset-cpus of every container (default auto: on a Linux host, every CPU
#                  except CPU 0 and its SMT siblings, so the host keeps one whole physical core;
#                  none on other hosts, for example Docker Desktop, where CPU 0 belongs to the
#                  Docker VM, not to the host). none = no CPU set
#   LANES          number of parallel lanes (default 1: one VM at a time). See "Lanes" below
#   BENCH_TRACE    1 = the JIT rows log warm-up slices into <vm>-warmup.csv (default 0)
#   DRIFT          1 = drift probe (default), 0 = off. See "Drift probe" below
#   PVB_PROGRESS   progress file, one line per stage (default <results-dir>/progress.txt)
# The BENCH_ switches are passed to the images (docs/IMAGE_CONTRACT.md). A run of a subset of
# the scripts writes their names to scripts.txt; the gate then compares only those.
#
# Order: with PULL=1 every image is pulled before the first VM runs, so a pull never overlaps a
# timing. Haskell runs first (the reference and the drift probe); the other VMs follow in the
# given order. Containers run with --network none.
#
# Lanes: LANES=n (n > 1) splits the physical cores, except the core of CPU 0 (kept for the host),
# into n lanes of the same number of whole cores. A lane has every SMT thread of its cores. Cores
# that do not divide evenly stay idle. Haskell runs first and alone, on lane 0, while the other
# lanes idle. Then each free lane takes the next VM, so up to n containers run at once, each with
# --cpuset-cpus of its lane. The drift probe runs at the end, alone, on lane 0. LANES > 1 needs a
# Linux host with the CPU topology in sysfs, CPUSET=auto and bash >= 5.1.
#   scripts/run-images.sh --lanes <n>   prints the lane layout of this host and exits
# PVB_SYSFS_CPU (default /sys/devices/system/cpu) is the topology root; tests set it to a fake tree.
#
# Drift probe: when haskell is in the list and the d3 loop runs, haskell runs once more at the
# end, d3 loop only, on 5 evenly spaced scripts of the selection. Its times go to
# haskell-drift.csv (not into unified.csv); normalize.py compares them with the same scripts of
# the first haskell run and writes drift.json and a line in environment.txt.
#
# environment.txt also records host noise data where the host has it (Linux): CPU topology, THP,
# kernel command line, cpufreq, active timers, the load average before each VM and the steal time
# during each VM and during the whole run.
#
# A VM that fails does not stop the run; the exit code is non-zero if any VM failed to run.
# A VM that fails the gate is hidden in the report; it does not change the exit code.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_PREFIX="${IMAGE_PREFIX:-ghcr.io/lantr-io/pvb-}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
PULL="${PULL:-0}"
BENCH_QUICK="${BENCH_QUICK:-0}"
BENCH_SCRIPTS="${BENCH_SCRIPTS:-}"
BENCH_LOOPS="${BENCH_LOOPS:-d3,eval,check}"
BENCH_TIMING="${BENCH_TIMING:-normal}"
BENCH_TRACE="${BENCH_TRACE:-0}"
[[ "$BENCH_QUICK" == 1 ]] && BENCH_TIMING=quick
DATA_DIR="${DATA_DIR:-$REPO_ROOT/data}"
PYTHON_IMAGE="python:3.12-slim"

die() { echo "ERROR: $*" >&2; exit 2; }

# --- CPU topology and lanes ---------------------------------------------------------------
# Expand a Linux CPU list such as "0-3,8" into one CPU number per line.
expand_cpus() {
    local part
    for part in ${1//,/ }; do
        if [[ "$part" == *-* ]]; then seq "${part%-*}" "${part#*-}"; else echo "$part"; fi
    done
}
SYSFS_CPU="${PVB_SYSFS_CPU:-/sys/devices/system/cpu}"
# The physical cores, one line each: the CPUs of the core (its SMT threads) as a sorted comma list.
# The cores are in the order of their first CPU.
physical_cores() {
    local c
    for c in $(expand_cpus "$(cat "$SYSFS_CPU/online")"); do
        expand_cpus "$(cat "$SYSFS_CPU/cpu$c/topology/thread_siblings_list")" | sort -n | paste -sd, -
    done | sort -t, -k1,1n -u
}
# split_lanes <n>: the cores on stdin (physical_cores) without the core of CPU 0, split into n lanes
# of the same number of whole cores. Prints n lines (the CPUs of each lane, sorted) and then a line
# "idle <CPUs>" (or "idle -") for the cores left over. Exits 3 when there are fewer cores than lanes.
split_lanes() {
    awk -v n="$1" -F, '
        { host = 0; for (i = 1; i <= NF; i++) if ($i == "0") host = 1
          if (!host) core[m++] = $0 }
        END {
            per = int(m / n)
            if (per < 1) { printf "%d physical cores besides the host core\n", m > "/dev/stderr"; exit 3 }
            for (l = 0; l < n; l++) {
                s = ""; for (k = 0; k < per; k++) s = s (k ? "," : "") core[l * per + k]; print s }
            s = ""; for (k = n * per; k < m; k++) s = s (s == "" ? "" : ",") core[k]
            print "idle " (s == "" ? "-" : s)
        }' | while read -r line; do
            # Sort the CPUs of each lane: "1,5,2,6" -> "1,2,5,6".
            if [[ "$line" == idle* ]]; then echo "idle $(echo "${line#idle }" | tr "," "\n" | sort -n | paste -sd, -)"; continue; fi
            echo "$line" | tr ',' '\n' | sort -n | paste -sd, -
        done
}
# lane_layout <n>: sets LANE_CPUS (one CPU list per lane) and LANE_IDLE, or dies with the reason.
lane_layout() {
    local out rc=0
    if [[ -z "${PVB_SYSFS_CPU:-}" && "$(uname -s)" != Linux ]]; then
        die "LANES=$1 needs a Linux host with the CPU topology in sysfs; this is $(uname -s) (for example Docker Desktop). Use LANES=1"
    fi
    [[ -r "$SYSFS_CPU/online" && -r "$SYSFS_CPU/cpu0/topology/thread_siblings_list" ]] \
        || die "LANES=$1 needs the CPU topology in $SYSFS_CPU (online, cpuN/topology/thread_siblings_list)"
    out=$(physical_cores | split_lanes "$1" 2>&1) || rc=$?
    if [[ $rc -ne 0 ]]; then
        die "LANES=$1 needs at least $1 physical cores besides the core of CPU 0; this host has ${out%% *}"
    fi
    LANE_CPUS=()
    while read -r line; do
        if [[ "$line" == idle* ]]; then LANE_IDLE="${line#idle }"; else LANE_CPUS+=("$line"); fi
    done <<< "$out"
}
# "lane0 1,5; lane1 2,6; idle 3,7"
lane_summary() {
    local l s=""
    for l in "${!LANE_CPUS[@]}"; do s="$s${s:+; }lane$l ${LANE_CPUS[$l]}"; done
    [[ "${LANE_IDLE:--}" == - ]] || s="$s; idle cores ${LANE_IDLE}"
    echo "$s"
}

LANES="${LANES:-1}"
[[ "$LANES" =~ ^[1-9][0-9]*$ ]] || die "LANES=$LANES: expected a whole number >= 1"
if [[ "${1:-}" == --lanes ]]; then
    n="${2:-$LANES}"
    [[ "$n" =~ ^[1-9][0-9]*$ ]] || die "--lanes $n: expected a whole number >= 1"
    lane_layout "$n"
    echo "physical cores: $(physical_cores | paste -sd' ' -)"
    echo "lanes: $n ($(lane_summary))"
    exit 0
fi

[[ $# -ge 1 ]] || { echo "usage: $0 <results-dir> [vm ...] | $0 --lanes <n>" >&2; exit 1; }
mkdir -p "$1"
RUN_DIR="$(cd "$1" && pwd)"
shift
DATA_DIR="$(cd "$DATA_DIR" && pwd)"

VMS=$(echo "$*" | tr ',' ' ')
[[ -n "${VMS// /}" ]] || VMS=$("$REPO_ROOT/scripts/images.sh" list)
VMS=$(echo "$VMS" | tr '\n' ' ')
# Haskell first: it is the reference, and the drift probe compares the end of the run with it.
if [[ " $VMS " == *" haskell "* ]]; then
    rest=""
    for vm in $VMS; do [[ "$vm" == haskell ]] || rest="$rest $vm"; done
    VMS="haskell$rest"
fi
DRIFT="${DRIFT:-1}"
DRIFT_N=5

# --- switches: the same checks as image-entry.sh, before any image runs ------------------
case "$BENCH_TIMING" in normal | quick) ;; *) die "BENCH_TIMING=$BENCH_TIMING: expected normal or quick" ;; esac
[[ -n "${BENCH_LOOPS//[ ,]/}" ]] || die "BENCH_LOOPS is empty (expected a comma list of d3, eval, check)"
for loop in ${BENCH_LOOPS//,/ }; do
    case "$loop" in d3 | eval | check) ;; *) die "BENCH_LOOPS=$BENCH_LOOPS: unknown loop '$loop'" ;; esac
done
case "$BENCH_TRACE" in 0 | 1) ;; *) die "BENCH_TRACE=$BENCH_TRACE: expected 0 or 1" ;; esac
has_loop() { [[ ",${BENCH_LOOPS// /}," == *",$1,"* ]]; }

# The selected scripts (image-entry.sh selects the same ones inside each image).
ALL_SCRIPTS=$(for f in "$DATA_DIR"/plutus_use_cases/*.flat; do basename "$f" .flat; done | LC_ALL=C sort)
if [[ -n "$BENCH_SCRIPTS" ]]; then
    # grep exits 1 for no match, 2 for a bad regex.
    rc=0
    SELECTED=$(echo "$ALL_SCRIPTS" | grep -E -- "^(${BENCH_SCRIPTS})\$") || rc=$?
    [[ $rc -le 1 ]] || die "BENCH_SCRIPTS='$BENCH_SCRIPTS' is not a valid extended regex"
    [[ -n "$SELECTED" ]] || die "BENCH_SCRIPTS='$BENCH_SCRIPTS' matches no script in $DATA_DIR/plutus_use_cases"
elif [[ "$BENCH_QUICK" == 1 ]]; then
    SELECTED=$(echo "$ALL_SCRIPTS" | head -5)
else
    SELECTED="$ALL_SCRIPTS"
fi
rm -f "$RUN_DIR/scripts.txt"
if [[ "$SELECTED" != "$ALL_SCRIPTS" ]]; then
    echo "$SELECTED" > "$RUN_DIR/scripts.txt"
fi

# --- host noise probes: Linux only, "n/a" where the host lacks the source -------------------
# cpu_ticks: "<steal> <total>" of all CPUs since boot (/proc/stat, USER_HZ ticks), else empty.
# In the "cpu" line field 9 is steal; fields 2..9 (user .. steal) add up to the total.
cpu_ticks() {
    if [[ -r /proc/stat ]]; then
        awk '/^cpu / { t = 0; for (i = 2; i <= 9; i++) t += $i; print $9, t; exit }' /proc/stat
    fi
}
# steal_between <ticks before> <ticks after>: steal time as a share of all CPU time in between.
steal_between() {
    if [[ -z "$1" || -z "$2" ]]; then echo "n/a"; return; fi
    awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, " "); split(b, y, " "); s = y[1] - x[1]; t = y[2] - x[2]
        printf "%.2f %% (%d of %d ticks)", (t > 0 ? 100 * s / t : 0), s, t }'
}
load_avg() {
    if [[ -r /proc/loadavg ]]; then cut -d' ' -f1-3 /proc/loadavg
    else sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' | xargs || echo "n/a"
    fi
}
# The value in brackets of a sysfs choice file ("always [madvise] never" -> madvise).
sysfs_choice() {
    if [[ -r "$1" ]]; then sed 's/.*\[\(.*\)\].*/\1/' "$1"; else echo "n/a"; fi
}

# --- docker run flags -------------------------------------------------------------------
# --network none: no VM needs the network at run time. --cpuset-cpus: every VM gets the same CPUs,
# and the whole physical core of CPU 0 stays for the host (dockerd, sshd, interrupts). A Hetzner
# ccx33 has 8 vCPUs = 4 cores x 2 SMT threads: leaving only CPU 0 would let the benchmark thread
# share a core with host work through CPU 0's sibling. On Docker Desktop the containers run in a
# Linux VM whose CPU 0 is not the host's, so the CPU set would protect nothing.


CPUSET="${CPUSET:-auto}"
if [[ "$LANES" -gt 1 ]]; then
    # Each lane has its own CPU set (see "Lanes" at the top); the containers get it per run.
    [[ "$CPUSET" == auto ]] || die "LANES=$LANES needs CPUSET=auto (CPUSET=$CPUSET)"
    [[ $((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1])) -ge 501 ]] \
        || die "LANES=$LANES needs bash >= 5.1 (wait -n -p); this is $BASH_VERSION"
    lane_layout "$LANES"
    CPUSET=lanes
elif [[ "$CPUSET" == auto ]]; then
    CPUSET=none
    sys=/sys/devices/system/cpu
    if [[ "$(uname -s)" == Linux && -r $sys/online && -r $sys/cpu0/topology/thread_siblings_list ]]; then
        host_cpus=" $(expand_cpus "$(cat $sys/cpu0/topology/thread_siblings_list)" | tr '\n' ' ')"
        bench_cpus=()
        for c in $(expand_cpus "$(cat $sys/online)"); do
            [[ "$host_cpus" == *" $c "* ]] || bench_cpus+=("$c")
        done
        if [[ ${#bench_cpus[@]} -gt 0 ]]; then
            CPUSET=$(IFS=,; echo "${bench_cpus[*]}")
        fi
    fi
fi
DOCKER_FLAGS=(--rm --cap-add SYS_NICE --network none)
if [[ "$LANES" -eq 1 ]]; then
    # One lane: the CPU set is in DOCKER_FLAGS, and run_image adds none.
    [[ "$CPUSET" == none ]] || DOCKER_FLAGS+=(--cpuset-cpus "$CPUSET")
    LANE_CPUS=("")
    LANE_LINE="lanes: 1 (lane0 $CPUSET)"
else
    LANE_LINE="lanes: $LANES ($(lane_summary))"
fi

# --- environment.txt: hardware, software, noise, images ----------------------------------
# Keys cpu, cores and memory feed the report's header badge; keep the other keys distinct.
RUN_TICKS_START=$(cpu_ticks)
{
    echo "date: $(date -Iseconds 2>/dev/null || date)"
    echo "kernel: $(uname -sr)"
    if [[ -r /proc/cpuinfo ]]; then
        echo "cpu: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
        echo "cores: $(nproc)"
        echo "memory: $(free -h | awk '/Mem:/ {print $2}')"
        flags=" $(grep -m1 '^flags' /proc/cpuinfo | cut -d: -f2 || true) "
        isa=""
        for f in hypervisor sse4_2 avx avx2 bmi2 fma avx512f avx512_vnni sha_ni vaes; do
            [[ "$flags" == *" $f "* ]] && isa="$isa $f"
        done
        echo "cpu flags (selected):${isa:- none}"
    else
        echo "cpu: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m)"
        echo "cores: $(sysctl -n hw.ncpu 2>/dev/null || echo unknown)"
        echo "memory: $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))G"
    fi
    if command -v lscpu >/dev/null 2>&1; then
        # Only the lscpu fields this host has (aarch64 has clusters, not sockets), "key value; ...".
        echo "topology: $(LC_ALL=C lscpu | awk -F: '
            /^(Model name|Thread\(s\) per core|Core\(s\) per (socket|cluster)|Socket\(s\)|Cluster\(s\)|NUMA node\(s\)|Hypervisor vendor|Virtualization type):/ {
                v = $2; gsub(/^ +| +$/, "", v); if (v != "-") { printf "%s%s %s", sep, $1, v; sep = "; " } }')"
        mhz=$(LC_ALL=C lscpu | awk -F: '/MHz/ { gsub(/^ +/, "", $2); printf "%s%s %s", sep, $1, $2; sep = ", " }')
        echo "lscpu mhz: ${mhz:-n/a}"
    else
        echo "topology: n/a (no lscpu)"
    fi
    cpufreq=/sys/devices/system/cpu/cpu0/cpufreq
    if [[ -d "$cpufreq" ]]; then
        echo "cpufreq: governor $(cat "$cpufreq/scaling_governor" 2>/dev/null || echo n/a), cur $(cat "$cpufreq/scaling_cur_freq" 2>/dev/null || echo n/a) kHz, max $(cat "$cpufreq/cpuinfo_max_freq" 2>/dev/null || echo n/a) kHz"
    elif [[ -d /sys/devices/system/cpu ]]; then
        echo "cpufreq: none (no cpufreq driver, for example a KVM guest)"
    else
        echo "cpufreq: n/a"
    fi
    thp=/sys/kernel/mm/transparent_hugepage
    echo "thp: enabled $(sysfs_choice "$thp/enabled"), defrag $(sysfs_choice "$thp/defrag")"
    echo "kernel cmdline: $(cat /proc/cmdline 2>/dev/null || echo n/a)"
    if command -v systemctl >/dev/null 2>&1; then
        echo "timers: $(systemctl list-units --type=timer --state=active --no-legend --plain 2>/dev/null \
            | awk '{print $1}' | paste -sd' ' - || echo n/a)"
    fi
    echo "load avg at start: $(load_avg)"
    echo "docker: $(docker version --format '{{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})' 2>/dev/null || echo unknown)"
    echo "docker cpus: $(docker info --format '{{.NCPU}}' 2>/dev/null || echo unknown)"
    echo "docker memory: $(( $(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0) / 1048576 )) MiB"
    echo "docker run flags: ${DOCKER_FLAGS[*]}"
    echo "$LANE_LINE"
    [[ "$LANES" -eq 1 ]] || echo "parallel: yes (up to $LANES VMs at once; haskell and the drift probe run alone on lane0)"
    [[ "$CPUSET" != none ]] || echo "docker cpuset: none ($(uname -s) host)"
    echo "harness: ${PVB_HARNESS:-$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)}"
    echo "vm order: $VMS"
    echo "bench_quick: $BENCH_QUICK"
    echo "bench_scripts: ${BENCH_SCRIPTS:-<all>} ($(echo "$SELECTED" | wc -l | tr -d ' ') of $(echo "$ALL_SCRIPTS" | wc -l | tr -d ' ') scripts)"
    echo "bench_loops: $BENCH_LOOPS"
    echo "bench_timing: $BENCH_TIMING"
    echo "bench_trace: $BENCH_TRACE"
} > "$RUN_DIR/environment.txt"
cat "$RUN_DIR/environment.txt"
# The pins of this run, so a page re-rendered later (publish-page.yml) shows the versions that ran.
cp "$REPO_ROOT/.env" "$RUN_DIR/pins.env"

image_of() {
    local tag="$IMAGE_TAG"
    [[ "$tag" == auto ]] && tag=$("$REPO_ROOT/scripts/images.sh" tag "$1")
    echo "${IMAGE_PREFIX}$1:${tag}"
}

# A temp dir for the pull markers and the output of parallel runs.
WORK=$(mktemp -d "${TMPDIR:-/tmp}/pvb-run.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# --- pull every image first: no pull overlaps a timing -----------------------------------
# Up to 4 pulls at a time. A pull that fails twice leaves a marker; that VM counts as failed.
FAILED=""
PULL_FAILED=" "
pull_one() {
    local image
    image=$(image_of "$1")
    echo "pull ${1}: ${image}"
    if ! docker pull -q "$image" && ! docker pull -q "$image"; then
        echo "FAIL: ${1}: cannot pull ${image}"
        : > "$WORK/pull-failed-$1"
    fi
}
if [[ "$PULL" == 1 ]]; then
    n=0
    for vm in $VMS; do
        pull_one "$vm" &
        n=$((n + 1))
        if [[ $((n % 4)) -eq 0 ]]; then wait; fi
    done
    wait
    for vm in $VMS; do
        if [[ -e "$WORK/pull-failed-$vm" ]]; then PULL_FAILED="$PULL_FAILED$vm "; fi
    done
fi

# run_image <image> <results dir> <BENCH_SCRIPTS> <BENCH_LOOPS> <BENCH_QUICK> <BENCH_TRACE> <cpuset>
# An empty cpuset adds no --cpuset-cpus: with one lane the CPU set is in DOCKER_FLAGS.
run_image() {
    local cpus=()
    [[ -z "$7" ]] || cpus=(--cpuset-cpus "$7")
    local cmd=(docker run "${DOCKER_FLAGS[@]}" ${cpus[@]+"${cpus[@]}"}
        -e BENCH_QUICK="$5" -e BENCH_SCRIPTS="$3" -e BENCH_LOOPS="$4" -e BENCH_TIMING="$BENCH_TIMING"
        -e BENCH_TRACE="$6" -v "$DATA_DIR:/bench/data:ro" -v "$2:/results" "$1")
    echo "${cmd[*]}"
    "${cmd[@]}"
}

# --- progress file ----------------------------------------------------------------------
# One line per stage, so a watcher (run-remote.sh status) can show "blaze-v8 3/9 running".
# With LANES > 1 each VM line ends with its lane, for example "blaze-v8 3/9 running lane1".
PROGRESS="${PVB_PROGRESS:-$RUN_DIR/progress.txt}"
N_VMS=$(echo "$VMS" | wc -w | tr -d ' ')
RUN_START=$(date +%s)
progress() { echo "$(date -u +%H:%M) $*" >> "$PROGRESS"; }
# The lane suffix of the progress lines: empty with one lane.
lane_tag() { [[ "$LANES" -eq 1 ]] || echo " lane$1"; }

# --- run each VM ------------------------------------------------------------------------
# vm_begin <vm>: prints the header and records the image; returns 1 when its pull failed.
vm_begin() {
    local image digest
    image=$(image_of "$1")
    echo ""
    echo "---------------------------------------------"
    echo " ${1}: ${image}"
    echo "---------------------------------------------"
    if [[ "$PULL_FAILED" == *" $1 "* ]]; then
        FAILED="$FAILED $1"
        echo "image ${1}: ${image} (pull failed)" >> "$RUN_DIR/environment.txt"
        return 1
    fi
    digest=$(docker image inspect --format '{{if .RepoDigests}}{{index .RepoDigests 0}}{{else}}{{.Id}}{{end}}' "$image" 2>/dev/null || echo missing)
    echo "image ${1}: ${image} ${digest}" >> "$RUN_DIR/environment.txt"
}
# vm_end <vm> <i> <lane> <rc> <start> <load before> <ticks before>: result, progress, noise line.
# Load average and steal time are for the whole host, so with LANES > 1 they include the VMs that
# ran at the same time.
vm_end() {
    local secs=$(( $(date +%s) - $5 ))
    if [[ $4 -eq 0 ]]; then
        echo "OK: ${1} in ${secs} s"
        progress "$1 $2/$N_VMS ok in $(( secs / 60 )) min$(lane_tag "$3")"
    else
        echo "FAIL: ${1} exited with $4 after ${secs} s"
        progress "$1 $2/$N_VMS FAILED (exit $4) after $(( secs / 60 )) min$(lane_tag "$3")"
        FAILED="$FAILED $1"
    fi
    echo "noise ${1}: load avg before $6, steal during run $(steal_between "$7" "$(cpu_ticks)")$(lane_tag "$3")" \
        >> "$RUN_DIR/environment.txt"
}
# run_vm <vm> <i> <lane>: one VM in the foreground, on the CPUs of the lane.
run_vm() {
    local load_before ticks_before start rc=0
    vm_begin "$1" || return 0
    load_before=$(load_avg)
    ticks_before=$(cpu_ticks)
    start=$(date +%s)
    progress "$1 $2/$N_VMS running$(lane_tag "$3")"
    run_image "$(image_of "$1")" "$RUN_DIR" "$BENCH_SCRIPTS" "$BENCH_LOOPS" "$BENCH_QUICK" "$BENCH_TRACE" \
        "${LANE_CPUS[$3]}" || rc=$?
    vm_end "$1" "$2" "$3" "$rc" "$start" "$load_before" "$ticks_before"
}

i=0
if [[ "$LANES" -eq 1 ]]; then
    for vm in $VMS; do
        i=$((i + 1))
        run_vm "$vm" "$i" 0
    done
else
    QUEUE=()
    for vm in $VMS; do
        if [[ "$vm" == haskell ]]; then
            # The reference runs first and alone, on lane 0: the other lanes idle.
            i=$((i + 1))
            run_vm haskell "$i" 0
        else
            QUEUE+=("$vm")
        fi
    done
    # A work queue: each free lane takes the next VM. Every record (environment.txt, FAILED,
    # progress) is written here in the main shell, when a container starts or ends. The output of
    # a container goes to a file and is printed when it ends, so run.log does not interleave.
    declare -A JOB_VM JOB_I JOB_LANE JOB_START JOB_LOAD JOB_TICKS
    FREE_LANES=()
    for l in "${!LANE_CPUS[@]}"; do FREE_LANES+=("$l"); done
    next=0
    running=0
    while [[ $next -lt ${#QUEUE[@]} || $running -gt 0 ]]; do
        while [[ $next -lt ${#QUEUE[@]} && ${#FREE_LANES[@]} -gt 0 ]]; do
            vm=${QUEUE[$next]}
            next=$((next + 1))
            i=$((i + 1))
            vm_begin "$vm" || continue
            lane=${FREE_LANES[0]}
            FREE_LANES=("${FREE_LANES[@]:1}")
            load_before=$(load_avg)
            ticks_before=$(cpu_ticks)
            progress "$vm $i/$N_VMS running$(lane_tag "$lane")"
            echo "started on lane$lane (CPUs ${LANE_CPUS[$lane]}); output follows when it ends"
            run_image "$(image_of "$vm")" "$RUN_DIR" "$BENCH_SCRIPTS" "$BENCH_LOOPS" "$BENCH_QUICK" \
                "$BENCH_TRACE" "${LANE_CPUS[$lane]}" > "$WORK/$vm.log" 2>&1 &
            pid=$!
            JOB_VM[$pid]=$vm
            JOB_I[$pid]=$i
            JOB_LANE[$pid]=$lane
            JOB_START[$pid]=$(date +%s)
            JOB_LOAD[$pid]=$load_before
            JOB_TICKS[$pid]=$ticks_before
            running=$((running + 1))
        done
        [[ $running -gt 0 ]] || break
        # set -e: a container that fails must not end the script, so take wait's status here.
        rc=0
        pid=""
        wait -n -p pid || rc=$?
        [[ -n "$pid" ]] || die "wait -n returned no job (exit $rc)"
        vm=${JOB_VM[$pid]}
        running=$((running - 1))
        FREE_LANES+=("${JOB_LANE[$pid]}")
        echo ""
        echo "---------------------------------------------"
        echo " ${vm} (lane${JOB_LANE[$pid]}): output"
        echo "---------------------------------------------"
        cat "$WORK/$vm.log"
        vm_end "$vm" "${JOB_I[$pid]}" "${JOB_LANE[$pid]}" "$rc" "${JOB_START[$pid]}" "${JOB_LOAD[$pid]}" "${JOB_TICKS[$pid]}"
    done
fi

# --- drift probe: haskell again at the end, on a fixed subset -----------------------------
# The subset is DRIFT_N evenly spaced scripts of the selection, so the full run always uses the
# same ones. Same timing as the first pass; d3 loop only. The container writes to drift/; the
# timing is copied to haskell-drift.csv, which normalize.py keeps out of unified.csv.
if [[ "$DRIFT" == 1 ]] && has_loop d3 && [[ " $VMS " == *" haskell "* ]]; then
    if [[ "$VMS" == haskell ]]; then
        echo "drift (haskell, end vs start): skipped, haskell is the only VM" >> "$RUN_DIR/environment.txt"
    elif [[ " $FAILED " == *" haskell "* || ! -s "$RUN_DIR/haskell.csv" ]]; then
        echo "drift (haskell, end vs start): skipped, the first haskell run failed" >> "$RUN_DIR/environment.txt"
    else
        DRIFT_SCRIPTS=$(echo "$SELECTED" | awk -v k="$DRIFT_N" '{ a[NR] = $0 }
            END { if (NR < k) k = NR; for (i = 0; i < k; i++) print a[1 + int(i * NR / k)] }')
        echo ""
        echo "---------------------------------------------"
        echo " drift probe: haskell on $(echo "$DRIFT_SCRIPTS" | paste -sd' ' -)"
        echo "---------------------------------------------"
        mkdir -p "$RUN_DIR/drift"
        rm -f "$RUN_DIR/haskell-drift.csv"
        progress "drift probe (haskell) running$(lane_tag 0)"
        rc=0
        # Alone, on lane 0. No warm-up trace: drift/ holds only the drift timing.
        run_image "$(image_of haskell)" "$RUN_DIR/drift" "$(echo "$DRIFT_SCRIPTS" | paste -sd'|' -)" d3 0 0 \
            "${LANE_CPUS[0]}" || rc=$?
        if [[ $rc -eq 0 && -s "$RUN_DIR/drift/haskell.csv" ]]; then
            cp "$RUN_DIR/drift/haskell.csv" "$RUN_DIR/haskell-drift.csv"
        else
            echo "drift (haskell, end vs start): skipped, the drift run failed (exit $rc)" >> "$RUN_DIR/environment.txt"
        fi
    fi
fi
echo "steal during the whole run: $(steal_between "$RUN_TICKS_START" "$(cpu_ticks)")" >> "$RUN_DIR/environment.txt"
echo "load avg at end: $(load_avg)" >> "$RUN_DIR/environment.txt"

progress "VMs done after $(( ($(date +%s) - RUN_START) / 60 )) min; building unified.csv, gate, report"

# --- unified.csv, gate, report ----------------------------------------------------------
echo ""
echo "---------------------------------------------"
echo " Normalizing results"
echo "---------------------------------------------"

# The images run as root. On a Linux host, give the results back to the calling user.
if [[ "$(uname -s)" == Linux && "$(id -u)" != 0 ]]; then
    docker run --rm -v "$RUN_DIR:/run-dir" "$PYTHON_IMAGE" chown -R "$(id -u):$(id -g)" /run-dir
fi

# The parsers need Python >= 3.10. Use the host's when it is new enough, else a container.
# PY runs python3; ROOT and RUN are the repo and the run dir as PY sees them.
if python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null; then
    PY=(python3)
    ROOT="$REPO_ROOT"
    RUN="$RUN_DIR"
else
    # Keep the run dir's name: the report uses it as the run date. Mount the parent dir, so the
    # report sees the earlier runs next to this one (history chart).
    ROOT=/repo
    RUN="/runs/$(basename "$RUN_DIR")"
    PY=(docker run --rm --user "$(id -u):$(id -g)" \
        -v "$REPO_ROOT:/repo" -v "$(dirname "$RUN_DIR"):/runs" "$PYTHON_IMAGE" python3)
fi

# normalize.py prints the drift line (drift probe) on stdout, if there is one.
drift_line=$("${PY[@]}" "$ROOT/parsers/normalize.py" "$RUN")
if [[ -n "$drift_line" ]]; then
    echo "$drift_line"
    echo "$drift_line" >> "$RUN_DIR/environment.txt"
fi

# --- correctness gate (check/README.md) -------------------------------------------------
# Every <vm>-check.csv against the Haskell reference; the mode per VM comes from
# check/modes.conf. The verdicts go to gate.json, which the report reads: a VM that fails is
# hidden. A gate failure does not stop the report. Without the check loop there is no gate and
# no gate.json: the report shows every VM as "not checked".
echo ""
echo "---------------------------------------------"
echo " Correctness gate"
echo "---------------------------------------------"
rm -f "$RUN_DIR/gate.json"
SCRIPTS_ARG=()
[[ -f "$RUN_DIR/scripts.txt" ]] && SCRIPTS_ARG=(--scripts "$RUN/scripts.txt")
CHECKS=()
for f in "$RUN_DIR"/*-check.csv; do
    [[ -f "$f" ]] && CHECKS+=("$RUN/$(basename "$f")")
done
MODES=()
while read -r vm mode _; do
    [[ -z "$vm" || "$vm" == \#* ]] && continue
    # gate.py rejects a mode for a VM without a check file.
    [[ -f "$RUN_DIR/$vm-check.csv" ]] || continue
    [[ -n "$mode" ]] || mode=strict
    case "$mode" in
        badge:*) MODES+=(--mode "$vm=badge:$ROOT/${mode#badge:}") ;;
        *) MODES+=(--mode "$vm=$mode") ;;
    esac
done < "$REPO_ROOT/check/modes.conf"
GATE_FAILED=""
if ! has_loop check; then
    echo "BENCH_LOOPS=$BENCH_LOOPS has no check: no gate, the report marks every VM as not checked"
elif [[ ${#CHECKS[@]} -eq 0 ]]; then
    echo "WARNING: no <vm>-check.csv in $RUN_DIR; every VM counts as failed check"
    echo '{"reference": null, "ok": false, "vms": {}}' > "$RUN_DIR/gate.json"
    GATE_FAILED=1
else
    gate_rc=0
    "${PY[@]}" "$ROOT/check/gate.py" --reference "$ROOT/check/reference/haskell-check.csv" \
        --json "$RUN/gate.json" ${SCRIPTS_ARG[@]+"${SCRIPTS_ARG[@]}"} ${MODES[@]+"${MODES[@]}"} \
        "${CHECKS[@]}" || gate_rc=$?
    if [[ $gate_rc -eq 2 || ! -f "$RUN_DIR/gate.json" ]]; then
        echo "WARNING: the gate could not read its input (exit $gate_rc); every VM counts as failed check"
        echo '{"reference": null, "ok": false, "vms": {}}' > "$RUN_DIR/gate.json"
        GATE_FAILED=1
    elif [[ $gate_rc -ne 0 ]]; then
        GATE_FAILED=1
    fi
fi

# --- report -----------------------------------------------------------------------------
# report.md and index.html in the run dir. Not docs/index.html: run.yml writes the published page
# (generate_report.py --write-index).
"${PY[@]}" "$ROOT/report/generate_report.py" "$RUN"

echo ""
echo "Results: $RUN_DIR"
if [[ -n "$GATE_FAILED" ]]; then
    echo "Gate: at least one VM failed the check (gate.json); its row is hidden in the report"
fi
if [[ -n "$FAILED" ]]; then
    echo "Failed VMs:$FAILED"
    exit 1
fi
