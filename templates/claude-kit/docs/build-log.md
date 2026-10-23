# Build log

What the workflow and its tests caught while building the kit. Newest first.

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
