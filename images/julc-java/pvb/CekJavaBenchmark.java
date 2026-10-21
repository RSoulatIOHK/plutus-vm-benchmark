package pvb;

import com.bloxbean.cardano.julc.core.Program;
import com.bloxbean.cardano.julc.core.flat.UplcFlatDecoder;
import com.bloxbean.cardano.julc.vm.EvalOptions;
import com.bloxbean.cardano.julc.vm.EvalResult;
import com.bloxbean.cardano.julc.vm.PlutusLanguage;
import com.bloxbean.cardano.julc.vm.java.JavaVmProvider;
import org.openjdk.jmh.annotations.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;

/**
 * plutus-vm-benchmark harness for julc, added to the pinned repo's julc-benchmark jmh source set
 * (images/julc-java/Dockerfile). docs/IMAGE_CONTRACT.md, spec D3/D4/D11.
 * <p>
 * Same class name as the upstream {@code CekJavaBenchmark}, in package {@code pvb}, so
 * parsers/parse_jmh.py maps it to julc-java. Differences from upstream:
 * <ul>
 *   <li>the mainnet PlutusV3 cost model through {@code setCostModelParams(array, PLUTUS_V3, 11, 0)}
 *       instead of the shipped variant C defaults;</li>
 *   <li>flat decode inside the timed method {@code bench} (spec D3, the ranking); {@code benchEval}
 *       evaluates the program decoded once in setup (julc-java-eval.csv);</li>
 *   <li>the evaluation result is checked: a failure throws, so it is never timed as a pass.</li>
 * </ul>
 * Budget {@code null}: counting mode, no limit. The file list comes from {@code -p file=...}.
 * The provider (cost model) is reused; each {@code evaluate} makes a new cost tracker and CEK
 * machine ({@code JavaVmProvider.evaluateInternal}).
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
@State(Scope.Benchmark)
@Fork(1)
@Threads(1)
public class CekJavaBenchmark {

    @Param({"auction_1-1.flat"})
    String file;

    static final EvalOptions OPTIONS = EvalOptions.DEFAULT.withBuiltinTrace(false);

    private byte[] flat;
    private Program program;
    private JavaVmProvider provider;

    @Setup(Level.Trial)
    public void setup() throws IOException {
        flat = Files.readAllBytes(Path.of("data", file));
        program = UplcFlatDecoder.decodeProgram(flat);
        provider = mainnetProvider();
        // A failing script fails its trial here (JMH goes on with the next file).
        EvalResult first = evaluate(provider, flat);
        if (!first.isSuccess()) {
            System.out.println("EVAL_FAIL: " + file.replace(".flat", ""));
            throw new IllegalStateException("EVAL_FAIL: " + file + ": " + first);
        }
    }

    @Benchmark
    public EvalResult bench() {
        EvalResult r = evaluate(provider, flat);
        if (!r.isSuccess()) {
            throw new IllegalStateException("evaluation failed: " + file);
        }
        return r;
    }

    @Benchmark
    public EvalResult benchEval() {
        EvalResult r = evaluateProgram(provider, program);
        if (!r.isSuccess()) {
            throw new IllegalStateException("evaluation failed: " + file);
        }
        return r;
    }

    /** One flat decode + evaluation, PlutusV3, counting mode. */
    static EvalResult evaluate(JavaVmProvider provider, byte[] flat) {
        return evaluateProgram(provider, UplcFlatDecoder.decodeProgram(flat));
    }

    /** One evaluation of a decoded program, PlutusV3, counting mode. */
    static EvalResult evaluateProgram(JavaVmProvider provider, Program program) {
        return provider.evaluate(program, PlutusLanguage.PLUTUS_V3, null, OPTIONS);
    }

    /** A provider with the mainnet PlutusV3 array from $PVB_COSTMODEL (one integer per line). */
    static JavaVmProvider mainnetProvider() throws IOException {
        String path = System.getenv("PVB_COSTMODEL");
        if (path == null) throw new IllegalStateException("set PVB_COSTMODEL");
        long[] values = Files.readAllLines(Path.of(path)).stream()
                .map(String::trim).filter(s -> !s.isEmpty()).mapToLong(Long::parseLong).toArray();
        if (values.length != 350) {
            throw new IllegalStateException(path + ": expected 350 PlutusV3 parameters, got " + values.length);
        }
        JavaVmProvider provider = new JavaVmProvider();
        provider.setCostModelParams(values, PlutusLanguage.PLUTUS_V3, 11, 0);
        return provider;
    }
}
