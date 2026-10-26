package pvb.julc;

import org.julclang.core.Program;
import org.julclang.vm.EvalResult;
import org.julclang.vm.java.JavaVmProvider;
import org.openjdk.jmh.annotations.*;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

/**
 * julc-java, two timed methods (docs/IMAGE_CONTRACT.md):
 * <ul>
 *   <li>{@code bench}: per invocation, flat decode + CEK evaluation with costing on (spec D3, the
 *       ranking);</li>
 *   <li>{@code benchEval}: per invocation, CEK evaluation of the program decoded once in setup
 *       ({@code julc-java-eval.csv}).</li>
 * </ul>
 * Both reuse the provider (cost model) and get a new cost tracker and CEK machine per invocation
 * (Harness). A failed evaluation throws, so it is never timed as a pass.
 */
@State(Scope.Thread)
public class CekJavaBenchmark {

    @Param({"auction_1-1.flat"})
    String file;

    private byte[] flat;
    private Program program;
    private JavaVmProvider provider;

    @Setup
    public void setup() throws IOException {
        provider = Harness.makeProvider();
        flat = Harness.readScript(file);
        program = Harness.decode(flat);
    }

    @Benchmark
    @BenchmarkMode(Mode.AverageTime)
    @OutputTimeUnit(TimeUnit.MICROSECONDS)
    public EvalResult bench() {
        return Harness.checked(Harness.eval(provider, flat), file);
    }

    @Benchmark
    @BenchmarkMode(Mode.AverageTime)
    @OutputTimeUnit(TimeUnit.MICROSECONDS)
    public EvalResult benchEval() {
        return Harness.checked(Harness.evalProgram(provider, program), file);
    }
}
