/** An expense in whole cents, paid by one person and shared equally by the participants. */
export type Expense = {
  payer: string;
  amountCents: number;
  participants: string[];
};

export type Transfer = {
  from: string;
  to: string;
  amountCents: number;
};

/**
 * Splits amountCents into shares that differ by at most one cent and add up exactly.
 * The extra cents go to the participants in alphabetical order, so the result is stable.
 */
export function shares(amountCents: number, participants: string[]): Map<string, number> {
  const names = [...new Set(participants)].sort();
  const base = Math.floor(amountCents / names.length);
  const remainder = amountCents - base * names.length;
  return new Map(names.map((name, index) => [name, base + (index < remainder ? 1 : 0)]));
}

/** Net balance per person: positive means others owe them money. */
export function balances(expenses: Expense[]): Map<string, number> {
  const result = new Map<string, number>();
  const add = (name: string, cents: number) => result.set(name, (result.get(name) ?? 0) + cents);
  for (const expense of expenses) {
    add(expense.payer, expense.amountCents);
    for (const [name, share] of shares(expense.amountCents, expense.participants)) {
      add(name, -share);
    }
  }
  return result;
}

/**
 * Who pays whom so that everyone ends up even.
 * Greedy matching of the largest debtor with the largest creditor needs at most n - 1 transfers.
 */
export function settle(expenses: Expense[]): Transfer[] {
  const byAmount = (a: [string, number], b: [string, number]) =>
    b[1] - a[1] || a[0].localeCompare(b[0]);
  const entries = [...balances(expenses)];
  const creditors = entries.filter(([, cents]) => cents > 0).sort(byAmount);
  const debtors = entries
    .filter(([, cents]) => cents < 0)
    .map(([name, cents]): [string, number] => [name, -cents])
    .sort(byAmount);

  const transfers: Transfer[] = [];
  let c = 0;
  let d = 0;
  while (c < creditors.length && d < debtors.length) {
    const amountCents = Math.min(creditors[c][1], debtors[d][1]);
    transfers.push({ from: debtors[d][0], to: creditors[c][0], amountCents });
    creditors[c][1] -= amountCents;
    debtors[d][1] -= amountCents;
    if (creditors[c][1] === 0) c++;
    if (debtors[d][1] === 0) d++;
  }
  return transfers;
}
