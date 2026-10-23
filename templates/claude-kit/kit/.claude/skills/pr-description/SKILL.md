---
name: pr-description
description: Write a pull request description from the diff, the spec and the verify log - what, why, and how it was tested, with an evidence row per acceptance criterion. Does not push or open the PR.
argument-hint: [base branch, default main]
disable-model-invocation: true
---

# Write the PR description

Base branch: $ARGUMENTS (use `main` if empty).

Read `git diff <base>...HEAD`, `git log <base>..HEAD`, the feature's spec (find it through the Branch column in `specs/README.md`) and `.work/<branch>.md`.

Write:

```markdown
<Title: imperative, at most 72 characters>

## What
<Two to four sentences on what changes for users.>

## Why
<The problem, and a link to specs/<feature>.md.>

## How it was tested
| Criterion | Test | Result |
|-----------|------|--------|
| INVITE-AC1 | <test name> | pass (red seen first) |

<Commands run: typecheck, lint, tests (n tests), build.>

## Risks and rollout
<Migrations, feature flags, config the deployment needs, human-only steps.>

## Notes for reviewers
<Where to start reading; anything deliberately left out.>
```

Rules:

- Take the evidence from the verify log and the test names. If a criterion has no test, or no recorded red run, say so in its row. Never fill a gap with a claim.
- For UI changes, add a Screenshots section with what should be captured, since you cannot attach images.
- Keep it short. No list of every file.

Save it to `.work/<branch>-pr.md` and show it. Do not push or create the PR yourself. Offer the command `gh pr create --base <base> --title "<title>" --body-file .work/<branch>-pr.md` for the user to approve.
