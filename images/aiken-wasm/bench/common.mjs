// Shared by the vitest bench and the check script.
//
// One evaluation = eval_flat of the WASM module built in the image
// (images/aiken-wasm/wasm): flat decode, conversion to named De Bruijn and a
// CEK run with costing on, PlutusV3 at protocol version 11 with the crate's
// default cost model. The corpus programs are fully applied (no arguments).
import { readdirSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { join } from "node:path";

// wasm-bindgen --target nodejs output is CommonJS.
const wasm = createRequire(import.meta.url)(
  process.env.AIKEN_WASM_PKG ?? "./pkg/aiken_wasm_bench.js",
);

export const buildInfo = () => wasm.build_info();

export const DATA_DIR =
  process.env.DATA_DIR ?? "/bench/data/plutus_use_cases";
export const QUICK = process.env.BENCH_QUICK === "1";

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
 * Decode + evaluate once. Returns { ok, cpu, mem } and frees the WASM result
 * object, so a timing loop does not grow the WASM heap. Throws when the flat
 * does not decode.
 */
export function evalOnce(bytes) {
  const r = wasm.eval_flat(bytes);
  try {
    return { ok: r.ok, cpu: r.cpu, mem: r.mem };
  } finally {
    r.free();
  }
}
