// One evaluation per script; writes vm,script,status,cpu,mem to stdout.
import { completed, evaluate, scripts } from "./common.mjs";

console.log("vm,script,status,cpu,mem");
for (const [name, flat] of scripts()) {
  try {
    const result = evaluate(flat);
    const status = completed(result) ? "ok" : "error";
    if (status === "error") console.error(`${name}: ${result.error?.code}: ${result.error?.message}`);
    console.log(`scalus-js,${name},${status},${result.budget.steps},${result.budget.memory}`);
  } catch (e) {
    console.error(`${name}: ${e}`);
    console.log(`scalus-js,${name},error,,`);
  }
}
