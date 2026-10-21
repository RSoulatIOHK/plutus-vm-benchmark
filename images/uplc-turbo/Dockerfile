# check=skip=InvalidDefaultArgInFrom
# uplc-turbo (Amaru), AST walker (Rust / Criterion). docs/IMAGE_CONTRACT.md.

ARG RUST_VERSION

# =============================================================================
# Build stage
# =============================================================================
FROM rust:${RUST_VERSION}-bookworm AS build

ARG UPLC_TURBO_REPO
ARG UPLC_TURBO_SHA

RUN git clone "$UPLC_TURBO_REPO" /src \
    && cd /src && git checkout "$UPLC_TURBO_SHA"

WORKDIR /src

# Our harness replaces the upstream use_cases bench (PV 11, continues after a failing script,
# PVB_CHECK_OUT check mode). See the header of images/uplc-turbo/use_cases.rs.
COPY images/uplc-turbo/use_cases.rs /src/crates/uplc/benches/use_cases/main.rs

RUN cargo build --release --bench use_cases --manifest-path crates/uplc/Cargo.toml

# =============================================================================
# Runtime stage
# =============================================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 procps \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/target /bench/uplc-turbo/target
COPY --from=build /src/crates/uplc/benches /bench/uplc-turbo/crates/uplc/benches
COPY --from=build /src/crates/uplc/Cargo.toml /bench/uplc-turbo/crates/uplc/Cargo.toml
COPY --from=build /src/Cargo.toml /bench/uplc-turbo/Cargo.toml
COPY --from=build /src/Cargo.lock /bench/uplc-turbo/Cargo.lock
RUN bin=$(find /bench/uplc-turbo/target/release/deps -name 'use_cases-*' -type f ! -name '*.d' | head -1) \
    && test -n "$bin" && ! ldd "$bin" | grep 'not found'

COPY check/reference/mainnet-plutusv3-costmodel.json /bench/mainnet-plutusv3-costmodel.json
COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-uplc-turbo.sh /bench/scripts/

ENV PVB_VM=uplc-turbo
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
