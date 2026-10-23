import { describe, expect, it } from "vitest";
import { splitExpenses } from "./actions";
import { parseExpenses } from "./parse";

const form = (expenses: string) => {
  const data = new FormData();
  data.set("expenses", expenses);
  return data;
};

describe("parseExpenses", () => {
  it("SPLIT-AC6: reads one expense per line and converts the amount to cents", () => {
    expect(parseExpenses("Alice paid 30.50 for Alice, Bob\n\nBob paid 4 for Bob")).toEqual({
      ok: true,
      expenses: [
        { payer: "Alice", amountCents: 3050, participants: ["Alice", "Bob"] },
        { payer: "Bob", amountCents: 400, participants: ["Bob"] },
      ],
    });
  });

  it.each([
    ["", "Add at least one expense."],
    ["Alice bought pizza", 'Line 1: write it as "Alice paid 30.50 for Alice, Bob".'],
    ["Alice paid 0 for Bob", "Line 1: The amount must be greater than zero."],
    ["Alice paid 5 for Bob, ", "Line 1: Every name needs at least one character."],
  ])("SPLIT-AC4: rejects %j with a message", (input, error) => {
    expect(parseExpenses(input)).toEqual({ ok: false, error });
  });
});

describe("splitExpenses", () => {
  it("SPLIT-AC4: returns an error instead of a result for invalid input", async () => {
    expect(await splitExpenses(null, form("nonsense"))).toEqual({
      error: 'Line 1: write it as "Alice paid 30.50 for Alice, Bob".',
    });
    expect(await splitExpenses(null, new FormData())).toHaveProperty("error");
    expect(await splitExpenses(null, form("x".repeat(10_001)))).toHaveProperty("error");
  });

  it("SPLIT-AC1: returns the transfers for valid input", async () => {
    expect(await splitExpenses(null, form("Alice paid 20 for Alice, Bob"))).toEqual({
      transfers: [{ from: "Bob", to: "Alice", amountCents: 1000 }],
    });
  });
});
