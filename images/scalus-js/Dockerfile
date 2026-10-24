# check=skip=InvalidDefaultArgInFrom
# scalus-js: the Scalus CEK machine compiled with Scala.js. Build context: repo root.
# Contract: docs/IMAGE_CONTRACT.md. Build: scripts/images.sh build scalus-js
# One Dockerfile, two VMs (TEMPORARY, Scalus 1.4.1 preparation; revert after the run):
#   scalus-js      the npm package built from Scalus source, twice: master SCALUS_BUNDLE_BASE from
#                  GitHub plus the local branches in images/scalus/scalus-141.bundle (PlutusVM,
#                  uplc.decodeProgram). SCALUS_BUILD picks one at run time: base (1.4.1-base) or
#                  perf (1.4.1-perf, with perf/cek-env-first); see .env
#   scalus-js-140  the published npm package SCALUS_JS_VERSION (1.4.0), the "before" row
# Each package is in /bench/scalus-js/pkgs/<build>; run-scalus-js.sh links the chosen one to
# node_modules/scalus.
# pvb-vms: scalus-js scalus-js-140

ARG VM
ARG JDK_VERSION

FROM eclipse-temurin:${JDK_VERSION}-jdk-jammy AS jdk

# --- scalus-js: the npm package from the branch build ----------------------------------------
# The Scalus build links scalus-cardano-ledger with Scala.js and bundles it with esbuild
# (prepareNpmPackage), which needs node and npm.
FROM node:22-bookworm AS pkg-scalus-js
ARG SBT_VERSION
ARG SCALUS_REPO
ARG SCALUS_BUNDLE_BASE
ARG SCALUS_BUNDLE_BASE_SHA
ARG SCALUS_BUNDLE_PERF_SHA
COPY --from=jdk /opt/java/openjdk /opt/java/openjdk
ENV JAVA_HOME=/opt/java/openjdk PATH=/opt/java/openjdk/bin:$PATH
RUN curl -fsSL "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" \
    | tar -xz -C /opt \
    && ln -s /opt/sbt/bin/sbt /usr/local/bin/sbt
COPY images/scalus/scalus-141.bundle /tmp/scalus.bundle
RUN git init -q /src \
    && cd /src \
    && git fetch -q --depth 1 "$SCALUS_REPO" "$SCALUS_BUNDLE_BASE" \
    && git fetch -q /tmp/scalus.bundle pvb-base:pvb-base pvb-perf:pvb-perf \
    && test "$(git rev-parse pvb-base)" = "$SCALUS_BUNDLE_BASE_SHA" \
    && test "$(git rev-parse pvb-perf)" = "$SCALUS_BUNDLE_PERF_SHA"
# One package per build, to /pkg/<build>.
RUN set -eu; \
    cd /src; \
    for b in base perf; do \
        git checkout -q "pvb-$b"; \
        SBT_OPTS="-Xmx6g" sbt -Dsbt.supershell=false -Dsbt.log.noformat=true \
            "set ThisBuild / version := \"1.4.1-$b\"" \
            scalusCardanoLedgerJS/prepareNpmPackage; \
        cd scalus-cardano-ledger/js/src/main/npm; \
        npm pkg set "version=1.4.1-$b"; \
        mkdir -p "/pkg/$b"; \
        cp package.json scalus.js scalus.d.ts README.md "/pkg/$b/"; \
        git checkout -q -- package.json scalus.js; \
        cd /src; \
    done

# --- scalus-js-140: the published npm package ------------------------------------------------
FROM node:22-bookworm-slim AS pkg-scalus-js-140
ARG SCALUS_JS_VERSION
WORKDIR /npm
COPY images/scalus-js/package.json images/scalus-js/package-lock.json ./
# Install from the lockfile, then pin the package to the .env version (a no-op when the lockfile
# already has it).
RUN npm ci --no-audit --no-fund \
    && npm install --no-audit --no-fund --save-exact \
        "scalus@${SCALUS_JS_VERSION}" \
    && node -e 'const v=require("./node_modules/scalus/package.json").version; if (v !== process.argv[1]) { console.error("scalus " + v + " != " + process.argv[1]); process.exit(1) }' "${SCALUS_JS_VERSION}" \
    && mkdir /pkg && cp -r node_modules/scalus /pkg/1.4.0

FROM pkg-${VM} AS pkg

# Node 22, the same major as the blaze-v8 harness (nodesource setup_22.x in the root Dockerfile).
FROM node:22-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /bench/scalus-js
# The scalus package has no dependencies: one self-contained scalus.js. run-scalus-js.sh links
# pkgs/<build> to node_modules/scalus.
COPY --from=pkg /pkg/ /bench/scalus-js/pkgs/
COPY images/scalus-js/package.json ./

COPY parsers/ /bench/parsers/
COPY images/scalus-js/common.mjs images/scalus-js/check.mjs images/scalus-js/time.mjs ./
COPY scripts/image-entry.sh scripts/run-scalus-js.sh scripts/run-scalus-js-140.sh /bench/scripts/

ARG VM
ENV PVB_VM=${VM}
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
