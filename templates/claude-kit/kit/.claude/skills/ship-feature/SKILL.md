---
name: ship-feature
description: Run a feature end to end - spec, plan, test-first build in fresh subagent contexts, independent review, PR description - with approval gates after the spec, after the plan and before anything is pushed. Resumes from the state file after a break.
argument-hint: <feature idea or existing feature name>
disable-model-invocation: true
---

# Ship a feature

Feature: $ARGUMENTS

You orchestrate. Subagents do the implementation in fresh contexts; you own the gates, the state file and the outcome.

## 0. Resume or start

Run `git branch --show-current`. If `.work/<branch>.md` exists, read its Progress section and continue at the first open step; do not redo finished ones. Otherwise start at step 1.

## 1. Spec (gate: user approves)

If the feature has no approved spec, follow `.claude/skills/spec-feature/SKILL.md`. Do not continue until the user approves the spec.

## 2. Plan (gate: user approves)

Follow `.claude/skills/plan-feature/SKILL.md` and wait for approval. Then create the branch (`git checkout -b <issue>-<slug>`) and move the state file to the branch name if it differs.

## 3. Build, one task at a time

For each task in the plan's order:

1. Dispatch the `implementer` subagent. Give it the spec path, the state file path, the task row, its criteria, the test cases and the `path:line` anchors from planning. It shares none of your context, so be complete. Tasks marked parallel with disjoint files may run at the same time.
2. Check what it returns. Every criterion needs a red run and a green run. Run `.claude/bin/check typecheck` and `.claude/bin/check test-related <files>` yourself. Do not take its word for it.
3. Update the state file: tick the task in Progress, and add the evidence to the Verify log.
4. Commit the task (one logical change per commit), so every finished task is a safe point to stop.

If a task fails its checks twice, stop and ask the user. If the implementer reports that the spec is wrong, stop and ask; never change an approved spec on your own.

Model choice: implementers inherit the session model. For a task that copies an existing pattern one to one, you may pass a cheaper model.

## 4. Simplify

Go over the changed code only: remove duplication with existing helpers, dead code, needless abstraction and leftover debug output. Do not change behaviour. Run the related tests again.

## 5. Independent review

Run `/review-diff`. It uses the read-only reviewer in a fresh context. Fix every high finding through the implementer, then review again. After two review rounds with open high findings, stop and ask the user.

## 6. Full verification

Run `.claude/bin/check typecheck`, `lint`, `test` and `build`. Every check must pass, and the test run must execute more than zero tests. Report any check that is not configured.

## 7. PR (gate: user approves the push)

Follow `.claude/skills/pr-description/SKILL.md`. Set the feature's status in `specs/README.md` to `in-review`. Ask before `git push` and before creating the PR. The feature stays `in-review` until the user has checked it and marks it `done` themselves.

Finally, report the branch, the commits, the review verdict, the checks, and anything left open. Be faithful: a skipped check or an unmet criterion is stated plainly.
