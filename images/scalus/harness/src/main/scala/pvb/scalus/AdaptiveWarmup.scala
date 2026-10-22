package pvb.scalus

import org.openjdk.jmh.infra.Blackhole

import scala.collection.mutable.ArrayBuffer

/** The warm-up of the JMH rows (METHODOLOGY.md, D13). JMH cannot end a warm-up early, so the run
  * scripts start JMH with no warm-up iterations (`-wi 0`) and the benchmark warms up in its
  * `@Setup(Level.Trial)`, in the forked JVM, before the first measurement iteration. The setup
  * calls the benchmark method itself and gives its result to JMH's Blackhole, as the generated JMH
  * loop does, so the warm-up runs the measured code path.
  *
  * `$PVB_WARMUP_MS` (set by scripts/run-scalus-cek.sh and run-scalus-jit.sh):
  *   - `adaptive`: the adaptive rule. Slices of 1 s; stop when at least 5 s have passed and the
  *     last 5 slices are all within ±3 % of their median; stop at 30 s at the latest (the cap).
  *   - a number: one fixed slice of that many milliseconds (`BENCH_TIMING=quick`).
  *   - unset: no warm-up here.
  *
  * The same rule as the JS harnesses (images/blaze/pvb-time.test.ts, images/scalus-js/time.mjs,
  * images/aiken-wasm/time.mjs). Keep them the same.
  *
  * Output: one line "PVB_WARMUP {json}" with the script, the loop, the slices (ops and ns of each)
  * and `capped`, the format of the JS harnesses. parsers/parse_warmup.py reads it.
  */
object AdaptiveWarmup {
    val SliceNs: Long = 1_000_000_000L
    val Window: Int = 5
    val Tolerance: Double = 0.03
    val MinNs: Long = 5_000_000_000L
    val CapNs: Long = 30_000_000_000L

    /** One slice: `op` back to back for at least `ns` nanoseconds. */
    final case class Slice(ops: Long, ns: Long) {
        def nsPerOp: Double = ns.toDouble / ops
    }

    /** Runs `op` back to back for at least `ns` nanoseconds; each result goes to the Blackhole. */
    def slice(bh: Blackhole, op: () => AnyRef, ns: Long): Slice = {
        val start = System.nanoTime()
        val deadline = start + ns
        var ops = 0L
        var now = start
        while {
            bh.consume(op())
            ops += 1
            now = System.nanoTime()
            now < deadline
        } do ()
        Slice(ops, now - start)
    }

    /** True when the last `Window` slices are all within ±`Tolerance` of their median. */
    def steady(slices: collection.Seq[Slice]): Boolean =
        if slices.size < Window then false
        else
            val last = slices.takeRight(Window).map(_.nsPerOp)
            val median = last.sorted.apply(Window / 2)
            last.forall(x => math.abs(x - median) <= Tolerance * median)

    /** The warm-up of `script` (without `.flat`) in loop `loop` (d3 or eval). */
    def run(script: String, loop: String, bh: Blackhole, op: () => AnyRef): Unit =
        sys.env.get("PVB_WARMUP_MS") match
            case None => ()
            case Some(spec) =>
                val slices = ArrayBuffer.empty[Slice]
                var capped = false
                if spec == "adaptive" then
                    val start = System.nanoTime()
                    var done = false
                    while !done do
                        slices += slice(bh, op, SliceNs)
                        val elapsed = System.nanoTime() - start
                        if elapsed >= MinNs && steady(slices) then done = true
                        else if elapsed >= CapNs then
                            done = true
                            capped = true
                else slices += slice(bh, op, spec.toLong * 1_000_000L)
                val end = if spec != "adaptive" then "fixed" else if capped then "capped" else "steady"
                report(script, loop, slices, end)

    private def report(
        script: String,
        loop: String,
        slices: collection.Seq[Slice],
        end: String
    ): Unit = {
        val total = slices.map(_.ns).sum / 1e9
        val last = slices.last.nsPerOp
        println(
          f"$loop $script warm-up: $total%.1f s, ${slices.size} slices, " +
              f"$end, last slice $last%.0f ns/op"
        )
        val json = slices.map(s => s"""{"ops":${s.ops},"ns":${s.ns}}""").mkString("[", ",", "]")
        val capped = end == "capped"
        println(s"""PVB_WARMUP {"script":"$script","loop":"$loop","slices":$json,"capped":$capped}""")
    }
}
