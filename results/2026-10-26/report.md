# Plutus VM Benchmark Results

**Date:** 2026-10-26

## Environment
```
date: 2026-10-26T14:34:02+00:00
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
load avg at start: 0.47 0.12 0.04
docker: 29.9.1 (linux/amd64)
docker cpus: 16
docker memory: 62786 MiB
docker run flags: --rm --cap-add SYS_NICE --network none
lanes: 3 (lane0 2,3,4,5; lane1 6,7,8,9; lane2 10,11,12,13; idle cores 14,15)
parallel: yes (up to 3 VMs at once; haskell and the drift probe run alone on lane0)
harness: c4872f309c7577b55f9874b4b1d77a6bdf0f84ba
vm order: haskell scalus-cek scalus-jit blaze-v8 scalus-js aiken aiken-wasm uplc-turbo plutigo
bench_quick: 0
bench_scripts: <all> (89 of 89 scripts)
bench_loops: d3,eval,check
bench_timing: normal
bench_trace: 0
host cpus: 0,1,14,15
server qualification: pass, ratio 0.961, attempt 1 of 3, nbg1; rejected: none; haskell geo ratio 0.961 <= 1.15 vs ccx43 reference (harness b0d8a22, 2026-10-22): auction_1-1 0.94, coop-6 0.94, uniswap-1 1.00
image haskell: ghcr.io/lantr-io/pvb-haskell:7b78360d2cdd ghcr.io/lantr-io/pvb-haskell@sha256:f1239cfa64f02a5b33434ef1277660fe3d47a2e83a078403c017e7f26ce33610
noise haskell: load avg before 0.93 0.29 0.10, steal during run 0.00 % (0 of 1476390 ticks) lane0
image scalus-cek: ghcr.io/lantr-io/pvb-scalus-cek:e4ceb730993e ghcr.io/lantr-io/pvb-scalus-cek@sha256:ab742bce3ae77bc5e1adaf5c57acb4d5c3108bd6abde8112987610332a111a64
image scalus-jit: ghcr.io/lantr-io/pvb-scalus-jit:72d385708658 ghcr.io/lantr-io/pvb-scalus-jit@sha256:95ebb13e361ade11f24b9c355866d9b82a295ff2dd26a66b95388a3d3c64dce6
image blaze-v8: ghcr.io/lantr-io/pvb-blaze-v8:98c2ab4a64bc ghcr.io/lantr-io/pvb-blaze-v8@sha256:083fc21b0e42c4e9b526b9feebf83d14909519b141adbe2132ea9b819fb8046c
noise blaze-v8: load avg before 1.26 1.06 0.73, steal during run 0.00 % (0 of 6144019 ticks) lane2
image scalus-js: ghcr.io/lantr-io/pvb-scalus-js:35e2340500dc ghcr.io/lantr-io/pvb-scalus-js@sha256:bfa46a6faaec5f861c41cc2dfc230b66b6bf8371b581b3db8b5916a9a0529bbb
noise scalus-jit: load avg before 1.11 1.03 0.72, steal during run 0.00 % (0 of 8510550 ticks) lane1
image aiken: ghcr.io/lantr-io/pvb-aiken:553af555815c ghcr.io/lantr-io/pvb-aiken@sha256:b1328c3825f56f452b1f7de6b156b45729d56979ab8afb122e9223fad02a5660
noise aiken: load avg before 3.04 3.25 3.44, steal during run 0.00 % (0 of 3030574 ticks) lane1
image aiken-wasm: ghcr.io/lantr-io/pvb-aiken-wasm:622e07dc30d7 ghcr.io/lantr-io/pvb-aiken-wasm@sha256:789e0f2f88c40e7c51056c0c58c006ce25762bc4625820a29aec54e53d2c3333
noise scalus-js: load avg before 3.49 3.60 3.55, steal during run 0.00 % (0 of 6262742 ticks) lane2
image uplc-turbo: ghcr.io/lantr-io/pvb-uplc-turbo:4f5f499a7ef9 ghcr.io/lantr-io/pvb-uplc-turbo@sha256:494e43756cca00c1160f0eefdf9836e12bb092dfbe9a714cecbd2c073246882d
noise scalus-cek: load avg before 1.11 1.03 0.72, steal during run 0.00 % (0 of 13316956 ticks) lane0
image plutigo: ghcr.io/lantr-io/pvb-plutigo:0135f9baacb4 ghcr.io/lantr-io/pvb-plutigo@sha256:aefe3292c5e2fde945273a5dee7e71f006cfcef45cf8aaf65e3b92f87ef00e0d
noise aiken-wasm: load avg before 3.11 3.09 3.13, steal during run 0.00 % (0 of 3014226 ticks) lane1
noise plutigo: load avg before 3.27 3.10 3.10, steal during run 0.00 % (0 of 1709410 ticks) lane0
noise uplc-turbo: load avg before 3.13 3.15 3.14, steal during run 0.00 % (0 of 3004537 ticks) lane2
steal during the whole run: 0.00 % (0 of 17005274 ticks)
load avg at end: 1.28 1.67 2.35
drift (haskell, end vs start): +4.0 % over 5 scripts
```

*The 89 scripts are PlutusV1-era programs. Every VM evaluates them as PlutusV3 programs at protocol version 11 with the mainnet cost model, like Plutus's own `validation` CEK benchmark; the node would run them as PlutusV1.*

*Drift (Haskell, end vs start): +4.0 % over 5 scripts. The run timed Haskell again at its end; this is the change of its time.*

## Summary (geometric mean across all scripts)

*Note: VMs that fail or skip a script are assigned the slowest competitor's time for that script.*
*A compiling VM's timed loop runs the compiled script ("decode and compile excluded": the decode and the compile run once per script, before timing). So it has only an eval-only time: its Geo Mean (decode + eval) is "–" and it is not ranked. The Compile column is the geometric mean of the compile time over the scripts.*
*Geo Mean: flat decode + evaluation (the ranking). Eval only: evaluation of a program decoded before the timed loop, geometric mean over its scripts.*
*Aiken WASM caches decoded programs inside the library, so its time is shown as eval only. It is not in the decode + eval ranking; it is ranked on eval only (Geo Mean "–").*
*Aiken uplc CEK (Rust → WASM / Node V8), "decode cached (by the library)": The library caches the decoded program by a hash of the flat bytes. After the first call (in the warm-up), the timed loop runs hash + evaluation, without the decode. Its eval-only time is the same loop.*

| VM | Language | Geo Mean | vs Fastest | Eval only | Compile | Check |
|---|---|---|---|---|---|---|
| **Scalus CEK (Scala / JVM)** | Scala / JVM | 207.72 us | 1.00x | 135.52 us | - | pass |
| **Plutigo CEK (Go)** | Go | 245.02 us | 1.18x | 151.67 us | - | pass |
| **uplc-turbo AST walker (Rust)** | Rust | 417.60 us | 2.01x | 325.66 us | - | pass |
| **plutus-core CEK (Haskell / GHC)** | Haskell / GHC | 629.02 us | 3.03x | 244.48 us | - | pass |
| **Scalus CEK (Scala.js / Node V8)** | Scala.js / Node V8 | 1.30 ms | 6.24x | 848.67 us | - | pass |
| **Aiken uplc CEK (Rust)** | Rust | 6.40 ms | 30.82x | 4.64 ms | - | pass |
| **Aiken uplc CEK (Rust → WASM / Node V8)** (decode cached (by the library)) | Rust → WASM / Node V8 | – | eval only | 778.72 us | - | pass |

### Experimental

Run, gated and shown, but not ranked: not in the table above, not a competitor in the penalty rule. Geo Mean uses the penalty rule against the ranked VMs. Geo Mean "–" (compiled once before timing, see the compile column): the VM has only an eval-only time.

| VM | Language | Geo Mean | Eval only | Compile | Check | Reason |
|---|---|---|---|---|---|---|
| **Scalus UPLC→JVM JIT (Scala / JVM)** | Scala / JVM | – | 94.64 us | 1.37 s (decode and compile excluded) | pass | not ranked: the JIT module is published (Maven, since Scalus 1.4.1) but has no downstream users yet (spec D17) |
| **blaze-plutus CEK (TypeScript / Node V8)** | TypeScript / Node V8 | 1.32 ms | 1.04 ms | - | pass | not ranked: no released project outside the Blaze repo depends on @blaze-cardano/plutus yet; Blaze itself evaluates scripts with @blaze-cardano/vm (Aiken uplc as WASM) (spec D17) |

### Notes

- **Aiken uplc CEK (Rust)**: Aiken v1.1.24 copies the CEK environment on every lambda application (quadratic in recursion depth). aiken main fixes it (PRs [#1451](https://github.com/aiken-lang/aiken/pull/1451), [#1452](https://github.com/aiken-lang/aiken/pull/1452): coop-6 92 ms -> 1.2 ms), but no release contains the fix yet.
- **Aiken uplc CEK (Rust → WASM / Node V8)**: Built from [colll78/aiken](https://github.com/colll78/aiken) (aiken main plus fixes), which includes the CEK fixes that v1.1.24 lacks.

### History (speed relative to Haskell plutus-core, same run; higher is faster)

| VM | 2026-10-23 | 2026-10-26 | Change vs previous run |
|---|---|---|---|
| plutus-core CEK (Haskell / GHC) | 1x (Haskell) | 1x (Haskell) | reference |
| Scalus UPLC→JVM JIT (Scala / JVM) (experimental, eval only) | 2.2x faster | 2.6x faster | +18 % |
| Scalus CEK (Scala / JVM) | 1.8x faster | 3.0x faster | +72 % |
| Scalus CEK (Scala.js / Node V8) | 5.0x slower | 2.1x slower | +143 % |
| Aiken uplc CEK (Rust) | 11.6x slower | 10.2x slower | +14 % |
| Aiken uplc CEK (Rust → WASM / Node V8) (eval only) | 3.3x slower | 3.2x slower | no change (within ±5 % noise) |
| uplc-turbo AST walker (Rust) | 1.5x faster | 1.5x faster | no change (within ±5 % noise) |
| Plutigo CEK (Go) | 2.5x faster | 2.6x faster | no change (within ±5 % noise) |
| blaze-plutus CEK (TypeScript / Node V8) (experimental) | 2.5x slower | 2.1x slower | +17 % |

A VM marked "eval only" has no decode + eval time (it compiles each script before timing, or its library caches the decode): its ratio is its eval-only time divided by Haskell's eval-only time.

Servers of the same type differ: ratios to Haskell move up to about 5 % between two runs on different servers, so a change under 5 % is shown as no change.

### Script Coverage

| VM | Passed | Failed | Missing | Total |
|---|---|---|---|---|
| Scalus CEK (Scala / JVM) | 89 | 0 | 0 | 89 |
| Plutigo CEK (Go) | 89 | 0 | 0 | 89 |
| uplc-turbo AST walker (Rust) | 89 | 0 | 0 | 89 |
| plutus-core CEK (Haskell / GHC) | 89 | 0 | 0 | 89 |
| Scalus CEK (Scala.js / Node V8) | 89 | 0 | 0 | 89 |
| Aiken uplc CEK (Rust) | 89 | 0 | 0 | 89 |
| Aiken uplc CEK (Rust → WASM / Node V8) | 89 | 0 | 0 | 89 |
| Scalus UPLC→JVM JIT (Scala / JVM) (experimental) | 89 | 0 | 0 | 89 |
| blaze-plutus CEK (TypeScript / Node V8) (experimental) | 89 | 0 | 0 | 89 |

## Per-Script Results

| Script | plutus-core CEK (Haskell / GHC) | plutus-core CEK (Haskell / GHC) (eval only) | Scalus CEK (Scala / JVM) | Scalus CEK (Scala / JVM) (eval only) | Scalus CEK (Scala.js / Node V8) | Scalus CEK (Scala.js / Node V8) (eval only) | Aiken uplc CEK (Rust) | Aiken uplc CEK (Rust) (eval only) | Aiken uplc CEK (Rust → WASM / Node V8) (eval only) | uplc-turbo AST walker (Rust) | uplc-turbo AST walker (Rust) (eval only) | Plutigo CEK (Go) | Plutigo CEK (Go) (eval only) | Scalus UPLC→JVM JIT (Scala / JVM) (experimental) (eval only) | blaze-plutus CEK (TypeScript / Node V8) (experimental) | blaze-plutus CEK (TypeScript / Node V8) (experimental) (eval only) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| auction_1-1 | 336.84 us | 117.10 us | **99.29 us** | 59.31 us | 609.88 us | 371.18 us | 2.36 ms | 1.42 ms | 322.79 us | 209.40 us | 158.31 us | 115.98 us | 61.80 us | 27.48 us | 552.91 us | 444.78 us |
| auction_1-2 | 972.96 us | 389.79 us | **328.52 us** | 226.62 us | 1.77 ms | 1.17 ms | 9.39 ms | 7.02 ms | 1.50 ms | 611.65 us | 489.39 us | 411.49 us | 275.77 us | 171.91 us | 1.92 ms | 1.44 ms |
| auction_1-3 | 988.34 us | 386.95 us | **313.19 us** | 212.33 us | 1.89 ms | 1.17 ms | 9.30 ms | 6.94 ms | 1.38 ms | 610.48 us | 490.24 us | 403.94 us | 268.96 us | 158.98 us | 1.87 ms | 1.43 ms |
| auction_1-4 | 378.44 us | 147.71 us | **118.20 us** | 75.33 us | 732.54 us | 458.91 us | 2.69 ms | 1.72 ms | 404.10 us | 257.27 us | 205.19 us | 129.62 us | 77.20 us | 31.01 us | 681.64 us | 586.85 us |
| auction_2-1 | 342.11 us | 117.54 us | **101.12 us** | 58.69 us | 626.39 us | 364.19 us | 2.35 ms | 1.42 ms | 321.90 us | 209.28 us | 158.77 us | 114.75 us | 62.29 us | 26.53 us | 554.51 us | 443.75 us |
| auction_2-2 | 980.59 us | 392.49 us | **315.94 us** | 212.49 us | 1.81 ms | 1.17 ms | 9.40 ms | 7.08 ms | 1.38 ms | 603.55 us | 480.63 us | 409.85 us | 277.56 us | 167.66 us | 1.90 ms | 1.47 ms |
| auction_2-3 | 1.10 ms | 488.18 us | **404.31 us** | 280.04 us | 2.31 ms | 1.54 ms | 11.40 ms | 9.13 ms | 1.85 ms | 806.17 us | 695.54 us | 497.78 us | 362.09 us | 214.32 us | 2.49 ms | 1.87 ms |
| auction_2-4 | 971.86 us | 377.29 us | **321.84 us** | 230.37 us | 1.89 ms | 1.16 ms | 9.26 ms | 6.90 ms | 1.37 ms | 607.93 us | 488.06 us | 407.32 us | 271.53 us | 162.34 us | 1.96 ms | 1.47 ms |
| auction_2-5 | 377.55 us | 144.40 us | **121.47 us** | 75.93 us | 734.58 us | 463.97 us | 2.73 ms | 1.75 ms | 387.95 us | 258.38 us | 206.51 us | 132.00 us | 78.04 us | 31.16 us | 685.51 us | 586.80 us |
| coop-1 | 299.23 us | 146.87 us | **112.14 us** | 86.89 us | 845.64 us | 652.98 us | 4.53 ms | 4.31 ms | 363.99 us | 224.01 us | 182.39 us | 112.61 us | 82.55 us | 30.99 us | 791.42 us | 696.16 us |
| coop-2 | 825.23 us | 477.72 us | **348.51 us** | 273.54 us | 2.71 ms | 2.10 ms | 95.90 ms | 116.30 ms | 1.34 ms | 715.42 us | 627.91 us | 358.38 us | 267.65 us | 124.66 us | 2.96 ms | 2.44 ms |
| coop-3 | 1.82 ms | 1.35 ms | **995.55 us** | 965.57 us | 8.51 ms | 7.05 ms | 122.86 ms | 142.97 ms | 5.13 ms | 1.58 ms | 1.43 ms | 1.02 ms | 953.00 us | 476.53 us | 6.84 ms | 6.12 ms |
| coop-4 | 1.05 ms | 614.29 us | **443.54 us** | 355.46 us | 3.37 ms | 2.73 ms | 97.84 ms | 117.00 ms | 1.81 ms | 761.06 us | 662.44 us | 456.24 us | 355.50 us | 186.79 us | 3.68 ms | 2.93 ms |
| coop-5 | 628.16 us | 272.85 us | **225.06 us** | 149.22 us | 1.51 ms | 1.17 ms | 21.33 ms | 23.93 ms | 722.64 us | 403.41 us | 312.94 us | 228.39 us | 144.04 us | 63.92 us | 1.50 ms | 1.20 ms |
| coop-6 | 692.17 us | 445.75 us | 323.36 us | 264.69 us | 2.43 ms | 2.02 ms | 132.48 ms | 164.85 ms | 1.09 ms | 636.35 us | 579.42 us | **300.98 us** | 245.33 us | 115.77 us | 2.53 ms | 2.26 ms |
| coop-7 | 390.36 us | 207.48 us | 160.44 us | 130.17 us | 1.16 ms | 911.35 us | 5.44 ms | 5.15 ms | 551.43 us | 316.35 us | 265.96 us | **152.16 us** | 112.47 us | 43.13 us | 1.13 ms | 986.86 us |
| crowdfunding-success-1 | 410.44 us | 135.03 us | **123.25 us** | 71.90 us | 762.51 us | 418.41 us | 2.78 ms | 1.64 ms | 414.40 us | 239.88 us | 181.48 us | 135.93 us | 70.98 us | 30.35 us | 651.81 us | 521.70 us |
| crowdfunding-success-2 | 405.39 us | 145.34 us | **124.92 us** | 71.29 us | 744.01 us | 414.63 us | 2.80 ms | 1.63 ms | 398.02 us | 235.63 us | 174.69 us | 135.70 us | 70.68 us | 30.81 us | 644.86 us | 517.13 us |
| crowdfunding-success-3 | 415.32 us | 145.31 us | **125.84 us** | 72.53 us | 710.22 us | 410.43 us | 2.78 ms | 1.65 ms | 387.84 us | 243.17 us | 186.68 us | 137.63 us | 69.94 us | 30.59 us | 646.78 us | 529.13 us |
| currency-1 | 465.25 us | 162.13 us | **144.20 us** | 87.78 us | 752.48 us | 484.36 us | 3.45 ms | 2.39 ms | 488.61 us | 271.45 us | 215.87 us | 165.45 us | 101.15 us | 53.98 us | 739.82 us | 603.18 us |
| escrow-redeem_1-1 | 614.93 us | 234.20 us | **188.38 us** | 120.62 us | 1.06 ms | 674.91 us | 4.81 ms | 3.33 ms | 676.18 us | 343.70 us | 266.20 us | 220.69 us | 133.03 us | 67.38 us | 1.00 ms | 792.80 us |
| escrow-redeem_1-2 | 588.82 us | 221.90 us | **186.07 us** | 118.23 us | 1.05 ms | 676.22 us | 4.81 ms | 3.35 ms | 643.33 us | 345.57 us | 267.18 us | 220.29 us | 132.32 us | 68.29 us | 1.10 ms | 824.18 us |
| escrow-redeem_2-1 | 630.43 us | 265.59 us | **208.87 us** | 141.26 us | 1.16 ms | 777.82 us | 5.37 ms | 3.89 ms | 884.70 us | 386.03 us | 306.93 us | 242.94 us | 154.57 us | 82.49 us | 1.25 ms | 978.62 us |
| escrow-redeem_2-2 | 633.30 us | 259.34 us | **207.39 us** | 144.24 us | 1.16 ms | 791.37 us | 5.38 ms | 3.89 ms | 849.88 us | 418.92 us | 336.70 us | 247.67 us | 157.92 us | 84.20 us | 1.27 ms | 974.89 us |
| escrow-redeem_2-3 | 620.24 us | 269.06 us | **210.76 us** | 147.73 us | 1.21 ms | 772.92 us | 5.38 ms | 3.89 ms | 844.81 us | 389.48 us | 308.69 us | 249.03 us | 159.59 us | 82.42 us | 1.22 ms | 953.03 us |
| escrow-refund-1 | 440.04 us | 100.86 us | **114.08 us** | 50.42 us | 712.25 us | 307.27 us | 2.80 ms | 1.30 ms | 297.19 us | 203.05 us | 129.04 us | 139.34 us | 54.28 us | 24.55 us | 527.61 us | 390.28 us |
| future-increase-margin-1 | 420.15 us | 154.49 us | **141.09 us** | 90.12 us | 786.86 us | 476.75 us | 3.49 ms | 2.39 ms | 518.54 us | 251.66 us | 194.93 us | 171.64 us | 102.06 us | 53.99 us | 752.65 us | 594.40 us |
| future-increase-margin-2 | 705.32 us | 331.67 us | **261.59 us** | 187.51 us | 1.51 ms | 1.03 ms | 6.86 ms | 5.39 ms | 1.21 ms | 503.13 us | 417.45 us | 304.98 us | 214.91 us | 113.95 us | 1.59 ms | 1.33 ms |
| future-increase-margin-3 | 729.44 us | 339.38 us | **256.85 us** | 193.25 us | 1.53 ms | 1.03 ms | 6.86 ms | 5.44 ms | 1.12 ms | 501.70 us | 417.23 us | 311.31 us | 222.08 us | 114.31 us | 1.65 ms | 1.37 ms |
| future-increase-margin-4 | 1.03 ms | 306.91 us | **293.30 us** | 166.98 us | 1.71 ms | 932.01 us | 8.09 ms | 5.21 ms | 1.04 ms | 593.12 us | 444.82 us | 393.03 us | 214.89 us | 148.31 us | 1.72 ms | 1.22 ms |
| future-increase-margin-5 | 1.27 ms | 517.02 us | **427.01 us** | 304.71 us | 3.41 ms | 2.59 ms | 11.76 ms | 8.79 ms | 1.93 ms | 820.75 us | 666.83 us | 512.79 us | 355.92 us | 320.77 us | 4.01 ms | 3.08 ms |
| future-pay-out-1 | 430.93 us | 159.17 us | **136.81 us** | 87.15 us | 781.67 us | 498.91 us | 3.48 ms | 2.38 ms | 532.54 us | 258.75 us | 202.06 us | 171.47 us | 103.74 us | 56.63 us | 813.44 us | 641.84 us |
| future-pay-out-2 | 719.94 us | 346.18 us | **245.29 us** | 185.56 us | 1.52 ms | 1.19 ms | 6.81 ms | 5.40 ms | 1.10 ms | 493.23 us | 414.36 us | 315.33 us | 222.24 us | 115.95 us | 1.67 ms | 1.27 ms |
| future-pay-out-3 | 731.60 us | 339.98 us | **254.07 us** | 186.97 us | 1.46 ms | 1.05 ms | 6.83 ms | 5.41 ms | 1.11 ms | 501.46 us | 414.20 us | 316.83 us | 219.76 us | 115.10 us | 1.61 ms | 1.38 ms |
| future-pay-out-4 | 1.27 ms | 505.22 us | **436.68 us** | 301.89 us | 3.50 ms | 2.63 ms | 11.80 ms | 8.89 ms | 1.92 ms | 873.30 us | 732.65 us | 519.16 us | 349.60 us | 314.84 us | 4.11 ms | 3.26 ms |
| future-settle-early-1 | 429.65 us | 155.44 us | **135.75 us** | 87.88 us | 799.12 us | 499.91 us | 3.50 ms | 2.41 ms | 520.46 us | 258.33 us | 197.28 us | 171.39 us | 103.69 us | 54.66 us | 828.58 us | 665.98 us |
| future-settle-early-2 | 726.80 us | 335.96 us | **259.78 us** | 190.76 us | 1.49 ms | 1.07 ms | 6.84 ms | 5.41 ms | 1.12 ms | 507.37 us | 417.17 us | 314.32 us | 220.17 us | 111.76 us | 1.74 ms | 1.38 ms |
| future-settle-early-3 | 714.60 us | 340.50 us | **245.75 us** | 185.65 us | 1.50 ms | 1.08 ms | 6.86 ms | 5.40 ms | 1.13 ms | 500.74 us | 419.90 us | 313.77 us | 220.44 us | 110.01 us | 1.69 ms | 1.38 ms |
| future-settle-early-4 | 1.12 ms | 390.68 us | **363.64 us** | 240.17 us | 3.08 ms | 2.25 ms | 9.16 ms | 6.20 ms | 1.45 ms | 654.68 us | 504.25 us | 416.45 us | 252.61 us | 218.31 us | 3.52 ms | 2.82 ms |
| game-sm-success_1-1 | 779.92 us | 244.31 us | **233.94 us** | 132.80 us | 1.36 ms | 738.32 us | 6.04 ms | 3.69 ms | 806.59 us | 437.98 us | 320.44 us | 295.72 us | 160.78 us | 101.82 us | 1.40 ms | 1.04 ms |
| game-sm-success_1-2 | 320.76 us | 127.03 us | **102.05 us** | 70.22 us | 626.78 us | 420.47 us | 2.51 ms | 1.67 ms | 334.45 us | 226.12 us | 181.96 us | 116.00 us | 70.33 us | 28.61 us | 659.83 us | 554.75 us |
| game-sm-success_1-3 | 980.88 us | 389.38 us | **323.05 us** | 219.38 us | 1.72 ms | 1.23 ms | 8.89 ms | 6.56 ms | 1.39 ms | 632.55 us | 508.22 us | 416.92 us | 275.95 us | 164.21 us | 2.18 ms | 1.65 ms |
| game-sm-success_1-4 | 347.30 us | 148.17 us | **117.73 us** | 77.11 us | 692.40 us | 464.17 us | 2.75 ms | 1.96 ms | 419.41 us | 265.58 us | 212.99 us | 128.17 us | 80.61 us | 32.62 us | 805.14 us | 636.54 us |
| game-sm-success_2-1 | 782.87 us | 246.47 us | **232.59 us** | 130.13 us | 1.34 ms | 739.30 us | 6.09 ms | 3.75 ms | 816.60 us | 454.60 us | 338.06 us | 297.23 us | 162.38 us | 105.64 us | 1.28 ms | 911.68 us |
| game-sm-success_2-2 | 320.65 us | 129.34 us | **103.06 us** | 65.90 us | 631.05 us | 406.55 us | 2.49 ms | 1.69 ms | 346.55 us | 235.80 us | 188.09 us | 116.32 us | 70.85 us | 29.23 us | 592.25 us | 517.44 us |
| game-sm-success_2-3 | 976.28 us | 388.49 us | **330.55 us** | 220.08 us | 1.72 ms | 1.21 ms | 8.81 ms | 6.53 ms | 1.39 ms | 716.57 us | 589.19 us | 417.16 us | 278.44 us | 166.42 us | 2.14 ms | 1.51 ms |
| game-sm-success_2-4 | 350.89 us | 148.21 us | **115.90 us** | 78.18 us | 700.42 us | 478.81 us | 2.79 ms | 1.95 ms | 404.35 us | 271.88 us | 220.96 us | 128.74 us | 80.83 us | 33.28 us | 709.10 us | 597.05 us |
| game-sm-success_2-5 | 990.64 us | 389.68 us | **323.25 us** | 225.41 us | 1.73 ms | 1.24 ms | 8.91 ms | 6.57 ms | 1.39 ms | 654.66 us | 526.30 us | 413.44 us | 277.65 us | 170.00 us | 1.96 ms | 1.48 ms |
| game-sm-success_2-6 | 348.34 us | 151.28 us | **116.37 us** | 76.69 us | 721.94 us | 478.87 us | 2.79 ms | 1.94 ms | 397.55 us | 269.99 us | 219.86 us | 128.14 us | 79.40 us | 32.72 us | 712.63 us | 606.29 us |
| guardrail-sorted-large | 493.84 us | 274.99 us | **231.85 us** | 176.54 us | 1.70 ms | 1.39 ms | 13.16 ms | 13.94 ms | 786.37 us | 427.78 us | 312.99 us | 263.52 us | 178.02 us | 171.94 us | 1.68 ms | 1.41 ms |
| guardrail-sorted-small | 165.28 us | 43.73 us | 58.33 us | 35.05 us | 409.23 us | 294.86 us | 2.48 ms | 2.29 ms | 139.18 us | 87.66 us | 42.99 us | **56.42 us** | 28.65 us | 65.36 us | 316.49 us | 245.73 us |
| guardrail-unsorted-large | 599.41 us | 379.74 us | **320.64 us** | 260.23 us | 2.26 ms | 1.90 ms | 161.02 ms | 196.84 ms | 1.18 ms | 585.60 us | 478.93 us | 333.00 us | 246.43 us | 210.35 us | 2.12 ms | 1.93 ms |
| guardrail-unsorted-small | 157.91 us | 42.62 us | 58.26 us | 35.32 us | 392.92 us | 292.46 us | 3.34 ms | 3.41 ms | 135.69 us | 86.23 us | 42.53 us | **55.70 us** | 26.88 us | 63.49 us | 314.85 us | 243.23 us |
| multisig-sm-01 | 872.91 us | 252.47 us | **235.50 us** | 132.82 us | 1.35 ms | 731.70 us | 6.87 ms | 4.19 ms | 876.07 us | 487.91 us | 349.00 us | 317.99 us | 170.74 us | 119.54 us | 1.49 ms | 1.01 ms |
| multisig-sm-02 | 856.76 us | 247.34 us | **237.92 us** | 131.62 us | 1.39 ms | 724.80 us | 6.64 ms | 4.06 ms | 865.97 us | 481.98 us | 343.14 us | 312.33 us | 167.01 us | 114.59 us | 1.45 ms | 983.64 us |
| multisig-sm-03 | 864.65 us | 252.85 us | **240.90 us** | 130.91 us | 1.41 ms | 720.94 us | 6.70 ms | 4.19 ms | 807.60 us | 480.86 us | 343.77 us | 316.85 us | 169.80 us | 111.58 us | 1.49 ms | 947.95 us |
| multisig-sm-04 | 878.80 us | 251.70 us | **243.40 us** | 130.43 us | 1.36 ms | 721.31 us | 6.88 ms | 4.21 ms | 819.86 us | 487.93 us | 351.40 us | 315.13 us | 169.43 us | 112.88 us | 1.51 ms | 999.38 us |
| multisig-sm-05 | 992.40 us | 341.61 us | **292.37 us** | 189.41 us | 1.74 ms | 1.02 ms | 9.10 ms | 6.45 ms | 1.24 ms | 608.85 us | 471.36 us | 389.56 us | 243.21 us | 156.42 us | 1.96 ms | 1.44 ms |
| multisig-sm-06 | 881.44 us | 252.07 us | **235.44 us** | 129.69 us | 1.39 ms | 722.88 us | 6.80 ms | 4.19 ms | 870.72 us | 481.82 us | 349.46 us | 315.38 us | 168.73 us | 113.13 us | 1.53 ms | 1.04 ms |
| multisig-sm-07 | 848.48 us | 246.44 us | **238.46 us** | 128.35 us | 1.38 ms | 745.28 us | 6.68 ms | 4.02 ms | 881.83 us | 467.98 us | 335.05 us | 309.54 us | 165.35 us | 111.85 us | 1.46 ms | 991.90 us |
| multisig-sm-08 | 862.61 us | 249.28 us | **231.45 us** | 128.20 us | 1.39 ms | 724.27 us | 6.64 ms | 4.10 ms | 807.47 us | 501.39 us | 369.82 us | 310.88 us | 168.34 us | 108.28 us | 1.44 ms | 953.71 us |
| multisig-sm-09 | 863.34 us | 252.59 us | **240.93 us** | 132.38 us | 1.39 ms | 761.26 us | 6.69 ms | 4.13 ms | 820.65 us | 505.43 us | 367.26 us | 312.39 us | 170.05 us | 112.94 us | 1.48 ms | 989.06 us |
| multisig-sm-10 | 988.61 us | 338.47 us | **290.51 us** | 188.70 us | 1.79 ms | 1.06 ms | 8.80 ms | 6.26 ms | 1.32 ms | 590.65 us | 461.76 us | 388.91 us | 241.53 us | 156.63 us | 1.89 ms | 1.36 ms |
| ping-pong-1 | 741.16 us | 215.50 us | **201.02 us** | 110.84 us | 1.20 ms | 645.28 us | 5.71 ms | 3.52 ms | 652.96 us | 381.44 us | 272.74 us | 262.73 us | 134.76 us | 87.59 us | 1.15 ms | 779.62 us |
| ping-pong-2 | 743.63 us | 207.89 us | **205.23 us** | 110.88 us | 1.18 ms | 630.61 us | 5.74 ms | 3.45 ms | 668.94 us | 411.65 us | 292.85 us | 260.21 us | 134.37 us | 86.91 us | 1.08 ms | 786.26 us |
| ping-pong_2-1 | 636.39 us | 130.25 us | **155.21 us** | 67.87 us | 907.71 us | 407.64 us | 4.27 ms | 1.96 ms | 403.13 us | 278.09 us | 175.96 us | 201.69 us | 76.26 us | 47.87 us | 773.92 us | 499.07 us |
| prism-1 | 288.00 us | 105.28 us | **89.02 us** | 54.34 us | 550.17 us | 351.10 us | 2.11 ms | 1.36 ms | 333.25 us | 193.07 us | 149.42 us | 99.03 us | 56.92 us | 23.14 us | 575.18 us | 445.12 us |
| prism-2 | 812.34 us | 258.20 us | **240.88 us** | 139.50 us | 1.38 ms | 800.77 us | 6.64 ms | 4.26 ms | 877.93 us | 489.22 us | 364.27 us | 295.71 us | 165.68 us | 103.45 us | 1.40 ms | 1.00 ms |
| prism-3 | 517.78 us | 234.98 us | **179.43 us** | 128.15 us | 1.01 ms | 753.36 us | 4.69 ms | 3.54 ms | 815.72 us | 398.13 us | 329.85 us | 214.80 us | 146.12 us | 72.87 us | 1.03 ms | 903.13 us |
| pubkey-1 | 277.08 us | 90.75 us | **83.31 us** | 46.00 us | 489.74 us | 298.69 us | 1.88 ms | 1.07 ms | 266.31 us | 173.55 us | 128.59 us | 92.67 us | 48.83 us | 19.61 us | 443.54 us | 357.52 us |
| stablecoin_1-1 | 1.36 ms | 599.16 us | **522.63 us** | 358.60 us | 4.89 ms | 4.05 ms | 12.71 ms | 9.43 ms | 2.11 ms | 1.11 ms | 917.80 us | 586.96 us | 382.73 us | 875.06 us | 5.71 ms | 4.71 ms |
| stablecoin_1-2 | 324.57 us | 126.17 us | **101.36 us** | 63.47 us | 616.49 us | 400.27 us | 2.47 ms | 1.67 ms | 385.30 us | 237.91 us | 189.27 us | 115.63 us | 68.99 us | 28.48 us | 605.70 us | 498.21 us |
| stablecoin_1-3 | 1.65 ms | 687.19 us | **583.19 us** | 406.17 us | 5.36 ms | 4.28 ms | 14.38 ms | 10.89 ms | 2.59 ms | 1.29 ms | 1.09 ms | 658.25 us | 448.33 us | 4.25 ms | 6.45 ms | 5.31 ms |
| stablecoin_1-4 | 333.39 us | 133.42 us | **105.42 us** | 69.31 us | 649.88 us | 423.53 us | 2.57 ms | 1.77 ms | 373.36 us | 253.58 us | 202.18 us | 117.66 us | 71.82 us | 28.73 us | 643.36 us | 542.07 us |
| stablecoin_1-5 | 1.84 ms | 847.21 us | **750.64 us** | 528.37 us | 6.16 ms | 4.92 ms | 17.28 ms | 14.04 ms | 3.00 ms | 1.65 ms | 1.41 ms | 793.63 us | 591.51 us | 2.50 ms | 7.57 ms | 6.17 ms |
| stablecoin_1-6 | 368.48 us | 161.50 us | **121.20 us** | 83.79 us | 754.78 us | 522.66 us | 3.05 ms | 2.18 ms | 459.71 us | 295.99 us | 245.57 us | 134.97 us | 88.56 us | 34.89 us | 775.07 us | 660.27 us |
| stablecoin_2-1 | 1.35 ms | 601.71 us | **523.19 us** | 367.75 us | 4.83 ms | 3.94 ms | 12.96 ms | 9.37 ms | 2.12 ms | 1.13 ms | 915.59 us | 592.74 us | 389.35 us | 1.65 ms | 5.71 ms | 4.69 ms |
| stablecoin_2-2 | 327.70 us | 125.34 us | **102.06 us** | 64.63 us | 629.28 us | 399.95 us | 2.47 ms | 1.66 ms | 354.59 us | 235.85 us | 186.72 us | 115.37 us | 69.01 us | 27.38 us | 606.49 us | 507.30 us |
| stablecoin_2-3 | 1.63 ms | 673.87 us | **569.57 us** | 395.11 us | 5.35 ms | 4.28 ms | 14.50 ms | 10.99 ms | 2.59 ms | 1.26 ms | 1.07 ms | 663.10 us | 456.39 us | 5.29 ms | 6.39 ms | 5.19 ms |
| stablecoin_2-4 | 330.31 us | 133.66 us | **107.11 us** | 67.76 us | 648.13 us | 413.40 us | 2.55 ms | 1.77 ms | 370.78 us | 248.50 us | 196.60 us | 119.36 us | 72.81 us | 28.73 us | 609.00 us | 513.23 us |
| token-account-1 | 380.95 us | 122.89 us | **113.11 us** | 64.33 us | 644.25 us | 368.74 us | 2.95 ms | 1.82 ms | 408.52 us | 229.26 us | 163.11 us | 142.93 us | 77.07 us | 38.45 us | 551.75 us | 446.09 us |
| token-account-2 | 470.19 us | 211.66 us | **162.10 us** | 116.12 us | 922.28 us | 652.38 us | 3.74 ms | 2.74 ms | 663.79 us | 336.13 us | 268.68 us | 199.13 us | 135.09 us | 66.11 us | 933.77 us | 785.97 us |
| uniswap-1 | 516.34 us | 246.25 us | **201.57 us** | 150.12 us | 1.09 ms | 791.96 us | 4.92 ms | 3.87 ms | 958.38 us | 380.85 us | 310.65 us | 247.15 us | 179.58 us | 93.83 us | 1.09 ms | 929.88 us |
| uniswap-2 | 410.50 us | 143.70 us | **124.27 us** | 73.97 us | 717.54 us | 446.36 us | 3.23 ms | 2.13 ms | 445.49 us | 265.50 us | 200.10 us | 151.10 us | 85.80 us | 41.77 us | 660.05 us | 536.13 us |
| uniswap-3 | 1.93 ms | 1.04 ms | **772.42 us** | 567.65 us | 4.57 ms | 3.59 ms | 18.35 ms | 15.44 ms | 3.54 ms | 1.57 ms | 1.41 ms | 954.77 us | 772.56 us | 402.39 us | 5.40 ms | 4.25 ms |
| uniswap-4 | 444.66 us | 209.11 us | **153.28 us** | 112.17 us | 942.64 us | 672.84 us | 3.51 ms | 2.63 ms | 584.15 us | 378.36 us | 326.38 us | 171.93 us | 117.84 us | 44.27 us | 1.04 ms | 914.93 us |
| uniswap-5 | 1.54 ms | 711.51 us | **521.89 us** | 383.48 us | 3.23 ms | 2.30 ms | 12.68 ms | 9.49 ms | 2.27 ms | 1.10 ms | 930.13 us | 667.77 us | 479.97 us | 252.07 us | 4.18 ms | 2.92 ms |
| uniswap-6 | 434.14 us | 203.35 us | **149.94 us** | 107.03 us | 905.46 us | 652.95 us | 3.44 ms | 2.64 ms | 560.17 us | 358.38 us | 301.53 us | 166.26 us | 114.52 us | 43.96 us | 925.17 us | 808.14 us |
| vesting-1 | 579.02 us | 218.05 us | **176.70 us** | 126.52 us | 1.02 ms | 646.84 us | 4.89 ms | 3.32 ms | 779.28 us | 346.01 us | 263.77 us | 239.06 us | 146.58 us | 79.50 us | 979.84 us | 778.37 us |

## VMs in this benchmark

| VM | Language | Runtime | Execution model | Version | Source | Home | Used by | Badges | Note |
|---|---|---|---|---|---|---|---|---|---|
| Scalus CEK (Scala / JVM) | Scala | GraalVM | Interpreter (CEK) | [v1.4.1](https://github.com/scalus3/scalus/releases/tag/v1.4.1) | [scalus3/scalus](https://github.com/scalus3/scalus) | [scalus.org](https://scalus.org) | [Hydrozoa](https://github.com/cardano-hydrozoa/hydrozoa) (L2), [Bifrost](https://github.com/FluidTokens/ft-bifrost-bridge) (bridge), [Cardano Client Lib](https://github.com/bloxbean/cardano-client-lib) (SDK), [Yaci Store](https://github.com/bloxbean/yaci-store) (indexer), [Yaci DevKit](https://github.com/bloxbean/yaci-devkit) (dev tool) | - | - |
| Plutigo CEK (Go) | Go | native | Interpreter (CEK) | [v0.1.10](https://github.com/blinklabs-io/plutigo/releases/tag/v0.1.10) | [blinklabs-io/plutigo](https://github.com/blinklabs-io/plutigo) | - | [Dingo](https://github.com/blinklabs-io/dingo) (node) | - | - |
| uplc-turbo AST walker (Rust) | Rust | native | Interpreter (AST walker) | [amaru-uplc-v0.4.0](https://github.com/pragma-org/uplc/releases/tag/amaru-uplc-v0.4.0) | [pragma-org/uplc](https://github.com/pragma-org/uplc) | - | [Amaru](https://github.com/pragma-org/amaru) (node) | - | - |
| plutus-core CEK (Haskell / GHC) | Haskell | GHC | Interpreter (CEK) | [1.70.0.0](https://github.com/IntersectMBO/plutus/releases/tag/1.70.0.0) | [IntersectMBO/plutus](https://github.com/IntersectMBO/plutus) | [plutus.cardano.intersectmbo.org](https://plutus.cardano.intersectmbo.org) | [cardano-node](https://github.com/IntersectMBO/cardano-node) (node) | - | - |
| Scalus CEK (Scala.js / Node V8) | Scala.js | Node (V8) | Interpreter (CEK) | [scalus 1.4.1 (npm)](https://github.com/scalus3/scalus/releases/tag/v1.4.1) | [scalus3/scalus](https://github.com/scalus3/scalus) | [scalus.org](https://scalus.org) | [Lucid Evolution](https://github.com/Anastasia-Labs/lucid-evolution) (SDK), [MeshJS](https://github.com/MeshJS/mesh) (SDK), [Evolution SDK](https://github.com/IntersectMBO/evolution-sdk) (SDK) | - | - |
| Aiken uplc CEK (Rust) | Rust | native | Interpreter (CEK) | [v1.1.24](https://github.com/aiken-lang/aiken/releases/tag/v1.1.24) | [aiken-lang/aiken](https://github.com/aiken-lang/aiken) | [aiken-lang.org](https://aiken-lang.org) | [Aiken](https://aiken-lang.org) (compiler), [Blaze SDK](https://github.com/butaneprotocol/blaze-cardano) (SDK) | - | Aiken v1.1.24 copies the CEK environment on every lambda application (quadratic in recursion depth). aiken main fixes it (PRs [#1451](https://github.com/aiken-lang/aiken/pull/1451), [#1452](https://github.com/aiken-lang/aiken/pull/1452): coop-6 92 ms -> 1.2 ms), but no release contains the fix yet. |
| Aiken uplc CEK (Rust → WASM / Node V8) | Rust → WASM | Node (V8) | Interpreter (CEK) | [@lucid-evolution/uplc 0.4.0](https://github.com/Anastasia-Labs/lucid-evolution/releases/tag/@lucid-evolution/uplc@0.4.0) | [Anastasia-Labs/lucid-evolution](https://github.com/Anastasia-Labs/lucid-evolution) | [anastasia-labs.github.io/lucid-evolution](https://anastasia-labs.github.io/lucid-evolution/) | [Lucid Evolution](https://github.com/Anastasia-Labs/lucid-evolution) (SDK) | decode cached (by the library) | Built from [colll78/aiken](https://github.com/colll78/aiken) (aiken main plus fixes), which includes the CEK fixes that v1.1.24 lacks. |
| Scalus UPLC→JVM JIT (Scala / JVM) | Scala | GraalVM | JIT compiler (UPLC → JVM bytecode) | [v1.4.1](https://github.com/scalus3/scalus/releases/tag/v1.4.1) | [scalus3/scalus](https://github.com/scalus3/scalus) | [scalus.org](https://scalus.org) | - | experimental, decode and compile excluded | - |
| blaze-plutus CEK (TypeScript / Node V8) | TypeScript | Node (V8) | Interpreter (CEK) | [@blaze-cardano/plutus 0.1.1](https://github.com/butaneprotocol/blaze-cardano/releases/tag/@blaze-cardano/plutus@0.1.1) | [butaneprotocol/blaze-cardano](https://github.com/butaneprotocol/blaze-cardano) | [blaze.butane.dev](https://blaze.butane.dev) | - | experimental | - |

---
Harness commit: [`c4872f309`](https://github.com/lantr-io/plutus-vm-benchmark/commit/c4872f309c7577b55f9874b4b1d77a6bdf0f84ba)

*Plutus VM Benchmark – maintained by [Lantr](https://lantr.io) – Alexander Nemish. Forked from [SAIB-Inc/cardano-plutus-vm-benchmark](https://github.com/SAIB-Inc/cardano-plutus-vm-benchmark) by SAIB Inc. and contributors. MIT License, original work © 2025 SAIB Inc., © 2026 Lantr. Source: [lantr-io/plutus-vm-benchmark](https://github.com/lantr-io/plutus-vm-benchmark)*