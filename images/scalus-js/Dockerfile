# check=skip=InvalidDefaultArgInFrom
# scalus-js: the Scalus CEK machine compiled with Scala.js, from the `scalus` npm package.
# Build context: repo root. Contract: docs/IMAGE_CONTRACT.md. Build: scripts/images.sh build scalus-js

# The Node base (images/node-base): the Node.js of every JS row and the shared timing loop.
ARG NODE_BASE

FROM ${NODE_BASE}

ARG SCALUS_JS_VERSION

WORKDIR /bench/scalus-js
COPY images/scalus-js/package.json images/scalus-js/package-lock.json ./
# Install from the lockfile, then pin the package to the .env version (a no-op when the lockfile
# already has it).
RUN npm ci --no-audit --no-fund \
    && npm install --no-audit --no-fund --save-exact \
        "scalus@${SCALUS_JS_VERSION}" \
    && node -e 'const v=require("./node_modules/scalus/package.json").version; if (v !== process.argv[1]) { console.error("scalus " + v + " != " + process.argv[1]); process.exit(1) }' "${SCALUS_JS_VERSION}"

COPY parsers/ /bench/parsers/
COPY images/scalus-js/common.mjs images/scalus-js/check.mjs images/scalus-js/vm.mjs ./
COPY scripts/image-entry.sh scripts/run-scalus-js.sh /bench/scripts/

ENV PVB_VM=scalus-js
ENTRYPOINT ["bash", "/bench/scripts/image-entry.sh"]
