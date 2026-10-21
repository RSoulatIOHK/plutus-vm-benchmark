// plutus-vm-benchmark timing harness for blaze (V8 via node, JSC via bun). Copied into
// packages/blaze-plutus/bench/ (images/blaze/Dockerfile). docs/IMAGE_CONTRACT.md, spec D3.
//
// Per iteration: flat decode + evaluation with costing on, counting mode (unlimited budget), the
// mainnet PlutusV3 cost model (pvb-costs.ts). A script that fails its first evaluation prints
// "EVAL_FAIL: <name>" and is not timed. BENCH_QUICK=1 shortens the timing.

import { readdirSync, readFileSync } from "fs";
import { join } from "path";
import { bench, describe } from "vitest";
import { CekMachine } from "../src/cek";
import { decodeFlatDeBruijn } from "../src/flat";
import { unlimitedBudget } from "../src/types";
import { harnessCosts } from "./pvb-costs";

const dataDir = process.env.PVB_DATA_DIR ?? join(__dirname, "plutus_use_cases");
const files = readdirSync(dataDir)
  .filter((f) => f.endsWith(".flat"))
  .sort();
const costs = harnessCosts();
const options = process.env.BENCH_QUICK === "1" ? { time: 100, warmupTime: 20 } : {};

function evalOnce(bytes: Uint8Array): void {
  const program = decodeFlatDeBruijn(bytes);
  const machine = new CekMachine(unlimitedBudget(), costs);
  machine.run(program.term);
}

describe("plutus use cases", () => {
  for (const file of files) {
    const bytes = new Uint8Array(readFileSync(join(dataDir, file)));
    const name = file.replace(".flat", "");
    try {
      evalOnce(bytes);
    } catch (e) {
      console.log(`EVAL_FAIL: ${name}`);
      console.log(`  ${String(e).slice(0, 200)}`);
      continue;
    }
    bench(name, () => evalOnce(bytes), options);
  }
});
