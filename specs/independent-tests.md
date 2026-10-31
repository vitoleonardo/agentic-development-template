# Independent acceptance tests

ID prefix: ATEST

## Goal
A team that builds features with `/ship-feature` gets acceptance tests that an agent wrote from the spec before any code existed. The agent that writes the code cannot change them by any tool, so a test cannot carry the same misunderstanding as the code it checks.

## User flow
1. The developer approves a plan and `/ship-feature` starts the build.
2. For each task with criteria, the test-writer writes that task's tests from the spec and the plan's test cases, before the implementer starts. The main session runs them and sees each one fail for the expected reason. Every file the test-writer created or changed for the task becomes locked: tests, helpers and fixtures alike.
3. The implementer gets the task and the locked tests and writes the code until they pass. It reports the locked tests green; their red runs come from the test-writer. It may add more tests in files that are not locked, red first as before.
4. When the implementer thinks a locked test is wrong, or needs a change in a locked file (an import after a move, a helper), it stops and reports it under its open issues. The main session judges the claim against the criterion text: an upheld claim goes to the test-writer, a rejected one goes back to the implementer with the ruling, and a claim that the spec itself is wrong stops for the user.
5. A locked test that passed on its first run is checked by breaking the code on purpose; the result goes into the PR's evidence.
6. A hotfix on a feature with a spec follows the same path: the test-writer writes the red test, and it becomes locked.

## Terms
- **Locked file**: a file the test-writer created or changed for a task of the branch, as listed in the branch's state file. Files stay locked until the branch is merged.
- **Lock list**: the list of locked files in the branch's state file.
- **Task with criteria**: a plan task that covers at least one acceptance criterion with a test, not one the plan marks as checked another way.
- **First run**: the test-writer's run of a version of a locked test, before the implementer is dispatched for it.
- **Never failed**: a locked test whose first run passed.

## Acceptance criteria
- **ATEST-AC1**: Given an approved plan whose task 1 covers INVITE-AC1, when `/ship-feature` builds task 1, then the test-writer is dispatched for task 1 before the implementer is dispatched for task 1.
- **ATEST-AC2**: Given the test-writer wrote a test for INVITE-AC1, when the implementer is dispatched for task 1, then the state file already records that test's red run with the test-writer as its author.
- **ATEST-AC3**: Given the test-writer created `src/invite.test.ts` and changed `src/test-helpers.ts` for task 1, when the main session records the task's tests, then the lock list names both files.
- **ATEST-AC4**: Given `src/invite.test.ts` is locked, when the implementer edits it with the edit tools, then the guard blocks the edit with a message that contains `src/invite.test.ts is a locked acceptance test`.
- **ATEST-AC5**: Given `src/invite.test.ts` is locked, when the implementer runs a shell command that writes, moves or deletes it, then the guard blocks the command.
- **ATEST-AC6**: Given a lock list in the state file, when the implementer writes to the state file by any tool, then the guard blocks the write.
- **ATEST-AC7**: Given `src/invite.test.ts` is locked, when the test-writer edits it, then the guard lets the edit through.
- **ATEST-AC8**: Given `src/invite.test.ts` is locked, when the main session edits it, then the guard lets the edit through.
- **ATEST-AC9**: Given `src/invite.test.ts` is locked and `src/format.test.ts` is not, when the implementer edits `src/format.test.ts`, then the guard lets the edit through.
- **ATEST-AC10**: Given the implementer was blocked on a locked file, when it returns, then its report lists that file under open issues.
- **ATEST-AC11**: Given the implementer reports that locked test `src/invite.test.ts` contradicts INVITE-AC1 and the main session upholds the claim, when the main session continues, then the state file has a Stops line with the class `test`, the test-writer changes the test, and the changed test has a new red run before the implementer is dispatched again.
- **ATEST-AC12**: Given the implementer reports that a locked test contradicts INVITE-AC1 and the main session rejects the claim, when the main session continues, then the state file has a Stops line whose resolution starts with `rejected` and the implementer is dispatched again with the ruling.
- **ATEST-AC13**: Given the implementer reports that INVITE-AC1 itself is wrong, when the main session continues, then the state file has a Stops line with the class `spec` and the run waits for the user.
- **ATEST-AC14**: Given a locked test for INVITE-AC2 whose first run passed, when the task's implementer has returned, then the state file records whether that test failed when the code was broken on purpose.
- **ATEST-AC15**: Given a locked test that never failed, when `/pr-description` writes the evidence, then the evidence names that test, its criterion and the result of breaking the code on purpose.
- **ATEST-AC16**: Given a hotfix on a feature with a spec, when the fix is built, then the test-writer writes its red test and the lock list names that test.

## Edge cases
- **ATEST-AC17**: Given a plan task whose only criterion the plan marks as checked another way, when `/ship-feature` builds that task, then the test-writer is not dispatched for it.
- **ATEST-AC18**: Given a task that failed its checks once, when it is retried a tier higher, then the test-writer is not dispatched again and the lock list is unchanged.
- **ATEST-AC19**: Given a branch whose state file has no lock list, when the implementer edits `src/invite.test.ts`, then the guard lets the edit through.
- **ATEST-AC20**: Given a branch without a state file, when the implementer edits `src/invite.test.ts`, then the guard lets the edit through.
- **ATEST-AC21**: Given the locked file `packages/api/src/invite.test.ts` in a monorepo, when the implementer edits that file, then the guard blocks the edit.
- **ATEST-AC22**: Given a locked file whose path contains a space, when the implementer edits that file, then the guard blocks the edit.
- **ATEST-AC23**: Given task 2 runs after task 1 was committed, when the implementer for task 2 edits a locked file of task 1, then the guard blocks the edit.
- **ATEST-AC24**: Given the simplify step moves `src/invite.ts` so that the import in locked test `src/invite.test.ts` breaks, when the implementer reports it, then the test-writer changes the import and the implementer does not.
- **ATEST-AC25**: Given the test-writer reports that task 1's code cannot be tested without a change, when the main session continues, then the state file has a Stops line with the class `plan` and the implementer has not been dispatched for task 1.
- **ATEST-AC26**: Given a locked end-to-end test whose red run needs code that does not exist yet, when the test-writer returns, then the state file records `not run: <reason>` as its red run and the PR evidence names the test.
- **ATEST-AC27**: Given the test-writer needs a fixture file it may not write, when it returns, then the state file has a Stops line with the class `plan` or `kit` naming that file.
- **ATEST-AC28**: Given the implementer's claim on a locked test was upheld twice for the same test, when it reports that test a third time, then the run stops and waits for the user, as for any failure that came back after two fixes.

## Out of scope
- Small fixes without a spec: the implementer still writes the regression test itself.
- A reviewer from another vendor, mutation testing tools, and test quality scoring.
- Locking files against the main session or the user.
- Changing what `/write-tests` does when run on its own.

## Open questions
- Should a team be able to turn this off to save one dispatch per task, or is it always on? (Viktor)

## Decisions
- 31.10.2026: Files stay locked for the whole branch, not only for their task, because the spec does not change during the build, so a later task has no reason to change an earlier criterion's test without going through the test-writer.
- 31.10.2026: Only the implementer is locked out. The main session and the user may still edit a locked file, because a person fixing a wrong test should not need a workaround.
- 31.10.2026: The lock list lives in the branch's state file, because that file survives a new session and a resumed autopilot run.
- 31.10.2026: Every file the test-writer touches for a task is locked, helpers and fixtures included, because a test can be weakened through its helper. The implementer then reports a needed change instead of making it, which costs a dispatch.
- 31.10.2026: The main session judges a claim against a locked test before the test-writer changes it, because sending every claim back would let the implementer's reading of the criterion win again. Spec review, 31.10.2026.
