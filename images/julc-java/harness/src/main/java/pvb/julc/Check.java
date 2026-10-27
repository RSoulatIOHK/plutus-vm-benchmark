package pvb.julc;

import org.julclang.vm.EvalResult;
import org.julclang.vm.ExBudget;
import org.julclang.vm.java.JavaVmProvider;

import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Stream;

/**
 * The correctness check (spec D4): one evaluation per {@code .flat} file of $BENCH_DATA_DIR, with
 * the same code and parameters as the timed loop (Harness).
 * <p>
 * Usage: {@code Check <results-dir>}, writes julc-java-check.csv (vm,script,status,cpu,mem).
 */
public final class Check {
    public static void main(String[] args) throws Exception {
        JavaVmProvider provider = Harness.makeProvider();
        List<String> files;
        try (Stream<Path> s = Files.list(Harness.dataDir())) {
            files = s.map(p -> p.getFileName().toString()).filter(f -> f.endsWith(".flat")).sorted().toList();
        }
        try (PrintWriter csv = new PrintWriter(Files.newBufferedWriter(Path.of(args[0], "julc-java-check.csv")))) {
            csv.println("vm,script,status,cpu,mem");
            for (String f : files) {
                String status = "error";
                String cpu = "";
                String mem = "";
                try {
                    EvalResult r = Harness.eval(provider, Harness.readScript(f));
                    ExBudget used = r.budgetConsumed();
                    cpu = Long.toString(used.cpuSteps());
                    mem = Long.toString(used.memoryUnits());
                    if (r.isSuccess()) {
                        status = "ok";
                    } else {
                        String msg = r.toString();
                        System.err.println(f + ": " + msg.substring(0, Math.min(300, msg.length())));
                    }
                } catch (Exception e) {
                    // A decode error or a crash: no ExUnits.
                    System.err.println(f + ": " + e);
                }
                csv.println("julc-java," + f.substring(0, f.length() - ".flat".length())
                        + "," + status + "," + cpu + "," + mem);
            }
        }
    }
}
