# check=skip=InvalidDefaultArgInFrom
# Scalus (Scala / JVM / JMH). docs/IMAGE_CONTRACT.md.
# One build, two VMs: the build arg VM picks the default command.
#   scalus-cek  CEK interpreter (JMH CekJVMBenchmark)
#   scalus-jit  UPLC -> JVM bytecode JIT (JMH JITBenchmark)
# pvb-vms: scalus-cek scalus-jit
#
# Our own JMH harness (images/scalus/harness) on the released Scalus SCALUS_VERSION: the core
# (org.scalus::scalus) and the JIT (org.scalus::scalus-uplc-jit-compiler), both from Maven Central.
# Built FROM the JVM base (images/jvm-base): Oracle GraalVM runs sbt, the JMH launcher and the forked
# benchmark JVM, with no tuning flags (scripts/run-scalus-cek.sh, spec D16); JMH JMH_VERSION.

ARG JVM_BASE

FROM ${JVM_BASE}

ARG SBT_VERSION
ARG SCALUS_VERSION
ARG JMH_VERSION

# sbt launcher (each project/build.properties picks the sbt version it runs)
RUN curl -fsSL "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" \
    | tar -xz -C /opt \
    && ln -s /opt/sbt/bin/sbt /usr/local/bin/sbt

COPY images/scalus/harness/ /bench/scalus/
COPY check/reference/mainnet-plutusv3-costmodel.json /bench/scalus/mainnet-plutusv3-costmodel.json

WORKDIR /bench/scalus

# Compile the harness and the JMH code, then save the JMH classpath. The run scripts call
# org.openjdk.jmh.Main on it directly instead of sbt Jmh/run: image layers keep file times in whole
# seconds, so sbt would recompile at run time (and sbt at run time ran out of memory before).
ENV SCALUS_VERSION=${SCALUS_VERSION} JMH_VERSION=${JMH_VERSION}
RUN sbt -Dsbt.supershell=false Jmh/compile \
    && sbt -Dsbt.supershell=false -Dsbt.log.noformat=true -error "export Jmh/fullClasspath" \
       | tail -1 > /bench/scalus/jmh-classpath.txt \
    && grep -q "jmh-core-${JMH_VERSION}.jar" /bench/scalus/jmh-classpath.txt \
    && grep -q "scalus_3-${SCALUS_VERSION}.jar" /bench/scalus/jmh-classpath.txt \
    && grep -q "scalus-uplc-jit-compiler_3-${SCALUS_VERSION}.jar" /bench/scalus/jmh-classpath.txt

COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-scalus-cek.sh scripts/run-scalus-jit.sh /bench/scripts/

# Last, so both VMs share every layer above.
ARG VM
ENV PVB_VM=${VM}
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
