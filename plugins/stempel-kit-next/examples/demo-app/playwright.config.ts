import { defineConfig, devices } from "@playwright/test";

// End-to-end tests and the screenshots for /verify-feature. Fixed locale, timezone and clock, and no
// animations, so the same commit gives the same images.
const port = Number(process.env.E2E_PORT ?? 3417);

export default defineConfig({
  testDir: "e2e",
  outputDir: ".work/playwright",
  reporter: [["list"]],
  use: {
    baseURL: `http://localhost:${port}`,
    locale: "en-US",
    timezoneId: "UTC",
    colorScheme: "light",
    reducedMotion: "reduce",
  },
  projects: [
    {
      name: "desktop",
      use: { ...devices["Desktop Chrome"], viewport: { width: 1280, height: 800 } },
    },
    { name: "mobile", use: { ...devices["Pixel 7"] } },
  ],
  webServer: {
    command: `npm run build && npm run start -- -p ${port}`,
    url: `http://localhost:${port}`,
    reuseExistingServer: false,
    timeout: 180_000,
  },
});
