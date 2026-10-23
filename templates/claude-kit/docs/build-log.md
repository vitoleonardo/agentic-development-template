# Build log

What the workflow and its tests caught while building the kit. Newest first.

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
