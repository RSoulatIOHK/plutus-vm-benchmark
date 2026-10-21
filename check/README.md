# Correctness gate

Spec decision D4: the result and the ExUnits of every script must equal Haskell. A VM that fails is
not published.

| File | What it is |
|---|---|
| `reference/haskell-check.csv` | The reference: `vm,script,status,cpu,mem` for the 89 scripts, from Haskell plutus 1.63.0.0 |
| `reference/Dockerfile`, `reference/gate-ref/` | The Haskell program that produces the reference |
| `reference/regenerate.sh` | Rebuilds the image and rewrites `reference/haskell-check.csv` |
| `reference/mainnet-plutusv3-costmodel.json` | The mainnet PlutusV3 cost model the reference uses |
| `scalus-crosscheck.sc` | Independent cross-check of the reference with the released Scalus 1.4.0 CEK |
| `gate.py`, `test_gate.py` | The compare tool and its test |

## Evaluation parameters

Every VM evaluates every script with these parameters, in the timed loop and in the check
(`docs/IMAGE_CONTRACT.md`).

| Parameter | Value |
|---|---|
| Input | `data/plutus_use_cases/<script>.flat`: a flat-encoded, fully applied program. Evaluate its term; apply no arguments |
| Ledger language | PlutusV3 |
| Protocol version | 11 (`vanRossemPV`). This selects builtin semantics variant E and enables case on builtin types |
| Cost model | The mainnet PlutusV3 cost model: 350 parameters, mainnet epoch 662, protocol version 11.0 (`reference/mainnet-plutusv3-costmodel.json`) |
| Budget mode | Counting: no limit, add up the cost. On success this gives the same numbers as the node's restricting mode |
| `status` | `ok` if the evaluation returns a term, `error` if it fails. The PlutusV3 ledger rule that the result must be `unit` (CIP-117) is **not** applied, see below |
| `cpu`, `mem` | The total ExUnits of one evaluation, including the machine startup cost |

The mainnet cost model is the same as the default PlutusV3 cost model of plutus 1.63.0.0 (variant E:
`builtinCostModelE.json` and `cekMachineCostsE.json`). Two checks show it:

- `gate-ref` evaluates every script with both and finds 0 differences (it exits 2 otherwise).
- In Scalus 1.4.0 the `MachineParams` built from the mainnet array are equal to the ones built from
  the two JSON files, and give the same ExUnits for all 89 scripts.

So "the latest PlutusV3 cost model that the VM ships" and "the mainnet cost model" are the same
numbers today. A VM that ships an older PlutusV3 default (variant C, before plutus 1.60) fails the
gate: C and E differ for `equalsByteString`, `divideInteger`, `modInteger`, `quotientInteger` and
`remainderInteger`.

### Why these parameters

- D3 asks for the node-equivalent evaluation. The production node (11.x) runs plutus 1.63.0.0 at
  protocol version 11, and mainnet scripts of today are PlutusV3.
- 11 of the 89 scripts (`coop-*`, `guardrail-*`) are UPLC 1.1.0 programs (`constr`/`case`). The
  other 78 are UPLC 1.0.0. PlutusV3 evaluates both.
- `gate-ref` uses the node's own code path: `PlutusLedgerApi.V3.mkEvaluationContext` over the
  on-chain array, then `evaluateTerm` at protocol version 11.
- No CIP-117 result check. 78 of the 89 scripts are PlutusV1-era validators: they return
  `delay (\x -> x)`, not `unit` (only the 11 UPLC 1.1.0 scripts return `unit`). The node would
  reject them as PlutusV3 scripts. The benchmark measures the evaluator, so `status` is the CEK
  result only. The check does not change `cpu` or `mem`: it runs after the evaluation. None of the
  audited VMs applies it in its evaluator.
- `gate-ref` is built with GHC 9.6.7 (latest 9.6, the series plutus 1.63.0.0 uses); `.env` has
  9.6.4 for the timing image. The GHC version does not change ExUnits.

## What the existing Haskell benchmark does

`scripts/run-haskell.sh` runs `plutus-benchmark:bench:validation` (`plutus-benchmark/validation/bench/BenchCek.hs`):

- Evaluation context: `mkEvalCtx PlutusV3 DefaultFunSemanticsVariantE`: the cost model compiled
  into plutus-core for variant E, through `mkDynEvaluationContext`.
- Budget mode: `restrictingEnormous` (costing on, with a budget too large to run out).
  `evaluateTerm` is called through `evaluateCekLikeInProd`. The protocol version argument is
  PlutusV1's (Alonzo), but the semantics variant is fixed to E, so it does not change the result.
- It times flat-decoded, name-converted terms; flat decoding is outside the timed loop.

At the current `.env` pin (`HASKELL_SHA=318c729`, 2026-03-10, before release 1.60.0.0) plutus-core has
no variant E files: `DataFilePaths.hs` maps variant E to `builtinCostModelC.json` and
`cekMachineCostsC.json`. So the Haskell timing today runs with the **old** PlutusV3 cost model. Its ExUnits would fail this
gate on all 89 scripts (measured with the C files in Scalus 1.4.0: every script uses at least one
of the five builtins above).

**Recommendation:** move `HASKELL_SHA` to the release tag 1.63.0.0
(`ac40fae4dea9dcad51b38a9c5c48148655cb13a2`), the plutus version of the production node. Release
1.63.0.0 exists in IntersectMBO/plutus (newer tags up to 1.69.0.0 exist, but the node does not use
them yet). Check the two `cabal.project` `sed` lines of the Haskell image at that tag: there the
flags line is `flags: +with-inline-r +with-cert`.

## Regenerate the reference

```bash
check/reference/regenerate.sh          # needs Docker; CABAL_JOBS=2 by default
```

The first build compiles plutus-core and plutus-ledger-api (about 10 minutes in Docker on an
M-series Mac). To use a new cost model, update `reference/mainnet-plutusv3-costmodel.json`, for example from
`https://api.koios.rest/api/v1/cli_protocol_params` (`.costModels.PlutusV3`).

## Cross-check with Scalus

```bash
scala-cli run check/scalus-crosscheck.sc -- data/plutus_use_cases > /tmp/scalus-check.csv
python3 check/gate.py /tmp/scalus-check.csv
```

## Run the gate

```bash
python3 check/gate.py --json results/<date>/gate.json results/<date>/*-check.csv
python3 -m unittest discover -s check -p 'test_*.py'
```

Output: one line per VM (`PASS`/`FAIL`, matching count, the first mismatching scripts). The JSON
has the full list. Exit code 1 if any VM fails, 2 on bad input. A row with empty `cpu`/`mem` fails
the VM as "no costing". A script that is in the reference but not in the VM's file fails as
"missing".

## Audit of the existing harnesses (2026-10-21, pins in `.env`)

Does the timed loop run with costing on, and how does each VM get a `<vm>-check.csv`?

| VM | Timed loop | Parameters in the timed loop | ExUnits API | Recipe for `<vm>-check.csv` | Predicted gate result at the pin |
|---|---|---|---|---|---|
| haskell | Costing on (`restrictingEnormous`) | PlutusV3, variant E, compiled-in cost model. At the current pin E = the old C files: **fails the gate until `HASKELL_SHA` moves to 1.63.0.0** | `CekReport` cost: `CountingSt` with `counting` | Use `gate-ref` from this directory (same code path, same image base). Small | Fail on 89 at the current pin (variant C files); pass at 1.63.0.0 |
| scalus-cek | Costing on (`RestrictingBudgetSpender(ExUnits.enormous)`) | **`makePlutusV1VM(vanRossemPV)`**: mainnet PlutusV1 cost model, variant D. Must change to `makePlutusV3VM(vanRossemPV)` | `BudgetSpender.getSpentBudget` (`CountingBudgetSpender`) | Same loop with a `CountingBudgetSpender`, print `steps`/`memory` (see `scalus-crosscheck.sc`). Trivial | Fail (PlutusV1 cost model) until the harness uses `makePlutusV3VM`; Scalus 1.4.0 with V3 passes 89/89 |
| scalus-jit | **Costing off** (`NoBudgetSpender`, `JITBenchmark.scala:43`) | Mainnet PlutusV3, PV11 | Pass a `CountingBudgetSpender` to the compiled function, then `getSpentBudget` | Same call with a `CountingBudgetSpender`. Trivial. The timed loop must also switch to a real spender (D3) | Likely pass (mainnet V3 params, same as scalus-cek V3) |
| uplc-turbo | Costing on, capped at the transaction limit (`ExBudget::default()`, 14M mem / 10G cpu) | V3, built-in `BuiltinCostsV3::default()` | `EvalResult.info.consumed_budget` | Example binary: eval each file, print `consumed_budget.cpu/mem`. Small | Likely pass: its V3 table has the variant E constants |
| plutigo | Costing on, capped at the transaction limit (`DefaultExBudget`) | **Language taken from the program version**: UPLC 1.0.0 runs as V1, 1.1.0 as V2, variant B, protocol version 200; one `DefaultCostModel`. Must pass V3 explicitly | None; `Machine.ExBudget` is the remaining budget, spent = `DefaultExBudget - m.ExBudget` | Go test or main: decode, `NewMachine`, `Run`, subtract. Small | Fail: ships variant C constants only, and evaluates as V1/V2 |
| blaze (V8, JSC) | Costing on, unlimited budget (counting) | `DEFAULT_BUILTIN_COSTS`, "Default PlutusV3 (Conway era)" | `CekMachine.remainingBudget`, spent = `I64_MAX - remaining` | Existing CLI `bun scripts/eval.ts --flat -p f.flat` prints `cpu`/`mem`; loop over files. Trivial | Fail: ships variant C constants only |
| julc-java | Costing on, unlimited budget (`null` budget) | PlutusV3, `DefaultCostModel` | `EvalResult.budgetConsumed()`, `isSuccess()` | Single-file Java with the same `evaluate` call. Trivial | Fail: ships variant C constants only |
| opshin | Costing on, capped at the transaction limit (`default_budget()`) | V3 CEK and builtin cost models | `ComputationResult.cost` (budget minus remaining), `.result` holds the term or the exception | Python loop over `uplc.tools.eval`, status from `isinstance(r.result, Exception)`. Do not use the `uplc eval` CLI: it defaults to the PlutusV2 cost model. Trivial | Fail: ships variant C constants only (cost model files 2024-07-30) |

The prediction comes from the cost model constants in each pinned repo: variant E has
`divideInteger` = 30623/28755/75, variant C has 24548/29498/38. A VM with only C constants differs
from the reference on all 89 scripts (measured with the C files in Scalus 1.4.0).
Such a VM can pass without a new release if its API takes a cost model array: give it
`reference/mainnet-plutusv3-costmodel.json` (plutigo has `NewEvalContext` with protocol parameter
cost models; opshin reads cost model files). Check this per VM when its emitter is written.

Other findings:

- julc and opshin do not check the evaluation result in the timed loop (`EvalResult.Failure` and
  `.result` hold the error without a throw). A failing script would be timed as if it passed. The
  check closes this gap.
- uplc-turbo's bench calls `.expect` on the result, so one failing script stops the Criterion run;
  `run-uplc-turbo.sh` hides it with `|| true` and `fill_failures`.
- Flat decoding is inside the timed loop for uplc-turbo, plutigo, blaze and opshin, and outside it
  for haskell, scalus and julc. D3 asks for decode + evaluate.
- A cap at the transaction limit (14M mem / 10G cpu) does not change ExUnits for scripts that fit.
  All 89 scripts fit: the largest is `coop-3` with 2.15G cpu and 11.7M mem.
