// Timing (spec D3): one eval_program_raw call per operation, costing on, for one script
// ($PVB_SCRIPT). The package caches the decoded program after the first call (warm-up), so the
// measured rounds time hash + evaluation, not the flat decode (common.mjs, README.md).
//
// One script per process: scripts/run-aiken-wasm.sh starts `node time.mjs` once per script, so no
// JIT profile or GC state carries over from another script.
//
// The timing is the JMH shape of the JVM rows (`-wi 1 -w 20s -i 3 -r 5s`), not tinybench: one
// warm-up round, then $PVB_ROUNDS measured rounds. A round runs evaluations back to back until its
// time is up and scores elapsed / ops, as JMH avgt does. The run script sets the times
// ($PVB_WARMUP_MS, $PVB_ROUND_MS, $PVB_ROUNDS). tinybench cannot give a mean per round. The same
// loop as the blaze and scalus-js harnesses (images/blaze/pvb-time.test.ts,
// images/scalus-js/time.mjs).
//
// Plain node runs it, not vitest: the harness is plain JavaScript and the VM is a package in
// node_modules that node loads natively, so vitest was only a launcher. Same engine (node, V8),
// same loop; the loop runs in the main thread instead of a vitest worker process.
//
// Output: one line per round, then "PVB_RESULT {json}" with the rounds, for parsers/parse_vitest.py.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { DATA_DIR, evaluate } from "./common.mjs";

const name = process.env.PVB_SCRIPT;
const warmupMs = Number(process.env.PVB_WARMUP_MS);
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

if (!name || !(rounds >= 1)) {
  throw new Error("set PVB_SCRIPT, PVB_WARMUP_MS, PVB_ROUND_MS, PVB_ROUNDS");
}
const flat = new Uint8Array(readFileSync(join(DATA_DIR, `${name}.flat`)));
const op = () => evaluate(flat);

const tag = `d3 ${name} pid ${process.pid}`;
const warmup = round(op, warmupMs);
console.log(show(`${tag} warm-up`, warmup));
const measured = [];
for (let i = 1; i <= rounds; i++) {
  const r = round(op, roundMs);
  measured.push(r);
  console.log(show(`${tag} round ${i}`, r));
}
console.log(`PVB_RESULT ${JSON.stringify({ script: name, loop: "d3", pid: process.pid, warmup, rounds: measured })}`);
if (sink === Symbol.for("never")) console.log("unreachable");
