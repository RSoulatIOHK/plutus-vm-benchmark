// One evaluation per script; prints <vm>-check.csv to stdout.
import { evalOnce, loadScripts, ranToValue } from "./common.mjs";

console.log("vm,script,status,cpu,mem");
for (const [name, bytes] of loadScripts()) {
  try {
    const r = evalOnce(bytes);
    const status = ranToValue(r.errorKind) ? "ok" : "error";
    if (status === "error") {
      console.error(`CHECK_ERROR: ${name}: error_kind ${r.errorKind}`);
    }
    console.log(`aiken-wasm,${name},${status},${r.cpu},${r.mem}`);
  } catch (e) {
    console.error(`CHECK_ERROR: ${name}: ${e}`);
    console.log(`aiken-wasm,${name},error,,`);
  }
}
