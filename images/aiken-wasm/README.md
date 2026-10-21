# aiken-wasm

Aiken's UPLC evaluator as JavaScript users run it: the published npm package
[`@lucid-evolution/uplc`](https://www.npmjs.com/package/@lucid-evolution/uplc), in Node.

## Route: the published package, no own WASM build

The package used to expose only transaction-level entry points (`eval_phase_two_raw`). Since 0.4.0
it also exports `eval_program_raw`, which decodes and evaluates a bare flat program. So the
benchmark calls the published package directly, and builds no WASM wrapper of its own.

This is representative of what Lucid Evolution users run:

- **Same artifact.** On Node the package resolves to `dist/speed/node`, a `wasm-pack --target nodejs`
  build with `-O3` and `wasm-opt -O3`. Lucid Evolution evaluates scripts with exactly this module.
  (Browser bundles get `dist/size`, an `-Oz` build. It is not measured here.)
- **Same crate.** `uplc_build_info()` reports the crate that the package is built from. The run
  writes it at the top of `aiken-wasm-raw.log`. For 0.4.0 it is `uplc 1.1.24` from
  `colll78/aiken@28e42883`. That is aiken `main` after the v1.1.24 release (it includes the CEK
  performance work that is not released yet), plus fixes for protocol versions 11 and 12.

The native `aiken` image builds the release tag `AIKEN_SHA` (v1.1.24) of `aiken-lang/aiken`.
That is a different revision of the crate, so the two rows are different code, not only
different targets.

## What is timed

`eval_program_raw(flat, [], 3, 11, costModel, 10^13, 1.4·10^13, false)`, in a vitest bench
(vitest 4.0.18 and Node 22 with default bench options, as in the blaze-v8 harness):

- `flat`: the bytes of the `.flat` file. The corpus programs are fully applied, so there are no
  arguments.
- Inside the WASM module: flat decode, conversion to named De Bruijn, CEK run with costing.
- PlutusV3, protocol version 11 (the newest one that `uplc_build_info()` reports).
- `strict_budget = false`: the budget is checked every 200 steps, as the ledger does.
- The budget is large, so every script runs to the end. Costing is computed in full.
- The result object is freed in every iteration, so the WASM heap does not grow.

## Cost model

The package does not include a cost model. The image downloads the PlutusV3 cost model of the
package's own test fixture,
`packages/uplc/test/fixtures/plutus-v3-cost-model.json`, at `LUCID_EVOLUTION_SHA`. It has 350
parameters (plutus-core 1.71). It is equal to `DEFAULT_V3` of the crate revision that the package is
built from. Upstream v1.1.24 has different values at parameters 319 and up. Those parameters
cost the newest builtins.

In a real Lucid transaction, the cost model comes from the protocol parameters on the chain. The
correctness gate compares the ExUnits with the Haskell reference. That comparison shows whether the
fixture gives the same costs on this corpus.

## Check output

`aiken-wasm-check.csv` holds one evaluation per script, with the same call:

| `error_kind` | Meaning | `status` |
|---|---|---|
| 0 | the program returned unit | `ok` |
| 3 | the program returned a value other than unit | `ok` |
| 1 | over budget | `error` |
| 2 | evaluation failed | `error` |

Kind 3 counts as `ok`. The reference checks that evaluation succeeds. It does not apply the ledger
rule that a PlutusV3 script must return unit, because these are 1.0.0 programs. `cpu` and `mem`
are the consumed budget.

`median_ns` equals `mean_ns`, because the vitest text reporter shows no median. The blaze harness
does the same.
