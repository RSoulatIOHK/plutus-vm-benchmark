# pvb-base
# JVM base image of the JMH rows (scalus-cek, scalus-jit, julc-java), published as
# ghcr.io/lantr-io/pvb-jvm-base:<tag> (scripts/images.sh). A VM Dockerfile uses it with
# "ARG JVM_BASE" and "FROM ${JVM_BASE}".
#
# One JVM for every JMH row: Oracle GraalVM GRAALVM_VERSION at /opt/jdk-25, the JMH launcher and
# the forked benchmark JVM. One JMH runner: /bench/scripts/jmh-run.sh (warm-up, measurement,
# fork, heap). The JMH version is JMH_VERSION of .env, set by each harness build.

FROM ubuntu:22.04

ARG GRAALVM_VERSION

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git zip unzip python3 procps \
    && rm -rf /var/lib/apt/lists/*

# Oracle GraalVM, checked against Oracle's sha256. 25.4.4 is GraalVM 25.4 for JDK 25.0.4
# (graalvm-jdk-25i4-25.0.4.1.1; SDKMAN: 25.4.4+1-graal), from Oracle's download service.
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
ENV JAVA_HOME=/opt/jdk-25
ENV PATH=/opt/jdk-25/bin:${PATH}

COPY scripts/jmh-run.sh /bench/scripts/jmh-run.sh
