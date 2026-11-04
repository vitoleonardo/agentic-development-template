import { describe, expect, it } from "vitest";
import { balances, settle, shares } from "./settle";

const sum = (values: Iterable<number>) => [...values].reduce((total, value) => total + value, 0);

describe("settle", () => {
  it("SPLIT-AC1: transfers leave everyone even", () => {
    const expenses = [
      { payer: "Alice", amountCents: 9000, participants: ["Alice", "Bob", "Carol"] },
      { payer: "Bob", amountCents: 3000, participants: ["Bob", "Carol"] },
    ];
    const after = balances(expenses);
    for (const t of settle(expenses)) {
      after.set(t.from, (after.get(t.from) ?? 0) + t.amountCents);
      after.set(t.to, (after.get(t.to) ?? 0) - t.amountCents);
    }
    expect([...after.values()].every((cents) => cents === 0)).toBe(true);
  });

  it("SPLIT-AC2: uneven amounts split to the cent", () => {
    const result = shares(1000, ["Carol", "Alice", "Bob"]);
    expect([...result.values()]).toEqual([334, 333, 333]);
    expect(sum(result.values())).toBe(1000);
    expect([...result.keys()]).toEqual(["Alice", "Bob", "Carol"]);
  });

  it("SPLIT-AC2: a duplicated participant is counted once", () => {
    expect(shares(1000, ["Alice", "Alice", "Bob"])).toEqual(
      new Map([
        ["Alice", 500],
        ["Bob", 500],
      ]),
    );
  });

  it("SPLIT-AC3: nobody owes anything when everyone paid their own share", () => {
    expect(settle([{ payer: "Alice", amountCents: 500, participants: ["Alice"] }])).toEqual([]);
    expect(settle([])).toEqual([]);
  });

  it("SPLIT-AC5: needs at most one transfer fewer than there are people", () => {
    const people = ["Alice", "Bob", "Carol", "Dan", "Eve"];
    const expenses = people.map((payer, i) => ({
      payer,
      amountCents: 1000 * (i + 1),
      participants: people,
    }));
    expect(settle(expenses).length).toBeLessThanOrEqual(people.length - 1);
  });
});
