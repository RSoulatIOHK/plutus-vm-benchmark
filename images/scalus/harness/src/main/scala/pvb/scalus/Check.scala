package pvb.scalus

import scalus.uplc.eval.{BudgetSpender, CountingBudgetSpender}
import scalus.uplc.jit.UplcEvaluator

import java.io.PrintWriter
import java.nio.file.{Files, Path, Paths}
import scala.jdk.CollectionConverters.*
import scala.util.control.NonFatal

/** The correctness check (spec D4) and the JIT compile column (spec D5).
  *
  * {{{
  * Check cek <results-dir>   writes scalus-cek-check.csv
  * Check jit <results-dir>   writes scalus-jit-check.csv and scalus-jit-compile.csv
  * }}}
  * One evaluation per `.flat` file of `$BENCH_DATA_DIR`, with the same code and parameters as the
  * timed loop (Harness).
  *
  * Compile time: flat decode + JIT compile, the median of `$SCALUS_JIT_COMPILE_RUNS` (default 3)
  * fresh compiles of the script, in one JVM, after one discarded warm-up compile of the first
  * script. The check evaluates the last of them.
  */
object Check {
    def main(args: Array[String]): Unit = {
        val Array(mode, out) = args
        val files = Files
            .list(Harness.dataDir)
            .iterator()
            .asScala
            .map(_.getFileName.toString)
            .filter(_.endsWith(".flat"))
            .toList
            .sorted
        val vm = Harness.makeVM()
        val outDir = Paths.get(out)
        mode match
            case "cek" =>
                withCsv(outDir.resolve("scalus-cek-check.csv"), "vm,script,status,cpu,mem") { check =>
                    for f <- files do
                        val flat = Harness.readScript(f)
                        val spender = CountingBudgetSpender()
                        val status = run(f)(Harness.cekEval(vm, flat, spender))
                        check.println(row("scalus-cek", f, status, spender))
                }
            case "jit" =>
                val runs = sys.env.getOrElse("SCALUS_JIT_COMPILE_RUNS", "3").toInt
                files.headOption.foreach(f => Harness.jitCompile(Harness.readScript(f)))
                withCsv(outDir.resolve("scalus-jit-check.csv"), "vm,script,status,cpu,mem") { check =>
                    withCsv(outDir.resolve("scalus-jit-compile.csv"), "vm,script,compile_ns") { compile =>
                        for f <- files do
                            val flat = Harness.readScript(f)
                            var jitted: UplcEvaluator = null
                            val times =
                                try
                                    (1 to runs).map { _ =>
                                        jitted = null // the previous compile can be collected
                                        val start = System.nanoTime()
                                        jitted = Harness.jitCompile(flat)
                                        System.nanoTime() - start
                                    }
                                catch
                                    case NonFatal(e) =>
                                        System.err.println(s"$f: compile failed: $e")
                                        Nil
                            val script = f.stripSuffix(".flat")
                            if times.isEmpty then
                                compile.println(s"scalus-jit,$script,-1")
                                check.println(s"scalus-jit,$script,error,,")
                            else
                                compile.println(s"scalus-jit,$script,${times.sorted.apply(times.size / 2)}")
                                var spender: BudgetSpender = null
                                val newSpender = () => { spender = CountingBudgetSpender(); spender }
                                val status = run(f)(Harness.jitEval(vm, jitted, newSpender))
                                check.println(row("scalus-jit", f, status, spender))
                    }
                }
            case other => sys.error(s"unknown mode $other, expected cek or jit")
    }

    private def run(file: String)(eval: => Any): String =
        try { eval; "ok" }
        catch
            case NonFatal(e) =>
                System.err.println(s"$file: ${e.getClass.getName}: ${e.getMessage}")
                "error"

    private def row(vm: String, file: String, status: String, spender: BudgetSpender): String = {
        val b = spender.getSpentBudget
        s"$vm,${file.stripSuffix(".flat")},$status,${b.steps},${b.memory}"
    }

    private def withCsv(path: Path, header: String)(body: PrintWriter => Unit): Unit = {
        val w = PrintWriter(Files.newBufferedWriter(path))
        try { w.println(header); body(w) }
        finally w.close()
    }
}
