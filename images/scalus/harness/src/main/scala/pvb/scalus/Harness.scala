package pvb.scalus

import scalus.cardano.ledger.{CostModels, ExUnits, Language, MajorProtocolVersion}
import scalus.uplc.{DeBruijnedProgram, Term}
import scalus.uplc.eval.*
import scalus.uplc.jit.{UplcCompiler, UplcEvaluator}

import java.nio.file.{Files, Path, Paths}

/** The evaluation parameters of check/README.md, shared by the timed loops and the check:
  * PlutusV3, protocol version 11 (builtin semantics variant E), the mainnet PlutusV3 cost model,
  * and a restricting budget too large to run out (as the node restricts, and as the other VMs do).
  */
object Harness {

    /** A new budget spender for one evaluation: restricting, with a budget no script can spend. Its
      * `getSpentBudget` is the cost of the evaluation, the same as a counting spender's.
      */
    def newSpender(): BudgetSpender = RestrictingBudgetSpender(ExUnits.enormous)

    val protocolVersion: MajorProtocolVersion = MajorProtocolVersion.vanRossemPV

    def dataDir: Path = Paths.get(sys.env.getOrElse("BENCH_DATA_DIR", "/bench/data/plutus_use_cases"))

    def readScript(file: String): Array[Byte] = Files.readAllBytes(dataDir.resolve(file))

    /** The machine parameters from the mainnet cost model array
      * (check/reference/mainnet-plutusv3-costmodel.json).
      */
    def machineParams(): MachineParams = {
        val path = sys.env.getOrElse("SCALUS_COST_MODEL", "/bench/scalus/mainnet-plutusv3-costmodel.json")
        val json = ujson.read(Files.readString(Paths.get(path)))
        val major = json("protocolVersion")("major").num.toInt
        require(major == protocolVersion.version, s"cost model is for protocol version $major")
        val costs = json("PlutusV3").arr.map(_.num.toLong).toIndexedSeq
        MachineParams.fromCostModels(
          CostModels(Map(Language.PlutusV3.ordinal -> costs)),
          Language.PlutusV3,
          protocolVersion
        )
    }

    /** A PlutusV3 machine at protocol version 11 with the mainnet cost model. */
    def makeVM(): PlutusVM = {
        val vm = PlutusVM.makePlutusV3VM(machineParams(), protocolVersion)
        // The JIT runs its compiled code without UplcCompiler's scope check: check it here.
        require(vm.language == Language.PlutusV3, vm.language)
        require(vm.semanticVariant == scalus.uplc.BuiltinSemanticsVariant.E, vm.semanticVariant)
        vm
    }

    /** Flat decode of a script. */
    def decode(flat: Array[Byte]): DeBruijnedProgram = DeBruijnedProgram.fromFlatEncoded(flat)

    /** scalus-cek: flat decode + CEK evaluation (the D3 loop). Throws if the evaluation fails. */
    def cekEval(vm: PlutusVM, flat: Array[Byte], spender: BudgetSpender): Term =
        cekEvalTerm(vm, decode(flat).term, spender)

    /** scalus-cek: CEK evaluation of a decoded term (the eval-only loop). Each call runs a new CEK
      * machine state; the VM and its machine parameters are reused.
      */
    def cekEvalTerm(vm: PlutusVM, term: Term, spender: BudgetSpender): Term =
        vm.evaluateDeBruijnedTerm(term, spender, NoLogger)

    /** scalus-jit compile: flat decode + JIT compile (the compile column, spec D5). The result
      * falls back to the CEK machine on the JIT's call-depth limit.
      */
    def jitCompile(flat: Array[Byte]): UplcEvaluator =
        UplcCompiler.compile(decode(flat).toProgram.term).withFallback()

    /** scalus-jit: evaluates the compiled script for its budget only (`UplcEvaluator.run`): 78
      * scripts return a function, which has no term in the JIT, and `run` returns normally for them,
      * as the CEK machine does.
      *
      * A script deeper than the JIT's call-depth limit is evaluated again with the CEK machine, with
      * a new spender: the last spender `newSpender` made holds the budget of the result.
      */
    def jitEval(vm: PlutusVM, jitted: UplcEvaluator, newSpender: () => BudgetSpender): Unit =
        jitted.run(newSpender(), NoLogger)(using vm)
}
