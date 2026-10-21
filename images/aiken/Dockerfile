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
# --profile dist: the profile of the aiken release binaries (images/aiken/bench/Cargo.toml).
# The check: rustc linked both binaries with thin LTO.
RUN cp /build/aiken/Cargo.lock Cargo.lock \
    && { cargo build -v --profile dist --bins > /tmp/build.log 2>&1 || { tail -50 /tmp/build.log; exit 1; }; } \
    && grep -E -- '--crate-name aiken_(bench|check) .*--crate-type bin' /tmp/build.log > /tmp/bins.log \
    && test "$(grep -c -- '-C lto=thin' /tmp/bins.log)" = 2 \
    && cp target/dist/aiken-bench target/dist/aiken-check /usr/local/bin/

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

ARG AIKEN_SHA
ENV AIKEN_SHA=${AIKEN_SHA}

COPY --from=build /usr/local/bin/aiken-bench /usr/local/bin/aiken-check /usr/local/bin/
COPY parsers/parse_criterion.py parsers/fill_failures.py /bench/parsers/
COPY scripts/image-entry.sh scripts/run-aiken.sh /bench/scripts/

ENV PVB_VM=aiken
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
