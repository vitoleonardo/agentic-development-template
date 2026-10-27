---
name: pr-description
description: Write a pull request description from the diff, the spec, the verify log and the evidence pack - what, why, how it was tested, and how to review it in five minutes. Does not push or open the PR.
argument-hint: [base branch, default main]
disable-model-invocation: true
---

# Write the PR description

Base branch: $ARGUMENTS (use `main` if empty).

Read `git diff <base>...HEAD`, `git log <base>..HEAD`, the feature's spec (find it through the Branch column in `specs/README.md`), `.work/<branch>.md`, and the evidence pack in `.work/<branch>/evidence/` (`evidence.json`, `gates.md`, `matrix.tsv`, `data-runs.md`, `screenshots-review.md`). If `evidence.json` names another commit than `HEAD`, say that the pack is stale and that `/verify-feature` must run again; do not use it.

Write:

```markdown
<Title: imperative, at most 72 characters>

## What
<Two to four sentences on what changes for users.>

## Why
<The problem, and a link to specs/<feature>.md.>

## How it was tested
| Criterion | Tests | Edge cases | Seeded | Mocked | Screenshots |
|-----------|-------|------------|--------|--------|-------------|
| INVITE-AC1 | <test names> | 4 of 4 | pass | n/a | INVITE-AC1-1-desktop.png |

<Gates from evidence.json: each gate and its result, n/a with its reason. Legacy and flaky tests by name.>

## How to review this PR in 5 minutes
1. <The two or three screenshots that show the change, base next to branch.>
2. <The edge cases that are new in this PR.>
3. <What the reviewer agent flagged as medium, and why it was left.>

## Risks and rollout
<Migrations, feature flags, config the deployment needs, human-only steps.>

## Cost
<The line from `.claude/bin/usage line`, if the branch has a usage record.>

## Notes for reviewers
<Where to start reading; anything deliberately left out.>
```

Rules:

- Take the evidence from `evidence.json`, the verify log and the test names. If a criterion has no test, or no recorded red run, say so in its row. Never fill a gap with a claim.
- Without an evidence pack, the table has the columns Criterion, Test and Result, and the PR says that verify did not run.
- The screenshots appear in CI's sticky comment; name the files here, do not try to attach them.
- Keep it short. No list of every file.

Save it to `.work/<branch>-pr.md` and show it. Do not push or create the PR yourself. Offer the command `gh pr create --base <base> --title "<title>" --body-file .work/<branch>-pr.md` for the user to approve.
