# aiken-wasm: Aiken's uplc CEK machine compiled to WASM, from the published npm package
# @lucid-evolution/uplc, used as it is (spec D17). README.md explains the decode cache.
# Build context: repo root. Contract: docs/IMAGE_CONTRACT.md. Build: scripts/images.sh build aiken-wasm

# Node 22, the same major as the blaze-v8 and scalus-js harnesses.
FROM node:22-bookworm-slim

ARG LUCID_UPLC_VERSION
ARG VITEST_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /bench/aiken-wasm
COPY images/aiken-wasm/package.json images/aiken-wasm/package-lock.json ./
# Install from the lockfile, then pin the two packages to the .env versions (a no-op when the
# lockfile already has them). The package must report a passing self-test (uplc_build_info()).
RUN npm ci --no-audit --no-fund \
    && npm install --no-audit --no-fund --save-exact \
        "@lucid-evolution/uplc@${LUCID_UPLC_VERSION}" "vitest@${VITEST_VERSION}" \
    && node -e 'const v=require("./node_modules/@lucid-evolution/uplc/package.json").version; if (v !== process.argv[1]) { console.error("@lucid-evolution/uplc " + v + " != " + process.argv[1]); process.exit(1) }' "${LUCID_UPLC_VERSION}" \
    && node -e 'const i=JSON.parse(require("@lucid-evolution/uplc").uplc_build_info()); console.log(i); if (i.selfTest !== "pass") process.exit(1)'

COPY check/reference/mainnet-plutusv3-costmodel.json /bench/mainnet-plutusv3-costmodel.json
COPY parsers/ /bench/parsers/
COPY images/aiken-wasm/common.mjs images/aiken-wasm/check.mjs images/aiken-wasm/time.test.mjs ./
COPY scripts/image-entry.sh scripts/run-aiken-wasm.sh /bench/scripts/

ENV PVB_VM=aiken-wasm
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
