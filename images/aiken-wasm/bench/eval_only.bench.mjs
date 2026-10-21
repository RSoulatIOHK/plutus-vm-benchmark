// Eval-only timing (docs/IMAGE_CONTRACT.md, <vm>-eval.csv): the program is
// decoded once, before timing; each iteration runs it on a fresh machine with
// a fresh budget. Same runner and options as use_cases.bench.mjs, so D3 minus
// this is the decode.
//
// Before timing, the decoded program is evaluated twice and the two spent
// budgets must be equal, which shows a run leaves the program as it was.
// The decoded programs (one per script) live until the process exits.
import { bench, describe } from "vitest";
import { QUICK, decodeOnce, evalDecoded, loadScripts } from "./common.mjs";

const opts = QUICK ? { time: 500, warmupTime: 100, iterations: 5 } : {};

describe("plutus use cases (eval only)", () => {
  for (const [name, bytes] of loadScripts()) {
    let program;
    try {
      program = decodeOnce(bytes);
    } catch (e) {
      console.log(`EVAL_FAIL: ${name} (${e})`);
      continue;
    }
    const first = evalDecoded(program);
    const second = evalDecoded(program);
    if (!first.ok) {
      console.log(`EVAL_FAIL: ${name} (evaluation failed)`);
      continue;
    }
    if (first.cpu !== second.cpu || first.mem !== second.mem || !second.ok) {
      console.log(`EVAL_FAIL: ${name} (second evaluation of the decoded program differs)`);
      continue;
    }
    bench(name, () => {
      evalDecoded(program);
    }, opts);
  }
});
