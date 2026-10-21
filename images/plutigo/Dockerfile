# check=skip=InvalidDefaultArgInFrom
# Plutigo (Dingo), CEK interpreter (Go / testing.B). docs/IMAGE_CONTRACT.md.

ARG GO_VERSION

# =============================================================================
# Build stage
# =============================================================================
FROM golang:${GO_VERSION}-bookworm AS build

ARG PLUTIGO_REPO
ARG PLUTIGO_SHA

RUN git clone "$PLUTIGO_REPO" /src \
    && cd /src && git checkout "$PLUTIGO_SHA"

WORKDIR /src
RUN go mod download
# Our harness (BenchmarkPvbFlatFiles, TestPvbCheck): PlutusV3, protocol version 11, mainnet
# cost model, counting mode. See the header of images/plutigo/pvb_bench_test.go.
COPY images/plutigo/pvb_bench_test.go /src/tests/pvb_bench_test.go
RUN CGO_ENABLED=0 go test -c -o /plutigo-bench ./tests/

# =============================================================================
# Runtime stage
# =============================================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 procps \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /plutigo-bench /bench/plutigo/plutigo-bench

COPY check/reference/mainnet-plutusv3-costmodel.json /bench/mainnet-plutusv3-costmodel.json
COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-plutigo.sh /bench/scripts/

ENV PVB_VM=plutigo
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
