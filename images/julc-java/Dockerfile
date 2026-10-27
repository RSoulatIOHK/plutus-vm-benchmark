# check=skip=InvalidDefaultArgInFrom
# Julc, CEK interpreter (Java / JVM / JMH). docs/IMAGE_CONTRACT.md.
#
# Our own JMH harness (images/julc-java/harness) on the released Julc JULC_VERSION
# (org.julclang:julc-vm-java from Maven Central). Julc is Java 25 bytecode. Built FROM the JVM base
# (images/jvm-base): Oracle GraalVM runs Maven, the JMH launcher and the forked benchmark JVM, the
# JVM of the Scalus rows, with no tuning flags (scripts/run-julc-java.sh, spec D16); JMH JMH_VERSION.

ARG JVM_BASE

FROM ${JVM_BASE}

ARG JULC_VERSION
ARG JMH_VERSION
ARG MAVEN_VERSION=3.9.11

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
RUN /opt/maven/bin/mvn -B -q -Djulc.version="${JULC_VERSION}" -Djmh.version="${JMH_VERSION}" compile \
    && /opt/maven/bin/mvn -B -q -Djulc.version="${JULC_VERSION}" -Djmh.version="${JMH_VERSION}" dependency:build-classpath \
       -Dmdep.includeScope=runtime -Dmdep.outputFile=/tmp/deps.txt \
    && echo "/bench/julc/target/classes:$(cat /tmp/deps.txt)" > /bench/julc/jmh-classpath.txt \
    && grep -q "jmh-core-${JMH_VERSION}.jar" /bench/julc/jmh-classpath.txt \
    && grep -q "julc-vm-java-${JULC_VERSION}.jar" /bench/julc/jmh-classpath.txt \
    && test -f target/classes/META-INF/BenchmarkList

COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-julc-java.sh /bench/scripts/

ENV PVB_VM=julc-java
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
