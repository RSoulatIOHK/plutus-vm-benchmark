// Timed loop: flat decode + evaluation with costing on, one bench per script.
// Same vitest bench defaults as the blaze-v8 harness (bench/plutus_use_cases.bench.ts).
import { bench, describe } from "vitest";
import { QUICK, evaluate, scripts } from "./common.mjs";

const options = QUICK ? { time: 50, warmupTime: 10 } : {};

describe("plutus use cases", () => {
  for (const [name, flat] of scripts()) {
    bench(name, () => {
      evaluate(flat);
    }, options);
  }
});
