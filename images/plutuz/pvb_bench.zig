//! pvb harness for Plutuz (docs/IMAGE_CONTRACT.md). Built inside the Plutuz source tree as the
//! `pvb-bench` executable (images/plutuz/Dockerfile).
//!
//!   pvb-bench check <costmodel.json> <out.csv> <data-dir>
//!       One evaluation per *.flat file of <data-dir>: vm,script,status,cpu,mem.
//!   pvb-bench time <costmodel.json> <script.flat> <loops> <measure-ms>
//!       The timed loops of one script (one process per script, spec D14). <loops> is a comma
//!       list of d3 and eval, run in that order. Prints "PVB_LOOP <loop> <script>" when a loop
//!       starts and one "PVB_RESULT {...}" line per loop (parsers/parse_plutuz_json.py).
//!
//! Evaluation parameters (check/README.md):
//! - PlutusV3, protocol version 11: Plutuz has one semantics switch, SemanticsVariant a, b, c.
//!   The harness sets .c, the Plutus V3 variant (Plutuz's default); it has case on builtin values
//!   and the PV11 builtins.
//! - Cost model: Plutuz has no cost model loader, but Machine.costs is a plain field. The harness
//!   copies Plutuz's built-in model (variant C) and overwrites every number with the mainnet value
//!   of the same parameter name (PlutusV3Named). The cost function shapes stay those of Plutuz. A
//!   builtin whose shape needs a parameter that the mainnet model lacks keeps its built-in numbers
//!   and is listed on stderr ("cost model: keep").
//! - Restricting mode with a budget of maxInt(i64) for cpu and mem, too large to run out. The
//!   ExUnits of one evaluation are maxInt(i64) minus the remaining budget.
//!
//! Timing: the rules of Plutuz's own bench (bench/bench.zig at the pinned commit): 5 warm-up
//! iterations, then timed iterations until at least 50 iterations and <measure-ms> have passed.
//! Each iteration is timed alone with std.time.Timer. Each iteration uses an arena that is reset
//! (retain_capacity) after it, as in bench/bench.zig. Upstream stops at 10 000 samples; this
//! harness has no such cap, so every script gets at least <measure-ms> of measurement (spec D13).
//! - d3: flat decode + evaluation per iteration.
//! - eval: evaluation of a program decoded once before timing.
//! The cost model is built once per process. A new Machine (budget counter and state) is made in
//! every iteration, as plutuz.eval does.

const std = @import("std");
const plutuz = @import("plutuz");

const Machine = plutuz.DeBruijnMachine;
const CostModel = plutuz.cek.CostModel;
const ExBudget = plutuz.cek.ExBudget;
const DefaultFunction = plutuz.ast.DefaultFunction;
const costing = plutuz.cek.costing;
const Program = plutuz.DeBruijnProgram;

const WARMUP_ITERATIONS = 5;
const MIN_ITERATIONS = 50;

// ===== Cost model ==========================================================================

const Params = struct {
    values: std.StringArrayHashMap(i64),
    used: std.StringArrayHashMap(void),

    fn get(self: *Params, key: []const u8) ?i64 {
        const e = self.values.getEntry(key) orelse return null;
        // The key of `values` outlives `key`, which may be a stack buffer.
        self.used.put(e.key_ptr.*, {}) catch {};
        return e.value_ptr.*;
    }
};

/// Parameter name suffix of a cost function field. Plutuz names follow plutus except these.
fn suffix(comptime T: type, comptime field: []const u8) []const u8 {
    if (T == costing.ThreeArgCost.ExpMod) return "coefficient" ++ field["coeff_".len..];
    if (std.mem.eql(u8, field, "slope_y")) return "slope1";
    if (std.mem.eql(u8, field, "slope_z")) return "slope2";
    if (std.mem.startsWith(u8, field, "coeff_")) return "c" ++ field["coeff_".len..];
    return field;
}

/// Fill the numbers of a cost function payload from `key` (a bare i64) or `key-<field>`.
fn fillPayload(comptime T: type, a: std.mem.Allocator, p: *T, params: *Params, key: []const u8) !bool {
    if (T == i64) {
        p.* = params.get(key) orelse return false;
        return true;
    }
    inline for (std.meta.fields(T)) |f| {
        if (f.type == i64) {
            const k = try std.fmt.allocPrint(a, "{s}-{s}", .{ key, comptime suffix(T, f.name) });
            @field(p, f.name) = params.get(k) orelse return false;
        } else {
            // The polynomial of const_above_diagonal / const_below_diagonal.
            const k = try std.fmt.allocPrint(a, "{s}-model-arguments", .{key});
            if (!try fillPayload(f.type, a, &@field(p, f.name), params, k)) return false;
        }
    }
    return true;
}

fn fillCost(comptime U: type, a: std.mem.Allocator, u: *U, params: *Params, key: []const u8) !bool {
    switch (u.*) {
        inline else => |*payload| return fillPayload(@TypeOf(payload.*), a, payload, params, key),
    }
}

fn setStep(target: *ExBudget, params: *Params, name: []const u8) !void {
    var buf: [64]u8 = undefined;
    const cpu = std.fmt.bufPrint(&buf, "{s}-exBudgetCPU", .{name}) catch unreachable;
    target.cpu = params.get(cpu) orelse return error.MissingMachineCost;
    const mem = std.fmt.bufPrint(&buf, "{s}-exBudgetMemory", .{name}) catch unreachable;
    target.mem = params.get(mem) orelse return error.MissingMachineCost;
}

/// Plutuz's built-in model with every number replaced by the mainnet value (see the header).
fn loadCostModel(a: std.mem.Allocator, path: []const u8) !CostModel {
    const bytes = try std.fs.cwd().readFileAlloc(a, path, 1 << 20);
    const parsed = try std.json.parseFromSlice(std.json.Value, a, bytes, .{});
    const named = parsed.value.object.get("PlutusV3Named") orelse return error.NoPlutusV3Named;

    var params = Params{
        .values = std.StringArrayHashMap(i64).init(a),
        .used = std.StringArrayHashMap(void).init(a),
    };
    var it = named.object.iterator();
    while (it.next()) |e| try params.values.put(e.key_ptr.*, e.value_ptr.integer);

    var model = CostModel.default;
    const mc = &model.machine_costs;
    try setStep(&mc.startup, &params, "cekStartupCost");
    try setStep(&mc.constant, &params, "cekConstCost");
    try setStep(&mc.var_, &params, "cekVarCost");
    try setStep(&mc.lambda, &params, "cekLamCost");
    try setStep(&mc.apply, &params, "cekApplyCost");
    try setStep(&mc.delay, &params, "cekDelayCost");
    try setStep(&mc.force, &params, "cekForceCost");
    try setStep(&mc.builtin, &params, "cekBuiltinCost");
    try setStep(&mc.constr, &params, "cekConstrCost");
    try setStep(&mc.case, &params, "cekCaseCost");

    // The builtin names of the mainnet model: the part of a parameter name before
    // "-cpu-arguments" (every builtin has a cpu cost).
    var builtins = std.StringArrayHashMap(void).init(a);
    for (params.values.keys()) |key| {
        const at = std.mem.indexOf(u8, key, "-cpu-arguments") orelse continue;
        try builtins.put(key[0..at], {});
    }
    var loaded: usize = 0;
    var kept: usize = 0;
    for (builtins.keys()) |name| {
        const fun = DefaultFunction.fromName(name) orelse {
            std.debug.print("cost model: no Plutuz builtin {s}\n", .{name});
            continue;
        };
        const slot = &model.builtin_costs[@intFromEnum(fun)];
        var candidate = slot.*;
        const ok = switch (candidate) {
            inline else => |*cf| blk: {
                const cpu_key = try std.fmt.allocPrint(a, "{s}-cpu-arguments", .{name});
                const mem_key = try std.fmt.allocPrint(a, "{s}-memory-arguments", .{name});
                break :blk try fillCost(@TypeOf(cf.cpu), a, &cf.cpu, &params, cpu_key) and
                    try fillCost(@TypeOf(cf.mem), a, &cf.mem, &params, mem_key);
            },
        };
        if (ok) {
            slot.* = candidate;
            loaded += 1;
        } else {
            kept += 1;
            std.debug.print("cost model: keep the built-in numbers of {s}: its Plutuz shape (cpu {s}, mem {s}) needs a parameter that the mainnet model lacks\n", .{
                name, shapeName(slot.*, .cpu), shapeName(slot.*, .mem),
            });
        }
    }

    var unused: usize = 0;
    var all = params.values.iterator();
    while (all.next()) |e| {
        if (!params.used.contains(e.key_ptr.*)) {
            unused += 1;
            std.debug.print("cost model: unused mainnet parameter {s}\n", .{e.key_ptr.*});
        }
    }
    std.debug.print("cost model: {d} mainnet parameters, {d} builtins loaded, {d} kept built-in, {d} parameters unused\n", .{
        params.values.count(), loaded, kept, unused,
    });
    return model;
}

fn shapeName(m: costing.BuiltinCostModel, comptime which: enum { cpu, mem }) []const u8 {
    return switch (m) {
        inline else => |cf| @tagName(@field(cf, @tagName(which))),
    };
}

// ===== Evaluation ==========================================================================

const Outcome = struct { ok: bool, cpu: i64, mem: i64 };

fn evaluate(a: std.mem.Allocator, model: *const CostModel, program: *const Program) Outcome {
    var m = Machine.init(a);
    m.costs = model.*;
    m.semantics = .c;
    m.restricting = true;
    m.budget = ExBudget.unlimited;
    const ok = if (m.run(program.term)) |_| true else |_| false;
    return .{
        .ok = ok,
        .cpu = ExBudget.unlimited.cpu - m.budget.cpu,
        .mem = ExBudget.unlimited.mem - m.budget.mem,
    };
}

fn scriptName(path: []const u8) []const u8 {
    const base = std.fs.path.basename(path);
    return if (std.mem.endsWith(u8, base, ".flat")) base[0 .. base.len - ".flat".len] else base;
}

fn check(gpa: std.mem.Allocator, model: *const CostModel, out_path: []const u8, data_dir: []const u8) !void {
    var dir = try std.fs.cwd().openDir(data_dir, .{ .iterate = true });
    defer dir.close();

    var files: std.ArrayList([]const u8) = .empty;
    var it = dir.iterate();
    while (try it.next()) |e| {
        if (e.kind == .directory or !std.mem.endsWith(u8, e.name, ".flat")) continue;
        try files.append(gpa, try gpa.dupe(u8, e.name));
    }
    std.mem.sort([]const u8, files.items, {}, struct {
        fn lt(_: void, x: []const u8, y: []const u8) bool {
            return std.mem.order(u8, x, y) == .lt;
        }
    }.lt);

    var csv: std.ArrayList(u8) = .empty;
    try csv.appendSlice(gpa, "vm,script,status,cpu,mem\n");
    for (files.items) |file| {
        const name = scriptName(file);
        var arena = std.heap.ArenaAllocator.init(gpa);
        defer arena.deinit();
        const a = arena.allocator();
        const bytes = try dir.readFileAlloc(a, file, 64 << 20);
        const program = plutuz.decodeFlatDeBruijn(a, bytes) catch |err| {
            std.debug.print("{s}: decode error: {}\n", .{ name, err });
            try csv.print(gpa, "plutuz,{s},error,,\n", .{name});
            continue;
        };
        const r = evaluate(a, model, program);
        if (r.ok) {
            try csv.print(gpa, "plutuz,{s},ok,{d},{d}\n", .{ name, r.cpu, r.mem });
        } else {
            try csv.print(gpa, "plutuz,{s},error,,\n", .{name});
        }
        std.debug.print("{s}: {s} cpu={d} mem={d}\n", .{ name, if (r.ok) "ok" else "error", r.cpu, r.mem });
    }
    const out = try std.fs.cwd().createFile(out_path, .{});
    defer out.close();
    try out.writeAll(csv.items);
}

// ===== Timing ==============================================================================

const Loop = enum { d3, eval };

fn timeLoop(
    gpa: std.mem.Allocator,
    model: *const CostModel,
    loop: Loop,
    name: []const u8,
    bytes: []const u8,
    decoded: *const Program,
    measure_ns: u64,
) !void {
    std.debug.print("PVB_LOOP {s} {s}\n", .{ @tagName(loop), name });

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var samples: std.ArrayList(u64) = .empty;
    defer samples.deinit(gpa);
    var timer = try std.time.Timer.start();
    var total: u64 = 0;
    var i: usize = 0;
    while (true) : (i += 1) {
        const warm = i < WARMUP_ITERATIONS;
        if (!warm and samples.items.len >= MIN_ITERATIONS and total >= measure_ns) break;
        timer.reset();
        const program = switch (loop) {
            .d3 => try plutuz.decodeFlatDeBruijn(arena.allocator(), bytes),
            .eval => decoded,
        };
        const r = evaluate(arena.allocator(), model, program);
        const elapsed = timer.read();
        std.mem.doNotOptimizeAway(r);
        _ = arena.reset(.retain_capacity);
        if (warm) continue;
        try samples.append(gpa, elapsed);
        total += elapsed;
    }

    const s = samples.items;
    std.mem.sort(u64, s, {}, std.sort.asc(u64));
    var sum: u128 = 0;
    for (s) |x| sum += x;
    const mean: f64 = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(s.len));
    var var_sum: f64 = 0;
    for (s) |x| {
        const d = @as(f64, @floatFromInt(x)) - mean;
        var_sum += d * d;
    }
    const median: f64 = if (s.len % 2 == 0)
        (@as(f64, @floatFromInt(s[s.len / 2 - 1])) + @as(f64, @floatFromInt(s[s.len / 2]))) / 2
    else
        @floatFromInt(s[s.len / 2]);

    var line: std.ArrayList(u8) = .empty;
    defer line.deinit(gpa);
    try line.print(gpa, "PVB_RESULT {{\"name\":\"{s}\",\"loop\":\"{s}\",\"iterations\":{d},\"mean_ns\":{d:.0},\"median_ns\":{d:.0},\"min_ns\":{d},\"max_ns\":{d},\"stddev_ns\":{d:.0}}}\n", .{
        name,         @tagName(loop), s.len, mean, median, s[0], s[s.len - 1],
        @sqrt(var_sum / @as(f64, @floatFromInt(s.len))),
    });
    try std.fs.File.stdout().writeAll(line.items);
}

fn time(gpa: std.mem.Allocator, model: *const CostModel, path: []const u8, loops: []const u8, measure_ms: u64) !void {
    const name = scriptName(path);
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    const bytes = try std.fs.cwd().readFileAlloc(a, path, 64 << 20);

    // One evaluation before timing: a script that fails is reported, not timed.
    const program = plutuz.decodeFlatDeBruijn(a, bytes) catch |err| {
        std.debug.print("EVAL_FAIL: {s} (decode: {})\n", .{ name, err });
        return;
    };
    var first = std.heap.ArenaAllocator.init(gpa);
    const r = evaluate(first.allocator(), model, program);
    first.deinit();
    if (!r.ok) {
        std.debug.print("EVAL_FAIL: {s}\n", .{name});
        return;
    }

    const measure_ns = measure_ms * std.time.ns_per_ms;
    inline for (.{ Loop.d3, Loop.eval }) |loop| {
        var want = std.mem.tokenizeScalar(u8, loops, ',');
        while (want.next()) |w| {
            if (std.mem.eql(u8, w, @tagName(loop))) {
                try timeLoop(gpa, model, loop, name, bytes, program, measure_ns);
            }
        }
    }
}

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_state.allocator();
    var setup = std.heap.ArenaAllocator.init(gpa);
    const args = try std.process.argsAlloc(setup.allocator());

    const usage = "usage: pvb-bench check <costmodel.json> <out.csv> <data-dir>\n" ++
        "       pvb-bench time <costmodel.json> <script.flat> <loops> <measure-ms>\n";
    if (args.len < 2) {
        std.debug.print(usage, .{});
        std.process.exit(2);
    }
    if (std.mem.eql(u8, args[1], "check") and args.len == 5) {
        const model = try loadCostModel(setup.allocator(), args[2]);
        try check(gpa, &model, args[3], args[4]);
    } else if (std.mem.eql(u8, args[1], "time") and args.len == 6) {
        const model = try loadCostModel(setup.allocator(), args[2]);
        try time(gpa, &model, args[3], args[4], try std.fmt.parseInt(u64, args[5], 10));
    } else {
        std.debug.print(usage, .{});
        std.process.exit(2);
    }
}
