import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    benchmark: { include: ["*.bench.mjs"] },
    // Load the wasm-pack nodejs build with plain Node require, untouched by vite.
    server: { deps: { external: [/@lucid-evolution\/uplc/] } },
  },
});
