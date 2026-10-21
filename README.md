# Cardano Plutus VM Benchmark

Reproducible, cross-language benchmark suite for Plutus (UPLC) virtual machine implementations.

Each VM is built from a pinned source revision into its own Docker image. Each image runs the VM's **native benchmark framework**, and the harness merges the outputs into one comparison report. [View full results](https://saib-inc.github.io/cardano-plutus-vm-benchmark/)

Results of past runs, with their hardware, are in [`results/`](results/).

## VMs Benchmarked

| VM | Image | Language | Benchmark Framework | Repository |
|---|---|---|---|---|
| **plutus-core** | `haskell` | Haskell | Criterion | [IntersectMBO/plutus](https://github.com/IntersectMBO/plutus) |
| **Scalus** | `scalus-cek`, `scalus-jit` | Scala / GraalVM 25 | JMH (CEK + UPLC→JVM JIT) | [scalus3/scalus](https://github.com/scalus3/scalus) |
| **uplc-turbo** | `uplc-turbo` | Rust | Criterion.rs | [pragma-org/uplc](https://github.com/pragma-org/uplc) |
| **Plutigo** | `plutigo` | Go | testing.B | [blinklabs-io/plutigo](https://github.com/blinklabs-io/plutigo) |
| **blaze-plutus** | `blaze-v8`, `blaze-jsc` | TypeScript | Vitest bench (V8 + JSC) | [butaneprotocol/blaze-cardano](https://github.com/butaneprotocol/blaze-cardano) |
| **Julc** | `julc-java` | Java | JMH (CEK) | [bloxbean/julc](https://github.com/bloxbean/julc) |
| **opshin-uplc** | `opshin` | Python | Custom | [OpShin/uplc](https://github.com/OpShin/uplc) |

## What's Measured

Each VM: **flat-decode + CEK evaluate** on 89 real-world Plutus smart contract scripts (auction, escrow, uniswap, stablecoin, etc.).

All VMs use the same canonical `.flat` test data committed in `data/plutus_use_cases/`.

## Quick Start

```bash
# Build one image locally (pins come from .env)
scripts/images.sh build uplc-turbo

# Run images one at a time, then write unified.csv, report.md and docs/index.html
scripts/run-images.sh results/$(date +%F) uplc-turbo plutigo

# Smoke test: first 5 scripts, short timing
BENCH_QUICK=1 scripts/run-images.sh /tmp/smoke uplc-turbo

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
- `<vm>.csv` and `<vm>-raw.log` per VM, `environment.txt` with the hardware and image digests

See [docs/IMAGE_CONTRACT.md](docs/IMAGE_CONTRACT.md) for the interface every image follows.

## Updating VM Versions

Edit the pin in `.env`. The VM's image tag changes, so CI (`.github/workflows/images.yml`) rebuilds only that image.

## Project Structure

```
data/plutus_use_cases/    # 89 canonical .flat benchmark scripts
images/<vm>/Dockerfile    # One image per VM (images/scalus and images/blaze serve two VMs each)
.env                      # Pinned git SHAs and toolchain versions
scripts/run-<vm>.sh       # Per-VM runner, the default command of its image
scripts/images.sh         # List, tag and build the images
scripts/run-images.sh     # Run the images, then normalize and report
parsers/                  # Output normalizers (one per framework)
report/                   # Unified CSV -> markdown/HTML report generator
results/                  # Git-tracked historical results
```

## Methodology

See [METHODOLOGY.md](METHODOLOGY.md) for details on fairness, statistical methodology, and limitations.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)
