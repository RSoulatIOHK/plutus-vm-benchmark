# check=skip=InvalidDefaultArgInFrom
# blaze-plutus, CEK interpreter (TypeScript, timed under vitest). docs/IMAGE_CONTRACT.md.
# One build, two VMs: the build arg VM picks the engine of the default command.
# pvb-vms: blaze-v8 blaze-jsc

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
RUN bun install
# Every JS row times under the same vitest (.env VITEST_VERSION). blaze's lockfile picks its own;
# stop the build when it differs, so a blaze bump cannot change the timing tool silently.
RUN f=$(find /src -path '*/node_modules/vitest/package.json' -not -path '*/node_modules/*/node_modules/*' | head -1) \
    && v=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$f" | head -1) \
    && echo "vitest $v ($f)" \
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

# Bun (JavaScriptCore) from the build image, so build and run use the same Bun version.
COPY --from=build /usr/local/bin/bun /usr/local/bin/bun
COPY --from=build /src /bench/blaze-plutus

# Our harness (pvb-time.test.ts: timing, one script per process; pvb-check.test.ts) and the mainnet
# PlutusV3 cost model mapped into blaze's cost table (pvb-costs.ts). See the headers of images/blaze/*.ts.
COPY images/blaze/pvb-costs.ts images/blaze/pvb-time.test.ts images/blaze/pvb-check.test.ts \
     /bench/blaze-plutus/packages/blaze-plutus/bench/
COPY check/reference/mainnet-plutusv3-costmodel.json /bench/mainnet-plutusv3-costmodel.json
COPY images/blaze/plutusv3-param-names.txt /bench/plutusv3-param-names.txt

COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-blaze-v8.sh scripts/run-blaze-jsc.sh /bench/scripts/

# Last, so both VMs share every layer above.
ARG VM
ENV PVB_VM=${VM}
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
