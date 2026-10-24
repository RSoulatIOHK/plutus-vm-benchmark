# check=skip=InvalidDefaultArgInFrom
# Scalus (Scala / JVM / JMH). docs/IMAGE_CONTRACT.md.
# One build, two VMs: the build arg VM picks the default command.
#   scalus-cek  CEK interpreter (JMH CekJVMBenchmark)
#   scalus-jit  UPLC -> JVM bytecode JIT (JMH JITBenchmark)
# pvb-vms: scalus-cek scalus-jit
#
# TEMPORARY (Scalus 1.4.1 preparation, revert after the run): our own JMH harness
# (images/scalus/harness) on Scalus built from source: Scalus master SCALUS_BUNDLE_BASE from
# GitHub plus the local branch in scalus-vm-api-141.bundle (tip SCALUS_BUNDLE_SHA). The core is
# published to the local Maven repository as SCALUS_BUNDLE_VERSION; the JIT
# (scalus-uplc-jit-compiler, not published) is compiled from the same sources. JMH runs on JDK 21.
# The forked benchmark JVM is one of two Oracle GraalVM releases, chosen at run time by
# SCALUS_JAVA (scripts/run-scalus-cek.sh):
#   /opt/graalvm-25.0.2  GraalVM for JDK 25.0.2 (also at /opt/jdk-25, the default)
#   /opt/graalvm-25.4.4  GraalVM 25.4 for JDK 25.0.4 (graalvm-jdk-25i4-25.0.4.1.1; SDKMAN calls it
#                        25.4.4+1-graal)

ARG JDK_VERSION

FROM eclipse-temurin:${JDK_VERSION}-jdk-jammy

ARG SBT_VERSION
ARG SCALUS_REPO
ARG SCALUS_BUNDLE_BASE
ARG SCALUS_BUNDLE_SHA
ARG SCALUS_BUNDLE_VERSION

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl zip unzip python3 procps \
    && rm -rf /var/lib/apt/lists/*

# sbt launcher (each project/build.properties picks the sbt version it runs)
RUN curl -fsSL "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" \
    | tar -xz -C /opt \
    && ln -s /opt/sbt/bin/sbt /usr/local/bin/sbt

# Oracle GraalVM, two releases side by side, checked against Oracle's sha256. SDKMAN no longer
# lists 25.0.2, so both come from Oracle directly.
RUN set -eu; \
    case "$(uname -m)" in \
      x86_64) \
        a="https://download.oracle.com/graalvm/25/archive/graalvm-jdk-25.0.2_linux-x64_bin.tar.gz"; \
        a_sha=af545b1bc12ecd24a5ba95e2370da2163e87c4cf13991a482d5b176bf4165c12; \
        b="https://gds.oracle.com/api/20220101/artifacts/3D7BF49A7CBE4E8CBC2A5226914FA3D1/content"; \
        b_sha=4fcc632cfc68e98f49f9316f8a3588bafe4f5289f120104e2d290a75cf33e28e ;; \
      aarch64) \
        a="https://download.oracle.com/graalvm/25/archive/graalvm-jdk-25.0.2_linux-aarch64_bin.tar.gz"; \
        a_sha=e0e18106fa1d8628d8ba21f548865211d7c8608a3423f7b25cb2aa4eef9abf10; \
        b="https://gds.oracle.com/api/20220101/artifacts/6337E95696F94C1F9D562556BB29BCE1/content"; \
        b_sha=780d5784d3db9bbcff77775c4d026e4a0e21a041ba9dba7c59135949ea5234a4 ;; \
      *) echo "unsupported arch $(uname -m)"; exit 1 ;; \
    esac; \
    install_graal() { \
        curl -fsSL -o /tmp/graal.tgz "$1"; \
        echo "$2  /tmp/graal.tgz" | sha256sum -c -; \
        mkdir -p "$3"; tar -xzf /tmp/graal.tgz -C "$3" --strip-components 1; rm /tmp/graal.tgz; \
        "$3/bin/java" -version; \
    }; \
    install_graal "$a" "$a_sha" /opt/graalvm-25.0.2; \
    install_graal "$b" "$b_sha" /opt/graalvm-25.4.4; \
    ln -s /opt/graalvm-25.0.2 /opt/jdk-25

# Scalus sources: the base from GitHub, then the branch from the bundle.
COPY images/scalus/scalus-vm-api-141.bundle /tmp/scalus.bundle
RUN git init -q /bench/scalus-src \
    && cd /bench/scalus-src \
    && git fetch -q --depth 1 "$SCALUS_REPO" "$SCALUS_BUNDLE_BASE" \
    && git fetch -q /tmp/scalus.bundle feat/vm-api-141 \
    && git checkout -q FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "$SCALUS_BUNDLE_SHA"

# The Scalus core to the local Maven repository (~/.m2), as SCALUS_BUNDLE_VERSION.
RUN cd /bench/scalus-src \
    && SBT_OPTS="-Xmx6g" sbt -Dsbt.supershell=false -Dsbt.log.noformat=true \
       "set ThisBuild / version := \"${SCALUS_BUNDLE_VERSION}\"" \
       "set scalus.jvm / Compile / packageDoc / publishArtifact := false" \
       scalusJVM/publishM2 \
    && test -f "/root/.m2/repository/org/scalus/scalus_3/${SCALUS_BUNDLE_VERSION}/scalus_3-${SCALUS_BUNDLE_VERSION}.jar"

COPY images/scalus/harness/ /bench/scalus/
COPY check/reference/mainnet-plutusv3-costmodel.json /bench/scalus/mainnet-plutusv3-costmodel.json

WORKDIR /bench/scalus

# Compile the harness and the JMH code, then save the JMH classpath. The run scripts call
# org.openjdk.jmh.Main on it directly instead of sbt Jmh/run: image layers keep file times in whole
# seconds, so sbt would recompile at run time (and sbt at run time ran out of memory before).
ENV SCALUS_SRC=/bench/scalus-src SCALUS_VERSION=${SCALUS_BUNDLE_VERSION}
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
