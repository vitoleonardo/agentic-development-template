# Team playbook: rolling the kit out in one week

This plan takes one team from installing the kit to shipping features through it, in five working days. It assumes one repository, two to eight developers, and one person who owns the rollout (the "kit owner"). Start with the repository where agents already write the most code.

## Before Monday

- Pick a small, real feature for Wednesday: one to three days of work, touching code that has tests.
- Make sure the repository's typecheck, lint and test commands pass on `main`. The kit makes Claude run them constantly; if they are red already, every session starts by fighting old failures.
- Every developer updates Claude Code to the current version.

## Day 1: install and verify (kit owner, about 2 hours)

1. Install on a branch: `./install.sh <repo> --adapter <adapter> --preset <preset>`. Merge any file the installer kept by hand, usually `CLAUDE.md` or `.claude/settings.json`.
2. Fill in "Project facts" in `CLAUDE.md`. Facts only: stack, commands, what CI runs, what only a human can do.
3. Run every check once: `.claude/bin/check typecheck`, `lint`, `test`, `test-related <a source file>`, `build`. Fix `.claude/kit.conf` until each one passes on clean code and fails on a deliberate error.
4. Start `claude` in the repository, accept the trust prompt, and try the guardrails: ask it to `cat .env` and to run `rm -rf src`. Both must be refused.
5. Break a test on purpose through Claude ("round every price down") and watch the hook report the failure in the same turn.
6. Open a pull request with the kit. The CI workflow runs on it; fix what it reports before merging.

Done when: the kit is on `main`, CI is green, and the owner has seen the guard, the hooks and CI each catch something.

## Day 2: write specs (whole team, 90 minutes together)

The spec is the part teams find hardest, and the rest depends on it.

1. Together, run `/spec-feature` for Wednesday's feature. Answer Claude's questions as a group.
2. Read the result: does every acceptance criterion describe something a person can check with yes or no? Does the user flow match how users really work? What is out of scope?
3. Each developer runs `/spec-feature` for one item from the backlog on their own. Compare the specs in the afternoon and note what `spec-lint` and the reviewer rejected.
4. Agree who approves specs. Usually the developer who will build the feature, plus the product owner for anything users see.

Done when: Wednesday's spec is approved and marked `approved` in `specs/README.md`.

## Day 3: first feature end to end (pair or mob)

1. Run `/ship-feature <feature>`. It reads the approved spec and writes the plan to `.work/<branch>.md`.
2. Review the plan like a design review: data, contract, permissions, error states, which existing code it reuses. Change it until you would accept it from a colleague. Then approve.
3. Let it build. Watch the verify log in the state file: each criterion needs a failing test run before the passing one.
4. When it asks before pushing, read the review and the PR description first.

Expect it to stop and ask a few times. That is the workflow working: it stops at approval gates, after two failed fixes, and when the spec and the code disagree.

Done when: the pull request is open with the PR description, and CI is green.

## Day 4: review, merge, protect

1. Review the pull request as a human. Check it against the acceptance criteria, not just the code. Try the feature.
2. Merge, then set the feature to `done` in `specs/README.md`. Only a person who checked it does that.
3. In the repository settings, make the `quality-gates` workflow a required status check on `main`.
4. Collect what got in the way during the first three days: commands the guard blocked that were fine, permission prompts that came too often, checks that were too slow. Fix them in one pull request (see [customizing.md](customizing.md)). Each fix to the guard gets a test.

Done when: branch protection requires the gates, and the first round of fixes is merged.

## Day 5: retro and next steps (30 minutes)

Look at the week's pull requests and ask:

- Which problems did the spec, the reviewer, the hooks or CI catch before a human did?
- Where did Claude stop to ask, and was the question worth it?
- Which rules were broken anyway? Make those a check, not a longer rule.

Then decide what comes next: more repositories (consider the [plugin](customizing.md#use-it-as-a-plugin), so skills and hooks update in one place), more presets for your frameworks, or the sandbox.

## Everyday habits

- **Small fixes**: no spec needed, but still a test that fails first. Say so in the PR.
- **After a break**: start a new session and say "continue". Claude reads `specs/README.md` and `.work/<branch>.md` and picks up from there.
- **A check is red on purpose**: when a test is written to fail first, Claude records it in the state file and says so. A red check without that note is a real failure.
- **The guard blocked something you need**: run the command yourself. If it should never have been blocked, fix the pattern and add a test.
- **The spec turns out wrong mid-build**: Claude stops and asks. Change the spec first, get it approved again, then continue. Never let the code and the spec drift apart.
- **Never edit the rules or hooks to make a check pass.** Change them deliberately, in their own pull request.

## Signs it is working

After a few weeks you should see:

- pull requests that link a spec and list each criterion with its test;
- review comments about design and product decisions rather than missing tests or typos;
- fewer "works on my machine" failures in CI, because the same checks ran in every session;
- new developers shipping through the same flow in their first week.

## Record the demo

For a README GIF or an internal demo, record on the demo app (see [its README](../examples/demo-app/README.md)) so no client code is visible:

1. Prepare the copy, install the kit, and run `npm ci` before recording.
2. Use a terminal of 100 x 30 characters and a large font.
3. Record three short clips: `/ship-feature` up to the plan approval; the broken-edit hook (ask it to round every share down); the guard refusing `rm -rf src`.
4. Cut waiting time. Keep each clip under 30 seconds.
