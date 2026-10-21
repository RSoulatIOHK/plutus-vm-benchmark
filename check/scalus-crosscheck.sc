//> using scala 3.3.7
//> using jvm 21
//> using dep org.scalus::scalus:1.4.0

// Cross-check of the Haskell reference with the Scalus CEK machine (released Scalus from Maven).
//
// Usage: scala-cli run check/scalus-crosscheck.sc -- data/plutus_use_cases [variant-c] > /tmp/scalus-check.csv
//
// With variant-c: the cost model of the "outdated cost model" badge instead (builtinCostModelC.json,
// the same file as in plutus 1.63.0.0, and the variant C machine costs), protocol version 11 features on.
// Compare with check/reference/haskell-check-variant-c.csv.
//
// stdout: vm,script,status,cpu,mem with the gate parameters (check/README.md): PlutusV3, protocol
// version 11, the mainnet PlutusV3 cost model (Scalus 1.4.0 ships it as CardanoInfo.mainnet,
// Blockfrost epoch 645), counting budget.
// stderr: the number of scripts where the mainnet cost model and the compiled-in variant E cost
// model files (builtinCostModelE.json + cekMachineCostsE.json, identical to plutus 1.63.0.0) give
// different results.

import scalus.cardano.ledger.{CardanoInfo, Language, MajorProtocolVersion}
import scalus.uplc.DeBruijnedProgram
import scalus.uplc.eval.*

import java.nio.file.{Files, Path, Paths}
import scala.jdk.CollectionConverters.*

val dir = Paths.get(args.headOption.getOrElse("data/plutus_use_cases"))
val pv = MajorProtocolVersion.vanRossemPV
val variantC = args.lift(1).contains("variant-c")

val mainnetParams = MachineParams.fromProtocolParams(CardanoInfo.mainnet.protocolParams, Language.PlutusV3)
require(CardanoInfo.mainnet.majorProtocolVersion == pv, s"mainnet PV is ${CardanoInfo.mainnet.majorProtocolVersion}")

def resource(name: String): String =
    new String(getClass.getResourceAsStream(name).readAllBytes(), "UTF-8")

val variantEParams = {
    val builtins = BuiltinCostModel.fromJsonString(resource("/builtinCostModelE.json"))
    val machine = ujson.read(resource("/cekMachineCostsE.json")).obj.flatMap { case (k, v) =>
        v.obj.map { case (field, n) => s"$k-$field" -> n.num.toLong }
    }
    MachineParams(CekMachineCosts.fromMap(machine.toMap), builtins)
}

val variantCParams = MachineParams(
  CekMachineCosts.defaultMachineCostsC,
  BuiltinCostModel.fromJsonString(resource("/builtinCostModelC.json"))
)

def run(params: MachineParams, program: DeBruijnedProgram): (String, Long, Long) = {
    val vm = PlutusVM.makePlutusV3VM(params, pv)
    val spender = CountingBudgetSpender()
    val status =
        try { vm.evaluateDeBruijnedTerm(program.term, spender, NoLogger); "ok" }
        catch { case _: Exception => "error" }
    val b = spender.getSpentBudget
    (status, b.steps, b.memory)
}

val files = Files.list(dir).iterator().asScala.filter(_.toString.endsWith(".flat")).toList.sortBy(_.toString)
println("vm,script,status,cpu,mem")
var diffs = 0
for f <- files do
    val program = DeBruijnedProgram.fromFlatEncoded(Files.readAllBytes(f))
    val name = f.getFileName.toString.stripSuffix(".flat")
    val m = run(if variantC then variantCParams else mainnetParams, program)
    val e = if variantC then m else run(variantEParams, program)
    println(s"scalus-cek,$name,${m._1},${m._2},${m._3}")
    if m != e then
        diffs += 1
        System.err.println(s"DIFF $name: mainnet $m vs variant-E files $e")
System.err.println(
  s"${files.size} scripts, $diffs differ between the mainnet cost model and the variant E cost model files; " +
      s"params equal: ${mainnetParams == variantEParams}"
)
