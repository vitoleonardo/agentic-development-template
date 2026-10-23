import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: {
    alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) },
  },
  test: {
    include: ["src/**/*.test.ts"],
    coverage: {
      provider: "v8",
      // Untested files count as 0%. Routes and components in app/ are covered by E2E tests instead.
      include: ["src/**/*.ts"],
      exclude: ["src/**/*.test.ts", "src/app/**"],
    },
  },
});
