import { z } from "zod";
import type { Expense } from "./settle";

const name = z.string().trim().min(1, "Every name needs at least one character.").max(40);

export const expenseSchema = z.object({
  payer: name,
  amountCents: z.number().int().positive("The amount must be greater than zero.").max(100_000_000),
  participants: z.array(name).min(1, "An expense needs at least one participant."),
});

const linePattern = /^(.+?)\s+paid\s+(\d+(?:\.\d{1,2})?)\s+for\s+(.+)$/i;

export type ParseResult = { ok: true; expenses: Expense[] } | { ok: false; error: string };

/**
 * Parses one expense per line in the form "Alice paid 30.50 for Alice, Bob".
 * Blank lines are ignored. The first invalid line stops parsing with an error naming the line.
 */
export function parseExpenses(text: string): ParseResult {
  const lines = text
    .split("\n")
    .map((line, index) => ({ line: line.trim(), number: index + 1 }))
    .filter(({ line }) => line.length > 0);

  if (lines.length === 0) {
    return { ok: false, error: "Add at least one expense." };
  }

  const expenses: Expense[] = [];
  for (const { line, number } of lines) {
    const match = linePattern.exec(line);
    if (!match) {
      return { ok: false, error: `Line ${number}: write it as "Alice paid 30.50 for Alice, Bob".` };
    }
    const [, payer, amount, people] = match;
    const parsed = expenseSchema.safeParse({
      payer,
      amountCents: Math.round(Number(amount) * 100),
      participants: people.split(",").map((person) => person.trim()),
    });
    if (!parsed.success) {
      return { ok: false, error: `Line ${number}: ${parsed.error.issues[0].message}` };
    }
    expenses.push(parsed.data);
  }
  return { ok: true, expenses };
}
