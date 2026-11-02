---
name: onboard
description: Turn an existing repository into a kit repository in one session - scan it, baseline its checks so legacy failures never block a PR, propose kit.conf, project facts, rules and protected paths, apply only after approval. Never changes application code.
argument-hint: [--refresh]
disable-model-invocation: true
---

# Onboard an existing repository

Arguments: $ARGUMENTS

Four passes, each ending with a file the user approves before the next starts. You write only to `.work/onboard/`; only `.claude/bin/onboard-apply`, which the user runs or approves, writes into the project.

## Rules

- **Never change application code.** The only files that may change are `.claude/`, `<package>/.claude/kit.conf`, `CLAUDE.md`, `specs/README.md`, `.claude/baseline.tsv`, and the CI workflow. Write the CI workflow only after asking.
- **Never run a command that writes application files.** `KIT_FORMAT` and `--fix` linters rewrite code: prove the formatter in check mode (`biome format <file>` without `--write`, `prettier --check`, `ruff format --check`) and stage the writing form. Leave seed, migration and build commands that change tracked files to the user.
- **Never guess a command.** Every command in a staged `kit.conf` ran successfully this session, or (a check failing on legacy code) ran and produced the failures you recorded. A command you could not run stays empty and the summary says "not configured". A check the project cannot have gets `n/a: <reason>`.
- **Stage, don't write.** Stage files under `.work/onboard/files/`, laid out as they will land, with every `.claude` folder named `dot-claude` (`.work/onboard/files/dot-claude/kit.conf`, `.work/onboard/files/ai-service/dot-claude/kit.conf`). Claude Code protects `.claude/` from file-tool writes on purpose; it keeps the baseline from loosening behind the user's back.
- **Existing guides stay the source.** An existing `CLAUDE.md` keeps its content and gains the kit's sections. An existing `AGENTS.md` is not copied: the staged `CLAUDE.md` gets the line `@AGENTS.md`. Never edit `AGENTS.md`.
- **Protected paths are never read.** The guard knows them only after apply; until then it is on you. Find candidates by folder name and licence files only (`LICENSE`, `README` at the folder's top); never open source files in a folder that looks licence-restricted, and keep it out of greps (`rg --glob '!<path>'`). Once the user names a path, do not open, grep or `git show` it, and exclude it from every git command (`-- . ':(exclude)<path>'`).

## 0. Before you start

- `.claude/bin/check`, `.claude/bin/baseline` and `.claude/bin/onboard-apply` must exist. If not, stop and tell the user to run `./install.sh <repo>` from the kit first (add `--plugin` if the skills come from the plugin); it keeps every existing file.
- Run `git status`. Start from a clean tree on the default branch's head, so the baseline describes the default branch.
- With `--refresh`: skip to pass 2, using the current `.claude/kit.conf` files and `.claude/rules/structure.md` as the staged files (copy them to `.work/onboard/files/…/dot-claude/`), add any key the kit's adapter has and they lack (such as `KIT_DUPLICATES`), and remember that `onboard-apply` will refuse a looser baseline.

## 1. Scan (read-only)

Detect, and write to `.work/onboard/scan.md` with the file each finding comes from:

- languages, package managers and lockfiles, workspace layout (pnpm workspaces, turbo, nx, a `pyproject.toml` per folder);
- scripts in `package.json` and `Makefile`; test frameworks and their configs; linters and formatters and their configs;
- where each kind of code lives now (entry points, feature logic, data access, shared UI, shared helpers, config, unit and e2e tests, scripts), with two example files each, and every kind that has more than one home;
- CI workflows; existing `CLAUDE.md`, `AGENTS.md`, `.cursor/rules`, `CONTRIBUTING.md`;
- docker compose files, seed scripts, e2e setups (Playwright, Cypress), migration folders;
- candidate protected paths: licence-restricted code (for example `ee/` folders with a separate licence), vendored code, generated code. List them; the user decides.

For a large repository, explore with parallel `Explore` subagents and keep their conclusions, not file dumps.

Then decide the packages. A folder with its own toolchain (its own `pyproject.toml`, or a different language) gets its own `<package>/.claude/kit.conf`; everything else uses the root's. Start each config from the kit's matching adapter (`adapters/typescript/.claude/kit.conf`, `adapters/python/.claude/kit.conf`) in the kit's clone; ask the user for its path once. Keep the adapter's keys and conditionals; change only what the repository does differently. Stage the adapter's other `.claude/` files too: `bin/` helpers (the coverage readers) to the root's `dot-claude/bin/`, its stack rule and structure map to `dot-claude/rules/`. The duplicates checks need jscpd 5 (a devDependency, or on PATH); ask before adding it, and if the user declines, set `KIT_DUPLICATES="n/a: <reason>"`. Run each command once from its package folder and fix it until it works or fails only on legacy code. Stage the configs.

Show the user the scan, the packages, the commands and the protected path candidates, and ask which paths to protect. Wait.

## 2. Baseline

Run, from the project root:

```sh
KIT_CONF_ROOT=.work/onboard/files KIT_CONF_DIR=dot-claude .claude/bin/baseline record --out .work/onboard/baseline.tsv
```

It runs every configured test, lint, typecheck and coverage command in every package, recording each test ID with its result (from the JUnit report in `KIT_TEST_REPORT`), lint and typecheck errors per file, and overall coverage. Report its summary lines as they are: tests run and failing per package, errors per check, coverage, and every warning (a check whose output could not be read is recorded as clean, so every error will block; say so).

Show the legacy failures; every PR reports them as "legacy, not blocking" until someone fixes them. Wait.

## 3. Proposal

Write `.work/onboard/proposal.md` and stage the files it describes:

1. **`kit.conf` per package**: final commands, `KIT_SOURCE_PATTERNS`, `KIT_TEST_PATTERNS`, `KIT_DANGEROUS_PATTERNS` (migration resets, destructive seed commands the repository has), and in the root config `KIT_PROTECTED_PATHS`.
2. **Project facts** for `CLAUDE.md` (product, stack, install and dev commands, what CI runs, human-only steps), merged into the staged `CLAUDE.md` as described in the rules.
3. **Structure map**: stage `dot-claude/rules/structure.md` from the adapter's (or the installed one), with its Map rewritten from the scan: each row gets the home the code already uses, as a path pattern, citing one or two files. Where a kind has several homes, the user picks the one for new code; the others go under `## Legacy`. Where a kind has none, keep the kit's default row.
4. **Rules** from the repository's own conventions (naming, error handling, import style), each citing the two or three files it came from, staged as `dot-claude/rules/project.md` (or one file per area). Do not restate the kit's rules.
5. **Protected paths** in the staged `dot-claude/settings.json`, merged with the kit's settings:
   - `sandbox.enabled: true` and `sandbox.filesystem.denyRead` with each path (`./apps/server/src/ee`). The sandbox enforces it for every process a command starts.
   - `"gh *"` in `sandbox.excludedCommands`: on macOS, `gh` cannot verify GitHub's TLS certificate inside the sandbox (`x509: OSStatus -26276`), so `gh pr create` fails. `gh pr create` and `gh pr merge` still ask in `permissions.ask`.
   - If code outside a protected path imports from it, typecheck and build must read it: add `.claude/bin/check`, `.claude/bin/check *`, `.claude/bin/baseline` and `.claude/bin/baseline *` to `sandbox.excludedCommands`, and say in the proposal that a compiler error inside the path prints its code.
   - `Read(./<path>/**)` and `Edit(./<path>/**)` in `permissions.deny`. The sandbox merges Read denies, and Claude Code applies them to Read, Grep and Glob as well.
   - `KIT_PROTECTED_PATHS` in the root config, which the guard uses for commands that name the path and for git commands that would print it.
   Say plainly in the proposal that without the sandbox these layers are best effort.
6. **`specs/README.md`** if the repository has none.
7. **CI**: whether the existing workflow should call `.claude/bin/check --against-baseline <test|lint|typecheck|coverage>`, or the adapter's `quality-gates.yml` should be added. Do not stage CI files unless the user agreed.

Show the proposal with the diff of every staged file against its current version. Wait for approval.

## 4. Apply

After approval, ask the user to run (or approve running) `.claude/bin/onboard-apply` and show its output. If it refuses a baseline looser than the current one, show the list and stop: only the user can pass `--accept-looser`.

Then prove the configuration:

- For each package, `.claude/bin/check test-related <one source file>` and `.claude/bin/check format <one source file>` (these take files), then `.claude/bin/check typecheck` and `.claude/bin/check build` (these take none).
- The full gates: `.claude/bin/check --against-baseline test`, `lint`, `typecheck` and `coverage`, plus `.claude/bin/check duplicates` and `.claude/bin/structure`. Each must pass on the unchanged default branch; a failure means the baseline, a command or the Map is wrong. Then run `.claude/bin/structure` with one made-up file name per Map home; each must pass.
- With PR history on GitHub, run `.claude/bin/leadtime --baseline` to freeze the "before" numbers (the 90 days before today) in `reports/`. It warns below ten merged PRs; a fresh fork has none, so the comparison comes from `--split-by kit` later.

Check the tools the gates rely on: `command -v gitleaks` (without it the secret gate only warns about `name = value` matches) and, for the TypeScript adapter, `node_modules/.bin/jscpd`. Each missing one is a setup gap.

Check the settings base runs and long runs rely on:

- `KIT_SETUP` empty while `KIT_SCREENSHOTS` or `KIT_TEST` is set: the base worktree has no dependencies, so base screenshots fail and the red check proves nothing. Setup gap; the fix is the install command.
- `KIT_BASE_ENV` empty while the project has an env template (`.env.example` or similar) and `KIT_SCREENSHOTS` is set: the base run lacks the variables the app validates at startup. Setup gap; the user creates an env file for base runs from the template with local values and points `KIT_BASE_ENV` at it. Never create or read it yourself.
- `KIT_BUDGET_TOKENS` empty: not a gap yet. Say runs have no token limit, and `/improve-kit` proposes one at the p75 of tokens per run after five runs.

Finish with a summary per `.claude/rules/output.md`: packages and their checks (configured, `n/a`, not configured), legacy failures, protected paths and the layers protecting them, setup gaps with the command closing each (`brew install gitleaks`, or the release binary on Linux), files written, and what the user still has to do (commit the files, accept the trust prompt, make CI a required check). Do not commit.
