//! Decode + evaluate a bare flat program, for the aiken-wasm benchmark.
//!
//! This mirrors `eval_program_raw` of @lucid-evolution/uplc (same crate, same
//! calls), minus its cache of decoded programs: every call decodes the flat
//! again, so a timing loop measures decode + eval as the benchmark requires.

use uplc::{
    ast::{FakeNamedDeBruijn, NamedDeBruijn, Program, Term},
    machine::{
        cost_model::{CostModel, ExBudget},
        Machine,
    },
    protocol::VAN_ROSSEM_PROTOCOL_VERSION,
    Language,
};
use wasm_bindgen::prelude::*;

/// The ledger checks the budget every 200 steps; so does the published package.
const LEDGER_SLIPPAGE: u32 = 200;

#[wasm_bindgen]
pub struct EvalFlatResult {
    /// The machine ran the program to a value (it did not fail or go over budget).
    pub ok: bool,
    pub cpu: i64,
    pub mem: i64,
}

/// Decode the flat program and run it as PlutusV3 at the newest protocol
/// version the crate knows (Van Rossem, 11), with the crate's default PlutusV3
/// cost model for it and a large budget. Throws when the flat does not decode.
#[wasm_bindgen]
pub fn eval_flat(flat: &[u8]) -> Result<EvalFlatResult, JsValue> {
    let program: Program<NamedDeBruijn> = Program::<FakeNamedDeBruijn>::from_flat(flat)
        .map_err(|e| JsValue::from_str(&format!("Invalid flat program: {e}")))?
        .into();

    let language = Language::PlutusV3;
    let budget = ExBudget::max();
    let mut machine = Machine::new_with_protocol(
        language.clone(),
        VAN_ROSSEM_PROTOCOL_VERSION,
        CostModel::default_for_language_and_protocol(&language, VAN_ROSSEM_PROTOCOL_VERSION),
        budget,
        LEDGER_SLIPPAGE,
    );
    let result = machine.run_program(program);
    let used = budget - machine.ex_budget;

    Ok(EvalFlatResult {
        ok: matches!(&result, Ok(term) if !matches!(term, Term::Error)),
        cpu: used.cpu,
        mem: used.mem,
    })
}

/// The uplc crate this module is built from, as `<version> <source>`.
#[wasm_bindgen]
pub fn build_info() -> String {
    format!("{} {}", env!("UPLC_VERSION"), env!("UPLC_SOURCE"))
}
