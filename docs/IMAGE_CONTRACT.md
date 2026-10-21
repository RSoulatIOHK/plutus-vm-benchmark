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
  own image. Today: `images/scalus/` (`scalus-cek`, `scalus-jit`), `images/blaze/` (`blaze-v8`, `blaze-jsc`).
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
- Default command runs the benchmark AND the check, then exits 0. It exits non-zero only when the VM
  could not run at all. A single script that fails is a row with an error, not a failed container.
- `BENCH_SKIP_EVAL=1` skips the eval-only loop (`<vm>-eval.csv`); today honoured by haskell, scalus-cek and aiken.
- `BENCH_QUICK=1` runs only the first 5 scripts (C sort order) with short timing (for PR smoke tests).
  The run script reads the scripts from `$BENCH_DATA_DIR` and reads `$BENCH_QUICK` for its timing flags.
- The check covers every script of `/bench/data/plutus_use_cases`, also with `BENCH_QUICK=1`: the
  smoke test times 5 scripts but gates all of them (spec, section 2). The check is one evaluation
  per script, so it is cheap. A check with fewer scripts fails the gate as "missing".

## Outputs (all in `/results`)

| File | Content |
|---|---|
| `<vm>.csv` | Timing, schema `vm,script,mean_ns,median_ns,min_ns,max_ns,stddev_ns,iterations`. A failed script has `-1` in every number column |
| `<vm>-check.csv` | Correctness, schema `vm,script,status,cpu,mem`. `status` is `ok` or `error`. `cpu`/`mem` are the ExUnits the VM's own costing reports for one evaluation (empty when the VM has no costing) |
| `<vm>-raw.log` | Raw tool output, for debugging |
| `<vm>-eval.csv` | Eval-only timing, same schema as `<vm>.csv`: evaluation of a program decoded once outside the timed loop. Shown as a second column next to the D3 time |
| `<vm>-compile.csv` | Only for VMs that compile before they run (Scalus JIT): `vm,script,compile_ns` |

## What the timed loops do (spec D3, D11)

Parameters: PlutusV3 semantics at protocol version 11 with the mainnet cost model
(`check/reference/mainnet-plutusv3-costmodel.json`), costing on (counting mode or an enormous
restricting budget).

- `<vm>.csv` (D3, the ranking): each iteration does flat decode + evaluation.
- `<vm>-eval.csv`: each iteration evaluates a program that was decoded once before timing.
  For a compiling VM (Scalus JIT) this is its only loop; it writes the same numbers to both files.
- Built once, outside the loops (the ledger also caches its evaluation context): cost model, machine
  parameters, and a machine object if the VM's API allows reuse. Fresh in every iteration: decode
  (D3 loop only), the budget counter, and the evaluation state.
- Warm-up: JMH VMs use one 20 s warm-up iteration (`-wi 1 -w 20s`); the staged Scalus JIT needs
  about 20 s. Other frameworks keep their own warm-up rules.

The check is one evaluation per script with the same parameters. The gate (`check/`) compares
`<vm>-check.csv` with the Haskell reference.

## After the run

`scripts/run-images.sh` merges the timings into `unified.csv`, runs `check/gate.py` over every
`<vm>-check.csv` (mode per VM from `check/modes.conf`, default strict) and writes `gate.json`. Then
it builds the report: a VM that fails the gate, or has no `<vm>-check.csv`, is hidden and listed
as "failed check". A VM with `<vm>-compile.csv` gets a "compile excluded" badge and a compile-time
column.
