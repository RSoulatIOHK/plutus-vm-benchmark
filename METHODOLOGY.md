# Methodology

## What Is Measured

The ranking time (the "D3" loop) is node-equivalent. Each iteration does:

1. **Flat decode**: deserialize the `.flat`-encoded UPLC program.
2. **Evaluation**: run the decoded program with costing on.

Every VM uses the same parameters, in the timed loops and in the correctness check:

| Parameter | Value |
|---|---|
| Ledger language | PlutusV3 |
| Protocol version | 11 (builtin semantics variant E, `case` on builtin values enabled) |
| Cost model | The mainnet PlutusV3 cost model, 350 parameters ([`check/reference/mainnet-plutusv3-costmodel.json`](check/reference/mainnet-plutusv3-costmodel.json)). It equals the default PlutusV3 model of plutus 1.63.0.0, the version of the production node |
| Budget | Costing on: counting mode, or a restricting budget too large to run out |

Costing is part of the timed work, as on a node. The full parameter list and the reasons are in
[check/README.md](check/README.md#evaluation-parameters).

### Reuse rule

From [docs/IMAGE_CONTRACT.md](docs/IMAGE_CONTRACT.md):

- Built once, outside the timed loops: the cost model, the machine parameters and, if the VM's API
  allows reuse, a machine object. The ledger also caches its evaluation context.
- Fresh in every iteration: the flat decode (D3 loop only), the budget counter and the evaluation state.

### Eval-only column

A second loop (`<vm>-eval.csv`) evaluates a program that was decoded once before timing. The page
shows it next to the D3 time. Decoding is a large share of the D3 time for some VMs, so this
column shows the speed of the evaluator alone. The ranking uses the D3 time.

### Compiled VMs

The Scalus JIT compiles a script to JVM bytecode before it runs it. It decodes and compiles each
script once, before timing. Its timed loop evaluates the compiled script, so neither the flat
decode nor the compile step is timed. The page shows it with a "decode and compile excluded"
badge and a compile-time column (`<vm>-compile.csv`, the median of 3 compiles per script). Today
the Scalus JIT is in the unranked Experimental section (see [Inclusion rules](#inclusion-rules)).

### Cached decode

The published npm package `@lucid-evolution/uplc` 0.4.0 (the `aiken-wasm` row) caches the decoded
program, and it has no switch to turn the cache off. The harness uses the package as is. After the
first call, its timed loop does not decode the script again: it hashes the flat bytes, finds the
decoded program in the cache and evaluates it. The same times fill its D3 and eval-only columns.
The page ranks it with a "decode cached (by the library)" badge.

## Inclusion Rules

A VM is ranked when it meets three rules:

1. It has a published release: a stable version on a package registry, or a release tag.
   Pre-releases, such as `-alpha` or `0.1.0-preNN` versions, do not count.
2. It has a downstream user today, for example a node, a wallet, an SDK or a dev tool that runs it.
3. It passes the [correctness gate](#correctness-gate).

A VM that caches the decoded program or compiles it ahead is ranked with a badge:

| Badge | Meaning | Example |
|---|---|---|
| decode and compile excluded | The decode and the compile run once per script, before timing | Scalus JIT |
| decode cached (by the library) | The library caches the decoded program; the harness cannot turn the cache off | Aiken WASM (`@lucid-evolution/uplc` 0.4.0) |

The page shows an unranked "Experimental" section. It holds VMs that have a release tag and pass
the gate, but miss rule 2 or publish no artifact. Today that is the Scalus JIT: the
`scalus-uplc-jit-compiler` module is not published to Maven, and it has no downstream users.

The README lists the VMs that are not included and the rule that each one fails.

## Test Data

89 flat-encoded Plutus scripts from the
[`plutus-use-cases`](https://github.com/input-output-hk/plutus-use-cases) test suite, in
`data/plutus_use_cases/`. They were compiled with
[Plinth (formerly Plutus Tx)](https://plutus.cardano.intersectmbo.org/docs/essential-concepts/plinth-and-plutus-core)
under its old name. They cover:

- Auction, Crowdfunding, Currency, Escrow
- Futures (settle, pay-out, increase-margin)
- Game state machines, Multisig state machines
- Ping-pong, Prism, Pubkey
- Stablecoin, Token account, Uniswap, Vesting
- `coop-*` and `guardrail-*` (UPLC 1.1.0)

File sizes range from about 2 KB to 13 KB. All VMs read the same files.

### PlutusV1-era scripts

78 of the 89 scripts are PlutusV1-era validators (UPLC 1.0.0). The other 11 (`coop-*`,
`guardrail-*`) are UPLC 1.1.0 programs that use `constr`/`case`. The benchmark evaluates all 89 as
PlutusV3 programs at protocol version 11. Plutus's own `validation` CEK benchmark
(`plutus-benchmark`, `BenchCek.hs`) does the same. A node would run the 78 older scripts as PlutusV1.

The PlutusV3 rule that a script must return `unit` (CIP-117) is not applied. The 78 PlutusV1-era
scripts return a non-unit term. The benchmark measures the evaluator, so the status is the
evaluation result only. The rule does not change the ExUnits.

## Correctness Gate

Before the timings of a VM are published, its results must equal Haskell plutus-core. Each image
writes `<vm>-check.csv` (`vm,script,status,cpu,mem`): one evaluation per script, with the
parameters above. [`check/gate.py`](check/gate.py) compares it with
[`check/reference/haskell-check.csv`](check/reference/haskell-check.csv).

There are two modes ([check/README.md](check/README.md#policy)):

- **Strict** (the default). The VM loads the mainnet cost model. Status, CPU and memory must equal
  the Haskell reference for every script. A VM without costing fails.
- **Badge.** For a VM whose API cannot take a cost model. The VM runs with the model it ships. It
  must equal Haskell evaluated with that model
  ([`check/reference/haskell-check-variant-c.csv`](check/reference/haskell-check-variant-c.csv)).
  The page then shows the VM with an "outdated cost model" badge.

A VM that fails is not ranked; the page lists it as "failed check". The mode of each VM is in
[`check/modes.conf`](check/modes.conf). Today every VM is strict.

## Why Native Benchmark Frameworks

Each VM is timed with a benchmark framework of its own language. The framework handles warm-up,
iteration count and outlier detection. The harness code that calls the VM is in `images/<vm>/`,
and the runner is `scripts/run-<vm>.sh`.

| VM | Framework | Warm-up and measurement (normal timing) |
|---|---|---|
| haskell | Criterion | Criterion's warm-up; about 5 s per script, Criterion's default (`timeLimit = 5`) |
| scalus-cek, scalus-jit | JMH | One 20 s warm-up iteration, three 5 s measurement iterations, 1 fork (`-wi 1 -w 20s -i 3 -r 5s -f 1`) |
| aiken | Criterion.rs | Criterion.rs default warm-up, 5 s measurement |
| uplc-turbo | Criterion.rs | Criterion.rs default warm-up, 10 s measurement |
| plutigo | Go testing.B | Automatic `b.N` scaling, `-test.benchtime=5s` |
| blaze-v8, blaze-jsc | Vitest bench | 20 s warm-up, three 5 s measurements |
| aiken-wasm | Vitest bench | 20 s warm-up, three 5 s measurements (a JIT runtime, V8) |
| scalus-js | Vitest bench | 20 s warm-up, three 5 s measurements (the same Vitest version as blaze-v8) |

The JIT runtimes (JVM, V8, JSC) all get 20 s of warm-up, because the staged Scalus JIT needs about
20 s to warm up. See [Fairness rules](#fairness-rules). `BENCH_TIMING=quick` shortens every
warm-up and measurement, for smoke tests only.

## Fairness Rules

- **Same data**: all VMs decode the same 89 `.flat` files.
- **Same parameters**: PlutusV3, protocol version 11, the mainnet cost model, costing on.
- **Same machine, one VM at a time**: each VM runs in its own Docker image on the same server, one
  after the other, so VMs do not compete for CPU.
- **Pinned versions**: `.env` pins each VM; `environment.txt` of each run records the image digests.
- **Same results**: the correctness gate proves that each published VM did the same work.

Decisions D13 to D17 of the
[design](docs/superpowers/specs/2026-10-21-lantr-vm-benchmark-design.md#0-decisions):

- **Warm-up (D13)**: the JIT runtimes (JVM, V8, JSC) get a 20 s warm-up and three 5 s
  measurements. The ahead-of-time compiled VMs (Rust, Go, GHC) keep the defaults of their
  framework, with at least 5 s of measurement.
- **Process model (D14)**: every VM runs each script in a fresh process. No JIT profile, heap or
  allocator state carries over from one script to the next.
- **Compiled VMs (D15)**: the Scalus JIT row has a "decode and compile excluded" badge. Its timed
  loop runs the compiled script; the decode and the compile happen once per script, before timing.
- **Runtime settings (D16)**: each VM runs with the settings that its project documents for
  production use. A VM without such documentation runs with the defaults of its runtime. Scalus
  must document its JVM flags in public, so the flags of the Scalus rows are not settings only
  this benchmark uses.
- **Inclusion rules (D17)**: a ranked VM has a published release, a downstream user today, and
  passes the gate. See [Inclusion rules](#inclusion-rules).

Host and noise measures ([`scripts/run-images.sh`](scripts/run-images.sh),
[`nix/runner.nix`](nix/runner.nix)):

- **Image pulls first**: all images are pulled before the first VM runs. No pull overlaps a timing.
- **CPU set**: on a Linux host every container runs on CPUs 1 to N-1 (`--cpuset-cpus`). CPU 0
  stays free for the host (Docker, SSH, interrupts). On Docker Desktop (macOS) there is no CPU set:
  the containers run in a Linux VM, and its CPU 0 is not the host's.
- **No network**: every container runs with `--network none`.
- **Quiet host**: the bench server disables the logrotate and fstrim timers. Nix GC, Nix store
  optimisation and Docker auto-prune are off. Transparent huge pages are pinned to `madvise`.
- **Drift probe**: Haskell runs first. At the end of the run it runs again on 5 fixed scripts
  (`haskell-drift.csv`). The page shows the change, for example "Drift (Haskell, end vs start):
  +1.8 %". `drift.json` has the time of each script.
- **Noise record**: `environment.txt` records the CPU topology (`lscpu`), selected CPU flags, the
  THP mode, the kernel command line, cpufreq, the active systemd timers, the load average before
  each VM, and the steal time during each VM and during the whole run.

## Hardware

The monthly run uses a Hetzner Cloud dedicated-vCPU server, type `ccx33` (the default of
`run.yml`): AMD EPYC, 8 dedicated vCPUs, 32 GB RAM. A new server is created for each run. NixOS is
installed on it from [`nix/runner.nix`](nix/runner.nix), with the CPU governor set to
`performance` (a KVM guest has no cpufreq driver, so this has no effect there). The server runs
one VM at a time and is deleted after the run. `environment.txt` records the CPU, cores, memory
and the noise data of each run (see [Fairness rules](#fairness-rules)).

## Unified Output

All results are normalized to a common CSV schema:

```csv
vm,script,mean_ns,median_ns,min_ns,max_ns,stddev_ns,iterations
```

Times are in **nanoseconds**. The summary uses the **geometric mean** of the scripts that every VM
in a category ran successfully. The geometric mean handles the wide range of script sizes and is
not dominated by the largest scripts.

The history chart shows each VM's geometric mean divided by the Haskell geometric mean of the same
run. The ratio is less sensitive to hardware changes and to drift between runs than absolute times.

## Limitations

- **Different statistics**: each framework computes mean, median and standard deviation in its own
  way. Go testing.B reports only the mean time per operation.
  - JMH (scalus-cek, scalus-jit) reports the mean time per operation of each measurement iteration.
    `median_ns`, `min_ns`, `max_ns` and `stddev_ns` are over the 3 iteration means, not over single
    operations. `stddev_ns` is the sample standard deviation (n - 1). `iterations` is the number of
    measurement iterations. JMH's "Score Error" is a 99.9% confidence interval, so it is not used.
  - Criterion (haskell): `stddev_ns` is Criterion's standard deviation. `min_ns` and `max_ns` are the
    bounds of the bootstrap confidence interval of the mean. `iterations` is the number of samples
    when the run has Criterion's `--json` report, else 0 (the CSV and the log do not have it).
- **JIT warm-up**: the JVM, V8 and JSC compile hot code at run time. Their frameworks warm up first,
  but the execution model differs from ahead-of-time compiled VMs.
- **Cost model rebuilt per iteration**: some public APIs do not let a harness keep the cost model
  or machine parameters across evaluations. uplc-turbo builds its default cost model in every
  evaluation call, because the crate keeps the cost model types private. Aiken's machine takes the
  cost model by value, and the crate's evaluation entry point builds a new one per call.
  scalus-js turns the cost model into machine parameters on every call. This work is in their
  timed loops.
- **No eval-only time for scalus-js**: its public API has no call that evaluates an already decoded
  program, so it has no eval-only column.
- **Memory use is not compared**: the VMs use different allocators and garbage collectors.
- **Docker overhead**: containers add a small overhead compared with bare metal. It applies to all VMs.

## Reproducing

Anyone with Docker can reproduce the results:

```bash
git clone https://github.com/lantr-io/plutus-vm-benchmark.git
cd plutus-vm-benchmark
scripts/images.sh build <vm>                    # for each VM
scripts/run-images.sh results/$(date +%F)       # or PULL=1 to use the published images
```

For the most consistent results, use a dedicated machine with no other workloads.

The monthly run is [`.github/workflows/run.yml`](.github/workflows/run.yml). It creates the server,
runs [`scripts/run-images.sh`](scripts/run-images.sh) on it with the published images, and commits
the results. A maintainer can start it by hand with a subset of VMs, scripts and loops; such a
partial run is never published.
