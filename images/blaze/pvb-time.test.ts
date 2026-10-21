// plutus-vm-benchmark timing for blaze (V8 via node, JSC via bun). Copied into
// packages/blaze-plutus/bench/ (images/blaze/Dockerfile). docs/IMAGE_CONTRACT.md, spec D3.
//
// One script per process: scripts/run-blaze-*.sh starts vitest once per script ($PVB_SCRIPT) and
// loop ($PVB_LOOP), so no JIT profile or GC state carries over from another script.
//
// $PVB_LOOP selects what one operation is:
//   d3    flat decode + evaluation                                         -> <vm>.csv
//   eval  evaluation of the program decoded once before timing             -> <vm>-eval.csv
// Both: a fresh CekMachine with an unlimited budget (counting mode) and the mainnet PlutusV3 cost
// table (pvb-costs.ts).
//
// The timing is the JMH shape of the JVM rows (`-wi 1 -w 20s -i 3 -r 5s`), not tinybench: one
// warm-up round, then $PVB_ROUNDS measured rounds. A round runs operations back to back until
// its time is up and scores elapsed / ops, as JMH avgt does. The run script sets the times
// ($PVB_WARMUP_MS, $PVB_ROUND_MS, $PVB_ROUNDS). tinybench cannot give a mean per round.
//
// Output: one line per round, then "PVB_RESULT {json}" with the rounds, for parsers/parse_vitest.py.
// A script that fails its first evaluation prints "EVAL_FAIL: <name>" and is not timed.

import { readFileSync } from "fs";
import { join } from "path";
import { test } from "vitest";
import { CekMachine } from "../src/cek";
import { decodeFlatDeBruijn } from "../src/flat";
import { I64_MAX, unlimitedBudget } from "../src/types";
import { harnessCosts } from "./pvb-costs";

const name = process.env.PVB_SCRIPT!;
const loop = process.env.PVB_LOOP!;
const warmupMs = Number(process.env.PVB_WARMUP_MS);
const roundMs = Number(process.env.PVB_ROUND_MS);
const rounds = Number(process.env.PVB_ROUNDS);

// Keeps the result of every operation reachable, so the engine cannot drop the work (JMH's
// Blackhole).
let sink: unknown;

type Round = { ops: number; ns: number };

/** Runs op back to back for at least ms milliseconds. */
function round(op: () => unknown, ms: number): Round {
  const start = performance.now();
  const deadline = start + ms;
  let ops = 0;
  let now: number;
  do {
    sink = op();
    ops++;
    now = performance.now();
  } while (now < deadline);
  return { ops, ns: (now - start) * 1e6 };
}

function show(label: string, r: Round): string {
  return `${label}: ${(r.ns / 1e9).toFixed(2)} s, ${r.ops} ops, ${(r.ns / r.ops).toFixed(0)} ns/op`;
}

type Program = ReturnType<typeof decodeFlatDeBruijn>;

/** One evaluation of a decoded program; returns the spent budget as "cpu/mem". */
function evalDecoded(program: Program, costs: ReturnType<typeof harnessCosts>): string {
  const machine = new CekMachine(unlimitedBudget(), costs);
  machine.run(program.term);
  const left = machine.remainingBudget;
  return `${I64_MAX - left.cpu}/${I64_MAX - left.mem}`;
}

test(
  `pvb ${loop} ${name}`,
  () => {
    if (!name || (loop !== "d3" && loop !== "eval") || !(rounds >= 1)) {
      throw new Error("set PVB_SCRIPT, PVB_LOOP (d3 or eval), PVB_WARMUP_MS, PVB_ROUND_MS, PVB_ROUNDS");
    }
    const costs = harnessCosts();
    const bytes = new Uint8Array(readFileSync(join(process.env.PVB_DATA_DIR!, `${name}.flat`)));
    let op: () => unknown;
    try {
      if (loop === "d3") {
        op = () => new CekMachine(unlimitedBudget(), costs).run(decodeFlatDeBruijn(bytes).term);
        op();
      } else {
        // Two evaluations of one decoded term must spend the same budget: a run does not change
        // the term.
        const program = decodeFlatDeBruijn(bytes);
        const first = evalDecoded(program, costs);
        const second = evalDecoded(program, costs);
        if (first !== second) throw new Error(`budget changed between runs: ${first} then ${second}`);
        op = () => new CekMachine(unlimitedBudget(), costs).run(program.term);
      }
    } catch (e) {
      console.log(`EVAL_FAIL: ${name}`);
      console.log(`  ${String(e).slice(0, 200)}`);
      return;
    }

    const tag = `${loop} ${name} pid ${process.pid}`;
    const warmup = round(op, warmupMs);
    console.log(show(`${tag} warm-up`, warmup));
    const measured: Round[] = [];
    for (let i = 1; i <= rounds; i++) {
      const r = round(op, roundMs);
      measured.push(r);
      console.log(show(`${tag} round ${i}`, r));
    }
    console.log(`PVB_RESULT ${JSON.stringify({ script: name, loop, pid: process.pid, warmup, rounds: measured })}`);
    if (sink === Symbol.for("never")) console.log("unreachable");
  },
  warmupMs + rounds * roundMs + 120_000,
);
