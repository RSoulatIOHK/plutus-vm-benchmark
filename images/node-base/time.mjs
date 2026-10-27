// The shared timing loop of the JS rows (scalus-js, aiken-wasm, blaze-v8), in images/node-base as
// /bench/node/time.mjs. For one script ($PVB_SCRIPT) it runs the loops of $PVB_LOOPS (comma list:
// d3, eval or d3,eval; default d3), d3 first, each with its own warm-up and rounds:
//   d3    flat decode + evaluation with costing on (spec D3)                 -> <vm>.csv
//   eval  evaluation with costing on of the program decoded before the timing -> <vm>-eval.csv
//
// The VM is the module $PVB_VM_MODULE (default ./vm.mjs in the working directory). It exports
// operation(loop, flat): the operation of one loop for the flat bytes, a function the loop calls
// back to back. operation() may do setup (for eval: the decode) and throws when the VM cannot run
// the script or the loop.
//
// One script per process: the run script starts `node /bench/node/time.mjs` once per script, so no
// JIT profile or GC state carries over from another script.
//
// The timing is the JMH shape of the JVM rows (`-i 3 -r 5s`), not tinybench: the warm-up, then
// $PVB_ROUNDS measured rounds. A round runs operations back to back until its time is up and
// scores elapsed / ops, as JMH avgt does. The run script sets the times ($PVB_WARMUP_MS,
// $PVB_ROUND_MS, $PVB_ROUNDS).
//
// Warm-up ($PVB_WARMUP_MS, METHODOLOGY.md D13): "adaptive" runs rounds of 1 s until at least 5 s
// have passed and the last 5 rounds are within 3 % of their median, 30 s at most (the cap). A
// number is one fixed warm-up round of that many ms (BENCH_TIMING=quick). After the warm-up of a
// loop the harness prints "PVB_WARMUP {json}" with its slices and whether it hit the cap
// (parsers/parse_warmup.py -> <vm>-warmup-used.csv, and <vm>-warmup.csv with BENCH_TRACE=1).
//
// Output: per loop "PVB_LOOP <loop> <name>" (parsers/fill_failures.py --loop), one line per round,
// then "PVB_RESULT {json}" with the loop and its rounds, for parsers/parse_vitest.py. A loop whose
// operation() or first call throws prints "EVAL_FAIL: <name>" and is not timed.
import { readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const DATA_DIR = process.env.PVB_DATA_DIR ?? process.env.DATA_DIR ?? "/bench/data/plutus_use_cases";
const name = process.env.PVB_SCRIPT;
const loops = (process.env.PVB_LOOPS ?? process.env.PVB_LOOP ?? "d3").split(",").filter((l) => l !== "");
const warmupSpec = process.env.PVB_WARMUP_MS;
const roundMs = Number(process.env.PVB_ROUND_MS);
const rounds = Number(process.env.PVB_ROUNDS);
const { operation } = await import(pathToFileURL(resolve(process.env.PVB_VM_MODULE ?? "vm.mjs")).href);

// Keeps the result of every operation reachable, so the engine cannot drop the work (JMH's
// Blackhole).
let sink;

/** Runs op back to back for at least ms milliseconds; returns { ops, ns }. */
function round(op, ms) {
  const start = performance.now();
  const deadline = start + ms;
  let ops = 0;
  let now;
  do {
    sink = op();
    ops++;
    now = performance.now();
  } while (now < deadline);
  return { ops, ns: (now - start) * 1e6 };
}

function show(label, r) {
  return `${label}: ${(r.ns / 1e9).toFixed(2)} s, ${r.ops} ops, ${(r.ns / r.ops).toFixed(0)} ns/op`;
}

// The adaptive warm-up rule of every JS row.
const SLICE_MS = 1000;
const WINDOW = 5;
const TOLERANCE = 0.03;
const MIN_MS = 5000;
const CAP_MS = 30000;

/** True when the last WINDOW slices are all within ±TOLERANCE of their median. */
function steady(slices) {
  if (slices.length < WINDOW) return false;
  const last = slices.slice(-WINDOW).map((s) => s.ns / s.ops);
  const median = [...last].sort((a, b) => a - b)[Math.floor(WINDOW / 2)];
  return last.every((x) => Math.abs(x - median) <= TOLERANCE * median);
}

/**
 * The warm-up: "adaptive", or one fixed round of spec ms. Slices use the same round() as the
 * measured rounds. Returns { slices, end }, end is "steady", "capped" or "fixed".
 */
function warmUp(op, spec) {
  if (spec !== "adaptive") return { slices: [round(op, Number(spec))], end: "fixed" };
  const start = performance.now();
  const slices = [];
  for (;;) {
    slices.push(round(op, SLICE_MS));
    const elapsed = performance.now() - start;
    if (elapsed >= MIN_MS && steady(slices)) return { slices, end: "steady" };
    if (elapsed >= CAP_MS) return { slices, end: "capped" };
  }
}

if (!name || loops.length === 0 || loops.some((l) => l !== "d3" && l !== "eval") || !(rounds >= 1)
    || !(warmupSpec === "adaptive" || Number(warmupSpec) > 0) || !(roundMs > 0)) {
  throw new Error("set PVB_SCRIPT, PVB_LOOPS (d3, eval or d3,eval), PVB_WARMUP_MS (adaptive or ms), PVB_ROUND_MS, PVB_ROUNDS");
}
const flat = new Uint8Array(readFileSync(join(DATA_DIR, `${name}.flat`)));

for (const loop of ["d3", "eval"].filter((l) => loops.includes(l))) {
  console.log(`PVB_LOOP ${loop} ${name}`);
  let op;
  try {
    op = operation(loop, flat);
    sink = op();
  } catch (e) {
    console.log(`EVAL_FAIL: ${name}`);
    console.log(`  ${String(e).slice(0, 200)}`);
    continue;
  }
  const tag = `${loop} ${name} pid ${process.pid}`;
  const { slices, end } = warmUp(op, warmupSpec);
  const warmup = { ops: slices.reduce((n, sl) => n + sl.ops, 0), ns: slices.reduce((n, sl) => n + sl.ns, 0) };
  console.log(`${show(`${tag} warm-up`, warmup)}, ${slices.length} slices, ${end}`);
  console.log(`PVB_WARMUP ${JSON.stringify({ script: name, loop, slices, capped: end === "capped", end })}`);
  const measured = [];
  for (let i = 1; i <= rounds; i++) {
    const r = round(op, roundMs);
    measured.push(r);
    console.log(show(`${tag} round ${i}`, r));
  }
  console.log(`PVB_RESULT ${JSON.stringify({ script: name, loop, pid: process.pid, warmup, rounds: measured })}`);
}
if (sink === Symbol.for("never")) console.log("unreachable");
