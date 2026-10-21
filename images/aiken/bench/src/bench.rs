//! Criterion timing of decode + eval for every script.
//!
//! Each script is one top-level benchmark named after the script, so Criterion
//! writes `<CRITERION_HOME>/<script>/new/estimates.json` (what
//! `parsers/parse_criterion.py` reads). A script that fails its first
//! evaluation is printed as `EVAL_FAIL: <script>` and not timed.

use aiken_bench::{data_dir, decode_and_eval, quick, scripts, silence_panics};
use criterion::{Criterion, black_box};
use std::time::Duration;

fn main() {
    silence_panics();
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
        c.bench_function(&name, |b| b.iter(|| decode_and_eval(black_box(&bytes))));
    }

    c.final_summary();
}
