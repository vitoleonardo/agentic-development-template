"use server";

import { parseExpenses } from "./parse";
import { settle, type Transfer } from "./settle";

export type SplitState =
  | { transfers: Transfer[]; error?: undefined }
  | { transfers?: undefined; error: string }
  | null;

const maxInputLength = 10_000;

/** Server Action behind the split form. Public endpoint: it validates everything it receives. */
export async function splitExpenses(
  _previous: SplitState,
  formData: FormData,
): Promise<SplitState> {
  const text = formData.get("expenses");
  if (typeof text !== "string" || text.length > maxInputLength) {
    return { error: `Enter the expenses as text, at most ${maxInputLength} characters.` };
  }
  const parsed = parseExpenses(text);
  if (!parsed.ok) {
    return { error: parsed.error };
  }
  return { transfers: settle(parsed.expenses) };
}
