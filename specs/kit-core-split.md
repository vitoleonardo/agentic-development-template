# Kit core split

ID prefix: CORE

## Goal
One kit instead of two, with a core that a developer reads in ten minutes and extensions that a team installs one by one. The core keeps the five stamps in their lightest form: guard and check hooks, a spec with lint, a plan with lint, a test-first build with the three agents, a review in a fresh context, and the red and green runs as lines in the pull request. Everything else (evidence pack, autopilot, routing, run records, risk, stacks, onboarding of legacy repositories) becomes an extension: a Claude Code plugin in the kit's own marketplace, with its own scripts, hooks, skills, tests and `kit.conf` variables. `stempel-kit-next` is the base; `stempel-kit` is deleted once its tests pass against the new core.

## User flow
1. A developer installs the core in a project with one command and gets `.claude/` with the hooks, the three agents, the skills `spec-feature`, `plan-feature`, `ship-feature`, `fix-bug`, `pr-description`, `review-diff`, `write-tests`, a `kit.conf` with at most 10 variables, and a CI workflow.
2. The developer runs `/spec-feature`, `/plan-feature` and `/ship-feature` on a real ticket and gets a pull request whose body lists the red and green run per criterion. No extension is involved.
3. The team wants the evidence pack: `/plugin install stempel-kit-evidence`. The extension adds `/verify-feature`, the `evidence` script, the `kit-evidence` branch and its `KIT_*` variables to `kit.conf` under its own heading.
4. The team wants unattended builds: `/plugin install stempel-kit-autopilot`. The extension adds `autopilot`, `stack`, the `steer` and `summary` hooks and its variables.
5. Each further capability is one more plugin: `stempel-kit-routing`, `stempel-kit-improve`, `stempel-kit-risk`, `stempel-kit-onboard`.
6. The README fits on two screens: what the core does, the install command, the first feature, the list of extensions with one line each. Everything longer lives under `docs/`.
7. The kit's own eight features in review are merged first, then the split is built as a feature of the kit, with this spec, through `/ship-feature`.

## Terms
- **Core**: the plugin `stempel-kit` at `plugins/stempel-kit/kit/.claude`, after the split.
- **Extension**: a plugin listed in `.claude-plugin/marketplace.json` whose name starts with `stempel-kit-`, at `plugins/<name>/`.
- **Core shell**: every file under the core's `bin/` and `hooks/` that is not JSON.
- **Core variable**: a line in the core's `kit.conf` that starts with `KIT_`.
- **Extension section**: a block in the project's `kit.conf` that starts with `# extension: <name>` and ends at the next such line or the end of the file.
- **Install command**: `sh plugins/stempel-kit/install.sh <project> --adapter <adapter>`, or `/plugin install stempel-kit` followed by `install.sh --plugin`.

## Acceptance criteria

One kit:

- **CORE-AC1**: Given the repository after the split, when `ls plugins/` runs, then it lists `stempel-kit`, `repo-check` and the extensions, and no `stempel-kit-next`.
- **CORE-AC2**: Given `.claude-plugin/marketplace.json`, when it is read, then it lists `stempel-kit`, `repo-check` and one entry per extension, and no entry's description says "install this or that, never both".
- **CORE-AC3**: Given the core's `plugin.json`, when it is read, then its version is `1.0.0`.

Core size:

- **CORE-AC4**: Given the core shell, when `wc -l` runs over it, then the total is at most 1200 lines.
- **CORE-AC5**: Given the core's `kit.conf`, when the core variables are counted, then there are at most 10.
- **CORE-AC6**: Given the core's `bin/`, when it is listed, then it holds `check`, `gate`, `spec-lint`, `plan-lint`, `structure`, `conf.sh`, `criteria.sh`, `features.sh`, `json.sh` and no other file.
- **CORE-AC7**: Given the core's `hooks/`, when it is listed, then it holds `guard`, `check-edits`, `record-edit`, `lib.sh`, `hooks.json` and no other file.
- **CORE-AC8**: Given the core's `skills/`, when it is listed, then it holds `spec-feature`, `plan-feature`, `ship-feature`, `fix-bug`, `pr-description`, `review-diff`, `write-tests` and no other folder.

Core behaviour without extensions:

- **CORE-AC9**: Given a project with only the core installed, when `/ship-feature` builds an approved plan with two criteria, then the pull request body holds one line per criterion with the test name, its red run and its green run.
- **CORE-AC10**: Given a project with only the core installed, when `.claude/bin/gate push` runs, then it prints `ask` or `auto` and exits 0, without reading any variable that an extension defines.
- **CORE-AC11**: Given a project with only the core installed and `KIT_APPROVAL` unset, when `.claude/bin/gate level` runs, then it prints `strict`.
- **CORE-AC12**: Given a project with only the core installed, when a skill or hook references a script that an extension owns, then the reference is inside a block that starts with `If <extension> is installed` and the skill continues without it.

Extensions:

- **CORE-AC13**: Given the extension `stempel-kit-evidence`, when its folder is listed, then it holds `plugin/` with `bin/evidence`, `skills/verify-feature`, a `kit.conf.part` and `tests/`, and the core holds none of these.
- **CORE-AC14**: Given the extension `stempel-kit-autopilot`, when its folder is listed, then it holds `bin/autopilot`, `bin/stack`, `hooks/steer`, `hooks/summary`, `bin/status` and their tests, and the core holds none of these.
- **CORE-AC15**: Given the extension `stempel-kit-routing`, when its folder is listed, then it holds `bin/route`, `bin/usage`, `hooks/usage` and their tests.
- **CORE-AC16**: Given the extension `stempel-kit-improve`, when its folder is listed, then it holds `bin/runs`, `bin/leadtime`, `skills/improve-kit` and their tests.
- **CORE-AC17**: Given the extension `stempel-kit-risk`, when its folder is listed, then it holds `bin/risk`, the `risk.yml` workflow and their tests.
- **CORE-AC18**: Given the extension `stempel-kit-onboard`, when its folder is listed, then it holds `bin/baseline`, `bin/onboard-apply`, `skills/onboard` and their tests.
- **CORE-AC19**: Given an extension's `kit.conf.part`, when the extension is installed into a project, then the project's `kit.conf` gains one extension section with exactly the part's variables, and the core variables above it are unchanged.
- **CORE-AC20**: Given an extension installed twice, when the project's `kit.conf` is read, then it holds one extension section for that extension.
- **CORE-AC21**: Given an extension written in TypeScript or Python, when the kit's structure test runs, then it passes as long as the extension's `plugin.json` names its runtime under `requires`.
- **CORE-AC22**: Given the extension `stempel-kit-evidence` installed, when `/ship-feature` reaches the end of the build, then it dispatches `/verify-feature`; without the extension it writes the pull request body directly.

Tests and CI:

- **CORE-AC23**: Given the workflow `stempel-kit.yml`, when it runs, then it runs the core's tests and each extension's tests whose folder changed in the push, and no test that spends tokens.
- **CORE-AC24**: Given the workflow `agent-tests.yml`, when it is read, then it runs on a weekly schedule and on `workflow_dispatch`, runs the tests under `tests/*/run.sh` that spend tokens, and stops after `KIT_TEST_BUDGET_USD`.
- **CORE-AC25**: Given the repository after the split, when `sh plugins/stempel-kit/tests/run.sh` runs, then every test passes.

Docs:

- **CORE-AC26**: Given the root `README.md`, when its lines are counted, then there are at most 100.
- **CORE-AC27**: Given the root `README.md`, when it is read, then it holds the install command, the three commands of the first feature and a table with one row per extension.
- **CORE-AC28**: Given `plugins/stempel-kit/docs/SPEC-v1.1.md`, when it is read, then its first line says it is historical and names this spec.
- **CORE-AC29**: Given `specs/README.md` after the split, when it is read, then every row of the eight features that were in review on 07.11.2026 shows `done`.

## Edge cases
- **CORE-AC30**: Given a project whose `kit.conf` holds variables of an extension that is not installed, when `.claude/bin/check` runs, then it prints a warning naming the extension and exits 0.
- **CORE-AC31**: Given a project with `stempel-kit-next` installed from the old marketplace, when `install.sh --plugin` of the new core runs, then it prints that `stempel-kit-next` is retired, names the extensions that replace it, and changes no file.
- **CORE-AC32**: Given an extension removed with `/plugin uninstall`, when `.claude/bin/check` runs, then its extension section in `kit.conf` is still there and the warning of CORE-AC30 names it.
- **CORE-AC33**: Given two extensions that define the same `KIT_*` variable, when the second is installed, then the install stops with a message naming both extensions and the variable.

## Out of scope
- A catalog or search for extensions outside the kit's own marketplace.
- Presets that override core templates; the adapters stay what they are.
- Rewriting the core in another language.
- A Langfuse or observability extension; it follows as its own spec once the split is merged.

## Open questions

## Decisions
- 07.11.2026: `plan-lint` stays in the core as it is. The plan stamp is one of the five, and a lighter plan check would move the limit, not the work.
- 07.11.2026: The core holds guard, checks, spec, plan and ship with the three agents, so a developer gets a first pull request in 30 minutes without an extension. A core of only guard, checks and spec was considered and rejected for that reason.
- 07.11.2026: `stempel-kit-next` is the base of the split because it has the newer architecture; `stack` and `risk` become extensions rather than core.
- 07.11.2026: The core stays POSIX shell. Extensions may use TypeScript or Python, so a team can write its own; the runtime is declared in the extension's `plugin.json`.
- 07.11.2026: The eight features in review are merged before the split starts, so the split works on one state instead of eight branches.
- 07.11.2026: The limit for the core shell is 1200 lines, not 1000: the inventory on 07.11.2026 shows `guard` alone at 245 lines and the core scripts at about 700 before trimming. 1000 stays the aim for a later round.
- 07.11.2026: Extensions are Claude Code plugins in the kit's marketplace, not a kit-specific extension manager, because the plugin mechanism already does install, update and listing.
