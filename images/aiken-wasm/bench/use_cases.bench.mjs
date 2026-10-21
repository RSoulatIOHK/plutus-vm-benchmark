// vitest bench, same runner and defaults as the blaze-v8 harness.
import { bench, describe } from "vitest";
import { QUICK, evalOnce, loadScripts } from "./common.mjs";

const opts = QUICK ? { time: 500, warmupTime: 100, iterations: 5 } : {};

describe("plutus use cases", () => {
  for (const [name, bytes] of loadScripts()) {
    let first;
    try {
      first = evalOnce(bytes);
    } catch (e) {
      console.log(`EVAL_FAIL: ${name} (${e})`);
      continue;
    }
    if (!first.ok) {
      console.log(`EVAL_FAIL: ${name} (evaluation failed)`);
      continue;
    }
    bench(name, () => {
      evalOnce(bytes);
    }, opts);
  }
});
