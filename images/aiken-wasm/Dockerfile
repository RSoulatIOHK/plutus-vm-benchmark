# aiken-wasm: Aiken's uplc crate compiled to WASM the way @lucid-evolution/uplc is
# (same crate rev, lock file, release profile, wasm-bindgen --target nodejs, wasm-opt -O3),
# timed in Node with vitest bench. See images/aiken-wasm/README.md for why it is
# not the published package as is.
# Build context: repo root. Contract: docs/IMAGE_CONTRACT.md.

ARG RUST_VERSION=1.94

FROM rust:${RUST_VERSION}-bookworm AS build

ARG AIKEN_WASM_SHA
ARG LUCID_EVOLUTION_SHA
ARG BINARYEN_VERSION=version_133
ARG CARGO_BUILD_JOBS=2
ENV CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS}

# clang compiles blst (C) to wasm32.
RUN apt-get update \
    && apt-get install -y --no-install-recommends clang \
    && rm -rf /var/lib/apt/lists/* \
    && rustup target add wasm32-unknown-unknown

COPY images/aiken-wasm/wasm /build/wasm
WORKDIR /build/wasm

# Start from the lock file of the published package, at the pinned commit, and
# point the uplc dependency at AIKEN_WASM_SHA.
RUN curl -fsSL -o Cargo.lock \
      "https://raw.githubusercontent.com/Anastasia-Labs/lucid-evolution/${LUCID_EVOLUTION_SHA}/packages/uplc/rust/Cargo.lock" \
    && sed -i "s/rev = \"[0-9a-f]*\"/rev = \"${AIKEN_WASM_SHA}\"/" Cargo.toml \
    && grep -q "${AIKEN_WASM_SHA}" Cargo.toml

# wasm-bindgen CLI must equal the wasm-bindgen crate version in the lock file.
RUN set -eux; \
    WB=$(awk '/^name = "wasm-bindgen"$/{getline; gsub(/version = |"/, ""); print}' Cargo.lock); \
    case "$(uname -m)" in \
      x86_64) WB_T=x86_64-unknown-linux-musl; BY_T=x86_64-linux ;; \
      aarch64) WB_T=aarch64-unknown-linux-gnu; BY_T=aarch64-linux ;; \
    esac; \
    curl -fsSL "https://github.com/wasm-bindgen/wasm-bindgen/releases/download/${WB}/wasm-bindgen-${WB}-${WB_T}.tar.gz" \
      | tar -xz -C /opt; \
    ln -s /opt/wasm-bindgen-${WB}-${WB_T}/wasm-bindgen /usr/local/bin/wasm-bindgen; \
    curl -fsSL "https://github.com/WebAssembly/binaryen/releases/download/${BINARYEN_VERSION}/binaryen-${BINARYEN_VERSION}-${BY_T}.tar.gz" \
      | tar -xz -C /opt; \
    ln -s /opt/binaryen-${BINARYEN_VERSION}/bin/wasm-opt /usr/local/bin/wasm-opt

# What `wasm-pack build --target nodejs` does with the package's release profile.
RUN cargo build --release --target wasm32-unknown-unknown \
    && wasm-bindgen --target nodejs --out-dir pkg \
         target/wasm32-unknown-unknown/release/aiken_wasm_bench.wasm \
    && wasm-opt -O3 --enable-bulk-memory --enable-nontrapping-float-to-int \
         --enable-sign-ext --enable-reference-types --enable-multivalue \
         pkg/aiken_wasm_bench_bg.wasm -o pkg/aiken_wasm_bench_bg.wasm \
    && echo '{"type": "commonjs"}' > pkg/package.json \
    && ls -la pkg

# Node 22: the same major as the blaze-v8 harness.
FROM node:22-bookworm-slim

ARG LUCID_UPLC_VERSION
ARG AIKEN_WASM_SHA

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /bench/aiken-wasm
COPY images/aiken-wasm/bench/package.json images/aiken-wasm/bench/package-lock.json ./
RUN npm pkg set "dependencies.@lucid-evolution/uplc=${LUCID_UPLC_VERSION}" \
    && npm install --package-lock-only --no-audit --no-fund \
    && npm ci --no-audit --no-fund

COPY --from=build /build/wasm/pkg ./pkg
COPY images/aiken-wasm/bench/*.mjs ./

# Guard: the module must be built from the same uplc rev as the published
# package. A bump of only one of LUCID_UPLC_VERSION / AIKEN_WASM_SHA fails here.
RUN node --input-type=module -e ' \
      import { uplc_build_info } from "@lucid-evolution/uplc"; \
      import { createRequire } from "node:module"; \
      const ours = createRequire(import.meta.url)("/bench/aiken-wasm/pkg/aiken_wasm_bench.js").build_info(); \
      const theirs = JSON.parse(uplc_build_info()).uplc; \
      console.log("published:", theirs); console.log("ours:     ", ours); \
      if (ours !== theirs || !ours.includes(process.env.AIKEN_WASM_SHA)) process.exit(1);'

COPY parsers/parse_vitest.py parsers/fill_failures.py /bench/parsers/
COPY scripts/image-entry.sh scripts/run-aiken-wasm.sh /bench/scripts/

ENV PVB_VM=aiken-wasm
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
