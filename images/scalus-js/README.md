# scalus-js

The Scalus CEK machine compiled with Scala.js, as published on npm as
[`scalus`](https://www.npmjs.com/package/scalus). It runs on Node.js 22 (V8), the same Node major
and the same timing loop as the `blaze-v8` harness, run by plain `node`. The image follows
`docs/IMAGE_CONTRACT.md`.

Pin in `.env`: `SCALUS_SHA` (the Scalus source the package is built from) and `SCALUS_VERSION`.

```bash
scripts/images.sh build scalus-js
scripts/run-images.sh results/<date> scalus-js
```

## What is timed

One call of the public API per iteration, with one `PlutusVM` built at load:

```js
import { EvaluationOptions, PlutusVM, uplc } from "scalus";
const vm = new PlutusVM(EvaluationOptions.mainnet("PlutusV3")); // once, at load
vm.evaluateScript(flatBytes, []);                              // D3 loop: decode + eval, timed
const program = uplc.decodeProgram(flatBytes);                  // eval loop: decoded once...
vm.evaluateScript(program, []);                                 // ...then timed
```

`EvaluationOptions.mainnet("PlutusV3")` is the mainnet snapshot bundled in the package: protocol
version 11 and the PlutusV3 cost model. Costing is on: the `PlutusVM` has a `maxBudget` too large to run out (2^63 − 1 steps and
memory), so it restricts, as the node does, but never stops a script.
`evaluator.evaluateScript(script, args, options)` would build the machine from the cost model on
every call; a `PlutusVM` builds it once, as a downstream user evaluating many scripts would.

The image builds the package from Scalus source at `SCALUS_SHA` (`.env`), with the npm bundle task
of the Scalus build.

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
