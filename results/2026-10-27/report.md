# Plutus VM Benchmark Results

**Date:** 2026-10-27

## Environment
```
date: 2026-10-27T15:30:25+00:00
kernel: Linux 6.18.57
cpu: AMD EPYC-Milan Processor
cores: 16
memory: 61Gi
cpu flags (selected): hypervisor sse4_2 avx avx2 bmi2 fma sha_ni
topology: Model name AMD EPYC-Milan Processor; Thread(s) per core 2; Core(s) per socket 8; Socket(s) 1; Hypervisor vendor KVM; Virtualization type full; NUMA node(s) 1
lscpu mhz: n/a
cpufreq: none (no cpufreq driver, for example a KVM guest)
thp: enabled madvise, defrag madvise
kernel cmdline: BOOT_IMAGE=(hd0,gpt2)//kernels/ipabfanvi3crlh1zf18ss5fzh6lk1glg-linux-6.18.57-bzImage init=/nix/store/1nhkfsbcc9qy7g29vp49w4kxybwmiap0-nixos-system-bench-runner-26.05.20261020.cd4ea8d/init transparent_hugepage=madvise root=fstab loglevel=4 lsm=landlock,yama,bpf
timers: bench-selfdestruct.timer systemd-tmpfiles-clean.timer
load avg at start: 0.65 0.16 0.05
docker: 29.9.1 (linux/amd64)
docker cpus: 16
docker memory: 62786 MiB
docker run flags: --rm --cap-add SYS_NICE --network none
lanes: 3 (lane0 2,3,4,5; lane1 6,7,8,9; lane2 10,11,12,13; idle cores 14,15)
parallel: yes (up to 3 VMs at once; haskell and the drift probe run alone on lane0)
harness: 256b6aafce0f44faa876a9b24ed586c11bc385d3
vm order: haskell scalus-cek scalus-jit scalus-js blaze-v8 aiken aiken-wasm uplc-turbo plutigo chrysalis chrysalis-aot julc-java llvm-uplc-jit plutuz uplc-turbo-bc
bench_quick: 0
bench_scripts: <all> (89 of 89 scripts)
bench_loops: d3,eval,check
bench_timing: normal
bench_trace: 0
host cpus: 0,1,14,15
server qualification: pass, ratio 1.122, attempt 1 of 3, nbg1; rejected: none; haskell geo ratio 1.122 <= 1.15 vs ccx43 reference (harness b0d8a22, 2026-10-22): auction_1-1 1.05, coop-6 1.18, uniswap-1 1.13
image haskell: ghcr.io/lantr-io/pvb-haskell:cf0113e362e9 ghcr.io/lantr-io/pvb-haskell@sha256:293da049bd7c65ee6e058bb0d782625f89ecf38ca8e80f6fcf3468740e503c8c
noise haskell: load avg before 1.62 0.52 0.18, steal during run 0.00 % (0 of 1475757 ticks) lane0
image scalus-cek: ghcr.io/lantr-io/pvb-scalus-cek:e518f535d996 ghcr.io/lantr-io/pvb-scalus-cek@sha256:b817c3c0b2e18a38507e3040981c48956d7129f30d0d1020c1445d898d38234f
image scalus-jit: ghcr.io/lantr-io/pvb-scalus-jit:1aca35514d4c ghcr.io/lantr-io/pvb-scalus-jit@sha256:4a192b7e735b7b8ffed9ec96cff07113ad7de7282621252efbe011d7dc5ebd7b
image scalus-js: ghcr.io/lantr-io/pvb-scalus-js:9e63edfb374a ghcr.io/lantr-io/pvb-scalus-js@sha256:4eb32b92df051e2d3116e7e43fd10f4c522c2f28534df82e7ef7c1efddb431d4
noise scalus-js: load avg before 1.00 1.00 0.73, steal during run 0.00 % (0 of 6580644 ticks) lane2
image blaze-v8: ghcr.io/lantr-io/pvb-blaze-v8:c743ca940f93 ghcr.io/lantr-io/pvb-blaze-v8@sha256:3ba639f3d830d8e94d4d89eb945f38fdd382a7503352ed5882e2eec7c2925b84
noise scalus-jit: load avg before 1.00 1.00 0.73, steal during run 0.00 % (0 of 8872262 ticks) lane1
image aiken: ghcr.io/lantr-io/pvb-aiken:553af555815c ghcr.io/lantr-io/pvb-aiken@sha256:b1328c3825f56f452b1f7de6b156b45729d56979ab8afb122e9223fad02a5660
noise aiken: load avg before 3.18 3.29 3.46, steal during run 0.00 % (0 of 2982318 ticks) lane1
image aiken-wasm: ghcr.io/lantr-io/pvb-aiken-wasm:0770cbcc5dd3 ghcr.io/lantr-io/pvb-aiken-wasm@sha256:8251a1aae91e85e8add5850bff0be3ad6bab70c681f38e22b721b019a4ea86df
noise blaze-v8: load avg before 3.83 3.75 3.67, steal during run 0.00 % (0 of 6160554 ticks) lane2
image uplc-turbo: ghcr.io/lantr-io/pvb-uplc-turbo:f50174b9cf91 ghcr.io/lantr-io/pvb-uplc-turbo@sha256:3368eb649ecd8ec3efcdbe0aedd5f730840b81f6e4c680d6e24fc5ee4b156e9c
noise scalus-cek: load avg before 1.00 1.00 0.73, steal during run 0.00 % (0 of 13278833 ticks) lane0
image plutigo: ghcr.io/lantr-io/pvb-plutigo:9329d975a97e ghcr.io/lantr-io/pvb-plutigo@sha256:729c0d1a52503c93527d273de4883050c4760ac3b9f3d770c21e733cf08f3087
noise aiken-wasm: load avg before 3.27 3.23 3.22, steal during run 0.00 % (0 of 3080482 ticks) lane1
image chrysalis: ghcr.io/lantr-io/pvb-chrysalis:e2b8b3ae047a ghcr.io/lantr-io/pvb-chrysalis@sha256:765e67d6392301a2b977cbc3ed5d3d1481132dfab5c7346294900c8127eb278d
noise plutigo: load avg before 3.13 3.14 3.16, steal during run 0.00 % (0 of 1711951 ticks) lane0
image chrysalis-aot: ghcr.io/lantr-io/pvb-chrysalis-aot:0b6b2579dcee ghcr.io/lantr-io/pvb-chrysalis-aot@sha256:5ddb9793c4e53f6b32bf6c3a8b9e6d4ade92efc0cc9bfedfd38634c76d5cbe4d
noise uplc-turbo: load avg before 3.02 3.12 3.16, steal during run 0.00 % (0 of 3032616 ticks) lane2
image julc-java: ghcr.io/lantr-io/pvb-julc-java:5d99bb6a10a8 ghcr.io/lantr-io/pvb-julc-java@sha256:681c5af463f8c54960935ae618b789ff4e54fcfe57db025775cbd5c75edadeaa
noise chrysalis-aot: load avg before 3.04 3.06 3.08, steal during run 0.00 % (0 of 5284875 ticks) lane0
image llvm-uplc-jit: ghcr.io/lantr-io/pvb-llvm-uplc-jit:4f3d33826b1d ghcr.io/lantr-io/pvb-llvm-uplc-jit@sha256:af55d767e44000db5ce5848545fe8f4833b0aac7b65dde84cdbbaa23cfc4b3ba
noise llvm-uplc-jit: load avg before 3.26 3.21 3.13, steal during run 0.00 % (0 of 3667144 ticks) lane0
image plutuz: ghcr.io/lantr-io/pvb-plutuz:78e70bdbc120 ghcr.io/lantr-io/pvb-plutuz@sha256:3f145d66b434529cc15320f0081ee9c12b177c5bd9eceb1a141f44ce6da8d1af
noise plutuz: load avg before 3.35 3.18 3.12, steal during run 0.00 % (0 of 1429123 ticks) lane0
image uplc-turbo-bc: ghcr.io/lantr-io/pvb-uplc-turbo-bc:04b6cc170f17 ghcr.io/lantr-io/pvb-uplc-turbo-bc@sha256:97678a9fa315fd3b9c935237f85ac0dbf551d6a1b3b8f4f7cfaad876448e6133
noise uplc-turbo-bc: load avg before 3.21 3.16 3.11, steal during run 0.00 % (0 of 2919949 ticks) lane0
noise julc-java: load avg before 3.24 3.08 3.07, steal during run 0.00 % (0 of 13216180 ticks) lane2
noise chrysalis: load avg before 3.06 3.06 3.08, steal during run 0.00 % (0 of 21825760 ticks) lane1
steal during the whole run: 0.00 % (0 of 38368068 ticks)
load avg at end: 1.00 1.00 1.00
drift (haskell, end vs start): +1.2 % over 5 scripts
```

*The 89 scripts are PlutusV1-era programs. Every VM evaluates them as PlutusV3 programs at protocol version 11 with the mainnet cost model, like Plutus's own `validation` CEK benchmark; the node would run them as PlutusV1.*

*Drift (Haskell, end vs start): +1.2 % over 5 scripts. The run timed Haskell again at its end; this is the change of its time.*

## Summary (geometric mean across all scripts)

*Note: VMs that fail or skip a script are assigned the slowest competitor's time for that script.*
*A compiling VM's timed loop runs the compiled script ("decode and compile excluded": the decode and the compile run once per script, before timing). So it has only an eval-only time: its Geo Mean (decode + eval) is "–" and it is not ranked. The Compile column is the geometric mean of the compile time over the scripts.*
*Geo Mean: flat decode + evaluation (the ranking). Eval only: evaluation of a program decoded before the timed loop, geometric mean over its scripts.*
*Aiken WASM caches decoded programs inside the library, so its time is shown as eval only. It is not in the decode + eval ranking; it is ranked on eval only (Geo Mean "–").*
*Aiken uplc CEK (Rust → WASM / Node V8), "decode cached (by the library)": The library caches the decoded program by a hash of the flat bytes. After the first call (in the warm-up), the timed loop runs hash + evaluation, without the decode. Its eval-only time is the same loop.*

| VM | Language | Geo Mean | vs Fastest | Eval only | Compile | Check |
|---|---|---|---|---|---|---|
| **Scalus CEK (Scala / JVM)** | Scala / JVM | 268.19 us | 1.00x | 170.83 us | - | pass |
| **Plutigo CEK (Go)** | Go | 306.48 us | 1.14x | 204.65 us | - | pass |
| **amaru-uplc AST walker (Rust)** | Rust | 467.01 us | 1.74x | 365.22 us | - | pass |
| **plutus-core CEK (Haskell / GHC)** | Haskell / GHC | 710.63 us | 2.65x | 276.06 us | - | pass |
| **Scalus CEK (Scala.js / Node V8)** | Scala.js / Node V8 | 1.46 ms | 5.46x | 980.88 us | - | pass |
| **Aiken uplc CEK (Rust)** | Rust | 8.22 ms | 30.66x | 6.21 ms | - | pass |
| **Aiken uplc CEK (Rust → WASM / Node V8)** (decode cached (by the library)) | Rust → WASM / Node V8 | – | eval only | 884.88 us | - | pass |

### Experimental

Run, gated and shown, but not ranked: not in the table above, not a competitor in the penalty rule. Geo Mean uses the penalty rule against the ranked VMs. Geo Mean "–" (compiled once before timing, see the compile column): the VM has only an eval-only time.

| VM | Language | Geo Mean | Eval only | Compile | Check | Reason |
|---|---|---|---|---|---|---|
| **Scalus UPLC→JVM JIT (Scala / JVM)** | Scala / JVM | – | 94.41 us | 1.71 s (decode and compile excluded) | pass | **no downstream user**. not ranked: the JIT module is published (Maven, since Scalus 1.4.1) but has no downstream users yet (spec D17) |
| **blaze-plutus CEK (TypeScript / Node V8)** | TypeScript / Node V8 | 1.29 ms | 1.06 ms | - | pass | **no downstream user**. not ranked: no released project outside the Blaze repo depends on @blaze-cardano/plutus yet; Blaze itself evaluates scripts with @blaze-cardano/vm (Aiken uplc as WASM) (spec D17) |
| **Chrysalis CEK (C# / .NET JIT)** | C# / .NET JIT | 536.58 us | 401.63 us | - | pass | **pre-release only**. not ranked: only pre-releases on NuGet (Chrysalis.Plutus -alpha); the one stable version, 1.7.1, is unlisted (spec D22) |
| **Chrysalis CEK (C# / .NET AOT)** | C# / .NET AOT | 586.35 us | 447.74 us | - | pass | **pre-release only**. not ranked: only pre-releases on NuGet (Chrysalis.Plutus -alpha); the one stable version, 1.7.1, is unlisted (spec D22) |
| **Julc Java CEK (Java / JVM)** | Java / JVM | 487.78 us | 392.40 us | - | pass | **pre-release only**. not ranked: only pre-releases (0.1.0-preNN), and no downstream users yet (spec D22) |
| **Plutuz CEK (Zig)** | Zig | 517.88 us | 335.45 us | - | pass | **no release**. not ranked: no release (no tags or releases on GitHub), pinned to a main commit (spec D22) |
| **llvm-uplc UPLC→native JIT (C++ / LLVM)** | C++ / LLVM | – | 111.08 us | 8.19 s (decode and compile excluded) | outdated cost model | **outdated**. not ranked: outdated. Its built-in cost model is variant C (before protocol version 11; divideInteger c11 549, mainnet 960), no API takes a cost model, and its last commit is from 2026-04-16. No release (spec D22) |
| **amaru-uplc bytecode VM, fork jonathanlim222/uplc (Rust)** | Rust | 340.86 us | 220.89 us | - | pass | **no release**. not ranked: no release has the bytecode mode; it is in the fork jonathanlim222/uplc (closed PR pragma-org/uplc#47), pinned to a commit (spec D22) |

### Notes

- **Aiken uplc CEK (Rust)**: Aiken v1.1.24 copies the CEK environment on every lambda application (quadratic in recursion depth). aiken main fixes it (PRs [#1451](https://github.com/aiken-lang/aiken/pull/1451), [#1452](https://github.com/aiken-lang/aiken/pull/1452): coop-6 92 ms -> 1.2 ms), but no release contains the fix yet.
- **Aiken uplc CEK (Rust → WASM / Node V8)**: Built from [colll78/aiken](https://github.com/colll78/aiken) (aiken main plus fixes), which includes the CEK fixes that v1.1.24 lacks.

### History (speed relative to Haskell plutus-core, same run; higher is faster)

| VM | 2026-10-23 | 2026-10-26 | 2026-10-27 | Change vs previous run |
|---|---|---|---|---|
| plutus-core CEK (Haskell / GHC) | 1x (Haskell) | 1x (Haskell) | 1x (Haskell) | reference |
| Scalus UPLC→JVM JIT (Scala / JVM) (experimental, eval only) | 2.2x faster | 2.6x faster | 2.9x faster | +13 % |
| Scalus CEK (Scala / JVM) | 1.8x faster | 3.0x faster | 2.6x faster | -12 % |
| Scalus CEK (Scala.js / Node V8) | 5.0x slower | 2.1x slower | 2.1x slower | no change (within ±5 % noise) |
| Aiken uplc CEK (Rust) | 11.6x slower | 10.2x slower | 11.6x slower | -12 % |
| Aiken uplc CEK (Rust → WASM / Node V8) (eval only) | 3.3x slower | 3.2x slower | 3.2x slower | no change (within ±5 % noise) |
| amaru-uplc AST walker (Rust) | 1.5x faster | 1.5x faster | 1.5x faster | no change (within ±5 % noise) |
| Plutigo CEK (Go) | 2.5x faster | 2.6x faster | 2.3x faster | -10 % |
| blaze-plutus CEK (TypeScript / Node V8) (experimental) | 2.5x slower | 2.1x slower | 1.8x slower | +16 % |
| Chrysalis CEK (C# / .NET JIT) (experimental) | - | - | 1.3x faster | - |
| Chrysalis CEK (C# / .NET AOT) (experimental) | - | - | 1.2x faster | - |
| Julc Java CEK (Java / JVM) (experimental) | - | - | 1.5x faster | - |
| Plutuz CEK (Zig) (experimental) | - | - | 1.4x faster | - |
| llvm-uplc UPLC→native JIT (C++ / LLVM) (experimental, eval only) | - | - | 2.5x faster | - |
| amaru-uplc bytecode VM, fork jonathanlim222/uplc (Rust) (experimental) | - | - | 2.1x faster | - |

A VM marked "eval only" has no decode + eval time (it compiles each script before timing, or its library caches the decode): its ratio is its eval-only time divided by Haskell's eval-only time.

Servers of the same type differ: ratios to Haskell move up to about 5 % between two runs on different servers, so a change under 5 % is shown as no change.

### Script Coverage

| VM | Passed | Failed | Missing | Total |
|---|---|---|---|---|
| Scalus CEK (Scala / JVM) | 89 | 0 | 0 | 89 |
| Plutigo CEK (Go) | 89 | 0 | 0 | 89 |
| amaru-uplc AST walker (Rust) | 89 | 0 | 0 | 89 |
| plutus-core CEK (Haskell / GHC) | 89 | 0 | 0 | 89 |
| Scalus CEK (Scala.js / Node V8) | 89 | 0 | 0 | 89 |
| Aiken uplc CEK (Rust) | 89 | 0 | 0 | 89 |
| Aiken uplc CEK (Rust → WASM / Node V8) | 89 | 0 | 0 | 89 |
| Scalus UPLC→JVM JIT (Scala / JVM) (experimental) | 89 | 0 | 0 | 89 |
| blaze-plutus CEK (TypeScript / Node V8) (experimental) | 89 | 0 | 0 | 89 |
| Chrysalis CEK (C# / .NET JIT) (experimental) | 89 | 0 | 0 | 89 |
| Chrysalis CEK (C# / .NET AOT) (experimental) | 89 | 0 | 0 | 89 |
| Julc Java CEK (Java / JVM) (experimental) | 89 | 0 | 0 | 89 |
| Plutuz CEK (Zig) (experimental) | 89 | 0 | 0 | 89 |
| llvm-uplc UPLC→native JIT (C++ / LLVM) (experimental) | 89 | 0 | 0 | 89 |
| amaru-uplc bytecode VM, fork jonathanlim222/uplc (Rust) (experimental) | 89 | 0 | 0 | 89 |

## Per-Script Results

| Script | plutus-core CEK (Haskell / GHC) | plutus-core CEK (Haskell / GHC) (eval only) | Scalus CEK (Scala / JVM) | Scalus CEK (Scala / JVM) (eval only) | Scalus CEK (Scala.js / Node V8) | Scalus CEK (Scala.js / Node V8) (eval only) | Aiken uplc CEK (Rust) | Aiken uplc CEK (Rust) (eval only) | Aiken uplc CEK (Rust → WASM / Node V8) (eval only) | amaru-uplc AST walker (Rust) | amaru-uplc AST walker (Rust) (eval only) | Plutigo CEK (Go) | Plutigo CEK (Go) (eval only) | Scalus UPLC→JVM JIT (Scala / JVM) (experimental) (eval only) | blaze-plutus CEK (TypeScript / Node V8) (experimental) | blaze-plutus CEK (TypeScript / Node V8) (experimental) (eval only) | Chrysalis CEK (C# / .NET JIT) (experimental) | Chrysalis CEK (C# / .NET JIT) (experimental) (eval only) | Chrysalis CEK (C# / .NET AOT) (experimental) | Chrysalis CEK (C# / .NET AOT) (experimental) (eval only) | Julc Java CEK (Java / JVM) (experimental) | Julc Java CEK (Java / JVM) (experimental) (eval only) | Plutuz CEK (Zig) (experimental) | Plutuz CEK (Zig) (experimental) (eval only) | llvm-uplc UPLC→native JIT (C++ / LLVM) (experimental) (eval only) | amaru-uplc bytecode VM, fork jonathanlim222/uplc (Rust) (experimental) | amaru-uplc bytecode VM, fork jonathanlim222/uplc (Rust) (experimental) (eval only) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| auction_1-1 | 379.57 us | 132.39 us | **127.12 us** | 73.05 us | 696.91 us | 433.80 us | 2.99 ms | 1.92 ms | 363.91 us | 245.03 us | 184.97 us | 145.26 us | 90.84 us | 28.55 us | 600.51 us | 463.29 us | 246.77 us | 175.42 us | 265.14 us | 193.88 us | 233.77 us | 181.64 us | 264.67 us | 154.96 us | 43.48 us | 169.35 us | 102.04 us |
| auction_1-2 | 1.20 ms | 462.91 us | **423.48 us** | 273.84 us | 2.10 ms | 1.40 ms | 12.41 ms | 9.88 ms | 1.56 ms | 723.85 us | 586.92 us | 487.62 us | 352.46 us | 187.44 us | 1.94 ms | 1.61 ms | 913.07 us | 721.00 us | 1.01 ms | 805.77 us | 787.46 us | 645.08 us | 836.67 us | 556.30 us | 195.54 us | 528.80 us | 353.86 us |
| auction_1-3 | 1.20 ms | 449.67 us | **439.20 us** | 277.04 us | 2.16 ms | 1.42 ms | 12.72 ms | 9.67 ms | 1.55 ms | 726.57 us | 594.05 us | 484.68 us | 346.75 us | 168.16 us | 1.93 ms | 1.60 ms | 940.23 us | 726.80 us | 1.02 ms | 815.53 us | 779.77 us | 671.52 us | 807.60 us | 547.56 us | 195.49 us | 534.24 us | 356.54 us |
| auction_1-4 | 441.12 us | 169.04 us | **147.73 us** | 94.66 us | 826.43 us | 538.72 us | 3.46 ms | 2.41 ms | 463.91 us | 297.23 us | 234.53 us | 170.05 us | 117.37 us | 33.33 us | 721.16 us | 609.07 us | 304.57 us | 221.70 us | 322.74 us | 244.65 us | 309.08 us | 235.61 us | 309.69 us | 200.85 us | 58.48 us | 201.93 us | 133.71 us |
| auction_2-1 | 380.55 us | 134.26 us | **127.24 us** | 74.99 us | 689.62 us | 417.04 us | 3.04 ms | 1.97 ms | 360.01 us | 240.29 us | 178.83 us | 146.21 us | 89.98 us | 28.39 us | 579.91 us | 464.40 us | 248.09 us | 177.39 us | 269.95 us | 193.91 us | 234.37 us | 179.88 us | 264.51 us | 158.51 us | 46.35 us | 168.92 us | 103.82 us |
| auction_2-2 | 1.11 ms | 440.83 us | **445.95 us** | 271.07 us | 2.10 ms | 1.40 ms | 12.89 ms | 9.87 ms | 1.58 ms | 726.50 us | 590.82 us | 491.45 us | 356.06 us | 182.95 us | 2.00 ms | 1.58 ms | 979.99 us | 725.92 us | 1.02 ms | 813.23 us | 773.57 us | 646.65 us | 834.31 us | 558.99 us | 195.54 us | 533.05 us | 352.41 us |
| auction_2-3 | 1.29 ms | 560.08 us | **535.18 us** | 370.10 us | 2.52 ms | 1.83 ms | 15.19 ms | 12.69 ms | 2.12 ms | 898.06 us | 761.95 us | 602.21 us | 466.53 us | 231.54 us | 2.45 ms | 2.09 ms | 1.17 ms | 956.28 us | 1.28 ms | 1.07 ms | 943.59 us | 817.70 us | 998.09 us | 717.52 us | 253.45 us | 639.87 us | 467.81 us |
| auction_2-4 | 1.14 ms | 442.96 us | **432.02 us** | 272.06 us | 2.09 ms | 1.43 ms | 12.34 ms | 9.68 ms | 1.59 ms | 721.76 us | 590.41 us | 484.43 us | 349.12 us | 166.53 us | 2.01 ms | 1.56 ms | 949.63 us | 722.66 us | 1.02 ms | 806.49 us | 766.77 us | 643.96 us | 806.08 us | 538.63 us | 194.24 us | 536.12 us | 353.16 us |
| auction_2-5 | 432.18 us | 171.91 us | **150.78 us** | 94.48 us | 812.78 us | 535.05 us | 3.46 ms | 2.45 ms | 460.75 us | 297.85 us | 233.24 us | 172.29 us | 119.04 us | 33.08 us | 770.29 us | 623.55 us | 291.85 us | 219.62 us | 321.62 us | 246.38 us | 300.12 us | 233.54 us | 308.20 us | 199.26 us | 60.30 us | 202.15 us | 132.44 us |
| coop-1 | 337.75 us | 180.63 us | **143.21 us** | 109.68 us | 857.71 us | 710.52 us | 5.24 ms | 4.53 ms | 410.46 us | 261.30 us | 216.50 us | 154.68 us | 117.48 us | 34.97 us | 803.07 us | 669.36 us | 253.33 us | 205.12 us | 272.83 us | 223.34 us | 300.74 us | 232.42 us | 249.21 us | 184.95 us | 62.86 us | 172.70 us | 129.88 us |
| coop-2 | 966.48 us | 578.86 us | **457.44 us** | 363.16 us | 2.68 ms | 2.25 ms | 113.74 ms | 116.05 ms | 1.50 ms | 835.35 us | 730.23 us | 618.47 us | 403.80 us | 136.94 us | 2.60 ms | 2.29 ms | 797.61 us | 654.16 us | 854.19 us | 687.18 us | 888.48 us | 714.87 us | 725.47 us | 565.42 us | 211.26 us | 526.22 us | 408.93 us |
| coop-3 | 2.13 ms | 1.59 ms | **1.29 ms** | 1.20 ms | 8.14 ms | 7.58 ms | 145.81 ms | 151.17 ms | 5.58 ms | 1.80 ms | 1.70 ms | 1.53 ms | 1.42 ms | 536.29 us | 6.20 ms | 5.80 ms | 2.62 ms | 2.40 ms | 2.67 ms | 2.49 ms | 2.24 ms | 2.03 ms | 1.81 ms | 1.64 ms | 746.21 us | 1.46 ms | 1.34 ms |
| coop-4 | 1.19 ms | 722.03 us | **554.64 us** | 447.05 us | 3.36 ms | 3.06 ms | 117.22 ms | 118.17 ms | 2.03 ms | 886.40 us | 774.29 us | 656.34 us | 500.04 us | 208.19 us | 3.03 ms | 2.76 ms | 1.04 ms | 853.31 us | 1.08 ms | 911.88 us | 1.07 ms | 874.88 us | 850.92 us | 685.55 us | 281.27 us | 651.98 us | 516.50 us |
| coop-5 | 701.70 us | 314.21 us | **274.18 us** | 196.50 us | 1.54 ms | 1.20 ms | 27.93 ms | 27.22 ms | 852.16 us | 461.55 us | 355.12 us | 309.42 us | 200.42 us | 74.18 us | 1.42 ms | 1.14 ms | 505.39 us | 359.69 us | 535.66 us | 388.17 us | 530.41 us | 405.74 us | 463.99 us | 306.61 us | 115.67 us | 346.37 us | 225.91 us |
| coop-6 | 795.83 us | 534.53 us | **397.97 us** | 336.28 us | 2.44 ms | 2.09 ms | 155.90 ms | 160.65 ms | 1.25 ms | 759.55 us | 685.18 us | 542.11 us | 383.25 us | 126.77 us | 2.45 ms | 2.19 ms | 693.45 us | 591.28 us | 741.22 us | 652.08 us | 751.28 us | 657.33 us | 622.07 us | 538.36 us | 200.38 us | 461.40 us | 382.19 us |
| coop-7 | 445.71 us | 252.98 us | **201.59 us** | 158.84 us | 1.21 ms | 984.97 us | 6.37 ms | 5.56 ms | 636.39 us | 366.87 us | 314.10 us | 213.10 us | 158.01 us | 46.99 us | 1.10 ms | 1.01 ms | 350.59 us | 283.20 us | 363.26 us | 306.99 us | 411.00 us | 333.05 us | 334.00 us | 261.93 us | 89.84 us | 238.71 us | 182.58 us |
| crowdfunding-success-1 | 463.06 us | 154.77 us | **155.28 us** | 126.81 us | 805.32 us | 500.84 us | 3.48 ms | 2.23 ms | 480.17 us | 267.36 us | 200.61 us | 170.49 us | 104.82 us | 31.90 us | 677.84 us | 530.98 us | 287.26 us | 225.43 us | 312.40 us | 219.16 us | 264.63 us | 203.11 us | 301.52 us | 173.14 us | 53.43 us | 198.64 us | 119.99 us |
| crowdfunding-success-2 | 464.24 us | 155.43 us | **150.44 us** | 88.09 us | 812.42 us | 475.90 us | 3.51 ms | 2.19 ms | 470.07 us | 269.16 us | 199.12 us | 168.61 us | 103.16 us | 32.60 us | 677.36 us | 526.92 us | 287.49 us | 195.78 us | 313.99 us | 224.91 us | 272.75 us | 206.38 us | 300.78 us | 172.12 us | 52.54 us | 202.46 us | 119.11 us |
| crowdfunding-success-3 | 461.71 us | 154.61 us | **153.70 us** | 86.19 us | 801.45 us | 476.81 us | 3.51 ms | 2.27 ms | 481.46 us | 269.50 us | 195.91 us | 169.49 us | 103.67 us | 31.90 us | 683.86 us | 525.60 us | 287.14 us | 198.76 us | 315.87 us | 215.41 us | 269.74 us | 207.09 us | 300.59 us | 173.42 us | 54.26 us | 201.25 us | 119.15 us |
| currency-1 | 472.32 us | 174.77 us | **167.25 us** | 109.22 us | 894.25 us | 585.66 us | 4.44 ms | 3.23 ms | 596.77 us | 296.59 us | 230.16 us | 197.16 us | 135.46 us | 55.34 us | 742.16 us | 612.64 us | 366.41 us | 276.16 us | 396.30 us | 318.25 us | 302.23 us | 246.74 us | 335.68 us | 208.44 us | 69.99 us | 223.96 us | 142.06 us |
| escrow-redeem_1-1 | 678.63 us | 243.65 us | **241.22 us** | 149.59 us | 1.23 ms | 794.53 us | 6.06 ms | 4.38 ms | 790.09 us | 411.02 us | 314.38 us | 267.34 us | 181.78 us | 69.41 us | 1.04 ms | 819.64 us | 495.86 us | 366.86 us | 530.14 us | 405.10 us | 408.67 us | 314.84 us | 454.86 us | 286.59 us | 100.72 us | 311.01 us | 196.79 us |
| escrow-redeem_1-2 | 664.21 us | 242.89 us | **244.54 us** | 150.80 us | 1.24 ms | 795.92 us | 6.03 ms | 4.40 ms | 793.26 us | 404.89 us | 318.08 us | 279.72 us | 183.63 us | 68.39 us | 1.02 ms | 820.40 us | 485.21 us | 363.92 us | 534.51 us | 405.07 us | 430.10 us | 337.87 us | 452.54 us | 283.86 us | 95.06 us | 305.63 us | 197.36 us |
| escrow-redeem_2-1 | 695.66 us | 285.32 us | **264.98 us** | 176.66 us | 1.36 ms | 937.79 us | 6.83 ms | 5.33 ms | 977.06 us | 459.63 us | 371.53 us | 301.97 us | 211.76 us | 82.65 us | 1.18 ms | 953.51 us | 553.86 us | 418.47 us | 621.10 us | 480.86 us | 472.21 us | 380.36 us | 504.93 us | 331.34 us | 112.03 us | 340.30 us | 243.02 us |
| escrow-redeem_2-2 | 700.85 us | 287.25 us | **266.52 us** | 179.88 us | 1.36 ms | 967.28 us | 6.80 ms | 5.14 ms | 1.00 ms | 456.79 us | 365.65 us | 307.56 us | 210.97 us | 81.59 us | 1.18 ms | 996.53 us | 551.47 us | 422.12 us | 608.10 us | 478.67 us | 462.82 us | 380.28 us | 503.00 us | 333.18 us | 110.67 us | 355.60 us | 237.32 us |
| escrow-redeem_2-3 | 701.24 us | 285.38 us | **263.91 us** | 179.16 us | 1.36 ms | 917.90 us | 6.66 ms | 5.05 ms | 999.73 us | 462.00 us | 370.96 us | 303.93 us | 218.34 us | 82.76 us | 1.18 ms | 996.87 us | 543.98 us | 414.14 us | 596.58 us | 467.81 us | 460.92 us | 380.40 us | 500.97 us | 330.74 us | 114.71 us | 338.61 us | 227.34 us |
| escrow-refund-1 | 491.95 us | 120.23 us | **139.09 us** | 64.45 us | 768.39 us | 353.52 us | 3.44 ms | 1.80 ms | 368.97 us | 233.23 us | 145.20 us | 162.37 us | 77.92 us | 24.92 us | 569.91 us | 392.33 us | 263.07 us | 146.30 us | 272.09 us | 162.28 us | 232.97 us | 161.88 us | 294.12 us | 128.48 us | 42.08 us | 192.68 us | 87.22 us |
| future-increase-margin-1 | 474.77 us | 171.38 us | **174.73 us** | 109.24 us | 943.54 us | 588.04 us | 4.42 ms | 3.23 ms | 606.85 us | 300.49 us | 228.42 us | 200.03 us | 135.79 us | 56.18 us | 751.12 us | 603.33 us | 365.91 us | 279.83 us | 389.27 us | 303.44 us | 310.19 us | 247.50 us | 338.45 us | 208.80 us | 71.30 us | 224.89 us | 141.25 us |
| future-increase-margin-2 | 821.76 us | 376.94 us | **337.29 us** | 231.49 us | 1.66 ms | 1.20 ms | 8.94 ms | 7.32 ms | 1.28 ms | 581.37 us | 488.02 us | 382.10 us | 290.44 us | 111.94 us | 1.44 ms | 1.27 ms | 706.56 us | 573.19 us | 766.01 us | 643.09 us | 597.55 us | 508.68 us | 610.90 us | 433.44 us | 156.91 us | 420.69 us | 298.59 us |
| future-increase-margin-3 | 801.56 us | 376.43 us | **335.88 us** | 243.20 us | 1.67 ms | 1.21 ms | 8.83 ms | 7.22 ms | 1.28 ms | 581.42 us | 491.98 us | 379.45 us | 291.75 us | 113.92 us | 1.44 ms | 1.31 ms | 698.48 us | 574.31 us | 763.94 us | 628.72 us | 594.69 us | 502.07 us | 613.27 us | 433.92 us | 150.90 us | 416.05 us | 299.92 us |
| future-increase-margin-4 | 1.11 ms | 337.56 us | **370.76 us** | 204.50 us | 1.90 ms | 1.04 ms | 10.82 ms | 7.57 ms | 1.22 ms | 634.70 us | 472.62 us | 441.48 us | 281.07 us | 162.21 us | 1.65 ms | 1.23 ms | 799.79 us | 539.96 us | 859.69 us | 620.51 us | 672.40 us | 541.26 us | 788.04 us | 461.95 us | 153.73 us | 481.71 us | 274.50 us |
| future-increase-margin-5 | 1.39 ms | 555.62 us | **579.73 us** | 390.51 us | 3.97 ms | 3.11 ms | 16.17 ms | 13.37 ms | 2.16 ms | 970.49 us | 790.47 us | 607.73 us | 442.23 us | 316.01 us | 3.89 ms | 3.52 ms | 1.29 ms | 1.01 ms | 1.36 ms | 1.09 ms | 1.04 ms | 897.57 us | 1.24 ms | 906.93 us | 296.52 us | 725.19 us | 497.63 us |
| future-pay-out-1 | 478.00 us | 173.49 us | **170.57 us** | 110.15 us | 890.86 us | 575.44 us | 4.43 ms | 3.21 ms | 622.61 us | 299.94 us | 230.61 us | 198.43 us | 136.38 us | 54.78 us | 736.23 us | 596.62 us | 370.42 us | 280.77 us | 393.05 us | 307.51 us | 306.58 us | 248.99 us | 338.86 us | 212.44 us | 69.24 us | 224.12 us | 141.40 us |
| future-pay-out-2 | 809.11 us | 384.34 us | **329.15 us** | 230.30 us | 1.72 ms | 1.21 ms | 8.93 ms | 7.34 ms | 1.30 ms | 579.80 us | 490.45 us | 381.34 us | 289.72 us | 112.07 us | 1.48 ms | 1.32 ms | 713.41 us | 574.89 us | 769.16 us | 641.14 us | 594.75 us | 517.15 us | 613.00 us | 435.77 us | 158.92 us | 432.88 us | 304.47 us |
| future-pay-out-3 | 811.78 us | 377.49 us | **337.45 us** | 248.11 us | 1.68 ms | 1.20 ms | 8.75 ms | 7.02 ms | 1.27 ms | 580.32 us | 486.89 us | 375.45 us | 282.59 us | 113.02 us | 1.48 ms | 1.30 ms | 713.71 us | 583.28 us | 777.07 us | 645.85 us | 591.43 us | 506.04 us | 608.86 us | 434.44 us | 157.53 us | 421.48 us | 303.42 us |
| future-pay-out-4 | 1.40 ms | 564.64 us | **597.65 us** | 390.01 us | 4.04 ms | 3.13 ms | 16.02 ms | 12.91 ms | 2.13 ms | 960.28 us | 788.50 us | 621.03 us | 432.58 us | 317.07 us | 3.97 ms | 3.46 ms | 1.27 ms | 1.01 ms | 1.35 ms | 1.08 ms | 1.04 ms | 899.19 us | 1.23 ms | 914.50 us | 288.21 us | 693.81 us | 477.14 us |
| future-settle-early-1 | 476.32 us | 173.88 us | **170.39 us** | 109.38 us | 923.67 us | 590.76 us | 4.41 ms | 3.26 ms | 620.20 us | 298.81 us | 228.12 us | 200.96 us | 135.79 us | 54.96 us | 729.52 us | 611.37 us | 365.61 us | 276.70 us | 381.80 us | 304.14 us | 310.17 us | 248.17 us | 335.97 us | 209.85 us | 70.22 us | 221.48 us | 140.00 us |
| future-settle-early-2 | 802.90 us | 374.56 us | **332.58 us** | 246.66 us | 1.67 ms | 1.19 ms | 8.69 ms | 7.14 ms | 1.27 ms | 581.37 us | 490.17 us | 375.59 us | 284.30 us | 113.00 us | 1.47 ms | 1.27 ms | 713.16 us | 568.44 us | 778.48 us | 645.95 us | 590.26 us | 492.96 us | 619.40 us | 449.98 us | 158.92 us | 419.25 us | 299.75 us |
| future-settle-early-3 | 801.46 us | 379.96 us | **320.62 us** | 224.23 us | 1.69 ms | 1.21 ms | 8.75 ms | 7.34 ms | 1.29 ms | 581.97 us | 494.90 us | 380.98 us | 281.85 us | 113.92 us | 1.43 ms | 1.28 ms | 696.79 us | 558.85 us | 779.21 us | 640.75 us | 588.07 us | 499.65 us | 613.11 us | 441.24 us | 157.10 us | 425.92 us | 306.43 us |
| future-settle-early-4 | 1.26 ms | 446.55 us | 499.36 us | 306.68 us | 3.59 ms | 2.66 ms | 12.81 ms | 9.29 ms | 1.63 ms | 750.05 us | 595.11 us | **478.70 us** | 318.68 us | 253.47 us | 3.35 ms | 2.90 ms | 1.03 ms | 742.61 us | 1.07 ms | 804.38 us | 824.94 us | 691.39 us | 1.00 ms | 661.89 us | 226.93 us | 571.49 us | 364.61 us |
| game-sm-success_1-1 | 895.10 us | 283.21 us | **305.28 us** | 162.62 us | 1.51 ms | 861.15 us | 7.90 ms | 5.14 ms | 950.77 us | 497.98 us | 368.93 us | 344.21 us | 206.82 us | 105.24 us | 1.28 ms | 1.00 ms | 589.05 us | 405.55 us | 659.09 us | 456.43 us | 528.44 us | 409.65 us | 623.92 us | 353.75 us | 112.08 us | 396.83 us | 219.15 us |
| game-sm-success_1-2 | 371.72 us | 144.14 us | **130.20 us** | 83.03 us | 717.59 us | 451.17 us | 3.21 ms | 2.32 ms | 393.12 us | 252.57 us | 202.81 us | 147.46 us | 99.31 us | 30.55 us | 650.62 us | 528.45 us | 255.62 us | 189.77 us | 280.20 us | 214.63 us | 239.31 us | 202.19 us | 265.77 us | 173.34 us | 49.77 us | 171.91 us | 114.11 us |
| game-sm-success_1-3 | 1.12 ms | 455.26 us | **441.70 us** | 274.49 us | 2.11 ms | 1.38 ms | 11.56 ms | 9.05 ms | 1.58 ms | 719.21 us | 585.78 us | 489.46 us | 347.45 us | 175.69 us | 1.92 ms | 1.58 ms | 893.97 us | 704.52 us | 1.00 ms | 783.50 us | 762.42 us | 639.51 us | 815.05 us | 551.34 us | 194.14 us | 526.76 us | 355.86 us |
| game-sm-success_1-4 | 395.69 us | 167.76 us | **146.86 us** | 98.16 us | 819.95 us | 546.85 us | 3.52 ms | 2.66 ms | 458.69 us | 291.93 us | 233.85 us | 163.19 us | 116.25 us | 35.23 us | 719.48 us | 600.55 us | 290.27 us | 226.38 us | 311.98 us | 251.68 us | 276.38 us | 229.66 us | 298.96 us | 198.42 us | 58.76 us | 190.75 us | 132.80 us |
| game-sm-success_2-1 | 866.73 us | 273.33 us | **301.56 us** | 164.63 us | 1.49 ms | 854.41 us | 7.72 ms | 5.08 ms | 931.03 us | 492.74 us | 367.66 us | 344.17 us | 209.00 us | 101.21 us | 1.27 ms | 925.12 us | 594.38 us | 413.18 us | 659.28 us | 459.86 us | 533.87 us | 403.98 us | 617.94 us | 347.10 us | 112.42 us | 386.22 us | 217.36 us |
| game-sm-success_2-2 | 369.93 us | 148.84 us | **130.78 us** | 82.24 us | 716.83 us | 468.65 us | 3.17 ms | 2.29 ms | 388.98 us | 252.28 us | 198.33 us | 147.41 us | 101.97 us | 29.85 us | 601.78 us | 516.34 us | 251.23 us | 188.23 us | 269.15 us | 204.66 us | 239.02 us | 202.50 us | 266.50 us | 172.24 us | 49.20 us | 172.36 us | 114.04 us |
| game-sm-success_2-3 | 1.09 ms | 431.53 us | **426.21 us** | 264.98 us | 2.10 ms | 1.41 ms | 11.73 ms | 8.99 ms | 1.54 ms | 718.03 us | 583.52 us | 502.04 us | 349.23 us | 172.08 us | 1.93 ms | 1.61 ms | 900.61 us | 718.35 us | 1.01 ms | 793.93 us | 765.33 us | 627.22 us | 814.91 us | 551.66 us | 195.89 us | 530.47 us | 360.29 us |
| game-sm-success_2-4 | 395.71 us | 166.87 us | **146.71 us** | 96.08 us | 798.39 us | 556.35 us | 3.68 ms | 2.65 ms | 484.38 us | 289.94 us | 233.19 us | 164.81 us | 115.67 us | 34.21 us | 728.27 us | 617.58 us | 286.76 us | 233.57 us | 306.88 us | 244.94 us | 278.79 us | 228.69 us | 293.17 us | 197.66 us | 59.35 us | 194.87 us | 134.24 us |
| game-sm-success_2-5 | 1.12 ms | 433.64 us | **434.55 us** | 273.85 us | 2.09 ms | 1.39 ms | 12.05 ms | 9.47 ms | 1.63 ms | 714.20 us | 581.61 us | 486.96 us | 351.19 us | 171.39 us | 1.95 ms | 1.57 ms | 917.02 us | 720.69 us | 1.00 ms | 797.85 us | 767.87 us | 636.09 us | 814.69 us | 552.88 us | 192.65 us | 527.69 us | 353.58 us |
| game-sm-success_2-6 | 390.77 us | 168.62 us | **147.20 us** | 95.55 us | 785.78 us | 542.58 us | 3.49 ms | 2.70 ms | 455.78 us | 287.87 us | 229.49 us | 164.79 us | 117.02 us | 34.61 us | 715.78 us | 603.46 us | 294.69 us | 223.19 us | 309.57 us | 247.93 us | 282.26 us | 227.48 us | 291.11 us | 196.74 us | 59.36 us | 194.09 us | 134.28 us |
| guardrail-sorted-large | 569.18 us | 316.72 us | **296.08 us** | 222.74 us | 1.81 ms | 1.49 ms | 15.72 ms | 14.91 ms | 927.02 us | 479.05 us | 354.54 us | 748.18 us | 243.96 us | 186.93 us | 1.52 ms | 1.21 ms | 531.40 us | 431.69 us | 608.51 us | 502.17 us | 739.08 us | 433.75 us | 423.11 us | 319.15 us | 240.58 us | 402.45 us | 275.93 us |
| guardrail-sorted-small | 181.71 us | 50.85 us | 71.73 us | 43.10 us | 431.44 us | 338.91 us | 2.90 ms | 2.41 ms | 171.44 us | 93.27 us | 49.87 us | **68.15 us** | 36.26 us | 71.82 us | 285.69 us | 215.64 us | 118.87 us | 66.08 us | 130.10 us | 77.23 us | 111.79 us | 84.29 us | 119.60 us | 55.06 us | 17.77 us | 94.73 us | 44.93 us |
| guardrail-unsorted-large | 693.39 us | 440.94 us | **397.17 us** | 320.71 us | 2.45 ms | 2.09 ms | 190.77 ms | 197.49 ms | 1.35 ms | 604.77 us | 478.39 us | 794.54 us | 360.87 us | 249.99 us | 2.03 ms | 1.72 ms | 707.29 us | 606.82 us | 818.51 us | 709.67 us | 839.32 us | 575.18 us | 553.46 us | 454.79 us | 299.81 us | 502.71 us | 378.48 us |
| guardrail-unsorted-small | 172.90 us | 49.53 us | 74.19 us | 42.30 us | 430.55 us | 320.98 us | 4.00 ms | 3.54 ms | 157.38 us | 92.25 us | 47.75 us | **66.10 us** | 35.31 us | 70.22 us | 277.79 us | 210.02 us | 114.40 us | 63.22 us | 126.28 us | 75.21 us | 112.91 us | 83.81 us | 117.62 us | 54.14 us | 16.80 us | 94.39 us | 44.07 us |
| multisig-sm-01 | 970.57 us | 274.20 us | **305.28 us** | 159.09 us | 1.59 ms | 904.36 us | 8.64 ms | 5.75 ms | 1.01 ms | 519.34 us | 388.90 us | 361.42 us | 222.06 us | 110.95 us | 1.35 ms | 1.01 ms | 665.25 us | 442.95 us | 705.71 us | 488.46 us | 554.92 us | 428.20 us | 654.69 us | 362.24 us | 117.43 us | 400.99 us | 222.84 us |
| multisig-sm-02 | 949.39 us | 271.57 us | **310.56 us** | 163.10 us | 1.57 ms | 879.16 us | 8.55 ms | 5.79 ms | 995.61 us | 513.38 us | 373.31 us | 361.05 us | 217.42 us | 116.34 us | 1.35 ms | 986.73 us | 614.35 us | 425.11 us | 682.30 us | 471.68 us | 553.51 us | 430.36 us | 648.37 us | 354.09 us | 115.66 us | 402.33 us | 219.75 us |
| multisig-sm-03 | 955.56 us | 267.59 us | **310.62 us** | 159.90 us | 1.56 ms | 836.27 us | 8.43 ms | 5.61 ms | 937.59 us | 526.10 us | 377.78 us | 372.32 us | 223.34 us | 118.90 us | 1.37 ms | 1.10 ms | 631.35 us | 425.49 us | 681.51 us | 472.10 us | 550.66 us | 425.25 us | 644.59 us | 364.87 us | 116.33 us | 398.25 us | 219.64 us |
| multisig-sm-04 | 976.01 us | 274.95 us | **304.26 us** | 165.64 us | 1.61 ms | 857.81 us | 8.75 ms | 5.82 ms | 977.68 us | 522.89 us | 379.70 us | 363.89 us | 222.44 us | 121.07 us | 1.34 ms | 1.04 ms | 650.99 us | 422.08 us | 704.77 us | 482.05 us | 561.12 us | 427.14 us | 661.71 us | 363.26 us | 118.27 us | 407.57 us | 220.69 us |
| multisig-sm-05 | 1.11 ms | 387.55 us | **403.84 us** | 231.95 us | 1.95 ms | 1.22 ms | 11.50 ms | 8.88 ms | 1.40 ms | 673.29 us | 532.86 us | 454.25 us | 307.47 us | 164.74 us | 1.78 ms | 1.42 ms | 839.84 us | 630.62 us | 954.57 us | 706.56 us | 731.03 us | 598.95 us | 797.13 us | 505.15 us | 171.10 us | 497.66 us | 314.43 us |
| multisig-sm-06 | 976.51 us | 274.13 us | **321.09 us** | 169.53 us | 1.58 ms | 852.76 us | 8.77 ms | 5.87 ms | 984.20 us | 521.39 us | 382.83 us | 369.99 us | 223.85 us | 114.88 us | 1.32 ms | 1.02 ms | 640.02 us | 435.22 us | 694.96 us | 483.80 us | 563.60 us | 438.39 us | 666.39 us | 362.99 us | 118.42 us | 406.07 us | 224.45 us |
| multisig-sm-07 | 958.27 us | 270.46 us | **319.13 us** | 162.12 us | 1.58 ms | 848.31 us | 8.44 ms | 5.73 ms | 977.41 us | 670.38 us | 506.15 us | 360.19 us | 211.87 us | 115.82 us | 1.36 ms | 1.01 ms | 623.56 us | 415.20 us | 683.48 us | 471.92 us | 560.51 us | 416.15 us | 651.76 us | 360.97 us | 116.21 us | 402.44 us | 217.44 us |
| multisig-sm-08 | 961.95 us | 269.52 us | **308.62 us** | 157.16 us | 1.56 ms | 846.24 us | 8.56 ms | 5.65 ms | 945.58 us | 521.52 us | 378.34 us | 365.22 us | 217.84 us | 113.16 us | 1.36 ms | 1.04 ms | 621.63 us | 422.51 us | 682.07 us | 475.77 us | 553.48 us | 425.66 us | 646.48 us | 357.75 us | 115.92 us | 403.43 us | 219.12 us |
| multisig-sm-09 | 964.52 us | 279.74 us | **304.84 us** | 160.06 us | 1.57 ms | 880.63 us | 8.65 ms | 5.72 ms | 967.58 us | 526.34 us | 382.45 us | 376.25 us | 222.31 us | 116.78 us | 1.34 ms | 1.02 ms | 629.77 us | 425.50 us | 713.11 us | 488.02 us | 555.88 us | 434.59 us | 658.65 us | 363.06 us | 116.63 us | 403.93 us | 222.15 us |
| multisig-sm-10 | 1.11 ms | 370.65 us | **403.63 us** | 239.43 us | 1.94 ms | 1.23 ms | 11.68 ms | 8.92 ms | 1.38 ms | 688.25 us | 531.50 us | 457.73 us | 308.16 us | 165.02 us | 1.78 ms | 1.48 ms | 841.74 us | 624.19 us | 946.25 us | 716.22 us | 733.92 us | 598.98 us | 794.35 us | 509.71 us | 170.20 us | 496.89 us | 317.50 us |
| ping-pong-1 | 829.56 us | 229.07 us | **261.54 us** | 136.58 us | 1.31 ms | 724.95 us | 7.31 ms | 4.93 ms | 791.97 us | 434.32 us | 314.12 us | 298.74 us | 174.07 us | 80.99 us | 1.10 ms | 843.34 us | 516.93 us | 343.11 us | 575.44 us | 388.41 us | 446.89 us | 344.28 us | 548.33 us | 299.78 us | 94.59 us | 341.49 us | 184.78 us |
| ping-pong-2 | 827.70 us | 230.94 us | **259.75 us** | 136.74 us | 1.33 ms | 732.43 us | 7.35 ms | 4.89 ms | 780.14 us | 432.02 us | 307.01 us | 302.13 us | 175.15 us | 81.90 us | 1.10 ms | 816.97 us | 520.79 us | 349.91 us | 571.34 us | 393.53 us | 451.51 us | 344.36 us | 547.93 us | 300.98 us | 96.02 us | 340.26 us | 182.27 us |
| ping-pong_2-1 | 729.85 us | 149.96 us | **202.97 us** | 86.66 us | 1.04 ms | 456.46 us | 5.27 ms | 2.74 ms | 492.84 us | 313.13 us | 190.10 us | 225.39 us | 104.03 us | 44.20 us | 782.86 us | 498.39 us | 369.47 us | 200.35 us | 405.89 us | 229.63 us | 326.96 us | 221.25 us | 418.61 us | 172.87 us | 55.29 us | 267.01 us | 112.79 us |
| prism-1 | 332.58 us | 119.75 us | **114.96 us** | 71.87 us | 629.08 us | 395.52 us | 2.70 ms | 1.87 ms | 323.58 us | 216.04 us | 164.27 us | 127.74 us | 84.73 us | 24.54 us | 531.62 us | 441.12 us | 217.57 us | 155.91 us | 239.71 us | 178.46 us | 200.73 us | 163.04 us | 230.78 us | 145.17 us | 40.85 us | 148.37 us | 95.09 us |
| prism-2 | 920.01 us | 289.23 us | **306.01 us** | 178.66 us | 1.56 ms | 925.14 us | 8.56 ms | 6.06 ms | 1.00 ms | 521.33 us | 396.67 us | 366.03 us | 220.45 us | 102.98 us | 1.37 ms | 1.06 ms | 612.35 us | 424.64 us | 686.75 us | 507.41 us | 559.73 us | 431.07 us | 646.37 us | 381.07 us | 120.06 us | 401.11 us | 232.30 us |
| prism-3 | 574.58 us | 258.82 us | **233.23 us** | 161.87 us | 1.19 ms | 850.60 us | 6.26 ms | 5.03 ms | 884.73 us | 437.28 us | 362.04 us | 266.46 us | 196.00 us | 74.33 us | 1.12 ms | 979.53 us | 490.88 us | 396.21 us | 543.19 us | 442.16 us | 436.99 us | 371.41 us | 455.89 us | 325.72 us | 100.49 us | 298.68 us | 209.63 us |
| pubkey-1 | 313.27 us | 101.41 us | **104.32 us** | 60.61 us | 560.63 us | 333.36 us | 2.38 ms | 1.48 ms | 287.80 us | 186.86 us | 134.58 us | 115.48 us | 70.98 us | 20.75 us | 460.52 us | 366.04 us | 189.82 us | 130.28 us | 208.77 us | 144.65 us | 175.41 us | 135.69 us | 207.98 us | 117.46 us | 35.69 us | 134.33 us | 80.47 us |
| stablecoin_1-1 | 1.55 ms | 677.48 us | 749.35 us | 476.45 us | 5.90 ms | 4.80 ms | 18.90 ms | 14.77 ms | 2.50 ms | 1.21 ms | 983.33 us | **685.60 us** | 479.65 us | 958.48 us | 6.02 ms | 5.50 ms | 1.49 ms | 1.18 ms | 1.60 ms | 1.25 ms | 1.35 ms | 1.17 ms | 1.50 ms | 1.07 ms | 340.14 us | 856.43 us | 575.80 us |
| stablecoin_1-2 | 372.37 us | 145.02 us | **126.83 us** | 83.36 us | 703.10 us | 453.99 us | 3.18 ms | 2.33 ms | 378.47 us | 253.37 us | 198.61 us | 145.32 us | 98.16 us | 29.05 us | 610.91 us | 515.78 us | 246.91 us | 184.51 us | 266.29 us | 202.43 us | 240.02 us | 187.29 us | 259.88 us | 167.32 us | 49.37 us | 172.15 us | 112.98 us |
| stablecoin_1-3 | 1.86 ms | 765.60 us | 796.36 us | 503.49 us | 6.16 ms | 5.03 ms | 21.30 ms | 17.33 ms | 2.61 ms | 1.36 ms | 1.16 ms | **764.85 us** | 561.74 us | 1.03 ms | 6.82 ms | 5.99 ms | 1.65 ms | 1.36 ms | 1.83 ms | 1.47 ms | 1.54 ms | 1.35 ms | 1.65 ms | 1.25 ms | 366.16 us | 920.36 us | 669.47 us |
| stablecoin_1-4 | 381.24 us | 161.84 us | **133.05 us** | 85.52 us | 752.01 us | 484.87 us | 3.26 ms | 2.37 ms | 404.87 us | 267.64 us | 210.38 us | 152.10 us | 106.04 us | 32.10 us | 637.18 us | 532.74 us | 258.18 us | 191.76 us | 284.30 us | 221.04 us | 249.87 us | 205.20 us | 275.45 us | 178.14 us | 51.72 us | 181.55 us | 120.54 us |
| stablecoin_1-5 | 2.08 ms | 993.32 us | 938.91 us | 674.33 us | 6.81 ms | 5.81 ms | 25.29 ms | 21.36 ms | 3.22 ms | 1.76 ms | 1.51 ms | **922.38 us** | 738.30 us | 1.21 ms | 7.79 ms | 7.16 ms | 2.06 ms | 1.74 ms | 2.26 ms | 1.88 ms | 1.96 ms | 1.76 ms | 2.05 ms | 1.60 ms | 422.74 us | 1.09 ms | 838.79 us |
| stablecoin_1-6 | 423.27 us | 186.68 us | **155.23 us** | 105.62 us | 868.26 us | 594.54 us | 3.85 ms | 2.91 ms | 496.95 us | 316.90 us | 259.41 us | 178.28 us | 128.89 us | 38.15 us | 820.70 us | 694.17 us | 303.75 us | 245.37 us | 338.62 us | 271.66 us | 312.06 us | 249.16 us | 311.25 us | 216.86 us | 66.99 us | 212.39 us | 148.84 us |
| stablecoin_2-1 | 1.56 ms | 679.84 us | 749.25 us | 448.69 us | 5.92 ms | 5.16 ms | 18.24 ms | 14.53 ms | 2.32 ms | 1.23 ms | 998.11 us | **680.05 us** | 468.63 us | 1.39 ms | 5.98 ms | 5.50 ms | 1.46 ms | 1.15 ms | 1.62 ms | 1.26 ms | 1.33 ms | 1.16 ms | 1.49 ms | 1.07 ms | 337.48 us | 829.03 us | 585.70 us |
| stablecoin_2-2 | 371.60 us | 140.41 us | **126.54 us** | 81.72 us | 704.56 us | 455.69 us | 3.10 ms | 2.28 ms | 390.60 us | 257.75 us | 199.52 us | 145.31 us | 98.33 us | 30.12 us | 611.15 us | 506.08 us | 244.87 us | 183.72 us | 274.69 us | 208.69 us | 242.58 us | 189.95 us | 262.88 us | 170.40 us | 49.59 us | 171.71 us | 113.07 us |
| stablecoin_2-3 | 1.86 ms | 768.59 us | 790.52 us | 525.60 us | 6.12 ms | 5.02 ms | 21.72 ms | 17.70 ms | 2.62 ms | 1.36 ms | 1.15 ms | **763.76 us** | 566.16 us | 1.08 ms | 6.63 ms | 6.03 ms | 1.64 ms | 1.36 ms | 1.85 ms | 1.49 ms | 1.54 ms | 1.35 ms | 1.68 ms | 1.27 ms | 371.18 us | 924.83 us | 657.26 us |
| stablecoin_2-4 | 385.77 us | 154.80 us | **132.62 us** | 85.71 us | 742.52 us | 479.03 us | 3.28 ms | 2.40 ms | 402.91 us | 269.04 us | 216.40 us | 150.91 us | 105.39 us | 31.65 us | 653.62 us | 541.78 us | 259.50 us | 194.05 us | 293.76 us | 220.90 us | 251.05 us | 210.09 us | 272.68 us | 177.42 us | 52.62 us | 183.20 us | 122.16 us |
| token-account-1 | 433.42 us | 138.85 us | **142.33 us** | 80.22 us | 750.87 us | 444.82 us | 3.79 ms | 2.57 ms | 471.12 us | 248.88 us | 180.07 us | 163.60 us | 99.44 us | 39.56 us | 617.87 us | 465.94 us | 282.17 us | 199.26 us | 309.81 us | 228.15 us | 245.25 us | 189.99 us | 290.06 us | 162.11 us | 48.55 us | 185.65 us | 106.84 us |
| token-account-2 | 535.59 us | 238.83 us | **205.65 us** | 146.81 us | 1.10 ms | 792.75 us | 4.60 ms | 3.50 ms | 791.36 us | 363.45 us | 300.66 us | 241.78 us | 179.06 us | 66.62 us | 973.07 us | 809.96 us | 426.77 us | 346.59 us | 493.49 us | 404.51 us | 363.19 us | 288.96 us | 390.45 us | 270.64 us | 94.68 us | 265.78 us | 190.08 us |
| uniswap-1 | 589.20 us | 283.27 us | **249.65 us** | 193.99 us | 1.30 ms | 964.71 us | 6.15 ms | 4.96 ms | 1.05 ms | 426.01 us | 357.43 us | 297.79 us | 229.24 us | 96.79 us | 1.10 ms | 970.35 us | 551.05 us | 451.98 us | 635.69 us | 530.44 us | 431.54 us | 378.49 us | 462.81 us | 330.39 us | 119.95 us | 313.58 us | 229.61 us |
| uniswap-2 | 463.86 us | 162.83 us | **159.65 us** | 94.53 us | 831.21 us | 516.38 us | 4.19 ms | 3.02 ms | 528.37 us | 291.22 us | 219.01 us | 181.71 us | 117.07 us | 42.09 us | 715.38 us | 558.94 us | 317.18 us | 230.63 us | 349.10 us | 261.29 us | 292.73 us | 226.65 us | 321.29 us | 196.43 us | 58.15 us | 209.80 us | 127.27 us |
| uniswap-3 | 2.19 ms | 1.22 ms | **1.02 ms** | 768.50 us | 5.16 ms | 4.12 ms | 24.58 ms | 21.31 ms | 3.87 ms | 1.72 ms | 1.53 ms | 1.16 ms | 985.22 us | 443.49 us | 5.34 ms | 4.58 ms | 2.11 ms | 1.85 ms | 2.43 ms | 2.11 ms | 1.78 ms | 1.63 ms | 1.88 ms | 1.53 ms | 445.76 us | 1.20 ms | 968.28 us |
| uniswap-4 | 504.06 us | 238.44 us | **198.20 us** | 143.88 us | 1.07 ms | 772.78 us | 4.52 ms | 3.60 ms | 647.55 us | 406.95 us | 347.51 us | 227.81 us | 169.95 us | 47.87 us | 1.03 ms | 887.02 us | 394.73 us | 321.00 us | 440.39 us | 359.92 us | 399.25 us | 336.30 us | 390.94 us | 292.43 us | 87.10 us | 263.12 us | 195.01 us |
| uniswap-5 | 1.72 ms | 795.62 us | **707.63 us** | 490.49 us | 3.84 ms | 2.74 ms | 16.32 ms | 13.49 ms | 2.47 ms | 1.19 ms | 1.00 ms | 817.57 us | 627.12 us | 268.85 us | 3.64 ms | 3.04 ms | 1.42 ms | 1.16 ms | 1.60 ms | 1.32 ms | 1.25 ms | 1.09 ms | 1.29 ms | 940.24 us | 300.10 us | 867.34 us | 634.71 us |
| uniswap-6 | 485.73 us | 234.11 us | **197.35 us** | 137.57 us | 1.07 ms | 742.29 us | 4.47 ms | 3.50 ms | 628.76 us | 393.27 us | 328.90 us | 218.93 us | 162.87 us | 48.70 us | 968.58 us | 838.25 us | 385.78 us | 315.47 us | 424.69 us | 344.20 us | 382.39 us | 308.18 us | 376.29 us | 275.05 us | 81.51 us | 253.29 us | 184.36 us |
| vesting-1 | 653.56 us | 241.31 us | **233.88 us** | 151.72 us | 1.27 ms | 797.56 us | 5.85 ms | 4.23 ms | 881.60 us | 397.86 us | 312.66 us | 271.61 us | 183.38 us | 80.05 us | 1.02 ms | 842.74 us | 487.11 us | 366.54 us | 536.20 us | 414.89 us | 413.80 us | 331.00 us | 456.67 us | 283.41 us | 100.70 us | 303.09 us | 195.46 us |

## VMs in this benchmark

| VM | Language | Runtime | Execution model | Version | Source | Home | Used by | Badges | Note |
|---|---|---|---|---|---|---|---|---|---|
| Scalus CEK (Scala / JVM) | Scala | GraalVM | Interpreter (CEK) | [v1.4.1](https://github.com/scalus3/scalus/releases/tag/v1.4.1) | [scalus3/scalus](https://github.com/scalus3/scalus) | [scalus.org](https://scalus.org) | [Hydrozoa](https://github.com/cardano-hydrozoa/hydrozoa) (L2), [Bifrost](https://github.com/FluidTokens/ft-bifrost-bridge) (bridge), [Cardano Client Lib](https://github.com/bloxbean/cardano-client-lib) (SDK), [Yaci Store](https://github.com/bloxbean/yaci-store) (indexer), [Yaci DevKit](https://github.com/bloxbean/yaci-devkit) (dev tool) | - | - |
| Plutigo CEK (Go) | Go | native | Interpreter (CEK) | [v0.1.10](https://github.com/blinklabs-io/plutigo/releases/tag/v0.1.10) | [blinklabs-io/plutigo](https://github.com/blinklabs-io/plutigo) | - | [Dingo](https://github.com/blinklabs-io/dingo) (node) | - | - |
| amaru-uplc AST walker (Rust) | Rust | native | Interpreter (AST walker) | [amaru-uplc-v0.4.0](https://github.com/pragma-org/uplc/releases/tag/amaru-uplc-v0.4.0) | [pragma-org/uplc](https://github.com/pragma-org/uplc) | - | [Amaru](https://github.com/pragma-org/amaru) (node) | - | - |
| plutus-core CEK (Haskell / GHC) | Haskell | GHC | Interpreter (CEK) | [1.70.0.0](https://github.com/IntersectMBO/plutus/releases/tag/1.70.0.0) | [IntersectMBO/plutus](https://github.com/IntersectMBO/plutus) | [plutus.cardano.intersectmbo.org](https://plutus.cardano.intersectmbo.org) | [cardano-node](https://github.com/IntersectMBO/cardano-node) (node) | - | - |
| Scalus CEK (Scala.js / Node V8) | Scala.js | Node (V8) | Interpreter (CEK) | [scalus 1.4.1 (npm)](https://github.com/scalus3/scalus/releases/tag/v1.4.1) | [scalus3/scalus](https://github.com/scalus3/scalus) | [scalus.org](https://scalus.org) | [Lucid Evolution](https://github.com/Anastasia-Labs/lucid-evolution) (SDK), [MeshJS](https://github.com/MeshJS/mesh) (SDK), [Evolution SDK](https://github.com/IntersectMBO/evolution-sdk) (SDK) | - | - |
| Aiken uplc CEK (Rust) | Rust | native | Interpreter (CEK) | [v1.1.24](https://github.com/aiken-lang/aiken/releases/tag/v1.1.24) | [aiken-lang/aiken](https://github.com/aiken-lang/aiken) | [aiken-lang.org](https://aiken-lang.org) | [Aiken](https://aiken-lang.org) (compiler), [Blaze SDK](https://github.com/butaneprotocol/blaze-cardano) (SDK) | - | Aiken v1.1.24 copies the CEK environment on every lambda application (quadratic in recursion depth). aiken main fixes it (PRs [#1451](https://github.com/aiken-lang/aiken/pull/1451), [#1452](https://github.com/aiken-lang/aiken/pull/1452): coop-6 92 ms -> 1.2 ms), but no release contains the fix yet. |
| Aiken uplc CEK (Rust → WASM / Node V8) | Rust → WASM | Node (V8) | Interpreter (CEK) | [@lucid-evolution/uplc 0.4.0](https://github.com/Anastasia-Labs/lucid-evolution/releases/tag/@lucid-evolution/uplc@0.4.0) | [Anastasia-Labs/lucid-evolution](https://github.com/Anastasia-Labs/lucid-evolution) | [anastasia-labs.github.io/lucid-evolution](https://anastasia-labs.github.io/lucid-evolution/) | [Lucid Evolution](https://github.com/Anastasia-Labs/lucid-evolution) (SDK) | decode cached (by the library) | Built from [colll78/aiken](https://github.com/colll78/aiken) (aiken main plus fixes), which includes the CEK fixes that v1.1.24 lacks. |
| Scalus UPLC→JVM JIT (Scala / JVM) | Scala | GraalVM | JIT compiler (UPLC → JVM bytecode) | [v1.4.1](https://github.com/scalus3/scalus/releases/tag/v1.4.1) | [scalus3/scalus](https://github.com/scalus3/scalus) | [scalus.org](https://scalus.org) | - | experimental: no downstream user, decode and compile excluded | - |
| blaze-plutus CEK (TypeScript / Node V8) | TypeScript | Node (V8) | Interpreter (CEK) | [@blaze-cardano/plutus 0.1.1](https://github.com/butaneprotocol/blaze-cardano/releases/tag/@blaze-cardano/plutus@0.1.1) | [butaneprotocol/blaze-cardano](https://github.com/butaneprotocol/blaze-cardano) | [blaze.butane.dev](https://blaze.butane.dev) | - | experimental: no downstream user | - |
| Chrysalis CEK (C# / .NET JIT) | C# | .NET 10 (JIT) | Interpreter (CEK) | [Chrysalis.Plutus 1.7.14-alpha (NuGet)](https://www.nuget.org/packages/Chrysalis.Plutus/1.7.14-alpha) | [SAIB-Inc/Chrysalis](https://github.com/SAIB-Inc/Chrysalis) | - | - | experimental: pre-release only | - |
| Chrysalis CEK (C# / .NET AOT) | C# | .NET 10 (NativeAOT) | Interpreter (CEK) | [Chrysalis.Plutus 1.7.14-alpha (NuGet)](https://www.nuget.org/packages/Chrysalis.Plutus/1.7.14-alpha) | [SAIB-Inc/Chrysalis](https://github.com/SAIB-Inc/Chrysalis) | - | - | experimental: pre-release only | - |
| Julc Java CEK (Java / JVM) | Java | GraalVM | Interpreter (CEK) | [v0.1.0-pre19](https://github.com/bloxbean/julc/releases/tag/v0.1.0-pre19) | [bloxbean/julc](https://github.com/bloxbean/julc) | - | - | experimental: pre-release only | - |
| Plutuz CEK (Zig) | Zig | native | Interpreter (CEK) | [main 33b812d](https://github.com/utxo-company/plutuz/commit/33b812d) | [utxo-company/plutuz](https://github.com/utxo-company/plutuz) | - | - | experimental: no release | - |
| llvm-uplc UPLC→native JIT (C++ / LLVM) | C / C++ | native (LLVM 22 LLJIT) | JIT compiler (UPLC → native code) | [main 6bcef67](https://github.com/SeungheonOh/llvm-uplc/commit/6bcef67) | [SeungheonOh/llvm-uplc](https://github.com/SeungheonOh/llvm-uplc) | - | - | outdated cost model, experimental: outdated, decode and compile excluded | - |
| amaru-uplc bytecode VM, fork jonathanlim222/uplc (Rust) | Rust | native | Bytecode VM (UPLC → bytecode) | [fork 069cef5](https://github.com/jonathanlim222/uplc/commit/069cef5) | [jonathanlim222/uplc](https://github.com/jonathanlim222/uplc) | - | - | experimental: no release | - |

---
Harness commit: [`256b6aafc`](https://github.com/lantr-io/plutus-vm-benchmark/commit/256b6aafce0f44faa876a9b24ed586c11bc385d3)

*Plutus VM Benchmark – maintained by [Lantr](https://lantr.io) – Alexander Nemish. Forked from [SAIB-Inc/cardano-plutus-vm-benchmark](https://github.com/SAIB-Inc/cardano-plutus-vm-benchmark) by SAIB Inc. and contributors. MIT License, original work © 2025 SAIB Inc., © 2026 Lantr. Source: [lantr-io/plutus-vm-benchmark](https://github.com/lantr-io/plutus-vm-benchmark)*