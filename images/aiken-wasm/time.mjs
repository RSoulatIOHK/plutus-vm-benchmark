// Timing (spec D3): one eval_program_raw call per operation, costing on, for one script
// ($PVB_SCRIPT). The package caches the decoded program after the first call (warm-up), so the
// measured rounds time hash + evaluation, not the flat decode (common.mjs, README.md).
//
// One script per process: scripts/run-aiken-wasm.sh starts `node time.mjs` once per script, so no
// JIT profile or GC state carries over from another script.
//
// The timing is the JMH shape of the JVM rows (`-i 3 -r 5s`), not tinybench: the warm-up, then
// $PVB_ROUNDS measured rounds. A round runs evaluations back to back until its
// time is up and scores elapsed / ops, as JMH avgt does. The run script sets the times
// ($PVB_WARMUP_MS, $PVB_ROUND_MS, $PVB_ROUNDS). tinybench cannot give a mean per round. The same
// loop as the blaze and scalus-js harnesses (images/blaze/pvb-time.test.ts,
// images/scalus-js/time.mjs).
//
// Plain node runs it, not vitest: the harness is plain JavaScript and the VM is a package in
// node_modules that node loads natively, so vitest was only a launcher. Same engine (node, V8),
// same loop; the loop runs in the main thread instead of a vitest worker process.
//
// Warm-up ($PVB_WARMUP_MS, METHODOLOGY.md D13): "adaptive" runs rounds of 1 s until at least 5 s
// have passed and the last 5 rounds are within 3 % of their median, 30 s at most (the cap). A
// number is one fixed warm-up round of that many ms (BENCH_TIMING=quick). After the warm-up the harness prints
// "PVB_WARMUP {json}" with its slices and whether it hit the cap (parsers/parse_warmup.py ->
// <vm>-warmup-used.csv, and <vm>-warmup.csv with BENCH_TRACE=1).
//
// Output: one line per round, then "PVB_RESULT {json}" with the rounds, for parsers/parse_vitest.py.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { DATA_DIR, evaluate } from "./common.mjs";

const name = process.env.PVB_SCRIPT;
const warmupSpec = process.env.PVB_WARMUP_MS;
const roundMs = Number(process.env.PVB_ROUND_MS);
const rounds = Number(process.env.PVB_ROUNDS);

// Keeps the result of every evaluation reachable, so the engine cannot drop the work (JMH's
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

// The adaptive warm-up rule. Keep it the same in every JS harness: images/blaze/pvb-time.test.ts,
// images/scalus-js/time.mjs and images/aiken-wasm/time.mjs.
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

if (!name || !(rounds >= 1) || !(warmupSpec === "adaptive" || Number(warmupSpec) > 0)) {
  throw new Error("set PVB_SCRIPT, PVB_WARMUP_MS (adaptive or ms), PVB_ROUND_MS, PVB_ROUNDS");
}
const flat = new Uint8Array(readFileSync(join(DATA_DIR, `${name}.flat`)));
const op = () => evaluate(flat);

const tag = `d3 ${name} pid ${process.pid}`;
const { slices, end } = warmUp(op, warmupSpec);
const warmup = { ops: slices.reduce((n, sl) => n + sl.ops, 0), ns: slices.reduce((n, sl) => n + sl.ns, 0) };
console.log(`${show(`${tag} warm-up`, warmup)}, ${slices.length} slices, ${end}`);
console.log(`PVB_WARMUP ${JSON.stringify({ script: name, loop: "d3", slices, capped: end === "capped", end })}`);
const measured = [];
for (let i = 1; i <= rounds; i++) {
  const r = round(op, roundMs);
  measured.push(r);
  console.log(show(`${tag} round ${i}`, r));
}
console.log(`PVB_RESULT ${JSON.stringify({ script: name, loop: "d3", pid: process.pid, warmup, rounds: measured })}`);
if (sink === Symbol.for("never")) console.log("unreachable");
