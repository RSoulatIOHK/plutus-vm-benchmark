// The VM module of the shared timing loop (images/node-base/time.mjs): the operation of a loop.
//   d3    flat decode + evaluation per operation
//   eval  evaluation of the program decoded once, here, before the timing
import { decode, evaluate, evaluateProgram } from "./common.mjs";

export function operation(loop, flat) {
  if (loop === "d3") return () => evaluate(flat);
  const program = decode(flat);
  return () => evaluateProgram(program);
}
