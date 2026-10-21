// plutus-vm-benchmark eval-only timing for blaze (V8 via node, JSC via bun). Copied into
// packages/blaze-plutus/bench/ (images/blaze/Dockerfile). docs/IMAGE_CONTRACT.md, <vm>-eval.csv.
//
// The program is flat-decoded once, before timing. Per iteration: a fresh CekMachine (fresh
// budget, counting mode) runs the decoded term, with the cost table of pvb.bench.ts and the same
// vitest options. Only the decode moves out of the loop, so D3 minus this is the decode time.
//
// Before timing, the decoded term is evaluated twice and the two spent budgets must be equal:
// that shows that a run does not change the term. Otherwise the script prints
// "EVAL_FAIL: <name>" and is not timed.

import { readdirSync, readFileSync } from "fs";
import { join } from "path";
import { bench, describe } from "vitest";
import { CekMachine } from "../src/cek";
import { decodeFlatDeBruijn } from "../src/flat";
import { I64_MAX, unlimitedBudget } from "../src/types";
import { harnessCosts } from "./pvb-costs";

const dataDir = process.env.PVB_DATA_DIR ?? join(__dirname, "plutus_use_cases");
const files = readdirSync(dataDir)
  .filter((f) => f.endsWith(".flat"))
  .sort();
const costs = harnessCosts();
const options = process.env.BENCH_TIMING === "quick" ? { time: 100, warmupTime: 20 } : {};

type Program = ReturnType<typeof decodeFlatDeBruijn>;

/** One evaluation of the decoded program; returns the spent budget as "cpu/mem". */
function evalDecoded(program: Program): string {
  const machine = new CekMachine(unlimitedBudget(), costs);
  machine.run(program.term);
  const left = machine.remainingBudget;
  return `${I64_MAX - left.cpu}/${I64_MAX - left.mem}`;
}

describe("plutus use cases (eval only)", () => {
  for (const file of files) {
    const name = file.replace(".flat", "");
    let program: Program;
    try {
      program = decodeFlatDeBruijn(new Uint8Array(readFileSync(join(dataDir, file))));
      const first = evalDecoded(program);
      const second = evalDecoded(program);
      if (first !== second) throw new Error(`budget changed between runs: ${first} then ${second}`);
    } catch (e) {
      console.log(`EVAL_FAIL: ${name}`);
      console.log(`  ${String(e).slice(0, 200)}`);
      continue;
    }
    bench(
      name,
      () => {
        new CekMachine(unlimitedBudget(), costs).run(program.term);
      },
      options,
    );
  }
});
