# scalus-js

The Scalus CEK machine compiled with Scala.js, as published on npm as
[`scalus`](https://www.npmjs.com/package/scalus). It runs on Node.js 22 (V8), the same Node major
and the same benchmark tool (vitest 4.0.18 `bench`, default options) as the `blaze-v8` harness.
The image follows `docs/IMAGE_CONTRACT.md`.

Pins in `.env`: `SCALUS_JS_VERSION` (the npm version) and `VITEST_VERSION`.

```bash
scripts/images.sh build scalus-js
scripts/run-images.sh results/<date> scalus-js
```

## What is timed

One call of the public API per iteration, on the raw `.flat` bytes (no CBOR wrapping needed: the
API takes raw flat, single CBOR or double CBOR):

```js
import { evaluator, EvaluationOptions } from "scalus";
const options = EvaluationOptions.mainnet("PlutusV3"); // once, at load
evaluator.evaluateScript(flatBytes, [], options);      // timed
```

`EvaluationOptions.mainnet("PlutusV3")` is the mainnet snapshot bundled in the package: protocol
version 11 and the PlutusV3 cost model. Costing is on (a counting budget spender, no limit).

The call does flat decode + CEK evaluation, and also turns the cost-model array into machine
parameters on every call. The public API has no way to reuse a machine for single scripts, so a
downstream npm user pays this too. Measured on an M-series Mac in Docker: about 114 µs per call.

## The check and CIP-117

`check.mjs` evaluates each script once and writes `scalus-js-check.csv` with the `budget` that
`evaluateScript` reports (`cpu` = steps, `mem` = memory).

PlutusV3 requires a script to return unit (CIP-117). The `plutus_use_cases` programs are
PlutusV1-era and most of them return the Scott-encoded unit `(delay (lam x x))`, so Scalus reports
`isSuccess: false` with `error.code === "INVALID_RETURN_VALUE"`. That check runs after the machine
has finished, and the budget is the full evaluation cost. The harness reports these scripts as
`ok`. Any other error code (`SCRIPT_FAILURE`, `BUILTIN_FAILURE`, `OUT_OF_BUDGET`,
`INTERNAL_ERROR`) is `error`.

## No eval-only timing

The image writes no `scalus-js-eval.csv` (docs/IMAGE_CONTRACT.md allows a missing file). The
public API of `scalus` 1.4.0 cannot evaluate a program that was decoded before:

- `evaluator.evaluateScript` takes the script bytes (hex or bytes of flat, single or double CBOR)
  and decodes them on every call.
- `uplc.decodeToFlat` and `uplc.applyArgs` return flat bytes, not a decoded program.
- `TxEvaluator` with a `ScriptCache` keeps decoded scripts across evaluations, but it evaluates
  the scripts of a transaction, not a bare program.

The harness does not reach into the Scala.js internals of the bundle.
