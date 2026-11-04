# Fix bug

ID prefix: FIXBUG

## Goal
A reported bug gets the same discipline as a feature without a feature's ceremony: a red test that shows the bug, the smallest fix that makes it green, an independent review, verify with an evidence pack and a PR description. Today `CLAUDE.md` says that small fixes skip the spec but not the test, while every agent and script finds the criteria only through `specs/README.md` and the spec. `/fix-bug` gives a bug its own plan with its criteria inside, reuses the spec's criterion when one exists, and never writes a feature spec.

## User flow
1. The developer runs `/fix-bug` with a pasted bug report, an issue number or URL, or the name of a failing test.
2. The skill reads the report and finds the contract: the spec's criterion the bug contradicts, a gap in a spec that covers the feature, or no spec at all.
3. It writes the fix plan to `.work/<branch>.md`: the bug, one to three criteria, the cause, two tasks. `plan-lint` passes, then the plan is approved.
4. The `test-writer` writes the red test and shows it failing for the reported reason.
5. The `implementer` makes it green, and the test and the fix go into one commit.
6. The `reviewer` reviews the diff, `/verify-feature` proves it, `/pr-description` writes the PR with the report as the Why.

## Terms
- **Report**: what the developer gives `/fix-bug`: pasted text, an issue number or URL, or the name of a failing test.
- **Slug**: a short kebab-case name for the bug, taken from the report.
- **Fix branch**: `<issue>-<slug>` when the report is an issue, else `fix-<slug>`; never the file name of a spec.
- **Fix plan**: `.work/<branch>.md` with the sections `## Bug`, `## Criteria`, `## Design`, `## Tasks`, `## Progress`, `## Verify log`, `## Stops`, `## Rounds`, `## Decisions to review` and `## Notes`.
- **Covered bug**: the behaviour contradicts a criterion of a spec listed in `specs/README.md`.
- **Gap bug**: a listed spec covers the feature, but no criterion states the behaviour.
- **Unspecified bug**: no listed spec covers the area.
- **Red test**: a test whose name starts with a criterion ID and that fails before the fix for the reported reason.
- **Fix title**: `# Plan: <slug> (fix)`; a covered or gap bug uses `# Plan: <slug> (spec: specs/<feature>.md)` instead.
- **Feature of a plan**: the spec's file name without `.md` when the title names one, else the slug.

## Acceptance criteria

Reading the report:

- **FIXBUG-AC1**: Given a pasted report, when `/fix-bug` starts, then `## Bug` in the fix plan holds the lines `Source`, `Reproduce`, `Expected` and `Observed`.
- **FIXBUG-AC2**: Given an issue number or URL, when `/fix-bug` reads the report, then it runs `gh issue view <n> --json title,body,url` and `Source` holds the issue URL.
- **FIXBUG-AC3**: Given the name of a failing test, when `/fix-bug` reads the report, then task 1 names that test and `## Bug` holds its failure message.

Finding the contract:

- **FIXBUG-AC4**: Given a covered bug of `INVITE-AC3`, when the fix plan is written, then its title names `specs/invite.md` and `## Criteria` holds `INVITE-AC3` and no other ID.
- **FIXBUG-AC5**: Given a covered bug, when the fix is done, then `specs/invite.md` is unchanged.
- **FIXBUG-AC6**: Given a gap bug of a spec whose highest ID is `INVITE-AC7`, when the fix plan is written, then the spec holds exactly one new criterion `INVITE-AC8`, one new Decisions entry, and `spec-lint` passes on it.
- **FIXBUG-AC7**: Given a gap bug, when the spec gained its criterion, then `.claude/bin/gate spec` has run before any subagent is dispatched.
- **FIXBUG-AC8**: Given an unspecified bug, when the fix plan is written, then its title is `# Plan: <slug> (fix)` and the IDs under `## Criteria` use a prefix no spec has.

Planning:

- **FIXBUG-AC9**: Given any fix plan, when `/fix-bug` asks for its approval, then `.claude/bin/plan-lint` has passed on it.
- **FIXBUG-AC10**: Given any fix, when it is done, then no row of `specs/README.md` has a changed Status or Branch cell.
- **FIXBUG-AC11**: Given an approved fix plan, when its Tasks table is read, then it holds exactly the rows `reproduce` and `fix`, and `fix` depends on `reproduce`.

Building:

- **FIXBUG-AC12**: Given task 1, when it is dispatched, then the agent is the `test-writer` with `model` from `.claude/bin/route tests` and the description `task 1: reproduce <slug>`.
- **FIXBUG-AC13**: Given the test-writer reports a test that never failed, when `/fix-bug` reads the result, then no implementer is dispatched and a Stops line of class `test` is written.
- **FIXBUG-AC14**: Given task 2, when it is dispatched, then the agent is the `implementer` on the row's tier with the description `task 2: fix <slug>`, given the red test's file and its failure message.
- **FIXBUG-AC15**: Given task 2 fails its checks once, when it is dispatched again, then the description is `task 2 retry <tier>: fix <slug>` with the tier from `.claude/bin/route up`.
- **FIXBUG-AC16**: Given task 2 fails its checks twice, when the second failure is read, then no further implementer is dispatched and the developer is asked.
- **FIXBUG-AC17**: Given task 2 passes its checks, when the build ends, then the red test and the fix are in one commit, made after `.claude/bin/gate commit`.
- **FIXBUG-AC18**: Given the fix is committed, when the next step starts, then no subagent whose description starts with `simplify` is dispatched.

Review, verify and PR:

- **FIXBUG-AC19**: Given the fix is committed, when review starts, then the `reviewer` is dispatched with the description `review round 1`, and later rounds follow step 5 of `/ship-feature`.
- **FIXBUG-AC20**: Given verify fails because the product is wrong, when the round is classified, then `.claude/bin/gate round hotfix <n>` decides whether to ask.
- **FIXBUG-AC21**: Given verify passed, when `/fix-bug` ends, then `.work/<branch>-pr.md` exists and its Why line links the report's source and no spec.

Status and run records:

- **FIXBUG-AC22**: Given a state file titled `# Plan: login-redirect (fix)` and no row in `specs/README.md` for the branch, when the status command runs with `--line`, then it prints `login-redirect · plan`.
- **FIXBUG-AC23**: Given a `(fix)` plan whose `## Criteria` holds `LOGINFIX-AC1` and `LOGINFIX-AC2` and a Verify log with a filled Green cell for `LOGINFIX-AC1`, when the status command runs with `--json`, then `criteria` lists `LOGINFIX-AC1` as `green` and `LOGINFIX-AC2` as `open`.
- **FIXBUG-AC24**: Given a `(fix)` plan, when the status command runs with `--json`, then `spec` is `null` and `warnings` is empty.
- **FIXBUG-AC25**: Given a plan titled with `specs/invite.md` whose `## Criteria` holds `INVITE-AC3`, when the status command runs with `--json`, then `criteria` lists `INVITE-AC3` and no other ID.
- **FIXBUG-AC26**: Given a `(fix)` plan on branch `fix-login-redirect` and `KIT_IMPROVE` set, when `runs record` runs, then the record's feature is `login-redirect`.

Agents and sibling skills:

- **FIXBUG-AC27**: Given the implementer's agent file, when it is read, then it says to run an existing red test the task names and confirm its failure instead of writing one, and never to change it.
- **FIXBUG-AC28**: Given the reviewer's and the test-writer's agent files, when they are read, then each says to take the criteria from the state file's `## Criteria` section when no row names the branch.
- **FIXBUG-AC29**: Given the verify skill, when it is read, then it says to set the feature's status only when a row of `specs/README.md` names the branch.

## Edge cases
- **FIXBUG-AC30**: Given a report about a feature whose row is `building` or `in-review` on another branch, when `/fix-bug` starts, then it writes no plan and names that branch.
- **FIXBUG-AC31**: Given the reproduction shows the behaviour the spec's criterion states, when `/fix-bug` reads the result, then it writes a Stops line of class `spec`, changes no spec and asks.
- **FIXBUG-AC32**: Given the test-writer reports that the code needs a change to be testable, when `/fix-bug` reads the result, then it stops with a Stops line of class `plan`.
- **FIXBUG-AC33**: Given a state file for the branch that already has a `## Bug` section, when `/fix-bug` starts, then it resumes at the first open Progress step and `## Bug` is unchanged.
- **FIXBUG-AC34**: Given an issue number and `gh` not logged in, when `/fix-bug` reads the report, then it prints the error from `gh` and asks for the report as text.

## Out of scope
- Writing a feature spec from a bug report; a bug that needs more than one new criterion is a feature for `/spec-feature`.
- Changing an approved criterion; that is the `spec` class and always asks.
- Setting a feature's status or branch in `specs/README.md`.
- Simplify; the reviewer runs `check similar` on the fix's files.
- Queueing fixes in `.claude/bin/autopilot`.

## Open questions

## Decisions
- 04.11.2026: A fix plan always has `## Criteria`, because every agent, the status command and the PR then find the criteria in one place, with or without a spec.
- 04.11.2026: A gap bug amends the spec by exactly one criterion and goes through `gate spec` and then `gate plan`, because the spec stays the contract and the criterion was missing, not wrong.
- 04.11.2026: Simplify is skipped, because a fix touches two files and the reviewer runs `check similar`.
- 04.11.2026: The red test and the fix go into one commit, because the test alone leaves the branch red.
- 04.11.2026: Fix branches are `<issue>-<slug>` or `fix-<slug>`, because a branch named like a spec would match that feature's row in `specs/README.md`.
- 04.11.2026: `gh issue view` stays a prompt, because the kit allows no network command without asking.
