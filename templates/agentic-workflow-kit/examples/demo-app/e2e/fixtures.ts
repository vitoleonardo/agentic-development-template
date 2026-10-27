import { test as base, expect, type Page } from "@playwright/test";

// Fixed, versioned input for the end-to-end runs; the demo stores nothing, so this is its seed data.
export const expenses = {
  trip: ["Alice paid 30.50 for Alice, Bob", "Bob paid 12.00 for Alice, Bob, Carol"].join("\n"),
  even: ["Alice paid 10.00 for Alice, Bob", "Bob paid 10.00 for Alice, Bob"].join("\n"),
  invalid: "Alice spent a lot",
};

export const test = base.extend<{ split: (text: string) => Promise<void> }>({
  split: async ({ page }, use) => {
    await page.clock.setFixedTime(new Date("2026-01-01T12:00:00Z"));
    await use(async (text: string) => {
      await page.goto("/");
      await page.getByLabel("Expenses").fill(text);
      await page.getByRole("button", { name: "Split" }).click();
    });
  },
});

/**
 * Save a screenshot for the evidence pack when KIT_SCREENSHOT_DIR is set:
 * <criterion>-<step>-<desktop|mobile><KIT_SCREENSHOT_SUFFIX>.png
 */
export async function evidence(page: Page, criterion: string, step: number, project: string) {
  const dir = process.env.KIT_SCREENSHOT_DIR;
  if (!dir) return;
  const suffix = process.env.KIT_SCREENSHOT_SUFFIX ?? "";
  await page.screenshot({
    path: `${dir}/${criterion}-${step}-${project}${suffix}.png`,
    fullPage: true,
    animations: "disabled",
  });
}

export { expect };
