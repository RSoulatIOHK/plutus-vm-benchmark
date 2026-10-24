// Shared by the timed bench and the check, so both evaluate the same way.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { EvaluationOptions, PlutusVM, uplc } from "scalus";

export const DATA_DIR = process.env.DATA_DIR ?? "/bench/data/plutus_use_cases";
// Short timing (scripts/image-entry.sh, BENCH_TIMING=quick).
export const QUICK = process.env.BENCH_TIMING === "quick";

// Latest PlutusV3 machine: the mainnet protocol parameters bundled in the package
// (protocol version 11, the PlutusV3 cost model). The PlutusVM is built once, at load, and every
// evaluation reuses it, as a downstream user evaluating many scripts would.
// A maxBudget makes the machine restrict (RestrictingBudgetSpender), as the node does; this one is
// too large to run out.
const ENORMOUS = 9223372036854775807n;
export const OPTIONS = { ...EvaluationOptions.mainnet("PlutusV3"), maxBudget: { memory: ENORMOUS, steps: ENORMOUS } };
const MACHINE = new PlutusVM(OPTIONS);

/** The scripts to run: [name, flat bytes], sorted by name. DATA_DIR holds only the selected ones. */
export function scripts() {
  const files = readdirSync(DATA_DIR).filter((f) => f.endsWith(".flat")).sort();
  return files.map((f) => [
    f.slice(0, -".flat".length),
    new Uint8Array(readFileSync(join(DATA_DIR, f))),
  ]);
}

/** One evaluation: flat decode + CEK evaluation with costing (the D3 loop). Never throws on a script failure. */
export function evaluate(flat) {
  return MACHINE.evaluateScript(flat, []);
}

/** Flat decode only, outside the timing of the eval loop. */
export function decode(flat) {
  return uplc.decodeProgram(flat);
}

/** One evaluation of a decoded program, with costing (the eval loop). */
export function evaluateProgram(program) {
  return MACHINE.evaluateScript(program, []);
}

/**
 * Whether the machine ran the program to completion. PlutusV3 also demands that a script
 * return unit (CIP-117); the plutus_use_cases programs are PlutusV1-era and return the
 * Scott-encoded unit `(delay (lam x x))`, which Scalus reports as INVALID_RETURN_VALUE after
 * the machine has finished, with the full budget. That is not a machine failure.
 */
export function completed(result) {
  return result.isSuccess || result.error?.code === "INVALID_RETURN_VALUE";
}
