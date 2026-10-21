// plutus-vm-benchmark harness for uplc-turbo. Replaces crates/uplc/benches/use_cases/main.rs
// of the pinned repo (images/uplc-turbo/Dockerfile). docs/IMAGE_CONTRACT.md, spec D3/D4/D11.
//
// Parameters (check/README.md, "Evaluation parameters"): PlutusV3, protocol version 11,
// counting mode (no limit), mainnet PlutusV3 cost model.
//
// Cost model: the timed loop uses Program::eval_version_budget(V3), which builds
// CostModel::<BuiltinCostsV3>::default() per call. Those are the variant E numbers, equal to the
// mainnet model. The mainnet array goes in through Program::eval_with_params only, because the
// crate keeps the cost model types private (pub(crate) mod cost_model): an outside harness cannot
// build the model once and reuse it, and eval_with_params rebuilds a 350-entry HashMap<String, _>
// on every call. The check evaluates every script both ways and reports any difference as a
// COSTMODEL_DRIFT line and an error row, so the timed path is proven to use the mainnet numbers.
//
// Modes:
//   PVB_CHECK_OUT=<csv>  one evaluation per script, write vm,script,status,cpu,mem; no timing
//   otherwise            Criterion timing, flat decode + eval per iteration. A script that fails
//                        its first evaluation prints "EVAL_FAIL: <name>" and is not timed.
//   PVB_EVAL_ONLY=1      Criterion timing of evaluation only (uplc-turbo-eval.csv): the program is
//                        decoded once into its own arena before timing; each iteration evaluates
//                        it into a second arena, which is reset after every iteration. The machine
//                        and its budget are new on every call (Program::eval_version_budget).
// Warm-up, measurement time and the script filter come from the command line
// (scripts/run-uplc-turbo.sh, which runs one process per script).
// PVB_COSTMODEL=<file>: the mainnet PlutusV3 array, one integer per line (run-uplc-turbo.sh).
// PVB_DATA_DIR=<dir>: read the .flat files from <dir> instead of DATA_DIR (run-uplc-turbo.sh
// passes the selected scripts, $BENCH_DATA_DIR).

use amaru_uplc::{
    arena::Arena,
    binder::DeBruijn,
    flat,
    machine::{ExBudget, PlutusVersion},
};
use bumpalo::Bump;
use criterion::Criterion;
use std::{fs, io::Write, path::PathBuf};

const DATA_DIR: &str = "benches/use_cases/plutus_use_cases";
const PROTOCOL_MAJOR: u32 = 11;

fn scripts() -> Vec<(String, Vec<u8>)> {
    let dir = std::env::var("PVB_DATA_DIR").unwrap_or_else(|_| DATA_DIR.to_string());
    let mut paths: Vec<PathBuf> = fs::read_dir(&dir)
        .unwrap_or_else(|e| panic!("cannot read {dir}: {e}"))
        .map(|e| e.unwrap().path())
        .filter(|p| p.is_file() && p.extension().is_some_and(|x| x == "flat"))
        .collect();
    paths.sort();
    paths
        .into_iter()
        .map(|p| {
            let name = p.file_stem().unwrap().to_str().unwrap().to_string();
            (name, fs::read(&p).unwrap())
        })
        .collect()
}

/// One evaluation as in the timed loop. Ok((cpu, mem)) or Err((message, cpu, mem)).
fn eval_once(arena: &Arena, bytes: &[u8]) -> Result<(i64, i64), (String, i64, i64)> {
    let program = flat::decode::<DeBruijn>(arena, bytes, PlutusVersion::V3, PROTOCOL_MAJOR)
        .map_err(|e| (format!("decode: {e:?}"), 0, 0))?;
    let result = program.eval_version_budget(arena, PlutusVersion::V3, ExBudget::max());
    let used = result.info.consumed_budget;
    match result.term {
        Ok(_) => Ok((used.cpu, used.mem)),
        Err(e) => Err((format!("{e:?}"), used.cpu, used.mem)),
    }
}

/// The same evaluation with the mainnet array passed in.
fn eval_mainnet(arena: &Arena, bytes: &[u8], cost_model: &[i64]) -> Option<(bool, i64, i64)> {
    let program =
        flat::decode::<DeBruijn>(arena, bytes, PlutusVersion::V3, PROTOCOL_MAJOR).ok()?;
    let result =
        program.eval_with_params(arena, PlutusVersion::V3, cost_model, ExBudget::max());
    let used = result.info.consumed_budget;
    Some((result.term.is_ok(), used.cpu, used.mem))
}

fn load_cost_model() -> Vec<i64> {
    let path = std::env::var("PVB_COSTMODEL").expect("set PVB_COSTMODEL");
    let values: Vec<i64> = fs::read_to_string(&path)
        .unwrap_or_else(|e| panic!("cannot read {path}: {e}"))
        .split_whitespace()
        .map(|s| s.parse().unwrap())
        .collect();
    assert_eq!(values.len(), 350, "{path}: expected the 350 PlutusV3 parameters");
    values
}

fn check(out: &str) {
    let cost_model = load_cost_model();
    let mut arena = Arena::from_bump(Bump::with_capacity(1_048_576));
    let mut csv = String::from("vm,script,status,cpu,mem\n");
    for (name, bytes) in scripts() {
        let (mut status, cpu, mem) = match eval_once(&arena, &bytes) {
            Ok((cpu, mem)) => ("ok", cpu, mem),
            Err((msg, cpu, mem)) => {
                let msg: String = msg.chars().take(200).collect();
                println!("CHECK_FAIL: {name}: {msg}");
                ("error", cpu, mem)
            }
        };
        arena.reset();
        let mainnet = eval_mainnet(&arena, &bytes, &cost_model);
        arena.reset();
        if mainnet != Some((status == "ok", cpu, mem)) {
            println!(
                "COSTMODEL_DRIFT: {name}: default V3 model gives ({status}, {cpu}, {mem}), \
                 mainnet array gives {mainnet:?}"
            );
            status = "error";
        }
        csv.push_str(&format!("uplc-turbo,{name},{status},{cpu},{mem}\n"));
    }
    fs::File::create(out)
        .and_then(|mut f| f.write_all(csv.as_bytes()))
        .unwrap_or_else(|e| panic!("cannot write {out}: {e}"));
}

fn bench(c: &mut Criterion) {
    let mut arena = Arena::from_bump(Bump::with_capacity(1_048_576));
    for (name, bytes) in scripts() {
        // A panic inside b.iter would abort the whole run: evaluate once first, skip on failure.
        let first = eval_once(&arena, &bytes);
        arena.reset();
        if let Err((msg, _, _)) = first {
            let msg: String = msg.chars().take(200).collect();
            println!("EVAL_FAIL: {name}");
            println!("  {msg}");
            continue;
        }
        c.bench_function(&name, |b| {
            b.iter(|| {
                let program =
                    flat::decode::<DeBruijn>(&arena, &bytes, PlutusVersion::V3, PROTOCOL_MAJOR)
                        .expect("decode");
                let result =
                    program.eval_version_budget(&arena, PlutusVersion::V3, ExBudget::max());
                std::hint::black_box(result.term.is_ok());
                arena.reset();
            })
        });
    }
}

fn bench_eval_only(c: &mut Criterion) {
    let mut arena = Arena::from_bump(Bump::with_capacity(1_048_576));
    for (name, bytes) in scripts() {
        let first = eval_once(&arena, &bytes);
        arena.reset();
        if let Err((msg, _, _)) = first {
            let msg: String = msg.chars().take(200).collect();
            println!("EVAL_FAIL: {name}");
            println!("  {msg}");
            continue;
        }
        // The decoded program lives in its own arena for the whole benchmark of this script.
        let program_arena = Arena::from_bump(Bump::with_capacity(1_048_576));
        let program =
            flat::decode::<DeBruijn>(&program_arena, &bytes, PlutusVersion::V3, PROTOCOL_MAJOR)
                .expect("decode");
        c.bench_function(&name, |b| {
            b.iter(|| {
                let result = program.eval_version_budget(&arena, PlutusVersion::V3, ExBudget::max());
                std::hint::black_box(result.term.is_ok());
                drop(result);
                arena.reset();
            })
        });
    }
}

fn main() {
    if let Ok(out) = std::env::var("PVB_CHECK_OUT") {
        check(&out);
        return;
    }
    let mut c = Criterion::default().configure_from_args();
    if std::env::var("PVB_EVAL_ONLY").is_ok_and(|v| v == "1") {
        bench_eval_only(&mut c);
    } else {
        bench(&mut c);
    }
    c.final_summary();
}
