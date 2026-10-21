// Shared by the vitest bench and the check script.
//
// One evaluation = eval_program_raw of @lucid-evolution/uplc on the bare flat
// program: the WASM side decodes the flat, converts it to named De Bruijn and
// runs the CEK machine with costing on. The corpus programs are fully applied,
// so there are no arguments.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { eval_program_raw, uplc_build_info } from "@lucid-evolution/uplc";

export { uplc_build_info };

export const DATA_DIR =
  process.env.DATA_DIR ?? "/bench/data/plutus_use_cases";
export const QUICK = process.env.BENCH_QUICK === "1";

const PLUTUS_V3 = 3;
// Newest protocol version the package supports for the default cost model
// (Van Rossem). uplc_build_info() reports it as protocolMajorVersion.
const PROTOCOL = 11;
// Large budget: every corpus script runs to the end, costing still counts.
const BUDGET_CPU = 10_000_000_000_000n;
const BUDGET_MEM = 14_000_000_000_000n;

// The PlutusV3 cost model (350 parameters, ledger order) of the package's own
// test fixture; equal to DEFAULT_V3 of the uplc crate the package is built from.
const COST_MODEL_PATH =
  process.env.COST_MODEL ?? new URL("./plutus-v3-cost-model.json", import.meta.url);
export const costModel = BigInt64Array.from(
  JSON.parse(readFileSync(COST_MODEL_PATH, "utf8")).map(BigInt),
);

/** Sorted [name, bytes] of every .flat file; first 5 with BENCH_QUICK=1. */
export function loadScripts() {
  const files = readdirSync(DATA_DIR)
    .filter((f) => f.endsWith(".flat"))
    .sort();
  return (QUICK ? files.slice(0, 5) : files).map((f) => [
    f.slice(0, -".flat".length),
    new Uint8Array(readFileSync(join(DATA_DIR, f))),
  ]);
}

/**
 * Decode + evaluate once. Returns { errorKind, cpu, mem } and frees the WASM
 * result object, so a timing loop does not grow the WASM heap.
 * errorKind: 0 ok, 1 over budget, 2 failed, 3 a PlutusV3 program that returned
 * something other than unit.
 */
export function evalOnce(bytes) {
  // strict_budget = false: check the budget every 200 steps, as the ledger and
  // the native aiken Machine do.
  const r = eval_program_raw(
    bytes, [], PLUTUS_V3, PROTOCOL, costModel, BUDGET_CPU, BUDGET_MEM, false,
  );
  try {
    return { errorKind: r.error_kind, cpu: r.cpu, mem: r.mem };
  } finally {
    r.free();
  }
}

/** The program ran to a value. Kind 3 is still a value: the reference does
 * not apply the ledger's "V3 must return unit" rule to these 1.0.0 programs. */
export const ranToValue = (errorKind) => errorKind === 0 || errorKind === 3;
