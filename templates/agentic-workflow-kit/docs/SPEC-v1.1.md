# Agentic Workflow Kit: Specification v1.1

Status: draft, reviewed 27.10.2026 (decisions recorded in section 11). There is no written v1 specification in this repository; v1 is the shipped kit (`kit/`, `adapters/typescript/`, `install.sh`, `tests/`) and its history in `docs/build-log.md`. Everything v1 does stays valid unless this file says otherwise.

## 1. Why v1.1

v1 makes Claude Code follow rules and catches broken edits. It does not yet prove anything, and it only fits greenfield repos. v1.1 closes four gaps:

| # | Gap | Result |
|---|-----|--------|
| A | Onboarding for existing repos | `/onboard` turns a brownfield repo into a kit repo in one session, without blocking on legacy failures |
| B | Pre-PR verification with an evidence pack | `/verify-feature` runs after review and before the PR; the reviewer of the PR reads evidence instead of reproducing it |
| C | Model routing per task | each dispatched agent and each plan task runs on a declared model tier, with a recorded token count and a budget |
| D | Lead time measurement | `.claude/bin/leadtime` reports before and after numbers from git and GitHub |

Primary user for v1.1: me, building docmost-ai (a brownfield fork of Docmost: NestJS, React, plus a new Python service). A, B and C are dogfooded there before they count as done. D is not: a fresh fork has no PR history and one developer, so there is nothing to compare (section 6.5). D is proven on the fixture repo and on repos with history.

Order of work: A, B, C, D. A is needed to get the kit into the Docmost fork at all, B is the biggest time saver per PR, C needs B's evidence to judge whether a cheaper model was good enough, D needs a few weeks of PRs to say anything.

## 2. Changes to v1 non-goals and constraints

- Python is no longer out of scope: an `adapters/python/` adapter (uv, ruff, mypy or pyright, pytest) is required for docmost-ai's `ai-service/`.
- Monorepos with more than one adapter are in scope (section 3.4).
- "No token cost report per PR" is lifted in a reduced form: tokens per step and model are recorded (section 5). Euro cost stays out; prices change.
- The core stays POSIX sh with no jq or other runtime. Files that the kit's shell scripts read are line-based (tab-separated). JSON is used only where the model writes and CI reads it (`evidence.json`, read with `jq`, which GitHub's runners have), and where `gh --jq` reads GitHub's API.
- Still out: Cursor, Copilot, own runtime, dashboard UI.

## 3. A: `/onboard` for existing repos

### 3.1 Flow

`/onboard` is a skill with `disable-model-invocation: true`. It runs in four passes, each ending in a file the user approves.

1. **Scan (read-only).** Detect: languages, package managers and lockfiles, workspace layout (pnpm workspaces, turbo, nx, a `pyproject.toml` per folder), scripts in `package.json` and `Makefile`, test frameworks and their configs, linters and formatters and their configs, CI workflows, existing `CLAUDE.md`, `AGENTS.md`, `.cursor/rules`, `CONTRIBUTING.md`, docker compose files, seed scripts, e2e setups (Playwright, Cypress), migration folders, and paths that must not be touched (licence-restricted code, vendored code, generated code). Output: `.work/onboard/scan.md`.
2. **Baseline.** Run every detected check once on the default branch's head and record the result, the duration and the counts (format in 3.3): tests total, failing, skipped, by test ID from the JUnit report; lint and type errors by file. Output: `.work/onboard/baseline.tsv`. This is what the gates compare against, so legacy failures never block a PR, while new failures always do.
3. **Proposal.** Write: `kit.conf` per package (section 3.4), the Project facts block of `CLAUDE.md`, rule proposals derived from the repo's own conventions (folder structure, naming, error handling, test file placement, import style), and the protected paths for `settings.json` deny rules, the sandbox and the guard. Each rule proposal cites the files it was derived from. Output: `.work/onboard/proposal.md` plus the staged files under `.work/onboard/files/`, laid out as they will land in the repo. Nothing is written to `.claude/` yet.
4. **Apply.** After approval, the user runs (or approves running) `.claude/bin/onboard-apply`, which copies `.work/onboard/files/` and `.work/onboard/baseline.tsv` into place and prints what it wrote. Then the skill runs `.claude/bin/check` for every configured check on one changed file and on the full suite, and shows the result. Last, `.claude/bin/leadtime --baseline` (section 6) freezes the "before" numbers, if the repo has PR history.

Why a script: Claude Code refuses file-tool writes into `.claude/`, and the kit's settings ask before edits to `.claude/kit.conf` and `.claude/settings.json`. That protection is intended and stays. It is also what keeps the agent from loosening the baseline on its own (3.3).

### 3.2 Rules for the skill

- Never change application code during onboarding. The only files written are `.claude/`, `CLAUDE.md`, `specs/README.md`, `.claude/baseline.tsv`, `<pkg>/.claude/kit.conf`, and the CI workflow. The CI workflow is only written after asking.
- An existing `AGENTS.md` stays the source of its content. `CLAUDE.md` gets the line `@AGENTS.md` (Claude Code imports it) plus the kit's sections; nothing is copied. An existing `CLAUDE.md` keeps its own content, and the kit's sections are added. Show the diff.
- Every command in `kit.conf` must have been run once successfully during onboarding. A command that was not run is left empty and reported as "not configured". Never guess commands.
- A protected path the user names (for docmost: `apps/server/src/ee`, `apps/client/src/ee`, `packages/ee`) gets, in this order:
  1. a sandbox `denyRead` entry in `settings.json`. This is the enforcement: it holds for every process the agent starts, whatever the command;
  2. `Read`, `Edit` and `Grep`/`Glob`-covering deny rules;
  3. guard patterns for the common read commands (`cat`, `less`, `head`, `tail`, `sed`, `awk`, `grep -r`, `rg`, `find ... -exec`). The guard matcher grows to `Bash|Read|Edit|Write|Grep|Glob`;
  4. pathspec excludes (`':(exclude)apps/server/src/ee'`) on every git command the kit itself runs, including the reviewer's `git diff`, `git log -p` and `git show`. The allow rule `Bash(git show *)` would otherwise print protected files;
  5. a hooks test case for each layer the kit owns.

  The spec and the README state plainly that layers 2 to 4 are best effort, and that the sandbox is what makes the guarantee. Without the sandbox, `/onboard` reports protected paths as "not enforced".

### 3.3 Baseline-aware gates

The baseline is `.claude/baseline.tsv`, committed, one record per line, tab-separated:

```text
meta	sha	<default-branch sha>	created	<ISO date>
test	<package>	<test id>	pass|fail|skip
count	<package>	tests	<n>
lint	<package>	<file>	<error count>
typecheck	<package>	<file>	<error count>
coverage	<package>	<percent>
```

Inputs it is built from:

- Tests: a new optional key `KIT_TEST_REPORT` names the JUnit XML file that `KIT_TEST` writes (Vitest `--reporter=junit`, Jest `jest-junit`, pytest `--junitxml`). The test ID is `<classname>::<name>`. Without a report, the gate falls back to exit code and total count, and says so.
- Lint and typecheck: the `file:line` lines in the tool's normal output, counted per file. No per-rule counts.

`.claude/bin/check` gains `--against-baseline`:

- **Tests.** Fail if a test fails that passed in the baseline. Before failing, rerun each newly failing test once. A test that passes on the rerun is reported as "flaky", not blocking, and listed in the evidence. Known failing tests are reported as "legacy, not blocking". The total count may not drop, except by exactly the number of tests in files the diff deletes or tests whose names the diff removes. Those are listed.
- **Lint and typecheck.** Fail on any error in a changed file, and on a rise of the total count outside changed files.
- **Coverage.** Coverage of the changed source files as in v1 (lines covered in the files the diff changes, not the changed lines themselves), at or above `KIT_COVERAGE_THRESHOLD`. Overall coverage must not drop by more than `KIT_COVERAGE_TOLERANCE` (default 0.5 points).

CI runs the same `--against-baseline` checks (the adapters' `quality-gates.yml` changes to call them), so a legacy failure blocks neither the local gate nor the required status check.

`/onboard --refresh` rebuilds the baseline after legacy failures were fixed, staged in `.work/onboard/` and applied by `onboard-apply` like the first one. The baseline may only get stricter, never looser, without the user saying so. `onboard-apply` compares old and new and lists every loosened record (a test from pass to fail, a higher count) for the user to confirm.

### 3.4 Monorepos

- Package config lives at `<pkg>/.claude/kit.conf`, the same name and layout as the root's `.claude/kit.conf`. Claude Code ignores unknown files in nested `.claude/` folders. One ask rule, `Edit(**/.claude/kit.conf)`, protects all of them.
- `.claude/bin/check` walks up from each file to the nearest `.claude/kit.conf`, groups the files by it, and runs each group from that package's folder, with file paths relative to it. The root `.claude/kit.conf` is the fallback. `check <name>` without files runs the check in every package that configures it, and fails if any of them fails.
- `lib.sh` resolves the config per file the same way, so the guard, `record-edit` and the summary use the package's `KIT_SOURCE_PATTERNS`, `KIT_TEST_PATTERNS` and `KIT_DANGEROUS_PATTERNS`, not only the root's.
- docmost-ai target layout: root `.claude/kit.conf` (pnpm, Nx scripts as Docmost defines them), `ai-service/.claude/kit.conf` (Python adapter).

### 3.5 Python adapter

`adapters/python/.claude/kit.conf`: `uv run` for every command. Typecheck with mypy or pyright, whichever the project configures. Lint with `ruff check`. Format with `ruff format`. Tests with `pytest`, which writes JUnit through `--junitxml`. Coverage with `pytest --cov`, writing coverage.py JSON. Changed-files coverage reads that JSON, the equivalent of `changed-coverage.mjs` for Istanbul. `KIT_SOURCE_PATTERNS="*.py"`. `KIT_TEST_PATTERNS="test_*.py *_test.py conftest.py */tests/*"`.

### 3.6 Acceptance

- ONBOARD-AC1: on a fresh clone of the Docmost fork, `/onboard` finishes with all four files, without editing any file outside the allowed list.
- ONBOARD-AC2: a test that fails on the default branch does not block a PR, locally or in CI; a test that passed in the baseline and fails on the branch (twice) does.
- ONBOARD-AC3: reading a protected path is blocked by the sandbox. Reading, grepping or `git show`-ing it through the kit's own tools is blocked by the settings and the guard. Each layer is covered by a test.
- ONBOARD-AC4: on the demo app (greenfield), `/onboard` produces a `kit.conf` whose resolved `KIT_*` values, after sourcing, equal those of `install.sh` with the TypeScript adapter. The text may differ; the adapter file holds shell conditionals.
- ONBOARD-AC5: the scan finds and reports an existing `AGENTS.md`, keeps the file unchanged, and `CLAUDE.md` imports it.
- ONBOARD-AC6: a test that fails once and passes on the rerun is reported as flaky and does not block.
- ONBOARD-AC7: `onboard-apply` with a baseline that loosens a record lists it and does not write until the user confirms.

## 4. B: `/verify-feature` and the evidence pack

### 4.1 Where it sits

New flow in `CLAUDE.md` and `/ship-feature`:

1. Spec, 2. Plan, 3. Build, 4. Simplify, 5. Review, **6. Verify (replaces v1's "Full verification")**, 7. PR, 8. Acceptance.

`CLAUDE.md` lists all eight steps (v1 lists six without Simplify and says "five"; both are fixed). Review finds problems in the code. Verify proves the behaviour, with artefacts a human can check in minutes. Verify runs after the last review round with no high findings. If verify fails, the fix goes through the implementer and then back to review. After two verify rounds that still fail, stop and ask, as v1 does for review.

`/verify-feature` has `disable-model-invocation: true`.

### 4.2 What it produces

Folder `.work/<branch>/evidence/` (gitignored locally, pushed by verify, see 4.5). A branch name with `/` gives nested folders; that is fine.

```
evidence/
  evidence.json        # machine-readable summary, see 4.3
  gates.md             # every hard gate: command, exit code, counts, duration
  edge-cases.md        # matrix per criterion
  data-runs.md         # results on seeded data and on mocked dependencies
  screenshots/
    <AC-ID>-<step>-<desktop|mobile>.png        # branch
    <AC-ID>-<step>-<desktop|mobile>.main.png   # same flow on the base branch, when the page exists there
  review.md            # the final /review-diff report, copied in
```

### 4.3 `evidence.json`

```json
{
  "branch": "42-share-page",
  "head": "<sha>",
  "base": "main",
  "base_sha": "<sha>",
  "created": "2026-10-27T14:03:00Z",
  "gates": [{"name": "typecheck", "result": "pass", "ms": 8123},
            {"name": "build", "result": "n/a", "reason": "library, no build step"}],
  "criteria": [
    {"id": "SHARE-AC1", "tests": ["SHARE-AC1 shares a page by link"], "edge_cases": 4,
     "edge_cases_passed": 4, "screenshots": ["SHARE-AC1-1-desktop.png"], "seeded": "pass", "mocked": "pass"}
  ],
  "flaky": [],
  "review": {"verdict": "ready", "high": 0, "medium": 1, "low": 2},
  "usage": "usage.tsv"
}
```

The pack is valid only for the commit in `head`. Any push after verify (a review fix, a typo) makes it stale, and verify must run again. CI enforces this (4.5): stale evidence counts as no evidence.

### 4.4 The four parts

**Hard gates.** All must pass, or verify fails. No soft mode. A gate whose key is empty fails. A project without such a check sets the key to `n/a: <reason>` (for example `KIT_BUILD="n/a: library, no build step"`), and the reason appears in `gates.md` and `evidence.json`.

- typecheck, lint, build
- full test suite against the baseline (3.3), more than zero tests executed
- changed-files coverage at or above `KIT_COVERAGE_THRESHOLD`
- no focus or skip added in the diff: `.only`, `.skip`, `xit`, `xdescribe`, `fit`, `fdescribe`, `test.todo`, `@pytest.mark.skip`, `@pytest.mark.xfail`, `@unittest.skip`, `pytest.skip(`
- no new dependency in a manifest that the plan's `Approved dependencies` line does not list. `/plan-feature` gets that line in its template, default "none".
- no file in a protected path changed
- secret scan on the diff (gitleaks if installed, else the guard's patterns)
- diff size: warning above `KIT_MAX_CHANGED_LINES` (default 400), gate failure above twice that value. CI reads the same key from `kit.conf` instead of its own env value.

**Edge-case matrix.** For each criterion, the plan's test cases plus the reviewer's spec checklist (errors, empty data, duplicates, double submits, missing permissions, limits, concurrent edits) become rows: case, input, expected, test name, result. A case marked "not applicable" needs a one-line reason. A case without a test is a failure, not a note. The test-writer agent adds missing tests; it does not change code.

**Data runs.**

- Seeded: `KIT_SEED` resets and seeds a local database (docker compose, the project's seed script). `KIT_E2E` runs the e2e suite against it. Seed data is fixed and versioned.
- Mocked: `KIT_TEST_MOCKED` runs the suite with external dependencies replaced (MSW for HTTP in TypeScript, `respx` or fakes in Python, a fake LLM provider for the ai-service). Each run records which dependencies were mocked.
- Both runs record the seed version or mock set in `data-runs.md`.

**Screenshots.** `KIT_SCREENSHOTS` starts the app on seeded data and runs a Playwright script per criterion that has a UI. The steps come from the spec's user flow.

- Each screenshot is taken at desktop and at mobile width on the branch.
- Reproducible means more than fixed seed data: a fixed clock, locale and timezone, bundled fonts, and `animations: 'disabled'`.
- Each step that shows a criterion's visible result also has a Playwright text or role assertion. That assertion is the deterministic check.
- Then the `reviewer` agent reads the images and checks them against the criterion text. It reports a mismatch as a high finding. This judgement adds to the assertion; it does not replace it.
- A criterion without UI has no screenshots and says so.
- **Base-branch screenshots** (`*.main.png`) need a second worktree, app instance, port and seeded database. They are in scope, and they are the first item cut if B runs late (section 8).

### 4.5 Getting it into the PR

- `/verify-feature` ends by pushing the pack to the orphan branch `kit-evidence` under `<pr>/<sha>/` (or `<branch>/<sha>/` before the PR exists). This push is a git push, so it asks like every other push.
- `/pr-description` reads `evidence.json` and writes the evidence table from it, plus a "How to review this PR in 5 minutes" section: which screenshots to look at, which edge cases are new, what the reviewer agent flagged as medium.
- CI job `evidence`:
  1. fails if `kit-evidence` has no pack for the PR's head SHA, or if its `evidence.json` has a different `head` (VERIFY-AC5);
  2. runs `KIT_SEED`, `KIT_E2E` and `KIT_SCREENSHOTS` again, so the deterministic parts do not depend on my machine. It compares the results with the pushed pack and reports differences;
  3. uploads the CI run's folder as a workflow artefact;
  4. posts one sticky PR comment with the gate table, the matrix summary and the screenshots inline. The comment names the SHA and is updated on every push.

  The matrix, the screenshot judgement and `review.md` come from the pushed pack. CI cannot regenerate them without running Claude.
- Limits of the orphan branch, for open question 9.1:
  - Pushing from CI needs `contents: write`, which pull requests from forks do not get. For forks, the comment links to the artefact instead.
  - On a public repo the screenshots are public.
  - The branch grows without bound. A scheduled job deletes the folders of merged or closed PRs after 30 days.

### 4.6 Config keys (new in `kit.conf`)

`KIT_SEED`, `KIT_E2E`, `KIT_TEST_MOCKED`, `KIT_SCREENSHOTS`, `KIT_APP_URL`, `KIT_TEST_REPORT`, `KIT_COVERAGE_THRESHOLD` (default 70, replaces CI's `COVERAGE_THRESHOLD`), `KIT_COVERAGE_TOLERANCE`, `KIT_MAX_CHANGED_LINES` (default 400, replaces CI's `MAX_CHANGED_LINES`), `KIT_PROTECTED_PATHS`.

Each data-run and screenshot key is optional. A missing one makes its part of the evidence pack say "not configured", and `evidence.json` records that, so a reviewer sees what was not checked. Hard-gate keys follow the `n/a: <reason>` rule in 4.4.

### 4.7 Acceptance

- VERIFY-AC1: on the demo app, a feature with UI produces all parts of the evidence pack, including desktop and mobile screenshots on the branch (and on main, unless cut per section 8).
- VERIFY-AC2: a deliberately wrong UI (button label differs from the criterion) fails the Playwright text assertion, and the reviewer flags it from the screenshot alone.
- VERIFY-AC3: a criterion whose edge case has no test fails verify.
- VERIFY-AC4: an added `.only` fails verify; so does a new dependency not in the plan's `Approved dependencies`.
- VERIFY-AC5: a PR whose head SHA has no pack on `kit-evidence`, or whose pack names an older commit, fails the CI `evidence` job.
- VERIFY-AC6: the PR comment shows the gate table and at least one screenshot without opening any other page.
- VERIFY-AC7: time for me to review a demo-app PR with the comment vs without it, measured on three PRs each, logged in `docs/build-log.md`.
- VERIFY-AC8: a hard gate with an empty key fails verify; with `n/a: <reason>` it passes, and the reason appears in the evidence.

## 5. C: model routing per task

### 5.1 Tiers, not model names

What Claude Code accepts (docs checked 27.10.2026):

- An agent's `model` frontmatter takes an alias (`sonnet`, `opus`, `haiku`, `fable`), a full model ID, or `inherit`.
- The Agent tool's per-call `model` parameter wins over the frontmatter, but it takes aliases only.
- A skill's `model` field takes the same values as `/model`. With `context: fork` it sets the forked agent's model; without it, it changes the main session's model for the rest of the turn. It is a fixed value in the file; config cannot change it at run time.
- `CLAUDE_CODE_SUBAGENT_MODEL` is only a default. With `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` it overrides every per-call model, which disables routing. `/ship-feature` warns when it is set.

So routing applies to agents the orchestrator dispatches, and the tier models are aliases:

```sh
KIT_MODEL_FAST="haiku"        # search, scan, summarising logs
KIT_MODEL_STANDARD="sonnet"   # implementing tasks that follow an existing pattern, tests
KIT_MODEL_DEEP="opus"         # review, screenshot judgement, hard tasks

KIT_ROUTE_EXPLORE="fast"
KIT_ROUTE_IMPLEMENT="standard"  # default per task, the plan may raise or lower it
KIT_ROUTE_TESTS="standard"
KIT_ROUTE_REVIEW="deep"
KIT_ROUTE_VERIFY="standard"     # running gates; screenshot judgement uses REVIEW
```

Spec, plan and PR description run in the main session on the session model. They have no route key.

### 5.2 Routing rules

- Codebase search during spec and plan uses the built-in `Explore` agent with the fast tier passed per call, so the deep model reads conclusions, not file dumps. No new agent.
- The orchestrator dispatches the reviewer through the Agent tool with `model` set from `KIT_ROUTE_REVIEW`, instead of the forked `/review-diff` skill, whose model is fixed. `/review-diff` stays for standalone use.
- `/plan-feature` adds a `Tier` column to the task table. Default from `KIT_ROUTE_IMPLEMENT`. The planner raises a task to deep when it touches auth, data migrations, concurrency, money or a protected contract, or when there is no existing pattern to copy. It lowers a task to fast for pure renames and copy tasks. Each change of tier has a one-line reason in the plan.
- Escalation: if a task fails its checks once on its tier, the second attempt runs one tier higher. A deep task's second attempt stays on deep. A second failure stops and asks, as in v1.
- The reviewer never runs on a lower tier than the implementer of the code it reviews.

### 5.3 Usage record and budget

No hook input carries token counts. The counts come from the transcripts: `transcript_path` (main session, on Stop) and `agent_transcript_path` (subagent, on SubagentStop). Each assistant entry there has the model and a usage block. That transcript format is not documented and may lag; the hook tolerates missing entries, and the tests pin the format the kit was built against.

- `SubagentStop` writes one line per agent to `.work/<branch>/usage.tsv`: `agent_id`, step, task, model, input, output, cache-read and cache-write tokens. Because the transcript is cumulative, the line is recomputed and replaced, never appended.
- `Stop` recomputes the main session's line the same way.
- Step and task come from a `PostToolUse` hook on `Agent`, which records `agent_id` with the call's description. The orchestrator writes `task <n>: <title>` or the step name into the description. This keeps parallel tasks apart.
- Whether a forked skill (`context: fork`) fires `SubagentStop` is unknown. Test it first; if it does not, forked skills are not counted, and the record says so.
- `KIT_BUDGET_TOKENS` (default empty, meaning no budget): a `PreToolUse` hook on `Agent` sums `usage.tsv`. At 80 percent it adds a warning to the context; at 100 percent it blocks the dispatch with a message to ask the user. This is enforced by the hook, not left to the orchestrator.
- The PR description gets one line: tokens per tier, review rounds, escalations.
- After ten PRs, a short report in `docs/build-log.md`: per tier, how many tasks needed escalation and how many review findings came from tasks on each tier. That is the evidence for tuning the defaults.

### 5.4 Acceptance

- ROUTE-AC1: in a `/ship-feature` run, the plan shows a tier per task, and the usage record shows each implementer ran on that tier.
- ROUTE-AC2: a task forced to fail once is retried one tier higher (deep stays deep), and the escalation appears in the usage record and the PR description.
- ROUTE-AC3: with a small `KIT_BUDGET_TOKENS`, the `PreToolUse` hook blocks the next dispatch and the run asks.
- ROUTE-AC4: changing `KIT_MODEL_STANDARD` changes the model of every standard-tier dispatch without editing agents or skills.
- ROUTE-AC5: with `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` set, `/ship-feature` warns that routing is disabled.

## 6. D: lead time measurement

### 6.1 Definitions

All times are wall clock, reported as median and p75 per period.

| Metric | From | To | Source |
|--------|------|----|--------|
| Lead time for changes | earliest commit in the PR's commit list (squash merges lose branch commits on main) | merge to the default branch | GitHub |
| PR cycle time | PR opened | merged | GitHub |
| Time to first review | PR ready for review (draft PRs count from the `ReadyForReviewEvent`) | first review or comment by someone other than the author or a bot | GitHub (GraphQL timeline) |
| Review rounds | | count of "changes requested" plus pushes after the first review | GitHub |
| Spec to merge | spec status `approved` in `specs/README.md` | merge | git log of `specs/README.md` |
| Rework rate | | share of PRs followed within 14 days by a fix PR touching the same files. A fix PR has a `bug` or `fix` label, or a title starting with `fix` or `revert` | GitHub |
| PR size | | changed lines, median | GitHub |

If a Jira or Linear issue key is in the branch name, issue created and issue "in progress" can be added later; v1.1 uses GitHub only.

### 6.2 Tool

`.claude/bin/leadtime [--since DATE] [--until DATE] [--baseline] [--split-by kit|none] [--format md|csv] [--with-titles]`

- POSIX sh plus `gh` and `git`, using `gh`'s built-in `--jq`, no other runtime.
- Date arithmetic happens in `--jq` (`fromdateiso8601`), because date parsing is not portable across `date` implementations. Medians and percentiles happen in `sort` and `awk`.
- `GH` (default `gh`) names the command it calls, so tests run a fake `gh` that serves recorded JSON.
- `--baseline` measures the 90 days before today and writes `reports/lead-time-baseline.md` and `.csv`. `/onboard` calls it once.
- Default: from the baseline date until today, written to `reports/lead-time.md`, with the baseline next to it and the change in percent.
- `--split-by kit` splits PRs into "with evidence pack" (the sticky comment from 4.5 exists) and "without", so the comparison is fair even when not every PR goes through the kit.
- Bots and dependency PRs (Renovate, Dependabot) are excluded by default.

### 6.3 Honest reporting

- Each report prints the number of PRs per period. Below ten PRs it prints "too few PRs for a reliable comparison" above the numbers.
- A repo with one contributor gets "n/a: one contributor" for time to first review and review rounds, instead of numbers.
- It never claims causation. The text says what changed, not why.
- The report contains no PR titles or author names by default (`--with-titles` to include them), so it can be shown to a client without editing.

### 6.4 Acceptance

- LEAD-AC1: on a repo with known PR dates (fixture in `tests/`), every metric matches a hand-calculated value.
- LEAD-AC2: `--baseline` followed by a normal run shows both periods and the change.
- LEAD-AC3: below ten PRs, the warning is printed.
- LEAD-AC4: bot PRs are excluded, drafts count from "ready for review", and the author's own comments do not count as a first review.
- LEAD-AC5: no titles or names in the default output.

### 6.5 Not for docmost-ai

A fresh fork lists only its own PRs, so its 90-day baseline is empty. With one developer, review metrics mean nothing. D is not dogfooded on docmost-ai. It is proven on the fixture repo (LEAD-AC1 to AC5) and used on repos with PR history, such as client pilots.

## 7. Tests

- `tests/hooks.test.sh`: new cases for protected paths (guard on Bash, Read, Grep, Glob; git pathspec excludes), the usage hooks (fixture transcripts), the budget hook, the `.only` and dependency gates, and per-package config lookup in `lib.sh`.
- `tests/check.test.sh` (new): baseline-aware gates (legacy failure, new failure, flaky rerun, deleted tests, loosened baseline), `n/a: <reason>` handling, and nested `.claude/kit.conf` lookup in a two-package fixture.
- `tests/leadtime.test.sh` (new): against recorded `gh` JSON through a fake `GH`, no network.
- `tests/onboard/`: two fixture repos (a pnpm monorepo with one failing legacy test, a Python package), checked by a headless run.
- Demo app: one feature shipped end to end with `/ship-feature` including verify. The build log records what verify caught.

## 8. Milestones

| Days | Milestone |
|------|-----------|
| 1 to 2 | A: `/onboard`, `onboard-apply`, baseline-aware check, nested `kit.conf`, Python adapter |
| 3 | A on the Docmost fork; build log entry |
| 4 to 6 | B: `/verify-feature`, evidence pack, reviewer reads screenshots, PR description |
| 7 | B in CI: evidence job, sticky comment |
| 8 | C: tiers, Tier column in the plan, escalation, usage and budget hooks |
| 9 | D: `leadtime` with fixtures |
| 10 | First docmost-ai feature end to end; fixes; tag v1.1.0 |

This is tight, and B is the largest part. If it slips, cut in this order: base-branch screenshots (`*.main.png`), then the inline images on `kit-evidence` (the comment links to the artefact instead), then the mocked data run. The pack push to `kit-evidence` (VERIFY-AC5) and the branch screenshots stay.

## 9. Open questions

1. Screenshots in a private repo's PR comment: do images from the orphan branch render for collaborators, or is the artefact link the only option? Answer it by trying it, with the limits in 4.5 in mind.
2. ~~File name for package-level config in monorepos.~~ Decided: `<pkg>/.claude/kit.conf` (3.4).
3. Does Docmost's existing test setup support a seeded e2e run without the enterprise code? If not, docmost-ai needs its own seed script under `ai-service/` and the Docmost side stays at unit and integration tests.
4. Issue tracker for lead time later: GitHub Issues only, or Jira/Linear for client pilots?

## 10. Claude Code prompts

Run these one at a time in `templates/agentic-workflow-kit/`, each on its own branch, with plan mode. Paths are relative to that folder.

### Prompt A

```
Read docs/SPEC-v1.1.md sections 2, 3 and 11, kit/CLAUDE.md, kit/.claude/bin/check, kit/.claude/hooks/lib.sh, kit/.claude/hooks/guard, kit/.claude/settings.json and tests/hooks.test.sh. Plan the /onboard skill, .claude/bin/onboard-apply, the --against-baseline mode of check with .claude/baseline.tsv, the nested .claude/kit.conf lookup in check and lib.sh, the protected-path layers and adapters/python. Show me the plan with files, tests and the ONBOARD criteria each task covers, then wait. Build test first. Add fixture repos under tests/onboard/. Do not change kit behaviour outside section 3. Log what the tests caught in docs/build-log.md.
```

### Prompt B

```
Read docs/SPEC-v1.1.md sections 4 and 11 and the current review-diff, pr-description, plan-feature and ship-feature skills plus the reviewer agent and adapters/typescript/.github/workflows/quality-gates.yml. Plan /verify-feature, the evidence pack, the push to kit-evidence, the new kit.conf keys, the reviewer's screenshot check and the CI evidence job. Show the plan and wait. Build test first on examples/demo-app: add a seed script, MSW mocks and a Playwright setup there as part of this work, and ship one small demo feature through the full flow to prove VERIFY-AC1 to AC8. Answer open question 9.1 by trying it, and record the answer in the build log.
```

### Prompt C

```
Read docs/SPEC-v1.1.md sections 5 and 11. First check the current Claude Code docs again for the model field of agents and skills, the Agent tool model parameter, CLAUDE_CODE_SUBAGENT_MODEL(_FORCE), and the SubagentStop, Stop and PostToolUse (Agent) hook inputs, including whether a context: fork skill fires SubagentStop; write what changed since section 5.1 into the plan. Then plan the tiers in kit.conf, the Tier column in plan-feature, escalation and reviewer dispatch in ship-feature, and the usage and budget hooks. Show the plan and wait. Build test first.
```

### Prompt D

```
Read docs/SPEC-v1.1.md sections 6 and 11. Plan .claude/bin/leadtime in POSIX sh with gh and git only, with a GH override for tests. Record a gh JSON fixture for a small set of PRs (including a draft, a bot PR, an author self-comment and a fix PR) and hand-calculate the expected numbers before writing the script. Show the plan and wait. Build test first; no network in tests.
```

## 11. Review decisions (27.10.2026)

The draft was reviewed against the shipped kit and the Claude Code docs. These decisions are already worked into the sections above; this list is the short form.

| Topic | Decision | Section |
|-------|----------|---------|
| v1 spec | No written v1 spec; the shipped kit and the build log are the reference | header |
| Stale evidence | Verify pushes the pack to `kit-evidence/<pr>/<sha>/`; CI fails without a pack for the head SHA and reruns the deterministic parts | 4.3, 4.5 |
| Writes into `.claude/` | Staged in `.work/onboard/`, applied by `onboard-apply`; the protection on `.claude/` stays and guards the baseline | 3.1, 3.3 |
| Baseline inputs | JUnit XML through `KIT_TEST_REPORT`; lint and typecheck by `file:line` per file, no per-rule counts | 3.3 |
| Data formats | Line-based where sh reads; JSON only for `evidence.json` and `gh --jq`; no jq in the core | 2, 3.3, 5.3 |
| Lead time on docmost-ai | Not dogfooded there; proven on fixtures and repos with history | 1, 6.5 |
| Protected paths | Sandbox `denyRead` is the enforcement; deny rules, guard (now incl. Grep/Glob) and git pathspec excludes are best effort | 3.2 |
| Model routing | Only dispatched agents; aliases only; reviewer dispatched through the Agent tool; no route keys for spec, plan, PR; warn on `_FORCE` | 5.1, 5.2 |
| Usage and budget | Recomputed, not appended; task mapping through PostToolUse on `Agent`; budget enforced by a PreToolUse hook | 5.3 |
| Coverage | Stays changed-files coverage; wording fixed; Python reads coverage.py JSON | 3.3, 3.5 |
| CI | Runs the baseline-aware checks too | 3.3 |
| Package config | `<pkg>/.claude/kit.conf`, resolved per file by `check` and `lib.sh` | 3.4 |
| Flaky and deleted tests | Rerun once, flaky does not block; count may drop by exactly the deleted tests; no merge-base baseline | 3.3 |
| Flow | Verify replaces "Full verification"; two failed verify rounds stop and ask | 4.1 |
| Unconfigured gates | Empty key fails; `n/a: <reason>` skips with the reason in the evidence | 4.4 |
| Screenshots | Fixed clock, locale, fonts, no animations; Playwright assertions are the check; base-branch shots cut first | 4.4, 8 |
| `AGENTS.md` | Imported with `@AGENTS.md`, never copied | 3.2 |
| Explorer | Built-in `Explore` with a per-call fast model | 5.2 |
| Rework | Fix PR = `bug`/`fix` label or `fix`/`revert` title prefix, same files, 14 days | 6.1 |
| Escalation from deep | Retry once on deep, then stop and ask | 5.2 |
