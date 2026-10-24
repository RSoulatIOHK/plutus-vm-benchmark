# check=skip=InvalidDefaultArgInFrom
# scalus-js: the Scalus CEK machine compiled with Scala.js, as the `scalus` npm package.
# Build context: repo root. Contract: docs/IMAGE_CONTRACT.md. Build: scripts/images.sh build scalus-js
#
# The package is built from Scalus source at SCALUS_SHA (Scalus master before the 1.4.1 release),
# with the npm bundle task of the Scalus build, as version SCALUS_VERSION.

ARG JDK_VERSION

FROM eclipse-temurin:${JDK_VERSION}-jdk-jammy AS jdk

# The Scalus build links scalus-cardano-ledger with Scala.js and bundles it with esbuild
# (prepareNpmPackage), which needs node and npm.
FROM node:22-bookworm AS pkg
ARG SBT_VERSION
ARG SCALUS_REPO
ARG SCALUS_SHA
ARG SCALUS_VERSION
COPY --from=jdk /opt/java/openjdk /opt/java/openjdk
ENV JAVA_HOME=/opt/java/openjdk PATH=/opt/java/openjdk/bin:$PATH
RUN curl -fsSL "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" \
    | tar -xz -C /opt \
    && ln -s /opt/sbt/bin/sbt /usr/local/bin/sbt
RUN git init -q /src \
    && cd /src \
    && git fetch -q --depth 1 "$SCALUS_REPO" "$SCALUS_SHA" \
    && git checkout -q FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "$SCALUS_SHA"
RUN cd /src \
    && SBT_OPTS="-Xmx6g" sbt -Dsbt.supershell=false -Dsbt.log.noformat=true \
       "set ThisBuild / version := \"${SCALUS_VERSION}\"" \
       scalusCardanoLedgerJS/prepareNpmPackage \
    && cd scalus-cardano-ledger/js/src/main/npm \
    && npm pkg set "version=${SCALUS_VERSION}" \
    && mkdir /pkg \
    && cp package.json scalus.js scalus.d.ts README.md /pkg/

# Node 22, the same major as the blaze-v8 harness (nodesource setup_22.x in the root Dockerfile).
FROM node:22-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /bench/scalus-js
# The scalus package has no dependencies: one self-contained scalus.js.
COPY --from=pkg /pkg/ /bench/scalus-js/node_modules/scalus/
COPY images/scalus-js/package.json ./

COPY parsers/ /bench/parsers/
COPY images/scalus-js/common.mjs images/scalus-js/check.mjs images/scalus-js/time.mjs ./
COPY scripts/image-entry.sh scripts/run-scalus-js.sh /bench/scripts/

ENV PVB_VM=scalus-js
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
