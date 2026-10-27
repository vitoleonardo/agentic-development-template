---
name: ship-feature
description: Run a feature end to end - spec, plan, test-first build in fresh subagent contexts, simplify, independent review, verify with an evidence pack, PR description - with approval gates after the spec, after the plan and before anything is pushed. Resumes from the state file after a break.
argument-hint: <feature idea or existing feature name>
disable-model-invocation: true
---

# Ship a feature

Feature: $ARGUMENTS

You orchestrate. Subagents do the implementation in fresh contexts; you own the gates, the state file and the outcome.

## 0. Resume or start

Run `git branch --show-current`. If `.work/<branch>.md` exists, read its Progress section and continue at the first open step; do not redo finished ones. Otherwise start at step 1.

Run `.claude/bin/route check`. If it warns that `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is set, tell the user that every subagent will run on one model and the tiers are ignored.

**Model routing.** Every dispatch passes the Agent tool's `model` parameter from `.claude/bin/route`: `route explore` for `Explore`, `route <tier>` for an implementer (the task's Tier column), `route tests` for the `test-writer`, `route review` for the `reviewer`. Put the task number and the step in the dispatch's description (`task 3: invite form`, `task 3 retry deep: invite form`, `review round 2`), because the usage record maps agents to tasks through it. The usage hook blocks a dispatch once `KIT_BUDGET_TOKENS` is used up; then stop and ask.

## 1. Spec (gate: user approves)

If the feature has no approved spec, follow `${CLAUDE_SKILL_DIR}/../spec-feature/SKILL.md`. Do not continue until the user approves the spec.

## 2. Plan (gate: user approves)

Follow `${CLAUDE_SKILL_DIR}/../plan-feature/SKILL.md` and wait for approval. Then create the branch (`git checkout -b <issue>-<slug>`), move the state file to the branch name if it differs, and run `.claude/bin/usage adopt <the branch you started on>`, so the tokens of the spec and the plan count for this feature.

## 3. Build, one task at a time

For each task in the plan's order:

1. Dispatch the `implementer` subagent on the task's tier. Give it the spec path, the state file path, the task row, its criteria, the test cases and the `path:line` anchors from planning. It shares none of your context, so be complete. Tasks marked parallel with disjoint files may run at the same time.
2. Check what it returns. Every criterion needs a red run and a green run. Run `.claude/bin/check typecheck` and `.claude/bin/check test-related <files>` yourself. Do not take its word for it.
3. Update the state file: tick the task in Progress, and add the evidence to the Verify log.
4. Commit the task (one logical change per commit), so every finished task is a safe point to stop.

If a task fails its checks once, dispatch it again one tier higher (`.claude/bin/route up <tier>`; a deep task stays on deep) and say so in the description (`task 3 retry deep: ...`). If it fails again, stop and ask the user. If the implementer reports that the spec is wrong, stop and ask; never change an approved spec on your own.

## 4. Simplify

Go over the changed code only: remove duplication with existing helpers, dead code, needless abstraction and leftover debug output. Do not change behaviour. Run the related tests again.

## 5. Independent review

Dispatch the `reviewer` agent with the Agent tool (description `review round <n>`), `model` from `.claude/bin/route review`, and the same instructions as `/review-diff`: the base branch, and that it reviews the diff against the spec and the rules. The reviewer never runs on a lower tier than the highest tier an implementer used on this branch; raise it if it would. Fix every high finding through the implementer, then review again. After two review rounds with open high findings, stop and ask the user.

## 6. Verify

Follow `${CLAUDE_SKILL_DIR}/../verify-feature/SKILL.md`: hard gates, edge-case matrix, data runs, screenshots, and the evidence pack. If verify fails, the fix goes through the implementer and then back to step 5. After two failed verify rounds, stop and ask. Ask before pushing the pack.

## 7. PR (gate: user approves the push)

Follow `${CLAUDE_SKILL_DIR}/../pr-description/SKILL.md`, and add the line from `.claude/bin/usage line` (tokens per tier, review rounds, escalations). The description is a file in `.work/`, so write it without asking; it changes no commit. Ask before `git push` and before creating the PR. The feature stays `in-review` until the user has checked it and marks it `done` themselves.

Finally, report the branch, the commits, the review verdict, the checks, and anything left open. Be faithful: a skipped check or an unmet criterion is stated plainly.
