# check=skip=InvalidDefaultArgInFrom
# blaze-plutus, CEK interpreter (TypeScript, timed under vitest on Node.js / V8). docs/IMAGE_CONTRACT.md.
# The VM is named after its engine; the directory keeps the package name.
# pvb-vms: blaze-v8

ARG BUN_VERSION

# =============================================================================
# Build stage
# =============================================================================
FROM oven/bun:${BUN_VERSION}-debian AS build

ARG BLAZE_REPO
ARG BLAZE_SHA
ARG VITEST_VERSION

RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

RUN git clone "$BLAZE_REPO" /src \
    && cd /src && git checkout "$BLAZE_SHA"

WORKDIR /src
# blaze is a bun workspace (bun.lock), so bun installs it. Bun is a build tool only: the runtime
# stage has no bun, the benchmark runs on Node.js.
RUN bun install
# The timing runs under the vitest of .env (VITEST_VERSION). blaze's lockfile picks its own; stop
# the build when it differs, so a blaze bump cannot change the timing tool silently.
# bun installs packages isolated (no root node_modules/vitest), so ask bun from the package that
# runs the benchmark.
RUN v=$(cd packages/blaze-plutus && bun -e 'console.log(require("vitest/package.json").version)') \
    && echo "vitest $v" \
    && if [ "$v" != "$VITEST_VERSION" ]; then \
           echo "blaze uses vitest $v, .env VITEST_VERSION is $VITEST_VERSION" >&2; exit 1; \
       fi

# =============================================================================
# Runtime stage
# =============================================================================
FROM ubuntu:24.04

ARG NODE_VERSION

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 procps curl ca-certificates \
    && curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /src /bench/blaze-plutus

# Our harness (pvb-time.test.ts: timing, one script per process; pvb-check.test.ts) and the mainnet
# PlutusV3 cost model mapped into blaze's cost table (pvb-costs.ts). See the headers of images/blaze/*.ts.
COPY images/blaze/pvb-costs.ts images/blaze/pvb-time.test.ts images/blaze/pvb-check.test.ts \
     /bench/blaze-plutus/packages/blaze-plutus/bench/
COPY check/reference/mainnet-plutusv3-costmodel.json /bench/mainnet-plutusv3-costmodel.json
COPY images/blaze/plutusv3-param-names.txt /bench/plutusv3-param-names.txt

COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-blaze-v8.sh /bench/scripts/

ENV PVB_VM=blaze-v8
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
