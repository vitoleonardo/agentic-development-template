# Risk gates

ID prefix: RISK

## Goal
The kit runs on its own by default and stops for a person only where the work is risky: a change to the architecture, a security-relevant path, or a very complex change. Today `KIT_APPROVAL` defaults to `strict`, so every gate asks, and at `autonomous` nothing asks and the kit never merges. A deterministic risk rank decides instead: the plan is ranked before any code is written, and each layer of a stack is ranked again from its real diff and the run's signals before the stack merges. A low-ranked stack merges itself after a green stack stage. A high-ranked layer waits for a person's approval, and a required CI check that the build cannot change enforces that. `strict` stays available for teams that want every gate to ask.

## User flow
1. A project on the default level runs `/ship-feature` or `.claude/bin/autopilot`. The spec is written and approved without asking.
2. The plan is ranked. A low or medium plan is approved without asking and logged under Decisions to review; a high plan stops, and the developer approves spec and plan together, seeing the reasons.
3. The groups build, the stack is submitted, the stack stage runs.
4. Each layer is ranked from its diff and the run's signals. The rank and its reasons go into the layer's description, and CI's `Risk` check reports the same rank for the diff.
5. All layers below high and the stage green: the build merges the stack.
6. A high layer: the build stops with a Stops line of class `approval` naming the pull requests. A person reviews and approves them; the `Risk` check turns green; running the build again merges the stack.
7. A team that wants every gate to ask sets `KIT_APPROVAL="strict"`.

## Terms
- **Rank**: the first line `.claude/bin/risk` prints, `risk <score> <low|medium|high>`, followed by one reason per line (`+<points> <reason>` or `high: <reason>`).
- **Hard trigger**: a reason that makes the rank high whatever the score.
- **Plan rank**: `.claude/bin/risk plan`, from the state file.
- **Layer rank**: `.claude/bin/risk diff --from <layer below> --to <layer head>`, plus the run's signals from the state file.
- **Stack rank**: the highest layer rank of a stack, with each high layer named.
- **Human threshold**: `KIT_RISK_HUMAN`, the score from which a rank is high; default 8.
- **Medium**: a score from half the human threshold, rounded up, to the threshold minus 1.
- **Bot identity**: the GitHub account the build pushes, opens and merges pull requests with: `KIT_BOT_GH_CONFIG`, a `GH_CONFIG_DIR` logged in as a GitHub App or machine user.
- **Approval**: a review with state APPROVED on the layer's head, by an account with write access that is not the pull request's author.

## Acceptance criteria

Default level:

- **RISK-AC1**: Given no `KIT_APPROVAL` in the environment or `.claude/kit.conf`, when `.claude/bin/gate level` runs, then it prints `autonomous`.
- **RISK-AC2**: Given `KIT_APPROVAL="strict"` in `.claude/kit.conf`, when `.claude/bin/gate plan` runs, then it prints `ask`.
- **RISK-AC3**: Given `KIT_APPROVAL="often"`, when `.claude/bin/gate level` runs, then it prints `strict` and a warning on stderr.
- **RISK-AC4**: Given the kit's and the adapters' `kit.conf` templates, when they are read, then each sets `KIT_APPROVAL="autonomous"`.
- **RISK-AC5**: Given a project whose `kit.conf` sets `KIT_APPROVAL="strict"`, when the installer updates the project, then the project's `KIT_APPROVAL` is still `strict`.

Ranking:

- **RISK-AC6**: Given a diff that changes `src/auth/session.ts` and `KIT_PUSH_ASK_PATTERNS` holding `*auth*`, when `risk diff` runs, then the rank is high with a reason that names `src/auth/session.ts`.
- **RISK-AC7**: Given a diff that changes a file in `KIT_ARCHITECTURE_PATTERNS`, when `risk diff` runs, then the rank is high with a reason that names that file.
- **RISK-AC8**: Given a diff that changes a file under `.github/`, `.claude/`, the e2e map or the mutation exceptions file, when `risk diff` runs, then the rank is high with a reason that names that file.
- **RISK-AC9**: Given a diff of 20 changed lines in one source file outside every pattern, with no new dependency, when `risk diff` runs, then the rank is low.
- **RISK-AC10**: Given a diff with more changed lines than `KIT_MAX_CHANGED_LINES`, when `risk diff` runs, then a reason names the changed lines and the limit.
- **RISK-AC11**: Given a diff that adds a dependency to `package.json`, when `risk diff` runs, then a reason names the dependency.
- **RISK-AC12**: Given a diff whose e2e selection is `all`, when `risk diff` runs, then a reason names the e2e selection.
- **RISK-AC13**: Given a state file with a Stops line of class `tier` and a Rounds line `- review 2 | … | 1 high open`, when the layer rank is computed, then a reason names the retry and one names the review round.
- **RISK-AC14**: Given the same diff and state file, when `risk diff` runs twice, then both outputs are the same.
- **RISK-AC15**: Given `KIT_RISK_HUMAN=4` and a score of 4, when `risk diff` runs, then the rank is high.

Plan gate:

- **RISK-AC16**: Given a plan with `Architecture: a new queue between the API and the mailer`, when `risk plan` runs, then the rank is high with a reason that quotes the Architecture line.
- **RISK-AC17**: Given a plan with `Architecture: none`, `Estimate: 120 lines`, standard tasks only and no file in a pattern, when `risk plan` runs, then the rank is low.
- **RISK-AC18**: Given approval level `autonomous` and a high plan rank, when `.claude/bin/gate plan` runs, then it prints `ask` and the rank's reasons on stderr.
- **RISK-AC19**: Given approval level `autonomous` and a low plan rank, when `/plan-feature` ends, then Decisions to review holds a line with the plan approval and the rank.
- **RISK-AC20**: Given a plan without an `Architecture:` line, when `plan-lint` runs, then a finding names the missing line.
- **RISK-AC21**: Given a plan without an `Estimate: <n> lines` line, when `plan-lint` runs, then a finding names the missing line.
- **RISK-AC22**: Given an autopilot run and a high plan rank, when the plan session ends, then no group session starts, Stops holds a new line of class `approval`, and the run log's closing line starts with `Stopped at `.
- **RISK-AC23**: Given a build session that changes the plan's `Architecture:` or `Estimate:` line after the plan was approved, when the build continues, then no further session starts and the run log's closing line names that line.

Merge gate:

- **RISK-AC24**: Given approval level `autonomous`, a green stack stage and every layer rank below high, when the build continues, then `gh stack merge` ran with the top layer's pull request and `--yes`.
- **RISK-AC25**: Given a stack with one high layer, when the build continues, then no merge runs, Stops holds a new line of class `approval` naming that layer's pull request, and the run log's closing line starts with `Stopped at `.
- **RISK-AC26**: Given a Stops line of class `approval`, when the build continues, then no answer session starts.
- **RISK-AC27**: Given a high layer with an approval on its head and a green stage, when the build runs again, then the stack is merged.
- **RISK-AC28**: Given a stack stage that is not green, when the merge gate runs, then it prints `ask`.
- **RISK-AC29**: Given approval level `strict`, when `.claude/bin/gate merge` runs, then it prints `ask`.
- **RISK-AC30**: Given approval level `autonomous`, when `.claude/bin/gate push` runs on a branch that changes a file in `KIT_PUSH_ASK_PATTERNS`, then it prints `auto`.
- **RISK-AC31**: Given the kit's `settings.json`, when it is read, then `permissions.ask` holds `Bash(gh pr merge *)` and `Bash(gh stack merge *)`, so only the build's script merges.
- **RISK-AC32**: Given a stack is merged, when the build ends, then the run log's closing line starts with `Every feature has a PR, and the stack is merged`.
- **RISK-AC49**: Given `KIT_GATE_MERGE="ask"` and a green stage, when the build ends, then no merge runs and the run log's closing line starts with `Every feature has a PR. Review the PRs`.
- **RISK-AC33**: Given a merged stack, when `KIT_MERGE_METHOD` is empty, then the merge used `--squash`.

The Risk check in CI:

- **RISK-AC34**: Given the adapter's `risk.yml`, when it is read, then it runs on `pull_request_target` and on `pull_request_review`, and checks out `.claude/` and `.github/` from the base branch.
- **RISK-AC35**: Given a pull request whose diff ranks high and no approval on its head, when `risk.yml` runs, then the `Risk` check fails and its summary lists the reasons.
- **RISK-AC36**: Given that pull request and an approval on its head, when `risk.yml` runs again, then the `Risk` check passes.
- **RISK-AC37**: Given an approval by the pull request's author, when `risk.yml` runs, then the `Risk` check still fails for a high rank.
- **RISK-AC38**: Given a pull request that lowers `KIT_RISK_HUMAN` in `.claude/kit.conf`, when `risk.yml` runs, then the rank is computed with the base branch's `kit.conf` and is high.
- **RISK-AC39**: Given a low-ranked pull request, when `risk.yml` runs, then the `Risk` check passes without an approval.

Bot identity:

- **RISK-AC40**: Given `KIT_BOT_GH_CONFIG` set, when autopilot starts a session, then the session's environment has `GH_CONFIG_DIR` set to that folder.
- **RISK-AC41**: Given `KIT_BOT_GH_CONFIG` unset and level `autonomous`, when `.claude/bin/autopilot --ready` runs, then it prints a warning that the build pushes as the developer, so the developer cannot approve a high layer.
- **RISK-AC42**: Given the kit's `settings.json`, when it is read, then `permissions.deny` holds `Bash(gh pr review *)` and a rule for `gh api` calls on `reviews`.
- **RISK-AC43**: Given `/onboard` in a project with a GitHub remote, when it ends, then its report lists the required checks `Evidence`, `Risk`, `kit/e2e` and `kit/mutation` and the steps to create the bot identity.

Records:

- **RISK-AC44**: Given a submitted stack, when the layer descriptions are written, then each holds a `Risk:` line with the layer's rank and its reasons.
- **RISK-AC45**: Given 3 runs with one Stops line of class `approval` each, when `.claude/bin/runs report` runs, then the stops by class count 3 for `approval`.

## Edge cases
- **RISK-AC46**: Given a high plan approved by a person, when the stack is ranked later, then the plan's own high reasons are not counted again unless the diff shows them.
- **RISK-AC47**: Given a diff that renames a file into `KIT_ARCHITECTURE_PATTERNS`, when `risk diff` runs, then the rank is high.
- **RISK-AC48**: Given a pull request from a fork, when `risk.yml` runs, then it fails with a message that stacks from forks are not supported.

## Out of scope
- Ranking with a model. The rank is a script, so the same diff always gets the same rank.
- Merging part of a stack.
- Running the build under a separate operating-system user.

## Open questions

## Decisions
- 04.11.2026: The default level is `autonomous`, gated by the rank, because the user asked to run on its own "EXCEPT it does changes on the architecture or other very complex tasks". `strict` stays for teams that want every gate.
- 04.11.2026: The rank gates both the plan and the merge, so an architecture change gets a person's look before any code, and the measured diff gets one before it lands.
- 04.11.2026: The build merges a stack below high itself. A high layer needs a review by someone other than its author, enforced by `risk.yml` on `pull_request_target`, so a pull request cannot change the rules it is judged by.
- 04.11.2026: The build pushes as a bot identity, because GitHub does not let the author approve their own pull request; with the developer's own token nobody could approve a high layer. The kit warns but does not refuse without one.
- 04.11.2026: Changes to `.github/`, `.claude/`, the e2e map and the mutation exceptions are hard triggers, because a build that could change its own checks could lower its own bar.
- 04.11.2026: `KIT_PUSH_ASK_PATTERNS` no longer stops the push at `autonomous`; it is a hard trigger at the merge, where the person sees the finished, checked stack.
- 04.11.2026: The spec gate stays `auto` at `autonomous`; a high plan asks for spec and plan together, because the spec alone does not show the architecture.
- 04.11.2026: The rank reads its patterns from `kit.conf` only, never the environment, so CI on `pull_request_target` ranks with the base branch's rules. Only the build's script merges; a session's merge commands always ask, and its review commands are denied.
- 04.11.2026: When the merge gate asks without a waiting high layer (`KIT_GATE_MERGE="ask"`, `strict`), the build ends with the pull requests open, as before; only a high layer waiting for approval is a stop.
