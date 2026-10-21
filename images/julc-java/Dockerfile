# Julc, CEK interpreter (Java / GraalVM / JMH). docs/IMAGE_CONTRACT.md.

# =============================================================================
# Build stage
# =============================================================================
FROM debian:bookworm-slim AS build

ARG JULC_REPO
ARG JULC_SHA
ARG JDK_SDK_VERSION

RUN apt-get update \
    && apt-get install -y curl git zip unzip \
    && rm -rf /var/lib/apt/lists/*

# Install GraalVM JDK 25 via SDKMAN (required for Java 25 source)
RUN curl -s "https://get.sdkman.io" | bash \
    && bash -c "source /root/.sdkman/bin/sdkman-init.sh \
    && sdk install java ${JDK_SDK_VERSION}"
ENV JAVA_HOME=/root/.sdkman/candidates/java/current
ENV PATH="${JAVA_HOME}/bin:${PATH}"

RUN git clone "$JULC_REPO" /src \
    && cd /src && git checkout "$JULC_SHA"

WORKDIR /src

# Our harness (pvb.CekJavaBenchmark, pvb.Check): mainnet PlutusV3 cost model at protocol
# version 11, flat decode in the timed method, result checked. See images/julc-java/pvb/.
COPY images/julc-java/pvb/ /src/julc-benchmark/src/jmh/java/pvb/

# Build fat JMH benchmark JAR (includes all dependencies)
RUN ./gradlew :julc-benchmark:jmhJar --no-daemon

# =============================================================================
# Runtime stage
# =============================================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 procps \
    && rm -rf /var/lib/apt/lists/*

# GraalVM JDK 25 (Java 25 bytecode needs JDK 25) and the fat JMH jar: no Gradle at run time.
COPY --from=build /root/.sdkman/candidates/java/current /opt/jdk-25
COPY --from=build /src/julc-benchmark/build/libs/*-jmh.jar /bench/julc/julc-benchmark-jmh.jar
RUN /opt/jdk-25/bin/java -version \
    && /opt/jdk-25/bin/jar tf /bench/julc/julc-benchmark-jmh.jar | grep -q '^pvb/Check.class$'

COPY check/reference/mainnet-plutusv3-costmodel.json /bench/mainnet-plutusv3-costmodel.json
COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-julc-java.sh /bench/scripts/

ENV PVB_VM=julc-java
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
