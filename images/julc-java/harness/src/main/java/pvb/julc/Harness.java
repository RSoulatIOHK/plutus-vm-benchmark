package pvb.julc;

import org.julclang.core.Program;
import org.julclang.core.flat.UplcFlatDecoder;
import org.julclang.vm.EvalOptions;
import org.julclang.vm.EvalResult;
import org.julclang.vm.ExBudget;
import org.julclang.vm.LedgerEvaluationTarget;
import org.julclang.vm.PlutusLanguage;
import org.julclang.vm.java.JavaVmProvider;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * The evaluation parameters of check/README.md, shared by the timed loops and the check: PlutusV3,
 * protocol version 11, the mainnet PlutusV3 cost model, and a restricting budget too large to run
 * out (as the node restricts, and as the other VMs do).
 * <p>
 * The provider holds the parsed cost model and is reused. Each {@code evaluate} call makes a new
 * cost tracker and CEK machine ({@code JavaVmProvider.prepare}).
 */
public final class Harness {
    private Harness() {}

    /** PlutusV3 at protocol version 11. */
    public static final LedgerEvaluationTarget TARGET = LedgerEvaluationTarget.pv11(PlutusLanguage.PLUTUS_V3);

    /** A restricting budget no script can spend. On success it gives the same cost as no limit. */
    public static final ExBudget BUDGET = new ExBudget(Long.MAX_VALUE, Long.MAX_VALUE);

    /** No traces collected: the ledger does not collect them either. */
    public static final EvalOptions OPTIONS = EvalOptions.DEFAULT.withTracing(false).withBuiltinTrace(false);

    public static Path dataDir() {
        return Path.of(System.getenv().getOrDefault("BENCH_DATA_DIR", "/bench/data/plutus_use_cases"));
    }

    public static byte[] readScript(String file) throws IOException {
        return Files.readAllBytes(dataDir().resolve(file));
    }

    /**
     * A provider with the mainnet PlutusV3 cost model array of
     * check/reference/mainnet-plutusv3-costmodel.json ($JULC_COST_MODEL).
     */
    public static JavaVmProvider makeProvider() throws IOException {
        String path = System.getenv().getOrDefault("JULC_COST_MODEL", "/bench/julc/mainnet-plutusv3-costmodel.json");
        String json = Files.readString(Path.of(path));
        Matcher major = Pattern.compile("\"protocolVersion\"\\s*:\\s*\\{\\s*\"major\"\\s*:\\s*(\\d+)").matcher(json);
        if (!major.find() || Integer.parseInt(major.group(1)) != 11) {
            throw new IllegalStateException(path + ": cost model is not for protocol version 11");
        }
        Matcher array = Pattern.compile("\"PlutusV3\"\\s*:\\s*\\[([^\\]]*)\\]").matcher(json);
        if (!array.find()) throw new IllegalStateException(path + ": no PlutusV3 array");
        long[] values = Arrays.stream(array.group(1).split(","))
                .map(String::trim).mapToLong(Long::parseLong).toArray();
        if (values.length != 350) {
            throw new IllegalStateException(path + ": expected 350 PlutusV3 parameters, got " + values.length);
        }
        JavaVmProvider provider = new JavaVmProvider();
        provider.setCostModelParams(values, PlutusLanguage.PLUTUS_V3, 11, 0);
        return provider;
    }

    /** Flat decode of a script. */
    public static Program decode(byte[] flat) {
        return UplcFlatDecoder.decodeProgram(flat);
    }

    /** Flat decode + evaluation (the D3 loop). */
    public static EvalResult eval(JavaVmProvider provider, byte[] flat) {
        return evalProgram(provider, decode(flat));
    }

    /** Evaluation of a decoded program (the eval-only loop). */
    public static EvalResult evalProgram(JavaVmProvider provider, Program program) {
        return provider.evaluate(program, TARGET, BUDGET, OPTIONS);
    }

    /** Throws if the evaluation failed, so a failure is never timed as a pass. */
    public static EvalResult checked(EvalResult r, String file) {
        if (!r.isSuccess()) throw new IllegalStateException("evaluation failed: " + file + ": " + r);
        return r;
    }
}
