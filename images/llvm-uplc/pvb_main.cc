// pvb-llvm-uplc: the benchmark harness of the lantr Plutus VM benchmark for llvm-uplc
// (docs/IMAGE_CONTRACT.md). The image builds it in place of tools/bench/main.cc, so it links like
// upstream uplcbench (whole-archive libuplcrt, LLVM).
//
//   pvb-llvm-uplc time  <script.flat> <json-out> <min-time-s> <max-time-s>
//   pvb-llvm-uplc check <flat-dir> <check.csv> <compile.csv> <compile-runs>
//
// Parameters: llvm-uplc has no API for a cost model. Its builtin costs are compiled in
// (runtime/core/builtin_table.c, the plutus variant C numbers) and the machine costs too
// (runtime/core/budget.c: 16000 cpu / 100 mem per step, startup 100 / 100). Costing is on: a
// restricting budget of INT64_MAX cpu and mem, too large to run out.
//
// time: decode + compile the script once (LLJIT, outside timing), then the timed loop of upstream
// uplcbench: per iteration a fresh arena and budget and one call of the compiled program. Warm-up
// of 5 iterations, then at least 50 iterations and <min-time-s>, at most <max-time-s>. Unlike
// upstream, a failed evaluation is an error (no timing row), not a sample. Writes the upstream
// uplcbench JSON ({"benchmarks": [...], "failures": [...]}) to <json-out>.
//
// check: per script (C sort order), the median time of <compile-runs> flat decodes + compiles ->
// compile.csv (vm,script,compile_ns), then one evaluation -> check.csv (vm,script,status,cpu,mem).
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>

#include "runtime/compiled/entry.h"
#include "runtime/core/arena.h"
#include "uplc/budget.h"

#include "compiler/jit/codegen_pipeline.h"
#include "compiler/jit/jit_runner.h"

namespace fs = std::filesystem;
using clk = std::chrono::steady_clock;

namespace {

constexpr const char* kVm = "llvm-uplc-jit";

std::vector<std::uint8_t> read_bytes(const fs::path& p) {
    std::ifstream f(p, std::ios::binary);
    if (!f) throw std::runtime_error("cannot read " + p.string());
    return {std::istreambuf_iterator<char>(f), std::istreambuf_iterator<char>()};
}

std::int64_t ns_since(clk::time_point t0) {
    return std::chrono::duration_cast<std::chrono::nanoseconds>(clk::now() - t0).count();
}

// Flat decode + the llvm-uplc pipeline + LLJIT codegen and lookup of program_entry.
uplc::JitProgram compile(uplc::JitRunner& jit, const std::vector<std::uint8_t>& bytes,
                         const std::string& id) {
    uplc::Pipeline p;
    uplc::build_pipeline_from_flat(bytes.data(), bytes.size(), p);
    return jit.add_pipeline(p, id);
}

struct Eval {
    bool ok;
    std::string error;
    std::int64_t cpu, mem;  // consumed
};

// One evaluation with a fresh arena and budget, as in every timed iteration.
Eval evaluate(uplc_program_entry entry) {
    uplc_arena* arena = uplc_arena_create();
    uplc_budget budget;
    uplcrt_budget_init(&budget, INT64_MAX, INT64_MAX);
    uplc_compiled_result r = uplcrt_run_compiled(entry, arena, &budget);
    Eval e{r.ok != 0, r.ok ? "" : (r.fail_message ? r.fail_message : "evaluation failure"),
           budget.initial_cpu - budget.cpu, budget.initial_mem - budget.mem};
    uplc_arena_destroy(arena);
    return e;
}

// One timed iteration, the same work as upstream uplcbench run_one_compiled. -1 on failure.
std::int64_t run_one(uplc_program_entry entry) {
    auto t0 = clk::now();
    uplc_arena* arena = uplc_arena_create();
    uplc_budget budget;
    uplcrt_budget_init(&budget, INT64_MAX, INT64_MAX);
    uplc_compiled_result r = uplcrt_run_compiled(entry, arena, &budget);
    uplc_arena_destroy(arena);
    std::int64_t ns = ns_since(t0);
    return r.ok ? ns : -1;
}

int cmd_time(const fs::path& flat, const fs::path& out, double min_s, double max_s) {
    const std::string name = flat.stem().string();
    std::string error;
    std::vector<std::int64_t> samples;
    try {
        uplc::JitRunner jit;
        auto bytes = read_bytes(flat);
        auto c0 = clk::now();
        uplc::JitProgram prog = compile(jit, bytes, name);
        std::fprintf(stderr, "%s: compile %.3f ms\n", name.c_str(), ns_since(c0) / 1e6);
        uplc_program_entry entry = prog.entry;

        for (int i = 0; i < 5 && error.empty(); ++i)
            if (run_one(entry) < 0) error = "warmup failure: " + evaluate(entry).error;
        auto start = clk::now();
        auto min_t = start + std::chrono::duration<double>(min_s);
        auto max_t = start + std::chrono::duration<double>(max_s);
        while (error.empty()) {
            std::int64_t ns = run_one(entry);
            if (ns < 0) { error = "measurement failure: " + evaluate(entry).error; break; }
            samples.push_back(ns);
            auto now = clk::now();
            if ((samples.size() >= 50 && now >= min_t) || now >= max_t) break;
        }
    } catch (const std::exception& e) {
        error = std::string("compile failure: ") + e.what();
    }

    std::ofstream os(out);
    if (!error.empty()) {
        std::fprintf(stderr, "FAIL %s: %s\n", name.c_str(), error.c_str());
        os << "{\"benchmarks\": [], \"failures\": [{\"name\": \"" << name << "\"}]}\n";
        return 0;
    }
    std::sort(samples.begin(), samples.end());
    long double sum = 0;
    for (auto v : samples) sum += v;
    long double mean = sum / samples.size();
    long double var = 0;
    for (auto v : samples) var += (v - mean) * (v - mean);
    var /= samples.size();
    os << "{\"benchmarks\": [{\"name\": \"" << name << "\""
       << ", \"mean_ns\": " << static_cast<std::uint64_t>(mean + 0.5L)
       << ", \"median_ns\": " << samples[samples.size() / 2]
       << ", \"min_ns\": " << samples.front()
       << ", \"max_ns\": " << samples.back()
       << ", \"stddev_ns\": " << static_cast<std::uint64_t>(std::sqrt(static_cast<double>(var)) + 0.5)
       << ", \"iterations\": " << samples.size() << "}], \"failures\": []}\n";
    std::fprintf(stderr, "%s: median %.3f us, %zu iterations\n", name.c_str(),
                 samples[samples.size() / 2] / 1e3, samples.size());
    return 0;
}

int cmd_check(const fs::path& dir, const fs::path& check_out, const fs::path& compile_out,
              int runs) {
    std::vector<fs::path> files;
    for (auto& e : fs::directory_iterator(dir))
        if (e.path().extension() == ".flat") files.push_back(e.path());
    std::sort(files.begin(), files.end());

    uplc::JitRunner jit;
    std::ofstream check(check_out), comp(compile_out);
    check << "vm,script,status,cpu,mem\n";
    comp << "vm,script,compile_ns\n";
    for (const auto& f : files) {
        const std::string name = f.stem().string();
        try {
            auto bytes = read_bytes(f);
            std::vector<std::int64_t> times;
            uplc::JitProgram prog;
            for (int i = 0; i < runs; ++i) {
                if (prog.dylib) jit.remove(*prog.dylib);
                auto c0 = clk::now();
                prog = compile(jit, bytes, name + "#" + std::to_string(i));
                times.push_back(ns_since(c0));
            }
            std::sort(times.begin(), times.end());
            comp << kVm << "," << name << "," << times[times.size() / 2] << "\n";
            Eval e = evaluate(prog.entry);
            jit.remove(*prog.dylib);
            if (e.ok) {
                check << kVm << "," << name << ",ok," << e.cpu << "," << e.mem << "\n";
                std::fprintf(stderr, "%s: ok cpu=%lld mem=%lld\n", name.c_str(),
                             (long long)e.cpu, (long long)e.mem);
            } else {
                check << kVm << "," << name << ",error,,\n";
                std::fprintf(stderr, "%s: error: %s\n", name.c_str(), e.error.c_str());
            }
        } catch (const std::exception& e) {
            check << kVm << "," << name << ",error,,\n";
            std::fprintf(stderr, "%s: compile failure: %s\n", name.c_str(), e.what());
        }
        check.flush();
        comp.flush();
    }
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    std::string cmd = argc > 1 ? argv[1] : "";
    if (cmd == "time" && argc == 6)
        return cmd_time(argv[2], argv[3], std::stod(argv[4]), std::stod(argv[5]));
    if (cmd == "check" && argc == 6)
        return cmd_check(argv[2], argv[3], argv[4], std::stoi(argv[5]));
    std::fprintf(stderr,
                 "usage: pvb-llvm-uplc time <script.flat> <json-out> <min-time-s> <max-time-s>\n"
                 "       pvb-llvm-uplc check <flat-dir> <check.csv> <compile.csv> <compile-runs>\n");
    return 2;
}
