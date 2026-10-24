// Shared by the timed bench and the check, so both evaluate the same way.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
// A namespace import: PlutusVM and uplc.decodeProgram exist only in the branch build
// (images/scalus-js/Dockerfile), and a named import of a missing export fails at load.
import * as scalus from "scalus";

export const DATA_DIR = process.env.DATA_DIR ?? "/bench/data/plutus_use_cases";
// Short timing (scripts/image-entry.sh, BENCH_TIMING=quick).
export const QUICK = process.env.BENCH_TIMING === "quick";
// The VM name of the CSV rows: scalus-js (branch build) or scalus-js-140 (npm 1.4.0).
export const VM = process.env.PVB_JS_VM ?? "scalus-js";

// Latest PlutusV3 machine: the mainnet protocol parameters bundled in the package
// (protocol version 11, the PlutusV3 cost model).
export const OPTIONS = scalus.EvaluationOptions.mainnet("PlutusV3");

// The branch build has PlutusVM: a machine built once, at load, and reused by every call.
// scalus 1.4.0 has only evaluator.evaluateScript, which turns OPTIONS into machine parameters on
// every call.
export const HAS_PLUTUS_VM = typeof scalus.PlutusVM === "function";
const MACHINE = HAS_PLUTUS_VM ? new scalus.PlutusVM(OPTIONS) : null;

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
  return HAS_PLUTUS_VM ? MACHINE.evaluateScript(flat, []) : scalus.evaluator.evaluateScript(flat, [], OPTIONS);
}

/** Flat decode only, outside the timing of the eval loop. Branch build only. */
export function decode(flat) {
  return scalus.uplc.decodeProgram(flat);
}

/** One evaluation of a decoded program, with costing (the eval loop). Branch build only. */
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
