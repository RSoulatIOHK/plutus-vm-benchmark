# check=skip=InvalidDefaultArgInFrom
# aiken-wasm: Aiken's uplc CEK machine compiled to WASM, from the published npm package
# @lucid-evolution/uplc, used as it is (spec D17). README.md explains the decode cache.
# Build context: repo root. Contract: docs/IMAGE_CONTRACT.md. Build: scripts/images.sh build aiken-wasm

# The Node base (images/node-base): the Node.js of every JS row and the shared timing loop.
ARG NODE_BASE

FROM ${NODE_BASE}

ARG LUCID_UPLC_VERSION

WORKDIR /bench/aiken-wasm
COPY images/aiken-wasm/package.json images/aiken-wasm/package-lock.json ./
# Install from the lockfile, then pin the package to the .env version (a no-op when the lockfile
# already has it). The package must report a passing self-test (uplc_build_info()).
RUN npm ci --no-audit --no-fund \
    && npm install --no-audit --no-fund --save-exact \
        "@lucid-evolution/uplc@${LUCID_UPLC_VERSION}" \
    && node -e 'const v=require("./node_modules/@lucid-evolution/uplc/package.json").version; if (v !== process.argv[1]) { console.error("@lucid-evolution/uplc " + v + " != " + process.argv[1]); process.exit(1) }' "${LUCID_UPLC_VERSION}" \
    && node -e 'const i=JSON.parse(require("@lucid-evolution/uplc").uplc_build_info()); console.log(i); if (i.selfTest !== "pass") process.exit(1)'

COPY check/reference/mainnet-plutusv3-costmodel.json /bench/mainnet-plutusv3-costmodel.json
COPY parsers/ /bench/parsers/
COPY images/aiken-wasm/common.mjs images/aiken-wasm/check.mjs images/aiken-wasm/vm.mjs ./
COPY scripts/image-entry.sh scripts/run-aiken-wasm.sh /bench/scripts/

ENV PVB_VM=aiken-wasm
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
