# Cost visibility

ID prefix: COST

## Goal
A developer who runs builds with the next kit can see what a feature cost, how well its sessions used the prompt cache, and can set the reasoning effort per model tier. Today `usage` counts input, output and cache writes and leaves cache reads out, so a low cache hit rate stays invisible, and a group session always runs at the session's default effort. The talk "The Hidden Economics of Agentic Software Engineering" (Matthias Lau, 04.11.2026) names cache hit rate, reasoning effort and model by role as the first levers on an agentic bill; this feature makes the first two measurable and settable, and leaves the third as it is.

## User flow
1. A build runs as today. Each session records its tokens in `.work/<branch>/usage.tsv`, and autopilot records each session's cost in `.work/autopilot/sessions.tsv`.
2. The developer runs `.claude/bin/usage cache` and sees the cache hit rate per agent and for the branch.
3. The developer runs `.claude/bin/usage cost <feature>` and sees what the feature's sessions cost, in total and per phase.
4. The PR description's Cost line, the autopilot run log and `reports/runs.md` show the same figures, and a hit rate below the configured minimum is named.
5. The developer sets `KIT_EFFORT_FAST`, `KIT_EFFORT_STANDARD` or `KIT_EFFORT_DEEP` in `.claude/kit.conf`. Group sessions on that tier start with that effort. After three runs, `reports/runs.md` shows whether tokens, cost and escalations moved.

## Terms
- **Cache hit rate**: cache read tokens divided by the sum of input, cache read and cache write tokens, as a whole percent rounded down. It is `–` when that sum is 0.
- **Usage record**: `.work/<branch>/usage.tsv`, as in `.claude/bin/usage`.
- **Session cost**: the `cost_usd` column of `.work/autopilot/sessions.tsv`, which autopilot takes from the session's `total_cost_usd`. A row without a cost holds `–`.
- **Tier effort**: the value of `KIT_EFFORT_<TIER>` for the tier a group runs on. An empty value means the session's own default.
- **Effort values**: `low`, `medium`, `high`, `xhigh` and `max`.

## Acceptance criteria

Cache hit rate:

- **COST-AC1**: Given a usage record with one agent line of input 100, cache read 800 and cache write 100, when `usage cache` runs, then it prints a line with that agent's id, its model and `80%`.
- **COST-AC2**: Given one agent line of input 100, cache read 800, cache write 100 and another of input 100, cache read 0, cache write 900, when `usage cache` runs, then its last line is `branch` with `40%`.
- **COST-AC3**: Given a session line whose id starts with `main:`, when `usage cache` runs, then its line is labelled `main` instead of the session id.
- **COST-AC4**: Given no usage record, when `usage cache` runs, then it prints `No usage recorded for <branch> yet.` and exits with 0.

Reporting the hit rate:

- **COST-AC5**: Given a branch hit rate of 80% and `KIT_CACHE_MIN_PERCENT` empty, when `usage line` runs, then the line ends with `Escalations: 0. Cache hit rate: 80%.`
- **COST-AC6**: Given a branch hit rate of 80% and `KIT_CACHE_MIN_PERCENT="90"`, when `usage line` runs, then the line ends with `Cache hit rate: 80%, below 90%.`
- **COST-AC7**: Given a branch hit rate of 90% and `KIT_CACHE_MIN_PERCENT="90"`, when `usage line` runs, then the line ends with `Cache hit rate: 90%.`
- **COST-AC8**: Given a record whose three counters input, cache read and cache write are all 0, when `usage line` runs, then the line has no `Cache hit rate` sentence.
- **COST-AC9**: Given the shipped `.claude/kit.conf`, when it is read, then `KIT_CACHE_MIN_PERCENT` is `90`.

Cost:

- **COST-AC10**: Given sessions.tsv rows for feature `invite` with cost 1.50 and 2.25, and a row for feature `other` with cost 9.00, when `usage cost invite` runs, then its last line is `total 3.75 USD`.
- **COST-AC11**: Given rows for feature `invite` with phase `plan` (cost 1.00) and phase `build` (cost 3.00), when `usage cost invite` runs, then it prints `plan 1.00 USD` and `build 3.00 USD` before the total line.
- **COST-AC12**: Given a row for feature `invite` whose cost is `–` and a row with cost 2.00, when `usage cost invite` runs, then the total is `2.00 USD` and the output has the line `1 session without a cost`.
- **COST-AC13**: Given no sessions.tsv, when `usage cost invite` runs, then it prints `No session costs recorded for invite.` and exits with 0.
- **COST-AC14**: Given a build whose sessions.tsv rows for the feature sum to 3.75, when autopilot writes the feature's row in the run log, then the row's details contain `3.75 USD`.

Reasoning effort:

- **COST-AC15**: Given `KIT_EFFORT_STANDARD="medium"` and a group planned on the standard tier, when autopilot starts that group's session, then `claude` is called with `--effort medium`.
- **COST-AC16**: Given `KIT_EFFORT_DEEP="high"` and a group planned on the deep tier, when autopilot starts that group's session, then `claude` is called with `--effort high`.
- **COST-AC17**: Given no `KIT_EFFORT_STANDARD` value and a group planned on the standard tier, when autopilot starts that group's session, then `claude` is called without `--effort`.
- **COST-AC18**: Given a group on the deep tier whose checks fail after the group, when autopilot resumes the session, then `claude` is called with `--effort max`, whatever `KIT_EFFORT_DEEP` says.
- **COST-AC19**: Given `KIT_EFFORT_STANDARD="medium"`, `KIT_EFFORT_DEEP="high"` and a group on the standard tier whose checks fail, when autopilot resumes the session, then `claude` is called with the deep tier's model and `--effort high`.
- **COST-AC20**: Given `KIT_EFFORT_STANDARD="turbo"`, when `.claude/bin/autopilot --ready` runs, then it prints a line naming `KIT_EFFORT_STANDARD` and `turbo` and exits with 2.
- **COST-AC21**: Given `CLAUDE_CODE_EFFORT_LEVEL` is set and `KIT_EFFORT_STANDARD="medium"`, when `.claude/bin/route check` runs, then it prints a warning that the environment variable overrides the tier efforts and exits with 1.

Runs report:

- **COST-AC22**: Given a usage record with a branch hit rate of 80%, when `usage tsv` runs, then its tenth field is `80`.
- **COST-AC23**: Given three run records with hit rates 60, 80 and 90, when `runs report` runs, then the row `Cache hit rate (percent)` shows the median `80` and a run count of 3.
- **COST-AC24**: Given three run records of which one has no hit rate, when `runs report` runs, then the row `Cache hit rate (percent)` shows a run count of 2.
- **COST-AC25**: Given a run record whose setup differs from the normal flow, when `runs report` runs, then its hit rate is left out of the row `Cache hit rate (percent)`, as for the token metrics.

## Edge cases
- **COST-AC26**: Given a usage record with input 1, cache read 2 and cache write 0, when `usage cache` runs, then the agent's rate is `66%`.
- **COST-AC27**: Given an agent line whose counters are all 0, when `usage cache` runs, then its rate is `–`.
- **COST-AC28**: Given `KIT_CACHE_MIN_PERCENT="abc"`, when `usage line` runs, then the line has no `below` sentence and `usage` prints a line on stderr naming `KIT_CACHE_MIN_PERCENT`.
- **COST-AC29**: Given a sessions.tsv row whose cost is not a number and not `–`, when `usage cost invite` runs, then that row is counted as a session without a cost.
- **COST-AC30**: Given the feature slug `invite` and rows for `invite` and `invite-2`, when `usage cost invite` runs, then the total holds only the `invite` rows.

## Out of scope
- Euro or dollar prices per token and a price table; the cost comes from Claude Code's own `total_cost_usd`, because prices change.
- A cost budget (`KIT_BUDGET_USD`); the token budget stays as it is.
- Changing how the build escalates a failed group, or how the budget counts tokens.
- Effort per agent file: the Agent tool sets no effort, so subagents keep their frontmatter.
- Cost per group; sessions.tsv records the phases `plan`, `build` and `stack`, so groups are not told apart.
- Choosing the model by task kind, and any cache setting inside Claude Code.

## Open questions
- Does resuming a failed group on the next tier cost more than a fresh session on that tier? This spec measures it (COST-AC10, COST-AC11) but does not change it. Vito can decide after three runs.
- Does the installed `claude --effort` accept exactly `low`, `medium`, `high`, `xhigh` and `max`? Check `claude --help` for the version in use before approval.

## Decisions
- 04.11.2026: Cost comes from the sessions' `total_cost_usd`, not from a price table in `kit.conf`, because `docs/SPEC-v1.1.md` keeps euro cost out for the reason that prices change, and autopilot already records the figure.
- 04.11.2026: The hit rate counts input, cache read and cache write in its denominator, because that is every token the model was sent, and the budget's own exclusion of cache reads stays untouched.
- 04.11.2026: The default minimum is 90 percent, because the talk calls a rate below 90 percent work to do. It only names the rate; it never fails a build.
- 04.11.2026: A failed group that resumes one tier up takes that tier's effort, and a deep group keeps `max`, because the resume rule in `docs/customizing.md` already raises tier or effort and this feature must not weaken it.
- 04.11.2026: Effort is set per tier, not per task, because the Agent tool takes a model per dispatch but no effort, and the group already runs on its highest task tier.
