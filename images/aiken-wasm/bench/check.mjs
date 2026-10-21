// One evaluation per script; prints <vm>-check.csv to stdout.
// status is ok when the machine ran the program to a value.
import { evalOnce, loadScripts } from "./common.mjs";

console.log("vm,script,status,cpu,mem");
for (const [name, bytes] of loadScripts()) {
  try {
    const r = evalOnce(bytes);
    if (!r.ok) console.error(`CHECK_ERROR: ${name}: evaluation failed`);
    console.log(`aiken-wasm,${name},${r.ok ? "ok" : "error"},${r.cpu},${r.mem}`);
  } catch (e) {
    console.error(`CHECK_ERROR: ${name}: ${e}`);
    console.log(`aiken-wasm,${name},error,,`);
  }
}
