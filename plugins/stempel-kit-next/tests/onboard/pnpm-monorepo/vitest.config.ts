import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["packages/web/src/**/*.test.ts"],
    coverage: { provider: "v8", include: ["packages/web/src/**/*.ts"], exclude: ["**/*.test.ts"] },
  },
});
