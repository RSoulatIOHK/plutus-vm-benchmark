# aiken-wasm

Aiken's UPLC evaluator as JavaScript users run it: the uplc crate compiled to WASM the same way as
the npm package [`@lucid-evolution/uplc`](https://www.npmjs.com/package/@lucid-evolution/uplc)
(the package Lucid Evolution evaluates scripts with), run in Node.

## Route: own WASM build of the same crate, not the published package as is

`@lucid-evolution/uplc` 0.4.0 exports `eval_program_raw`, which evaluates a bare flat program. But it
keeps decoded programs in a cache (`ProgramCache`, keyed by the hash of the flat bytes). After the
first call, a timing loop measures hash + clone + eval, not flat decode + eval. The benchmark must
time decode + eval (spec D3). So the image builds a small wrapper (`wasm/`) with the function
`eval_flat`. It makes the same calls as `eval_program_raw`, without the cache. (Two more functions
serve the eval-only timing, see below.)

The wrapper is representative of what Lucid users run, because it is built the same way:

| | `@lucid-evolution/uplc` 0.4.0 | this image |
|---|---|---|
| uplc crate | `colll78/aiken@28e42883` | `AIKEN_WASM_SHA` = the same rev |
| Dependency versions | `packages/uplc/rust/Cargo.lock` | the same file, at `LUCID_EVOLUTION_SHA` |
| Release profile | `opt-level 3`, `lto`, `codegen-units 1` | the same |
| Bindings | `wasm-pack --target nodejs` (the Node default export, `dist/speed/node`) | `wasm-bindgen --target nodejs`, the same wasm-bindgen version |
| Post-processing | `wasm-opt -O3` | `wasm-opt -O3` (binaryen `version_133`) |

The image build fails if the uplc rev that the published package reports (`uplc_build_info()`)
is not the rev it compiles. A bump of only `LUCID_UPLC_VERSION` or only `AIKEN_WASM_SHA` stops the
build.

The crate rev is aiken `main` after the v1.1.24 release, plus fixes for protocol versions 11 and
12. That `main` includes the CEK performance work, which is not released yet. The native `aiken`
image builds the release tag v1.1.24 of `aiken-lang/aiken` (`AIKEN_SHA`). The two rows are
therefore different code, not only different targets.

For comparison, the published package with its cache measures about 0.30 ms on `auction_1-1`
(Node 22, Apple M-series, in Docker). That is what a Lucid user sees on a repeated evaluation of
one script. The wrapper, which decodes in every iteration, measures about 0.69 ms.

## What is timed

`eval_flat(flat)` in a vitest bench (vitest 4.0.18 and Node 22 with default bench options, as in
the blaze-v8 harness):

1. Flat decode, then conversion to named De Bruijn.
2. A CEK run with costing on: PlutusV3, protocol version 11 (Van Rossem, the newest that the crate
   supports), and a budget check every 200 steps, as on the ledger.
3. The cost model is the crate's default PlutusV3 cost model for protocol 11. It has 350
   parameters and equals the fixture that the package tests against (plutus-core 1.71).
4. The budget is `ExBudget::max()`, so every script runs to the end. Costing is computed in full.

The corpus programs are fully applied, so there are no arguments. The result object is freed in
every iteration, so the WASM heap does not grow.

## Check output

`aiken-wasm-check.csv` holds one evaluation per script with the same call. `status` is `ok` when the
machine ran the program to a value. It is `error` when evaluation failed or the flat did not
decode. The ledger rule that a PlutusV3 script must return unit is not applied, because these are
1.0.0 programs. `cpu` and `mem` are the consumed budget.

## Eval-only timing

`aiken-wasm-eval.csv` times the evaluation without the decode (docs/IMAGE_CONTRACT.md). The
wrapper has two more functions for it, built in the same module from the same crate rev (so the
`uplc_build_info()` guard covers them too):

- `decode_flat(flat)` decodes once, before timing, and returns a handle to the decoded program.
- `eval_decoded(handle)` runs it as `eval_flat` does after its decode: a new machine, a fresh
  `ExBudget::max()` budget, the same protocol version and cost model. The decoded terms are
  `Rc`-shared, so the clone that the machine takes copies only the root node.

`eval_only.bench.mjs` times `eval_decoded` with the vitest options of `use_cases.bench.mjs`.
Before timing, it evaluates the decoded program twice and requires the same budget both times.
This is close to what the published package's `ProgramCache` path measures on a repeated script
(about 0.30 ms on `auction_1-1`, above), minus its hash of the flat bytes.

`median_ns` equals `mean_ns`, because the vitest text reporter shows no median. The blaze harness
does the same.
