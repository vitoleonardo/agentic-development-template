---
name: ship-feature
description: Run a feature end to end - spec, plan, test-first build, simplify, independent review, verify with an evidence pack, PR description - with approval gates (KIT_APPROVAL). Use when the user asks to build or ship a feature. Resumes from the state file.
argument-hint: <feature idea or existing feature name>
---

# Ship a feature

Feature: $ARGUMENTS

You orchestrate: subagents implement in fresh contexts; you own the gates, the state file and the outcome.

## Approval gates

Run `.claude/bin/gate level` once and tell the user the level. Every gate below runs `.claude/bin/gate <name>` first. `ask`: stop and ask. `auto`: decide, add one line under Decisions to review in the state file, and continue. Failure stops (retries, review rounds, the budget, the `spec` and `env` classes) ask at every level; verify rounds ask when `.claude/bin/gate round` says so.

## 0. Resume or start

Run `git branch --show-current`. If `.work/<branch>.md` exists, continue at the first open step in its Progress section; do not redo finished ones. Otherwise start at step 1.

Run `.claude/bin/route check`. If it warns that `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is set, tell the user every subagent will run on one model and the tiers are ignored.

**Model routing.** Every dispatch passes the Agent tool's `model` from `.claude/bin/route`: `route explore` for `Explore`, `route <tier>` for an implementer (the task's Tier column), `route tests` for the `test-writer`, `route review` for the `reviewer`. Put the task number and step in the dispatch description (`task 3: invite form`, `task 3 retry deep: invite form`, `review round 2`); the usage record maps agents to tasks through it. When the usage hook blocks a dispatch because `KIT_BUDGET_TOKENS` is used up, stop and ask.

## 1. Spec (gate: spec)

If the feature has no approved spec, follow `${CLAUDE_SKILL_DIR}/../spec-feature/SKILL.md`. Do not continue until it is approved.

## 2. Plan (gate: plan)

Follow `${CLAUDE_SKILL_DIR}/../plan-feature/SKILL.md` until the plan is approved. On the base branch: create the branch (`git checkout -b <issue>-<slug>`), move the state file to the branch name if it differs, and run `.claude/bin/usage adopt <the branch you started on>` so the spec and plan tokens count for this feature. On a branch already made for this feature (`.claude/bin/autopilot` creates it before planning), keep it. Either way, write the branch into the feature's Branch column in `specs/README.md`.

Then decide the base once for the run and write `Base: <branch>` under the plan's title: `KIT_BASE` if set, else the open PR's base (`gh pr view --json baseRefName --jq .baseRefName`), else the branch you started on when it is not `main` (a stacked feature), else `main`. Review, verify, the PR and the kit's scripts all read it from the state file.

If the plan gate asked, suggest the user runs `/clear` and then `/ship-feature` again: it resumes at step 3 without the interview and exploration in context.

## 3. Build, one task at a time

For each task in the plan's order:

1. Dispatch the `implementer` on the task's tier with the spec path, the state file path (its Notes hold what earlier tasks left), the task row, its criteria, the test cases and the `path:line` anchors from planning. For a UI task, tell it to check its screenshots (its agent file says how). It shares none of your context, so be complete. One task at a time: implementers share the working tree and the edit hooks.
2. Check what it returns: every criterion needs a red and a green run. Run `.claude/bin/check typecheck` and `.claude/bin/check test-related <files>` yourself. For a UI task, open two images from its screenshot folder. Do not take its word for it.
3. Update the state file: tick the task in Progress, add the evidence to the Verify log, and add one or two lines to Notes: deviations, open issues, and any new helper or interface a later task needs (`path:line`).
4. Commit the task (gate: commit), so every finished task is a safe point to stop. With the first task, set the feature's status in `specs/README.md` from `planned` to `building` and commit it with that task.

If a task fails its checks once, dispatch it again one tier higher (`.claude/bin/route up <tier>`; deep stays deep) and say so in the description (`task 3 retry deep: ...`). If it fails again, stop and ask. If the implementer reports that the spec is wrong, stop and ask; never change an approved spec on your own.

## 4. Simplify

Run `.claude/bin/check duplicates` and `.claude/bin/check similar`; keep their clone lists that touch files changed on this branch. Dispatch the `implementer` (`model` from `.claude/bin/route implement`, description `simplify`) with the base branch, the state file path, those lists as its worklist, and this task: in code changed on this branch only, replace each listed copy with the existing code (or move both into the shared home of `.claude/rules/structure.md`), remove dead code, needless abstraction and leftover debug output, change no behaviour or tests, and run the related tests. A "not configured" check gives no list; the simplifier then looks for duplication itself. Check and commit its result as for any task.

## 5. Independent review

Dispatch the `reviewer` (description `review round <n>`, `model` from `.claude/bin/route review`, never below the highest tier an implementer used on this branch) with the state file's Base and the same instruction as `/review-diff`: review the diff against the spec and the rules. If the diff changes UI and `KIT_SCREENSHOTS` is set, first run `EVIDENCE_DIR=.work/<branch>/review-<n> .claude/bin/evidence screenshots --no-base` and give it that folder too: wording, missing items and layout that hides content are found here, not at verify. Fix every high finding through the implementer, then review again. After two rounds with open high findings, stop and ask.

Round 1 reviews the full diff. For a later round run `.claude/bin/evidence scope <the commit the previous round reviewed>`. `delta <range>`: give the reviewer the previous round's findings and that range. `full: <reason>` (fixes over 20% of the diff, or a file in `KIT_CONTRACT_PATTERNS`): review the full diff again. Record every round under `## Rounds` in the state file: `- review <n> | <full|delta> | <commit range> | <high findings, or pass>`.

## 6. Verify

Follow `${CLAUDE_SKILL_DIR}/../verify-feature/SKILL.md`. If verify fails, classify each failure as its Rounds section says and run `.claude/bin/gate round <class> <n>` (n: this branch's failed verify rounds of that class). `ask`: stop and ask. `auto`: fix it as the class says, log the round under Decisions to review, and verify again. Pushing the pack is gate push.

## 7. PR (gate: push)

Follow `${CLAUDE_SKILL_DIR}/../pr-description/SKILL.md`; it ends with gate push. The description is a file in `.work/`; write it without asking. Commit nothing now: the run record was committed in step 6, before the pack. The feature stays `in-review` until the user marks it `done`.

Finally, report in at most eight lines: branch, commits, review verdict, checks, decisions made at `auto` gates, and anything left open. State a skipped check or an unmet criterion plainly.

## When something does not work

The only automatic recovery: one retry a tier higher, two review rounds, the verify rounds `gate round` allows, and a stop at every level when the same failure came back after two fixes. Every retry and stop, including a review round with open high findings and a failed verify round, gets one line under Stops in the state file:

`- <step> | <class> | <trigger> | <what was tried> | <resolution>`

Start the resolution with `user:` when the run waited for the user (`user: dropped AC4`); `/improve-kit` counts those as interventions.

Pick the class by the cause, not the symptom:

- `spec`: the spec is wrong, unclear or untestable. Stop and ask. Once the user has decided, amend it through `${CLAUDE_SKILL_DIR}/../spec-feature/SKILL.md` (new criterion IDs or a `removed` mark, a Decisions entry, `spec-lint`, approval again), update the affected tasks, and continue.
- `plan`: a task is too big, in the wrong order, or misses an anchor. Propose the plan change; continue once the user approves.
- `tier`: the model was too weak. Retry a tier higher as in step 3.
- `test`: a test or its setup is flaky or tests the wrong thing. Dispatch the `test-writer`; never weaken the test.
- `hotfix`: the product is wrong while the spec stays as written. The implementer writes a red test first, then the fix.
- `kit`: a hook, the guard, a check command or a rule is wrong, too slow, or blocks something harmless. Never edit `.claude/` to get past it; ask the user, and write your proposed fix into the resolution. In verify, its Rounds section applies.
- `env`: a dependency, the network, credentials or a human-only step. Ask, and add it to the plan's Human-only steps.
- `budget`: the token budget blocked a dispatch. Ask whether to raise it or stop.
