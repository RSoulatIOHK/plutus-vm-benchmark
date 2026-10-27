# check=skip=InvalidDefaultArgInFrom
# pvb-base
# Node base image of the JS rows (scalus-js, aiken-wasm, blaze-v8), published as
# ghcr.io/lantr-io/pvb-node-base:<tag> (scripts/images.sh). A VM Dockerfile uses it with
# "ARG NODE_BASE" and "FROM ${NODE_BASE}".
#
# One Node.js for every JS row: Node 24 LTS, the official image of NODE_VERSION pinned by its
# digest NODE_IMAGE_DIGEST (V8 of that release). One timing loop: /bench/node/time.mjs (warm-up, rounds, output), which loads the
# VM module of each row (its operation of a loop).

ARG NODE_VERSION
ARG NODE_IMAGE_DIGEST

FROM node:${NODE_VERSION}-bookworm-slim@${NODE_IMAGE_DIGEST}

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 procps \
    && rm -rf /var/lib/apt/lists/*

COPY images/node-base/time.mjs /bench/node/time.mjs
