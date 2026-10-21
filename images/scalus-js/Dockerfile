# scalus-js: the Scalus CEK machine compiled with Scala.js, from the `scalus` npm package.
# Build context is the repo root:
#   docker build -f images/scalus-js/Dockerfile --build-arg SCALUS_JS_VERSION=... -t pvb-scalus-js .

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
COPY images/scalus-js/common.mjs images/scalus-js/check.mjs images/scalus-js/scalus-js.bench.mjs images/scalus-js/run.sh ./

CMD ["/bench/scalus-js/run.sh"]
