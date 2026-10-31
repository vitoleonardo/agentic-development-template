---
name: verify-feature
description: Prove a reviewed branch before its PR - hard gates, an edge-case matrix with a passing test per case, seeded and mocked data runs, screenshots on the branch and the base checked against the criteria - and push the evidence pack for CI. Runs after the last review round with no high findings.
argument-hint: [base branch, default the state file's Base, else main]
---

# Verify a feature

Base branch: $ARGUMENTS (if empty: the `Base:` line of `.work/<branch>.md`, which `/ship-feature` writes, else `main`). The kit's scripts read the same line; set `KIT_BASE` only when the argument differs from it.

Review finds problems in the code; verify proves the behaviour, with artefacts a human can check in minutes. The pack goes to `.work/<branch>/evidence/`. `.claude/bin/evidence` decides everything a script can decide; you write only the matrix and the screenshot judgement, and you never edit what the script wrote.

## 0. Preconditions

- The last `/review-diff` round has no high findings. Copy its report to `.work/<branch>/evidence/review.md`.
- Every task is committed. Then set the feature's status in `specs/README.md` to `in-review`, run `.claude/bin/runs record` (with `KIT_IMPROVE` on it writes `reports/runs/<branch>.tsv` for `/improve-kit`; off, it writes nothing), and commit the status and the record together, before the gates: the pack is valid only for the commit it was made on, so nothing may be committed after it. Any later commit, even a typo fix, makes it stale, and verify must run again.
- The working tree is clean.
- Read the spec (`specs/<feature>.md`) and the plan (`.work/<branch>.md`), including its test cases and its `Approved dependencies` line.

## 1. Hard gates

Run `.claude/bin/evidence gates`. All must pass; there is no soft mode. It runs typecheck, lint, build, the full test suite and coverage against the baseline, the duplicates check, the structure check, the focus and skip scan, the dependency check against the plan, protected paths, the secret scan and the diff size. A gate with an empty key in `kit.conf` fails; a check the project cannot have says `n/a: <reason>` there.

If a gate fails, stop and classify the failure as in Rounds below. Do not fix it here.

## 2. Data runs

Run `.claude/bin/evidence data`. It runs `KIT_SEED` and then `KIT_E2E` against the seeded data, and `KIT_TEST_MOCKED` with external dependencies replaced, and records the seed version and the mock set. A run that is `not configured` or `n/a` is recorded as such; say so in the report, because a reviewer must see what was not checked.

The e2e run covers only the tests the change affects when `KIT_E2E_RELATED` is set: the changed e2e files and the ones that name this feature's criteria. Its row says what ran and why (`related: …`, `all: …`, or `n/a` when only tests and docs changed). Report that line as it is. Do not pass `--all` to make a selection go away; the whole suite runs in CI after the merge.

With `KIT_E2E_REPORT` set, the e2e run's JUnit results go into the pack's `tests.tsv`, so the matrix can name e2e tests too.

## 3. Edge-case matrix

Write `.work/<branch>/evidence/edge-cases.md` with one table:

```markdown
| Criterion | Case | Input | Expected | Test | Result |
|-----------|------|-------|----------|------|--------|
| SPLIT-AC7 | empty data | no expenses | error, no total | SPLIT-AC7: no total without expenses | |
```

- Rows: for each criterion, the plan's test cases plus the reviewer's checklist: errors, empty data, duplicates, double submits, missing permissions, limits, concurrent edits.
- Test: the test's title (or the distinctive part of it) exactly as it appears in the test file, a unit or an e2e test. A case that cannot apply gets `n/a: <one-line reason>` in the Test cell.
- Leave Result empty; the script fills it in.

Run `.claude/bin/evidence matrix`. A case without a passing test is a failure, not a note. For each one, dispatch the `test-writer` (`model` from `.claude/bin/route tests`) with the criterion, the case and the files; it adds tests and does not change code. A new test that fails shows missing behaviour: that goes through the implementer and review, not here. Then run `evidence gates`, `evidence data` (if a new test is an e2e test) and `evidence matrix` again.

## 4. Screenshots

Run `.claude/bin/evidence screenshots`. It runs `KIT_SCREENSHOTS` (with the same selection as the e2e run) on the branch and, in a worktree, on the base, so each step has `<AC-ID>-<step>-<desktop|mobile>.png` and, where the page exists on the base, a `.main.png` next to it. The base run gets the variables of `KIT_BASE_ENV`. When no e2e test on the base names this feature, it is skipped and recorded as `n/a: base has no <FEATURE>`, which is not a failure. A criterion without UI has no screenshots.

Then dispatch the `reviewer` (Agent tool, description `review screenshots`, `model` from `.claude/bin/route review`) with: the spec path, the screenshot folder, and the instruction to check the screenshots as described in its agent file. Save its report to `.work/<branch>/evidence/screenshots-review.md`. A mismatch between an image and the criterion text is a high finding: verify fails, and the fix goes through the implementer and review. The implementer and the review round have judged these flows already, so this check confirms them at the final commit. A finding here is one they missed: mark the round `(screenshots)` under Rounds, so `/improve-kit` can count it.

## 5. Pack and push

1. `.claude/bin/evidence json`. It refuses a dirty tree.
2. Show the user the gate table, the matrix summary, the data runs, the screenshots and the reviewer's verdict. Keep it short (`.claude/rules/output.md`).
3. Run `.claude/bin/gate push`: with `ask`, ask before pushing; with `auto`, log it under Decisions to review. Then `.claude/bin/evidence push` (or `--pr <number>` once the PR exists). It pushes the pack to the `kit-evidence` branch under `<pr-N|branch>/<head sha>/` and leaves the current branch alone. CI's `evidence` job fails for a head commit without a pack.

## Rounds

Record every round under `## Rounds` in `.work/<branch>.md`: `- verify <n> | <full|delta> | <commit range> | pass` or `fail: <classes>`, with `(screenshots)` when the screenshot review found it.

If verify fails, classify each failure by its cause:

- `kit`: a false positive of the kit (the check is wrong, not the code). Not a verify round. Fix it in the kit's narrow way or log it, as `/ship-feature` describes; never relax a threshold or a strict path.
- `test`: the test or the test setup is wrong. The `test-writer` fixes it; the product code stays.
- `hotfix`: the product is wrong and the spec stays as written. Implementer with a red test, then review, then verify.
- `spec`: the criterion has to change. Always stop and ask.

A failed round reruns only what failed: `.claude/bin/evidence gates --only <the failed gates>`, the screenshot flow of the fix, and the e2e cases of the fix (`evidence data` already selects them). Record it as `delta` under Rounds. Only the full run at the final commit builds the pack: `evidence json` refuses gates that ran with `--only`.

Then run `.claude/bin/gate round <class> <n>` (n: the failed verify rounds of that class so far). `ask`: stop and ask the user, explaining what failed, what was tried, and what you think is wrong. `auto`: continue, and log the round under Decisions to review. Stop at any level when the same failure came back after two fixes.

Report faithfully: a gate that is `n/a`, a data run that is not configured, a screenshot the reviewer could not judge, or a pack that was not pushed is stated plainly.
