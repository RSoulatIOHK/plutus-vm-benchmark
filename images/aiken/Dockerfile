# aiken: the UPLC evaluator of aiken-lang/aiken (crates/uplc, Rust), timed with Criterion.
# Build context: repo root. Contract: docs/IMAGE_CONTRACT.md.

ARG RUST_VERSION=1.94

FROM rust:${RUST_VERSION}-bookworm AS build

ARG AIKEN_REPO
ARG AIKEN_SHA
# Keep peak memory low when other images build at the same time.
ARG CARGO_BUILD_JOBS=2
ENV CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS}

RUN apt-get update \
    && apt-get install -y --no-install-recommends git build-essential clang \
    && rm -rf /var/lib/apt/lists/*

RUN git clone "$AIKEN_REPO" /build/aiken \
    && cd /build/aiken && git checkout "$AIKEN_SHA"

COPY images/aiken/bench /build/bench
WORKDIR /build/bench
# Start from aiken's own lock file so uplc gets the dependency versions it was
# released with; cargo only adds what the bench crate needs (criterion).
RUN cp /build/aiken/Cargo.lock Cargo.lock \
    && cargo build --release --bins \
    && cp target/release/aiken-bench target/release/aiken-check /usr/local/bin/

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

ARG AIKEN_SHA
ENV AIKEN_SHA=${AIKEN_SHA}

COPY --from=build /usr/local/bin/aiken-bench /usr/local/bin/aiken-check /usr/local/bin/
COPY parsers/parse_criterion.py parsers/fill_failures.py /bench/parsers/
COPY images/aiken/run.sh /bench/run.sh

ENTRYPOINT ["/bench/run.sh"]
