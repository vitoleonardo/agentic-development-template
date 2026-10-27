# Customizing the kit

Everything the kit installs is plain Markdown, JSON and POSIX shell in your repository. Change it like any other code, through a pull request. The permission rules ask before anyone, Claude included, edits `.claude/settings.json`, `kit.conf`, `bin/`, `hooks/` or `rules/`.

## Add a rule

Rules are short Markdown files in `.claude/rules/`. Claude Code loads all of them at the start of a session. A rule that only matters for some files gets a `paths:` header and loads only when Claude works on matching files:

```markdown
---
paths:
  - "src/billing/**"
---

# Billing

- Amounts are integers in cents. Never use floating point for money.
- Every change to `src/billing/` needs a test for rounding and for a zero amount.
```

Write rules as instructions that can be checked ("amounts are integers in cents"), not as values ("be careful with money"). Keep each file short; a rule nobody reads in review is a rule the model also skips. If a rule must never be broken, enforce it with a hook or a CI step as well, because rules guide the model but do not stop it.

`output.md` keeps answers, summaries and PR descriptions short. Edit or delete it if your team wants longer prose.

## Add a stack preset

Presets are rules for one framework, in `adapters/<adapter>/presets/<name>.md`, with a `paths:` header for the framework's files. `install.sh --preset <name>` copies them to `.claude/rules/`. The TypeScript adapter has `nextjs`, `nestjs` and `node`.

Write down what the model gets wrong for your version of the framework, not a tutorial. The Next.js preset, for example, says that request APIs such as `cookies()` are async and that `middleware.ts` is now `proxy.ts`, because models trained on older versions get both wrong.

## Add an adapter

An adapter tells the kit how your stack typechecks, lints, tests and formats. It is a folder in `adapters/` whose files are copied over the core, usually just `.claude/kit.conf`, a rules file and a CI workflow.

`.claude/kit.conf` is sourced by POSIX `sh`. Each value is a command. Leave a value empty if the project has no such check, and `.claude/bin/check` then reports "not configured" (exit 3). If the project cannot have the check, say why: `KIT_BUILD="n/a: library, no build step"` exits 4, and CI passes it with the reason in the log.

| Variable | Used by | Gets |
|---|---|---|
| `KIT_TYPECHECK` | hooks, `/ship-feature`, CI | nothing |
| `KIT_LINT` | `/ship-feature`, reviewer, CI | nothing |
| `KIT_TEST` | `/ship-feature`, reviewer, CI | nothing; must fail when zero tests run |
| `KIT_TEST_REPORT` | baseline, CI | nothing; the JUnit XML file `KIT_TEST` writes, so legacy failures can be told from new ones |
| `KIT_TEST_RELATED` | hooks, implementer, test-writer | the edited files; runs only the tests that cover them |
| `KIT_COVERAGE` | CI | nothing; writes a coverage report, also when tests fail |
| `KIT_COVERAGE_FILES` | coverage gate | nothing; prints `<file> TAB <covered lines> TAB <total lines>` from that report |
| `KIT_COVERAGE_PCT` | coverage gate | nothing; prints the overall line percentage |
| `KIT_COVERAGE_EXCLUDE` | coverage gate | shell patterns of source files that carry no coverage, for example `*.d.ts` |
| `KIT_COVERAGE_THRESHOLD`, `KIT_COVERAGE_TOLERANCE` | coverage gate | percent of the lines in the changed source files that must be covered (70), and how far overall coverage may drop below the baseline (0.5 points) |
| `KIT_FORMAT` | hooks | the edited files |
| `KIT_BUILD` | `/ship-feature`, CI | nothing |
| `KIT_SOURCE_PATTERNS` | hooks | shell patterns of files that trigger the checks, for example `*.py` |
| `KIT_TEST_PATTERNS` | guard | shell patterns of the files the test-writer may edit |
| `KIT_DANGEROUS_PATTERNS` | guard | extra commands to block, one extended regex per line |
| `KIT_PROTECTED_PATHS` | guard, baseline | paths nobody may read or change (root config only); see [Protect paths](#protect-paths) |

Commands can call helpers the adapter ships in `.claude/bin/` through `$KIT_BIN`, for example `KIT_COVERAGE_FILES="node \"\$KIT_BIN/coverage-files.mjs\""`.

The kit ships two adapters: `typescript` (npm or pnpm, Vitest, Biome or Prettier) and `python` (uv, Ruff, mypy or pyright, pytest with pytest-cov). Python has no "related tests" mode, so the adapter's `pytest-related` helper runs `test_<name>.py` for each edited source file, and the whole suite when there is none.

Check the adapter by hand before relying on it: `.claude/bin/check typecheck`, `.claude/bin/check test-related <a source file>`, and then a deliberate type error, which must make the first one fail.

For CI, copy an adapter's `.github/workflows/quality-gates.yml` and replace the setup and install steps. Everything else goes through `.claude/bin/check --against-baseline`, so it carries over unchanged, including the coverage gate, which only needs `KIT_COVERAGE_FILES` and `KIT_COVERAGE_PCT`.

## Monorepos

A package with its own toolchain gets its own `<package>/.claude/kit.conf`. Each file is checked with the nearest config, from that package's folder and with its path relative to it; the root's `.claude/kit.conf` is the fallback. `check <name>` without files runs the check in every package that configures it. The hooks use the package's source, test and dangerous patterns too. `/onboard` sets this up.

## Onboard an existing repository

Install the project files (`./install.sh <repo>`, without an adapter), start Claude Code in the repository and run `/onboard`. It scans the repository, records `.claude/baseline.tsv` (every test ID with its result, lint and type errors per file, overall coverage), and proposes the configs, project facts, rules and protected paths. It writes only under `.work/onboard/`; after you approve, `.claude/bin/onboard-apply` copies the files into place.

With a baseline, `.claude/bin/check --against-baseline <test|lint|typecheck|coverage>` (and CI) blocks only new problems:

- **Tests:** a test that passed in the baseline, or a new test, must pass. A failure gets one rerun of the suite; a test that passes on it is reported as flaky. Known failures are reported as "legacy, not blocking". A test may only disappear when the diff removes it from a test file.
- **Lint and typecheck:** no error in a changed file, and no more errors elsewhere than in the baseline. The errors are read from `file:line` output; a tool that fails without such lines blocks.
- **Coverage:** the changed source files must reach `KIT_COVERAGE_THRESHOLD`, and overall coverage may not drop by more than `KIT_COVERAGE_TOLERANCE`.

After legacy failures are fixed, `/onboard --refresh` records a stricter baseline. `onboard-apply` refuses a looser one unless you pass `--accept-looser`.

## Protect paths

For code the agent must never see, such as licence-restricted `ee/` folders, three layers work together. `/onboard` writes all three:

1. **The sandbox** (`sandbox.enabled` and `sandbox.filesystem.denyRead` in `.claude/settings.json`) blocks the path for every process a command starts. This is the only layer that holds against any command; the others are best effort.
2. **Deny rules** `Read(./<path>/**)` and `Edit(./<path>/**)` stop the file tools, and Claude Code applies Read denies to Grep and Glob as well.
3. **`KIT_PROTECTED_PATHS`** makes the guard block Read, Edit, Grep and Glob calls into the path, commands that name it, and git commands that would print it (`git diff`, `git show`, `git log -p`) unless they exclude it: `git diff main...HEAD -- . ':(exclude)packages/ee'`.

## Route models by task

Dispatched agents run on a tier, and `.claude/kit.conf` maps tiers to models:

```sh
KIT_MODEL_FAST="haiku"       KIT_ROUTE_EXPLORE="fast"
KIT_MODEL_STANDARD="sonnet"  KIT_ROUTE_IMPLEMENT="standard"   # the plan may raise or lower it per task
KIT_MODEL_DEEP="opus"        KIT_ROUTE_TESTS="standard"
                             KIT_ROUTE_REVIEW="deep"
                             KIT_ROUTE_VERIFY="standard"
```

`/ship-feature` passes the model on every dispatch (`.claude/bin/route <role|tier>`), because the Agent tool's `model` parameter wins over an agent's frontmatter. That parameter takes aliases only, so the values must be `sonnet`, `opus`, `haiku` or `fable`. The plan gives each task a Tier; a task that fails its checks once is retried one tier higher, and deep stays deep. The reviewer never runs below the highest tier an implementer used. Spec, plan and PR description run in the main session, on whatever model the session uses.

If `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is set, Claude Code runs every subagent on one model and ignores the routing; `/ship-feature` warns about it.

## Token usage and budget

The `usage` hook keeps `.work/<branch>/usage.tsv` (tokens per agent and model, read from the transcripts) and `agents.tsv` (which agent ran which task, from the dispatch description). `.claude/bin/usage report` shows the details, and `.claude/bin/usage line` gives the line for the PR description: tokens per tier, review rounds, escalations.

`KIT_BUDGET_TOKENS` sets a budget per branch, counted as input, output and cache writes (cache reads are cheap and would dwarf everything else). At 80 percent the hook tells Claude to report it; at 100 percent it blocks the next dispatch, and `/ship-feature` stops and asks.

## Measure lead time

`.claude/bin/leadtime` reads merged pull requests through `gh` (one GraphQL query, its built-in `--jq`) and `git`, and reports the median and p75 per period:

| Metric | From | To |
|---|---|---|
| Lead time for changes | first commit of the PR | merge |
| PR cycle time | ready for review (drafts count from then) | merge |
| Time to first review | ready for review | first review or comment by someone other than the author or a bot |
| Review rounds | | "changes requested" plus commits after the first review |
| Spec to merge | the spec's first `approved` in `specs/README.md` (matched by the Branch column) | merge |
| Rework rate | | share of PRs followed within 14 days by a fix PR (label `bug` or `fix`, or a title starting with `fix` or `revert`) touching the same files |
| PR size | | changed lines |

`/onboard` runs `leadtime --baseline` once, which freezes the 90 days before that day in `reports/lead-time-baseline.md` and `.csv`. Later runs cover the time since then and show the baseline and the change next to each number. `--split-by kit` compares PRs with an evidence pack against PRs without, in the same period, which is the fair comparison for a repository without history. Bots and dependency PRs are left out; below ten PRs the report says the comparison is not reliable; with one contributor the review metrics are "n/a". The report names no PRs or people unless you pass `--with-titles`, and it says what changed, not why.

## Run records and improvement (optional)

Off by default. Set `KIT_IMPROVE="1"` in `.claude/kit.conf` to turn it on.

Every retry and stop in `/ship-feature` gets a line under Stops in `.work/<branch>.md`, whether this is on or not: `- <step> | <class> | <trigger> | <what was tried> | <resolution>`, with one of the classes `spec`, `plan`, `tier`, `test`, `kit`, `env`, `budget`. `/ship-feature` describes how each class is fixed.

With `KIT_IMPROVE` on, `/ship-feature` runs `.claude/bin/runs record` before the PR. It writes `reports/runs/<branch>.tsv`, which is committed with the PR: one `run` row (date, feature, branch, tasks, escalations, review rounds, tokens in total, per tier and in the main session, from `.claude/bin/usage tsv`) and one `stop` row per Stops line. One file per branch, so parallel PRs never conflict. Turned off, `runs record` writes nothing.

`.claude/bin/runs report` combines all records into `reports/runs.md`: median and p75 of tokens per run, tokens per task, the main session's share and review rounds, the escalation rate, and the stops by class with their text. Below five runs it says the numbers are not reliable. Cost is shown as tokens per tier, not money.

`/improve-kit` is the optional retrospective on top. It reads that report, `leadtime` when `gh` works, and `reports/improvements.md`, checks whether earlier changes moved their metric, and applies fixed rules: escalations above 25 % of tasks, no escalations over ten tasks, more than one review round in the median, the same `kit` stop twice, repeated `spec` or `plan` stops, any `env` or `budget` stop, a rising main-session share. Each rule has a minimum sample. It writes proposals to `.work/improve/<date>.md` and changes nothing until you approve; approved changes go on a `kit-improve-<date>` branch, with a test for every hook or check change, and an entry in `reports/improvements.md` naming the metric to judge them by.

## Block more commands

Add stack-specific destructive commands to `KIT_DANGEROUS_PATTERNS`, one extended regex per line. The guard removes quotes before matching, so `sh -c 'prisma migrate reset'` is caught as well.

For commands that should ask rather than be blocked, add a rule to `permissions.ask` in `.claude/settings.json`, for example `"Bash(terraform apply *)"`. Rules in `permissions.deny` beat `ask` and `allow` in every scope, so a developer cannot allow a denied command in their own settings.

Test every new pattern in `tests/hooks.test.sh`: one command that must be blocked and one similar command that must pass.

## Change the hooks

The hooks are in `.claude/hooks/` and registered in `.claude/settings.json`:

| Event | Script | Runs |
|---|---|---|
| `PreToolUse` (Bash, Read, Edit, Write, Grep, Glob) | `guard` | before every command and file access; exit 2 blocks it |
| `PostToolUse` (Edit, Write) | `record-edit` | after every edit; only notes the file, because it runs in parallel |
| `PostToolBatch` | `check-edits` | once per batch of tool calls: spec lint, format, typecheck, related tests |
| `Stop` | `summary`, `usage` | when Claude wants to end the turn |
| `PreToolUse`, `PostToolUse` (Agent), `SubagentStop` | `usage` | token record per agent, and the budget check before each dispatch |

Hooks registered for the same event run in parallel. Anything that must run in order, such as format before typecheck, belongs in one script, which is why `check-edits` exists. Add a step there rather than registering a new hook.

Hook scripts receive JSON on stdin. `lib.sh` has helpers to read it without `jq`. Keep the scripts POSIX `sh` so they work on macOS, Linux and in CI images.

## Run only the affected e2e tests

A whole e2e suite on every pull request is slow. With `KIT_E2E_RELATED` set (the TypeScript adapter sets it when the project has a Playwright config), `/verify-feature` and the CI `evidence` job run only the e2e tests a change affects. `.claude/bin/evidence e2e-select` prints the selection and why:

- **related**: the e2e files the change touches (`KIT_E2E_PATTERNS`), plus the e2e files that name a feature whose criterion IDs the diff adds. A diff that adds `SPLIT-AC5` runs every e2e file that mentions `SPLIT-AC…`. This is why test names start with their criterion.
- **all**: a file in `KIT_E2E_FULL_PATTERNS` changed (lockfile, `package.json`, Playwright config, shared fixtures), or code changed that no e2e test maps to.
- **none**: only tests and docs changed.

The selection can miss a feature whose code a change breaks without naming it. The `Full e2e` job in `evidence.yml` covers that: it runs `evidence data --all` after every merge to `main`, one run per merge, so a failure points at the merge that caused it. Add files your e2e tests share (helpers, page objects, global setup) to `KIT_E2E_FULL_PATTERNS`. For other runners, set `KIT_E2E_RELATED` to a command that takes test files as arguments (`uv run pytest`, `cypress run --spec` needs a comma list, so wrap it in a script).

## Change the CI thresholds

- `KIT_COVERAGE_THRESHOLD` in `.claude/kit.conf` (default 70): minimum line coverage of the source files a pull request changes. The same value applies locally and in CI.
- `MAX_CHANGED_LINES` in `.github/workflows/quality-gates.yml` (default 400): above this the job warns. Lockfiles and snapshots do not count.

## Turn on the sandbox

The guard and the deny rules match patterns, so a command that is written differently can get past them. Claude Code's sandbox restricts Bash at the operating-system level instead: file writes outside the project and network access to domains you have not allowed. It is off by default and the kit does not turn it on, because it changes how many tools behave; `/onboard` turns it on only for protected paths. To try it for one session:

```sh
claude --settings '{"sandbox": {"enabled": true, "allowUnsandboxedCommands": false}}'
```

`allowUnsandboxedCommands: false` stops Claude from retrying a blocked command outside the sandbox. By default Claude Code also runs commands without the sandbox when it cannot start (a missing dependency or an unsupported platform). Set `sandbox.failIfUnavailable` to `true` if the sandbox is meant as a hard boundary. On macOS, Go-based CLIs such as `gh` fail TLS verification inside the sandbox (`x509: OSStatus -26276`); `/onboard` adds `"gh *"` to `sandbox.excludedCommands` so `gh` runs outside it, and `gh pr create` still asks first. When it works for your stack, move the settings into `.claude/settings.json`. See the [sandboxing docs](https://code.claude.com/docs/en/sandboxing).

## Connect MCP servers

`.mcp.example.json` shows two servers. Rename it to `.mcp.json` to use it; Claude Code asks each developer once before starting a project's servers.

- **github** uses GitHub's remote server with read-only tools (`/mcp/readonly`), with a fine-grained token from the developer's environment (`GITHUB_PAT`). Claude can read issues and pull requests but not merge or comment.
- **db** uses DBHub with a connection string from `DATABASE_URL_READONLY`. Give it a database user that can only read. The read-only user is the protection; the MCP server does not enforce it.

Never write a token into `.mcp.json`. Use `${VAR}` references; the file is committed.

## Use it as a plugin

`kit/.claude` is also a Claude Code plugin named `agentic-workflow-kit`, listed in the repository's `.claude-plugin/marketplace.json`. The plugin carries the skills, the agents and the hooks; `install.sh --plugin` installs the rest. To change the workflow for every repository at once, fork this repository, change `kit/.claude`, bump `version` in `kit/.claude/.claude-plugin/plugin.json`, and point your team's marketplace at the fork.

Two differences from a project install:

- Plugin skills are called `/agentic-workflow-kit:ship-feature` and so on; the plain `/ship-feature` also works unless another command has that name. Plugin agents are named `agentic-workflow-kit:reviewer`. The skills in `kit/.claude` use the prefixed agent names; `install.sh` rewrites them to plain names for project installs.
- Plugin hooks run in every project where the plugin is enabled. The guard applies everywhere; the check hooks do nothing in a project without `.claude/bin/check`.

## Formatters and the kit's own files

Some formatters also format Markdown and JSON, and they may rewrite the kit's files after installation. That is harmless. If you want the kit's files left as shipped, exclude `.claude/`, `.work/` and `CLAUDE.md` in the formatter's ignore list. The installer's step 2 reminds you to run your formatter once over installed code such as the adapter's helpers in `.claude/bin/`.

## Patterns for later

Two patterns from larger setups that version 1 does not ship:

- **Version-pinned framework rules.** Generic "best practices" files go stale with every major version. Keep one rules file per framework and version (`nextjs-16.md`), generated from the framework's current docs and your own code, and replace it on upgrade. The presets here are hand-written examples of the result.
- **Evals for the workflow.** When the kit runs as a plugin, `claude plugin eval` runs a set of prompts with and without it and scores the results. A small set of realistic feature requests, each with the criteria a good spec must contain, shows whether a change to a skill made it better or worse.
