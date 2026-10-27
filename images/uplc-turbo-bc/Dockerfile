# check=skip=InvalidDefaultArgInFrom
# uplc-turbo-bc: the bytecode VM of uplc-turbo (Rust / Criterion). docs/IMAGE_CONTRACT.md.
# The bytecode VM lives only in a fork: jonathanlim222/uplc (closed PR pragma-org/uplc#47).

ARG RUST_VERSION

# =============================================================================
# Build stage
# =============================================================================
FROM rust:${RUST_VERSION}-bookworm AS build

ARG UPLC_TURBO_BC_REPO
ARG UPLC_TURBO_BC_SHA
# Keep peak memory low when other images build at the same time.
ARG CARGO_BUILD_JOBS=2
ENV CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS}

RUN git clone "$UPLC_TURBO_BC_REPO" /src \
    && cd /src && git checkout "$UPLC_TURBO_BC_SHA"

WORKDIR /src

# Our harness replaces the upstream use_cases bench (PV 11, continues after a failing script,
# PVB_CHECK_OUT check mode). See the header of images/uplc-turbo-bc/use_cases.rs.
COPY images/uplc-turbo-bc/use_cases.rs /src/crates/uplc/benches/use_cases/main.rs

# The harness builds the mainnet cost model once and clones it per evaluation (bytecode::vm::execute
# takes it by value). The pinned cost model types derive only Debug and PartialEq, so add Clone.
# That adds an impl and changes no code the VM runs. The check: all 21 derives got it.
RUN sed -i 's/^#\[derive(Debug, PartialEq)\]$/#[derive(Debug, PartialEq, Clone)]/' \
        $(grep -rl '^#\[derive(Debug, PartialEq)\]$' crates/uplc/src/machine/cost_model) \
    && test "$(grep -r '^#\[derive(Debug, PartialEq, Clone)\]$' crates/uplc/src/machine/cost_model | wc -l)" -eq 22

# The release profile of Amaru, the node that ships this crate (spec D16): fat LTO and one codegen
# unit (pragma-org/amaru Cargo.toml:194-196 at a393a0b; its release binaries are built with
# `cargo build --release`, .github/workflows/release-begin.yml:202). The workspace of the pinned
# repo has no [profile] section, so the environment sets it. `cargo build --release` builds the
# bench with the release profile; the BENCH pair covers `cargo bench`.
ENV CARGO_PROFILE_RELEASE_LTO=true \
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 \
    CARGO_PROFILE_BENCH_LTO=true \
    CARGO_PROFILE_BENCH_CODEGEN_UNITS=1

# The check: rustc built the crate and linked the bench binary with fat LTO and one codegen unit.
RUN { cargo build -v --release --bench use_cases --manifest-path crates/uplc/Cargo.toml \
        > /tmp/build.log 2>&1 || { tail -50 /tmp/build.log; exit 1; }; } \
    && grep -E -- '--crate-name use_cases ' /tmp/build.log > /tmp/bench.log \
    && grep -q -E -- '-C lto( |=fat )' /tmp/bench.log && grep -q -- '-C codegen-units=1' /tmp/bench.log \
    && grep -E -- '--crate-name amaru_uplc ' /tmp/build.log | grep -q -- '-C codegen-units=1'

# =============================================================================
# Runtime stage
# =============================================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 procps \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/target /bench/uplc-turbo-bc/target
COPY --from=build /src/crates/uplc/benches /bench/uplc-turbo-bc/crates/uplc/benches
COPY --from=build /src/crates/uplc/Cargo.toml /bench/uplc-turbo-bc/crates/uplc/Cargo.toml
COPY --from=build /src/Cargo.toml /bench/uplc-turbo-bc/Cargo.toml
COPY --from=build /src/Cargo.lock /bench/uplc-turbo-bc/Cargo.lock
RUN bin=$(find /bench/uplc-turbo-bc/target/release/deps -name 'use_cases-*' -type f ! -name '*.d' | head -1) \
    && test -n "$bin" && ! ldd "$bin" | grep 'not found'

COPY check/reference/mainnet-plutusv3-costmodel.json /bench/mainnet-plutusv3-costmodel.json
COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-uplc-turbo-bc.sh /bench/scripts/

ENV PVB_VM=uplc-turbo-bc
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
