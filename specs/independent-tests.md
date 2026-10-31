# Independent acceptance tests

ID prefix: ATEST

## Goal
A team that builds features with `/ship-feature` gets acceptance tests that an agent wrote from the spec before any code existed. The agent that writes the code cannot change them, so a test cannot carry the same misunderstanding as the code it checks.

## User flow
1. The developer approves a plan and `/ship-feature` starts the build.
2. For each task with criteria, the test-writer writes that task's tests from the spec and the plan's test cases, before the implementer starts. The main session runs them and sees each one fail for the expected reason.
3. The state file lists those tests as locked, and the Verify log names the test-writer as their author.
4. The implementer gets the task and the locked tests and writes the code until they pass. It can read the locked tests but not change them.
5. When the implementer thinks a locked test is wrong, it stops and reports it. The main session records a `test` stop and dispatches the test-writer to change the test.
6. The PR description lists every locked test that passed before the code existed.

## Terms
- **Locked test**: a test file listed under `## Locked tests` in the branch's state file, one path from the repository root per line.
- **Task with criteria**: a plan task that covers at least one acceptance criterion with a test, not one the plan marks as checked another way.
- **Never failed**: a locked test whose first run, before the implementer's dispatch for its task, passed.

## Acceptance criteria
- **ATEST-AC1**: Given an approved plan whose task 1 covers INVITE-AC1, when `/ship-feature` builds task 1, then the usage record lists a test-writer dispatch described as `task 1 tests` before the implementer dispatch described as `task 1`.
- **ATEST-AC2**: Given the test-writer returned tests for task 1, when the main session dispatches the implementer for task 1, then the Verify log holds a row per new test with a filled Red seen cell and the note `author: test-writer`.
- **ATEST-AC3**: Given the test-writer created `src/invite.test.ts` for task 1, when the main session records the task's tests, then `## Locked tests` in the state file contains the line `- src/invite.test.ts`.
- **ATEST-AC4**: Given `src/invite.test.ts` is a locked test, when the implementer agent edits it, then the guard blocks the edit with the message `src/invite.test.ts is a locked acceptance test; report what is wrong with it instead of editing it.`
- **ATEST-AC5**: Given `src/invite.test.ts` is a locked test, when the test-writer agent edits it, then the guard lets the edit through.
- **ATEST-AC6**: Given `src/invite.test.ts` is a locked test, when the main session edits it, then the guard lets the edit through.
- **ATEST-AC7**: Given `src/invite.test.ts` is a locked test and `src/format.test.ts` is not, when the implementer agent edits `src/format.test.ts`, then the guard lets the edit through.
- **ATEST-AC8**: Given the implementer returns that the locked test `src/invite.test.ts` contradicts the spec, when the main session continues, then the state file has a Stops line with the class `test` and the next dispatch for that task is the test-writer.
- **ATEST-AC9**: Given a locked test for INVITE-AC2 passed on its first run, when `/pr-description` writes the description, then it lists that test with `INVITE-AC2` under `Never failed`.

## Edge cases
- **ATEST-AC10**: Given a plan task whose only criterion the plan marks as checked another way, when `/ship-feature` builds that task, then the usage record has no test-writer dispatch for it.
- **ATEST-AC11**: Given a state file without a `## Locked tests` section, when the implementer agent edits `src/invite.test.ts`, then the guard lets the edit through.
- **ATEST-AC12**: Given a branch without a state file, when the implementer agent edits `src/invite.test.ts`, then the guard lets the edit through.
- **ATEST-AC13**: Given the locked test `packages/api/src/invite.test.ts` in a monorepo, when the implementer agent edits that file, then the guard blocks the edit.
- **ATEST-AC14**: Given the test-writer reports that task 1's code cannot be tested without a change, when the main session continues, then the state file has a Stops line with the class `plan` and no implementer dispatch for task 1 has happened.
- **ATEST-AC15**: Given task 2 runs after task 1 was committed, when the implementer for task 2 edits a locked test of task 1, then the guard blocks the edit.
- **ATEST-AC16**: Given a locked test path that contains a space, when the implementer agent edits that file, then the guard blocks the edit.

## Out of scope
- Small fixes without a spec: the implementer still writes the regression test itself.
- A reviewer from another vendor, mutation testing, and test quality scoring.
- Locking tests against the main session or the user.
- Changing what `/write-tests` does when run on its own.

## Open questions
- Should a team be able to turn this off to save one dispatch per task, or is it always on? (Viktor)

## Decisions
- 31.10.2026: Tests stay locked for the whole branch, not only for their task, because the spec does not change during the build, so a later task has no reason to change an earlier criterion's test.
- 31.10.2026: Only the implementer is locked out. The main session and the user may still edit a locked test, because a person fixing a wrong test should not need a workaround.
- 31.10.2026: The lock list lives in the state file, because the guard already reads branch state from there and it survives a new session.
