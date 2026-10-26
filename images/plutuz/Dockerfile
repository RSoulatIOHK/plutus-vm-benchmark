# Plutuz (utxo-company), CEK interpreter (Zig). docs/IMAGE_CONTRACT.md.

# =============================================================================
# Build stage
# =============================================================================
FROM debian:bookworm-slim AS build

ARG PLUTUZ_REPO
ARG PLUTUZ_SHA
# Zig: the minimum_zig_version of build.zig.zon at PLUTUZ_SHA (.env)
ARG ZIG_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl xz-utils git \
    && rm -rf /var/lib/apt/lists/*

# Zig for the build platform: uname -m is x86_64 or aarch64, as in Zig's tarball names, so the
# image builds natively on amd64 and arm64.
RUN ARCH="$(uname -m)" \
    && curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-${ARCH}-linux-${ZIG_VERSION}.tar.xz" \
    | tar -xJ -C /opt \
    && ln -s "/opt/zig-${ARCH}-linux-${ZIG_VERSION}/zig" /usr/local/bin/zig

RUN git clone "$PLUTUZ_REPO" /src \
    && cd /src && git checkout "$PLUTUZ_SHA"

WORKDIR /src
# Our harness (pvb-bench): PlutusV3, protocol version 11, mainnet cost model, restricting mode
# with an enormous budget. See the header of images/plutuz/pvb_bench.zig. build.zig gets one more
# executable next to the upstream bench.
COPY images/plutuz/pvb_bench.zig /src/bench/pvb_bench.zig
COPY images/plutuz/build-pvb.zig.snippet /tmp/build-pvb.zig.snippet
RUN sed -i '/bench_step.dependOn(&run_bench.step);/r /tmp/build-pvb.zig.snippet' build.zig \
    && grep -q '"pvb-bench"' build.zig
# -Dcpu=baseline: the image is built on a CI runner and runs on the bench server, so the code
# must not use CPU features of the build machine (Zig's default target is the native CPU). blst
# keeps its runtime CPU detection (__BLST_PORTABLE__, set by upstream build.zig).
RUN zig build -Doptimize=ReleaseFast -Dcpu=baseline \
    && test -x zig-out/bin/pvb-bench

# =============================================================================
# Runtime stage
# =============================================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 procps \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/zig-out/bin/pvb-bench /bench/plutuz/pvb-bench

COPY check/reference/mainnet-plutusv3-costmodel.json /bench/mainnet-plutusv3-costmodel.json
COPY parsers/parse_plutuz_json.py parsers/fill_failures.py /bench/parsers/
COPY scripts/image-entry.sh scripts/run-plutuz.sh /bench/scripts/

ARG PLUTUZ_SHA
ENV PLUTUZ_SHA=${PLUTUZ_SHA}
ENV PVB_VM=plutuz
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
