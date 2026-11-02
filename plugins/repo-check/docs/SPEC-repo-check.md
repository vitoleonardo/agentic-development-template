# repo-check: Specification

Status: approved 30.10.2026, implemented 30.10.2026. What was built and proven: [build-log.md](build-log.md).

## 1. Why

`repo-check` is a free Claude Code plugin and the first step into the consulting offer: workshop, pilot, Begleitung, feature sprint and Kit Pro. In about ten minutes a team learns where its delivery is jammed right now ("Der Stau wandert": from Schreiben to Review to Release once agents write faster). They get three steps they can take alone, and an honest answer about which offer fits, if any. If they want to, they send the answers themselves.

It is standalone. It works in a repo that has not installed the agentic-workflow-kit and depends on no `.claude/` file in the target repo.

Deliverables:

| Part | Path |
|------|------|
| Plugin (marketplace source) | `plugins/repo-check/plugin/` |
| Skill `/repo-check` | `plugin/skills/repo-check/SKILL.md` |
| Read-only hook | `plugin/hooks/read-only` |
| Scanner | `plugin/skills/repo-check/scan` |
| Lead time (generated copy of the kit's) | `plugin/skills/repo-check/leadtime` |
| Hosted single-file prompt (generated) | `plugins/repo-check/repo-check.md` |
| Build script | `plugins/repo-check/build` |
| Tests | `plugins/repo-check/tests/` |

## 2. Modes

`/repo-check [interview|scan]`, with `disable-model-invocation: true`. Without a mode the skill asks which one and does nothing else (RC-AC1).

### 2.1 Common rules

- Language follows the user's first message, German or English. German uses "du" for the reader and "ihr" for the team, never "Sie" (RC-AC2).
- Never mention prices, never promise dates, never name other customers, never pressure. No urgency, scarcity or discounts (RC-AC3).
- Never send anything. The email is a draft the user sends from their own mail program (RC-AC4).
- Unanswered questions are marked "offen" (de) or "open" (en).
- Output follows `plugins/agentic-workflow-kit/kit/.claude/rules/output.md`: answer first, short lines, no recap.

### 2.2 Interview

No code access. Ten questions, one per message, in this order. Each has numbered options plus "oder in deinen eigenen Worten" / "or in your own words". The intro says it takes about ten minutes and that the answers stay in this chat (RC-AC5). A skipped or unclear answer becomes "offen"/"open" and the interview moves on (RC-AC6).

| # | Topic | Deutsch | English |
|---|-------|---------|---------|
| 1 | Team | Wie viele Leute arbeiten bei euch am Produkt, und in welchen Rollen? 1) nur ich 2) 2–5, vor allem Entwicklung 3) 6–15, mit Produkt und QA 4) mehr als 15, mehrere Teams | How many people work on your product, and in which roles? 1) just me 2) 2–5, mostly engineering 3) 6–15, with product and QA 4) more than 15, several teams |
| 2 | Product stage | In welcher Phase ist euer Produkt? 1) Idee oder Prototyp 2) erste zahlende Kunden 3) wächst, mehrere Kunden 4) etabliert, mit viel gewachsenem Code | What stage is your product in? 1) idea or prototype 2) first paying customers 3) growing, several customers 4) established, with a lot of legacy code |
| 3 | Agent tools | Welche Coding-Agenten nutzt ihr? 1) keine 2) Autovervollständigung (Copilot o. ä.) 3) Agenten einzeln (Claude Code, Cursor, Codex …) 4) Agenten im ganzen Team, auch in CI | Which coding agents do you use? 1) none 2) autocomplete (Copilot or similar) 3) agents, individually (Claude Code, Cursor, Codex …) 4) agents across the team, also in CI |
| 4 | Shared rules | Gibt es gemeinsame Regeln für die Agenten (CLAUDE.md, AGENTS.md, Cursor Rules)? 1) nein 2) jede:r hat eigene 3) ja, im Repo, selten gepflegt 4) ja, im Repo und im Review geprüft | Are there shared rules for the agents (CLAUDE.md, AGENTS.md, Cursor rules)? 1) no 2) everyone has their own 3) yes, in the repo, rarely updated 4) yes, in the repo and checked in review |
| 5 | PR size, review wait | Wie groß ist ein typischer PR, und wie lange wartet er auf das erste Review? 1) klein (unter 200 Zeilen), unter einem Tag 2) mittel, ein bis zwei Tage 3) groß (über 500 Zeilen), mehrere Tage 4) wir arbeiten ohne PRs oder Review | How big is a typical PR, and how long does it wait for its first review? 1) small (under 200 lines), less than a day 2) medium, one or two days 3) large (over 500 lines), several days 4) we work without PRs or review |
| 6 | CI and tests | Was prüft eure CI vor dem Merge? 1) es gibt keine CI 2) Build 3) Build und Tests 4) Build, Tests, Lint, Typecheck und Coverage | What does your CI check before a merge? 1) there is no CI 2) build 3) build and tests 4) build, tests, lint, typecheck and coverage |
| 7 | Release frequency | Wie oft geht bei euch etwas live? 1) mehrmals am Tag 2) jede Woche 3) jeden Monat 4) seltener oder unregelmäßig | How often do you ship to production? 1) several times a day 2) every week 3) every month 4) less often or irregularly |
| 8 | Pain | Was tut gerade am meisten weh? 1) bis ein Feature geschrieben ist, dauert es zu lange 2) PRs warten auf Review 3) Fehler nach dem Release, Hotfixes 4) Agenten liefern Code, dem niemand traut | What hurts most right now? 1) writing a feature takes too long 2) PRs wait for review 3) bugs after release, hotfixes 4) agents deliver code nobody trusts |
| 9 | In 3 months | Was soll in drei Monaten anders sein? 1) wir liefern schneller 2) weniger Fehler 3) das Team nutzt Agenten einheitlich 4) ein konkretes Feature ist fertig | What should be different in three months? 1) we ship faster 2) fewer bugs 3) the team uses agents the same way 4) one specific feature is done |
| 10 | Budget | Wer entscheidet bei euch über Budget für so etwas? 1) ich 2) meine Chefin, mein Chef oder die Gründer:innen 3) Einkauf oder ein Gremium 4) noch unklar | Who decides about budget for something like this? 1) me 2) my manager or the founders 3) purchasing or a committee 4) not clear yet |

Result (RC-AC7):

1. **Assessment.** Where the jam sits now, Schreiben, Review or Release, and the answers it rests on (by number). Rules:
   - Schreiben: Q3 is 1 or 2, Q4 is 1 or 2, or Q8 is 1.
   - Review: Q5 is 2 or 3, or Q8 is 2 or 4.
   - Release: Q6 is 1 or 2, Q7 is 3 or 4, or Q8 is 3.
   - Several match: the one Q8 names wins. Then the later one in the flow, because the jam moves downstream.
   - Nothing matches: "kein klarer Stau" / "no clear jam".
2. **Three next steps** the team can take alone this month, tied to the jam, each one line.
3. **Offer fit** by section 4, or "noch keins" / "none yet", with the reason in one line.

Then the email draft (RC-AC8):

- A subject, "repo-check: <team size>, Stau bei <stage>" (en: "repo-check: <team size>, jam at <stage>").
- One heading per question with the answer, then the assessment.
- A mailto link to `hi@vito.koeln` with subject and body URL-encoded. If the body is over 1,800 characters, the link carries only the subject and the user is told to paste the draft.
- After that, the booking link `https://calendar.app.google/N14WVsxK4fdqBhZv6` as an alternative, in one neutral sentence.
- Both links are opened only by the user. The skill sends nothing.

### 2.3 Scan

A strictly read-only analysis of the current repo. Only `.repo-check/` gets written.

Flow:

1. Check that the folder is a git repo. If it is not, say so and offer the interview.
2. If a GitHub remote exists (`git remote -v` shows `github.com`), ask whether the scan may read PR data with `gh`, and list which read-only calls it makes. Without a yes, the scan is git-only.
3. Run `${CLAUDE_SKILL_DIR}/scan --lang <de|en> [--gh]`. It writes `.repo-check/.gitignore` (`*`) and `.repo-check/report.md` with every deterministic part. It leaves three markers: `<!-- fill:reason -->`, `<!-- fill:next-steps -->` and `<!-- fill:offer -->`.
4. Read only the config and doc files the report cites, if needed, and replace the three markers with Edit. Never touch the anonymised block.
5. Print the anonymised block. Ask whether the user wants the email draft (RC-AC19). Write it only after a yes, as in 2.2, with the block instead of the answers.

Report `.repo-check/report.md`, sections in this order (RC-AC17):

1. "Der Stau steckt gerade bei: <stage>" (en: "The jam is at: <stage>"), with the reason.
2. The five verdicts with their evidence: file paths or the command (RC-AC14).
3. Up to four baseline numbers, each with its source and PR count (RC-AC16).
4. The top 3 next steps.
5. Which offer fits, honestly, including "noch keins" / "none yet".
6. The anonymised summary block: stage verdicts, the jam, the numbers and the counts. No code, no file contents, no person names, no paths below the repo's top level, no repo name and no remote URL unless the user adds them (RC-AC18). It is written as plain lines, not in a code fence.

The report never contains a code snippet: no code fence, and no line longer than 20 characters from a tracked file (RC-AC20). `git status --porcelain --untracked-files=all` is the same before and after the scan (RC-AC17).

## 3. Stages and verdicts

The scanner applies these rules. The hosted prompt applies the same table by hand.

| Stage | Group | Evidence | Green | Red | Yellow |
|-------|-------|----------|-------|-----|--------|
| Intent | Schreiben | spec folders (`specs/`, `docs/specs/`, `rfcs/`, `adr/`, `docs/adr/`); issue templates (`.github/ISSUE_TEMPLATE/`, `.gitlab/issue_templates/`); PR template; Markdown with "Acceptance criteria", "Akzeptanzkriterien" or Given/When/Then | specs or templates, and acceptance criteria | none of them | otherwise |
| Build | Schreiben | agent guides (`CLAUDE.md`, `AGENTS.md`, `.cursor/rules/`, `.cursorrules`, `.github/copilot-instructions.md`); agent permissions (`.claude/settings.json` with `permissions`); structure docs (`ARCHITECTURE.md`, `CONTRIBUTING.md`, `docs/adr/`) | agent guide and permissions | none of them | otherwise |
| Review | Review | with gh: leadtime's PR size, time to first review and review rounds (medians). Git only: changed lines of first-parent merges | size ≤ 400, first review ≤ 24 h, rounds ≤ 1 | size > 1,000 or first review > 72 h | otherwise. Yellow below 10 PRs or merges (too few to judge); at best yellow without gh or with one contributor |
| Gates | Release | CI files (`.github/workflows/*`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/config.yml`, `azure-pipelines.yml`, `bitbucket-pipelines.yml`); which checks they run, by keyword (test, lint, typecheck, build, coverage); test files; a coverage threshold; strict typing (`"strict": true` in `tsconfig.json`, `strict = true` for mypy, pyright `strict`) | CI runs test, lint and typecheck, with strict typing | no CI, or no tests | otherwise |
| Release | Release | git, the last 90 days: merges per week on the default branch, tags, and the follow-up fix rate (leadtime's rework rule on git: a merge whose subject starts with `fix` or `revert`, within 14 days, touching a file of an earlier merge). With gh: leadtime's `rework_pct` | ≥ 1 merge per week and fix rate ≤ 15 % | no merge in the last 30 days, or fix rate > 30 % | otherwise |

- The jam is the stage with the worst verdict. On a tie, the earliest stage in flow order wins (Intent, Build, Review, Gates, Release). The report names the stage and its group.
- Verdict thresholds are fixed values in the scanner. A change goes through this table first.

## 4. Offer fit

Pick at most one. "None yet" is a valid and common answer.

| Offer | Fits when |
|-------|-----------|
| Workshop | Two or more people; the jam is at Schreiben; there are no shared agent rules |
| Pilot | The jam is at Review or Release; there is PR history; the budget owner is known |
| Begleitung | Agents are already in team use; the jam has moved downstream; the goal is lasting change within three months |
| Feature sprint | Q9 says "one specific feature is done", and capacity is short |
| Kit Pro | The team sets up the open kit itself and agents are in daily use; there is budget for a tool, not for a package |
| Noch keins / none yet | Solo with no budget decision; prototype stage; or the three next steps come first |

In scan mode, team size is the number of distinct authors in the last 90 days. It is counted, never named. Budget and goals are unknown, so the offer line says what it could not judge.

## 5. Enforcement

### 5.1 What Claude Code offers (checked 30.10.2026, code.claude.com)

- `allowed-tools` in a skill pre-approves tools, and only for the turn that invokes the skill. It restricts nothing.
- `disallowed-tools` removes tools, but the restriction clears on the next user message. Interview and scan are multi-turn.
- Hooks in a skill's frontmatter stay registered for the rest of the session. A probe on 30.10.2026 showed what that means: they hold for later messages in the same process, but are gone after `claude --resume` (a new process). `${CLAUDE_PLUGIN_ROOT}` reaches them as an environment variable; `${CLAUDE_SKILL_DIR}` is not substituted in a hook command, and `CLAUDE_PLUGIN_DATA` names another plugin's folder.
- A plugin's `hooks/hooks.json` applies to every session in which the plugin is enabled.

So the enforcement is one PreToolUse hook, `hooks/read-only`, registered twice. The skill's frontmatter runs it with `--start`, which marks the session (an empty file named after the session ID in `${XDG_STATE_HOME:-~/.local/state}/repo-check/read-only-sessions/`; not `${CLAUDE_PLUGIN_DATA}`, which a frontmatter hook receives from another plugin) and enforces. The plugin's `hooks/hooks.json` runs it without `--start` for every session; it enforces only in a marked session and exits at once in every other. That keeps the lock after a resume and leaves sessions that never ran `/repo-check` alone. `allowed-tools` only saves prompts (RC-AC12). The block message says to start a new session to edit files.

### 5.2 The `read-only` hook (RC-AC9 to AC11, AC13)

Matcher `*`. Exit 2 blocks, with the reason on stderr. A JSON `permissionDecision` of `ask` sends the call to the user.

| Tool | Decision |
|------|----------|
| Read | allow, except secret files |
| Glob | allow, except a pattern or path that names secret files |
| Grep | allow, except secret paths or globs, and `output_mode: content` (no file content in the context) |
| Write, Edit | allow only below `<project>/.repo-check/`, after resolving `..` and symlinks; block otherwise |
| AskUserQuestion, TodoWrite | allow |
| Bash: `${CLAUDE_SKILL_DIR}/scan` | allow; `ask` with `--gh` |
| Bash: git | allow for `status`, `log`, `shortlog -s -n` (counts only), `rev-parse`, `rev-list`, `ls-files`, `ls-tree`, `branch` (listing), `tag` (listing), `for-each-ref`, `describe`, `merge-base`, `remote -v`, `diff` and `show` with `--stat`, `--numstat`, `--shortstat` or `--name-only` only. Block `-p`, `--patch`, `-c`, `--output`, `<rev>:<path>`, and every other subcommand (commit, checkout, switch, reset, stash, clean, fetch, pull, push, config, gc, worktree …) |
| Bash: gh | `ask` for `repo view`, `pr list`, `pr view`, `api` without a method other than GET, and `api graphql` without `mutation`. Block every other call |
| Bash: anything else | block. This includes install, build, test, lint, seed and migration commands, `curl`, `wget`, chaining (`;`, `&&`, `\|\|`, `\|`), redirection (`>`, `<`), subshells and backticks |
| Every other tool (WebFetch, WebSearch, Agent, NotebookEdit, `mcp__*` …) | block |

Secret files (RC-AC10): `.env` and `.env.*` (except `.example`, `.sample` and `.template`), `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa*`, `id_ed25519*`, `.npmrc`, `.pypirc`, `.netrc`, `credentials*`. The rule applies to file paths, glob patterns and every Bash argument. The scanner lists files only with `git ls-files` and opens only the config and doc files of section 3, by name.

GitHub's GraphQL endpoint takes POST, even for queries. `api graphql` is allowed because leadtime's query only reads. The hook asks first, and refuses any request that contains `mutation`.

### 5.3 The hosted prompt

The hosted prompt has no hook. It enforces nothing technically, it says so in its first lines, and it reduces the scan so that there is little to enforce (section 6).

## 6. Hosted prompt `repo-check.md`

People without the plugin paste this single file into Claude Code. It runs the interview fully (2.2) and a reduced scan (RC-AC22):

- only `git` commands from the allowlist in 5.2, and `git ls-files` for the file listing;
- no file contents are read, so verdicts rest on file names and git history alone, and the report marks every row that the full scan would judge differently;
- nothing is written: the report is printed in chat.

`plugins/repo-check/build` generates it from the shared blocks of SKILL.md (`<!-- shared:NAME -->` … `<!-- /shared:NAME -->`: common rules, questions, interview result, email, verdict table, offer fit) plus the prompt-only text in `plugins/repo-check/prompt/repo-check.md.in`, whose `<!-- include:NAME -->` lines name the blocks. `build --check` regenerates into a temporary folder and fails on any difference (RC-AC21). The contact address and the booking link are set once each in SKILL.md.

## 7. Lead time reuse

The scanner reuses `plugins/agentic-workflow-kit/kit/.claude/bin/leadtime`: its query, its definitions (SPEC-v1.1, section 6.1), bot exclusion, the one-contributor rule and the threshold of ten PRs with its warning, "Too few PRs for a reliable comparison". The German report uses "Zu wenige PRs für einen verlässlichen Vergleich".

An installed plugin is copied into Claude Code's cache. A symlink to another plugin is dereferenced for git marketplaces but skipped for local-path installs, so `build` writes a byte-identical copy to `plugin/skills/repo-check/leadtime`, and `build --check` fails if it differs (RC-AC24). leadtime gains:

- `--stdout`: write the CSV to stdout, create no `reports/` and write no file;
- `LEADTIME_ROOT`: the repository to measure. The default stays the kit project, found from the script's location.

The scanner calls `LEADTIME_ROOT=<repo> leadtime --stdout --format csv --since <90 days ago>`, with `GH` passed through for tests.

Up to four numbers:

| With gh | Without gh |
|---------|------------|
| PR size (median changed lines) | PR size (median changed lines of first-parent merges, from `git log --first-parent --numstat`) |
| Time to first review (median h) | Merges per week |
| Review rounds (median) | Tags in 90 days |
| Rework rate (%) | Follow-up fix rate (%) |

Each number states its source (`leadtime` via gh, or the git command) and its PR or merge count. Without gh, time to first review and review rounds read "n/a: needs GitHub data" (RC-AC15).

## 8. Tests

Same style as `plugins/agentic-workflow-kit/tests/*.test.sh`: POSIX sh, `ok`, `fail` and `has` helpers, a pass/fail count, and they run under `dash`. CI gets `.github/workflows/repo-check.yml` (shellcheck and the three suites, also under dash, with no path filters).

- `tests/hook.test.sh` feeds the hook the JSON Claude Code sends:
  - it blocks a write outside `.repo-check/` (including `.repo-check/../x`), build and test commands, reading a `.env` canary, and the other cases in 5.2;
  - it allows writes to `.repo-check/report.md` and read-only git commands;
  - it returns `ask` for read-only gh calls and for `scan --gh`.
- `tests/scan.test.sh` scans two fixtures from `plugins/agentic-workflow-kit/tests/onboard/`, each with a `.env` canary added:
  - `pnpm-monorepo` with recorded gh JSON (`tests/leadtime/fake-gh` and `prs.json`);
  - `python-pkg`, git-only, with synthetic merges, tags and a revert.

  It checks, in German and English:
  - `git status` is unchanged apart from the excluded `.repo-check/`;
  - every stage is in the report with evidence, along with the jam line, the numbers with source and PR count, and the too-few warning;
  - the anonymised block contains no `/`, no author names or logins, no repo name, and no code fence;
  - neither the canary nor any tracked file line is in the report.
- `tests/prompt.test.sh` is the drift test:
  - `build --check` passes, and a hand-edited `repo-check.md` or `leadtime` copy makes it fail;
  - the question list and the rules blocks are byte-identical in SKILL.md and `repo-check.md`;
  - no forbidden word (RC-AC3) is in either.
- `plugins/agentic-workflow-kit/tests/leadtime.test.sh` gets cases for `--stdout` (CSV on stdout, no `reports/`) and `LEADTIME_ROOT`.
- `tests/run.sh` is a headless end-to-end run on a copy of `examples/demo-app`. It needs Claude Code and network and spends tokens, so it is not part of CI:
  - a scan, then a probe turn asking for `npm test` (the hook must block it);
  - a German interview with scripted answers.

  It checks the git status, the report, the canary in the transcript, the forbidden words and the number of questions. The findings go to `plugins/repo-check/docs/build-log.md`.

## 9. Acceptance

General
- RC-AC1: `/repo-check` with no mode asks "interview or scan" and does nothing else. `/repo-check interview` and `/repo-check scan` start directly.
- RC-AC2: Language follows the user's first message. German uses "du" for the reader and "ihr" for the team, never "Sie".
- RC-AC3: The sources and every output mention no prices, no promised dates, no customer names and no pressure. A forbidden-word test checks the sources and the headless transcripts (€, EUR, Preis, price, Rabatt, discount, "nur noch", "limited", "garantiert").
- RC-AC4: Nothing is sent. The email is a draft plus links the user opens. The hook blocks WebFetch, WebSearch, MCP tools, Agent, `curl` and `gh` writes.

Interview
- RC-AC5: Exactly the ten questions of 2.2 in order, one per message, with numbered options plus free text. The intro says about ten minutes and that answers stay in the chat.
- RC-AC6: A skipped or unclear answer is recorded as "offen"/"open", and the interview continues.
- RC-AC7: The result names the jam (Schreiben, Review or Release) with the answers it rests on, three steps the team can take alone, and the fitting offer or "none yet" with the reason.
- RC-AC8: The email draft has a subject and one heading per question, then the assessment. It is followed by a mailto link to `hi@vito.koeln` (subject and body URL-encoded; above 1,800 characters subject only, with "paste the draft") and the booking link `https://calendar.app.google/N14WVsxK4fdqBhZv6` in one neutral sentence. Nothing is sent automatically.

Scan: enforcement
- RC-AC9: The `read-only` hook enforces table 5.2 from the first `/repo-check` until the session ends, also after a resume, and leaves other sessions alone (5.1). Its block message says to start a new session to edit.
- RC-AC10: Secret files (5.2) are never read through Read, Grep, Glob or Bash arguments.
- RC-AC11: No install, build, test, lint, seed or migration command and no writing git subcommand runs.
- RC-AC12: `allowed-tools` pre-approves the read-only set. The skill and the README say the hook is the enforcement.
- RC-AC13: gh runs only after the user agrees in chat and approves the permission prompt (`ask`). Only the read-only calls of 5.2 are possible; every other gh call is blocked.

Scan: content
- RC-AC14: Every one of the five stages has a verdict by table 3, with the file path or command it rests on.
- RC-AC15: Review numbers come from leadtime with gh, or from git first-parent history without it. Without gh, time to first review and review rounds read "n/a: needs GitHub data".
- RC-AC16: At most four baseline numbers, each with its source and PR count. Below ten PRs, leadtime's warning is printed (translated in German).
- RC-AC17: `.repo-check/report.md` has the six sections of 2.3 in order, and `git status --porcelain --untracked-files=all` is the same before and after the scan.
- RC-AC18: The anonymised block contains no `/`, no git author names or emails, no gh logins, no repo name or remote URL, and no code fence.
- RC-AC19: After writing, the skill prints the anonymised block and asks about the email draft. The draft comes only after a yes.
- RC-AC20: The report has no code fence, and no line longer than 20 characters from a tracked file appears in it.

Hosted prompt
- RC-AC21: `build` generates `repo-check.md` from SKILL.md's shared blocks and the prompt-only parts. `build --check` fails on any difference, and the question and rules blocks are byte-identical in both.
- RC-AC22: The hosted prompt runs the full interview and the reduced scan of section 6 (git and `git ls-files` only, no file contents, nothing written, report in chat), and says that no hook enforces it.

Plugin
- RC-AC23: `repo-check` is listed in `.claude-plugin/marketplace.json`, `claude plugin validate` passes for the plugin and the marketplace, and the plugin depends on no `.claude/` file in the target repo.
- RC-AC24: The plugin's `leadtime` is byte-identical to the kit's. leadtime supports `--stdout` and `LEADTIME_ROOT`, and LEAD-AC1 to AC5 still pass.
- RC-AC25: The headless run on a copy of `examples/demo-app`:
  - the scan meets RC-AC14 to AC20;
  - the `.env` canary never appears in the transcript;
  - the probed `npm test` is blocked by the hook;
  - the German interview meets RC-AC2 to AC8.

## 10. Open

- Contact address and booking link are set once each in SKILL.md; `build` carries them into the hosted prompt.
- The wording of the offers and their fit rules (section 4).
- The verdict thresholds (section 3).
- Resolved: `${CLAUDE_PLUGIN_ROOT}` works in the frontmatter hook, and the lock across a resume comes from the session mark (5.1).

## 11. Out of scope

- Sending anything, collecting leads automatically, or any telemetry.
- Euro prices, packages or availability.
- Languages other than German and English.
- Non-GitHub APIs (GitLab, Bitbucket). Those repos get the git-only scan.
