//! One evaluation per script; prints `<vm>-check.csv` to stdout.
//!
//! `status` is `ok` when the machine ran the term to a value, `error` when it
//! failed or the flat could not be decoded. `cpu`/`mem` are the consumed
//! budget, also for a failed run (empty when decoding failed).

use aiken_bench::{data_dir, decode_and_eval, scripts, silence_panics};

fn main() {
    silence_panics();
    println!("vm,script,status,cpu,mem");
    for (name, bytes) in scripts(&data_dir()) {
        match decode_and_eval(&bytes) {
            Ok(r) => {
                let cost = r.cost();
                let status = if r.result.is_ok() { "ok" } else { "error" };
                if let Err(e) = &r.result {
                    eprintln!("CHECK_ERROR: {name}: {e:?}");
                }
                println!("aiken,{name},{status},{},{}", cost.cpu, cost.mem);
            }
            Err(e) => {
                eprintln!("CHECK_ERROR: {name}: decode: {e}");
                println!("aiken,{name},error,,");
            }
        }
    }
}
