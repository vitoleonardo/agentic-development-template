---
name: ship-feature
description: Run a feature end to end - spec and plan, then one fresh headless session per planned group of tasks (test-first implementation with shared context, subagents for simplify and review), then a final session for the full review, verify with an evidence pack and the PR - with approval gates after the spec, after the plan and before anything is pushed (KIT_APPROVAL decides which ones ask). Use when the user asks to build or ship a feature. Resumes from the state file after a break.
argument-hint: <feature idea or existing feature name>
---

# Ship a feature

Feature and flags: $ARGUMENTS

Three paths, chosen by the flags:

- **Neither flag:** you run the spec and the plan, then start the build (steps 0 to 3).
- **`--group <id> --tasks <n,n|none> --from <commit>`:** you are one group's session: "Group session" below.
- **`--final`:** you are the session after the last group: "Final session" below.

## Approval gates

Run `.claude/bin/gate level` once and tell the user the level. Every gate below runs `.claude/bin/gate <name>` first. `ask`: stop and ask, as written. `auto`: decide, add one line under Decisions to review in the state file, and continue. Failure stops (retries, review rounds, the budget, the `spec` and `env` classes) ask at every level; verify rounds ask when `.claude/bin/gate round` says so.

A group or final session has nobody to ask. Where this skill says to stop and ask, write the Stops line, end the session with the question as your last message, and let the build decide what happens next. `.claude/bin/autopilot` has already set the gates: the approved plan covers commits, and deps and config unless the project's config asks for them.

## 0. Resume or start

Run `.claude/bin/autopilot --ready` first.

- If `.claude/bin/autopilot` does not mention `--ready`, the project files are older than the plugin. Say to run `./install.sh <project> --update` from the kit's repository, and stop.
- Exit 1: a build is running. Print what it said and stop. Make no commit and do not ask to push.
- Exit 2: print what it said and stop. Write no spec and no plan.

Run `git branch --show-current`. If `.work/<branch>.md` exists, read its Progress section and continue at the first open step; do not redo finished ones. Otherwise start at step 1.

Run `.claude/bin/route check`. If it warns that `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is set, tell the user that every subagent will run on one model and the tiers are ignored.

**Model routing.** Every dispatch passes the Agent tool's `model` parameter from `.claude/bin/route`: `route explore` for `Explore`, `route tests` for the `test-writer`, and for the implementer and the reviewer what the sections below say. Put the step in the dispatch's description (`task 3 retry deep: invite form`, `simplify group A`, `group A review round 1`, `review round 2`), because the usage record maps agents to steps through it. The usage hook blocks a dispatch once `KIT_BUDGET_TOKENS` is used up; then stop and ask.

## 1. Spec (gate: spec)

If the feature has no approved spec, follow `${CLAUDE_SKILL_DIR}/../spec-feature/SKILL.md`. Do not continue until the spec is approved.

## 2. Plan (gate: plan)

Follow `${CLAUDE_SKILL_DIR}/../plan-feature/SKILL.md` until the plan is approved. If you are on the base branch, create the branch (`git checkout -b <issue>-<slug>`), move the state file to the branch name if it differs, and run `.claude/bin/usage adopt <the branch you started on>`, so the tokens of the spec and the plan count for this feature. If you are already on a branch made for this feature (`.claude/bin/autopilot` creates it before planning), keep it: the state file and the usage record are already there. Either way, write the branch into the feature's Branch column in `specs/README.md`.

Then decide the base once for the whole run and write it as `Base: <branch>` under the plan's title: `KIT_BASE` if it is set (`.claude/bin/autopilot` sets it for stacked branches), else the open PR's base (`gh pr view --json baseRefName --jq .baseRefName`), else the branch you started on when it is not `main` (a stacked feature), else `main`. Review, verify and the PR use this base; the kit's scripts read it from the state file, so a stacked branch never counts the earlier branches' changes as its own.

Everything the build needs is now in files.

## 3. Start the build

If the last line in Rounds that starts with `- verify ` ends with `| pass`, the evidence pack was made on this commit (`.claude/bin/status --json`), no PR exists and `.claude/bin/gate push` prints `ask`: start no session. Ask to push, and on approval do "PR" below in this session.

Otherwise commit the spec and the status row (gate: commit), because a build stashes or refuses uncommitted changes. Then run `.claude/bin/autopilot --ship <feature>`. Print the two lines it prints: the run log's path and `Do not edit this checkout until the build ends.` The build goes on if this session or the terminal closes.

Wait in the background until `.claude/bin/autopilot --ready` no longer exits with 1, then report from the run log's last lines: the closing line, the PR, and what is left to decide. `.claude/bin/autopilot --stop` ends a build. Running `/ship-feature` again continues it.

## Group session

You implement `--tasks` in this session, in plan order, so later tasks know what earlier ones did. Do not start the next group, verify or open a PR. Stay on this branch.

Read the spec, the plan, Notes and the plan's Tasks rows of this group. The diff of the group is `<--from>..HEAD`.

For each task:

1. Read the files named in the task and the anchors. Build it by the "For each criterion" steps in `${CLAUDE_SKILL_DIR}/../../agents/implementer.md`, including its screenshots step for a task that changes what a page shows, and by its rules on staying inside the task. Those rules allow a commit here: you own them.
2. Run `.claude/bin/check typecheck` and `.claude/bin/check test-related <files>`.
3. Commit the task with `task <n>` in the message (one logical change per commit, gate: commit), so every finished task is a safe point to stop. With the first task, set the feature's status in `specs/README.md` from `planned` to `building` and commit it with that task.
4. Only after the commit, tick the task in Progress, add the evidence to the Verify log (a filled Red seen and Green cell for each of its criteria), and add one or two lines to Notes: its deviations, open issues, and any new helper or interface a later group needs (`path:line`). Later groups start with nothing but these files and the commits.

If a task still fails after your second fix attempt, dispatch the `implementer` on it, one tier above this group's tier (`.claude/bin/route up <tier>`; deep stays on deep), with the description `task <n> retry <tier>: ...`. If that fails too, leave the task unticked, write a Stops line of class `tier`, and end the session. If the spec turns out to be wrong, write a Stops line of class `spec` and end the session; never change an approved spec on your own.

If the prompt holds failure output from the build's own checks, fix that first, and commit it. Do not weaken a test.

**With one group in the plan, stop here:** the final session simplifies and reviews. Leave no uncommitted changes.

With several groups, once every task is ticked:

1. Simplify the group's diff as in "Simplify", with the description `simplify group <id>`, the range `<--from>..HEAD`, and the clone lists of the group's files.
2. Dispatch the `reviewer` with the description `group <id> review round <n>`. Its `model` is this group's tier, at least standard, and deep if a task of the group was retried on deep. Give it the range `<--from>..HEAD`, this group's task rows, their criteria and their Verify log rows, and say that a criterion only in another group's tasks is not a finding.
3. Record each round under Rounds: `- group <id> review <n> | <full|delta> | <commit range> | pass`, or `<n> high open` in place of `pass`.
4. Fix every high finding yourself and commit it, then review again. After two rounds with open high findings, write a Stops line of class `hotfix`, and end the session.

If this group's last round in Rounds is not `pass`, a build stopped there: start with a full review, numbered on from that round, with at most 2 more rounds.

Leave no uncommitted changes when you end.

## Final session

Every group is done. Do the steps below in order, on the whole branch.

### Simplify

With one group in the plan, always. With several, only when the two checks below list clones in files changed on this branch: each group already simplified its own work.

Run `.claude/bin/check duplicates` and `.claude/bin/check similar` and keep their clone lists that touch files changed on this branch. Then dispatch the `implementer` (`model` from `.claude/bin/route implement`, description `simplify`), before the review, with the base branch, the state file path, those clone lists as its worklist, and this task: in the code changed on this branch only, replace each listed copy with the existing code (or move both into the shared home of `.claude/rules/structure.md`), then remove dead code, needless abstraction and leftover debug output; do not change behaviour or tests; run the related tests. A "not configured" check gives no list; the simplifier then looks for duplication itself. Check its result with `.claude/bin/check typecheck` and `.claude/bin/check test-related <files>` as for any task, and commit it.

### Independent review

Dispatch the `reviewer` agent with the Agent tool (description `review round <n>`), `model` from `.claude/bin/route review`, and the same instructions as `/review-diff`: the state file's Base, and that it reviews the diff against the spec and the rules. If the diff changes UI and `KIT_SCREENSHOTS` is set, first run `EVIDENCE_DIR=.work/<branch>/review-<n> .claude/bin/evidence screenshots --no-base` and give the reviewer that folder with the diff. Wording, a missing item, and layout that hides content are found here, not at verify. The reviewer never runs on a lower tier than the highest tier an implementer used on this branch; raise it if it would. Fix every high finding through the implementer, then review again. After two review rounds with open high findings, stop and ask the user.

Round 1 reviews the full diff. A later round reviews only what changed, when `.claude/bin/evidence scope <the commit the previous round reviewed>` prints `delta <range>`: give the reviewer the previous round's findings and that commit range. It checks that each finding is closed and reviews those commits and the criteria they touch. When `scope` prints `full: <reason>` (the fixes are more than 20% of the diff, or touch a file in `KIT_CONTRACT_PATTERNS`: auth, migrations, public routes), the round reviews the full diff again. Record every round under `## Rounds` in the state file: `- review <n> | <full|delta> | <commit range> | <high findings, or pass>`.

### Verify

Follow `${CLAUDE_SKILL_DIR}/../verify-feature/SKILL.md`: hard gates, data runs, edge-case matrix, screenshots, and the evidence pack. If verify fails, classify every failure as in "Verify failures" below and run `.claude/bin/gate round <class> <n>`, where n counts this branch's failed verify rounds of that class. `ask`: stop and ask. `auto`: fix it as the class says, log the round under Decisions to review, and verify again. Pushing the pack is gate push.

### PR (gate: push)

Follow `${CLAUDE_SKILL_DIR}/../pr-description/SKILL.md`, and add the line from `.claude/bin/usage line` (tokens per tier, review rounds, escalations). The description is a file in `.work/`, so write it without asking; it changes no commit. The run record for `/improve-kit`, if any, was committed in step 6 before the pack; do not commit anything now. Pushing and creating the PR are gate push; with `auto`, push and run `gh pr create` yourself. With `ask` in a final session, do not push: write a Stops line of class `push` and end the session; the developer approves it by running `/ship-feature` in a terminal. The feature stays `in-review` until the user has checked it and marks it `done` themselves.

Finally, report in at most eight lines: the branch, the commits, the review verdict, the checks, the decisions you made at `auto` gates, and anything left open. Be faithful: a skipped check or an unmet criterion is stated plainly.

## When something does not work

The loops in a group session and a final session are the only automatic recovery: one retry a tier higher, two review rounds per group and for the final review, the verify rounds `gate round` allows, and a stop when the same failure came back after two fixes, at every level. Every retry and every stop, including a review round with open high findings and a failed verify round, gets one line under Stops in the state file:

`- <step> | <class> | <trigger> | <what was tried> | <resolution>`

Start the resolution with `user:` when the run waited for the user to decide or do something (`user: dropped AC4`). `/improve-kit` counts those as interventions.

Pick the class by the cause, not the symptom, and fix it where it belongs:

- `spec`: the spec is wrong, unclear or untestable. Stop and ask. Once the user has decided, amend it through `${CLAUDE_SKILL_DIR}/../spec-feature/SKILL.md` (new criterion IDs or a `removed` mark, a Decisions entry, `spec-lint`, approval again), update the affected tasks, and continue.
- `plan`: a task is too big, in the wrong order, or misses an anchor. Propose the change to the plan and continue once the user approves it.
- `tier`: the model was too weak for the task. Retry a tier higher as in "Group session". A failed retry stops the build.
- `push`: verified, and the push gate asks. The final session ends without pushing.
- `test`: a test or its setup is flaky or tests the wrong thing. Dispatch the `test-writer`; never weaken the test.
- `hotfix`: the product is wrong while the spec stays as written. The implementer writes a red test first, then the fix.
- `kit`: a hook, the guard, a check command or a rule is wrong, too slow, or blocks something harmless. Never edit `.claude/` to get past it; ask the user, and write the fix you would propose into the resolution. In verify, see "Verify failures".
- `env`: a dependency, the network, credentials or a step only a human can do. Ask, and add it to the plan's Human-only steps.
- `budget`: the token budget blocked a dispatch. Ask whether to raise it or stop.

### Verify failures

A verify round that fails gets one line under `## Rounds` in the state file (`- verify <n> | <full|delta> | <commit range> | fail: <classes>`, with `(screenshots)` when the screenshot review found it), and each failure gets its class:

- `kit`: a false positive. The gate or script is wrong, not the code. It does not count as a verify round. Write a Stops line with the kit fix you propose. If the kit offers a narrow way for exactly this case (an approved fake value in `.claude/secrets-allow.tsv`, a test pattern for a test file) and `.claude/bin/gate config` is `auto`, apply it in its own commit and log it under Decisions to review; otherwise ask. Never relax a threshold, a key format, a hook or a strict path to get past it.
- `test`: the test or the test stack is wrong (a selector, timing, an auth throttle, shared Redis or database state). The `test-writer` fixes it, the product code stays as it is, and the round continues.
- `hotfix`: the product is wrong and the spec stays as written (layout, a missing state, responsive behaviour). The implementer writes a red test and the fix, then one review round on the fix, then verify.
- `spec`: the criterion itself has to change. Always stop and ask.

