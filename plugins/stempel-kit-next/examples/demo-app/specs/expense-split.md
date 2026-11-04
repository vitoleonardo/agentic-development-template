# Expense split

ID prefix: SPLIT

## Goal
A group that shared costs (a trip, a flat) types in who paid what for whom and sees the fewest payments that settle everything.

## User flow
1. The user opens the start page and sees one text field with an example line.
2. The user types one expense per line, for example "Alice paid 30.50 for Alice, Bob", and presses Split.
3. The page shows "Who pays whom" with one line per payment, or "Everyone is even."
4. If a line cannot be read, the page shows an error naming the line, and no payments.

## Acceptance criteria
- **SPLIT-AC1**: Given a list of expenses, when the user splits them, then the shown transfers leave every person exactly even.
- **SPLIT-AC2**: Given an amount that does not divide evenly, when it is shared, then the shares differ by at most one cent and add up to the amount.
- **SPLIT-AC5**: Given n people, when the expenses are settled, then at most n - 1 transfers are shown.
- **SPLIT-AC6**: Given lines like "Alice paid 30.50 for Alice, Bob", when the user splits, then each line counts as one expense with the amount in cents.

## Edge cases
- **SPLIT-AC3**: Given expenses where nobody owes anything, when the user splits them, then the page says "Everyone is even."
- **SPLIT-AC4**: Given invalid input (unreadable line, amount of zero or less, empty name, no expenses), when the user splits, then an error names the problem and no transfers are shown.

## Out of scope
- Currencies other than one implicit currency.
- Saving groups or expenses between visits.
- Unequal shares.

## Open questions
- None.

## Decisions
- 23.10.2026: amounts are whole cents, so rounding is exact and testable.
