//! Shared code for the aiken timing and check binaries.
//!
//! One evaluation = flat decode + conversion to named De Bruijn + CEK run with
//! costing on, as the aiken ledger code path does (`uplc::tx::eval` decodes to
//! `FakeNamedDeBruijn` and converts to `NamedDeBruijn` before it evaluates).

use std::{fs, path::Path};
use uplc::{
    Language,
    ast::{FakeNamedDeBruijn, NamedDeBruijn, Program},
    machine::{cost_model::ExBudget, eval_result::EvalResult, runtime::VAN_ROSSEM_PROTOCOL_VERSION},
};

/// Newest protocol version the crate knows (Van Rossem, 11). The default
/// PlutusV3 cost model of the crate is selected for it.
pub const PROTOCOL: u16 = VAN_ROSSEM_PROTOCOL_VERSION;

/// Decode and evaluate one flat program. The budget is large so every corpus
/// script runs to the end; costing is still computed step by step.
///
/// A panic inside the crate (for example in the decoder) is returned as an
/// error, so one bad script does not stop the run. Call [`silence_panics`]
/// first, or the default hook prints the panic to the raw log.
pub fn decode_and_eval(bytes: &[u8]) -> Result<EvalResult, String> {
    guarded(|| decode_and_eval_unguarded(bytes)).and_then(|r| r)
}

/// Replace the panic hook with a silent one. Its default output contains
/// "panicked", which `parsers/fill_failures.py` would charge to whichever
/// script Criterion printed last.
pub fn silence_panics() {
    std::panic::set_hook(Box::new(|_| {}));
}

fn decode_and_eval_unguarded(bytes: &[u8]) -> Result<EvalResult, String> {
    Ok(eval_unguarded(decode_unguarded(bytes)?))
}

/// Flat decode + conversion to named De Bruijn: the part of [`decode_and_eval`]
/// that the eval-only loop does once, before timing.
pub fn decode(bytes: &[u8]) -> Result<Program<NamedDeBruijn>, String> {
    guarded(|| decode_unguarded(bytes)).and_then(|r| r)
}

/// Evaluate a decoded program, guarded like [`decode_and_eval`]. Takes the
/// program by value because the crate's eval consumes it; a clone is cheap
/// (the term's children are `Rc`). The machine and its budget are new on
/// every call.
pub fn eval(program: Program<NamedDeBruijn>) -> Result<EvalResult, String> {
    guarded(|| eval_unguarded(program))
}

fn decode_unguarded(bytes: &[u8]) -> Result<Program<NamedDeBruijn>, String> {
    let program = Program::<FakeNamedDeBruijn>::from_flat(bytes).map_err(|e| e.to_string())?;
    Ok(program.into())
}

fn eval_unguarded(program: Program<NamedDeBruijn>) -> EvalResult {
    program.eval_version_with_protocol(ExBudget::max(), &Language::PlutusV3, PROTOCOL)
}

fn guarded<R>(f: impl FnOnce() -> R) -> Result<R, String> {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(f)).map_err(|p| {
        let msg = p
            .downcast_ref::<String>()
            .cloned()
            .or_else(|| p.downcast_ref::<&str>().map(|s| s.to_string()))
            .unwrap_or_default();
        format!("panic: {msg}")
    })
}

/// All `*.flat` files of the directory, sorted by name. The harness puts only the selected
/// scripts there (scripts/image-entry.sh).
pub fn scripts(dir: &Path) -> Vec<(String, Vec<u8>)> {
    let mut names: Vec<String> = fs::read_dir(dir)
        .unwrap_or_else(|e| panic!("cannot read {}: {e}", dir.display()))
        .filter_map(|e| e.ok())
        .map(|e| e.file_name().to_string_lossy().into_owned())
        .filter(|n| n.ends_with(".flat"))
        .collect();
    names.sort();
    names
        .into_iter()
        .map(|n| {
            let bytes = fs::read(dir.join(&n)).expect("read flat file");
            (n.trim_end_matches(".flat").to_string(), bytes)
        })
        .collect()
}

pub fn data_dir() -> std::path::PathBuf {
    std::env::var("DATA_DIR")
        .unwrap_or_else(|_| "/bench/data/plutus_use_cases".to_string())
        .into()
}
