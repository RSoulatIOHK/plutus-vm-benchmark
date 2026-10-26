# Plutus VM Benchmark Results

**Date:** 2026-10-23

## Environment
```
date: 2026-10-23T10:28:22+00:00
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
load avg at start: 0.28 0.09 0.03
docker: 29.9.1 (linux/amd64)
docker cpus: 16
docker memory: 62786 MiB
docker run flags: --rm --cap-add SYS_NICE --network none
lanes: 3 (lane0 2,3,4,5; lane1 6,7,8,9; lane2 10,11,12,13; idle cores 14,15)
parallel: yes (up to 3 VMs at once; haskell and the drift probe run alone on lane0)
harness: 0529b3ac142270732bbd1849860f2a4322dd6d9a
vm order: haskell aiken aiken-wasm blaze-v8 plutigo scalus-cek scalus-jit scalus-js uplc-turbo
bench_quick: 0
bench_scripts: <all> (89 of 89 scripts)
bench_loops: d3,eval,check
bench_timing: normal
bench_trace: 0
host cpus: 0,1,14,15
server qualification: pass, ratio 1.073, attempt 1 of 3, nbg1; rejected: none; haskell geo ratio 1.073 <= 1.15 vs ccx43 reference (harness b0d8a22, 2026-10-22): auction_1-1 1.02, coop-6 1.10, uniswap-1 1.10
image haskell: ghcr.io/lantr-io/pvb-haskell:7b78360d2cdd ghcr.io/lantr-io/pvb-haskell@sha256:f1239cfa64f02a5b33434ef1277660fe3d47a2e83a078403c017e7f26ce33610
noise haskell: load avg before 1.70 0.57 0.20, steal during run 0.00 % (0 of 1473674 ticks) lane0
image aiken: ghcr.io/lantr-io/pvb-aiken:553af555815c ghcr.io/lantr-io/pvb-aiken@sha256:b1328c3825f56f452b1f7de6b156b45729d56979ab8afb122e9223fad02a5660
image aiken-wasm: ghcr.io/lantr-io/pvb-aiken-wasm:0438949b9439 ghcr.io/lantr-io/pvb-aiken-wasm@sha256:e799dbcfb01ae2ae7a583388d1c32e5654c8a4bcae0411f1a1024325d481ca0a
image blaze-v8: ghcr.io/lantr-io/pvb-blaze-v8:98c2ab4a64bc ghcr.io/lantr-io/pvb-blaze-v8@sha256:083fc21b0e42c4e9b526b9feebf83d14909519b141adbe2132ea9b819fb8046c
noise aiken: load avg before 1.00 1.00 0.74, steal during run 0.00 % (0 of 2988027 ticks) lane0
image plutigo: ghcr.io/lantr-io/pvb-plutigo:0135f9baacb4 ghcr.io/lantr-io/pvb-plutigo@sha256:aefe3292c5e2fde945273a5dee7e71f006cfcef45cf8aaf65e3b92f87ef00e0d
noise aiken-wasm: load avg before 1.00 1.00 0.74, steal during run 0.00 % (0 of 3015448 ticks) lane1
image scalus-cek: ghcr.io/lantr-io/pvb-scalus-cek:e0632b1f04b6 ghcr.io/lantr-io/pvb-scalus-cek@sha256:423ebf22eb8446258c86d5518f2ef9e9791304395674677c3c2734b7b32fe2a4
noise plutigo: load avg before 3.22 3.19 2.91, steal during run 0.00 % (0 of 1707344 ticks) lane0
image scalus-jit: ghcr.io/lantr-io/pvb-scalus-jit:277188e34d2f ghcr.io/lantr-io/pvb-scalus-jit@sha256:ebe43dda94aa7a2e93ae75d805715d83065b1e5dcc9fe7fbe59865e6ec5c43ba
noise blaze-v8: load avg before 1.16 1.03 0.75, steal during run 0.00 % (0 of 6831090 ticks) lane2
image scalus-js: ghcr.io/lantr-io/pvb-scalus-js:c98417becc85 ghcr.io/lantr-io/pvb-scalus-js@sha256:91aa00c16b40070fb0efa11861249e518f4470920806962f99cbdb35f539e6b8
noise scalus-js: load avg before 3.28 3.45 3.40, steal during run 0.00 % (0 of 4817430 ticks) lane2
image uplc-turbo: ghcr.io/lantr-io/pvb-uplc-turbo:4f5f499a7ef9 ghcr.io/lantr-io/pvb-uplc-turbo@sha256:494e43756cca00c1160f0eefdf9836e12bb092dfbe9a714cecbd2c073246882d
noise scalus-jit: load avg before 3.20 3.18 3.08, steal during run 0.00 % (0 of 9002651 ticks) lane0
noise uplc-turbo: load avg before 4.04 3.85 3.78, steal during run 0.00 % (0 of 3025942 ticks) lane2
noise scalus-cek: load avg before 3.16 3.18 2.91, steal during run 0.00 % (0 of 13356070 ticks) lane1
steal during the whole run: 0.00 % (0 of 17975466 ticks)
load avg at end: 1.10 1.17 1.66
drift (haskell, end vs start): +0.6 % over 5 scripts
```

*The 89 scripts are PlutusV1-era programs. Every VM evaluates them as PlutusV3 programs at protocol version 11 with the mainnet cost model, like Plutus's own `validation` CEK benchmark; the node would run them as PlutusV1.*

*Drift (Haskell, end vs start): +0.6 % over 5 scripts. The run timed Haskell again at its end; this is the change of its time.*

## Summary (geometric mean across all scripts)

*Note: VMs that fail or skip a script are assigned the slowest competitor's time for that script.*
*A compiling VM's timed loop runs the compiled script ("decode and compile excluded": the decode and the compile run once per script, before timing). So it has only an eval-only time: its Geo Mean (decode + eval) is "–" and it is not ranked. The Compile column is the geometric mean of the compile time over the scripts.*
*Geo Mean: flat decode + evaluation (the ranking). Eval only: evaluation of a program decoded before the timed loop, geometric mean over its scripts.*
*Aiken WASM caches decoded programs inside the library, so its time is shown as eval only. It is not in the decode + eval ranking; it is ranked on eval only (Geo Mean "–").*
*Aiken uplc CEK (Rust → WASM / Node V8), "decode cached (by the library)": The library caches the decoded program by a hash of the flat bytes. After the first call (in the warm-up), the timed loop runs hash + evaluation, without the decode. Its eval-only time is the same loop.*

| VM | Language | Geo Mean | vs Fastest | Eval only | Compile | Check |
|---|---|---|---|---|---|---|
| **Plutigo CEK (Go)** | Go | 283.97 us | 1.00x | 182.63 us | - | pass |
| **Scalus CEK (Scala / JVM)** | Scala / JVM | 399.88 us | 1.41x | 291.39 us | - | pass |
| **uplc-turbo AST walker (Rust)** | Rust | 468.58 us | 1.65x | 367.94 us | - | pass |
| **plutus-core CEK (Haskell / GHC)** | Haskell / GHC | 702.57 us | 2.47x | 271.69 us | - | pass |
| **Scalus CEK (Scala.js / Node V8)** | Scala.js / Node V8 | 3.51 ms | 12.37x | - | - | pass |
| **Aiken uplc CEK (Rust)** | Rust | 8.18 ms | 28.81x | 6.17 ms | - | pass |
| **Aiken uplc CEK (Rust → WASM / Node V8)** (decode cached (by the library)) | Rust → WASM / Node V8 | – | eval only | 901.44 us | - | pass |

### Experimental

Run, gated and shown, but not ranked: not in the table above, not a competitor in the penalty rule. Geo Mean uses the penalty rule against the ranked VMs. Geo Mean "–" (compiled once before timing, see the compile column): the VM has only an eval-only time.

| VM | Language | Geo Mean | Eval only | Compile | Check | Reason |
|---|---|---|---|---|---|---|
| **Scalus UPLC→JVM JIT (Scala / JVM)** | Scala / JVM | – | 123.96 us | 1.74 s (decode and compile excluded) | pass | not ranked: the JIT module is published (Maven, since Scalus 1.4.1) but has no downstream users yet (spec D17) |
| **blaze-plutus CEK (TypeScript / Node V8)** | TypeScript / Node V8 | 1.73 ms | 1.33 ms | - | pass | not ranked: no released project outside the Blaze repo depends on @blaze-cardano/plutus yet; Blaze itself evaluates scripts with @blaze-cardano/vm (Aiken uplc as WASM) (spec D17) |

### Notes

- **Aiken uplc CEK (Rust)**: Aiken v1.1.24 copies the CEK environment on every lambda application (quadratic in recursion depth). aiken main fixes it (PRs [#1451](https://github.com/aiken-lang/aiken/pull/1451), [#1452](https://github.com/aiken-lang/aiken/pull/1452): coop-6 92 ms -> 1.2 ms), but no release contains the fix yet.
- **Aiken uplc CEK (Rust → WASM / Node V8)**: Built from [colll78/aiken](https://github.com/colll78/aiken) (aiken main plus fixes), which includes the CEK fixes that v1.1.24 lacks.

### History (speed relative to Haskell plutus-core, same run; higher is faster)

| VM | 2026-10-23 | Change vs previous run |
|---|---|---|
| plutus-core CEK (Haskell / GHC) | 1x (Haskell) | reference |
| Scalus UPLC→JVM JIT (Scala / JVM) (experimental, eval only) | 2.2x faster | - |
| Scalus CEK (Scala / JVM) | 1.8x faster | - |
| Scalus CEK (Scala.js / Node V8) | 5.0x slower | - |
| Aiken uplc CEK (Rust) | 11.6x slower | - |
| Aiken uplc CEK (Rust → WASM / Node V8) (eval only) | 3.3x slower | - |
| uplc-turbo AST walker (Rust) | 1.5x faster | - |
| Plutigo CEK (Go) | 2.5x faster | - |
| blaze-plutus CEK (TypeScript / Node V8) (experimental) | 2.5x slower | - |

A VM marked "eval only" has no decode + eval time (it compiles each script before timing, or its library caches the decode): its ratio is its eval-only time divided by Haskell's eval-only time.

Servers of the same type differ: ratios to Haskell move up to about 5 % between two runs on different servers, so a change under 5 % is shown as no change.

### Script Coverage

| VM | Passed | Failed | Missing | Total |
|---|---|---|---|---|
| Plutigo CEK (Go) | 89 | 0 | 0 | 89 |
| Scalus CEK (Scala / JVM) | 89 | 0 | 0 | 89 |
| uplc-turbo AST walker (Rust) | 89 | 0 | 0 | 89 |
| plutus-core CEK (Haskell / GHC) | 89 | 0 | 0 | 89 |
| Scalus CEK (Scala.js / Node V8) | 89 | 0 | 0 | 89 |
| Aiken uplc CEK (Rust) | 89 | 0 | 0 | 89 |
| Aiken uplc CEK (Rust → WASM / Node V8) | 89 | 0 | 0 | 89 |
| Scalus UPLC→JVM JIT (Scala / JVM) (experimental) | 89 | 0 | 0 | 89 |
| blaze-plutus CEK (TypeScript / Node V8) (experimental) | 89 | 0 | 0 | 89 |

## Per-Script Results

| Script | plutus-core CEK (Haskell / GHC) | plutus-core CEK (Haskell / GHC) (eval only) | Scalus CEK (Scala / JVM) | Scalus CEK (Scala / JVM) (eval only) | Scalus CEK (Scala.js / Node V8) | Aiken uplc CEK (Rust) | Aiken uplc CEK (Rust) (eval only) | Aiken uplc CEK (Rust → WASM / Node V8) (eval only) | uplc-turbo AST walker (Rust) | uplc-turbo AST walker (Rust) (eval only) | Plutigo CEK (Go) | Plutigo CEK (Go) (eval only) | Scalus UPLC→JVM JIT (Scala / JVM) (experimental) (eval only) | blaze-plutus CEK (TypeScript / Node V8) (experimental) | blaze-plutus CEK (TypeScript / Node V8) (experimental) (eval only) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| auction_1-1 | 374.44 us | 130.46 us | 177.45 us | 125.81 us | 1.38 ms | 3.02 ms | 1.91 ms | 365.53 us | 241.18 us | 181.63 us | **130.90 us** | 78.38 us | 37.91 us | 703.79 us | 560.70 us |
| auction_1-2 | 1.08 ms | 422.51 us | 687.46 us | 511.84 us | 6.13 ms | 12.45 ms | 9.87 ms | 1.52 ms | 727.48 us | 595.40 us | **461.85 us** | 325.38 us | 255.41 us | 2.45 ms | 1.82 ms |
| auction_1-3 | 1.11 ms | 430.43 us | 689.33 us | 506.36 us | 7.42 ms | 12.22 ms | 9.68 ms | 1.55 ms | 727.92 us | 596.28 us | **456.91 us** | 317.44 us | 233.76 us | 2.46 ms | 1.82 ms |
| auction_1-4 | 428.60 us | 167.67 us | 219.36 us | 153.43 us | 1.81 ms | 3.53 ms | 2.46 ms | 496.25 us | 296.15 us | 235.09 us | **153.62 us** | 96.97 us | 45.52 us | 891.64 us | 743.17 us |
| auction_2-1 | 376.97 us | 129.93 us | 180.88 us | 126.64 us | 1.37 ms | 2.96 ms | 1.92 ms | 374.72 us | 238.30 us | 180.98 us | **131.95 us** | 76.81 us | 38.39 us | 707.09 us | 560.44 us |
| auction_2-2 | 1.09 ms | 423.09 us | 690.32 us | 506.92 us | 7.40 ms | 13.33 ms | 10.95 ms | 1.58 ms | 723.64 us | 593.45 us | **463.81 us** | 322.85 us | 249.20 us | 2.46 ms | 1.80 ms |
| auction_2-3 | 1.24 ms | 543.83 us | 840.98 us | 675.96 us | 9.35 ms | 15.40 ms | 12.91 ms | 2.10 ms | 899.05 us | 766.46 us | **561.39 us** | 429.59 us | 299.91 us | 4.29 ms | 2.31 ms |
| auction_2-4 | 1.12 ms | 432.52 us | 668.72 us | 505.35 us | 6.17 ms | 12.40 ms | 9.69 ms | 1.55 ms | 728.72 us | 603.08 us | **452.38 us** | 316.56 us | 237.89 us | 2.45 ms | 1.81 ms |
| auction_2-5 | 428.71 us | 166.94 us | 215.00 us | 156.43 us | 1.70 ms | 3.52 ms | 2.49 ms | 513.08 us | 298.08 us | 232.66 us | **152.61 us** | 98.28 us | 45.66 us | 875.24 us | 745.85 us |
| coop-1 | 330.80 us | 174.37 us | 213.84 us | 169.28 us | 1.63 ms | 5.30 ms | 4.59 ms | 420.62 us | 257.12 us | 215.33 us | **147.31 us** | 109.42 us | 42.38 us | 966.58 us | 846.74 us |
| coop-2 | 964.33 us | 570.62 us | 708.83 us | 561.47 us | 6.38 ms | 113.86 ms | 116.95 ms | 1.50 ms | 842.72 us | 727.67 us | **562.86 us** | 389.92 us | 164.72 us | 4.11 ms | 2.80 ms |
| coop-3 | 2.10 ms | 1.56 ms | 2.15 ms | 2.02 ms | 19.06 ms | 146.14 ms | 148.49 ms | 5.88 ms | 1.86 ms | 1.76 ms | **1.45 ms** | 1.37 ms | 617.44 us | 9.38 ms | 7.12 ms |
| coop-4 | 1.16 ms | 690.90 us | 863.16 us | 733.12 us | 7.65 ms | 115.91 ms | 117.86 ms | 2.05 ms | 884.18 us | 774.23 us | **627.92 us** | 477.34 us | 246.12 us | 5.09 ms | 3.24 ms |
| coop-5 | 678.32 us | 306.00 us | 414.19 us | 293.76 us | 3.17 ms | 25.58 ms | 24.57 ms | 860.32 us | 460.08 us | 359.59 us | **303.08 us** | 189.88 us | 89.98 us | 1.73 ms | 1.42 ms |
| coop-6 | 782.20 us | 524.97 us | 599.28 us | 519.55 us | 4.92 ms | 155.64 ms | 161.18 ms | 1.29 ms | 759.40 us | 685.80 us | **507.65 us** | 363.24 us | 145.48 us | 3.23 ms | 2.65 ms |
| coop-7 | 447.11 us | 252.10 us | 291.57 us | 254.94 us | 2.36 ms | 6.42 ms | 5.57 ms | 648.77 us | 366.12 us | 316.49 us | **202.73 us** | 146.05 us | 57.67 us | 1.36 ms | 1.20 ms |
| crowdfunding-success-1 | 465.61 us | 155.02 us | 212.78 us | 137.29 us | 1.70 ms | 3.53 ms | 2.22 ms | 464.98 us | 269.35 us | 200.20 us | **153.51 us** | 88.46 us | 43.27 us | 798.02 us | 637.60 us |
| crowdfunding-success-2 | 464.54 us | 155.36 us | 208.68 us | 137.03 us | 1.65 ms | 3.48 ms | 2.27 ms | 467.50 us | 268.65 us | 198.58 us | **153.63 us** | 86.82 us | 45.77 us | 806.54 us | 650.08 us |
| crowdfunding-success-3 | 460.92 us | 155.12 us | 210.60 us | 138.58 us | 1.76 ms | 3.41 ms | 2.30 ms | 471.09 us | 268.54 us | 195.68 us | **153.87 us** | 86.63 us | 44.96 us | 793.43 us | 633.22 us |
| currency-1 | 471.60 us | 172.81 us | 255.55 us | 186.50 us | 2.11 ms | 4.28 ms | 3.21 ms | 629.77 us | 298.28 us | 234.49 us | **186.24 us** | 123.28 us | 71.92 us | 889.89 us | 718.12 us |
| escrow-redeem_1-1 | 663.36 us | 244.65 us | 371.02 us | 256.01 us | 2.73 ms | 6.01 ms | 4.41 ms | 853.07 us | 411.65 us | 327.12 us | **249.49 us** | 159.42 us | 92.89 us | 1.30 ms | 1.03 ms |
| escrow-redeem_1-2 | 657.42 us | 245.74 us | 363.91 us | 247.63 us | 2.77 ms | 6.05 ms | 4.43 ms | 794.56 us | 413.94 us | 325.20 us | **248.62 us** | 160.38 us | 92.93 us | 1.28 ms | 1.02 ms |
| escrow-redeem_2-1 | 702.83 us | 283.77 us | 398.16 us | 304.16 us | 3.35 ms | 6.83 ms | 5.28 ms | 1.09 ms | 462.30 us | 373.56 us | **277.56 us** | 190.66 us | 109.50 us | 1.44 ms | 1.18 ms |
| escrow-redeem_2-2 | 696.49 us | 285.83 us | 400.08 us | 311.49 us | 3.30 ms | 6.80 ms | 5.22 ms | 995.16 us | 459.79 us | 375.49 us | **279.83 us** | 191.60 us | 108.49 us | 1.44 ms | 1.16 ms |
| escrow-redeem_2-3 | 703.54 us | 284.93 us | 400.05 us | 306.20 us | 3.24 ms | 6.79 ms | 5.11 ms | 987.37 us | 462.84 us | 369.41 us | **277.06 us** | 189.04 us | 108.34 us | 1.45 ms | 1.18 ms |
| escrow-refund-1 | 504.08 us | 114.45 us | 193.55 us | 105.68 us | 1.39 ms | 3.40 ms | 1.75 ms | 398.86 us | 233.43 us | 145.38 us | **156.99 us** | 67.33 us | 36.32 us | 664.83 us | 482.61 us |
| future-increase-margin-1 | 475.11 us | 171.66 us | 251.32 us | 185.43 us | 2.20 ms | 4.50 ms | 3.28 ms | 625.14 us | 298.50 us | 228.44 us | **187.12 us** | 120.98 us | 71.64 us | 898.08 us | 723.31 us |
| future-increase-margin-2 | 801.92 us | 374.98 us | 496.76 us | 394.39 us | 4.17 ms | 8.67 ms | 7.25 ms | 1.31 ms | 587.47 us | 499.82 us | **350.78 us** | 259.57 us | 145.13 us | 1.85 ms | 1.63 ms |
| future-increase-margin-3 | 802.86 us | 377.46 us | 505.71 us | 400.12 us | 4.17 ms | 8.72 ms | 7.03 ms | 1.30 ms | 580.84 us | 488.39 us | **351.45 us** | 255.88 us | 147.83 us | 1.87 ms | 1.54 ms |
| future-increase-margin-4 | 1.13 ms | 328.69 us | 571.56 us | 391.32 us | 5.35 ms | 10.69 ms | 7.51 ms | 1.33 ms | 640.65 us | 477.10 us | **413.87 us** | 256.34 us | 219.87 us | 1.86 ms | 1.47 ms |
| future-increase-margin-5 | 1.42 ms | 554.82 us | 884.81 us | 691.34 us | 12.76 ms | 15.65 ms | 12.81 ms | 2.12 ms | 965.20 us | 796.27 us | **565.63 us** | 405.96 us | 411.19 us | 5.18 ms | 3.75 ms |
| future-pay-out-1 | 475.81 us | 172.26 us | 256.32 us | 184.69 us | 2.18 ms | 4.47 ms | 3.22 ms | 632.13 us | 296.77 us | 228.29 us | **185.35 us** | 121.95 us | 72.32 us | 895.61 us | 731.37 us |
| future-pay-out-2 | 804.21 us | 378.44 us | 521.58 us | 400.61 us | 4.21 ms | 8.71 ms | 7.03 ms | 1.31 ms | 589.13 us | 493.41 us | **348.07 us** | 256.63 us | 151.41 us | 1.91 ms | 1.61 ms |
| future-pay-out-3 | 808.20 us | 378.12 us | 507.72 us | 393.96 us | 4.37 ms | 8.73 ms | 7.09 ms | 1.30 ms | 582.25 us | 494.54 us | **347.50 us** | 255.09 us | 145.90 us | 1.86 ms | 1.55 ms |
| future-pay-out-4 | 1.40 ms | 550.78 us | 918.79 us | 680.17 us | 11.63 ms | 15.67 ms | 12.42 ms | 2.25 ms | 967.06 us | 801.26 us | **563.50 us** | 415.14 us | 403.49 us | 5.94 ms | 3.92 ms |
| future-settle-early-1 | 475.52 us | 170.47 us | 254.09 us | 189.22 us | 2.09 ms | 4.42 ms | 3.15 ms | 619.46 us | 296.58 us | 227.47 us | **184.47 us** | 119.91 us | 70.99 us | 899.39 us | 730.73 us |
| future-settle-early-2 | 804.07 us | 376.68 us | 508.14 us | 412.07 us | 4.25 ms | 8.87 ms | 7.18 ms | 1.30 ms | 580.08 us | 492.35 us | **346.00 us** | 257.35 us | 148.63 us | 1.88 ms | 1.57 ms |
| future-settle-early-3 | 804.77 us | 377.81 us | 530.02 us | 401.66 us | 4.89 ms | 8.87 ms | 7.28 ms | 1.28 ms | 581.55 us | 489.93 us | **347.40 us** | 266.17 us | 147.30 us | 1.88 ms | 1.52 ms |
| future-settle-early-4 | 1.25 ms | 422.88 us | 715.98 us | 522.59 us | 9.75 ms | 11.87 ms | 8.99 ms | 1.67 ms | 756.38 us | 599.70 us | **475.24 us** | 288.30 us | 330.21 us | 5.03 ms | 3.11 ms |
| game-sm-success_1-1 | 905.67 us | 277.59 us | 438.03 us | 305.69 us | 3.26 ms | 7.70 ms | 5.10 ms | 951.41 us | 499.84 us | 369.35 us | **330.49 us** | 187.54 us | 155.61 us | 1.61 ms | 1.17 ms |
| game-sm-success_1-2 | 362.69 us | 140.36 us | 190.42 us | 143.35 us | 1.48 ms | 3.21 ms | 2.27 ms | 404.91 us | 253.35 us | 199.59 us | **131.49 us** | 84.65 us | 38.89 us | 726.67 us | 624.93 us |
| game-sm-success_1-3 | 1.08 ms | 429.92 us | 656.76 us | 529.96 us | 6.20 ms | 12.16 ms | 9.11 ms | 1.54 ms | 724.75 us | 586.72 us | **456.43 us** | 316.65 us | 235.57 us | 2.75 ms | 1.99 ms |
| game-sm-success_1-4 | 392.02 us | 167.34 us | 212.47 us | 162.58 us | 1.83 ms | 3.60 ms | 2.69 ms | 449.51 us | 288.37 us | 236.76 us | **146.28 us** | 97.84 us | 45.32 us | 930.36 us | 781.77 us |
| game-sm-success_2-1 | 878.82 us | 270.19 us | 443.10 us | 303.46 us | 3.85 ms | 7.73 ms | 5.19 ms | 948.80 us | 496.75 us | 372.45 us | **319.74 us** | 188.60 us | 153.06 us | 1.82 ms | 1.25 ms |
| game-sm-success_2-2 | 361.98 us | 142.53 us | 194.03 us | 137.26 us | 1.48 ms | 3.03 ms | 2.24 ms | 381.58 us | 253.24 us | 199.79 us | **132.07 us** | 85.84 us | 38.98 us | 808.95 us | 681.06 us |
| game-sm-success_2-3 | 1.09 ms | 432.10 us | 664.32 us | 493.62 us | 6.87 ms | 11.58 ms | 8.94 ms | 1.61 ms | 720.34 us | 586.10 us | **464.12 us** | 327.41 us | 235.97 us | 2.96 ms | 2.07 ms |
| game-sm-success_2-4 | 392.63 us | 165.47 us | 212.37 us | 157.50 us | 1.57 ms | 3.56 ms | 2.59 ms | 456.19 us | 288.42 us | 234.87 us | **145.75 us** | 100.92 us | 44.29 us | 998.05 us | 805.90 us |
| game-sm-success_2-5 | 1.09 ms | 427.46 us | 656.36 us | 515.28 us | 6.38 ms | 11.60 ms | 9.14 ms | 1.56 ms | 719.53 us | 589.19 us | **453.73 us** | 319.64 us | 235.10 us | 3.05 ms | 2.20 ms |
| game-sm-success_2-6 | 391.05 us | 165.31 us | 215.24 us | 162.93 us | 1.62 ms | 3.55 ms | 2.63 ms | 473.10 us | 287.77 us | 233.12 us | **148.89 us** | 102.52 us | 43.64 us | 988.07 us | 824.77 us |
| guardrail-sorted-large | 559.81 us | 310.65 us | **415.43 us** | 344.58 us | 3.90 ms | 15.72 ms | 14.99 ms | 961.54 us | 479.40 us | 357.80 us | 762.74 us | 219.66 us | 209.56 us | 2.20 ms | 1.82 ms |
| guardrail-sorted-small | 177.42 us | 50.07 us | 88.26 us | 54.96 us | 794.81 us | 2.91 ms | 2.41 ms | 174.72 us | 93.11 us | 49.60 us | **69.59 us** | 36.89 us | 74.59 us | 402.77 us | 311.56 us |
| guardrail-unsorted-large | 683.71 us | 435.46 us | **570.82 us** | 495.77 us | 5.57 ms | 189.11 ms | 194.07 ms | 1.39 ms | 599.74 us | 478.67 us | 772.42 us | 309.95 us | 272.63 us | 2.84 ms | 2.62 ms |
| guardrail-unsorted-small | 170.28 us | 48.77 us | 85.97 us | 52.02 us | 803.24 us | 3.96 ms | 3.49 ms | 167.54 us | 91.72 us | 47.79 us | **67.45 us** | 35.20 us | 73.61 us | 389.33 us | 293.84 us |
| multisig-sm-01 | 961.61 us | 270.27 us | 473.46 us | 323.53 us | 4.07 ms | 8.77 ms | 5.88 ms | 1.06 ms | 524.20 us | 383.13 us | **346.30 us** | 202.16 us | 171.21 us | 2.00 ms | 1.32 ms |
| multisig-sm-02 | 943.38 us | 265.25 us | 467.04 us | 315.87 us | 3.93 ms | 8.43 ms | 5.59 ms | 983.42 us | 513.89 us | 379.17 us | **340.40 us** | 192.42 us | 177.65 us | 1.87 ms | 1.27 ms |
| multisig-sm-03 | 940.95 us | 267.01 us | 460.34 us | 321.92 us | 4.12 ms | 8.54 ms | 5.63 ms | 947.99 us | 522.24 us | 379.42 us | **345.67 us** | 195.61 us | 180.65 us | 1.87 ms | 1.35 ms |
| multisig-sm-04 | 957.71 us | 271.82 us | 456.65 us | 318.76 us | 4.05 ms | 8.52 ms | 5.66 ms | 954.72 us | 525.06 us | 387.48 us | **346.73 us** | 197.79 us | 178.54 us | 1.94 ms | 1.27 ms |
| multisig-sm-05 | 1.10 ms | 372.16 us | 624.30 us | 460.70 us | 6.53 ms | 11.59 ms | 8.68 ms | 1.42 ms | 680.29 us | 536.17 us | **426.86 us** | 282.70 us | 237.43 us | 2.50 ms | 1.96 ms |
| multisig-sm-06 | 974.63 us | 272.86 us | 470.95 us | 312.81 us | 4.45 ms | 8.74 ms | 5.72 ms | 1.04 ms | 526.20 us | 383.99 us | **344.00 us** | 197.88 us | 173.79 us | 1.92 ms | 1.28 ms |
| multisig-sm-07 | 947.76 us | 265.55 us | 450.63 us | 300.11 us | 3.71 ms | 8.51 ms | 5.48 ms | 991.83 us | 513.21 us | 375.52 us | **344.01 us** | 198.00 us | 177.48 us | 1.84 ms | 1.36 ms |
| multisig-sm-08 | 952.24 us | 269.29 us | 456.22 us | 318.53 us | 4.20 ms | 8.41 ms | 5.57 ms | 962.53 us | 519.53 us | 382.54 us | **346.31 us** | 201.07 us | 179.62 us | 1.87 ms | 1.23 ms |
| multisig-sm-09 | 946.64 us | 270.51 us | 459.38 us | 321.31 us | 4.33 ms | 8.48 ms | 5.72 ms | 963.16 us | 525.80 us | 385.77 us | **351.95 us** | 200.05 us | 179.46 us | 1.84 ms | 1.30 ms |
| multisig-sm-10 | 1.11 ms | 371.12 us | 628.75 us | 457.99 us | 6.24 ms | 11.52 ms | 8.64 ms | 1.51 ms | 670.58 us | 533.71 us | **428.02 us** | 279.89 us | 239.51 us | 2.63 ms | 1.88 ms |
| ping-pong-1 | 823.51 us | 228.34 us | 395.66 us | 254.97 us | 3.03 ms | 7.36 ms | 4.85 ms | 781.38 us | 433.81 us | 312.85 us | **282.84 us** | 156.12 us | 131.35 us | 1.51 ms | 1.09 ms |
| ping-pong-2 | 827.82 us | 226.88 us | 402.67 us | 249.31 us | 3.07 ms | 7.35 ms | 4.93 ms | 796.81 us | 431.53 us | 310.74 us | **279.20 us** | 155.28 us | 132.28 us | 1.51 ms | 1.06 ms |
| ping-pong_2-1 | 710.14 us | 147.23 us | 306.07 us | 143.17 us | 2.27 ms | 5.24 ms | 2.75 ms | 476.52 us | 312.24 us | 192.66 us | **214.90 us** | 90.88 us | 85.34 us | 977.37 us | 662.05 us |
| prism-1 | 328.11 us | 117.98 us | 163.64 us | 114.37 us | 1.29 ms | 2.69 ms | 1.92 ms | 339.24 us | 212.61 us | 162.44 us | **113.55 us** | 71.31 us | 31.48 us | 703.82 us | 551.18 us |
| prism-2 | 911.97 us | 283.56 us | 474.17 us | 319.80 us | 3.91 ms | 8.64 ms | 6.11 ms | 1.01 ms | 528.33 us | 401.29 us | **327.26 us** | 193.10 us | 164.75 us | 1.92 ms | 1.34 ms |
| prism-3 | 579.57 us | 258.00 us | 368.98 us | 293.11 us | 2.75 ms | 6.21 ms | 4.91 ms | 908.06 us | 436.76 us | 362.15 us | **240.44 us** | 173.18 us | 98.31 us | 1.42 ms | 1.23 ms |
| pubkey-1 | 307.95 us | 100.40 us | 143.44 us | 94.47 us | 1.14 ms | 2.36 ms | 1.43 ms | 300.38 us | 185.76 us | 135.24 us | **104.73 us** | 59.02 us | 27.87 us | 600.78 us | 479.93 us |
| stablecoin_1-1 | 1.53 ms | 667.86 us | 1.04 ms | 780.03 us | 15.51 ms | 18.24 ms | 14.42 ms | 2.39 ms | 1.22 ms | 986.71 us | **637.86 us** | 422.99 us | 745.89 us | 8.18 ms | 6.86 ms |
| stablecoin_1-2 | 363.90 us | 138.72 us | 191.16 us | 136.88 us | 1.53 ms | 3.16 ms | 2.24 ms | 394.94 us | 253.65 us | 199.10 us | **129.63 us** | 83.15 us | 38.43 us | 815.06 us | 666.36 us |
| stablecoin_1-3 | 1.81 ms | 760.83 us | 1.14 ms | 919.70 us | 14.14 ms | 20.92 ms | 17.12 ms | 2.68 ms | 1.37 ms | 1.16 ms | **716.67 us** | 508.37 us | 978.40 us | 9.19 ms | 7.64 ms |
| stablecoin_1-4 | 373.24 us | 151.45 us | 198.14 us | 145.64 us | 1.50 ms | 3.31 ms | 2.48 ms | 395.94 us | 268.75 us | 210.06 us | **135.25 us** | 88.32 us | 39.68 us | 910.32 us | 727.41 us |
| stablecoin_1-5 | 2.05 ms | 955.76 us | 1.46 ms | 1.16 ms | 16.83 ms | 25.26 ms | 21.38 ms | 3.28 ms | 1.77 ms | 1.52 ms | **876.11 us** | 660.81 us | 1.55 ms | 13.59 ms | 9.15 ms |
| stablecoin_1-6 | 413.12 us | 182.99 us | 225.78 us | 171.31 us | 1.79 ms | 3.91 ms | 3.03 ms | 515.89 us | 318.69 us | 260.10 us | **156.04 us** | 108.07 us | 48.30 us | 1.01 ms | 890.96 us |
| stablecoin_2-1 | 1.53 ms | 670.12 us | 1.05 ms | 801.81 us | 15.50 ms | 18.13 ms | 14.59 ms | 2.34 ms | 1.22 ms | 1.01 ms | **632.07 us** | 429.13 us | 1.22 ms | 10.76 ms | 6.31 ms |
| stablecoin_2-2 | 367.65 us | 139.56 us | 187.16 us | 135.75 us | 1.53 ms | 3.15 ms | 2.23 ms | 408.02 us | 257.00 us | 204.85 us | **128.64 us** | 83.48 us | 37.67 us | 813.80 us | 686.97 us |
| stablecoin_2-3 | 1.82 ms | 760.23 us | 1.17 ms | 928.20 us | 14.57 ms | 20.68 ms | 16.94 ms | 2.66 ms | 1.37 ms | 1.18 ms | **713.72 us** | 508.29 us | 1.04 ms | 12.25 ms | 6.92 ms |
| stablecoin_2-4 | 374.77 us | 151.48 us | 197.64 us | 142.50 us | 1.48 ms | 3.36 ms | 2.45 ms | 420.00 us | 265.45 us | 213.26 us | **134.69 us** | 89.55 us | 41.24 us | 887.53 us | 696.77 us |
| token-account-1 | 432.83 us | 135.60 us | 210.93 us | 143.24 us | 1.64 ms | 3.80 ms | 2.55 ms | 472.42 us | 249.87 us | 181.96 us | **152.79 us** | 88.17 us | 55.89 us | 762.03 us | 607.15 us |
| token-account-2 | 540.20 us | 248.21 us | 346.10 us | 239.14 us | 2.53 ms | 4.59 ms | 3.43 ms | 812.29 us | 370.23 us | 302.61 us | **219.05 us** | 162.28 us | 79.52 us | 1.21 ms | 1.08 ms |
| uniswap-1 | 578.37 us | 274.79 us | 395.87 us | 324.92 us | 3.29 ms | 6.07 ms | 4.91 ms | 1.08 ms | 431.19 us | 359.74 us | **272.04 us** | 207.15 us | 118.92 us | 1.55 ms | 1.29 ms |
| uniswap-2 | 459.56 us | 157.77 us | 233.47 us | 165.32 us | 2.01 ms | 4.25 ms | 3.00 ms | 516.88 us | 291.57 us | 221.75 us | **167.30 us** | 102.57 us | 58.84 us | 968.09 us | 734.46 us |
| uniswap-3 | 2.14 ms | 1.19 ms | 1.49 ms | 1.27 ms | 15.81 ms | 24.08 ms | 21.25 ms | 3.78 ms | 1.76 ms | 1.55 ms | **1.06 ms** | 907.35 us | 543.50 us | 10.08 ms | 6.20 ms |
| uniswap-4 | 494.76 us | 240.52 us | 335.53 us | 220.03 us | 2.35 ms | 4.62 ms | 3.57 ms | 728.92 us | 413.71 us | 348.42 us | **198.45 us** | 144.85 us | 62.59 us | 1.45 ms | 1.21 ms |
| uniswap-5 | 1.70 ms | 791.23 us | 1.04 ms | 815.10 us | 11.46 ms | 16.39 ms | 12.85 ms | 2.57 ms | 1.19 ms | 1.02 ms | **741.35 us** | 552.45 us | 356.51 us | 5.66 ms | 3.91 ms |
| uniswap-6 | 501.52 us | 251.30 us | 336.18 us | 213.99 us | 2.00 ms | 4.25 ms | 3.46 ms | 680.08 us | 581.41 us | 501.19 us | **191.68 us** | 136.61 us | 63.57 us | 1.38 ms | 1.13 ms |
| vesting-1 | 641.96 us | 240.18 us | 369.71 us | 263.67 us | 3.00 ms | 5.89 ms | 4.33 ms | 891.72 us | 405.65 us | 318.64 us | **255.15 us** | 166.05 us | 109.76 us | 1.33 ms | 1.06 ms |

## VMs in this benchmark

| VM | Language | Runtime | Execution model | Version | Source | Home | Used by | Badges | Note |
|---|---|---|---|---|---|---|---|---|---|
| Plutigo CEK (Go) | Go | native | Interpreter (CEK) | [v0.1.10](https://github.com/blinklabs-io/plutigo/releases/tag/v0.1.10) | [blinklabs-io/plutigo](https://github.com/blinklabs-io/plutigo) | - | [Dingo](https://github.com/blinklabs-io/dingo) (node) | - | - |
| Scalus CEK (Scala / JVM) | Scala | GraalVM | Interpreter (CEK) | [v1.4.0](https://github.com/scalus3/scalus/releases/tag/v1.4.0) | [scalus3/scalus](https://github.com/scalus3/scalus) | [scalus.org](https://scalus.org) | [Hydrozoa](https://github.com/cardano-hydrozoa/hydrozoa) (L2), [Bifrost](https://github.com/FluidTokens/ft-bifrost-bridge) (bridge), [Cardano Client Lib](https://github.com/bloxbean/cardano-client-lib) (SDK), [Yaci Store](https://github.com/bloxbean/yaci-store) (indexer), [Yaci DevKit](https://github.com/bloxbean/yaci-devkit) (dev tool) | - | - |
| uplc-turbo AST walker (Rust) | Rust | native | Interpreter (AST walker) | [amaru-uplc-v0.4.0](https://github.com/pragma-org/uplc/releases/tag/amaru-uplc-v0.4.0) | [pragma-org/uplc](https://github.com/pragma-org/uplc) | - | [Amaru](https://github.com/pragma-org/amaru) (node) | - | - |
| plutus-core CEK (Haskell / GHC) | Haskell | GHC | Interpreter (CEK) | [1.70.0.0](https://github.com/IntersectMBO/plutus/releases/tag/1.70.0.0) | [IntersectMBO/plutus](https://github.com/IntersectMBO/plutus) | [plutus.cardano.intersectmbo.org](https://plutus.cardano.intersectmbo.org) | [cardano-node](https://github.com/IntersectMBO/cardano-node) (node) | - | - |
| Scalus CEK (Scala.js / Node V8) | Scala.js | Node (V8) | Interpreter (CEK) | [scalus 1.4.0 (npm)](https://github.com/scalus3/scalus/releases/tag/v1.4.0) | [scalus3/scalus](https://github.com/scalus3/scalus) | [scalus.org](https://scalus.org) | [Lucid Evolution](https://github.com/Anastasia-Labs/lucid-evolution) (SDK), [MeshJS](https://github.com/MeshJS/mesh) (SDK), [Evolution SDK](https://github.com/IntersectMBO/evolution-sdk) (SDK) | - | - |
| Aiken uplc CEK (Rust) | Rust | native | Interpreter (CEK) | [v1.1.24](https://github.com/aiken-lang/aiken/releases/tag/v1.1.24) | [aiken-lang/aiken](https://github.com/aiken-lang/aiken) | [aiken-lang.org](https://aiken-lang.org) | [Aiken](https://aiken-lang.org) (compiler), [Blaze SDK](https://github.com/butaneprotocol/blaze-cardano) (SDK) | - | Aiken v1.1.24 copies the CEK environment on every lambda application (quadratic in recursion depth). aiken main fixes it (PRs [#1451](https://github.com/aiken-lang/aiken/pull/1451), [#1452](https://github.com/aiken-lang/aiken/pull/1452): coop-6 92 ms -> 1.2 ms), but no release contains the fix yet. |
| Aiken uplc CEK (Rust → WASM / Node V8) | Rust → WASM | Node (V8) | Interpreter (CEK) | [@lucid-evolution/uplc 0.4.0](https://github.com/Anastasia-Labs/lucid-evolution/releases/tag/@lucid-evolution/uplc@0.4.0) | [Anastasia-Labs/lucid-evolution](https://github.com/Anastasia-Labs/lucid-evolution) | [anastasia-labs.github.io/lucid-evolution](https://anastasia-labs.github.io/lucid-evolution/) | [Lucid Evolution](https://github.com/Anastasia-Labs/lucid-evolution) (SDK) | decode cached (by the library) | Built from [colll78/aiken](https://github.com/colll78/aiken) (aiken main plus fixes), which includes the CEK fixes that v1.1.24 lacks. |
| Scalus UPLC→JVM JIT (Scala / JVM) | Scala | GraalVM | JIT compiler (UPLC → JVM bytecode) | [v1.4.0](https://github.com/scalus3/scalus/releases/tag/v1.4.0) | [scalus3/scalus](https://github.com/scalus3/scalus) | [scalus.org](https://scalus.org) | - | experimental, decode and compile excluded | - |
| blaze-plutus CEK (TypeScript / Node V8) | TypeScript | Node (V8) | Interpreter (CEK) | [@blaze-cardano/plutus 0.1.1](https://github.com/butaneprotocol/blaze-cardano/releases/tag/@blaze-cardano/plutus@0.1.1) | [butaneprotocol/blaze-cardano](https://github.com/butaneprotocol/blaze-cardano) | [blaze.butane.dev](https://blaze.butane.dev) | - | experimental | - |

---
Harness commit: [`0529b3ac1`](https://github.com/lantr-io/plutus-vm-benchmark/commit/0529b3ac142270732bbd1849860f2a4322dd6d9a)

*Plutus VM Benchmark – maintained by [Lantr](https://lantr.io) – Alexander Nemish. Forked from [SAIB-Inc/cardano-plutus-vm-benchmark](https://github.com/SAIB-Inc/cardano-plutus-vm-benchmark) by SAIB Inc. and contributors. MIT License, original work © 2025 SAIB Inc., © 2026 Lantr. Source: [lantr-io/plutus-vm-benchmark](https://github.com/lantr-io/plutus-vm-benchmark)*