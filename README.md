# Stempel Kit

Plugins and templates that make AI coding agents work like a disciplined team member: requirements written down before code, tests before features, an independent review, and gates in CI that hold the agent to what it promised. Built for [Claude Code](https://code.claude.com/docs), in plain Markdown, JSON and POSIX shell that live in your repository.

[![stempel-kit](https://github.com/vitoleonardo/stempel-kit/actions/workflows/stempel-kit.yml/badge.svg?branch=main)](https://github.com/vitoleonardo/stempel-kit/actions/workflows/stempel-kit.yml)
[![repo-check](https://github.com/vitoleonardo/stempel-kit/actions/workflows/repo-check.yml/badge.svg?branch=main)](https://github.com/vitoleonardo/stempel-kit/actions/workflows/repo-check.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

## What's inside

| | What it is | For | Version |
|---|---|---|---|
| [**stempel-kit**](./plugins/stempel-kit/) | Plugin and installer | Existing projects in any language: spec-driven workflow, permissions, guard and check hooks, subagents, CI gates, onboarding for legacy repos, lead time measurement. Adapters for TypeScript and Python | 0.4.0 |
| [**stempel-kit-next**](./plugins/stempel-kit-next/) | Plugin and installer, under test | The kit's next version: one headless session and one stacked pull request per planned group of tasks, e2e and mutation tests once per stack, risk-ranked merges. Install this or the stable kit, never both | 0.4.1 |
| [**repo-check**](./plugins/repo-check/) | Plugin or single-file prompt | Any repository: finds where delivery is jammed right now (writing, review or release), by a 10-minute interview or a strictly read-only scan. Sends nothing | 0.1.0 |

### Which one do I need?

- **You want to know where AI agents would help your team most:** start with `repo-check`. It takes ten minutes and changes nothing.
- **You have a codebase and want agents to work in it under rules:** install the `stempel-kit`.

## Quick start

Install the plugins from this repository's marketplace inside Claude Code:

```text
/plugin marketplace add vitoleonardo/stempel-kit
/plugin install repo-check@stempel-kit
/plugin install stempel-kit@stempel-kit
```

`/repo-check` then runs the assessment. The kit also needs its project files (rules, permissions, check commands) in each repository, because plugins cannot ship those:

```sh
git clone https://github.com/vitoleonardo/stempel-kit
cd stempel-kit/plugins/stempel-kit
./install.sh ~/code/my-app --adapter typescript --preset nextjs
```

Without the plugin, `install.sh` installs everything, skills and hooks included. The [kit's README](./plugins/stempel-kit/README.md) covers the options, existing repositories and updates.

Requirements: Claude Code (tested with 2.1.309), git and a POSIX shell. The TypeScript adapter needs Node 20.9+, the duplicates gate [jscpd](https://github.com/kucherenko/jscpd) 5.

## Repository layout

```text
.claude-plugin/            marketplace: lists every plugin
plugins/
  stempel-kit/    kit/ (what gets installed), adapters/, install.sh, tests/, docs/, examples/demo-app/
  stempel-kit-next/  the kit's next version under test, same layout
  repo-check/              plugin/, the generated single-file prompt repo-check.md, build, tests/, docs/
.github/workflows/         one CI workflow per product
```

## How it is tested

Every product has its own CI workflow that runs on each pull request and on `main`:

- **stempel-kit:** shellcheck over every script, thirteen test suites (hooks, spec lint, plan lint, installer, checks and baseline, evidence pack, routing, lead time, run records, structure map, autopilot, status, fix-bug skill), and eleven of them again under `dash`. The demo app is installed with the kit and must pass spec lint, typecheck, lint, tests, coverage and build.
- **repo-check:** shellcheck, the read-only hook, the scanner, and a drift test that fails when the single-file prompt or the bundled `leadtime` differs from its source. All under `dash` as well.

What the tests and real end-to-end runs caught while building each product is in its build log: [kit](./plugins/stempel-kit/docs/build-log.md), [repo-check](./plugins/repo-check/docs/build-log.md). The specifications behind them are next to the logs. Every change to the kit after a real run is in its [improvements log](./plugins/stempel-kit/reports/improvements.md), with the metric it should move and the value before, and `/improve-kit` checks each one after three more runs. What the tools cannot do is under the kit's [limits](./plugins/stempel-kit/README.md#limits).

## Security

The kit's guard hook and permissions reduce risk; they are not a sandbox. See [SECURITY.md](./SECURITY.md) for how to report a vulnerability, and the kit's [limits](./plugins/stempel-kit/README.md#limits).

## Support and consulting

These tools come from consulting work on agentic software delivery: workshops, pilots, ongoing support and feature sprints with agents.

Everything in this repository stays open source. Teams that work with me also get Stempel Kit Pro, a private add-on with a cockpit for Claude Code (status line and pane for the feature and the autopilot run), playbooks for onboarding, rollout and measurement, and updates. It builds on the open kit and removes nothing from it; details on [vito.koeln](https://vito.koeln/).

Not sure whether that fits? Paste [repo-check.md](./plugins/repo-check/repo-check.md) into Claude Code. Ten questions, about ten minutes, nothing is sent; it shows where your delivery is jammed and ends with an email draft you can send or ignore.

- Email: [hi@vito.koeln](mailto:hi@vito.koeln)
- Book a free 20-minute call: [calendar.app.google/N14WVsxK4fdqBhZv6](https://calendar.app.google/N14WVsxK4fdqBhZv6)
- Web: [vito.koeln](https://vito.koeln/)

Bugs and feature requests: [GitHub Issues](https://github.com/vitoleonardo/stempel-kit/issues).

## License

MIT. See [LICENSE](./LICENSE).
