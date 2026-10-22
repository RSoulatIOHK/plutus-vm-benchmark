// One evaluation per script; writes vm,script,status,cpu,mem to stdout.
// status is ok when the machine ran the program to a value (common.mjs, evaluate).
import { evaluate, scripts } from "./common.mjs";

// EvalProgramResult.error_kind values that are a failure.
const KINDS = { 1: "over budget", 2: "evaluation failure" };

console.log("vm,script,status,cpu,mem");
for (const [name, flat] of scripts()) {
  try {
    const r = evaluate(flat);
    if (!r.completed) console.error(`${name}: ${KINDS[r.errorKind] ?? `error_kind ${r.errorKind}`}`);
    console.log(`aiken-wasm,${name},${r.completed ? "ok" : "error"},${r.cpu},${r.mem}`);
  } catch (e) {
    console.error(`${name}: ${e}`);
    console.log(`aiken-wasm,${name},error,,`);
  }
}
