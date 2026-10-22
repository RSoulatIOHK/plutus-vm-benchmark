// Timing (spec D3): flat decode + evaluation with costing on, for one script ($PVB_SCRIPT).
//
// One script per process: scripts/run-scalus-js.sh starts `node time.mjs` once per script, so no
// JIT profile or GC state carries over from another script.
//
// The timing is the JMH shape of the JVM rows (`-wi 1 -w 20s -i 3 -r 5s`), not tinybench: one
// warm-up round, then $PVB_ROUNDS measured rounds. A round runs evaluations back to back until its
// time is up and scores elapsed / ops, as JMH avgt does. The run script sets the times
// ($PVB_WARMUP_MS, $PVB_ROUND_MS, $PVB_ROUNDS). tinybench cannot give a mean per round. The same
// loop as the blaze harness (images/blaze/pvb-time.test.ts).
//
// Plain node runs it, not vitest: the harness is plain JavaScript and the VM is a package in
// node_modules that node loads natively, so vitest was only a launcher. Same engine (node, V8),
// same loop; the loop runs in the main thread instead of a vitest worker process.
//
// BENCH_TRACE=1: the warm-up runs as rounds of 1 s with the same total time (as JMH -wi 20 -w 1s),
// and the harness prints them after the warm-up as "PVB_WARMUP {json}" (parsers/parse_warmup.py ->
// <vm>-warmup.csv). The measured rounds do not change.
//
// Output: one line per round, then "PVB_RESULT {json}" with the rounds, for parsers/parse_vitest.py.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { DATA_DIR, evaluate } from "./common.mjs";

const name = process.env.PVB_SCRIPT;
const warmupMs = Number(process.env.PVB_WARMUP_MS);
const roundMs = Number(process.env.PVB_ROUND_MS);
const rounds = Number(process.env.PVB_ROUNDS);
// BENCH_TRACE=1 (scripts/image-entry.sh): run and log the warm-up in 1 s slices.
const trace = process.env.BENCH_TRACE === "1";

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

/**
 * Trace mode: the warm-up as rounds of 1 s (the last one shorter if ms is not a whole number of
 * seconds), as JMH's -wi 20 -w 1s. The same round() as the measured rounds, so it is warm too.
 */
function warmupSlices(op, ms) {
  const slices = [];
  for (let left = ms; left > 0; left -= 1000) slices.push(round(op, Math.min(1000, left)));
  return slices;
}

if (!name || !(rounds >= 1)) {
  throw new Error("set PVB_SCRIPT, PVB_WARMUP_MS, PVB_ROUND_MS, PVB_ROUNDS");
}
const flat = new Uint8Array(readFileSync(join(DATA_DIR, `${name}.flat`)));
const op = () => evaluate(flat);

const tag = `d3 ${name} pid ${process.pid}`;
let warmup;
if (trace) {
  const slices = warmupSlices(op, warmupMs);
  warmup = { ops: slices.reduce((n, sl) => n + sl.ops, 0), ns: slices.reduce((n, sl) => n + sl.ns, 0) };
  slices.forEach((sl, i) => console.log(show(`${tag} warm-up second ${i + 1}`, sl)));
  console.log(`PVB_WARMUP ${JSON.stringify({ script: name, loop: "d3", slices })}`);
} else {
  warmup = round(op, warmupMs);
}
console.log(show(`${tag} warm-up`, warmup));
const measured = [];
for (let i = 1; i <= rounds; i++) {
  const r = round(op, roundMs);
  measured.push(r);
  console.log(show(`${tag} round ${i}`, r));
}
console.log(`PVB_RESULT ${JSON.stringify({ script: name, loop: "d3", pid: process.pid, warmup, rounds: measured })}`);
if (sink === Symbol.for("never")) console.log("unreachable");
