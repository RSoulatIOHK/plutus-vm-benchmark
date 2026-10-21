# aiken-wasm: @lucid-evolution/uplc (Aiken's uplc crate built to WASM by wasm-pack),
# the evaluator Lucid Evolution users run, timed in Node with vitest bench.
# Build context: repo root. Contract: docs/IMAGE_CONTRACT.md.

# Node 22: the same major as the blaze-v8 harness.
FROM node:22-bookworm-slim

ARG LUCID_UPLC_VERSION
ARG LUCID_EVOLUTION_SHA

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /bench/aiken-wasm
COPY images/aiken-wasm/bench/package.json images/aiken-wasm/bench/package-lock.json ./
# Pin the package to LUCID_UPLC_VERSION from .env, then install exactly the lock file.
RUN npm pkg set "dependencies.@lucid-evolution/uplc=${LUCID_UPLC_VERSION}" \
    && npm install --package-lock-only --no-audit --no-fund \
    && npm ci --no-audit --no-fund

# The package ships no cost model: take the PlutusV3 one (350 parameters) from
# the package's own test fixture at the pinned lucid-evolution commit.
RUN curl -fsSL -o plutus-v3-cost-model.json \
    "https://raw.githubusercontent.com/Anastasia-Labs/lucid-evolution/${LUCID_EVOLUTION_SHA}/packages/uplc/test/fixtures/plutus-v3-cost-model.json" \
    && node -e 'const a=require("./plutus-v3-cost-model.json"); if (a.length !== 350) { console.error("cost model has", a.length, "params"); process.exit(1) }'

COPY images/aiken-wasm/bench/*.mjs ./
COPY parsers/parse_vitest.py parsers/fill_failures.py /bench/parsers/
COPY images/aiken-wasm/run.sh /bench/run.sh

ENTRYPOINT ["/bench/run.sh"]
