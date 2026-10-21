package pvb.scalus

import org.openjdk.jmh.annotations.*
import scalus.uplc.Term
import scalus.uplc.eval.{CountingBudgetSpender, PlutusVM}

import java.util.concurrent.TimeUnit
import scala.annotation.nowarn

/** scalus-cek: per invocation, flat decode + CEK evaluation with costing on (spec D3). */
@State(Scope.Thread)
class CekJVMBenchmark {
    @Param(Array("auction_1-1.flat"))
    @nowarn("msg=unset private variable")
    private var file: String = ""
    private var flat: Array[Byte] = null
    private var vm: PlutusVM = null

    @Setup
    def setup(): Unit = {
        vm = Harness.makeVM()
        flat = Harness.readScript(file)
    }

    @Benchmark
    @BenchmarkMode(Array(Mode.AverageTime))
    @OutputTimeUnit(TimeUnit.MICROSECONDS)
    def bench(): Term = Harness.cekEval(vm, flat, CountingBudgetSpender())
}
