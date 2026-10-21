# check=skip=InvalidDefaultArgInFrom
# Scalus (Scala / JVM / JMH). docs/IMAGE_CONTRACT.md.
# One build, two VMs: the build arg VM picks the default command.
#   scalus-cek  CEK interpreter (JMH CekJVMBenchmark)
#   scalus-jit  UPLC -> JVM bytecode JIT (JMH JITBenchmark)
# pvb-vms: scalus-cek scalus-jit
#
# Our own JMH harness (images/scalus/harness) on the released Scalus SCALUS_VERSION: the core from
# Maven Central, the JIT (scalus-uplc-jit-compiler, not published) compiled from its sources at
# SCALUS_SHA, the commit of the release tag. JMH runs on JDK 21; the forked benchmark JVM is
# GraalVM 25 at /opt/jdk-25.

ARG JDK_VERSION

FROM eclipse-temurin:${JDK_VERSION}-jdk-jammy

ARG SBT_VERSION
ARG JDK_SDK_VERSION
ARG SCALUS_REPO
ARG SCALUS_SHA
ARG SCALUS_VERSION

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl zip unzip python3 procps \
    && rm -rf /var/lib/apt/lists/*

# sbt launcher (the harness's project/build.properties picks the sbt version it runs)
RUN curl -fsSL "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" \
    | tar -xz -C /opt \
    && ln -s /opt/sbt/bin/sbt /usr/local/bin/sbt

# GraalVM JDK 25 via SDKMAN for the forked benchmark JVM (same JDK as julc-java)
RUN curl -s "https://get.sdkman.io" | bash \
    && bash -c "source /root/.sdkman/bin/sdkman-init.sh && sdk install java ${JDK_SDK_VERSION}" \
    && ln -s "$(readlink -f /root/.sdkman/candidates/java/current)" /opt/jdk-25 \
    && /opt/jdk-25/bin/java -version

# Scalus sources at the release tag, for the JIT module only
RUN git init -q /bench/scalus-src \
    && cd /bench/scalus-src \
    && git fetch -q --depth 1 "$SCALUS_REPO" "$SCALUS_SHA" \
    && git checkout -q FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "$SCALUS_SHA"

COPY images/scalus/harness/ /bench/scalus/
COPY check/reference/mainnet-plutusv3-costmodel.json /bench/scalus/mainnet-plutusv3-costmodel.json

WORKDIR /bench/scalus

# Compile the harness and the JMH code, then save the JMH classpath. The run scripts call
# org.openjdk.jmh.Main on it directly instead of sbt Jmh/run: image layers keep file times in whole
# seconds, so sbt would recompile at run time (and sbt at run time ran out of memory before).
ENV SCALUS_SRC=/bench/scalus-src SCALUS_VERSION=${SCALUS_VERSION}
RUN sbt -Dsbt.supershell=false Jmh/compile \
    && sbt -Dsbt.supershell=false -Dsbt.log.noformat=true -error "export Jmh/fullClasspath" \
       | tail -1 > /bench/scalus/jmh-classpath.txt \
    && grep -q jmh-core /bench/scalus/jmh-classpath.txt \
    && grep -q "scalus_3-${SCALUS_VERSION}.jar" /bench/scalus/jmh-classpath.txt

COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-scalus-cek.sh scripts/run-scalus-jit.sh /bench/scripts/

# Last, so both VMs share every layer above.
ARG VM
ENV PVB_VM=${VM}
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
