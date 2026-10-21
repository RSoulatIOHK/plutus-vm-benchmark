# plutus-core, the Haskell reference evaluator (GHC / Criterion). docs/IMAGE_CONTRACT.md.
# The build stage is the build-haskell stage of the old monolithic Dockerfile, unchanged.

# =============================================================================
# Build stage
# =============================================================================
FROM debian:bookworm AS build

ARG HASKELL_REPO
ARG HASKELL_SHA
ARG GHC_VERSION

ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
    BOOTSTRAP_HASKELL_GHC_VERSION=${GHC_VERSION} \
    BOOTSTRAP_HASKELL_INSTALL_NO_STACK=1

RUN apt-get update \
    && apt-get install -y curl git pkg-config build-essential \
       libsodium-dev libsecp256k1-dev zlib1g-dev libgmp-dev libnuma-dev \
    && rm -rf /var/lib/apt/lists/*

# Install libblst (BLS12-381 crypto required by cardano-crypto-class)
RUN git clone --depth 1 --branch v0.3.14 https://github.com/supranational/blst.git /tmp/blst \
    && cd /tmp/blst && ./build.sh \
    && cp libblst.a /usr/local/lib/ \
    && cp bindings/blst.h bindings/blst_aux.h /usr/local/include/ \
    && mkdir -p /usr/local/lib/pkgconfig \
    && printf 'prefix=/usr/local\nlibdir=${prefix}/lib\nincludedir=${prefix}/include\nName: libblst\nVersion: 0.3.14\nDescription: BLS12-381 library\nLibs: -L${libdir} -lblst\nCflags: -I${includedir}\n' > /usr/local/lib/pkgconfig/libblst.pc \
    && rm -rf /tmp/blst

# Install GHC + cabal via ghcup
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
ENV PATH="/root/.ghcup/bin:${PATH}"

RUN git clone "$HASKELL_REPO" /src \
    && cd /src && git checkout "$HASKELL_SHA"

WORKDIR /src

# Disable inline-r (requires libR) and cert (requires extra deps) — not needed for benchmarks
RUN sed -i 's/flags: +with-inline-r/flags: -with-inline-r/' cabal.project \
    && sed -i 's/flags: +with-cert/flags: -with-cert/' cabal.project

RUN cabal update
RUN cabal build plutus-benchmark:bench:validation -j

# Stage the built bench binary at an arch-independent path. dist-newstyle nests
# the binary under <arch>-linux (x86_64-linux or aarch64-linux), so glob it here
# and let the runner COPY from a fixed location.
RUN cp dist-newstyle/build/*-linux/ghc-*/plutus-benchmark-*/b/validation/build/validation/validation /src/validation-bin

# =============================================================================
# Runtime stage
# =============================================================================
# Same distribution as the build stage, so the binary finds the same shared libraries
# (libsecp256k1, libsodium, libgmp, libnuma) with the same sonames. The old monolithic
# image ran it on ubuntu:24.04, where it relied on opshin's hand-built libsecp256k1.
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       python3 procps libsodium-dev libsecp256k1-dev zlib1g-dev libgmp-dev libnuma-dev libffi-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/validation-bin /bench/haskell/bin/validation
RUN ! ldd /bench/haskell/bin/validation | grep 'not found'

COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-haskell.sh /bench/scripts/

ENV PVB_VM=haskell
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
