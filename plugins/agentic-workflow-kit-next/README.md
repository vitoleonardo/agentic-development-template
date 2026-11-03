# Agentic Workflow Kit for Claude Code

Claude Code writes code fast, but out of the box nothing makes it write down what "done" means, test before it builds, or keep away from `.env` and `git push --force`. Teams end up re-explaining the same rules in every session and reviewing diffs that were never checked against a requirement. This kit puts the rules, the workflow and the checks into the repository, so every session and every developer works the same way and the CI enforces what the agent promised.

![Claude Code with the kit: it pushes back on an edit that breaks an acceptance criterion, the hooks catch the failing test, and the guard blocks rm -rf](docs/assets/demo.gif)

## Before and after

| Without the kit | With the kit |
|---|---|
| The request lives in the chat and is gone after a restart | A spec in `specs/` with a user flow and numbered acceptance criteria. `spec-lint` rejects vague ones ("fast", "user-friendly") before anyone approves them |
| Claude decides how to build it while building it | A plan with the technical design and tasks in `.work/<branch>.md`, approved before any code |
| Tests come last, if at all | Each criterion gets a test that fails first; the red and the green run are recorded |
| "Done, all tests pass" without a test run | Hooks format, typecheck and run the related tests after every batch of edits, and the turn does not end quietly while they are red |
| Every session puts files somewhere else and writes a second copy of an existing helper | One Map of where each kind of code lives. The guard blocks a new file outside it; jscpd fails on code the branch copies, also with renamed variables |
| The author reviews its own work | A read-only reviewer in a fresh context checks the diff against every criterion |
| `cat .env`, `rm -rf`, `git push --force` are one approval click away | Denied by permissions, and a guard hook catches what the deny list misses (`sh -c '...'`, `/usr/bin/env`, `git -C x push -f`). Licence-restricted folders are closed by the sandbox |
| CI checks whatever someone remembered to configure | Spec lint, typecheck, lint, tests, coverage of the changed files, build, and a warning above 400 changed lines |

## Install in 60 seconds

Requirements: Claude Code (tested with 2.1.309), git and a POSIX shell. The core needs nothing else; the TypeScript adapter expects Node 20.9+. The duplicates check needs [jscpd](https://github.com/kucherenko/jscpd) 5 (tested with 5.4.2): `npm i -D jscpd@5.4.2` in TypeScript projects, the binary on PATH (`brew install jscpd`) for Python.

```sh
git clone https://github.com/vitoleonardo/agentic-development-template
cd agentic-development-template/plugins/agentic-workflow-kit
./install.sh ~/code/my-app --adapter typescript --preset nextjs
```

The installer never overwrites a file that is already in your project; it lists them so you can merge by hand (or rerun with `--force`, or with `--update`, see [Updating](#updating)). Then:

1. Fill in the "Project facts" section of `CLAUDE.md`.
2. Run `.claude/bin/check typecheck` (and `lint`, `test`, `build`, `duplicates`) once to see that the adapter found your commands.
3. Start `claude` in the project and accept the trust prompt. Until then Claude Code ignores the project's hooks and allow rules.
4. Make the `quality-gates` workflow a required status check.
5. TypeScript adapter only: `evidence.yml` fails a pull request whose head commit has no evidence pack from `/verify-feature` (bot PRs are skipped). Delete the file, or do not make it required, if not every PR goes through the kit.

Adapters: `typescript` and `python`. Projects in another language: install without `--adapter` and fill in the commands in `.claude/kit.conf`. See [docs/customizing.md](docs/customizing.md#add-an-adapter).

### Existing repositories

Install without an adapter (`./install.sh ~/code/legacy-app`), start `claude` there and run `/onboard`. It scans the repository, records a baseline of its checks in `.claude/baseline.tsv`, and proposes the stack config (one per package in a monorepo), the project facts, rules from the repository's own conventions, and protected paths. It writes nothing outside `.work/onboard/` until you approve; then `.claude/bin/onboard-apply` puts the files in place. From then on, tests that already failed are reported as legacy and do not block a pull request; new failures always do. See [docs/customizing.md](docs/customizing.md#onboard-an-existing-repository).

### As a plugin

For teams with many repositories, the skills, agents and hooks can come from a plugin, so an update reaches every repo at once:

```text
/plugin marketplace add vitoleonardo/agentic-development-template
/plugin install agentic-workflow-kit@agentic-development-template
```

Plugins cannot ship permissions, rules or `CLAUDE.md`, so each repository still needs the project files: `./install.sh ~/code/my-app --adapter typescript --plugin`. That installs everything except the skills, agents and hooks, and leaves the hooks out of `settings.json` so they do not run twice. The commands are then `/agentic-workflow-kit:ship-feature` and so on; the plain `/ship-feature` works too unless another command has that name.

### Updating

Pull the kit's repository, then run `./install.sh ~/code/my-app --update`. It uses the options of the last install, saved in `.claude/kit.manifest` with a checksum of every file the kit installed:

- A file the project has not changed is replaced with the kit's new version.
- A file the project has changed and the kit has too is kept. The kit's version goes to `.work/kit-update/`, and the installer prints a `diff` command for each one to merge by hand. `/onboard` writes `settings.json`, `kit.conf` and `CLAUDE.md`, so expect those there. The exception is the `permissions.ask` rules that the guard now decides per `KIT_APPROVAL`: they are removed from a changed `settings.json` in place, and the installer lists them.
- A file the kit has not changed is left alone, changed or not.

Projects installed before the manifest existed have no checksums yet. Their first update overwrites nothing and stages every file that differs from the kit. Commit `.claude/kit.manifest` with the update.

The duplicates gate needs `KIT_DUPLICATES`, `KIT_DUPLICATES_RELATED` and `KIT_SIMILAR` in `kit.conf`. If the update staged `kit.conf`, copy them from the adapter (or run `/onboard --refresh`); until then `/verify-feature` fails its duplicates gate.

## How a feature flows

```text
/ship-feature Invite colleagues to a team by email
  1. Spec       specs/invite.md: user flow, INVITE-AC1..n, edge cases, out of scope
                spec-lint + reviewer check it                    -> you approve*
  2. Plan       .work/<branch>.md: design, tasks, test per criterion   -> you approve*
  3. Build      implementer subagents, one task each: test red, code, test green
  4. Review     read-only reviewer: verdict per criterion, findings by severity
  5. PR         description with criteria and evidence           -> you push*
  6. Accept     you check it and set the status to done
```

\* With `KIT_APPROVAL=standard` the agent pushes and opens the PR itself, unless the branch changes auth or migration files (`KIT_PUSH_ASK_PATTERNS`). With `autonomous` it also approves the spec and the plan. Every decision it makes is listed under "Decisions to review" in the PR. See [docs/customizing.md](docs/customizing.md#choose-how-often-the-agent-asks).

To build a backlog of approved specs unattended, one fresh headless session per feature on stacked branches, run `.claude/bin/autopilot`. See [docs/customizing.md](docs/customizing.md#run-a-backlog-unattended).

Every step leaves a file, so a new session continues where the last one stopped. The steps also run on their own: `/spec-feature`, `/plan-feature`, `/write-tests`, `/review-diff`, `/pr-description`. Small fixes may skip the spec, but not the test.

## What is included

| Part | Files | What it does |
|---|---|---|
| Project guide | `CLAUDE.md` | Project facts, the flow above, working agreements ("ask, don't fill gaps", "stop after two failed fixes") |
| Rules | `.claude/rules/*.md` | Structure (the Map of where code lives), architecture, testing, security, code style, git, output (short answers and PRs). Stack rules load only for matching files |
| Permissions | `.claude/settings.json` | Read-only git and the checks run without asking. Installs, pushes, CI, lockfiles, migrations and infra ask. Secrets, `rm -rf`, force push, network tools are denied |
| Hooks | `.claude/hooks/` | `guard` blocks destructive commands and secret files and keeps agents in scope. It also blocks writing a new source file outside the Map. `record-edit` and `check-edits` run format, typecheck, related tests and the duplicates check after each batch of edits. `summary` lists changed files and check results, and holds the turn once while a check is red |
| Skills | `.claude/skills/` | `/ship-feature`, `/spec-feature`, `/plan-feature`, `/write-tests`, `/review-diff`, `/verify-feature`, `/pr-description`, `/onboard`, and the optional `/improve-kit` |
| Subagents | `.claude/agents/` | `implementer` (one task, test first), `test-writer` (may only edit test files), `reviewer` (read-only, specs and diffs) |
| Status | `.claude/bin/status` | The current branch's feature in one line (stage, tasks, red checks, budget) or as JSON with criteria, sections, evidence and the autopilot run. Writes nothing |
| Lead time | `.claude/bin/leadtime` | Lead time, cycle time, time to first review, review rounds, spec to merge, rework and PR size from GitHub, before and after the kit, without names by default |
| Model routing | `.claude/bin/route`, `.claude/bin/usage`, `hooks/usage` | Each dispatched agent runs on a tier (fast, standard, deep) from `kit.conf`; tokens per agent and an optional budget per branch |
| Run records (optional) | `.claude/bin/runs`, `/improve-kit` | Off until `KIT_IMPROVE` is set. One record per feature in `reports/runs/` (tokens per tier, escalations, review rounds, every stop with its cause); `/improve-kit` turns them into proposed changes to the kit, applied only after approval |
| Check runner | `.claude/bin/check`, `.claude/kit.conf` | One entry point for typecheck, lint, test, related tests, coverage, format, build, duplicates and similar functions. The adapter fills in the commands; a package in a monorepo can have its own config |
| Baseline | `.claude/bin/baseline`, `.claude/baseline.tsv` | `check --against-baseline` blocks only new failures: tests by ID, lint and type errors per file, coverage. `/onboard` records it for existing repositories |
| Structure | `.claude/bin/structure`, `.claude/rules/structure.md` | Hard gate: every new source file sits in a home of the Map, and no file is named `utils`, `helpers`, `common` or `misc`. `/onboard` writes the Map from the repository |
| Spec lint | `.claude/bin/spec-lint` | Hard gate for acceptance criteria: IDs, Given/when/then, one result per criterion, no vague words, required sections, no open questions once approved |
| CI | `.github/workflows/quality-gates.yml` (each adapter) | Spec lint, typecheck, lint, tests, coverage of the changed files (70%), build, duplicates, structure, diff size warning, all against the baseline |
| MCP example | `.mcp.example.json` | GitHub (read-only tools) and a database through a read-only user. Not active until you rename it |
| Demo | `examples/demo-app/` | A small Next.js 16 app with a spec and tests to try everything on |

The kit is language-neutral at its core. It ships and tests two adapters: TypeScript, with presets for Next.js, NestJS and plain Node, and Python with uv.

## Try it on the demo app

[examples/demo-app/README.md](examples/demo-app/README.md) takes about five minutes: install the kit into a copy of the demo, run `/ship-feature`, break a test on purpose, and watch the guard block `rm -rf`.

## Docs

- [Team playbook](docs/team-playbook.md): rolling the kit out to a team in one week, day by day
- [Customizing](docs/customizing.md): rules, presets, adapters, hooks, the sandbox, MCP servers
- [Build log](docs/build-log.md): what the kit's own tests and end-to-end runs caught while building it
- [Specification v1.1](docs/SPEC-v1.1.md): onboarding, the evidence pack, model routing and lead time

## Limits

- Hooks and permissions reduce risk; they are not a sandbox. A determined command can still get past a pattern list. For OS-level isolation, turn on the [sandbox](docs/customizing.md#turn-on-the-sandbox).
- In a folder you have not trusted, Claude Code ignores the project's hooks and allow rules. Deny rules still apply.
- The hooks run the typecheck after every batch of edits, so a slow typecheck slows every turn. Point `KIT_TYPECHECK` at an incremental command if that hurts.

## License

MIT. See [LICENSE](../../LICENSE).

---

Need this tailored to your codebase, your stack and your team? Run [repo-check](../repo-check/) first: ten questions, nothing sent, and it ends with an email draft. Or [book a free 20-minute call](https://calendar.app.google/N14WVsxK4fdqBhZv6), or write to [hi@vito.koeln](mailto:hi@vito.koeln).
