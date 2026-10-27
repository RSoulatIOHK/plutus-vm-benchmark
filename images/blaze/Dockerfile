# check=skip=InvalidDefaultArgInFrom
# blaze-plutus, CEK interpreter (TypeScript, timed on Node.js / V8 by the shared loop of
# images/node-base). docs/IMAGE_CONTRACT.md.
# The VM is named after its engine; the directory keeps the package name.
# pvb-vms: blaze-v8

ARG BUN_VERSION
ARG NODE_BASE

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

# The VM module of the shared timing loop (pvb-vm.ts, with the mainnet PlutusV3 cost model mapped
# into blaze's cost table, pvb-costs.ts), bundled with blaze's sources into one plain JavaScript
# module that node runs: bench/pvb-vm.mjs.
COPY images/blaze/pvb-costs.ts images/blaze/pvb-vm.ts /src/packages/blaze-plutus/bench/
RUN cd packages/blaze-plutus \
    && bun build bench/pvb-vm.ts --target=node --format=esm --outfile=bench/pvb-vm.mjs

# =============================================================================
# Runtime stage: the Node base (images/node-base), Node.js and the shared timing loop
# =============================================================================
FROM ${NODE_BASE}

COPY --from=build /src /bench/blaze-plutus

# The check runs under vitest (pvb-check.test.ts). See the headers of images/blaze/*.ts.
COPY images/blaze/pvb-check.test.ts /bench/blaze-plutus/packages/blaze-plutus/bench/
COPY check/reference/mainnet-plutusv3-costmodel.json /bench/mainnet-plutusv3-costmodel.json
COPY images/blaze/plutusv3-param-names.txt /bench/plutusv3-param-names.txt

COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-blaze-v8.sh /bench/scripts/

ENV PVB_VM=blaze-v8
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
