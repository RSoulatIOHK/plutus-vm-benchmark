<p align="center">
  <a href="https://lantr.io">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="docs/lantr-logo-dark.png">
      <source media="(prefers-color-scheme: light)" srcset="docs/lantr-logo.png">
      <img alt="Lantr" src="docs/lantr-logo.png" width="240">
    </picture>
  </a>
</p>

# Plutus VM Benchmark

Reproducible, cross-language benchmark of Plutus (UPLC) virtual machine implementations.

Results: [plutus-vm-bench.lantr.io](https://plutus-vm-bench.lantr.io)

## Aim

Give a neutral, reproducible comparison of the Plutus/UPLC evaluators that people use today.
Library and node authors can use it to choose an evaluator.

## Goals

- **Node-equivalent timing.** Each iteration does a flat decode and an evaluation. The evaluation
  uses PlutusV3 semantics at protocol version 11, the mainnet PlutusV3 cost model, and costing on.
- **Correctness gate.** For every script, the result and the ExUnits of a VM must equal Haskell
  plutus-core. A VM that fails is not ranked.
- **Released versions only.** Each VM is to be pinned to a release tag in `.env`. Today Haskell,
  Scalus, Scalus.js, Aiken and Plutigo are; the other pins are commits.
- **Monthly runs on fixed hardware.** One Hetzner dedicated-vCPU server type runs every VM, one at a time.
- **History.** Each run stays in `results/`. The page shows each VM's time relative to Haskell over time.

## Maintainers

Maintained by Lantr ([lantr.io](https://lantr.io)), Alexander Nemish.

## Acknowledgement

Forked from [SAIB-Inc/cardano-plutus-vm-benchmark](https://github.com/SAIB-Inc/cardano-plutus-vm-benchmark),
created by SAIB Inc. and contributors. Thank you for the original harness, data set and methodology.

What changed:

- **Per-VM images on GHCR.** Each VM is its own Docker image (`ghcr.io/lantr-io/pvb-<vm>`). A version
  bump rebuilds only that image.
- **Correctness gate.** Each VM reports the result and the ExUnits of every script. The gate compares
  them with Haskell plutus-core ([check/README.md](check/README.md)).
- **Node-equivalent parameters.** Flat decode + evaluation with PlutusV3 semantics, protocol version 11,
  the mainnet cost model and costing on, for every VM.
- **Curated line-up.** A VM joins if it has a downstream user today.
- **Eval-only column.** A second timing evaluates a program decoded once before timing.
- **Automated monthly runs.** GitHub Actions creates a Hetzner server, installs NixOS on it, runs the
  benchmark and deletes the server.

## VMs Benchmarked

| VM | Image | Language | Benchmark framework | Repository |
|---|---|---|---|---|
| **plutus-core** | `haskell` | Haskell | Criterion | [IntersectMBO/plutus](https://github.com/IntersectMBO/plutus) |
| **Scalus** | `scalus-cek`, `scalus-jit` | Scala / GraalVM 25 | JMH (CEK, and UPLC → JVM bytecode JIT) | [scalus3/scalus](https://github.com/scalus3/scalus) |
| **Scalus.js** | `scalus-js` | Scala.js / Node.js | Vitest bench | [scalus3/scalus](https://github.com/scalus3/scalus) (npm `scalus`) |
| **Aiken uplc** | `aiken` | Rust | Criterion.rs | [aiken-lang/aiken](https://github.com/aiken-lang/aiken) |
| **uplc-turbo** | `uplc-turbo` | Rust | Criterion.rs | [pragma-org/uplc](https://github.com/pragma-org/uplc) |
| **Plutigo** | `plutigo` | Go | testing.B | [blinklabs-io/plutigo](https://github.com/blinklabs-io/plutigo) |
| **blaze-plutus** | `blaze-v8`, `blaze-jsc` | TypeScript | Vitest bench (Node V8, Bun JSC) | [butaneprotocol/blaze-cardano](https://github.com/butaneprotocol/blaze-cardano) |
| **Julc** | `julc-java` | Java / GraalVM 25 | JMH (CEK) | [bloxbean/julc](https://github.com/bloxbean/julc) |
| **opshin-uplc** | `opshin` | Python | Custom loop | [OpShin/uplc](https://github.com/OpShin/uplc) |

That is 11 images: `scripts/images.sh list` prints them. The pins are in [`.env`](.env).

## What Is Measured

Each VM runs a flat decode and an evaluation of 89 Plutus scripts from the `plutus-use-cases` test
suite (auction, escrow, uniswap, stablecoin and others). All VMs read the same `.flat` files in
`data/plutus_use_cases/`.

The 89 scripts are PlutusV1-era programs. Every VM evaluates them as PlutusV3 programs at protocol
version 11. Plutus's own `validation` CEK benchmark does the same. See [METHODOLOGY.md](METHODOLOGY.md).

## Results

The latest run is at [plutus-vm-bench.lantr.io](https://plutus-vm-bench.lantr.io). Each run is in
[`results/<date>/`](results/) with its hardware and image digests (`environment.txt`).

The directories in `results/` from before 2026-10 are SAIB-era runs. They used different VMs,
parameters and hardware. Do not compare them with the current runs.

## Quick Start

```bash
# Build one image locally (pins come from .env)
scripts/images.sh build uplc-turbo

# Run images one at a time, then write unified.csv, report.md and docs/index.html
scripts/run-images.sh results/$(date +%F) uplc-turbo plutigo

# Smoke test: first 5 scripts, short timing
BENCH_QUICK=1 scripts/run-images.sh /tmp/smoke uplc-turbo

# A subset: two scripts, D3 timing and check only, short timing
BENCH_SCRIPTS='auction_1-1|uniswap-1' BENCH_LOOPS=d3,check BENCH_TIMING=quick \
  scripts/run-images.sh /tmp/subset plutigo aiken

# Only the correctness check, all 89 scripts, every VM
BENCH_LOOPS=check scripts/run-images.sh /tmp/check

# The same on the bench server (GitHub Actions); a partial run is never published
gh workflow run run.yml -f vms="plutigo aiken" -f scripts='auction_.*' -f loops=eval -f timing=quick

# Use the published images instead of local builds (what the bench server does)
PULL=1 scripts/run-images.sh results/$(date +%F)
```

One image by hand:

```bash
docker run --rm --cap-add SYS_NICE \
  -v "$PWD/data:/bench/data:ro" -v "$PWD/results/<date>:/results" \
  ghcr.io/lantr-io/pvb-uplc-turbo:latest
```

Results are written to the results dir:

- `unified.csv` – all VMs, all scripts, nanosecond precision
- `report.md` – markdown comparison table with geometric means
- `gate.json` – the correctness verdict of each VM
- `<vm>.csv`, `<vm>-eval.csv`, `<vm>-check.csv` and `<vm>-raw.log` per VM
- `environment.txt` – the hardware, the switches and the image digests

See [docs/IMAGE_CONTRACT.md](docs/IMAGE_CONTRACT.md) for the interface every image follows and the
switches `BENCH_SCRIPTS` (regex on the script name), `BENCH_LOOPS` (`d3`, `eval`, `check`) and
`BENCH_TIMING` (`normal`, `quick`).

## Updating VM Versions

Change the pin of the VM in `.env` to a release. The image tag of that VM changes, so CI
(`.github/workflows/images.yml`) rebuilds only that image. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Project Structure

```
data/plutus_use_cases/    # 89 canonical .flat benchmark scripts
.env                      # Pinned VM releases and toolchain versions
images/<vm>/              # One Dockerfile and harness per VM (images/scalus and images/blaze serve two VMs each)
scripts/run-<vm>.sh       # Per-VM runner, the default command of its image
scripts/image-entry.sh    # Entry point of every image: switches, data selection, exit code
scripts/images.sh         # List, tag and build the images
scripts/run-images.sh     # Run the images, then gate, normalize and report
scripts/hetzner/          # Create, use and delete the bench server
check/                    # Correctness gate and the Haskell reference
parsers/                  # Output normalizers (one per framework)
report/                   # Unified CSV -> markdown/HTML report generator
docs/                     # GitHub Pages site (index.html), image contract, design notes
nix/, flake.nix           # NixOS config of the bench server
.github/workflows/        # images (build and push), run (monthly run), sweep, provision-test
results/                  # Git-tracked historical results
```

## Methodology

See [METHODOLOGY.md](METHODOLOGY.md) for what is measured, the correctness gate, warm-up, hardware
and limitations.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Original work © 2025 SAIB Inc. © 2026 Lantr.
