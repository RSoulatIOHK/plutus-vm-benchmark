package pvb.scalus

import org.openjdk.jmh.annotations.*
import scalus.uplc.eval.{BudgetSpender, PlutusVM}
import scalus.uplc.jit.UplcEvaluator

import java.util.concurrent.TimeUnit
import scala.annotation.nowarn

/** scalus-jit: per invocation, evaluation of the precompiled script with costing on (spec D3). Flat
  * decode + compile run once, in setup; their time is the compile column (spec D5,
  * `Check jit`).
  */
@State(Scope.Thread)
class JITBenchmark {
    @Param(Array("auction_1-1.flat"))
    @nowarn("msg=unset private variable")
    private var file: String = ""
    private var jitted: UplcEvaluator = null
    private var vm: PlutusVM = null

    @Setup
    def setup(): Unit = {
        vm = Harness.makeVM()
        jitted = Harness.jitCompile(Harness.readScript(file))
    }

    @Benchmark
    @BenchmarkMode(Array(Mode.AverageTime))
    @OutputTimeUnit(TimeUnit.MICROSECONDS)
    def benchJIT(): AnyRef = {
        // The spender is the result, so JMH consumes the evaluation's budget.
        var spender: BudgetSpender = null
        Harness.jitEval(vm, jitted, () => { spender = Harness.newSpender(); spender })
        spender
    }
}
