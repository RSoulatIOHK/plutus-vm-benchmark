# Julc, CEK interpreter (Java / JVM / JMH). docs/IMAGE_CONTRACT.md.
#
# Our own JMH harness (images/julc-java/harness) on the released Julc JULC_VERSION
# (org.julclang:julc-vm-java from Maven Central). Julc is Java 25 bytecode. JMH and the forked
# benchmark JVM both run on Oracle GraalVM GRAALVM_VERSION at /opt/jdk-25, the JVM of the Scalus
# rows, with no tuning flags (scripts/run-julc-java.sh, spec D16).

FROM ubuntu:22.04

ARG JULC_VERSION
ARG GRAALVM_VERSION
ARG MAVEN_VERSION=3.9.11

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl python3 procps \
    && rm -rf /var/lib/apt/lists/*

# Oracle GraalVM, checked against Oracle's sha256: the same download as images/scalus/Dockerfile.
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

# Maven, checked against Apache's sha512. Build time only.
RUN set -eu; \
    case "${MAVEN_VERSION}" in \
      3.9.11) sha=bcfe4fe305c962ace56ac7b5fc7a08b87d5abd8b7e89027ab251069faebee516b0ded8961445d6d91ec1985dfe30f8153268843c89aa392733d1a3ec956c9978 ;; \
      *) echo "no sha512 for Maven ${MAVEN_VERSION}"; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/maven.tgz \
      "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"; \
    echo "$sha  /tmp/maven.tgz" | sha512sum -c -; \
    mkdir -p /opt/maven; \
    tar -xzf /tmp/maven.tgz -C /opt/maven --strip-components 1; \
    rm /tmp/maven.tgz

COPY images/julc-java/harness/ /bench/julc/
COPY check/reference/mainnet-plutusv3-costmodel.json /bench/julc/mainnet-plutusv3-costmodel.json

WORKDIR /bench/julc

# Compile the harness (the JMH annotation processor writes the benchmark list), then save the
# runtime classpath. The run script calls org.openjdk.jmh.Main on it directly, without Maven.
RUN /opt/maven/bin/mvn -B -q -Djulc.version="${JULC_VERSION}" compile \
    && /opt/maven/bin/mvn -B -q -Djulc.version="${JULC_VERSION}" dependency:build-classpath \
       -Dmdep.includeScope=runtime -Dmdep.outputFile=/tmp/deps.txt \
    && echo "/bench/julc/target/classes:$(cat /tmp/deps.txt)" > /bench/julc/jmh-classpath.txt \
    && grep -q jmh-core /bench/julc/jmh-classpath.txt \
    && grep -q "julc-vm-java-${JULC_VERSION}.jar" /bench/julc/jmh-classpath.txt \
    && test -f target/classes/META-INF/BenchmarkList

COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-julc-java.sh /bench/scripts/

ENV PVB_VM=julc-java
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
