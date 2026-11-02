# Agentic Development

Plugins and templates that make AI coding agents work like a disciplined team member: requirements written down before code, tests before features, an independent review, and gates in CI that hold the agent to what it promised. Built for [Claude Code](https://code.claude.com/docs), in plain Markdown, JSON and POSIX shell that live in your repository.

[![agentic-workflow-kit](https://github.com/vitoleonardo/agentic-development-template/actions/workflows/agentic-workflow-kit.yml/badge.svg?branch=main)](https://github.com/vitoleonardo/agentic-development-template/actions/workflows/agentic-workflow-kit.yml)
[![repo-check](https://github.com/vitoleonardo/agentic-development-template/actions/workflows/repo-check.yml/badge.svg?branch=main)](https://github.com/vitoleonardo/agentic-development-template/actions/workflows/repo-check.yml)
[![greenfield-nextjs](https://github.com/vitoleonardo/agentic-development-template/actions/workflows/greenfield-nextjs.yml/badge.svg?branch=main)](https://github.com/vitoleonardo/agentic-development-template/actions/workflows/greenfield-nextjs.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

## What's inside

| | What it is | For | Version |
|---|---|---|---|
| [**agentic-workflow-kit**](./plugins/agentic-workflow-kit/) | Plugin and installer | Existing projects in any language: spec-driven workflow, permissions, guard and check hooks, subagents, CI gates, onboarding for legacy repos, lead time measurement. Adapters for TypeScript and Python | 0.3.0 |
| [**repo-check**](./plugins/repo-check/) | Plugin or single-file prompt | Any repository: finds where delivery is jammed right now (writing, review or release), by a 10-minute interview or a strictly read-only scan. Sends nothing | 0.1.0 |
| [**greenfield-nextjs**](./templates/greenfield-nextjs/) | Template to copy | New Next.js apps built by several agents in parallel tracks, contract-first | 0.0.1 |

### Which one do I need?

- **You want to know where AI agents would help your team most:** start with `repo-check`. It takes ten minutes and changes nothing.
- **You have a codebase and want agents to work in it under rules:** install the `agentic-workflow-kit`.
- **You start a new web app from an empty repository:** copy `greenfield-nextjs`.

## Quick start

Install the plugins from this repository's marketplace inside Claude Code:

```text
/plugin marketplace add vitoleonardo/agentic-development-template
/plugin install repo-check@agentic-development-template
/plugin install agentic-workflow-kit@agentic-development-template
```

`/repo-check` then runs the assessment. The kit also needs its project files (rules, permissions, check commands) in each repository, because plugins cannot ship those:

```sh
git clone https://github.com/vitoleonardo/agentic-development-template
cd agentic-development-template/plugins/agentic-workflow-kit
./install.sh ~/code/my-app --adapter typescript --preset nextjs
```

Without the plugin, `install.sh` installs everything, skills and hooks included. The [kit's README](./plugins/agentic-workflow-kit/README.md) covers the options, existing repositories and updates.

Requirements: Claude Code (tested with 2.1.309), git and a POSIX shell. The TypeScript adapter needs Node 20.9+, the duplicates gate [jscpd](https://github.com/kucherenko/jscpd) 5.

## Repository layout

```text
.claude-plugin/            marketplace: lists both plugins
plugins/
  agentic-workflow-kit/    kit/ (what gets installed), adapters/, install.sh, tests/, docs/, examples/demo-app/
  repo-check/              plugin/, the generated single-file prompt repo-check.md, build, tests/, docs/
templates/
  greenfield-nextjs/       contracts, coordination files, workflows and validators for a new app
.github/workflows/         one CI workflow per product
```

## How it is tested

Every product has its own CI workflow that runs on each pull request and on `main`:

- **agentic-workflow-kit:** shellcheck over every script, ten test suites (hooks, spec lint, installer, checks and baseline, evidence pack, routing, lead time, run records, structure map, autopilot), and eight of them again under `dash`. The demo app is installed with the kit and must pass spec lint, typecheck, lint, tests, coverage and build.
- **repo-check:** shellcheck, the read-only hook, the scanner, and a drift test that fails when the single-file prompt or the bundled `leadtime` differs from its source. All under `dash` as well.
- **greenfield-nextjs:** shellcheck over the scripts, and the naming, docs, contract and design validators on the untouched template.

What the tests and real end-to-end runs caught while building each product is in its build log: [kit](./plugins/agentic-workflow-kit/docs/build-log.md), [repo-check](./plugins/repo-check/docs/build-log.md). The specifications behind them are next to the logs. Every change to the kit after a real run is in its [improvements log](./plugins/agentic-workflow-kit/reports/improvements.md), with the metric it should move and the value before, and `/improve-kit` checks each one after three more runs. What the tools cannot do is under the kit's [limits](./plugins/agentic-workflow-kit/README.md#limits).

## Security

The kit's guard hook and permissions reduce risk; they are not a sandbox. See [SECURITY.md](./SECURITY.md) for how to report a vulnerability, and the kit's [limits](./plugins/agentic-workflow-kit/README.md#limits).

## Support and consulting

These tools come from consulting work on agentic software delivery: workshops, pilots, ongoing support and feature sprints with agents.

Not sure whether that fits? Paste [repo-check.md](./plugins/repo-check/repo-check.md) into Claude Code. Ten questions, about ten minutes, nothing is sent; it shows where your delivery is jammed and ends with an email draft you can send or ignore.

- Email: [hi@vito.koeln](mailto:hi@vito.koeln)
- Book a free 20-minute call: [calendar.app.google/N14WVsxK4fdqBhZv6](https://calendar.app.google/N14WVsxK4fdqBhZv6)
- Web: [vito.koeln](https://vito.koeln/)

Bugs and feature requests: [GitHub Issues](https://github.com/vitoleonardo/agentic-development-template/issues).

## License

MIT. See [LICENSE](./LICENSE).
