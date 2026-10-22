// Shared by the timed loop and the check, so both evaluate the same way.
//
// One evaluation = eval_program_raw of the published npm package @lucid-evolution/uplc, used as it
// is: flat decode, then a CEK run with costing on, as PlutusV3 at protocol version 11 with the
// mainnet PlutusV3 cost model (check/reference/mainnet-plutusv3-costmodel.json). The corpus
// programs are fully applied, so there are no arguments.
//
// The package keeps decoded programs in a cache keyed by a hash of the flat bytes. So only the
// first call on a script decodes it; every later call hashes the bytes, takes the decoded program
// from the cache and evaluates it. The timed loop therefore measures hash + evaluation, not
// decode + evaluation (report badge "decode cached (by the library)").
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { eval_program_raw, uplc_build_info } from "@lucid-evolution/uplc";

export const DATA_DIR = process.env.DATA_DIR ?? "/bench/data/plutus_use_cases";
const COST_MODEL_JSON = process.env.PVB_COSTMODEL_JSON ?? "/bench/mainnet-plutusv3-costmodel.json";

const PLUTUS_V3 = 3;
const PROTOCOL_MAJOR_VERSION = 11;
// The mainnet PlutusV3 cost model, 350 values in the ledger's order. Built once, at load.
const COST_MODEL = BigInt64Array.from(
  JSON.parse(readFileSync(COST_MODEL_JSON, "utf8")).PlutusV3,
  (v) => BigInt(v),
);
// Large enough that every script runs to its end (i64::MAX, the crate's ExBudget::max()).
const BUDGET = 9223372036854775807n;
// false: the ledger's way, the budget is checked every 200 steps. With a budget no script
// reaches, both settings give the same cost.
const STRICT_BUDGET = false;

// EvalProgramResult.error_kind (the package's .d.ts).
const OK = 0;
const NOT_UNIT = 3;

/** The uplc crate the package was built from, and its self-test (uplc_build_info()). */
export const buildInfo = () => uplc_build_info();

/** The scripts to run: [name, flat bytes], sorted by name. DATA_DIR holds only the selected ones. */
export function scripts() {
  const files = readdirSync(DATA_DIR).filter((f) => f.endsWith(".flat")).sort();
  return files.map((f) => [
    f.slice(0, -".flat".length),
    new Uint8Array(readFileSync(join(DATA_DIR, f))),
  ]);
}

/**
 * One evaluation. Returns { completed, errorKind, cpu, mem } and frees the WASM result object, so
 * a timing loop does not grow the WASM heap. Throws only when the input is malformed (the flat
 * does not decode).
 *
 * completed: the machine ran the program to a value. For PlutusV3 the package's `ok` also demands
 * a unit result (CIP-117). The plutus_use_cases programs are PlutusV1-era, and 78 of them return
 * a value that is not unit: error_kind 3, decided after the machine has finished, with the full
 * cost. That is not a machine failure, as for scalus-js (INVALID_RETURN_VALUE).
 */
export function evaluate(flat) {
  const r = eval_program_raw(
    flat, [], PLUTUS_V3, PROTOCOL_MAJOR_VERSION, COST_MODEL, BUDGET, BUDGET, STRICT_BUDGET,
  );
  try {
    const errorKind = r.error_kind;
    return { completed: errorKind === OK || errorKind === NOT_UNIT, errorKind, cpu: r.cpu, mem: r.mem };
  } finally {
    r.free();
  }
}
