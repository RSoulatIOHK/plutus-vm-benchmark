# Per-VM image contract

Every VM in the line-up is one Docker image. The run on the bench server pulls the images and runs
them one at a time. This file is the interface between an image and the rest of the harness.

## Layout

- `images/<vm>/Dockerfile`. Build context is the repo root, so the Dockerfile can `COPY` from
  `parsers/`, `scripts/` and `images/<vm>/`.
- Pins (repo URL, SHA or tag, toolchain versions) come from `.env` as build args with the same names. An `ARG` with a
  default in the Dockerfile (for example `ARG CARGO_BUILD_JOBS=2`) needs no `.env` value.
- `<vm>` is lowercase with dashes, for example `scalus-cek`, `blaze-v8`.
- Published as `ghcr.io/lantr-io/pvb-<vm>:<tag>` and `:latest`. The tag is `scripts/images.sh tag <vm>`:
  a hash of `images/<dir>/`, the repo files the Dockerfile `COPY`s and the `.env` values of its `ARG`s.
  An unchanged VM keeps its tag, so CI does not rebuild it.
- Variants of one build share a Dockerfile: `images/<family>/Dockerfile` with a header line
  `# pvb-vms: <vm> <vm>...` and an `ARG VM` that sets the default command. Each variant is still its
  own image. Today: `images/scalus/` (`scalus-cek`, `scalus-jit`). `images/blaze/` serves one VM,
  `blaze-v8`, named after its engine by the header line `# pvb-vms: blaze-v8`.
- Default command: `ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]` with `ENV PVB_VM=<vm>`. The
  entry script prepares the data, runs `scripts/run-<vm>.sh /results` and sets the exit code.
- Build locally: `scripts/images.sh build <vm>`. Run several: `scripts/run-images.sh <results-dir> [vm ...]`.

## Run

```bash
docker run --rm --cap-add SYS_NICE \
  -v "$PWD/data:/bench/data:ro" -v "$PWD/results/<date>:/results" \
  ghcr.io/lantr-io/pvb-<vm>:<tag>
```

- Input: every `/bench/data/plutus_use_cases/*.flat`. The script name is the file name without `.flat`.
- Default command runs the timed loops AND the check over every script, then exits 0. A single
  script that fails is a row with an error, not a failed container.

### Switches

Three environment variables select a subset, and a fourth turns on the warm-up trace.
`image-entry.sh` checks them and exits 2 on a bad value; `scripts/run-images.sh` and the `run`
workflow pass them through and record them in `environment.txt`.

| Variable | Values | Default |
|---|---|---|
| `BENCH_SCRIPTS` | Extended regex, full match against the script name, e.g. `auction_.*\|uniswap-1`. No match is an error | empty = every script |
| `BENCH_LOOPS` | Comma list of `d3` (`<vm>.csv`), `eval` (`<vm>-eval.csv`), `check` (`<vm>-check.csv`) | `d3,eval,check` |
| `BENCH_TIMING` | `normal`, or `quick`: short warm-up and measurement (for smoke tests) | `normal` |
| `BENCH_TRACE` | `0`, or `1`: the JIT rows also write `<vm>-warmup.csv` (see below) | `0` |

`BENCH_QUICK=1` is a shortcut: `BENCH_TIMING=quick` and, when `BENCH_SCRIPTS` is empty, the first 5
scripts (C sort order).

How the image applies them:

- `image-entry.sh` copies the selected scripts to a temporary dir and exports it as
  `$BENCH_DATA_DIR` (without a selection it is `/bench/data/plutus_use_cases`). Every loop of the
  run script, the check too, reads only `$BENCH_DATA_DIR`. So the check covers exactly the selected
  scripts, and the gate compares only those (`check/gate.py --scripts`, written by `run-images.sh`
  as `scripts.txt`). A selected script that a VM's check lacks still fails as "missing".
- The run script gets `$BENCH_LOOPS` and `$BENCH_TIMING` and runs only the requested loops.
- A run script declares the loops it has in a header line, for example `# pvb-loops: d3 check`
  (scalus-js has no eval loop). `image-entry.sh` skips a requested loop the VM does not have, with a
  note; when none is left it exits 0 without running anything.
- The Scalus JIT has one timed loop (evaluation of the compiled script). It runs when `d3` or
  `eval` is requested and writes the same rows to `<vm>.csv` (for `d3`) and `<vm>-eval.csv` (for
  `eval`). `<vm>-compile.csv` comes from the check, so it needs `check`.

### Exit code

- 2: a bad switch, or `BENCH_SCRIPTS` matches no script.
- 1: the VM could not run: a requested loop (that the VM has) wrote no file, no timing file has
  a timed row, or the requested check file has no row.
- 0: otherwise.

## Outputs (all in `/results`)

| File | Content |
|---|---|
| `<vm>.csv` | Timing, schema `vm,script,mean_ns,median_ns,min_ns,max_ns,stddev_ns,iterations`. A failed script has `-1` in every number column |
| `<vm>-check.csv` | Correctness, schema `vm,script,status,cpu,mem`. `status` is `ok` or `error`. `cpu`/`mem` are the ExUnits the VM's own costing reports for one evaluation (empty when the VM has no costing) |
| `<vm>-raw.log` | Raw tool output of the timed loops (both loops, one process per script), for debugging |
| `<vm>-eval.csv` | Eval-only timing, same schema as `<vm>.csv`: evaluation of a program decoded once outside the timed loop. Shown as a second column next to the D3 time |
| `<vm>-compile.csv` | Only for VMs that compile before they run (Scalus JIT): `vm,script,compile_ns` |
| `<vm>-warmup.csv` | Only with `BENCH_TRACE=1`, for the JIT rows (scalus-cek, scalus-jit, blaze-v8, scalus-js, aiken-wasm): `vm,script,loop,second,ns_per_op`, the warm-up in slices of 1 s |

## What the timed loops do (spec D3, D11)

Parameters: PlutusV3 semantics at protocol version 11 with the mainnet cost model
(`check/reference/mainnet-plutusv3-costmodel.json`), costing on (counting mode or an enormous
restricting budget).

- `<vm>.csv` (D3, the ranking): each iteration does flat decode + evaluation.
- `<vm>-eval.csv`: each iteration evaluates a program that was decoded once before timing.
  For a compiling VM (Scalus JIT) this is its only loop; it writes the same numbers to both files
  (each only when its loop is requested).
- Built once, outside the loops (the ledger also caches its evaluation context): cost model, machine
  parameters, and a machine object if the VM's API allows reuse. Fresh in every iteration: decode
  (D3 loop only), the budget counter, and the evaluation state.
- One process per script (spec D14) runs the requested timed loops of that script: the D3 loop
  first, then the eval-only loop. Each loop has its own warm-up and measurement. The harness prints
  `PVB_LOOP <loop> <script>` when a loop starts, so `parsers/fill_failures.py --loop` charges an
  error in the log to the right loop.
- Warm-up: JMH VMs use one 20 s warm-up iteration (`-wi 1 -w 20s`); the staged Scalus JIT needs
  about 20 s. Then three 5 s measurement iterations (`-i 3 -r 5s`). Other frameworks keep their own
  warm-up rules.

- Trace mode (`BENCH_TRACE=1`): a JIT row runs its warm-up as slices of 1 s with the same total
  time, and writes the score of each slice to `<vm>-warmup.csv`. JMH uses `-wi 20 -w 1s` in place
  of `-wi 1 -w 20s`; the JS harnesses run their round function 20 times for 1 s. The measured
  iterations do not change. It shows how long each VM needs to reach a steady state.

The check is one evaluation per script with the same parameters. The gate (`check/`) compares
`<vm>-check.csv` with the Haskell reference.

## After the run

`scripts/run-images.sh` merges the timings into `unified.csv`, runs `check/gate.py` over every
`<vm>-check.csv` (mode per VM from `check/modes.conf`, default strict) and writes `gate.json`. Then
it builds the report: a VM that fails the gate, or has no `<vm>-check.csv`, is hidden and listed
as "failed check". A VM with `<vm>-compile.csv` gets a "compile excluded" badge and a compile-time
column.

Without the `check` loop there is no gate and no `gate.json`; the report shows every VM as "not
checked". Without the `d3` loop `unified.csv` has only its header, and the report shows the
eval-only column.

### Host switches of `run-images.sh`

These switches change how the host runs the images. The images do not see them, except
`BENCH_TRACE`.

| Variable | Values | Default |
|---|---|---|
| `LANES` | Number of parallel lanes. See below | `1` |
| `BENCH_TRACE` | `1`: the JIT rows log warm-up slices into `<vm>-warmup.csv`. Passed to the image | `0` |
| `PULL` | `1`: pull every image first, up to 4 at a time, before any VM runs | `0` |

`LANES=1` runs one VM at a time. All VMs use the same CPU set: every CPU except the core of CPU 0.

`LANES=n` (n > 1) runs up to n VMs at once:

- The host keeps the whole physical core of CPU 0. The other physical cores split into n lanes
  with the same number of whole cores. A lane has every SMT thread of its cores. Cores that do not
  divide evenly stay idle.
- Haskell runs first and alone, on lane 0. The other lanes idle. Haskell is the reference and the
  base of the drift probe.
- Then each free lane takes the next VM. Each container gets `--cpuset-cpus` of its lane.
- The drift probe runs at the end, alone, on lane 0.
- `environment.txt` records the layout, for example `lanes: 3 (lane0 2,3; lane1 4,5; lane2 6,7)`,
  and `parallel: yes`. The page header shows "3 parallel lanes".
- Load average and steal time are for the whole host. With lanes, they include the VMs that ran
  at the same time.
- It needs a Linux host with the CPU topology in sysfs, `CPUSET=auto` and bash 5.1 or newer. On
  Docker Desktop (macOS) `LANES` > 1 is an error.
- `scripts/run-images.sh --lanes <n>` prints the lane layout of the host and exits.

The `run` workflow uses `LANES=3` for the full run (spec D19). A run with `BENCH_TRACE=1`, or with a
lane count other than 1 and 3, is a partial run: the `run` workflow never publishes it.

`PVB_QUALIFY` (set by the `run` workflow) is the result of the server qualification. The host
writes it to `environment.txt` as the line `server qualification: <result>`. See METHODOLOGY.md,
Hardware.
