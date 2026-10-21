# scalus-js: the Scalus CEK machine compiled with Scala.js, from the `scalus` npm package.
# Build context: repo root. Contract: docs/IMAGE_CONTRACT.md. Build: scripts/images.sh build scalus-js

# Node 22, the same major as the blaze-v8 harness (nodesource setup_22.x in the root Dockerfile).
FROM node:22-bookworm-slim

ARG SCALUS_JS_VERSION
ARG VITEST_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /bench/scalus-js
COPY images/scalus-js/package.json images/scalus-js/package-lock.json ./
# Install from the lockfile, then pin the two packages to the .env versions (a no-op when the
# lockfile already has them).
RUN npm ci --no-audit --no-fund \
    && npm install --no-audit --no-fund --save-exact \
        "scalus@${SCALUS_JS_VERSION}" "vitest@${VITEST_VERSION}" \
    && node -e 'const v=require("./node_modules/scalus/package.json").version; if (v !== process.argv[1]) { console.error("scalus " + v + " != " + process.argv[1]); process.exit(1) }' "${SCALUS_JS_VERSION}"

COPY parsers/ /bench/parsers/
COPY images/scalus-js/common.mjs images/scalus-js/check.mjs images/scalus-js/time.test.mjs ./
COPY scripts/image-entry.sh scripts/run-scalus-js.sh /bench/scripts/

ENV PVB_VM=scalus-js
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
