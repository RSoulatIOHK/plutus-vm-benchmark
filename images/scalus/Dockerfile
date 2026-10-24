# check=skip=InvalidDefaultArgInFrom
# Scalus (Scala / JVM / JMH). docs/IMAGE_CONTRACT.md.
# One build, two VMs: the build arg VM picks the default command.
#   scalus-cek  CEK interpreter (JMH CekJVMBenchmark)
#   scalus-jit  UPLC -> JVM bytecode JIT (JMH JITBenchmark)
# pvb-vms: scalus-cek scalus-jit
#
# Our own JMH harness (images/scalus/harness) on Scalus built from source at SCALUS_SHA (Scalus
# master before the 1.4.1 release): the core is published to the local Maven repository as
# SCALUS_VERSION, and the JIT (scalus-uplc-jit-compiler) is compiled from the same sources. JMH runs
# on JDK 21; the forked benchmark JVM is Oracle GraalVM GRAALVM_VERSION at /opt/jdk-25, with no
# tuning flags (scripts/run-scalus-cek.sh, spec D16).

ARG JDK_VERSION

FROM eclipse-temurin:${JDK_VERSION}-jdk-jammy

ARG SBT_VERSION
ARG SCALUS_REPO
ARG SCALUS_SHA
ARG SCALUS_VERSION
ARG GRAALVM_VERSION

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl zip unzip python3 procps \
    && rm -rf /var/lib/apt/lists/*

# sbt launcher (each project/build.properties picks the sbt version it runs)
RUN curl -fsSL "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" \
    | tar -xz -C /opt \
    && ln -s /opt/sbt/bin/sbt /usr/local/bin/sbt

# Oracle GraalVM for the forked benchmark JVM, checked against Oracle's sha256. 25.4.4 is GraalVM
# 25.4 for JDK 25.0.4 (graalvm-jdk-25i4-25.0.4.1.1; SDKMAN: 25.4.4+1-graal), from Oracle's download
# service.
RUN set -eu; \
    case "${GRAALVM_VERSION}/$(uname -m)" in \
      25.4.4/x86_64) \
        url="https://gds.oracle.com/api/20220101/artifacts/3D7BF49A7CBE4E8CBC2A5226914FA3D1/content"; \
        sha=4fcc632cfc68e98f49f9316f8a3588bafe4f5289f120104e2d290a75cf33e28e ;; \
      25.4.4/aarch64) \
        url="https://gds.oracle.com/api/20220101/artifacts/6337E95696F94C1F9D562556BB29BCE1/content"; \
        sha=780d5784d3db9bbcff77775c4d026e4a0e21a041ba9dba7c59135949ea5234a4 ;; \
      *) echo "no download for GraalVM ${GRAALVM_VERSION} on $(uname -m)"; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/graal.tgz "$url"; \
    echo "$sha  /tmp/graal.tgz" | sha256sum -c -; \
    mkdir -p /opt/jdk-25; \
    tar -xzf /tmp/graal.tgz -C /opt/jdk-25 --strip-components 1; \
    rm /tmp/graal.tgz; \
    /opt/jdk-25/bin/java -version

# Scalus sources at SCALUS_SHA
RUN git init -q /bench/scalus-src \
    && cd /bench/scalus-src \
    && git fetch -q --depth 1 "$SCALUS_REPO" "$SCALUS_SHA" \
    && git checkout -q FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "$SCALUS_SHA"

# The Scalus core to the local Maven repository (~/.m2), as SCALUS_VERSION.
RUN cd /bench/scalus-src \
    && SBT_OPTS="-Xmx6g" sbt -Dsbt.supershell=false -Dsbt.log.noformat=true \
       "set ThisBuild / version := \"${SCALUS_VERSION}\"" \
       "set scalus.jvm / Compile / packageDoc / publishArtifact := false" \
       scalusJVM/publishM2 \
    && test -f "/root/.m2/repository/org/scalus/scalus_3/${SCALUS_VERSION}/scalus_3-${SCALUS_VERSION}.jar"

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
