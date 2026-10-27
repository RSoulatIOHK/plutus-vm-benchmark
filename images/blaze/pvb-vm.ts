// The VM module of the shared timing loop (images/node-base/time.mjs) for blaze-plutus. Copied
// into packages/blaze-plutus/bench/ and bundled with bun into pvb-vm.mjs (images/blaze/Dockerfile),
// so plain node runs blaze's TypeScript sources.
//   d3    flat decode + evaluation per operation
//   eval  evaluation of the program decoded once, here, before the timing
// Both: a fresh CekMachine with an unlimited budget (counting mode) and the mainnet PlutusV3 cost
// table (pvb-costs.ts).

import { CekMachine } from "../src/cek";
import { decodeFlatDeBruijn } from "../src/flat";
import { I64_MAX, unlimitedBudget } from "../src/types";
import { harnessCosts } from "./pvb-costs";

type Program = ReturnType<typeof decodeFlatDeBruijn>;
type Costs = ReturnType<typeof harnessCosts>;

let costs: Costs | undefined;

/** One evaluation of a decoded program; returns the spent budget as "cpu/mem". */
function evalDecoded(program: Program, c: Costs): string {
  const machine = new CekMachine(unlimitedBudget(), c);
  machine.run(program.term);
  const left = machine.remainingBudget;
  return `${I64_MAX - left.cpu}/${I64_MAX - left.mem}`;
}

export function operation(loop: string, bytes: Uint8Array): () => unknown {
  const c = (costs ??= harnessCosts());
  if (loop === "d3") {
    return () => new CekMachine(unlimitedBudget(), c).run(decodeFlatDeBruijn(bytes).term);
  }
  // Two evaluations of one decoded term must spend the same budget: a run does not change the
  // term.
  const program = decodeFlatDeBruijn(bytes);
  const first = evalDecoded(program, c);
  const second = evalDecoded(program, c);
  if (first !== second) throw new Error(`budget changed between runs: ${first} then ${second}`);
  return () => new CekMachine(unlimitedBudget(), c).run(program.term);
}
