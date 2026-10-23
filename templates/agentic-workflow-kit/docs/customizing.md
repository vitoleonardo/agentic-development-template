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

## Add a stack preset

Presets are rules for one framework, in `adapters/<adapter>/presets/<name>.md`, with a `paths:` header for the framework's files. `install.sh --preset <name>` copies them to `.claude/rules/`. The TypeScript adapter has `nextjs`, `nestjs` and `node`.

Write down what the model gets wrong for your version of the framework, not a tutorial. The Next.js preset, for example, says that request APIs such as `cookies()` are async and that `middleware.ts` is now `proxy.ts`, because models trained on older versions get both wrong.

## Add an adapter

An adapter tells the kit how your stack typechecks, lints, tests and formats. It is a folder in `adapters/` whose files are copied over the core, usually just `.claude/kit.conf`, a rules file and a CI workflow.

`.claude/kit.conf` is sourced by POSIX `sh`. Each value is a command; leave a value empty if the project has no such check, and `.claude/bin/check` then reports "not configured" instead of failing.

| Variable | Used by | Gets |
|---|---|---|
| `KIT_TYPECHECK` | hooks, `/ship-feature`, CI | nothing |
| `KIT_LINT` | `/ship-feature`, reviewer, CI | nothing |
| `KIT_TEST` | `/ship-feature`, reviewer, CI | nothing; must fail when zero tests run |
| `KIT_TEST_RELATED` | hooks, implementer, test-writer | the edited files; runs only the tests that cover them |
| `KIT_COVERAGE` | CI | nothing; writes `coverage/coverage-summary.json` (Istanbul json-summary) for the changed-lines gate |
| `KIT_FORMAT` | hooks | the edited files |
| `KIT_BUILD` | `/ship-feature`, CI | nothing |
| `KIT_SOURCE_PATTERNS` | hooks | shell patterns of files that trigger the checks, for example `*.py` |
| `KIT_TEST_PATTERNS` | guard | shell patterns of the files the test-writer may edit |
| `KIT_DANGEROUS_PATTERNS` | guard | extra commands to block, one extended regex per line |

A starting point for a Python project with uv, Ruff, mypy and pytest (not tested by the kit yet):

```sh
KIT_TYPECHECK="uv run mypy ."
KIT_LINT="uv run ruff check ."
KIT_TEST="uv run pytest"
# pytest has no "related tests" mode. The trailing # drops the file names the hook appends, so this runs the whole suite.
KIT_TEST_RELATED="uv run pytest -q #"
KIT_COVERAGE=""
KIT_FORMAT="uv run ruff format"
KIT_BUILD=""
KIT_SOURCE_PATTERNS="*.py"
KIT_TEST_PATTERNS="test_*.py *_test.py */tests/*"
KIT_DANGEROUS_PATTERNS='alembic[[:space:]]+downgrade[[:space:]]+base'
```

Running the whole suite after every batch of edits is fine for small projects. For larger ones, write a small script that maps edited files such as `src/foo.py` to `tests/test_foo.py` and point `KIT_TEST_RELATED` at it.

Check the adapter by hand before relying on it: `.claude/bin/check typecheck`, `.claude/bin/check test-related <a source file>`, and then a deliberate type error, which must make the first one fail.

For CI, copy `adapters/typescript/.github/workflows/quality-gates.yml` and replace the setup and install steps. Spec lint, the diff-size warning and the order of the steps carry over unchanged. The changed-lines coverage script reads the Istanbul `json-summary` format that JavaScript tools write. For other languages, replace that step with your coverage tool's own diff check, for example `diff-cover` for Python.

## Block more commands

Add stack-specific destructive commands to `KIT_DANGEROUS_PATTERNS`, one extended regex per line. The guard removes quotes before matching, so `sh -c 'prisma migrate reset'` is caught as well.

For commands that should ask rather than be blocked, add a rule to `permissions.ask` in `.claude/settings.json`, for example `"Bash(terraform apply *)"`. Rules in `permissions.deny` beat `ask` and `allow` in every scope, so a developer cannot allow a denied command in their own settings.

Test every new pattern in `tests/hooks.test.sh`: one command that must be blocked and one similar command that must pass.

## Change the hooks

The hooks are in `.claude/hooks/` and registered in `.claude/settings.json`:

| Event | Script | Runs |
|---|---|---|
| `PreToolUse` (Bash, Read, Edit, Write) | `guard` | before every command and file access; exit 2 blocks it |
| `PostToolUse` (Edit, Write) | `record-edit` | after every edit; only notes the file, because it runs in parallel |
| `PostToolBatch` | `check-edits` | once per batch of tool calls: spec lint, format, typecheck, related tests |
| `Stop` | `summary` | when Claude wants to end the turn |

Hooks registered for the same event run in parallel. Anything that must run in order, such as format before typecheck, belongs in one script, which is why `check-edits` exists. Add a step there rather than registering a new hook.

Hook scripts receive JSON on stdin. `lib.sh` has helpers to read it without `jq`. Keep the scripts POSIX `sh` so they work on macOS, Linux and in CI images.

## Change the CI thresholds

In `.github/workflows/quality-gates.yml`:

- `COVERAGE_THRESHOLD` (default 70): minimum line coverage of the source files a pull request changes.
- `MAX_CHANGED_LINES` (default 400): above this the job warns. Lockfiles and snapshots do not count.

## Turn on the sandbox

The guard and the deny rules match patterns, so a command that is written differently can get past them. Claude Code's sandbox restricts Bash at the operating-system level instead: file writes outside the project and network access to domains you have not allowed. It is off by default and the kit does not turn it on, because it changes how many tools behave. To try it for one session:

```sh
claude --settings '{"sandbox": {"enabled": true, "allowUnsandboxedCommands": false}}'
```

`allowUnsandboxedCommands: false` stops Claude from retrying a blocked command outside the sandbox. By default Claude Code also runs commands without the sandbox when it cannot start (a missing dependency or an unsupported platform). Set `sandbox.failIfUnavailable` to `true` if the sandbox is meant as a hard boundary. When it works for your stack, move the settings into `.claude/settings.json`. See the [sandboxing docs](https://code.claude.com/docs/en/sandboxing).

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

Some formatters also format Markdown and JSON, and they may rewrite the kit's files after installation. That is harmless. If you want the kit's files left as shipped, exclude `.claude/`, `.work/` and `CLAUDE.md` in the formatter's ignore list. The installer's step 2 reminds you to run your formatter once over installed code such as the CI script.

## Patterns for later

Two patterns from larger setups that version 1 does not ship:

- **Version-pinned framework rules.** Generic "best practices" files go stale with every major version. Keep one rules file per framework and version (`nextjs-16.md`), generated from the framework's current docs and your own code, and replace it on upgrade. The presets here are hand-written examples of the result.
- **Evals for the workflow.** When the kit runs as a plugin, `claude plugin eval` runs a set of prompts with and without it and scores the results. A small set of realistic feature requests, each with the criteria a good spec must contain, shows whether a change to a skill made it better or worse.
