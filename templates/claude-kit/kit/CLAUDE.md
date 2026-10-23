# Project guide for Claude

Rules in `.claude/rules/` load automatically. Stack rules from the adapter load when you touch matching files.

## Project facts

<!-- Fill this in once per project. Keep it to facts; it describes the current state, not history. -->

- Product: <one sentence: who uses it and what problem it solves>
- Stack: <framework, database, auth, hosting>
- Install and dev server: `<install command>`, `<dev server command>`
- Checks: always run them through `.claude/bin/check <typecheck|lint|test|test-related|coverage|format|build> [files]`. The stack adapter defines each one in `.claude/kit.conf`; a check that reports "not configured" does not exist in this project. Never invent commands.
- What CI runs on every PR: <the workflow file and its checks>
- Things only a human can do: <dashboards, API keys, DNS, third-party accounts>

## How work flows here

Every feature goes through the same steps. Each step leaves a file behind, so a new session can pick up without the chat history.

1. **Spec** (`/spec-feature`): `specs/<feature>.md` states what "done" means as numbered acceptance criteria (`<FEATURE>-AC<n>`). One feature, one spec; extend it instead of creating a second one. A human approves it.
2. **Plan** (`/plan-feature`): files touched, tests, risks, and which criterion each step covers. A human approves it before any code is written.
3. **Build**: implement against the plan. Every criterion gets a test that failed before the code made it pass. Progress and evidence go to `.work/<branch>.md`.
4. **Review** (`/review-diff`): an independent reviewer that did not write the code checks the diff against the spec and these rules.
5. **PR** (`/pr-description`): what, why, and an evidence table (criterion → test → result).

`/ship-feature` runs all five steps with the approval gates. Small fixes can skip the spec but not the test.

Where things live:

- `specs/README.md`: one row per feature with its current status. Update the row when the status changes; it is not a log.
- `specs/<feature>.md`: the contract. Do not change it during the build. If it is wrong, stop and say so.
- `.work/`: plan progress and verify logs. Gitignored, never committed.

## Working agreements

- When a session starts on existing work, read `specs/README.md` and the matching `.work/<branch>.md` before doing anything else.
- Ask before deciding anything the code and the spec cannot answer. Do not fill gaps silently.
- Report faithfully: a skipped test, an unmet criterion, a red build or a check you did not run is stated plainly. "Build passed" is not "verified".
- Never edit the rules, hooks or settings in `.claude/` to make a check pass. Propose the change and wait for approval.
- Stop and ask when the same fix has failed twice. Explain what you tried and what you think is wrong.
