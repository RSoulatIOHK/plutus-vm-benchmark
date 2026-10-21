# Haskell reference for the correctness gate (check/README.md).
#
# Builds check/reference/gate-ref against plutus-core and plutus-ledger-api at the given plutus
# tag, then runs it over /bench/data/plutus_use_cases. Regenerate with check/reference/regenerate.sh.
#
# Build context: check/reference/

FROM debian:bookworm AS build

ARG PLUTUS_REPO=https://github.com/IntersectMBO/plutus.git
# Release 1.63.0.0: the plutus version of the production cardano-node (PV11 on mainnet)
ARG PLUTUS_TAG=1.63.0.0
ARG PLUTUS_SHA=ac40fae4dea9dcad51b38a9c5c48148655cb13a2
ARG GHC_VERSION=9.6.7
# cabal -j: keep low on small Docker VMs, GHC needs ~2 GB per job on plutus-core
ARG CABAL_JOBS=2

ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
    BOOTSTRAP_HASKELL_GHC_VERSION=${GHC_VERSION} \
    BOOTSTRAP_HASKELL_INSTALL_NO_STACK=1

RUN apt-get update \
    && apt-get install -y curl git pkg-config build-essential \
       libsodium-dev libsecp256k1-dev zlib1g-dev libgmp-dev libnuma-dev \
    && rm -rf /var/lib/apt/lists/*

# libblst (BLS12-381, required by cardano-crypto-class)
RUN git clone --depth 1 --branch v0.3.14 https://github.com/supranational/blst.git /tmp/blst \
    && cd /tmp/blst && ./build.sh \
    && cp libblst.a /usr/local/lib/ \
    && cp bindings/blst.h bindings/blst_aux.h /usr/local/include/ \
    && mkdir -p /usr/local/lib/pkgconfig \
    && printf 'prefix=/usr/local\nlibdir=${prefix}/lib\nincludedir=${prefix}/include\nName: libblst\nVersion: 0.3.14\nDescription: BLS12-381 library\nLibs: -L${libdir} -lblst\nCflags: -I${includedir}\n' > /usr/local/lib/pkgconfig/libblst.pc \
    && rm -rf /tmp/blst

RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
ENV PATH="/root/.ghcup/bin:${PATH}"

RUN git clone --depth 1 --branch "$PLUTUS_TAG" "$PLUTUS_REPO" /src \
    && test "$(git -C /src rev-parse HEAD)" = "$PLUTUS_SHA"

WORKDIR /src

# No tests, benchmarks, inline-r (libR) or plutus-cert.
RUN sed -i 's/^tests: true/tests: false/; s/^benchmarks: true/benchmarks: false/' cabal.project \
    && sed -i 's/flags: +with-inline-r +with-cert/flags: -with-inline-r -with-cert/' cabal.project

RUN cabal update
# Build the dependencies first, so that a change to gate-ref does not rebuild plutus.
RUN cabal build plutus-core plutus-core:flat plutus-ledger-api -j${CABAL_JOBS} --disable-documentation

# Add gate-ref to the plutus project and build it.
COPY gate-ref /src/gate-ref
RUN sed -i 's/^packages: cardano-constitution/packages: gate-ref\n          cardano-constitution/' cabal.project \
    && cabal build gate-ref -j${CABAL_JOBS} --disable-documentation
RUN cp "$(cabal list-bin gate-ref)" /usr/local/bin/gate-ref

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
       libgmp10 libsodium23 libsecp256k1-1 libnuma1 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /usr/local/bin/gate-ref /usr/local/bin/gate-ref
COPY mainnet-plutusv3-costmodel.json /bench/mainnet-plutusv3-costmodel.json
ENTRYPOINT ["gate-ref", "/bench/mainnet-plutusv3-costmodel.json", "/bench/data/plutus_use_cases"]
