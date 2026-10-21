package pvb;

import com.bloxbean.cardano.julc.vm.EvalResult;
import com.bloxbean.cardano.julc.vm.ExBudget;
import com.bloxbean.cardano.julc.vm.java.JavaVmProvider;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Stream;

/**
 * Correctness check (spec D4) for julc: one evaluation per script with the parameters of
 * {@link CekJavaBenchmark}. Writes vm,script,status,cpu,mem.
 * <p>
 * Usage: {@code java -cp julc-benchmark-jmh.jar pvb.Check <data-dir> <out.csv>}
 */
public class Check {
    public static void main(String[] args) throws Exception {
        JavaVmProvider provider = CekJavaBenchmark.mainnetProvider();
        List<Path> files;
        try (Stream<Path> s = Files.list(Path.of(args[0]))) {
            files = s.filter(p -> p.toString().endsWith(".flat")).sorted().toList();
        }
        StringBuilder csv = new StringBuilder("vm,script,status,cpu,mem\n");
        for (Path f : files) {
            String name = f.getFileName().toString().replace(".flat", "");
            String status;
            ExBudget used;
            try {
                EvalResult r = CekJavaBenchmark.evaluate(provider, Files.readAllBytes(f));
                used = r.budgetConsumed();
                status = r.isSuccess() ? "ok" : "error";
                if (!r.isSuccess()) {
                    String msg = r.toString();
                    System.out.println("CHECK_FAIL: " + name + ": " + msg.substring(0, Math.min(200, msg.length())));
                }
            } catch (RuntimeException e) {
                // A decode error or a crash: no ExUnits.
                System.out.println("CHECK_FAIL: " + name + ": " + e);
                used = ExBudget.ZERO;
                status = "error";
            }
            csv.append("julc-java,").append(name).append(',').append(status).append(',')
                    .append(used.cpuSteps()).append(',').append(used.memoryUnits()).append('\n');
        }
        Files.writeString(Path.of(args[1]), csv);
    }
}
