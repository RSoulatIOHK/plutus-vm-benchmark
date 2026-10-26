// pvb harness for Chrysalis.Plutus (docs/IMAGE_CONTRACT.md). One program, two builds: chrysalis
// (.NET JIT) and chrysalis-aot (NativeAOT).
//
//   pvb-chrysalis check <vm> <data-dir> <cost-model.json> <out-csv>
//       One evaluation per *.flat in <data-dir> -> vm,script,status,cpu,mem
//   pvb-chrysalis time <vm> <script.flat> <cost-model.json> <loops> <timing> <trace>
//       The timed loops of one script (one process per script, spec D14), BenchmarkDotNet in
//       process: d3 (flat decode + evaluation), then eval (evaluation of the program decoded once).
//       <loops> is a comma list of d3, eval; <timing> normal | quick; <trace> 0 | 1.
//
// Parameters (check/README.md): PlutusV3 with the mainnet cost model of <cost-model.json>
// (array "PlutusV3"), costing on with a restricting budget too large to run out
// (ExBudget.Unlimited). Chrysalis.Plutus 1.7.14-alpha has no public API that takes a cost model
// once and then evaluates many terms: Evaluator.EvaluateScript rebuilds the cost model on every
// call, and the public CekMachine constructor uses the conformance model DefaultCosts.Create()
// (variant C division costs). So the harness calls the two internal members that EvaluateScript
// uses, CostModelLoader.FromFlatV3 (once) and the CekMachine constructor that takes the builtin
// costs (every iteration), through UnsafeAccessor. This works the same under the JIT and
// NativeAOT. Every iteration makes a new machine: its budget counter and evaluation state.

using System.Globalization;
using System.Runtime.CompilerServices;
using System.Text.Json;
using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Configs;
using BenchmarkDotNet.Engines;
using BenchmarkDotNet.Filters;
using BenchmarkDotNet.Jobs;
using BenchmarkDotNet.Reports;
using BenchmarkDotNet.Running;
using BenchmarkDotNet.Toolchains.InProcess.NoEmit;
using Perfolizer.Horology;
using Chrysalis.Plutus.Cek;
using Chrysalis.Plutus.Flat;
using Chrysalis.Plutus.Types;

namespace Pvb.Chrysalis;

static class Internals
{
    const string CostArray = "Chrysalis.Plutus.Cek.BuiltinCostModel[], Chrysalis.Plutus";

    /// CostModelLoader.FromFlatV3(IReadOnlyList<long>): the structured PlutusV3 builtin costs.
    [UnsafeAccessor(UnsafeAccessorKind.StaticMethod, Name = "FromFlatV3")]
    [return: UnsafeAccessorType(CostArray)]
    public static extern object FromFlatV3(
        [UnsafeAccessorType("Chrysalis.Plutus.Cek.CostModelLoader, Chrysalis.Plutus")] object? loader,
        IReadOnlyList<long> costs);

    /// internal CekMachine(ExBudget initialBudget, BuiltinCostModel[] builtinCosts)
    [UnsafeAccessor(UnsafeAccessorKind.Constructor)]
    public static extern CekMachine NewMachine(ExBudget initialBudget, [UnsafeAccessorType(CostArray)] object builtinCosts);
}

static class Vm
{
    public static readonly ExBudget Budget = ExBudget.Unlimited;

    public static object LoadCosts(string path)
    {
        using JsonDocument doc = JsonDocument.Parse(File.ReadAllBytes(path));
        long[] costs = doc.RootElement.GetProperty("PlutusV3").EnumerateArray().Select(e => e.GetInt64()).ToArray();
        return Internals.FromFlatV3(null, costs);
    }

    /// One evaluation; returns the status and the ExUnits spent (also when the evaluation fails).
    public static (string Status, long Cpu, long Mem, string? Error) Evaluate(Term<DeBruijn> term, object costs)
    {
        CekMachine machine = Internals.NewMachine(Budget, costs);
        string status = "ok";
        string? error = null;
        try
        {
            machine.Run(term);
        }
        catch (Exception e)
        {
            status = "error";
            error = $"{e.GetType().FullName}: {e.Message}";
        }
        ExBudget remaining = machine.RemainingBudget;
        return (status, Budget.Cpu - remaining.Cpu, Budget.Mem - remaining.Mem, error);
    }
}

/// The two timed loops. BenchmarkDotNet runs them in this process (InProcessNoEmitToolchain).
public class ChrysalisBench
{
    public static byte[] Flat = [];
    public static Term<DeBruijn> Decoded = null!;
    public static object Costs = null!;

    /// d3: flat decode + evaluation.
    [Benchmark]
    public Term<DeBruijn> D3()
    {
        Program<DeBruijn> program = FlatDecoder.DecodeProgram(Flat);
        return Internals.NewMachine(Vm.Budget, Costs).Run(program.Term);
    }

    /// eval: evaluation of the program decoded once before timing.
    [Benchmark]
    public Term<DeBruijn> Eval() => Internals.NewMachine(Vm.Budget, Costs).Run(Decoded);
}

static class Program
{
    static int Main(string[] args)
    {
        if (args.Length == 5 && args[0] == "check")
        {
            return Check(args[1], args[2], args[3], args[4]);
        }
        if (args.Length == 7 && args[0] == "time")
        {
            return Time(args[1], args[2], args[3], args[4].Split(','), args[5], args[6] == "1");
        }
        Console.Error.WriteLine("usage: pvb-chrysalis check <vm> <data-dir> <cost-model.json> <out-csv>");
        Console.Error.WriteLine("       pvb-chrysalis time <vm> <script.flat> <cost-model.json> <loops> <timing> <trace>");
        return 2;
    }

    static int Check(string vm, string dataDir, string costModel, string outCsv)
    {
        object costs = Vm.LoadCosts(costModel);
        using StreamWriter csv = new(outCsv);
        csv.WriteLine("vm,script,status,cpu,mem");
        foreach (string file in Directory.GetFiles(dataDir, "*.flat").Order(StringComparer.Ordinal))
        {
            string script = Path.GetFileNameWithoutExtension(file);
            try
            {
                Term<DeBruijn> term = FlatDecoder.DecodeProgram(File.ReadAllBytes(file)).Term;
                (string status, long cpu, long mem, string? error) = Vm.Evaluate(term, costs);
                if (error != null)
                {
                    Console.Error.WriteLine($"{script}: {error}");
                }
                csv.WriteLine($"{vm},{script},{status},{cpu},{mem}");
            }
            catch (Exception e)
            {
                Console.Error.WriteLine($"{script}: decode: {e.GetType().FullName}: {e.Message}");
                csv.WriteLine($"{vm},{script},error,,");
            }
        }
        return 0;
    }

    static int Time(string vm, string file, string costModel, string[] loops, string timing, bool trace)
    {
        string script = Path.GetFileNameWithoutExtension(file);
        ChrysalisBench.Costs = Vm.LoadCosts(costModel);
        ChrysalisBench.Flat = File.ReadAllBytes(file);
        ChrysalisBench.Decoded = FlatDecoder.DecodeProgram(ChrysalisBench.Flat).Term;

        // A script that fails is not timed: fill_failures.py gives it -1 rows ("EVAL_FAIL:").
        (string status, _, _, string? error) = Vm.Evaluate(ChrysalisBench.Decoded, ChrysalisBench.Costs);
        if (status != "ok")
        {
            Console.WriteLine($"EVAL_FAIL: {script} {error}");
            return 1;
        }

        bool aot = !System.Runtime.CompilerServices.RuntimeFeature.IsDynamicCodeSupported;
        Job job = MakeJob(aot, timing, trace).WithToolchain(new InProcessNoEmitToolchain(TimeSpan.FromHours(1), logOutput: true));
        foreach (string loop in new[] { "d3", "eval" }.Where(loops.Contains))
        {
            Console.WriteLine($"PVB_LOOP {loop} {script}");
            string method = loop == "d3" ? nameof(ChrysalisBench.D3) : nameof(ChrysalisBench.Eval);
            IConfig config = ManualConfig.CreateMinimumViable()
                .AddJob(job)
                .AddFilter(new NameFilter(name => name == method || name.EndsWith("." + method, StringComparison.Ordinal)))
                .WithArtifactsPath(Path.Combine(Path.GetTempPath(), "pvb-bdn"))
                .WithOptions(ConfigOptions.DisableLogFile);
            Summary summary = BenchmarkRunner.Run<ChrysalisBench>(config);
            BenchmarkReport? report = summary.Reports.FirstOrDefault();
            if (report is null || !report.Success)
            {
                Console.WriteLine($"EVAL_FAIL: {script} BenchmarkDotNet gave no result for loop {loop}");
                continue;
            }
            // The measurement iterations as rounds (ops, elapsed ns), the line of the JS harnesses:
            // parsers/parse_vitest.py computes the columns as parse_jmh.py does over JMH
            // iterations (mean of the iteration means, no overhead subtraction, no outlier removal).
            Console.WriteLine($"PVB_RESULT {{\"vm\":\"{vm}\",\"script\":\"{script}\",\"loop\":\"{loop}\",\"rounds\":[{Slices(report, IterationStage.Actual)}]}}");
            if (!aot)
            {
                // The warm-up has a fixed length, so "end" is "fixed" (parsers/parse_warmup.py).
                Console.WriteLine($"PVB_WARMUP {{\"script\":\"{script}\",\"loop\":\"{loop}\",\"slices\":[{Slices(report, IterationStage.Warmup)}],\"capped\":false,\"end\":\"fixed\"}}");
            }
        }
        return 0;
    }

    /// The workload iterations of one stage as JSON {"ops", "ns"} objects.
    static string Slices(BenchmarkReport report, IterationStage stage) => string.Join(",", report.AllMeasurements
        .Where(m => m.IterationMode == IterationMode.Workload && m.IterationStage == stage)
        .Select(m => FormattableString.Invariant($"{{\"ops\":{m.Operations},\"ns\":{m.Nanoseconds:F0}}}")));

    /// The BenchmarkDotNet job. JIT row (METHODOLOGY.md, D13), the JMH shape of the scalus rows:
    /// 30 s of warm-up (6 iterations of 5 s), then 3 measurement iterations of 5 s. Trace mode:
    /// the warm-up in 30 iterations of 1 s, and the measurement in 15 iterations of 1 s
    /// (BenchmarkDotNet has one iteration time for both stages). AOT row: BenchmarkDotNet's own
    /// defaults (ahead-of-time compiled VMs keep their framework's warm-up rules).
    /// Quick: one 1 s warm-up and one 1 s measurement iteration.
    static Job MakeJob(bool aot, string timing, bool trace)
    {
        Job job = new Job("pvb");
        if (timing == "quick")
        {
            return job.WithIterationTime(TimeInterval.FromMilliseconds(1000))
                .WithWarmupCount(1).WithIterationCount(1);
        }
        if (aot)
        {
            return job;
        }
        return trace
            ? job.WithIterationTime(TimeInterval.FromMilliseconds(1000))
                .WithWarmupCount(30).WithIterationCount(15)
            : job.WithIterationTime(TimeInterval.FromMilliseconds(5000))
                .WithWarmupCount(6).WithIterationCount(3);
    }
}
