# Build log

What the workflow and its tests caught while building the kit. Newest first.

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
