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
| `Stop` | `summary` | when Claude wants to end the turn |

Hooks registered for the same event run in parallel. Anything that must run in order, such as format before typecheck, belongs in one script, which is why `check-edits` exists. Add a step there rather than registering a new hook.

Hook scripts receive JSON on stdin. `lib.sh` has helpers to read it without `jq`. Keep the scripts POSIX `sh` so they work on macOS, Linux and in CI images.

## Change the CI thresholds

- `KIT_COVERAGE_THRESHOLD` in `.claude/kit.conf` (default 70): minimum line coverage of the source files a pull request changes. The same value applies locally and in CI.
- `MAX_CHANGED_LINES` in `.github/workflows/quality-gates.yml` (default 400): above this the job warns. Lockfiles and snapshots do not count.

## Turn on the sandbox

The guard and the deny rules match patterns, so a command that is written differently can get past them. Claude Code's sandbox restricts Bash at the operating-system level instead: file writes outside the project and network access to domains you have not allowed. It is off by default and the kit does not turn it on, because it changes how many tools behave; `/onboard` turns it on only for protected paths. To try it for one session:

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

Some formatters also format Markdown and JSON, and they may rewrite the kit's files after installation. That is harmless. If you want the kit's files left as shipped, exclude `.claude/`, `.work/` and `CLAUDE.md` in the formatter's ignore list. The installer's step 2 reminds you to run your formatter once over installed code such as the adapter's helpers in `.claude/bin/`.

## Patterns for later

Two patterns from larger setups that version 1 does not ship:

- **Version-pinned framework rules.** Generic "best practices" files go stale with every major version. Keep one rules file per framework and version (`nextjs-16.md`), generated from the framework's current docs and your own code, and replace it on upgrade. The presets here are hand-written examples of the result.
- **Evals for the workflow.** When the kit runs as a plugin, `claude plugin eval` runs a set of prompts with and without it and scores the results. A small set of realistic feature requests, each with the criteria a good spec must contain, shows whether a change to a skill made it better or worse.
