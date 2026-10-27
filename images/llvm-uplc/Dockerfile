# pvb-vms: llvm-uplc-jit
# llvm-uplc (C / C++, UPLC compiled to native code with LLVM LLJIT). docs/IMAGE_CONTRACT.md.
# Experimental row: no release tag, no downstream user (spec D17). Compile excluded (D15, D21).

# =============================================================================
# Build stage
# =============================================================================
FROM ubuntu:24.04 AS build

ARG LLVM_UPLC_REPO
ARG LLVM_UPLC_SHA
# LLVM major version from apt.llvm.org (llvm-uplc needs >= 19; the latest 22.x patch release).
ARG LLVM_VERSION

ENV DEBIAN_FRONTEND=noninteractive

# xxd: runtime/CMakeLists.txt embeds the runtime bitcode with it.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates git cmake ninja-build pkg-config wget gnupg build-essential xxd \
       libgmp-dev libsodium-dev libsecp256k1-dev libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/llvm-archive-keyring.gpg; \
    . /etc/os-release; \
    echo "deb [signed-by=/usr/share/keyrings/llvm-archive-keyring.gpg] http://apt.llvm.org/${UBUNTU_CODENAME}/ llvm-toolchain-${UBUNTU_CODENAME}-${LLVM_VERSION} main" \
        > /etc/apt/sources.list.d/llvm.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        "clang-${LLVM_VERSION}" "lld-${LLVM_VERSION}" "llvm-${LLVM_VERSION}-dev" \
        "libclang-${LLVM_VERSION}-dev" "libpolly-${LLVM_VERSION}-dev"; \
    rm -rf /var/lib/apt/lists/*

RUN git clone "$LLVM_UPLC_REPO" /src \
    && cd /src && git checkout "$LLVM_UPLC_SHA" \
    && git submodule update --init --recursive

WORKDIR /src

# Our harness replaces upstream's tools/bench/main.cc, so the uplcbench target links it the same
# way (header of images/llvm-uplc/pvb_main.cc). The configure step fetches BLST (FetchContent).
# /usr/lib/llvm-N/bin first: runtime/CMakeLists.txt finds clang, llvm-link and opt unversioned.
COPY images/llvm-uplc/pvb_main.cc /src/tools/bench/main.cc
RUN set -eux; \
    export PATH="/usr/lib/llvm-${LLVM_VERSION}/bin:${PATH}"; \
    cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="clang-${LLVM_VERSION}" \
        -DCMAKE_CXX_COMPILER="clang++-${LLVM_VERSION}" \
        -DLLVM_DIR="/usr/lib/llvm-${LLVM_VERSION}/lib/cmake/llvm"; \
    cmake --build build --target uplcbench -j"$(nproc)"; \
    llvm-config --version > /llvm-version.txt

# =============================================================================
# Runtime stage
# =============================================================================
FROM ubuntu:24.04

ARG LLVM_VERSION
ENV DEBIAN_FRONTEND=noninteractive

# uplcbench links libLLVM dynamically; the llvm-uplc libraries are static in the binary.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates gnupg wget python3 procps \
        libgmp10 libsodium23 libsecp256k1-1 libssl3t64 libstdc++6; \
    wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/llvm-archive-keyring.gpg; \
    . /etc/os-release; \
    echo "deb [signed-by=/usr/share/keyrings/llvm-archive-keyring.gpg] http://apt.llvm.org/${UBUNTU_CODENAME}/ llvm-toolchain-${UBUNTU_CODENAME}-${LLVM_VERSION} main" \
        > /etc/apt/sources.list.d/llvm.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends "libllvm${LLVM_VERSION}"; \
    apt-get purge -y gnupg wget; apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /src/build/tools/bench/uplcbench /bench/llvm-uplc/pvb-llvm-uplc
COPY --from=build /llvm-version.txt /bench/llvm-uplc/llvm-version.txt

COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-llvm-uplc-jit.sh /bench/scripts/

ENV PVB_VM=llvm-uplc-jit
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
