# Build log

What the tests and the headless runs caught while building repo-check. Newest first.

## 30.10.2026: repo-check v0.1

Spec: [SPEC-repo-check.md](SPEC-repo-check.md). New: the `repo-check` plugin (skill, `read-only` hook, scanner, generated `leadtime`), the hosted prompt `repo-check.md`, `build`, and `.github/workflows/repo-check.yml`. Tests: `tests/hook.test.sh` (126 cases), `tests/scan.test.sh` (93), `tests/prompt.test.sh` (30), all also under `dash`, plus two new cases in the kit's `tests/leadtime.test.sh`. `claude plugin validate` passes for the plugin and the marketplace; the only warning is the missing listing icon.

- **What the docs say decided the enforcement** (checked 30.10.2026):
  - `allowed-tools` only pre-approves tools for the turn that invokes the skill, and `disallowed-tools` clears on the next message. Neither restricts a ten-turn interview.
  - Hooks in a skill's frontmatter "stay registered for the rest of the session".
  - So the hook is the enforcement, and `allowed-tools` only saves prompts.
- **A probe plugin showed what "rest of the session" means.**
  - The frontmatter hook fired, `CLAUDE_PLUGIN_ROOT` reached it, and it blocked Bash with exit 2.
  - It still fired for the next message in the same process (stream-json input).
  - It did not fire after `claude -p --resume`, which starts a new process.
  - `${CLAUDE_SKILL_DIR}` is not substituted in a hook command.

  So the same script is also registered in the plugin's `hooks.json`. That registration enforces only in sessions the skill has marked.
- **`CLAUDE_PLUGIN_DATA` in a frontmatter hook names another plugin's folder.** In the second headless run the lock was gone after the resume.
  - `npm test` ran; it failed only because vitest is not installed in the copy.
  - The model read the `.env` canary.
  - `notes.md` was written outside `.repo-check/`.

  A probe showed the cause: the skill's hook got `CLAUDE_PLUGIN_DATA=~/.claude/plugins/data/codex-openai-codex`, so its session marks landed in that plugin's folder, and the `hooks.json` registration looked in `repo-check-inline`. The marks now go to `${XDG_STATE_HOME:-~/.local/state}/repo-check/read-only-sessions/`, which both registrations compute the same way. `tests/hook.test.sh` sets a wrong `CLAUDE_PLUGIN_DATA` on purpose. I removed my three stray empty marks from the codex plugin's folder; its `state/` was not touched.
- **A passing check proved nothing at first.** In the first run the model refused `npm test` without calling the tool, which is good behaviour but no test of the hook. The check passed on a block from the first turn, where the hook stopped `git rev-parse && git remote -v`. The probe turn now tells the model to call Bash, Read and Write anyway, and the check counts blocks in the resumed process only. In the third run all three were blocked, and the canary never reached the model.
- **One import commit made Review red.** The demo copy has one 3,600-line commit, and the scanner called that a large PR. Below 10 PRs or merges, Review is now yellow and says "too few to judge". A third fixture in `tests/scan.test.sh` pins it.
- **The skill now says "one command per Bash call."** The model chained `git rev-parse && git remote -v` in the first run and needed a second try. In the third run no call was blocked during the scan.
- **The scanner decides what a script can decide.** It produces the verdicts, the jam, the numbers and the shareable summary, all deterministically. The model writes only the reason, the three steps and the offer line, into marked places.

  The tests caught three bugs:
  - "test, lint, typecheck" never matched, because the comma patterns overlapped;
  - the summary extraction used `\|`, which BSD sed does not support, so the privacy checks ran on empty text until a size check caught it;
  - "ben" matched inside "Weitergeben", so names are now checked as whole words.

  A planted line from a tracked file proves that the leak check can fail.
- **Expected values in `tests/scan.test.sh`, calculated by hand**, with today = 30.09.2026:
  - `pnpm-monorepo` with gh: leadtime's `prs.json` over 02.07.–30.09.2026 gives 7 PRs, PR size 40.0, first review 3.5 h, rounds 0.0 and rework 28.6 %. Review is yellow (below 10 PRs), and Release is yellow (7 × 7 / 90 = 0.5 merges per week). Specs, `AGENTS.md` with permissions, and a CI running test, lint and typecheck with strict TypeScript make Intent, Build and Gates green, so the jam is Review.
  - `python-pkg`, git only: four `--no-ff` merges of 10, 20, 3 and 40 lines (median 15.0). "fix a" touches `a.py` 9 days after the merge that added it, so 1 of 4 is reworked (25.0 %). That is 0.3 merges per week, two tags, and the last merge 10 days ago. Intent, Build and Gates are red, so the jam is Intent.
- **Headless runs on a copy of `examples/demo-app`** (Sonnet, `--plugin-dir`, `bypassPermissions` standing in for the user's approvals, with the hooks still running; `tests/run.sh`):
  - Scan, third run, 17 of 17 checks:
    - `git status` was unchanged, and every marker in the report was filled;
    - all five stages had evidence, and the summary held no path, name or code fence;
    - the jam was Build, because the demo has no agent guide;
    - the offer was "noch keins", with what the scan could not judge;
    - the email draft carried the mailto and the booking link.
  - Interview, German, scripted answers, 9 of 9 checks:
    - ten questions, one per message, in the "du" form;
    - the skipped question 6 was recorded as "offen";
    - the jam was Review, from questions 5 and 8;
    - the offer was Pilot, and the draft had both links;
    - no price or pressure words appeared.
  - Hosted prompt without the plugin, 6 of 6 checks: it used only git, wrote nothing, kept the canary out, printed the jam and the summary, and marked unchecked rows "(reduzierter Scan)". It counted contributors with `| sort -u | wc -l`, which keeps addresses out of the chat, so the prompt now lists exactly that command.
- **Not done:**
  - The gh path live. The demo copy has no GitHub remote; `--gh` is covered by the fake `gh` with recorded data.
  - The hook's `ask` prompt in front of a real user.
  - An English interview.
  - A mailto body over 1,800 characters.
  - An install from the marketplace, which copies the plugin into the cache. All runs used `--plugin-dir`.
  - The kit's `spec to merge` case fails on macOS before and after this change (GNU `sed -i` in the test). CI runs on Linux.
