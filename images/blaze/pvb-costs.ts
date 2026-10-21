// plutus-vm-benchmark: the mainnet PlutusV3 cost model as a blaze cost table.
// Copied into packages/blaze-plutus/bench/ (images/blaze/Dockerfile). Spec D10/D11.
//
// blaze takes builtin costs as a structured table, `new CekMachine(budget, costs)` with
// costs: Record<DefaultFunction, BuiltinCostModel>, and has no parser for the on-chain array.
// This module fills a copy of blaze's DEFAULT_BUILTIN_COSTS from the array: for every builtin and
// for cpu and memory, the parameter names follow from the cost function shape of the table
// (prefix "<builtin>-<cpu|memory>-arguments"). The names come from the plutus 1.63.0.0
// ParamName list (plutusv3-param-names.txt), zipped with the array in on-chain order.
//
// The shapes stay blaze's (variant C): with the mainnet numbers and the C shapes the 89 scripts
// give the strict reference (check/README.md).
//
// Machine step costs are module constants in blaze's machine.ts (16000 cpu / 100 mem per step,
// startup 100 / 100) and cannot be passed in. assertMachineCosts() stops the run if the mainnet
// values ever differ from them.

import { readFileSync } from "fs";
import type { BuiltinCostModel } from "../src/cek/costing";
import { DEFAULT_BUILTIN_COSTS } from "../src/cek/costs";
import type { DefaultFunction } from "../src/types";

export type Params = Map<string, number>;

export function loadParams(costModelJson: string, paramNames: string): Params {
  const values: number[] = JSON.parse(readFileSync(costModelJson, "utf8")).PlutusV3;
  const names = readFileSync(paramNames, "utf8")
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l !== "" && !l.startsWith("#"));
  if (names.length !== values.length) {
    throw new Error(`${paramNames}: ${names.length} names for ${values.length} values`);
  }
  return new Map(names.map((n, i) => [n, values[i]!]));
}

// The step costs hard-coded in blaze's machine.ts at the pinned commit.
const BLAZE_STEP = { cpu: 16000, mem: 100 };
const BLAZE_STARTUP = { cpu: 100, mem: 100 };
const STEPS = ["Apply", "Builtin", "Const", "Delay", "Force", "Lam", "Var", "Constr", "Case"];

export function assertMachineCosts(params: Params): void {
  const expect = (name: string, want: number) => {
    const got = params.get(name);
    if (got !== want) {
      throw new Error(`mainnet ${name} = ${got}, blaze hard-codes ${want}: cannot inject`);
    }
  };
  for (const s of STEPS) {
    expect(`cek${s}Cost-exBudgetCPU`, BLAZE_STEP.cpu);
    expect(`cek${s}Cost-exBudgetMemory`, BLAZE_STEP.mem);
  }
  expect("cekStartupCost-exBudgetCPU", BLAZE_STARTUP.cpu);
  expect("cekStartupCost-exBudgetMemory", BLAZE_STARTUP.mem);
}

export interface MappedCosts {
  costs: Record<DefaultFunction, BuiltinCostModel>;
  // Mainnet parameters that no field of the table took (builtins blaze shapes differently or lacks).
  unused: string[];
  // Fields of the table with no mainnet parameter: they keep blaze's default.
  missing: string[];
}

/* eslint-disable @typescript-eslint/no-explicit-any */
export function mainnetBuiltinCosts(params: Params): MappedCosts {
  const costs = structuredClone(DEFAULT_BUILTIN_COSTS) as Record<string, any>;
  const used = new Set<string>();
  const missing: string[] = [];

  for (const [fn, bcm] of Object.entries(costs)) {
    for (const mode of ["cpu", "mem"] as const) {
      const prefix = `${fn}-${mode === "cpu" ? "cpu" : "memory"}-arguments`;
      const m = bcm.fun[mode];
      // Set obj[field] from the first of the given parameter suffixes that exists.
      const set = (obj: any, field: string, ...suffixes: string[]) => {
        for (const suffix of suffixes) {
          const name = suffix === "" ? prefix : `${prefix}-${suffix}`;
          const v = params.get(name);
          if (v !== undefined) {
            obj[field] = v;
            used.add(name);
            return;
          }
        }
        missing.push(`${prefix}-{${suffixes.join("|")}} (${m.tag}.${field})`);
      };
      switch (m.tag) {
        case "constant":
          set(m, "value", "");
          break;
        case "linear":
        case "linear_in_x":
        case "linear_in_y":
        case "linear_in_z":
        case "added_sizes":
        case "multiplied_sizes":
        case "min_size":
        case "max_size":
        case "linear_in_max_yz":
        case "literal_in_y_or_linear_in_z":
          set(m.model, "intercept", "intercept");
          set(m.model, "slope", "slope");
          break;
        case "quadratic":
        case "quadratic_in_y":
        case "quadratic_in_z":
          set(m.model, "coeff0", "c0");
          set(m.model, "coeff1", "c1");
          set(m.model, "coeff2", "c2");
          break;
        case "subtracted_sizes":
          set(m, "intercept", "intercept");
          set(m, "slope", "slope");
          set(m, "minimum", "minimum");
          break;
        case "linear_on_diagonal":
          set(m, "constant", "constant");
          set(m, "intercept", "intercept");
          set(m, "slope", "slope");
          break;
        case "const_above_diagonal":
        case "const_below_diagonal":
          set(m, "constant", "constant");
          set(m.model, "minimum", "model-arguments-minimum");
          for (const c of ["00", "10", "01", "20", "11", "02"]) {
            set(m.model, `coeff${c}`, `model-arguments-c${c}`);
          }
          break;
        case "with_interaction":
          for (const c of ["00", "10", "01", "11"]) set(m, `c${c}`, `c${c}`);
          break;
        case "linear_in_y_and_z":
          set(m, "intercept", "intercept", "model-arguments-intercept");
          set(m, "slopeY", "slope1", "model-arguments-slope1");
          set(m, "slopeZ", "slope2", "model-arguments-slope2");
          break;
        case "exp_mod":
          set(m, "coeff00", "coefficient00");
          set(m, "coeff11", "coefficient11");
          set(m, "coeff12", "coefficient12");
          break;
        default:
          throw new Error(`${prefix}: unknown cost function shape ${m.tag}`);
      }
    }
  }

  const unused = [...params.keys()].filter((k) => !k.startsWith("cek") && !used.has(k));
  return { costs: costs as Record<DefaultFunction, BuiltinCostModel>, unused, missing };
}

/** The table for the harness, from $PVB_COSTMODEL_JSON and $PVB_PARAM_NAMES. Logs what it skips. */
export function harnessCosts(): Record<DefaultFunction, BuiltinCostModel> {
  const params = loadParams(
    process.env.PVB_COSTMODEL_JSON ?? "/bench/mainnet-plutusv3-costmodel.json",
    process.env.PVB_PARAM_NAMES ?? "/bench/plutusv3-param-names.txt",
  );
  assertMachineCosts(params);
  const { costs, unused, missing } = mainnetBuiltinCosts(params);
  const bun = (process.versions as Record<string, string | undefined>).bun;
  console.log(`engine: ${bun ? `bun ${bun} (JavaScriptCore)` : `node ${process.versions.node} (V8)`}`);
  console.log(
    `cost model: ${params.size} mainnet parameters; ${unused.length} not used by blaze's table, ` +
      `${missing.length} table fields without a mainnet parameter (blaze default kept)`,
  );
  if (unused.length) console.log(`  not used: ${unused.join(" ")}`);
  if (missing.length) console.log(`  missing: ${missing.join(" ")}`);
  return costs;
}
