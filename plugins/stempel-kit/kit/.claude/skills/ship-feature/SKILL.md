---
name: ship-feature
description: Run a feature end to end - spec and plan, then a test-first build of every task with a red and a green run per criterion, simplify, an independent review in a fresh context, verify and the PR - with approval gates after the spec, after the plan and before anything is pushed (KIT_APPROVAL decides which ones ask). Use when the user asks to build or ship a feature. Resumes from the state file after a break.
argument-hint: <feature idea or existing feature name>
---

# Ship a feature

Feature and flags: $ARGUMENTS

Without flags you run the spec, the plan, the build, the review, verify and the PR (steps 0 to 7). The flags `--group`, `--final` and `--stack` mark a session that the extension stempel-kit-autopilot started: see "Build sessions" at the end.

## Approval gates

Run `.claude/bin/gate level` once and tell the user the level. Every gate below runs `.claude/bin/gate <name>` first. `ask`: stop and ask, as written. `auto`: decide, add one line under Decisions to review in the state file, and continue. Failure stops (retries, review rounds, the budget, the `spec` and `env` classes) ask at every level; verify rounds ask when `.claude/bin/gate round` says so.

## 0. Resume or start

Run `.claude/bin/check extensions`. It warns about a section in `kit.conf` whose extension is not installed; tell the user.

If stempel-kit-autopilot is installed, run `.claude/bin/autopilot --ready` first. If it does not mention `--ready`, the project files are older than the plugin: say to run `./install.sh <project> --update` from the kit's repository, and stop. Exit 1: a build is running; print what it said and stop, make no commit and do not ask to push. Exit 2: print what it said and stop; write no spec and no plan.

Run `git branch --show-current`. If `.work/<branch>.md` exists, read its Progress section and continue at the first open step; do not redo finished ones. Otherwise start at step 1.

**Dispatch descriptions.** Put the step in each dispatch's description (`task 3: invite form`, `simplify`, `review round 2`).

If stempel-kit-routing is installed, every dispatch passes the Agent tool's `model` parameter from `.claude/bin/route`: `route explore` for `Explore`, `route tests` for the `test-writer`, `route <tier>` for the `implementer` (the task's Tier), `route review` for the `reviewer` and the screenshot review, `route implement` for the simplifier. Run `.claude/bin/route check` first; if it warns that `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is set, tell the user that every subagent will run on one model and the tiers are ignored. The usage record maps agents to steps through the descriptions, and the usage hook blocks a dispatch once `KIT_BUDGET_TOKENS` is used up; then stop and ask.

Without it, every agent runs on the session's model.

## 1. Spec (gate: spec)

If the feature has no approved spec, follow `${CLAUDE_SKILL_DIR}/../spec-feature/SKILL.md`. Do not continue until the spec is approved.

## 2. Plan (gate: plan)

Follow `${CLAUDE_SKILL_DIR}/../plan-feature/SKILL.md` until the plan is approved. If you are on the base branch, create the branch (`git checkout -b <issue>-<slug>`) and move the state file to the branch name if it differs. If you are already on a branch made for this feature, keep it. Either way, write the branch into the feature's Branch column in `specs/README.md`.

If stempel-kit-routing is installed and you created the branch, run `.claude/bin/usage adopt <the branch you started on>`, so the tokens of the spec and the plan count for this feature.

Then decide the base once for the whole run and write it as `Base: <branch>` under the plan's title: `KIT_BASE` if it is set, else the open PR's base (`gh pr view --json baseRefName --jq .baseRefName`), else the branch you started on when it is not `main` (a stacked feature), else `main`. Review, verify and the PR use this base; the kit's scripts read it from the state file, so a stacked branch never counts the earlier branches' changes as its own.

Everything the build needs is now in files.

## 3. Build

If stempel-kit-autopilot is installed, the build runs unattended, one headless session per group of the plan. If the last line in Rounds that starts with `- verify ` ends with `| pass`, the evidence pack was made on this commit (`.claude/bin/status --json`), no PR exists and `.claude/bin/gate push` prints `ask`: start no session; ask to push, and on approval do step 7 in this session. Otherwise commit the spec and the status row (gate: commit), because a build stashes or refuses uncommitted changes, and run `.claude/bin/autopilot --ship <feature>`. Print the two lines it prints: the run log's path and `Do not edit this checkout until the build ends.` Wait in the background until `.claude/bin/autopilot --ready` no longer exits with 1, then report from the run log's last lines: the closing line, the PR, and what is left to decide. `.claude/bin/autopilot --stop` ends a build. Running `/ship-feature` again continues it. Steps 4 to 7 then run in the build's sessions, not here.

Without it, build every task in this session, in plan order, so later tasks know what earlier ones did:

1. Read the files named in the task and the anchors. Build it by the "For each criterion" steps in `${CLAUDE_SKILL_DIR}/../../agents/implementer.md`, and by its rules on staying inside the task: the test first, its red run, the smallest change, its green run. Those rules allow a commit here: you own them.
2. Run `.claude/bin/check typecheck` and `.claude/bin/check test-related <files>`.
3. Commit the task with `task <n>` in the message (one logical change per commit, gate: commit), so every finished task is a safe point to stop. With the first task, set the feature's status in `specs/README.md` from `planned` to `building` and commit it with that task.
4. Only after the commit, tick the task in Progress and add the evidence to the Verify log: per criterion the test name, the Red seen cell with the failing run's one-line message and the Green cell with the passing run. Add one or two lines to Notes: deviations, open issues, and any helper a later task needs (`path:line`).

If a task still fails after your second fix attempt, dispatch the `implementer` on it with the description `task <n> retry: ...` and write a Stops line of class `tier`. If that fails too, leave the task unticked and stop and ask. If the spec turns out to be wrong, write a Stops line of class `spec` and stop; never change an approved spec on your own.

If stempel-kit-routing is installed, that retry runs one tier above the task's Tier (`.claude/bin/route up <tier>`; deep stays on deep), with the description `task <n> retry <tier>: ...`.

## 4. Simplify

Run `.claude/bin/check duplicates` and `.claude/bin/check similar` and keep their clone lists that touch files changed on this branch. Then dispatch the `implementer` (description `simplify`), before the review, with the base branch, the state file path, those clone lists as its worklist, and this task: in the code changed on this branch only, replace each listed copy with the existing code (or move both into the shared home of `.claude/rules/structure.md`), then remove dead code, needless abstraction and leftover debug output; do not change behaviour or tests; run the related tests. A "not configured" check gives no list; the simplifier then looks for duplication itself. Check its result with `.claude/bin/check typecheck` and `.claude/bin/check test-related <files>` as for any task, and commit it.

## 5. Independent review

Dispatch the `reviewer` agent with the Agent tool (description `review round <n>`) and the same instructions as `/review-diff`: the state file's Base, and that it reviews the diff against the spec and the rules. Wording, a missing item, and layout that hides content are found here. The reviewer never runs on a lower tier than the highest tier an implementer used on this branch. Fix every high finding through the implementer, then review again. After two review rounds with open high findings, stop and ask the user. Record every round under `## Rounds` in the state file: `- review <n> | <full|delta> | <commit range> | <high findings, or pass>`.

Round 1 reviews the full diff. A later round gives the reviewer the previous round's findings and the commits since: it checks that each finding is closed and reviews those commits and the criteria they touch.

If stempel-kit-evidence is installed, a later round reviews only what changed when `.claude/bin/evidence scope <the commit the previous round reviewed>` prints `delta <range>`; when it prints `full: <reason>` (the fixes are more than 20% of the diff, or touch a file in `KIT_CONTRACT_PATTERNS`), the round reviews the full diff again. If the diff changes UI, `KIT_SCREENSHOTS` is set and `KIT_STACK_CHECKS` is `off`, first run `EVIDENCE_DIR=.work/<branch>/review-<n> .claude/bin/evidence screenshots --no-base` and give the reviewer that folder with the diff.

## 6. Verify

Run `.claude/bin/check --against-baseline typecheck`, `--against-baseline lint`, `--against-baseline test`, `.claude/bin/check build` and `.claude/bin/structure`. Record each result in the Verify log's Notes column or under Notes; "not configured" and `n/a` are recorded as such. A failure is classified as in "Verify failures" below; run `.claude/bin/gate round <class> <n>`, where n counts this branch's failed verify rounds of that class. `ask`: stop and ask. `auto`: fix it as the class says, log the round under Decisions to review, and verify again.

If stempel-kit-evidence is installed, follow `${CLAUDE_SKILL_DIR}/../verify-feature/SKILL.md` instead: hard gates, data runs, edge-case matrix, screenshots, and the evidence pack. Pushing the pack is gate push.

## 7. PR (gate: push)

Follow `${CLAUDE_SKILL_DIR}/../pr-description/SKILL.md`. The pull request body holds one line per criterion with the test name, its red run and its green run, from the Verify log.

If stempel-kit-evidence is installed, step 6 ran `/verify-feature` and the body adds its pack. Without it, write the pull request body directly from the Verify log and the checks of step 6.

The description is a file in `.work/`, so write it without asking; it changes no commit. Opening the pull request is gate push. The feature stays `in-review` until the user has checked it and marks it `done` themselves.

Finally, report in at most eight lines: the branch, the commits, the review verdict, the checks, the decisions you made at `auto` gates, and anything left open. Be faithful: a skipped check or an unmet criterion is stated plainly.

## When something does not work

The loops above are the only automatic recovery: one retry, two review rounds, the verify rounds `gate round` allows, and a stop when the same failure came back after two fixes, at every level. Every retry and every stop, including a review round with open high findings and a failed verify round, gets one line under Stops in the state file:

`- <step> | <class> | <trigger> | <what was tried> | <resolution>`

Start the resolution with `user:` when the run waited for the user to decide or do something (`user: dropped AC4`).

Pick the class by the cause, not the symptom, and fix it where it belongs:

- `spec`: the spec is wrong, unclear or untestable. Stop and ask. Once the user has decided, amend it through `${CLAUDE_SKILL_DIR}/../spec-feature/SKILL.md` (new criterion IDs or a `removed` mark, a Decisions entry, `spec-lint`, approval again), update the affected tasks, and continue.
- `plan`: a task is too big, in the wrong order, or misses an anchor. Propose the change to the plan and continue once the user approves it.
- `tier`: the model was too weak for the task. Retry as in step 3. A failed retry stops the build.
- `push`: verified, and the push gate asks. The session ends without pushing.
- `test`: a test or its setup is flaky or tests the wrong thing. Dispatch the `test-writer`; never weaken the test.
- `hotfix`: the product is wrong while the spec stays as written. The implementer writes a red test first, then the fix.
- `kit`: a hook, the guard, a check command or a rule is wrong, too slow, or blocks something harmless. Never edit `.claude/` to get past it; ask the user, and write the fix you would propose into the resolution.
- `env`: a dependency, the network, credentials or a step only a human can do. Ask, and add it to the plan's Human-only steps.
- `budget`: the token budget blocked a dispatch. Ask whether to raise it or stop.

### Verify failures

A verify round that fails gets one line under `## Rounds` in the state file (`- verify <n> | <full|delta> | <commit range> | fail: <classes>`, with `(screenshots)` when the screenshot review found it), and each failure gets its class:

- `kit`: a false positive. The gate or script is wrong, not the code. It does not count as a verify round. Write a Stops line with the kit fix you propose. If the kit offers a narrow way for exactly this case (an approved fake value in `.claude/secrets-allow.tsv`, a test pattern for a test file) and `.claude/bin/gate config` is `auto`, apply it in its own commit and log it under Decisions to review; otherwise ask. Never relax a threshold, a key format, a hook or a strict path to get past it.
- `test`: the test or the test stack is wrong (a selector, timing, an auth throttle, shared Redis or database state). The `test-writer` fixes it, the product code stays as it is, and the round continues.
- `hotfix`: the product is wrong and the spec stays as written (layout, a missing state, responsive behaviour). The implementer writes a red test and the fix, then one review round on the fix, then verify.
- `spec`: the criterion itself has to change. Always stop and ask.

## If stempel-kit-autopilot is installed: build sessions

`.claude/bin/autopilot` starts these sessions and has already set the gates: the approved plan covers commits, and deps and config unless the project's config asks for them. The build goes on if the terminal that started it closes. The routing paragraph of step 0 applies to every dispatch in these sessions. A session has nobody to ask. Where this skill says to stop and ask, write the Stops line, end the session with the question as your last message, and let the build decide what happens next.

### Group session (`--group <id> --tasks <n,n|none> --from <commit>`)

You implement `--tasks` in this session as in step 3 without the extension, in plan order. Do not start the next group, verify or open a PR. Stay on this branch. Read the spec, the plan, Notes and the plan's Tasks rows of this group. The diff of the group is `<--from>..HEAD`.

For a task that changes what a page shows, also follow the implementer's screenshots step. If a task still fails after your second fix attempt, dispatch the `implementer` on it as in step 3; if that fails too, leave the task unticked, write a Stops line of class `tier`, and end the session. If the spec turns out to be wrong, write a Stops line of class `spec` and end the session.

If the prompt holds failure output from the build's own checks, fix that first, and commit it. Do not weaken a test.

**With one group in the plan, stop here:** the final session simplifies and reviews. Leave no uncommitted changes.

With several groups, once every task is ticked:

1. Simplify the group's diff as in step 4, with the description `simplify group <id>`, the range `<--from>..HEAD`, and the clone lists of the group's files.
2. Dispatch the `reviewer` with the description `group <id> review round <n>`. Give it the range `<--from>..HEAD`, this group's task rows, their criteria and their Verify log rows, and say that a criterion only in another group's tasks is not a finding.
3. Record each round under Rounds: `- group <id> review <n> | <full|delta> | <commit range> | pass`, or `<n> high open` in place of `pass`.
4. Fix every high finding yourself and commit it, then review again. After two rounds with open high findings, write a Stops line of class `hotfix`, and end the session.

If stempel-kit-routing is installed, a retry inside a group runs one tier above the group's tier, and the group reviewer's `model` is this group's tier, at least standard, and deep if a task of the group was retried on deep.

If this group's last round in Rounds is not `pass`, a build stopped there: start with a full review, numbered on from that round, with at most 2 more rounds.

Leave no uncommitted changes when you end.

### Final session (`--final`)

Every group is done. Do steps 4 to 7 on the whole branch. With several groups, step 4 runs only when the two checks list clones in files changed on this branch: each group already simplified its own work.

In step 7, a feature with several groups gets one description per layer (the "Stacked layers" of `/pr-description`). Commit nothing now.

If stempel-kit-improve is installed, the run record for `/improve-kit`, if any, was committed before the pack.

Opening the pull requests is gate push. With `auto`, run `.claude/bin/stack submit` yourself: it cuts one branch per group below the top, pushes them with their evidence packs, and opens one pull request per layer, stacked. With `ask` in a final session, do not run it: write a Stops line of class `push` and end the session; the developer approves it by running `/ship-feature` in a terminal.

### Stack session (`--stack` or `--stack review`)

The stack stage (`specs/stack-stage.md`) ran the selected e2e tests, with their screenshots, and the mutation tests once on this branch, the stack's top layer. Its results are in `.work/<branch>/stack/`: `data-runs.tsv`, `red.txt` (the red e2e files), `e2e-junit.xml`, `mutation.txt`, `survivors.tsv` and `screenshots/`. Stay on this branch: every commit goes on the top layer, also a fix for a lower layer's code, because a commit on a lower layer would rebase every layer above it. Never edit `KIT_MUTATION_EXCEPTIONS`, the e2e map or a threshold to get past the stage.

**`--stack`: the stage is red.** The prompt holds its output.

1. Red e2e tests: classify each failure as in "Verify failures" and fix it as its class says: `test` through the `test-writer`, `hotfix` through the `implementer` with a red test first, `kit` and `spec` stop and ask. Commit each fix.
2. A mutation score below the threshold: dispatch the `test-writer` (description `stack survivors`) with `survivors.tsv` as its worklist: for each surviving mutant, a test that fails with the mutant and passes without it. A mutant no test can tell from the code (an equivalent mutant) goes into Notes with its reason, for a person to list in `KIT_MUTATION_EXCEPTIONS`. Commit the tests.
3. If stempel-kit-evidence is installed, the pack must describe the new top commit: run `.claude/bin/evidence gates`, `.claude/bin/evidence matrix`, `.claude/bin/evidence json` and `.claude/bin/evidence push` (gate push), as in verify's rounds.
4. Record `- stack <n> | fix | <commit range> | <classes, or survivors>` under Rounds and end the session. The build runs only the red e2e tests again, and the mutation tests.

**`--stack review`: the stage is green.**

1. If stempel-kit-evidence is installed, run `.claude/bin/evidence stage-results --dir .work/<branch>/stack`, then `.claude/bin/evidence matrix`: every e2e case of every feature in the stack now has its result. A failed case is a finding.
2. Dispatch the `reviewer` (description `review screenshots`) with the specs of the stack's features, the screenshot folder `.work/<branch>/evidence/screenshots/` and the instruction to check them as its agent file describes. Save its report to `.work/<branch>/stack/screenshots-review.md`.
3. If stempel-kit-evidence is installed and there is no high finding, run `.claude/bin/evidence json` and `.claude/bin/evidence push` (gate push), so the screenshots are on `kit-evidence` for the pull requests, and record `- stack review <n> | full | <head> | pass`. The build then puts each layer's screenshots and the mutation score into its pull request (`.claude/bin/stack bodies`).
4. A high finding: fix it as a `hotfix` on this branch, run step 3 of `--stack` for the pack, and record `- stack review <n> | full | <head> | <n> high open`. The build runs the stage again.
