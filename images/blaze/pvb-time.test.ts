// plutus-vm-benchmark timing for blaze (V8 via node). Copied into
// packages/blaze-plutus/bench/ (images/blaze/Dockerfile). docs/IMAGE_CONTRACT.md, spec D3.
//
// One script per process: scripts/run-blaze-v8.sh starts vitest once per script ($PVB_SCRIPT), so no
// JIT profile or GC state carries over from another script. The process runs the loops of
// $PVB_LOOPS (comma list) in this order, each with its own warm-up and rounds:
//   d3    flat decode + evaluation                                         -> <vm>.csv
//   eval  evaluation of the program decoded once before timing             -> <vm>-eval.csv
// Both: a fresh CekMachine with an unlimited budget (counting mode) and the mainnet PlutusV3 cost
// table (pvb-costs.ts). A loop prints "PVB_LOOP <loop> <name>" before it starts
// (parsers/fill_failures.py --loop).
//
// The timing is the JMH shape of the JVM rows (`-i 3 -r 5s`), not tinybench: the warm-up, then
// $PVB_ROUNDS measured rounds. A round runs operations back to back until
// its time is up and scores elapsed / ops, as JMH avgt does. The run script sets the times
// ($PVB_WARMUP_MS, $PVB_ROUND_MS, $PVB_ROUNDS). tinybench cannot give a mean per round.
//
// Warm-up ($PVB_WARMUP_MS, METHODOLOGY.md D13): "adaptive" runs rounds of 1 s until at least 5 s
// have passed and the last 5 rounds are within 3 % of their median, 30 s at most (the cap). A
// number is one fixed warm-up round of that many ms (BENCH_TIMING=quick). After the warm-up of a loop the harness prints
// "PVB_WARMUP {json}" with its slices and whether it hit the cap (parsers/parse_warmup.py ->
// <vm>-warmup-used.csv, and <vm>-warmup.csv with BENCH_TRACE=1).
//
// Output: one line per round, then per loop "PVB_RESULT {json}" with the loop and its rounds, for
// parsers/parse_vitest.py. A loop whose first evaluation fails prints "EVAL_FAIL: <name>" and is
// not timed.

import { readFileSync } from "fs";
import { join } from "path";
import { test } from "vitest";
import { CekMachine } from "../src/cek";
import { decodeFlatDeBruijn } from "../src/flat";
import { I64_MAX, unlimitedBudget } from "../src/types";
import { harnessCosts } from "./pvb-costs";

const name = process.env.PVB_SCRIPT!;
const loops = (process.env.PVB_LOOPS ?? "").split(",").filter((l) => l !== "");
const warmupSpec = process.env.PVB_WARMUP_MS ?? "";
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

// The adaptive warm-up rule. Keep it the same in every JS harness: images/blaze/pvb-time.test.ts,
// images/scalus-js/time.mjs and images/aiken-wasm/time.mjs.
const SLICE_MS = 1000;
const WINDOW = 5;
const TOLERANCE = 0.03;
const MIN_MS = 5000;
const CAP_MS = 30000;

/** True when the last WINDOW slices are all within ±TOLERANCE of their median. */
function steady(slices: Round[]): boolean {
  if (slices.length < WINDOW) return false;
  const last = slices.slice(-WINDOW).map((s) => s.ns / s.ops);
  const median = [...last].sort((a, b) => a - b)[Math.floor(WINDOW / 2)];
  return last.every((x) => Math.abs(x - median) <= TOLERANCE * median);
}

/**
 * The warm-up: "adaptive", or one fixed round of spec ms. Slices use the same round() as the
 * measured rounds. Returns { slices, end }, end is "steady", "capped" or "fixed".
 */
function warmUp(op: () => unknown, spec: string): { slices: Round[]; end: string } {
  if (spec !== "adaptive") return { slices: [round(op, Number(spec))], end: "fixed" };
  const start = performance.now();
  const slices: Round[] = [];
  for (;;) {
    slices.push(round(op, SLICE_MS));
    const elapsed = performance.now() - start;
    if (elapsed >= MIN_MS && steady(slices)) return { slices, end: "steady" };
    if (elapsed >= CAP_MS) return { slices, end: "capped" };
  }
}

/** The longest warm-up of one loop, for the test timeout. */
const warmupMaxMs = warmupSpec === "adaptive" ? CAP_MS + SLICE_MS : Number(warmupSpec);

type Program = ReturnType<typeof decodeFlatDeBruijn>;

/** One evaluation of a decoded program; returns the spent budget as "cpu/mem". */
function evalDecoded(program: Program, costs: ReturnType<typeof harnessCosts>): string {
  const machine = new CekMachine(unlimitedBudget(), costs);
  machine.run(program.term);
  const left = machine.remainingBudget;
  return `${I64_MAX - left.cpu}/${I64_MAX - left.mem}`;
}

/** The operation of one loop, or undefined after an EVAL_FAIL. */
function operation(loop: string, bytes: Uint8Array, costs: ReturnType<typeof harnessCosts>): (() => unknown) | undefined {
  try {
    if (loop === "d3") {
      const op = () => new CekMachine(unlimitedBudget(), costs).run(decodeFlatDeBruijn(bytes).term);
      op();
      return op;
    }
    // Two evaluations of one decoded term must spend the same budget: a run does not change
    // the term.
    const program = decodeFlatDeBruijn(bytes);
    const first = evalDecoded(program, costs);
    const second = evalDecoded(program, costs);
    if (first !== second) throw new Error(`budget changed between runs: ${first} then ${second}`);
    return () => new CekMachine(unlimitedBudget(), costs).run(program.term);
  } catch (e) {
    console.log(`EVAL_FAIL: ${name}`);
    console.log(`  ${String(e).slice(0, 200)}`);
    return undefined;
  }
}

test(
  `pvb ${loops.join(",")} ${name}`,
  () => {
    if (!name || loops.length === 0 || loops.some((l) => l !== "d3" && l !== "eval") || !(rounds >= 1)
        || !(warmupMaxMs > 0)) {
      throw new Error("set PVB_SCRIPT, PVB_LOOPS (d3, eval or d3,eval), PVB_WARMUP_MS (adaptive or ms), PVB_ROUND_MS, PVB_ROUNDS");
    }
    const costs = harnessCosts();
    const bytes = new Uint8Array(readFileSync(join(process.env.PVB_DATA_DIR!, `${name}.flat`)));
    for (const loop of ["d3", "eval"].filter((l) => loops.includes(l))) {
      console.log(`PVB_LOOP ${loop} ${name}`);
      const op = operation(loop, bytes, costs);
      if (!op) continue;

      const tag = `${loop} ${name} pid ${process.pid}`;
      const { slices, end } = warmUp(op, warmupSpec);
      const warmup = { ops: slices.reduce((n, sl) => n + sl.ops, 0), ns: slices.reduce((n, sl) => n + sl.ns, 0) };
      console.log(`${show(`${tag} warm-up`, warmup)}, ${slices.length} slices, ${end}`);
      console.log(`PVB_WARMUP ${JSON.stringify({ script: name, loop, slices, capped: end === "capped", end })}`);
      const measured: Round[] = [];
      for (let i = 1; i <= rounds; i++) {
        const r = round(op, roundMs);
        measured.push(r);
        console.log(show(`${tag} round ${i}`, r));
      }
      console.log(`PVB_RESULT ${JSON.stringify({ script: name, loop, pid: process.pid, warmup, rounds: measured })}`);
    }
    if (sink === Symbol.for("never")) console.log("unreachable");
  },
  loops.length * ((warmupMaxMs || 0) + rounds * roundMs) + 120_000,
);
