# Stack stage

ID prefix: STAGE

## Goal
The slow checks run once per stack, as the last check before it merges, not once per pull request and push. Today a feature runs Playwright up to five times (verify's data run, screenshots on the branch and on the base, the review screenshots, and CI on every push), and three stacked pull requests of a project with a 20-minute suite spend over an hour on e2e. The stack stage runs the e2e tests the stack's changes select, takes the screenshots in that same run, and runs mutation tests on the changed lines, in CI by default or in the checkout. The screenshots go into each layer's pull request, next to its criteria.

## User flow
1. A build submits its layers as pull requests (`specs/stacked-groups.md`). Their CI runs only the fast gates.
2. After the last feature of the build, the build starts the stack stage on the top layer: one CI run, or one local run with `KIT_STACK_CHECKS=local`.
3. The run executes the selected e2e tests, which save a screenshot per criterion step, and mutation tests on the stack's changed lines, side by side.
4. Red e2e tests or surviving mutants start a session that fixes them on the top layer; then only the red tests and the survivors' files run again.
5. Once both are green, a reviewer checks the screenshots against the criteria, and each layer's pull request gets its criteria's screenshots and the mutation score in its description.
6. Every layer's head gets the statuses `kit/e2e` and `kit/mutation`. The stack can merge (`specs/risk-gates.md`).
7. After the merge, the whole e2e suite runs on the default branch, as today.

## Terms
- **Stack**: the layers of the features one build submitted, bottom to top (`specs/stacked-groups.md`).
- **Stack top**: the top layer's branch and head.
- **Stack diff**: the changes from the stack base to the stack top.
- **Location**: `KIT_STACK_CHECKS`, `ci` (the default, also when empty), `local`, or `off` for no stack stage: verify then runs the seed and the e2e tests itself, as before.
- **Stack run**: one run of the stack checks at the location: the CI workflow `stack-checks.yml` with its jobs `e2e` and `mutation`, or both steps in the checkout.
- **Screenshot**: a PNG named `<AC-ID>-<step>-<viewport>.png` that an e2e test writes into `KIT_SCREENSHOT_DIR`.
- **Mutation score**: killed and timed-out mutants divided by all mutants on the stack diff's changed lines, minus the mutants listed in the exceptions file, in percent.
- **Survivor**: a mutant on a changed line with status survived or no coverage that the exceptions file does not list.
- **Exceptions file**: `KIT_MUTATION_EXCEPTIONS`, default `.kit/mutation-exceptions.tsv`, rows `<file> TAB <line> TAB <mutator> TAB <reason>`.
- **Red test**: an e2e test file with a failed test in the last stack run.

## Acceptance criteria

Fewer runs:

- **STAGE-AC1**: Given a build with the stack stage on, when `/verify-feature` runs in a final session, then no e2e command and no screenshot command runs.
- **STAGE-AC2**: Given a build with the stack stage on, when `/verify-feature` writes the data runs, then the e2e row reads `deferred: stack stage`.
- **STAGE-AC3**: Given a pull request of a stack, when the adapter's `evidence.yml` runs on it, then it runs no seed, e2e or screenshot command.
- **STAGE-AC4**: Given a build of 2 features with 2 layers each, when the build has ended with a green stage, then exactly one stack run started for e2e.
- **STAGE-AC5**: Given a push to the default branch, when the adapter's `evidence.yml` runs, then the full-e2e job runs the whole suite.

In CI:

- **STAGE-AC6**: Given location `ci`, when the stage starts, then `gh workflow run stack-checks.yml` ran with `--ref` the stack top and inputs `base`, `layers` and `kit_run`.
- **STAGE-AC7**: Given location `ci` and two runs of `stack-checks.yml` on the stack top, when the stage looks for its run, then it watches the run whose title holds its `kit_run` and whose head is the stack top's head.
- **STAGE-AC8**: Given a stack run that is still running after `AUTOPILOT_MAX_SESSION_SECONDS`, when the build's limit is reached, then the run log's closing line starts with `Stopped at ` and names the stack run.
- **STAGE-AC9**: Given a finished stack run, when the stage reads its result, then the `kit-stack` artifact's screenshots are in `.work/<top branch>/stack/screenshots/`.
- **STAGE-AC10**: Given the stack run's e2e job passed, when the run has ended, then every layer head has the status `kit/e2e` with state `success`.
- **STAGE-AC11**: Given the stack run's mutation job reports a score of 59 with threshold 60, when the run has ended, then every layer head has the status `kit/mutation` with state `failure`.

Locally:

- **STAGE-AC12**: Given location `local`, when the stage runs, then no `gh workflow run` call is made and the e2e command runs once in the checkout.
- **STAGE-AC13**: Given location `local` and passing e2e and mutation steps, when the stage has run, then every layer head has the statuses `kit/e2e` and `kit/mutation` with state `success`.

Selection and screenshots:

- **STAGE-AC14**: Given a stack whose layers change `src/invoices/total.ts` and `src/time/entry.ts` and a map with rows for both, when the stack run's e2e job selects tests, then it runs the files of both rows and no other.
- **STAGE-AC15**: Given an e2e test that calls the adapter's screenshot helper with `INVITE-AC1` and step `form`, when the stack run's e2e job runs on the `desktop` project, then `INVITE-AC1-form-desktop.png` is among the downloaded screenshots.
- **STAGE-AC16**: Given `KIT_SCREENSHOTS` is empty and the e2e tests write screenshots, when the stage runs, then no command other than the e2e command took screenshots.

Red tests:

- **STAGE-AC17**: Given a stack run with `e2e/time.spec.ts` red and every other selected file green, when the fix session has committed its fix, then the next stack run's `tests` input is `e2e/time.spec.ts`.
- **STAGE-AC18**: Given a rerun of only the red files that passes, when the stage continues, then `kit/e2e` on every layer head has state `success`.
- **STAGE-AC19**: Given a red e2e test, when the fix session starts, then its prompt holds the red test's failure output and the session runs on the model of the verify role.
- **STAGE-AC20**: Given a fix session for a red test, when it ends, then its commits are on the stack top and on no lower layer.
- **STAGE-AC21**: Given the same red test after 2 fixes, when the stage continues, then no further session starts and the run log's closing line starts with `Stopped at `.

Mutation:

- **STAGE-AC22**: Given a stack diff that changes lines 10 to 14 of `src/total.ts`, when the mutation step runs, then `KIT_MUTATION` gets `src/total.ts:10-14` and no range outside the stack diff.
- **STAGE-AC23**: Given 10 mutants on the changed lines with 7 killed, 1 timed out and 2 survived, when the score is computed, then it is 80.
- **STAGE-AC24**: Given 10 mutants with 5 killed and 5 survived, of which 2 are listed in the exceptions file, when the score is computed, then it is 62.
- **STAGE-AC25**: Given a score below `KIT_MUTATION_THRESHOLD`, when the stage continues, then a session dispatches the `test-writer` with the survivors' file, line and mutator in its prompt.
- **STAGE-AC26**: Given a score still below the threshold after the test-writer's round, when the stage continues, then no further session starts and Stops holds a new line of class `test` that names the score.
- **STAGE-AC27**: Given `KIT_MUTATION` is `n/a: <reason>`, when the stage runs, then the mutation status is `success` with the reason as its description.
- **STAGE-AC28**: Given `KIT_MUTATION` is empty, when the stage runs, then `kit/mutation` has state `failure` with a description that names `KIT_MUTATION`.
- **STAGE-AC29**: Given a mutation report from Stryker, when the adapter's `mutation-files.mjs` reads it, then it prints one `<file> TAB <line> TAB <mutator> TAB <status>` row per mutant.

Into the pull requests:

- **STAGE-AC30**: Given a green stage and a layer whose group covers `INVITE-AC1`, when the descriptions are updated, then that layer's pull request body holds an image link to `INVITE-AC1-form-desktop.png` on `kit-evidence`.
- **STAGE-AC31**: Given a layer whose group covers no criterion with a screenshot, when the descriptions are updated, then its body holds no `### Screenshots` heading.
- **STAGE-AC32**: Given a body that already holds a `<!-- kit-stage -->` block, when the descriptions are updated again, then the body holds exactly one such block.
- **STAGE-AC33**: Given a green stage, when the descriptions are updated, then every layer's body holds a line with the mutation score, the killed and the survived count.
- **STAGE-AC34**: Given a green stage, when the reviewer checks the screenshots, then its report is saved to `.work/<top branch>/stack/screenshots-review.md` before any description is updated.
- **STAGE-AC35**: Given the screenshot review reports a high finding, when the stage continues, then no description is updated and a fix session starts with the finding in its prompt.

Records:

- **STAGE-AC36**: Given a running stage, when the status command runs with `--json`, then `autopilot.current.phase` is `stack`.
- **STAGE-AC37**: Given a stage that ran a fix session, when the build has ended, then `.work/autopilot/sessions.tsv` holds a row with phase `stack`.

Without a stage:

- **STAGE-AC42**: Given `KIT_STACK_CHECKS="off"`, when `/verify-feature` writes the data runs, then the e2e row holds the e2e run's own result.
- **STAGE-AC43**: Given the stack stage on and an edge case whose test is an e2e test that has not run, when `evidence matrix` runs at verify, then that case reads `deferred: stack stage` and the matrix does not fail for it.
- **STAGE-AC44**: Given the stack stage's e2e results in the pack, when `evidence matrix` runs again, then that case reads `pass` or `fail` from those results.

## Edge cases
- **STAGE-AC38**: Given a stack diff that only changes tests and docs, when the stage runs, then the e2e job records `none` and `kit/e2e` has state `success`.
- **STAGE-AC39**: Given a stack diff without a changed line in a source file, when the mutation step runs, then no mutant is generated and `kit/mutation` has state `success`.
- **STAGE-AC40**: Given location `ci` and `stack-checks.yml` missing on the default branch, when the stage starts, then no session starts and the run log's closing line names `stack-checks.yml` and the default branch.
- **STAGE-AC41**: Given a `/fix-bug` branch with one layer, when the fix is submitted, then the stage runs on that branch as a stack of one.

## Out of scope
- Deciding whether a person approves the merge, and merging; that is `specs/risk-gates.md`.
- Base screenshots (`.main.png`) in the stage: a single run on the stack top cannot take them.
- Running the stage per layer, or after each push.
- A Java adapter (PIT).

## Open questions

## Decisions
- 04.11.2026: E2e runs once per stack, on the stack top, as the last check before the merge, because per-layer and per-push runs multiply a 20-minute suite (ADR-065, ADR-066 in os.home). A break in a lower layer is found at the stage, and the whole suite still runs after the merge.
- 04.11.2026: CI is the default location and `local` is the option, because a home server may be too weak for a browser suite while CI minutes may cost. The user chose: "Standard is CI, but local is also possible."
- 04.11.2026: The screenshots come from the e2e run itself, so the stage needs one browser run, not three; base screenshots are dropped from the stage.
- 04.11.2026: The CI workflow posts `kit/e2e` and `kit/mutation` on every layer head itself, so the result does not come from the agent, and no pull request workflow has to run again.
- 04.11.2026: Mutation tests are a hard gate at 60 on the changed lines, with one test-writer round on the survivors first, because the tests are the evidence that the code works. Exceptions sit in a committed file so CI applies them, and a change to it needs a person (`specs/risk-gates.md`).
- 04.11.2026: Fixes from the stage go on the stack top, as in `specs/stacked-groups.md`.
- 04.11.2026: `KIT_STACK_CHECKS="off"` keeps the per-feature e2e run for projects that have no stage workflow yet; the adapters ship `stack-checks.yml` for TypeScript only, so a Python project sets `local` or `off`.
