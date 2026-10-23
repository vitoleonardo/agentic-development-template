"use client";

import { useActionState } from "react";
import { type SplitState, splitExpenses } from "@/features/split/actions";

const euros = (cents: number) => (cents / 100).toFixed(2);

export function SplitForm() {
  const [state, action, pending] = useActionState<SplitState, FormData>(splitExpenses, null);

  return (
    <form action={action}>
      <label htmlFor="expenses">Expenses</label>
      <textarea
        id="expenses"
        name="expenses"
        rows={6}
        style={{ display: "block", width: "100%" }}
        required
      />
      <button type="submit" disabled={pending}>
        {pending ? "Splitting…" : "Split"}
      </button>

      {state?.error && <p role="alert">{state.error}</p>}
      {state?.transfers && (
        <section aria-live="polite">
          <h2>Who pays whom</h2>
          {state.transfers.length === 0 ? (
            <p>Everyone is even.</p>
          ) : (
            <ul>
              {state.transfers.map((t) => (
                <li key={`${t.from}-${t.to}`}>
                  {t.from} pays {t.to} {euros(t.amountCents)}
                </li>
              ))}
            </ul>
          )}
        </section>
      )}
    </form>
  );
}
