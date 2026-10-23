# Build log

What the workflow and its tests caught while building the kit. Newest first.

## 23.10.2026: release checks

Sanitization checklist from the spec, run on `main` after the merge (e0398f0), including the full git history:

- [x] No client or project names: 0 matches in the tree and in `git log -p --all`.
- [x] No business logic, domain models or code from client projects: the demo is a generic expense splitter written for the kit.
- [x] No internal URLs, hostnames, API keys, tokens or emails in tracked files (pattern search for tokens, private keys, private IP ranges and internal domains; the only addresses are `ci@example.invalid` and the commit trailer). Commit metadata carries the author's own addresses.
- [x] Rules rewritten in generic terms.
- [x] `references/` never committed: 0 paths in the history; it is in `.gitignore`.

Delivered (spec §5): `CLAUDE.md` and rules, permissions, 4 hooks, 6 skills, 3 subagents, CI gates, MCP example, plugin and marketplace, README with GIF, team playbook, customizing guide, demo app, this build log, MIT license. `main` requires the kit's CI. Open for later: the booking link points to the GitHub profile until a booking page exists.

## 23.10.2026: leftovers (interactive run, GIF, repository CI)

- **Interactive run in a trusted folder** (Claude Code 2.1.309, manual permission mode). The trust dialog listed the kit's 9 allow rules. `.claude/bin/check test` ran without a prompt, `cat .env` was refused with the security rule as the reason, and `git push` stopped for approval. An edit that broke SPLIT-AC2 was formatted, typechecked and tested by the hooks; the Stop hook held the turn once and the summary listed the red check.
- **The rules work before the hooks do.** For the GIF (Sonnet, user settings left out), Claude refused the breaking edit at first and quoted SPLIT-AC1 and SPLIT-AC2. Only after "make the edit anyway" did the hook clip happen. The guard then blocked `sh -c "rm -rf src"` and Claude declined to work around it.
- **The recording found a CI failure in waiting.** `biome check` in the demo flagged the installed `.mcp.example.json` and the coverage script. The JSON now ships wrapped so any formatter accepts it. The script's line width is the project's choice, so the demo README and CI run the formatter once, as installer step 2 says.
- **`/ship-feature` end to end through the plugin** (Sonnet, headless, three turns, `--plugin-dir`). It extended the spec with SPLIT-AC7 to AC9, and the reviewer's spec pass led to four fixes. It wrote the plan and, after approval, built it on a branch with `agentic-workflow-kit:implementer` subagents, one commit per task. It ran the reviewer, set the status to `in-review`, and stopped before pushing.
- **The Stop hook trusted stale results.** In that run the last hook-run typecheck was the intended red one (a test importing a function that did not exist yet), so Stop kept reporting it as failing after Claude's own runs were green. Stop now re-runs each red check once on the turn's files and blocks only if it is still red. New test; its timeout went from 10 to 300 seconds.
- **The adapter's `quality-gates.yml` ran unchanged** under `act` 0.2.89 (`catthehacker/ubuntu:act-latest`). It ran on a pull request made of the commits `/ship-feature` produced through the plugin. Every step passed: 72 changed lines, spec lint, typecheck, lint, 20 tests, coverage on changed files and build. It warned that `split-form.tsx` is not in the coverage report, which is true (the demo has no component tests) and is what the warning is for.
- **`main` now requires the repository's CI** (`Kit tests`, `Demo app gates`). The workflow lost its path filters, because a required check that never runs blocks every pull request that does not touch the kit.
- **Small fix:** the Stop message said "still failing: test-related ." and now lists checks with commas.
- **Repository CI** (`.github/workflows/agentic-workflow-kit.yml`): ShellCheck, the three test suites (also under `dash`), and the TypeScript gates on the demo app with the kit installed. Simulated locally first; actionlint and ShellCheck are clean. The first real run on GitHub Actions (PR #1) passed: kit tests in 11 s, demo gates in 18 s.

## 23.10.2026: Phase 4 (plugin, docs, MCP example)

- **`kit/.claude` is the plugin.** It needed only `.claude-plugin/plugin.json` and `hooks/hooks.json`, so nothing is duplicated. `claude plugin validate` passes for the plugin and for the repository's marketplace. `install.sh --plugin` installs only the project files and removes the hooks from `settings.json`, so they do not run twice. Installer tests: `tests/install.test.sh`, 13 cases.
- **The name `claude-kit` is reserved for plugins.** The validator refuses names starting with `claude-`, so the plugin was first called `agentic-workflow`. The kit is now `agentic-workflow-kit`, for the folder and the plugin alike.
- **Forked skills lost their agent inside the plugin.** Headless with `--plugin-dir`: `/review-diff` ran as `general-purpose`, not as the read-only reviewer, because a plugin's agents are named `agentic-workflow-kit:reviewer`. With the prefixed name in the skill, the reviewer ran, and the guard blocked its chained commands 8 times. The installer rewrites the names back to plain ones for project installs.
- **Also verified through the plugin:** the guard blocked `rm -r -f src/app`, and a broken edit was caught by the check hooks. The Stop hook then made Claude explain why the test stayed red.
- **Writing the README found a guard gap.** `git push -f origin main`, `git push -uf` and `git -C x push -f` passed the guard, because the pattern expected a second space before the flag. The deny list caught the plain form, but not the other two. Fixed, with 4 new tests (65 in total).
- **`/ship-feature` read its sub-steps from `.claude/skills/...`,** which does not exist in plugin installs. It now uses `${CLAUDE_SKILL_DIR}/../<skill>/SKILL.md`, which works in both.
- **Not done in this phase:** the README GIF, a real GitHub Actions run, an interactive run in a trusted folder, and an end-to-end `/ship-feature` through the plugin. See the entry above.

## 23.10.2026: acceptance-criteria gate, user flow, technical design

- **The gate has two layers.**
  - `.claude/bin/spec-lint` is a deterministic hard gate (shell and awk, any language). It checks: ID format and reuse, Given/when/then in order, one "then" per criterion, vague words, the required sections (Goal, User flow, Acceptance criteria, Edge cases, Out of scope), and no open questions once a spec is approved. It runs on every spec edit (hook), before approval in `/spec-feature`, and in CI. 19 tests.
  - The reviewer now also reviews specs for what a linter cannot judge: testability, missing cases, contradictions, scope.
- **The linter caught the demo's own spec on its first run:** no User flow, and the invalid-input criterion was not under Edge cases.
- **End to end with `/spec-feature`**, given the request "mark a transfer as paid so it works nicely and fast":
  - It called "nicely and fast" untestable, noticed the conflict with the existing "no saving between visits" scope, and asked five questions instead of guessing.
  - After the answers, spec-lint passed and the reviewer still found a real flaw. "The text field stays unchanged" would pass even after a reload, because browsers restore form text. It was rewritten to "no page navigation or network request".
  - A dropped criterion kept its ID as removed, and the model flagged its own additions (keyboard support) as proposals for the user to accept or reject.
- **The spec template now has a User flow section.** The plan template opens with a Design section: data, contract, permissions, states, decisions with alternatives.
- **Only the user sets `done`, after acceptance.**

## 23.10.2026: Phase 3 (CI gates, installer, demo app)

- **CI ran as designed.** The TypeScript adapter ships `quality-gates.yml`, which `actionlint` reports as clean. Locally simulated pull requests on the demo app:
  - a tested change passed (100% of changed lines covered);
  - a new untested file was blocked (0%);
  - a failing test was blocked and the 452-line diff got a warning.
- **One confusing error removed.** Vitest writes no coverage report when tests fail, so the changed-files step added a "summary not found" error on top. It now runs only after the tests pass.
- **`pnpm/action-setup` v6 now requires pnpm 11+.** The workflow installs the version from `packageManager` with npm instead, which is also one fewer third-party action.
- **Projects reformat the kit's files.** Biome 2.6 also formats Markdown and wanted to rewrite the kit's `CLAUDE.md`, and the project's line width flagged the CI script. The demo limits Biome to code files, the script ships Prettier-style, and the installer now says to run the formatter once.
- **`next build` rewrites `tsconfig.json`.** The demo ships the keys Next adds, so the tree stays clean.
- **Install from a copy took 0.1 seconds** and kept the demo's own `specs/README.md`.
- **`/ship-feature` ran end to end** (Sonnet, headless, four turns):
  - It extended the existing spec with SPLIT-AC7 to AC11 and asked two real questions.
  - After approval it wrote the plan; after that approval, two implementer subagents built the feature test first.
  - The verify log shows real red messages before green. One commit per task; then review, full checks, and a PR description. It stopped before pushing.
  - It reported honestly: AC10's tests were green before the change (unchanged error path), and the page layout was not checked.
- **Untrusted folders ignore command-line allowances.** In an untrusted folder `--allowedTools` was ignored like the allow list, so the build turns used `bypassPermissions` to stand in for a user approving the git prompts. The guard hook still ran. An interactive run in a trusted folder is still to do.

## 23.10.2026: Phase 2 (hooks, commands, agents)

Unit tests: `tests/hooks.test.sh`, 59 cases. End to end: Claude Code 2.1.309 (Haiku) on a scratch TypeScript project.

- **Parallel hooks would have raced.** The docs say hooks for one event run in parallel, and `PostToolUse` fires once per edit. So format, typecheck and tests became one ordered script on `PostToolBatch`, which runs once per batch of edits.
- **A broken edit is caught before the turn ends.** An edit that broke a test was formatted, typechecked and tested in one batch, and the failure was fed back to Claude. The Stop hook then held the turn open once while it was red. Claude explained why it left the test red (the request contradicted it), and the user saw the summary.
- **The guard caught what the deny list misses:** `head -n 1 .env`, `sh -c 'rm -rf src'`, `git push --force`.
  - The first version blocked every allowed command: a `while ... || block` construct took the last grep's "no match" as failure. Caught by the unit tests.
  - `head .env` was blocked for the wrong reason (the `env` pattern matched inside `.env`). Fixed, and a test now checks the reason text.
- **The test-writer stayed in scope.** It wrote only the test file, and its two new tests failed first. It was stopped from chaining commands. It was also blocked from `git -C <path> status` and from calling `check` by absolute path, which were harmless, so the allowlist was widened.
- **The reviewer caught its own author.** `/review-diff` found the unmet criterion, the missing test-name prefixes and the missing red-before-green record. It also noticed that a guard change had stopped catching `/usr/bin/env`. That was true; fixed with a test.
- **`.claude/` is write-protected.** Claude Code refuses file-tool writes to `.claude/` even in acceptEdits mode, so `/plan-feature` and `/pr-description` could not save to `.claude/state/`. State moved to `.work/`, which ignores itself through its own `.gitignore`. Re-tested: the plan was written and source files were untouched.
- **Headless tests need explicit settings.** In an untrusted folder Claude Code ignores both project hooks and the allow list. The tests pass `--settings .claude/settings.json`; real users accept the trust prompt once.
- **Not tested end to end yet:** `/spec-feature` (an interview) and `/ship-feature` (several approval gates). Both need an interactive session; planned for the demo-app test.

## 23.10.2026: language-neutral core

- Split into `kit/` (core) and `adapters/typescript/`. All checks go through `.claude/bin/check`, configured by the adapter's `.claude/kit.conf`.
- Tested on a scratch TypeScript project (npm, Vitest, Prettier): typecheck and related tests passed on clean code and both failed on a deliberately broken edit. The runner also formatted a file whose name has a space, worked from a subdirectory and under `dash`, detected pnpm from its lockfile, and exited 3 with a clear message when no adapter was installed.

## 23.10.2026: Phase 1 (rules, settings, presets)

Tested by copying `kit/` and the Next.js preset into an empty repo with a canary `.env`, then running Claude Code 2.1.309 headless.

- **The rules alone stopped the agent.** Asked to read `.env`, run `cat .env` and `rm -rf ./tmpdir`, it refused and cited `security.md`. So the rules reach the model, but that is behaviour, not enforcement.
- **Enforcement was tested separately.** Told to attempt the calls anyway, the harness blocked `Read(.env)`, `rm -rf` and `curl`.
- **`cat .env` only asked for approval.** The `Read(.env)` deny turned it into a prompt, not a denial, so one careless "yes" would have exposed the file. Fix: explicit `Bash(cat .env*)` and similar denies. Re-tested: denied.
- **Untrusted folders ignore `allow`.** Claude Code skips the whole `permissions.allow` list until the workspace trust dialog has been accepted once. The install guide must say so.
- **Path-scoped presets work.** `nextjs.md` was absent at session start and loaded as soon as `app/page.tsx` was read.
