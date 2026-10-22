# scalus-js

The Scalus CEK machine compiled with Scala.js, as published on npm as
[`scalus`](https://www.npmjs.com/package/scalus). It runs on Node.js 22 (V8), the same Node major
and the same timing loop as the `blaze-v8` harness, run by plain `node`. The image follows
`docs/IMAGE_CONTRACT.md`.

Pin in `.env`: `SCALUS_JS_VERSION` (the npm version).

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

## Timing

`time.mjs` uses the JMH shape of the JVM rows (`-wi 1 -w 20s -i 3 -r 5s`): one 20 s warm-up
round, then 3 measured rounds of 5 s. A round calls `evaluateScript` back to back until its time
is up; its score is elapsed time / calls, as in JMH `avgt`. The CSV has the mean of the 3 round
scores and their median, min, max and standard deviation; `iterations` is the number of rounds.
`run-scalus-js.sh` starts a new node process for each script, so no JIT profile or GC state
carries over from another script. `BENCH_TIMING=quick`: 0.5 s warm-up, one 0.5 s round.

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
