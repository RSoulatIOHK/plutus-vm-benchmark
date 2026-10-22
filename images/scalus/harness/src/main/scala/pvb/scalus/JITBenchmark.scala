package pvb.scalus

import org.openjdk.jmh.annotations.*
import org.openjdk.jmh.infra.Blackhole
import scalus.uplc.eval.{CountingBudgetSpender, PlutusVM}

import java.util.concurrent.TimeUnit
import scala.annotation.nowarn

/** scalus-jit: per invocation, evaluation of the precompiled script with costing on (spec D3). Flat
  * decode + compile run once, in setup; their time is the compile column (spec D5,
  * `Check jit`). The setup also runs the warm-up (AdaptiveWarmup.scala).
  */
@State(Scope.Thread)
class JITBenchmark {
    @Param(Array("auction_1-1.flat"))
    @nowarn("msg=unset private variable")
    private var file: String = ""
    private var jitted: Harness.Jitted = null
    private var vm: PlutusVM = null

    @Setup(Level.Trial)
    def setup(bh: Blackhole): Unit = {
        vm = Harness.makeVM()
        jitted = Harness.jitCompile(Harness.readScript(file))
        AdaptiveWarmup.run(file.stripSuffix(".flat"), "d3", bh, () => benchJIT())
    }

    @Benchmark
    @BenchmarkMode(Array(Mode.AverageTime))
    @OutputTimeUnit(TimeUnit.MICROSECONDS)
    def benchJIT(): AnyRef = Harness.jitEval(vm, jitted, () => CountingBudgetSpender())
}
