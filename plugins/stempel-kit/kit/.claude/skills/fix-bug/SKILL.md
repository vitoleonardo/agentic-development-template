---
name: fix-bug
description: Fix a reported bug test-first - the report becomes one to three criteria in the plan (the spec's own criterion when one exists), the test-writer writes the red test, the implementer the fix, then independent review, verify and the PR description. Use when the user reports a bug, names an issue or a failing test. Never writes a feature spec, never changes an approved spec on its own, never sets a feature's status.
argument-hint: <bug report, issue number or URL, or failing test name>
---

# Fix a bug

Report: $ARGUMENTS

You orchestrate. Subagents write the test and the fix in fresh contexts; you own the gates, the state file and the outcome. A fix is a feature with a smaller plan: no spec interview, two tasks, one commit, the same review, verify and PR.

## Approval gates

Run `.claude/bin/gate level` once and tell the user the level. Every gate below runs `.claude/bin/gate <name>` first. `ask`: stop and ask, as written. `auto`: decide, add one line under Decisions to review in the state file, and continue. Failure stops (retries, review rounds, the budget, the `spec` and `env` classes) ask at every level; verify rounds ask when `.claude/bin/gate round` says so.

If stempel-kit-routing is installed, run `.claude/bin/usage adopt <the branch you started on>` right after creating the branch in step 3, so the tokens spent before it count for this fix.

**Dispatch descriptions.** Put the task and the step in each dispatch's description (`task 1: reproduce <slug>`, `task 2: fix <slug>`, `task 2 retry deep: fix <slug>`, `review round 1`).

If stempel-kit-routing is installed, every dispatch passes the Agent tool's `model` parameter from `.claude/bin/route`: `route tests` for the `test-writer` (task 1), `route <tier>` for the `implementer` (task 2, the row's Tier), `route review` for the `reviewer`, never below the tier the implementer used. The usage record maps agents to tasks through the descriptions. Without it, every agent runs on the session's model.

## 0. Resume or start

Run `git branch --show-current`. If `.work/<branch>.md` exists and has a `## Bug` section, this fix is in progress: read its Progress section and continue at the first open step, leave `## Bug` as it is, and do not redo finished steps. Otherwise start at step 1.

## 1. Read the report

- Pasted text: take it as it is.
- An issue number or URL: run `gh issue view <n> --json title,body,url` (it asks once; `gh` needs a login). If `gh` fails, show its error and ask for the report as text.
- The name of a failing test: run `.claude/bin/check test-related <its file>` and keep the one-line failure. That test is the red test; task 1 names it instead of writing one.

Write down, for the plan: the source (issue URL, `pasted report`, or `failing test <name>`), how to reproduce it, what was expected, what happens (the exact message or value). Ask when the report does not say how to reproduce the bug.

## 2. Find the contract

Read `specs/README.md` and the specs of the features the report touches. Decide which case this is:

- **Covered**: a criterion of a listed spec says what should happen and the code contradicts it. Reuse that criterion: its ID, its text. The spec is not changed.
- **Gap**: a listed spec covers the feature, but no criterion states this behaviour. Add exactly one criterion to that spec, continuing its numbering (`<PREFIX>-AC<highest + 1>`, under Edge cases when it is one), with a Decisions entry that names the report; follow the format in `${CLAUDE_SKILL_DIR}/../spec-feature/SKILL.md`, run `.claude/bin/spec-lint specs/<feature>.md`, then `.claude/bin/gate spec` (`ask`: stop until the user approves the criterion). A bug that needs more than one new criterion is a feature: stop and propose `/spec-feature`.
- **Unspecified**: no spec covers the area. The criteria live in the plan only, with a prefix no spec uses (`LOGINFIX` for a login bug; check every `ID prefix:` line).

If the feature's row in `specs/README.md` is `building` or `in-review` on another branch, write no plan: tell the user that branch is still open and that the fix belongs there.

Then write the criteria: one to three lines of `- **<ID>**: Given <state>, when <action>, then <observable result>.`, each one yes/no check that the red test can show. A covered bug has one, the spec's own.

## 3. Plan (gate: plan)

Create the branch when you are on the base branch: `<issue>-<slug>` for an issue, else `fix-<slug>` (never a spec's file name: a branch named like a feature would match that feature's row in `specs/README.md`). Write `.work/<branch>.md`:

```markdown
# Plan: <slug> (fix)          or, for a covered or gap bug: # Plan: <slug> (spec: specs/<feature>.md)
Base: <branch>

## Bug
- Source: <issue URL | pasted report | failing test <name>>
- Reproduce: <steps or input>
- Expected: <what the criterion says>
- Observed: <what happens, exact message>

## Criteria
- **<PREFIX>-AC1**: Given <state>, when <action>, then <observable result>.

## Design
- Cause: <path:line and why>
- Side effects: <none, or each write and external call the fix changes>
- Reused: <what you searched for, with path:line>
- Approved dependencies: none

## Tasks
| # | Task | Files | Criteria | Test cases | Depends on | Tier |
|---|------|-------|----------|------------|------------|------|
| 1 | reproduce | <test file> | <IDs> | <test file>: <ID>: <case> | – | – |
| 2 | fix | <source files> | <IDs> | the tests of task 1 pass | 1 | standard |

## Progress
- [ ] 1 reproduce
- [ ] 2 fix

## Verify log
| Criterion | Test | Red seen | Green | Notes |
|-----------|------|----------|-------|-------|

## Stops
- <step> | <class> | <trigger> | <what was tried> | <resolution>

## Rounds
- <review|verify> <n> | <full|delta> | <commit range> | <pass, or fail: <classes>>

## Decisions to review
- <gate> | <what was decided> | <why>

## Notes
- <What the fix changed that a later reader needs: path:line.>
```

`Base:` as in `/ship-feature`: `KIT_BASE` if set, else the open PR's base, else the branch you started on when it is not `main`, else `main`. The cause is a `path:line` you have read, not a guess; if you cannot find it, say so in the plan and let task 1 find it. Raise task 2 to `deep` with a `Task 2 deep: <reason>` line under the table when the fix touches auth, money, migrations or concurrency. The test file goes to the home of its kind in `.claude/rules/structure.md`.

Run `.claude/bin/plan-lint .work/<branch>.md` and fix every finding. This is a hard gate: never ask for approval while it fails.

Then summarise the bug, the criteria and the cause in five lines and run `.claude/bin/gate plan`. `ask`: stop and wait. `auto`: log the approval under Decisions to review. The feature list is not touched: a fix has no row, and the feature's Status and Branch stay as they are.

## 4. Reproduce (task 1)

Dispatch the `test-writer` (description `task 1: reproduce <slug>`) with the state file path, the criteria, the test file and the `## Bug` section. Its job: one test per criterion, named with the ID, that fails for the reported reason; or, when the report names a failing test, run that test and report its failure. It shares none of your context, so be complete.

Check what it returns:

- Every test failed, and the failure is the bug (the observed value or message, not a typo or an import error). Add a Verify log row per criterion with `Red seen` filled, tick task 1.
- A test passed without ever failing: no fix is dispatched. Write a Stops line of class `test` and ask the user: the report may describe the spec's own behaviour (then it is class `spec`, see below), or the test does not reach the bug.
- The reproduction shows the behaviour the spec's criterion states: the report contradicts the spec. Write a Stops line of class `spec`, change no spec, and ask.
- The test-writer says the code needs a change to be testable: stop with a Stops line of class `plan` and propose the change; the user decides.

## 5. Fix (task 2, gate: commit)

Dispatch the `implementer` (description `task 2: fix <slug>`) with the state file path, the task row, the red test's file and its failure message, and the cause from the plan. It runs the red test, confirms it still fails for that reason, writes the smallest change that makes it pass, and never changes the test.

Check what it returns. Run `.claude/bin/check typecheck` and `.claude/bin/check test-related <the test file and the changed files>` yourself. Do not take its word for it.

If the checks fail once, dispatch task 2 again with the description `task 2 retry <tier>: fix <slug>`, and write a Stops line of class `tier`.

If stempel-kit-routing is installed, the retry runs one tier higher (`.claude/bin/route up <tier>`; a deep task stays on deep).

If it fails again, stop and ask the user. If the implementer reports that the criterion is wrong, that is class `spec`: stop and ask; never change an approved spec on your own.

When the checks pass: fill the Green cell of the Verify log rows, tick task 2, add one line to Notes (`path:line` of the fix), and commit the test and the fix in one commit (gate commit): the test alone would leave the branch red. Simplify is skipped: a fix touches two files, and the reviewer runs `.claude/bin/check similar` on them.

## 6. Independent review

Dispatch the `reviewer` agent with the Agent tool (description `review round <n>`) and the same instructions as `/review-diff`: the state file's Base, and that it reviews the diff against the plan's `## Criteria` (and the spec the title names) and the rules. Fix every high finding through the implementer (task 2 again, same description with the round), then review again. Rounds, delta reviews and the stop after two rounds with open high findings are as in "Independent review" of `/ship-feature`; record every round under `## Rounds`.

If stempel-kit-evidence is installed, the diff changes UI and `KIT_SCREENSHOTS` is set, first run `EVIDENCE_DIR=.work/<branch>/review-<n> .claude/bin/evidence screenshots --no-base` and give the reviewer that folder with the diff.

## 7. Verify

Run the checks of "Verify" in `/ship-feature`. If one fails, classify every failure as in "Verify failures" of `/ship-feature`; the product being wrong is `hotfix`, and `.claude/bin/gate round hotfix <n>` (n counts this branch's failed verify rounds of that class) says whether to ask or to fix and verify again.

If stempel-kit-evidence is installed, follow `${CLAUDE_SKILL_DIR}/../verify-feature/SKILL.md` instead: hard gates, data runs, edge-case matrix, screenshots, and the evidence pack. It reads the criteria from the plan's `## Criteria`, and it leaves `specs/README.md` alone because no row names this branch. Pushing the pack is gate push.

## 8. PR (gate: push)

Follow `${CLAUDE_SKILL_DIR}/../pr-description/SKILL.md`. The Why links the report's source (the issue URL, or the `## Bug` section's source), not a spec. The description is a file in `.work/`, so write it without asking; pushing and creating the PR are gate push.

Finally, report in at most six lines: the branch, the commit, the red test and what it showed, the review verdict, the checks, and anything left open.

## When something does not work

The classes, the Stops line format and the recovery rules are those of `/ship-feature` ("When something does not work"): one retry a tier higher, two review rounds, the verify rounds `gate round` allows, then a stop. Every stop gets one line under Stops: `- <step> | <class> | <trigger> | <what was tried> | <resolution>`. A report that turns out to describe the spec's own behaviour is class `spec` and always asks; a report that asks for new behaviour is a feature, not a fix.
