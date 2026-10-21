package pvb.scalus

import scalus.cardano.ledger.{CostModels, Language, MajorProtocolVersion}
import scalus.uplc.{DeBruijnedProgram, Term}
import scalus.uplc.eval.*
import scalus.uplc.jit.{CompiledTerm, UplcCompiler}
import scalus.uplc.jit.nativestack.StackThresholdException

import java.nio.file.{Files, Path, Paths}

/** The evaluation parameters of check/README.md, shared by the timed loops and the check:
  * PlutusV3, protocol version 11 (builtin semantics variant E), the mainnet PlutusV3 cost model,
  * counting budget.
  */
object Harness {
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

    /** scalus-cek: flat decode + CEK evaluation. Throws if the evaluation fails. */
    def cekEval(vm: PlutusVM, flat: Array[Byte], spender: BudgetSpender): Term = {
        val program = DeBruijnedProgram.fromFlatEncoded(flat)
        vm.evaluateDeBruijnedTerm(program.term, spender, NoLogger)
    }

    /** A script compiled by the JIT, with its De Bruijn term for the CEK fallback. */
    final class Jitted(val code: CompiledTerm, val deBruijned: Term)

    /** scalus-jit compile: flat decode + JIT compile (the compile column, spec D5). */
    def jitCompile(flat: Array[Byte]): Jitted = {
        val program = DeBruijnedProgram.fromFlatEncoded(flat)
        Jitted(UplcCompiler.compile(program.toProgram.term).code, program.term)
    }

    /** scalus-jit: evaluates the compiled code, as `UplcCompiler.Compiled.withFallback` does, but
      * returns the JIT value instead of converting it to a term: 78 scripts return a function, which
      * has no term in the JIT (`FunctionResultError`), and the CEK machine returns it as `ok`.
      *
      * A script deeper than the JIT's call-depth limit is evaluated again with the CEK machine, with
      * a new spender: the last spender `newSpender` made holds the budget of the result.
      */
    def jitEval(vm: PlutusVM, jitted: Jitted, newSpender: () => BudgetSpender): AnyRef =
        try jitted.code(NoLogger, newSpender(), vm.machineParams)
        catch
            case _: StackThresholdException =>
                vm.evaluateDeBruijnedTerm(jitted.deBruijned, newSpender(), NoLogger)
}
