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
- **Released versions only.** Every VM is pinned to a release tag in `.env`.
- **Monthly runs on fixed hardware.** One Hetzner dedicated-vCPU server type runs every VM, one at a time.
- **History.** Each run stays in `results/`. The page shows each VM's time relative to Haskell over time.

## Background

- [Cardano](https://cardano.org) is a proof-of-stake blockchain.
- [Plutus](https://plutus.cardano.intersectmbo.org/docs/) is the smart contract platform of Cardano
  ([IntersectMBO/plutus](https://github.com/IntersectMBO/plutus)).
- UPLC (Untyped Plutus Core) is the on-chain language. Compilers such as Plutus Tx, Aiken and Scalus emit it.
  The node evaluates a UPLC script with a CEK machine. A cost model charges each step and each builtin
  call in ExUnits (CPU and memory). See the
  [Plutus Core specification](https://plutus.cardano.intersectmbo.org/resources/plutus-core-spec.pdf).
- Many tools evaluate scripts, not only the node. Wallets and off-chain transaction builders evaluate
  each script to estimate fees. Test frameworks and emulators evaluate scripts in every test. Indexers
  evaluate scripts to report their costs. Alternative nodes such as [Amaru](https://github.com/pragma-org/amaru) and
  [Dingo](https://github.com/blinklabs-io/dingo) evaluate them to validate blocks. A faster evaluator
  makes all of these faster.

## Maintainers

Maintained by Lantr ([lantr.io](https://lantr.io)), Alexander Nemish.

## Acknowledgement

Forked from [SAIB-Inc/cardano-plutus-vm-benchmark](https://github.com/SAIB-Inc/cardano-plutus-vm-benchmark),
created by Clark Alesna ([SAIB Inc.](https://github.com/SAIB-Inc)) and contributors. Thank you for the
original harness, data set and methodology.

What changed:

- **Per-VM images on GHCR.** Each VM is its own Docker image (`ghcr.io/lantr-io/pvb-<vm>`). A version
  bump rebuilds only that image.
- **Correctness gate.** Each VM reports the result and the ExUnits of every script. The gate compares
  them with Haskell plutus-core ([check/README.md](check/README.md)).
- **Node-equivalent parameters.** Flat decode + evaluation with PlutusV3 semantics, protocol version 11,
  the mainnet cost model and costing on, for every VM.
- **Curated line-up.** A VM joins if it has a downstream user today, a stable release and passes the
  correctness gate. See [Not included](#not-included).
- **Eval-only column.** A second timing evaluates a program decoded once before timing.
- **Automated monthly runs.** GitHub Actions creates a Hetzner server, installs NixOS on it, runs the
  benchmark and deletes the server.

## VMs Benchmarked

| Image | VM | Language | Benchmark framework | Project | Pinned release |
|---|---|---|---|---|---|
| `haskell` | plutus-core | Haskell | Criterion | [IntersectMBO/plutus](https://github.com/IntersectMBO/plutus) | [1.63.0.0](https://github.com/IntersectMBO/plutus/releases/tag/1.63.0.0) |
| `scalus-cek` | Scalus CEK | Scala / GraalVM 25 | JMH | [scalus3/scalus](https://github.com/scalus3/scalus) | [v1.4.0](https://github.com/scalus3/scalus/releases/tag/v1.4.0) |
| `scalus-jit` | Scalus JIT (UPLC → JVM bytecode) | Scala / GraalVM 25 | JMH | [scalus3/scalus](https://github.com/scalus3/scalus) | [v1.4.0](https://github.com/scalus3/scalus/releases/tag/v1.4.0) |
| `scalus-js` | Scalus.js | Scala.js / Node.js | Vitest bench | [scalus3/scalus](https://github.com/scalus3/scalus) | npm `scalus` [1.4.0](https://github.com/scalus3/scalus/releases/tag/v1.4.0) |
| `aiken` | Aiken uplc | Rust | Criterion.rs | [aiken-lang/aiken](https://github.com/aiken-lang/aiken) | [v1.1.24](https://github.com/aiken-lang/aiken/releases/tag/v1.1.24) |
| `uplc-turbo` | uplc-turbo (Amaru) | Rust | Criterion.rs | [pragma-org/uplc](https://github.com/pragma-org/uplc) | [amaru-uplc-v0.4.0](https://github.com/pragma-org/uplc/releases/tag/amaru-uplc-v0.4.0) |
| `plutigo` | Plutigo (Dingo) | Go | testing.B | [blinklabs-io/plutigo](https://github.com/blinklabs-io/plutigo) | [v0.1.10](https://github.com/blinklabs-io/plutigo/releases/tag/v0.1.10) |
| `blaze-v8` | blaze-plutus on Node (V8) | TypeScript | Vitest bench | [butaneprotocol/blaze-cardano](https://github.com/butaneprotocol/blaze-cardano) | [@blaze-cardano/plutus 0.1.1](https://github.com/butaneprotocol/blaze-cardano/releases/tag/%40blaze-cardano%2Fplutus%400.1.1) |
| `blaze-jsc` | blaze-plutus on Bun (JSC) | TypeScript | Vitest bench | [butaneprotocol/blaze-cardano](https://github.com/butaneprotocol/blaze-cardano) | [@blaze-cardano/plutus 0.1.1](https://github.com/butaneprotocol/blaze-cardano/releases/tag/%40blaze-cardano%2Fplutus%400.1.1) |

That is 9 images: `scripts/images.sh list` prints them. The pins are in [`.env`](.env).

Aiken v1.1.24 copies the CEK environment on every lambda application (quadratic in recursion
depth). aiken main fixes it (PRs [#1451](https://github.com/aiken-lang/aiken/pull/1451),
[#1452](https://github.com/aiken-lang/aiken/pull/1452): coop-6 92 ms -> 1.2 ms), but no release
contains the fix yet.

## Not included

A VM joins the line-up when it meets three conditions:

1. It has a downstream user today.
2. It has a stable release.
3. It passes the correctness gate.

| Project | Reason |
|---|---|
| [Chrysalis](https://github.com/SAIB-Inc/Chrysalis) | SAIB's own .NET VM. No visible downstream users. |
| [Plutuz](https://github.com/utxo-company/plutuz) | Zig VM. No visible downstream users. |
| [llvm-uplc](https://github.com/SeungheonOh/llvm-uplc) | Research prototype. No releases and no users. |
| Aiken WASM | The Aiken team publishes no UPLC WASM. The only released build, `@lucid-evolution/uplc`, caches decoded programs and has no off switch. So it cannot time decode + evaluation as published. |
| [Julc](https://github.com/bloxbean/julc) | No stable release: only `0.1.0-preNN` pre-releases. It can join at its first stable release. |
| [OpShin uplc](https://github.com/OpShin/uplc) | Fails the correctness gate at its latest release 1.3.3. It has no `case` on builtin values, a protocol version 11 feature. |
| uplc-turbo-bc | The released `uplc-turbo` crate has no bytecode mode. |

### How a VM can join

Meet the three conditions above. Then open a pull request that adds an image. Follow
[CONTRIBUTING.md](CONTRIBUTING.md) and [docs/IMAGE_CONTRACT.md](docs/IMAGE_CONTRACT.md).
Candidates today: plu-ts ([`@harmoniclabs/uplc`](https://github.com/HarmonicLabs/uplc)) and
Helios ([HeliosLang/uplc](https://github.com/HeliosLang/uplc)).

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

# Run images one at a time, then write unified.csv, report.md and index.html into the run dir
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
- `environment.txt` – the hardware, the switches, the image digests and the host noise data
- `haskell-drift.csv`, `drift.json` – the drift probe: Haskell again at the end of the run

See [docs/IMAGE_CONTRACT.md](docs/IMAGE_CONTRACT.md) for the interface every image follows and the
switches `BENCH_SCRIPTS` (regex on the script name), `BENCH_LOOPS` (`d3`, `eval`, `check`) and
`BENCH_TIMING` (`normal`, `quick`).

## Updating VM Versions

Change the pin of the VM in `.env` to a release. The image tag of that VM changes, so CI
(`.github/workflows/images.yml`) rebuilds only that image. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Project Structure

```
data/plutus_use_cases/    # 89 canonical .flat benchmark scripts
.env                      # Pinned VM versions and toolchain versions
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
