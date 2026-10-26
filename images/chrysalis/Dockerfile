# check=skip=InvalidDefaultArgInFrom
# Chrysalis (C# / .NET / BenchmarkDotNet). docs/IMAGE_CONTRACT.md.
# One build, two VMs: the build arg VM picks the default command.
#   chrysalis      the harness on the .NET runtime (JIT), runtime defaults (spec D16)
#   chrysalis-aot  the same harness compiled with NativeAOT
# pvb-vms: chrysalis chrysalis-aot
#
# Our own harness (images/chrysalis/harness) on the released Chrysalis.Plutus CHRYSALIS_VERSION from
# NuGet. The build checks that the package was built from CHRYSALIS_SHA (the commit in its nuspec).

ARG DOTNET_VERSION

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS build

ARG CHRYSALIS_VERSION
ARG CHRYSALIS_SHA

# NativeAOT needs the platform linker.
RUN apt-get update \
    && apt-get install -y --no-install-recommends clang zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

COPY images/chrysalis/harness/ /src/
WORKDIR /src
RUN dotnet restore -p:CHRYSALIS_VERSION="${CHRYSALIS_VERSION}" \
    && grep -q "commit=\"${CHRYSALIS_SHA}\"" \
       /root/.nuget/packages/chrysalis.plutus/"${CHRYSALIS_VERSION}"/*.nuspec \
    || { echo "Chrysalis.Plutus ${CHRYSALIS_VERSION} is not built from ${CHRYSALIS_SHA}"; exit 1; }
RUN dotnet publish -c Release -p:CHRYSALIS_VERSION="${CHRYSALIS_VERSION}" -o /out/jit \
    && dotnet publish -c Release -p:CHRYSALIS_VERSION="${CHRYSALIS_VERSION}" -p:PublishAot=true -o /out/aot \
    && echo "${CHRYSALIS_VERSION} (${CHRYSALIS_SHA})" > /out/version.txt

FROM mcr.microsoft.com/dotnet/runtime:${DOTNET_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 procps \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /out/ /bench/chrysalis/
RUN dotnet --list-runtimes | grep Microsoft.NETCore.App > /bench/chrysalis/dotnet-version.txt \
    && /bench/chrysalis/aot/pvb-chrysalis 2>/dev/null; test $? -eq 2
COPY check/reference/mainnet-plutusv3-costmodel.json /bench/chrysalis/mainnet-plutusv3-costmodel.json
COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-chrysalis.sh scripts/run-chrysalis-aot.sh /bench/scripts/

# Last, so both VMs share every layer above.
ARG VM
ENV PVB_VM=${VM}
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
