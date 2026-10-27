# check=skip=InvalidDefaultArgInFrom
# pvb-base
# Node base image of the JS rows (scalus-js, aiken-wasm, blaze-v8), published as
# ghcr.io/lantr-io/pvb-node-base:<tag> (scripts/images.sh). A VM Dockerfile uses it with
# "ARG NODE_BASE" and "FROM ${NODE_BASE}".
#
# One Node.js for every JS row: the official image of NODE_VERSION (one pinned patch version, V8 of
# that release). One timing loop: /bench/node/time.mjs (warm-up, rounds, output), which loads the
# VM module of each row (its operation of a loop).

ARG NODE_VERSION

FROM node:${NODE_VERSION}-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 procps \
    && rm -rf /var/lib/apt/lists/*

COPY images/node-base/time.mjs /bench/node/time.mjs
