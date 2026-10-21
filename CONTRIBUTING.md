# Contributing to the Plutus VM Benchmark

Thank you for your interest. This document describes how to change the benchmark and how pull
requests are handled. Lantr (lantr.io) maintains the project.

## Code of Conduct

Be respectful and constructive. The benchmark serves the whole Cardano community.

## Getting Started

### Prerequisites

- Docker (with BuildKit) and bash
- Git
- Python 3.10+ (for the parsers, the gate and the report outside Docker)

### Setup

1. Fork the repository.
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/plutus-vm-benchmark.git
   cd plutus-vm-benchmark
   ```
3. Add the upstream remote:
   ```bash
   git remote add upstream https://github.com/lantr-io/plutus-vm-benchmark.git
   ```

### Running Locally

```bash
scripts/images.sh build <vm>
scripts/run-images.sh /tmp/run <vm>
```

## Development Workflow

1. Create a feature branch from `main`:
   ```bash
   git checkout main
   git pull upstream main
   git checkout -b feature/your-feature-name
   ```
2. Make your changes.
3. Test the changed images. Quick mode runs 5 scripts with short timing:
   ```bash
   scripts/images.sh build <vm>
   BENCH_QUICK=1 scripts/run-images.sh /tmp/smoke <vm>
   ```
   Run the correctness check on all 89 scripts:
   ```bash
   BENCH_LOOPS=check scripts/run-images.sh /tmp/check <vm>
   ```
4. Commit your changes with the [commit conventions](#commit-conventions).
5. Push to your fork and open a pull request.

## Commit Conventions

We use [Conventional Commits](https://www.conventionalcommits.org/).

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | A new feature (new VM, new parser, new report feature) |
| `fix` | A bug fix |
| `docs` | Documentation changes |
| `style` | Code style changes (formatting, etc.) |
| `refactor` | Code refactoring without feature changes |
| `perf` | Performance improvements to the benchmark infrastructure |
| `test` | Adding or updating tests |
| `chore` | Maintenance tasks (dependencies, version bumps) |
| `results` | Result commits of a benchmark run |

### Scopes

| Scope | Description |
|-------|-------------|
| `images` | `images/` Dockerfile and harness changes |
| `parsers` | Output parser changes |
| `scripts` | Runner script changes |
| `gate` | `check/` changes |
| `report` | Report generator changes |
| `data` | Benchmark data changes |
| `ci` | GitHub Actions workflow changes |
| `nix` | Bench server config (`nix/`, `flake.nix`, `scripts/hetzner/`) |
| `<vm>` | Changes for one VM, for example `aiken` or `scalus-js` |

### Examples

```
feat(images): add the aiken image
fix(parsers): handle missing stddev in Go bench output
chore(plutigo): update to v0.1.10
docs(methodology): describe the eval-only column
```

## Pull Requests

There are two kinds of pull requests.

### Version bumps

A version bump changes only `.env`. CI (`.github/workflows/images.yml`) builds the changed image on
the pull request; it pushes nothing.

Planned: a bot will open version-bump pull requests when a VM publishes a new release. A smoke
workflow will time 5 scripts and run the gate on all 89 scripts. If both pass, the pull request
merges automatically. If not, it gets the label `needs-human` and the old pin stays. The bot and
the smoke workflow (`bump.yml`, `smoke.yml`) are not built yet. Until then, a maintainer reviews
version bumps by hand.

### Code changes

Every other pull request needs a review by a maintainer. CI on pull requests runs without secrets:
it builds the changed images and pushes nothing. Only the monthly run on `main` uses the bench
server.

Requirements:

- The changed images build.
- A changed VM passes the correctness gate on all 89 scripts.
- Parsers handle edge cases (missing data, empty output).
- Follow the existing code style and patterns.
- Update [METHODOLOGY.md](METHODOLOGY.md) if you change what is measured or how.
- Update [README.md](README.md) if you add a VM or change usage.

## Adding a New VM

Inclusion rule: a VM joins the line-up if it has a downstream user today, for example a node,
a wallet, an SDK or a dev tool that runs it.

1. Add `images/<vm>/Dockerfile` and the harness that calls the VM. Follow the image contract in
   [docs/IMAGE_CONTRACT.md](docs/IMAGE_CONTRACT.md): the D3 loop (flat decode + evaluation), the
   eval-only loop if the API allows it, and the check (`<vm>-check.csv`). Use the parameters in
   [check/README.md](check/README.md#evaluation-parameters): PlutusV3, protocol version 11, the
   mainnet cost model, costing on.
2. Add `scripts/run-<vm>.sh`. It reads only `$BENCH_DATA_DIR` (the check too), runs the loops of
   `$BENCH_LOOPS`, shortens the timing for `BENCH_TIMING=quick`, and declares its loops in a
   `# pvb-loops:` header line.
3. Add an output parser in `parsers/` if the framework is new.
4. Add the VM to `VM_ORDER` and `VM_LABELS` in `report/generate_report.py`, and to `VM_META` and
   `VM_ORDER` in `report/template.html`.
5. Pin the VM to a release in `.env`.
6. Pass the correctness gate on all 89 scripts:
   ```bash
   BENCH_LOOPS=check scripts/run-images.sh /tmp/check <vm>
   ```
   If the VM's API cannot take a cost model, see the badge mode in
   [check/README.md](check/README.md#policy) and [`check/modes.conf`](check/modes.conf).
7. Update [README.md](README.md) and [METHODOLOGY.md](METHODOLOGY.md).

## Updating VM Versions

Pin release tags only, not development branches.

1. In `.env`, set the `*_SHA` of the VM to the commit of the release tag, with the tag in a trailing
   comment, for example `AIKEN_SHA=bacbeb3... # v1.1.24`. Some VMs also have a version variable,
   for example `SCALUS_VERSION` (the Maven release at `SCALUS_SHA`) and `SCALUS_JS_VERSION` (the
   npm version).
2. Test: `scripts/images.sh build <vm> && BENCH_QUICK=1 scripts/run-images.sh /tmp/smoke <vm>`,
   then the check on all 89 scripts.
3. Open a pull request with the commit message `chore(<vm>): update to <tag>`.

### What Not to Do

- **Never push directly to `main`.** Always use pull requests.
- **Never force push to `main`.** It destroys history.
- **Never change the benchmark data** without agreement from the maintainers.
- **Never change a result directory** in `results/` after the run committed it.

## Questions?

Open an issue in [lantr-io/plutus-vm-benchmark](https://github.com/lantr-io/plutus-vm-benchmark/issues).
