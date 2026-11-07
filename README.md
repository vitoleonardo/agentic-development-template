<p align="center">
  <a href="https://github.com/vitoleonardo/stempel-kit"><img src=".github/assets/stempel-kit.svg" alt="Stempel Kit: nothing ships without a stamp" width="900"></a>
</p>

<p align="center">
  <a href="https://github.com/vitoleonardo/stempel-kit/actions/workflows/stempel-kit.yml"><img alt="stempel-kit CI" src="https://github.com/vitoleonardo/stempel-kit/actions/workflows/stempel-kit.yml/badge.svg?branch=main"></a>
  <a href="https://github.com/vitoleonardo/stempel-kit/actions/workflows/repo-check.yml"><img alt="repo-check CI" src="https://github.com/vitoleonardo/stempel-kit/actions/workflows/repo-check.yml/badge.svg?branch=main"></a>
</p>

<h1 align="center">Stempel Kit</h1>

<p align="center"><strong>Nothing ships without a stamp.</strong></p>

Claude Code writes code fast. Out of the box, nothing makes it write down what "done" means, test before it builds, keep away from `.env` and `git push --force`, or prove its work before a pull request. Stempel Kit puts the rules, the workflow and the checks into your repository as plain Markdown, JSON and POSIX shell, so every session and every developer works the same way and CI enforces what the agent promised. Built for [Claude Code](https://code.claude.com/docs), MIT licensed.

A *Stempel* is a rubber stamp. Every feature collects five of them before it merges, and each one is a file or a check, not a chat message:

| Stamp | Who sets it | What it proves |
|---|---|---|
| **Spec approved** | `spec-lint`, the reviewer, you | A spec in `specs/` with a user flow and numbered acceptance criteria. Vague words ("fast", "user-friendly") are rejected before anyone approves |
| **Plan approved** | `plan-lint`, you | Every criterion has a task and a named test, new files sit in the Map, nothing is left as a placeholder |
| **Tests red, then green** | `test-writer`, `implementer`, the hooks | Each criterion gets a test that fails first. Format, typecheck, related tests and the duplicates check run after every batch of edits, and the turn does not end quietly while they are red |
| **Review passed** | `reviewer` | A read-only reviewer in a fresh context, with a verdict per criterion and findings by severity |
| **Evidence sealed, CI green** | `/verify-feature`, the quality gates | An evidence pack on the commit: red run, green run, edge-case matrix, coverage of the changed files. CI repeats spec lint, typecheck, lint, tests, coverage, build and duplicates, against a baseline in legacy repositories |

The core is small on purpose: the two hooks, the spec and the plan with their lints, `/ship-feature` with the three subagents, and the red and green runs as lines in the pull request. Everything else is an extension you install when the team wants it. [docs/workflow.md](./docs/workflow.md) walks through a feature; [docs/hooks.md](./docs/hooks.md) shows what runs around every tool call.

## Install

Inside Claude Code, add the marketplace and the core, then put the project files (rules, permissions, `kit.conf`, `CLAUDE.md`) into the repository:

```sh
/plugin marketplace add vitoleonardo/stempel-kit
/plugin install stempel-kit@stempel-kit
git clone https://github.com/vitoleonardo/stempel-kit
sh stempel-kit/plugins/stempel-kit/install.sh ~/code/my-app --adapter typescript --preset nextjs --plugin
```

Adapters: `typescript` (presets `nextjs`, `nestjs`, `node`) and `python`. Without `--plugin` the installer puts skills, agents and hooks into the project too. Then fill in "Project facts" in `CLAUDE.md`, run `.claude/bin/check typecheck` once, start `claude` in the project and accept the trust prompt. Requirements: Claude Code 2.1.309 or later, git, a POSIX shell.

## The first feature

```text
/spec-feature Invite colleagues to a team by email
/plan-feature invite
/ship-feature invite
```

The spec names what "done" means, the plan names a test per criterion, the build writes each test red before the code and ends with a pull request whose body lists the red and green run per criterion. The shipped `kit.conf` sets `KIT_APPROVAL=autonomous`: the build decides alone and lists every decision under "Decisions to review" in the PR; `standard` asks for the spec and the plan, `strict` (the level when the variable is unset) asks at every gate.

## Extensions

Each one is a plugin in the kit's marketplace: `/plugin install stempel-kit-<name>@stempel-kit`, then `sh stempel-kit/plugins/stempel-kit/install.sh ~/code/my-app --extension <name>` copies its scripts and its `kit.conf` section into the project.

| Extension | Adds |
|---|---|
| `stempel-kit-evidence` | `/verify-feature` and the evidence pack: hard gates, data runs, the edge-case matrix, screenshots, the `kit-evidence` branch. Needs `stempel-kit-onboard` |
| `stempel-kit-autopilot` | Unattended builds, one headless session per planned group, stacked pull requests per group (`stack`), the build status and steering. Needs `stempel-kit-routing` |
| `stempel-kit-routing` | A model per dispatched agent (`route`), the token usage record and a token budget per branch |
| `stempel-kit-improve` | Run records per branch, lead time for changes and `/improve-kit`, which proposes kit changes from them |
| `stempel-kit-risk` | Risk ranks for plans, pushes and stack layers, so at `autonomous` only a high rank asks a person; the `Risk` check on pull requests |
| `stempel-kit-onboard` | `/onboard` for existing repositories: scan, a baseline of every check so legacy failures never block a PR, the Map and rules from your own conventions |

[`repo-check`](./plugins/repo-check/) is a separate plugin: a ten-minute interview or a read-only scan that shows where delivery is jammed. Sends nothing.

## Security

The guard hook and the permissions reduce risk; they are not a sandbox. See [SECURITY.md](./SECURITY.md) and the kit's [limits](./plugins/stempel-kit/README.md#limits).

## Stempel Kit Pro, support and consulting

Everything here stays open source. Teams that work with me also get Stempel Kit Pro, a private add-on: a cockpit in Claude Code for the feature, its criteria, red checks, budget, evidence and the autopilot run, playbooks for onboarding, rollout and measurement, and twelve months of updates. Workshops in your own repository, pilots and feature sprints with agents: [hi@vito.koeln](mailto:hi@vito.koeln), a free 20-minute call at [calendar.app.google/N14WVsxK4fdqBhZv6](https://calendar.app.google/N14WVsxK4fdqBhZv6), details on [vito.koeln](https://vito.koeln/). Bugs and feature requests: [GitHub Issues](https://github.com/vitoleonardo/stempel-kit/issues).

## License

MIT. See [LICENSE](./LICENSE).
