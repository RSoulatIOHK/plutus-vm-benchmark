# check=skip=InvalidDefaultArgInFrom
# Scalus (Scala / JVM / JMH). docs/IMAGE_CONTRACT.md.
# One build, two VMs: the build arg VM picks the default command.
#   scalus-cek  CEK interpreter (JMH CekJVMBenchmark)
#   scalus-jit  UPLC -> JVM bytecode JIT (JMH JITBenchmark)
# pvb-vms: scalus-cek scalus-jit
#
# One stage: the image keeps the sbt project with its compiled target/ dirs at the path where it
# was built, and the JDK that built it. JMH runs on JDK 21; the forked benchmark JVM is GraalVM 25
# at /opt/jdk-25.

ARG JDK_VERSION

FROM eclipse-temurin:${JDK_VERSION}-jdk-jammy

ARG SBT_VERSION
ARG JDK_SDK_VERSION
ARG SCALUS_REPO
ARG SCALUS_SHA

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl zip unzip python3 procps \
    && rm -rf /var/lib/apt/lists/*

# sbt launcher (the project's build.properties picks the sbt version it runs)
RUN curl -fsSL "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" \
    | tar -xz -C /opt \
    && ln -s /opt/sbt/bin/sbt /usr/local/bin/sbt

# GraalVM JDK 25 via SDKMAN for the forked benchmark JVM (same JDK as julc-java)
RUN curl -s "https://get.sdkman.io" | bash \
    && bash -c "source /root/.sdkman/bin/sdkman-init.sh && sdk install java ${JDK_SDK_VERSION}" \
    && ln -s "$(readlink -f /root/.sdkman/candidates/java/current)" /opt/jdk-25 \
    && /opt/jdk-25/bin/java -version

RUN git clone "$SCALUS_REPO" /bench/scalus \
    && cd /bench/scalus && git checkout "$SCALUS_SHA"

WORKDIR /bench/scalus

# No depth patch: since 60083c162 Scalus defaults to maxDepth 25000 (NativeStackContext.DefaultMaxDepth)

# Pre-compile JMH benchmarks (this downloads deps + compiles everything), then save the JMH
# classpath. The run scripts call org.openjdk.jmh.Main on it directly instead of sbt
# bench/Jmh/run: image layers keep file times in whole seconds, so sbt would recompile every
# module at run time.
RUN sbt -Dsbt.supershell=false bench/Jmh/compile \
    && sbt -Dsbt.supershell=false -Dsbt.log.noformat=true -error "export bench/Jmh/fullClasspath" \
       | tail -1 > /bench/scalus/jmh-classpath.txt \
    && grep -q jmh-core /bench/scalus/jmh-classpath.txt

COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-scalus-cek.sh scripts/run-scalus-jit.sh /bench/scripts/

# Last, so both VMs share every layer above.
ARG VM
ENV PVB_VM=${VM}
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
