# check=skip=InvalidDefaultArgInFrom
# OpShin uplc, CEK interpreter (Python). docs/IMAGE_CONTRACT.md.
# One stage: the Python image that builds the package also runs it (the old monolithic image
# copied Python 3.14 into ubuntu:24.04).

ARG PYTHON_VERSION

FROM python:${PYTHON_VERSION}-bookworm

ARG OPSHIN_REPO
ARG OPSHIN_SHA

RUN apt-get update \
    && apt-get install -y git autoconf automake libtool sudo procps \
    && rm -rf /var/lib/apt/lists/*

RUN git clone "$OPSHIN_REPO" /bench/opshin \
    && cd /bench/opshin && git checkout "$OPSHIN_SHA"

WORKDIR /bench/opshin

# Build secp256k1 from source (the upstream script uses sudo; we are root)
RUN bash install_secp256k1.sh && ldconfig

RUN pip install --no-cache-dir .

# Our benchmark script (not part of the upstream repo)
COPY scripts/opshin_bench.py /bench/opshin/bench_plutus_use_cases.py

COPY parsers/ /bench/parsers/
COPY scripts/image-entry.sh scripts/run-opshin.sh /bench/scripts/

ENV PVB_VM=opshin
WORKDIR /bench
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
