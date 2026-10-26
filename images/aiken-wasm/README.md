# aiken-wasm

Aiken's UPLC evaluator compiled to WASM, as published on npm as
[`@lucid-evolution/uplc`](https://www.npmjs.com/package/@lucid-evolution/uplc) (the package Lucid
Evolution evaluates scripts with). The image uses the package as it is: no own WASM build
(spec D17). It runs on Node.js 22 (V8), with the same timing loop as the `scalus-js`
and `blaze-v8` harnesses. The image follows `docs/IMAGE_CONTRACT.md`.

Pin in `.env`: `LUCID_UPLC_VERSION` (the npm version).

```bash
scripts/images.sh build aiken-wasm
scripts/run-images.sh results/<date> aiken-wasm
```

`@lucid-evolution/uplc` 0.4.0 is built from `colll78/aiken@28e42883` (`uplc_build_info()`): aiken
`main` after v1.1.24 plus fixes for protocol versions 11 and 12. That code has the CEK fixes that
the v1.1.24 release lacks, so the `aiken` (native, v1.1.24) and `aiken-wasm` rows are different
code, not only different targets. The image build fails if the package's self-test
(`uplc_build_info().selfTest`) does not pass.

## What is timed

One call of the public API per iteration, on the raw `.flat` bytes:

```js
import { eval_program_raw } from "@lucid-evolution/uplc";
// once, at load: the mainnet PlutusV3 cost model (350 values)
const costModel = BigInt64Array.from(json.PlutusV3, BigInt);
// timed
eval_program_raw(flat, [], 3 /* PlutusV3 */, 11 /* protocol */, costModel,
                 2n ** 63n - 1n, 2n ** 63n - 1n, false /* strict_budget */);
```

- The cost model is `check/reference/mainnet-plutusv3-costmodel.json`, copied into the image.
- The budget is `i64::MAX` for CPU and memory, so every script runs to its end. Costing is on.
- `strict_budget = false`: the ledger's way, the budget is checked every 200 steps. With a budget
  that no script reaches, both settings give the same cost.
- The corpus programs are fully applied, so there are no arguments.
- The result object is freed in every iteration, so the WASM heap does not grow.

### The decode cache: "decode cached (by the library)"

The package keeps decoded programs in a cache (`ProgramCache`), keyed by a hash of the flat
bytes. The cache cannot be turned off. Only the first call on a script decodes it; the warm-up
round makes that call. Every measured call hashes the bytes, takes the decoded program from the
cache and evaluates it. So the time is hash + evaluation, not flat decode + evaluation.

The report shows the row with the badge "decode cached (by the library)" and ranks it only on eval
only (spec D21), as it does for the Scalus JIT ("decode and compile excluded"): the time does not
include the decode, so it is not in the decode + eval ranking. It is also what a Lucid user gets
when one script is evaluated again and again.

`run-aiken-wasm.sh` starts a new node process per script, so the cache of one script never
serves another.

## Timing

`time.mjs` is the loop of `images/scalus-js/time.mjs`: the JMH shape of the JVM rows
(`-wi 1 -w 20s -i 3 -r 5s`). One 20 s warm-up round, then 3 measured rounds of 5 s. A round calls
`eval_program_raw` back to back until its time is up; its score is elapsed time / calls, as in JMH
`avgt`. `BENCH_TIMING=quick`: 0.5 s warm-up, one 0.5 s round.

### Eval-only column: the same loop

With the decode cached, the timed loop already is an eval-only loop. `run-aiken-wasm.sh` runs it
once and writes the same rows to `aiken-wasm.csv` (D3) and `aiken-wasm-eval.csv` (eval only), as
`run-scalus-jit.sh` does. So the two columns of the report have the same numbers.

## The check and CIP-117

`check.mjs` evaluates each script once with the same call and writes `aiken-wasm-check.csv` with
the `cpu` and `mem` that the result reports.

For PlutusV3, the package's `ok` also requires a unit result (CIP-117). The `plutus_use_cases`
programs are PlutusV1-era: 11 of them return unit, 78 return another value. The harness uses
`error_kind` of `EvalProgramResult` instead of `ok`:

| `error_kind` | meaning (package `.d.ts`) | status |
|---|---|---|
| 0 | success | `ok` |
| 3 | PlutusV3 program returned something other than unit; decided after the machine finished, with the full cost | `ok` |
| 1 | over budget | `error` |
| 2 | any other failure (for example the `error` term) | `error` |

This is the same rule as `scalus-js` (`INVALID_RETURN_VALUE` is `ok`). A flat that does not decode
makes `eval_program_raw` throw: `error` with empty `cpu` and `mem`.

Locally (Node 24, macOS arm64), the check gives 89/89 rows equal to
`check/reference/haskell-check.csv` (status, cpu and mem).
