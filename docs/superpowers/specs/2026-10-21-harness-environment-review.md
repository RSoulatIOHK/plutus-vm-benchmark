# Harness environment review – 9 VM rows

Date: 2026-10-21. Branch `wt/review` at `03b7266`. Read-only review.

Goal: the 9 rows (aiken, blaze-v8, blaze-jsc, haskell, plutigo, scalus-js, scalus-cek, scalus-jit,
uplc-turbo) must differ because of the VM, not because of the harness.

## 0. Scope and method

- Sources: `images/*/Dockerfile`, `images/*/` harness code, `scripts/run-*.sh`,
  `scripts/image-entry.sh`, `scripts/run-images.sh`, `scripts/hetzner/run-remote.sh`,
  `nix/runner.nix`, `parsers/*.py`, `.env`, `METHODOLOGY.md`, `docs/IMAGE_CONTRACT.md`.
- Images: I inspected the local `ghcr.io/lantr-io/pvb-<vm>:latest` images. They are **arm64**
  (built on a Mac), and most of them are older than the current tags (`scripts/images.sh tag`):
  only `aiken:latest` = current tag `ca85d8d55175`. So build facts come from the Dockerfiles. Image
  facts are marked "observed" and can differ on the amd64 server image.
- Upstream sources: plutus 1.63.0.0 and cardano-node (local clones in `~/projects/iohk`),
  plutigo at `PLUTIGO_SHA` (fresh clone), Amaru (`~/projects/lantr/amaru`).
- `results/` holds only pre-redesign runs (latest 2026-05-09, WSL2). I use them only as evidence
  for framework behaviour (JMH forks, vitest sample counts), not for numbers.
- "Verify" marks a fact that I did not confirm from a primary source.

## 1. Build and runtime per VM

| VM | Runtime base / libc (observed) | Runtime, version, pin | Compiler / build flags |
|---|---|---|---|
| haskell | debian:bookworm-slim, glibc 2.36 (`images/haskell/Dockerfile:67`) | GHC 9.6.7 (`.env:17`), exact. RTS: `rts_v` (non-threaded), `-with-rtsopts` empty (observed, `+RTS --info`). No RTS options at run time (`run-haskell.sh:35-37`) | `pvb-bench`: `-O2 -rtsopts` (`pvb-bench.cabal:10`). plutus-core library: cabal default `-O1` (plutus-core has no `-O2` for the library; CEK module has no `OPTIONS_GHC -O2`). Same as plutus-benchmark `validation` |
| scalus-cek | ubuntu 22.04 (jammy), glibc 2.35 (`images/scalus/Dockerfile:15`) | JMH launcher: Temurin `JDK_VERSION=21` (floating, `.env:31`; observed 21.0.12.1). Benchmark JVM: Oracle GraalVM 25.0.2 (`.env:32`), exact. Graal JIT on (`UseJVMCICompiler=true`, observed) | Scala 3.3.8, Scalus 1.4.0 from Maven. JVM flags: `-Xss64m -XX:+UseCompactObjectHeaders -XX:+UseG1GC -XX:+UseStringDeduplication -XX:MaxInlineLevel=15 -XX:MaxInlineSize=270 -XX:ReservedCodeCacheSize=512m -XX:InitialCodeCacheSize=64m -Xmx4g -Xms4g -XX:+AlwaysPreTouch` (`run-scalus-cek.sh:40,53-56`) |
| scalus-jit | same image as scalus-cek | same | same flags (`run-scalus-jit.sh:44,51-54`). JIT module built from source at `SCALUS_SHA` |
| scalus-js | node:22-bookworm-slim, glibc 2.36 (`images/scalus-js/Dockerfile:5`) | Node `22` floating tag; observed v22.23.4. No Node flags | `scalus` 1.4.0 npm bundle (`scalus.js`, 2.4 MB, observed). vitest 4.0.18, tinybench 2.9.0 (observed) |
| blaze-v8 | ubuntu:24.04, glibc 2.39 (`images/blaze/Dockerfile:27`) | Node from nodesource `setup_22.x` (`Dockerfile:35`, `.env:28` = `22`), floating; observed v22.23.3. No Node flags | blaze **TypeScript source** (`../src/cek`), transpiled by vitest at run time (`pvb.bench.ts:11-12`), not the published `dist`. vitest 4.0.18, tinybench 2.9.0 (observed, from blaze's `bun.lock`) |
| blaze-jsc | same image as blaze-v8 | Bun 1.3.10 (`.env:27`), exact; `bun --bun run vitest` (`run-blaze-jsc.sh:41`) | same as blaze-v8 |
| aiken | debian:bookworm-slim, glibc 2.36 (`images/aiken/Dockerfile:29`) | native binary | rust:1.94 (floating patch). Our crate profile: `opt-level=3, lto="thin", codegen-units=1` (`images/aiken/bench/Cargo.toml:20-24`). Criterion **0.5**, `default-features=false` (`Cargo.toml:10`). Baseline `x86-64` target |
| uplc-turbo | ubuntu:24.04, glibc 2.39 (`images/uplc-turbo/Dockerfile:31`) | native binary | rust:1.94. `cargo build --release --bench` (`Dockerfile:26`) with the **upstream default release profile**: the workspace `Cargo.toml` has no `[profile]` (observed), so no LTO and `codegen-units=16`. Amaru itself ships `lto=true, codegen-units=1` (`amaru/Cargo.toml:165-167`). Criterion **0.7** with `html_reports` (observed). Baseline `x86-64` |
| plutigo | ubuntu:24.04, glibc 2.39 (`images/plutigo/Dockerfile:27`) | Go `1.26` (floating patch, `.env:26`), static (`CGO_ENABLED=0`, `Dockerfile:22`) | `go test -c`, default flags, `GOAMD64=v1` (default). No PGO |

Notes:

- 4 different runtime bases, 3 glibc versions (2.35, 2.36, 2.39). glibc `malloc` matters for aiken
  (Rc + system allocator) and partly for Node and GHC (`libgmp`). Go is static and does not use it.
- blaze-v8 and scalus-js claim "the same Node" (`images/scalus-js/README.md:4-5`), but they use
  different Node builds (nodesource deb vs the official image) on different OSes. The observed
  patch versions differ (22.23.3 vs 22.23.4).
- `.env:30` `GHC_VERSION=9.6.4` is unused (the Dockerfile reads `HASKELL_GHC_VERSION`).
- The JIT runtimes (JVM, V8, JSC) generate code for the real CPU (AVX2 on EPYC Milan). The AOT
  VMs (Rust, Go, GHC) are compiled for baseline x86-64 on GitHub runners.

## 2. Benchmark framework and statistic

| VM | Framework | Warm-up | Measurement | Samples | Statistic in `mean_ns` | Timer |
|---|---|---|---|---|---|---|
| haskell | criterion (Haskell) | criterion built-in (short) | `timeLimit = 20` s per script (`Main.hs:149`) | criterion samples, growing batch size | criterion CSV `Mean` (mean of per-iteration time over batches) (`parse_criterion_hs.py:185-190`) | monotonic clock, per batch |
| scalus-cek | JMH 1.x (sbt-jmh 0.4.8) | 1 × 20 s (`run-scalus-cek.sh:23,54`) | 1 × 5 s | **1 iteration** | `avgt` Score = total time / ops (`parse_jmh.py:59-66`) | `System.nanoTime`, per iteration |
| scalus-jit | JMH | 1 × 20 s | 1 × 5 s | 1 iteration | same | same |
| aiken | Criterion.rs 0.5 | default 3 s | default 5 s (`bench.rs:26-28`) | 100, linear batches | `estimates.json` mean (`parse_criterion.py:115`) | `Instant`, per batch |
| uplc-turbo | Criterion.rs 0.7 | default 3 s | **10 s** (`use_cases.rs:178-180`) | 100, linear batches | same | same |
| plutigo | Go `testing.B`, `b.Loop()` | none explicit; the `b.N` ramp-up runs act as warm-up | `-test.benchtime=5s` (`run-plutigo.sh:18,52`) | 1 final round | ns/op = total / N (`parse_go_bench.py:243`) | runtime monotonic, per round |
| blaze-v8, blaze-jsc | vitest 4.0.18 bench → tinybench 2.9.0 | **100 ms + ≥5 iterations** | **500 ms, ≥10 iterations** | 1 timestamp pair per op | arithmetic mean of per-op times (`parse_vitest.py:347-351`) | `performance.now()` around each op (tinybench `dist/index.js:281-285`) |
| scalus-js | same as blaze | same | same | same | same | same |

Sources for the vitest numbers: tinybench 2.9.0 defaults `time=500, iterations=10,
warmupTime=100, warmupIterations=5` (`node_modules/tinybench/dist/index.js:403-406`, observed in
both JS images). In normal timing the harness passes `{}` (`images/blaze/pvb.bench.ts:21`,
`images/blaze/pvb-eval.bench.ts:25`, `images/scalus-js/scalus-js.bench.mjs:6`).
Evidence from the old 2026-05-09 run (same vitest defaults): the whole blaze-v8 suite of 89
scripts took 54 s, that is about 0.6 s per script, with 74 to 1915 samples per script.

Time per script, normal timing:

| VM | Warm-up + measurement per script |
|---|---|
| scalus-cek, scalus-jit | 20 s + 5 s, plus a new JVM start |
| haskell | ≥ 20 s |
| uplc-turbo | 3 s + 10 s |
| aiken | 3 s + 5 s |
| plutigo | ~5 s + ramp-up |
| blaze-v8, blaze-jsc, scalus-js | 0.1 s + 0.5 s |

V8 and JSC are JIT engines, like the JVM. They get 1/200 of the JVM warm-up time.

Parser columns that are not what their name says (the report ranks on `mean_ns` only,
`report/generate_report.py:86`, so the ranking is not affected):

- `median_ns` = `mean_ns` for haskell (`parse_criterion_hs.py:194`), JMH (`parse_jmh.py:72`), Go
  (`parse_go_bench.py:248`) and the vitest text table (`parse_vitest.py:354`). Only Criterion.rs
  gives a real median.
- `min_ns`/`max_ns` are `score ± error` for JMH (`parse_jmh.py:69-70`) and `MeanLB`/`MeanUB` for
  haskell (`parse_criterion_hs.py:192-193`), not a minimum and maximum. Go writes 0.
- `stddev_ns` is the JMH 99.9 % error (`parse_jmh.py:68`); with `-i 1` it is `NaN` → 0. For vitest
  it is `mean × rme %` (`parse_vitest.py:355`), a margin of error, not a standard deviation.

## 3. Timed region

### 3.1 D3 loop (`<vm>.csv`, the ranking)

| VM | Inside the timed region | Built once, outside | Result handling |
|---|---|---|---|
| haskell | `unflat` + `termMapNames fakeNameDeBruijn` (a full term pass) + `evaluateTerm` (counting) (`Main.hs:77-100`) | `EvaluationContext` from the mainnet array (`Main.hs:64-74,132`); file bytes (`Main.hs:142`) | WHNF of `budget \`seq\` isRight result` (`Main.hs:99-100`) |
| scalus-cek | `DeBruijnedProgram.fromFlatEncoded` + `evaluateDeBruijnedTerm` with a new `CountingBudgetSpender` (`CekJVMBenchmark.scala:37`, `Harness.scala:51-58`) | `PlutusVM` with `MachineParams` (`CekJVMBenchmark.scala:29`) | returns the result `Term`, JMH blackhole |
| scalus-jit | **no decode**: call of the compiled code with a new spender (`JITBenchmark.scala:30`, `Harness.scala:76-80`) | decode + JIT compile in `@Setup` (`JITBenchmark.scala:22-25`) | returns the JIT value, blackhole |
| aiken | `from_flat` + `FakeNamedDeBruijn → NamedDeBruijn` + `eval_version_with_protocol(ExBudget::max())`, which builds a new machine and cost model per call; `catch_unwind` (`lib.rs:24-60`) | file bytes | `b.iter` returns `EvalResult`; Criterion drops it **inside** timing (`bench.rs:49`) |
| uplc-turbo | `flat::decode` into an arena + `eval_version_budget(V3, ExBudget::max())`, which builds the default V3 cost model per call + `arena.reset()` (`use_cases.rs:133-141`) | the arena (`use_cases.rs:121`), file bytes | `black_box(is_ok())`, then arena reset inside timing |
| plutigo | `decoder.Decode` (reused `DeBruijnDecoder`, its arenas keep their chunks between calls, `syn/flat_decode.go:50-55` at the pin) + `machine.Run` (`pvb_bench_test.go:138-146`) | `EvalContext`, **one machine per script** (`Run` resets the budget and state), one decoder per script (`pvb_bench_test.go:136-137`) | error check only |
| blaze-v8/jsc | `decodeFlatDeBruijn` + `new CekMachine(unlimitedBudget(), costs)` + `run` (`pvb.bench.ts:23-27`) | cost table (`pvb.bench.ts:20`); file bytes | result discarded |
| scalus-js | `evaluator.evaluateScript(flat, [], OPTIONS)`: format detection, flat decode, cost model → machine parameters **per call**, CEK, result conversion to a JS object, CIP-117 return check (`common.mjs:26-28`, `README.md:29-31`) | `EvaluationOptions.mainnet("PlutusV3")` (`common.mjs:14`) | result discarded |

### 3.2 Eval-only loop (`<vm>-eval.csv`)

| VM | Inside the timed region | Outside |
|---|---|---|
| haskell | `evaluateTerm` (`Main.hs:104-108`) | decode, forced to normal form by `env` (`Main.hs:146-147`) |
| scalus-cek | `evaluateDeBruijnedTerm`, new spender (`CekJVMBenchmark.scala:42`) | decode in `@Setup` |
| scalus-jit | the same loop as D3 (`run-scalus-jit.sh:63-65`) | decode + compile |
| aiken | `eval` (new machine, new cost model) (`bench.rs:46`) | `program.clone()` in `iter_batched` setup; the outputs of `iter_batched` are dropped **after** the timer stops (Criterion.rs `iter_batched` docs – verify) |
| uplc-turbo | `eval_version_budget` + `drop(result)` + `arena.reset()` (`use_cases.rs:163-168`) | decode into a separate arena |
| plutigo | `machine.Run` on the reused machine (`pvb_bench_test.go:193-200`) | decode; reuse proven by a budget check (`pvb_bench_test.go:177-192`) |
| blaze-v8/jsc | `new CekMachine` + `run` (`pvb-eval.bench.ts:51-57`) | decode |
| scalus-js | – (no API, `run-scalus-js.sh:6-9`) | – |

### 3.3 Asymmetries found

1. **scalus-jit D3 row has no decode.** The ranking is decode + eval for 8 rows and eval only for
   scalus-jit (`run-scalus-jit.sh:63-65`). The badge says "compile excluded"
   (`METHODOLOGY.md:36-41`), but decode is excluded too.
2. **Per-call setup that the API forces** (disclosed in `METHODOLOGY.md:143-149`): aiken and
   uplc-turbo build a cost model per call; scalus-js builds machine parameters and converts the
   result per call. These are VM API costs, not harness errors. Keep the disclosure.
3. **Result drop.** aiken D3 drops the result inside timing; aiken eval-only drops it outside.
   uplc-turbo drops inside in both loops. So "D3 − eval = decode" is true for uplc-turbo and blaze,
   but not for aiken.
4. **Allocator reuse through the public API.** plutigo reuses the decoder arenas and the machine;
   uplc-turbo reuses the evaluation arena. `IMAGE_CONTRACT.md:92-94` names only the cost model,
   machine parameters and machine object. The reuse is legal (public API, a node can do it), but
   the contract does not name it.
5. **Budget mode.** haskell, Scalus and blaze count (blaze: `unlimitedBudget()` passes `I64_MAX`,
   so `restricting = false`, `src/cek/machine.ts:72-74`, observed); aiken, uplc-turbo and plutigo
   use a maximal restricting budget. The contract allows both (`IMAGE_CONTRACT.md:86`). No action.
6. **blaze runs source, not its release.** The harness imports `../src/cek` through vitest's
   transform. Downstream users run the `tsdown` build in `dist/`. The difference is probably small;
   disclose it or import the built package.

No VM checks results or ExUnits inside the timed loop. Every VM reads files outside the loop.

## 4. Threads, memory, affinity, priority

| VM | Threads beside the benchmark thread | Heap / GC settings |
|---|---|---|
| haskell | none: non-threaded RTS, GC on the benchmark thread | RTS defaults, no `-A`/`-H` |
| scalus-cek/jit | Graal JIT compiler threads (`CICompilerCount` ergonomic, 4 observed with 14 CPUs), G1 parallel and concurrent GC threads, string dedup thread | G1, `-Xms4g -Xmx4g`, `AlwaysPreTouch` |
| blaze-v8, scalus-js | V8 background compile and concurrent marking threads; vitest runs the bench in a worker process | V8 defaults, no `--max-old-space-size` |
| blaze-jsc | JSC JIT threads, concurrent GC | defaults |
| plutigo | Go GC workers on up to `GOMAXPROCS` = 8 CPUs | `GOGC=100` default |
| aiken, uplc-turbo | none in the timed code (Criterion.rs analysis runs between benchmarks) | glibc malloc (aiken), bumpalo arena (turbo) |

- Wall time is the metric. VMs with background threads move GC and JIT work to idle CPUs. GHC and
  Rust cannot. With 8 idle vCPUs this favours JVM, V8, JSC and Go. This is part of the VM design,
  but the page does not show it.
- No CPU pinning: no `--cpuset-cpus`, no `taskset` anywhere (`run-images.sh:119-126`).
- Priority: `nice -n -20` for the whole run script (`image-entry.sh:106-116`), with
  `--cap-add SYS_NICE`. Same for every VM.
- cardano-node runs GHC with `-threaded -A16m -N2` (`cardano-node.cabal:229-235`). Plutus's own
  `validation` benchmark uses no RTS options (`plutus-benchmark.cabal:360-370`). The harness
  follows Plutus's benchmark.

## 5. Process model and order

| VM | Processes |
|---|---|
| scalus-cek, scalus-jit | JMH `-f 1`: **one new JVM per script** (and per method). Evidence: 89 `# Fork: 1 of 1` blocks in `results/2026-05-09/scalus-cek-raw.log`. Each script gets a clean JIT profile |
| blaze-v8, blaze-jsc, scalus-js | one vitest worker for all scripts of one loop. JIT profile and heap carry from script to script |
| haskell, aiken, uplc-turbo, plutigo | one process for all scripts of one loop; heap and allocator state carry over (no JIT) |

- The JVM rows get a per-script specialised JIT. The JS rows get a JIT that has seen up to 88
  other scripts first. That can help (warm shared code) or hurt (polymorphic call sites). The
  direction is unknown; the harness causes it.
- Go runs `runtime.GC()` before each `b.N` round. Haskell criterion also collects between
  measurements (verify). JMH (`-gc false` default), tinybench and Criterion.rs do not.
- VM order is fixed: the order of `scripts/images.sh list` (`images.sh:32-37`), alphabetical by
  image dir. A 3–5 h run with host drift (boost clock, noisy neighbours) shifts VMs in a fixed
  direction.

## 6. Docker and host

Docker (`run-images.sh:119-126`):

- `docker run --rm --cap-add SYS_NICE`, data bind mount read-only, results bind mount.
- No `--cpus`, `--cpuset-cpus`, `--memory`. Default seccomp profile. Default bridge network
  (network on). Default `json-file` log driver: every line of Criterion, JMH and vitest output goes
  through dockerd. overlay2 storage; Criterion writes its JSON to the container's `/tmp` or
  `target/` (outside timing).
- The pull of each image runs just before its run (`PULL=1`, `run-images.sh:109`,
  `run-remote.sh:40`). The scalus images are about 1.3 GB compressed. Disk and CPU work of the
  extraction ends before the run, but page cache and dockerd state differ per VM.

Host (`nix/runner.nix`):

- Rootful Docker (`runner.nix:88`), sshd, systemd-networkd, `bench-ssh-keys` (boot only),
  `bench-selfdestruct` timer (one shot at 14 h, `runner.nix:13,62-65`). The run is a transient
  systemd unit (`run-remote.sh:37-46`); the workflow polls it over SSH every 5 min.
- fail2ban: **not** enabled in `runner.nix`. `nix.gc.automatic` and `nix.optimise.automatic` are not
  set (NixOS default off). Docker `autoPrune` not set (default off). Other default NixOS units (for
  example `logrotate`, `systemd-tmpfiles-clean`, `nscd`, `systemd-timesyncd`) still run; verify with
  `systemctl list-timers` on the server.
- CPU governor: `powerManagement.cpuFreqGovernor = "performance"` (`runner.nix:91`). A KVM guest
  has no cpufreq driver, so this does nothing (the comment at `runner.nix:90` says so). Boost clock
  is controlled by the Hetzner host and other tenants on the same socket.
- THP: not set in `runner.nix`. The nixpkgs kernel default is probably `madvise` (verify). With
  `madvise` no runtime here asks for huge pages (`UseTransparentHugePages=false`, observed).
- SMT topology of a ccx33 (8 vCPU = 4 cores × 2 threads, or 8 cores?) is not known and not
  recorded. If two benchmark-relevant threads share one core, results change.
- `environment.txt` (`run-images.sh:75-95`) records CPU model, cores, memory, kernel, Docker. It
  does not record THP, cpufreq, `lscpu` topology, kernel command line (mitigations), steal time,
  load average, or running timers.

## 7. Changes, by priority

"Owner" = needs a decision of the VM owner (or of the benchmark owner where it is a policy).

### Must

| # | Change | File | Expected effect | Owner |
|---|---|---|---|---|
| M1 | Give the JS engines the same warm-up and measurement as the JVM rows: `{ warmupTime: 20_000, time: 5_000 }` in normal timing (or one shared value for all JIT runtimes) | `images/blaze/pvb.bench.ts:21`, `images/blaze/pvb-eval.bench.ts:25`, `images/scalus-js/scalus-js.bench.mjs:6` | V8/JSC reach steady state; removes the 200× warm-up gap and the 10× measurement gap. Run time of each JS loop grows from ~1 min to ~37 min | no (harness) |
| M2 | One process model for all VMs. Simplest: run each script in its own process (loop over scripts in each `run-<vm>.sh`, `BENCH_DATA_DIR` with one file). Alternative: keep it and disclose "JVM: fresh process per script; others: one process per loop" | `scripts/run-*.sh`, or `scripts/image-entry.sh:116` | Removes the per-script clean JIT profile that only the JVM rows have; removes order effects inside a loop | policy |
| M3 | scalus-jit in the D3 ranking: either rank it with the eval-only column, or change the badge to "decode and compile excluded" | `report/generate_report.py`, `METHODOLOGY.md:36-41`, `docs/IMAGE_CONTRACT.md:61-63` | The ranking compares the same work, or says clearly that it does not | Scalus owner |
| M4 | A written runtime-flags policy for all VMs: stock runtime defaults, or VM-owner flags that are listed on the page. Today only the Scalus rows are tuned (Oracle GraalVM, inlining limits, compact headers, pre-touched 4 GB heap, `run-scalus-cek.sh:40,56`) | `METHODOLOGY.md`, `run-scalus-*.sh`, per-VM flags | Removes the impression that the harness author tuned his own VM only | Scalus owner + policy |
| M5 | Record noise data per VM: steal time and load average before and after each `docker run`, THP mode, `lscpu` (threads per core), `/proc/cmdline`, cpufreq presence, `systemctl list-timers` | `scripts/run-images.sh:75-95,118-131` | A noisy VM run becomes visible; topology and THP become reproducible facts | no |

### Should

| # | Change | File | Expected effect | Owner |
|---|---|---|---|---|
| S1 | Same Rust release profile for aiken and uplc-turbo, set by `CARGO_PROFILE_RELEASE_LTO` / `CARGO_PROFILE_RELEASE_CODEGEN_UNITS` (and the `BENCH_` equivalents) in both Dockerfiles. Candidates: the downstream profile (Amaru: fat LTO, cgu 1) or one shared value | `images/uplc-turbo/Dockerfile:26`, `images/aiken/bench/Cargo.toml:20-24` | Removes an LTO/codegen-unit gap between the two Rust rows (often 5–15 %, measure) | aiken and Amaru owners |
| S2 | Same Criterion.rs version and measurement time for both Rust rows (0.7, 3 s + 10 s or 3 s + 5 s) | `images/aiken/bench/Cargo.toml:10`, `images/aiken/bench/src/bench.rs:26-28`, `images/uplc-turbo/use_cases.rs:178-180` | Same framework, same sample budget | no |
| S3 | aiken eval-only: drop the result inside the routine (`\|p\| { let r = eval(black_box(p)); drop(r); }`) | `images/aiken/bench/src/bench.rs:46` | Eval loop has the same cleanup as D3 and as uplc-turbo | no |
| S4 | One Node build for blaze-v8 and scalus-js: exact `NODE_VERSION=22.x.y` in `.env`, `node:${NODE_VERSION}-bookworm-slim` as the base of both runtime stages (copy Bun into it for blaze-jsc) | `.env:28`, `images/blaze/Dockerfile:27-37`, `images/scalus-js/Dockerfile:5` | The "same Node" claim becomes true | no |
| S5 | One runtime base for all images (for example `debian:bookworm-slim`), and exact patch pins for Rust, Go and the JDK 21 launcher | all `images/*/Dockerfile`, `.env:25-26,31` | Same glibc/malloc; monthly runs do not drift with floating tags | no |
| S6 | Uniform CPU set for every container, for example `--cpuset-cpus=1-7` (CPU 0 for host daemons and IRQs). Record cgroup `cpu.stat` `usage_usec` before and after each loop, and show "CPU-seconds per wall-second" on the page | `scripts/run-images.sh:119`, `scripts/image-entry.sh:114-118` | Same CPUs for each VM; the page shows which VMs use helper threads | policy |
| S7 | Pull all images first, then run | `scripts/run-images.sh:100-117` | No extraction or cache churn just before a VM | no |
| S8 | Drift probe: run haskell at the start and again at the end (or rotate the VM order per run) | `scripts/run-images.sh:100` | Measures host drift during the multi-hour run; the Haskell ratio needs a stable Haskell | no |
| S9 | JMH: `-i 5 -r 1s` instead of `-i 1 -r 5s` (same 5 s) | `run-scalus-cek.sh:54`, `run-scalus-jit.sh:52` | JMH gives an error estimate; today it is `NaN` | no |
| S10 | Parsers: write empty cells instead of fake `median`/`min`/`max`/`stddev`; parse the vitest JSON reporter (real p50, sd) | `parsers/parse_jmh.py:66-72`, `parse_criterion_hs.py:190-195`, `parse_go_bench.py:246-249`, `parse_vitest.py:351-355` | `unified.csv` columns mean what they say | no |
| S11 | Haskell RTS options: keep Plutus's benchmark defaults, or use the node's `-A16m` (and `-threaded -N2`). Write the choice in `METHODOLOGY.md` | `images/haskell/pvb-bench/pvb-bench.cabal:10` or `run-haskell.sh:35` | The "node-equivalent" claim (D3) matches the RTS the node uses, or says why not | IOG / owner |
| S12 | Name allocator and machine reuse in the contract (decoder arenas, evaluation arenas, reusable machines), and apply it the same way: if the API allows reuse, reuse it | `docs/IMAGE_CONTRACT.md:92-94` | The reuse rule covers what plutigo and uplc-turbo do | no |

### Nice

| # | Change | File | Expected effect | Owner |
|---|---|---|---|---|
| N1 | `--network none` | `scripts/run-images.sh:119` | No network activity during a run | no |
| N2 | `--log-driver none` (keep the attached stream), or a quiet reporter | `scripts/run-images.sh:119` | Less dockerd work while VMs print | no |
| N3 | Remove `-XX:+UseStringDeduplication` (no effect on this workload, one more thread) | `run-scalus-cek.sh:40`, `run-scalus-jit.sh:44` | One fewer background thread | Scalus owner |
| N4 | Pin THP explicitly (`boot.kernelParams = [ "transparent_hugepage=madvise" ]`) | `nix/runner.nix` | Same memory behaviour on every run | no |
| N5 | AOT target: `-C target-cpu=x86-64-v3`, `GOAMD64=v3`, GHC `-mavx2`-class flags. Not `native`: images build on GitHub runners | Rust/Go/Haskell Dockerfiles | AOT VMs use the same ISA level as the JIT VMs | VM owners |
| N6 | blaze: benchmark the built `dist` package instead of `src` | `images/blaze/pvb*.ts` imports | The row is the code downstream users run | blaze owner |

## 8. Where equality is not possible – disclosure

| Difference | Why it stays | Suggested text for the page |
|---|---|---|
| Statistics | Criterion (Haskell and Rust) uses means of batch means; JMH and Go use total time / operations; tinybench times each operation and adds timer overhead (~0.1 µs) | "Each time is the mean time per evaluation as the VM's own benchmark framework computes it. Frameworks sample differently; differences under about 5 % are not significant." |
| Medians | Only Criterion.rs and tinybench give one | Rank on the mean only; do not show a median column |
| API-imposed work | aiken and uplc-turbo build a cost model per call; scalus-js builds machine parameters and converts the result per call and has no eval-only API | Keep `METHODOLOGY.md:143-151`, and add a marker on these rows |
| Runtime threads | JVM, V8, JSC and Go use helper threads for GC and JIT; GHC (non-threaded) and Rust do not | "Times are wall-clock. Some runtimes do GC and compilation on other cores; the CPU column shows the CPU time per wall time." |
| Allocation and GC | Arenas (uplc-turbo, plutigo), refcount + malloc (aiken), generational GCs (others) | "Memory management is part of each VM and is in the time." |
| JIT dynamics | Warm-up length can be equal, but the time to steady state differs by engine | "JIT runtimes are measured after N s of warm-up; the first evaluation is slower." |
| ISA level | JIT runtimes use the host CPU; AOT binaries use a fixed level | State the level of each AOT build |
| Host | Cloud VM: boost clock and other tenants are not under our control | Show the steal time and the Haskell drift probe for each run |

## 9. Summary of the main risks

1. JS rows get 0.6 s per script; JVM rows get 25 s and a fresh JVM per script (M1, M2).
2. scalus-jit's ranked time has no decode (M3).
3. Only the Scalus rows have tuned runtime flags (M4).
4. The two Rust rows have different LTO profiles and Criterion versions (S1, S2).
5. The run does not record steal time, topology or THP, so noise is invisible (M5).
