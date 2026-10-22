package pvb.scalus

import org.openjdk.jmh.annotations.*
import org.openjdk.jmh.infra.{BenchmarkParams, Blackhole}
import scalus.uplc.Term
import scalus.uplc.eval.{CountingBudgetSpender, PlutusVM}

import java.util.concurrent.TimeUnit
import scala.annotation.nowarn

/** scalus-cek, two timed methods (docs/IMAGE_CONTRACT.md):
  *   - `bench`: per invocation, flat decode + CEK evaluation with costing on (spec D3, the ranking).
  *   - `benchEval`: per invocation, CEK evaluation of the program decoded once in setup
  *     (`scalus-cek-eval.csv`).
  *
  * Both reuse the VM (machine parameters from the cost model) and make a new counting budget spender
  * and CEK state per invocation.
  *
  * JMH forks one JVM per method and script. The setup warms up the method of its fork
  * (AdaptiveWarmup.scala).
  */
@State(Scope.Thread)
class CekJVMBenchmark {
    @Param(Array("auction_1-1.flat"))
    @nowarn("msg=unset private variable")
    private var file: String = ""
    private var flat: Array[Byte] = null
    private var term: Term = null
    private var vm: PlutusVM = null

    @Setup(Level.Trial)
    def setup(params: BenchmarkParams, bh: Blackhole): Unit = {
        vm = Harness.makeVM()
        flat = Harness.readScript(file)
        term = Harness.decode(flat).term
        val script = file.stripSuffix(".flat")
        if params.getBenchmark.endsWith(".benchEval") then
            AdaptiveWarmup.run(script, "eval", bh, () => benchEval())
        else AdaptiveWarmup.run(script, "d3", bh, () => bench())
    }

    @Benchmark
    @BenchmarkMode(Array(Mode.AverageTime))
    @OutputTimeUnit(TimeUnit.MICROSECONDS)
    def bench(): Term = Harness.cekEval(vm, flat, CountingBudgetSpender())

    @Benchmark
    @BenchmarkMode(Array(Mode.AverageTime))
    @OutputTimeUnit(TimeUnit.MICROSECONDS)
    def benchEval(): Term = Harness.cekEvalTerm(vm, term, CountingBudgetSpender())
}
