# plutus-core, the Haskell reference evaluator (GHC / Criterion). docs/IMAGE_CONTRACT.md.
#
# Builds images/haskell/pvb-bench against plutus-core and plutus-ledger-api at HASKELL_SHA
# (release 1.63.0.0, the plutus version of the production cardano-node). pvb-bench times flat
# decode + CEK evaluation with the mainnet PlutusV3 cost model at protocol version 11 (spec D3)
# and writes the check (spec D4) with the code of check/reference/gate-ref.

# =============================================================================
# Build stage
# =============================================================================
FROM debian:bookworm AS build

ARG HASKELL_REPO
ARG HASKELL_SHA
ARG HASKELL_GHC_VERSION

ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
    BOOTSTRAP_HASKELL_GHC_VERSION=${HASKELL_GHC_VERSION} \
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

RUN git init -q /src \
    && git -C /src fetch --depth 1 "$HASKELL_REPO" "$HASKELL_SHA" \
    && git -C /src checkout -q FETCH_HEAD

WORKDIR /src

# No tests, benchmarks, inline-r (libR) or plutus-cert. Add pvb-bench to the project.
RUN sed -i 's/^tests: true/tests: false/; s/^benchmarks: true/benchmarks: false/' cabal.project \
    && sed -i 's/flags: +with-inline-r +with-cert/flags: -with-inline-r -with-cert/' cabal.project \
    && sed -i 's/^packages: cardano-constitution/packages: pvb-bench\n          cardano-constitution/' cabal.project \
    && grep -q '^packages: pvb-bench' cabal.project \
    && grep -q 'flags: -with-inline-r -with-cert' cabal.project

# Build the dependencies first (plutus-core, plutus-ledger-api, criterion), so that a change to
# Main.hs does not rebuild them. -j2: GHC needs ~2 GB per job on plutus-core.
COPY images/haskell/pvb-bench/pvb-bench.cabal /src/pvb-bench/pvb-bench.cabal
RUN cabal update
RUN cabal build pvb-bench --only-dependencies -j2 --disable-documentation

COPY images/haskell/pvb-bench/Main.hs /src/pvb-bench/Main.hs
RUN cabal build pvb-bench -j2 --disable-documentation \
    && cp "$(cabal list-bin pvb-bench)" /src/pvb-bench-bin

# =============================================================================
# Runtime stage
# =============================================================================
# Same distribution as the build stage, so the binary finds the same shared libraries
# (libsecp256k1, libsodium, libgmp, libnuma) with the same sonames.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       python3 procps libgmp10 libsodium23 libsecp256k1-1 libnuma1 libffi8 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/pvb-bench-bin /bench/haskell/bin/pvb-bench
RUN ! ldd /bench/haskell/bin/pvb-bench | grep 'not found'

COPY check/reference/mainnet-plutusv3-costmodel.json /bench/haskell/
COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-haskell.sh /bench/scripts/

ENV PVB_VM=haskell
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
