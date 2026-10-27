// The VM module of the shared timing loop (images/node-base/time.mjs): the operation of a loop.
// One loop only, d3: eval_program_raw on the flat bytes. The package caches the decoded program
// after the first call (warm-up), so the measured rounds time hash + evaluation, not the flat
// decode (common.mjs, README.md). The run script copies it to the eval-only file.
import { evaluate } from "./common.mjs";

export function operation(loop, flat) {
  if (loop !== "d3") throw new Error(`aiken-wasm has only the d3 loop, not ${loop}`);
  return () => evaluate(flat);
}
