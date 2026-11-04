---
name: pr-description
description: Write a pull request description from the diff, the spec, the verify log and the evidence pack - what, why, how it was tested, and how to review it in five minutes. Does not push or open the PR.
argument-hint: [base branch, default the state file's Base, else main]
---

# Write the PR description

Base branch: $ARGUMENTS (if empty: `$KIT_BASE` when it is set, else the `Base:` line of `.work/<branch>.md`, else `main`). Open the PR against it (`gh pr create --base <base>`).

Read `git diff <base>...HEAD`, `git log <base>..HEAD`, the feature's spec (find it through the Branch column in `specs/README.md`, or, when no row names the branch, through the title of `.work/<branch>.md`; a fix's criteria are its `## Criteria`), `.work/<branch>.md`, and the evidence pack in `.work/<branch>/evidence/` (`evidence.json`, `gates.md`, `matrix.tsv`, `data-runs.md`, `screenshots-review.md`). If `evidence.json` names another commit than `HEAD`, say that the pack is stale and that `/verify-feature` must run again; do not use it.

Write:

```markdown
<Title: imperative, at most 72 characters>

## What
- <One to three bullets on what changes for users.>

## Why
<One line, and a link to specs/<feature>.md; for a fix, the issue URL or the `## Bug` source instead.>

## Evidence
| Criterion | Tests | Edge cases | Seeded | Mocked | Screenshots |
|-----------|-------|------------|--------|--------|-------------|
| INVITE-AC1 | <test names> | 4 of 4 | pass | n/a | INVITE-AC1-1-desktop.png |

Gates: <one line from evidence.json, n/a with its reason>. <Legacy and flaky tests by name.>

## Review
- <At most three bullets: the screenshots to compare, the new edge cases, reviewer mediums left and why. Where to start reading.>

## Risks
<Only if there are migrations, feature flags, deployment config or human-only steps.>

Cost: <the line from `.claude/bin/usage line`, only if the branch has a usage record.>
```

Rules:

- Follow `.claude/rules/output.md`. At most 150 words outside the table. Omit an empty section.
- Take the evidence from `evidence.json`, the verify log and the test names. If a criterion has no test, or no recorded red run, say so in its row. Never fill a gap with a claim.
- Without an evidence pack, the table has the columns Criterion, Test and Result, and the PR says that verify did not run.
- The screenshots appear in CI's sticky comment; name the files here, do not try to attach them.

If the state file has a Decisions to review section, copy it into the description under that heading, so the reviewer sees every decision no human approved.

## Stacked layers

Run `.claude/bin/stack layers`. It prints one line per layer, bottom to top: `<layer branch> TAB <commit> TAB <group>`. With one line, write the description above. With several, a feature built in groups becomes one pull request per group, stacked on each other (`specs/stacked-groups.md`); write one description per layer, bottom to top:

- Read the layer's own diff: `git diff <the layer below>..<its commit>`, where the first layer's below is the base.
- Title: the feature's title with `(<n>/<N>)`, n counted from the bottom.
- Evidence: only the criteria of that layer's group's tasks.
- Every layer but the top one adds under Review: `Reviewed and verified on the stack top, <branch>. Review the stack from the bottom up.`
- The top layer, the branch itself, also carries what belongs to the whole feature: Why, Risks, Decisions to review and Cost.

Save a lower layer's description to `.work/<branch>/pr/<group>.md` and the top layer's to `.work/<branch>-pr.md`.

## Open the pull requests

Show the descriptions. Then run `.claude/bin/gate push`. With `ask`, do not push or open anything yourself: offer the command `.claude/bin/stack submit` for the user to approve. With `auto`, run it. It cuts the layer branches, pushes them with their evidence packs, and opens or updates one pull request per layer: linked as a GitHub stack with `gh stack`, or as a chain of pull requests, each based on the one below, when `gh stack` is missing or stacks are off. A feature with one layer gets one pull request, as with `gh pr create --base <base>`. Report the lines it prints.
