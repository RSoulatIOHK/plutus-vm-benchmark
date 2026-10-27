// plutus-vm-benchmark correctness check (spec D4) for blaze: one evaluation per script with the
// parameters of the timed loop (pvb-vm.ts). Writes $PVB_CHECK_OUT (vm,script,status,cpu,mem) with vm $PVB_VM.
// A vitest test file, so the check runs on the same engine as the timing (node).

import { readdirSync, readFileSync, writeFileSync } from "fs";
import { join } from "path";
import { test } from "vitest";
import { CekMachine } from "../src/cek";
import { decodeFlatDeBruijn } from "../src/flat";
import { I64_MAX, unlimitedBudget } from "../src/types";
import { harnessCosts } from "./pvb-costs";

test("pvb check", () => {
  const dataDir = process.env.PVB_DATA_DIR!;
  const out = process.env.PVB_CHECK_OUT!;
  const vm = process.env.PVB_VM!;
  const costs = harnessCosts();
  const files = readdirSync(dataDir)
    .filter((f) => f.endsWith(".flat"))
    .sort();
  const lines = ["vm,script,status,cpu,mem"];
  for (const file of files) {
    const name = file.replace(".flat", "");
    let status = "ok";
    let machine: CekMachine | undefined;
    try {
      const program = decodeFlatDeBruijn(new Uint8Array(readFileSync(join(dataDir, file))));
      machine = new CekMachine(unlimitedBudget(), costs);
      machine.run(program.term);
    } catch (e) {
      status = "error";
      console.log(`CHECK_FAIL: ${name}: ${String(e).slice(0, 200)}`);
    }
    // Spent = initial - remaining; a decode error has no machine and no ExUnits.
    const remaining = machine?.remainingBudget;
    const cpu = remaining ? I64_MAX - remaining.cpu : 0n;
    const mem = remaining ? I64_MAX - remaining.mem : 0n;
    lines.push(`${vm},${name},${status},${cpu},${mem}`);
  }
  writeFileSync(out, lines.join("\n") + "\n");
}, 600_000);
