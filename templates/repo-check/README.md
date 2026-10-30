# repo-check

Find where your team's delivery is jammed right now: **Schreiben**, **Review** or **Release**. Once agents write code faster, the jam moves downstream ("Der Stau wandert"). repo-check shows where it sits today, three steps you can take alone, and honestly whether one of my offers fits, or none yet.

It works in any repository. It does not need the [agentic-workflow-kit](../agentic-workflow-kit/), and it sends nothing.

## Two ways to run it

| | Plugin | Single-file prompt |
|---|---|---|
| Install | `/plugin marketplace add vitoleonardo/agentic-development-template`, then `/plugin install repo-check@agentic-development-template` | paste [repo-check.md](./repo-check.md) into Claude Code |
| Interview (10 questions, about 10 minutes) | yes | yes |
| Scan | full: file contents of config and docs, git history, and GitHub review numbers if you allow `gh` | reduced: git history and file names only |
| Read-only | enforced by a hook | instructions only; keep Claude Code's permission prompts on |
| Report | `.repo-check/report.md`, ignored by git | in the chat |

Run `/repo-check interview`, `/repo-check scan`, or `/repo-check` to be asked.

## What it never does

- It never writes outside `.repo-check/`, which carries its own `.gitignore`, so `git status` stays clean.
- It never runs install, build, test, lint, seed or migration commands. It only runs read-only `git` commands and its own scanner.
- It never reads `.env` files, keys or anything that looks like a secret, and never prints code.
- It never calls `gh` unless you agree, and then only read-only. Claude Code asks you again before it runs.
- It never sends anything. At the end you get an email draft, a mailto link and a booking link, and you decide what to do with them.

The plugin's `read-only` hook enforces this. The skill registers it on its first tool call and marks the session, and the plugin-wide copy keeps the mark after a resume. From then on the session stays read-only, so start a new session for other work. Sessions that never ran `/repo-check` are not affected. `allowed-tools` in the skill only saves permission prompts; it restricts nothing.

## Development

- Spec: [docs/SPEC-repo-check.md](./docs/SPEC-repo-check.md). Build log: [docs/build-log.md](./docs/build-log.md).
- `plugin/skills/repo-check/SKILL.md` is the source for the questions, rules and tables. `./build` generates `repo-check.md` from it (and from `prompt/repo-check.md.in`), and copies the kit's `leadtime` into the plugin. Never edit the generated files by hand; `tests/prompt.test.sh` fails if they drift.
- Tests: `sh tests/hook.test.sh`, `sh tests/scan.test.sh` and `sh tests/prompt.test.sh`, also under `dash`. They run in CI (`.github/workflows/repo-check.yml`). `sh tests/run.sh` is a headless end-to-end run on the demo app; it spends tokens and is not part of CI.
