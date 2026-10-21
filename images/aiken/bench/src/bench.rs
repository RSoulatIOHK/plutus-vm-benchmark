//! Criterion timing of every script.
//!
//! Default: flat decode + eval per iteration (spec D3, `aiken.csv`).
//! `PVB_EVAL_ONLY=1`: eval only (`aiken-eval.csv`). The program is decoded once
//! before timing; each iteration evaluates a clone of it on a new machine with
//! a new budget. The clone is made in Criterion's untimed setup (`iter_batched`).
//!
//! Each script is one top-level benchmark named after the script, so Criterion
//! writes `<CRITERION_HOME>/<script>/new/estimates.json` (what
//! `parsers/parse_criterion.py` reads). A script that fails its first
//! evaluation is printed as `EVAL_FAIL: <script>` and not timed.

use aiken_bench::{data_dir, decode, decode_and_eval, eval, quick, scripts, silence_panics};
use criterion::{BatchSize, Criterion, black_box};
use std::time::Duration;

fn main() {
    silence_panics();
    let eval_only = std::env::var("PVB_EVAL_ONLY").is_ok_and(|v| v == "1");
    let mut c = if quick() {
        Criterion::default()
            .sample_size(10)
            .warm_up_time(Duration::from_millis(500))
            .measurement_time(Duration::from_secs(1))
    } else {
        Criterion::default()
    }
    .configure_from_args();

    for (name, bytes) in scripts(&data_dir()) {
        match decode_and_eval(&bytes) {
            Ok(r) if r.result.is_ok() => {}
            Ok(r) => {
                println!("EVAL_FAIL: {name} ({:?})", r.result.err());
                continue;
            }
            Err(e) => {
                println!("EVAL_FAIL: {name} (decode: {e})");
                continue;
            }
        }
        if eval_only {
            // The first evaluation succeeded, so decoding does too.
            let program = decode(&bytes).expect("decode");
            c.bench_function(&name, |b| {
                b.iter_batched(|| program.clone(), |p| eval(black_box(p)), BatchSize::SmallInput)
            });
        } else {
            c.bench_function(&name, |b| b.iter(|| decode_and_eval(black_box(&bytes))));
        }
    }

    c.final_summary();
}
