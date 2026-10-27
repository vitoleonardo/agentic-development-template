import { evidence, expect, expenses, test } from "./fixtures";

test("SPLIT-AC1: the shown transfers settle a trip @screenshot", async ({ page, split }, info) => {
  await split(expenses.trip);
  await expect(page.getByRole("heading", { name: "Who pays whom" })).toBeVisible();
  await expect(page.getByRole("listitem")).toHaveText([
    "Bob pays Alice 7.25",
    "Carol pays Alice 4.00",
  ]);
  await evidence(page, "SPLIT-AC1", 1, info.project.name);
});

test("SPLIT-AC3: even expenses say everyone is even @screenshot", async ({ page, split }, info) => {
  await split(expenses.even);
  await expect(page.getByText("Everyone is even.")).toBeVisible();
  await evidence(page, "SPLIT-AC3", 1, info.project.name);
});

test("SPLIT-AC4: an unreadable line shows an error and no transfers @screenshot", async ({
  page,
  split,
}, info) => {
  await split(expenses.invalid);
  // Next.js adds its own empty role="alert" route announcer, so match the form's message by its text.
  await expect(page.getByText(/^Line 1:/)).toBeVisible();
  await expect(page.getByRole("heading", { name: "Who pays whom" })).toHaveCount(0);
  await evidence(page, "SPLIT-AC4", 1, info.project.name);
});
