# Group sessions

ID prefix: GROUP

## Goal
A developer who builds a feature larger than one small change gets it built in several fresh headless sessions, without losing context between closely related tasks. The plan splits the work into groups; one session implements each group with shared context, and subagents simplify and review its work. The new flow ships as a separate plugin version, so teams on the current kit see no change until it has been tested.

## User flow
1. The developer installs the plugin `agentic-workflow-kit-next` in a project instead of `agentic-workflow-kit`, updates the project files with its installer, and sets a token budget.
2. The developer runs `/ship-feature` in a terminal session and approves the spec and the plan. The plan shows the groups, the tier each group runs on, and any size limit it asks to approve.
3. `/ship-feature` starts the build, which keeps running on its own, and prints the run log's path. The developer leaves this checkout alone until the build ends, and may close the terminal.
4. One headless session runs per group, in plan order. Each implements its tasks, commits each one, and has subagents simplify and review the group's work. After each session the build runs its own checks.
5. One final session reviews the whole diff, verifies and opens the PR.
6. If the project's approval level asks before a push, the build stops there. The developer runs `/ship-feature` again in a terminal and approves the push.
7. For a backlog, the developer runs `.claude/bin/autopilot` from a shell, as today. Each feature builds the same way, without asking.

Where a build stops, the run log's closing line says why. Running the build again re-checks the last done group if nothing has built on it yet, then continues at the first group that is not done. Uncommitted changes that a fresh session can redo are stashed first.

## Terms
- **Group**: the tasks of a plan that share one value in the Tasks table's Group column. A plan without that column has groups `1`, `2` and so on, of three tasks each, counted over all its tasks in plan order.
- **Group session**: the headless session that implements one group's open tasks, started with `--group <id>`.
- **Final session**: the headless session that runs after the last group and ends with the PR, started with `--final`.
- **Group tier**: the highest tier among a group's tasks, in the order fast, standard, deep.
- **Done group**: every task of the group is ticked under Progress, no tracked file has uncommitted changes, and, in a plan with a Group column and more than one group, the group's last line in Rounds that starts with `- group <id> review ` ends with `| pass`.
- **Group diff**: the changes from the parent of the group's first task commit to the current commit, across all of the group's sessions. If a ticked task of the group has no commit naming it, the group diff starts at the base.
- **Failed check**: a check that exits with any code other than 0, 3 (not configured) or 4 (marked n/a). Where a baseline exists, the typecheck is compared with it, and failing related tests count as failed only if the whole suite's comparison with the baseline also fails.
- **Verified**: the last line in Rounds that starts with `- verify ` ends with `| pass`, and the evidence pack was made on the current commit.
- **Size limit**: the plan's `Approved size: <n> lines` if it has one, otherwise twice `KIT_MAX_CHANGED_LINES`.
- **Build**: one run of `.claude/bin/autopilot`, started from a shell or by `/ship-feature`.
- **Closing line**: as in the kit's status command, a run log line that starts with `Stopped at ` or `Every feature has a PR`.

## Acceptance criteria

Separate plugin:

- **GROUP-AC1**: Given this feature is complete, when its branch is compared with `main`, then no file under `plugins/agentic-workflow-kit/` differs.
- **GROUP-AC2**: Given this feature is complete, when the repository's marketplace file is read, then it lists both `agentic-workflow-kit` and `agentic-workflow-kit-next`.
- **GROUP-AC3**: Given this feature is complete, when the plugin file of `agentic-workflow-kit-next` is read, then its version is `0.4.0` or later.
- **GROUP-AC68**: Given only `agentic-workflow-kit-next` is installed, when `/review-diff` runs, then it runs in that plugin's reviewer agent.
- **GROUP-AC69**: Given only `agentic-workflow-kit-next` is installed, when `/write-tests` runs, then it runs in that plugin's test-writer agent.
- **GROUP-AC70**: Given the new plugin's installer has run without `--plugin`, when the project's skills are read, then none names an agent with a plugin prefix.
- **GROUP-AC71**: Given this feature is complete, when CI runs, then the test suites run for both plugin directories.
- **GROUP-AC72**: Given the new plugin's README, when a developer reads its install section, then it says a project installs only one of the two plugins.

Planning:

- **GROUP-AC4**: Given an approved spec, when `/plan-feature` writes the plan, then the Tasks table has a Group column with a value in every row.
- **GROUP-AC5**: Given a plan with a group above the default tier, when `/plan-feature` writes the plan, then one line under the table names that group and the reason.
- **GROUP-AC73**: Given an approved spec, when `/plan-feature` writes the plan, then no group holds more than 3 tasks.
- **GROUP-AC74**: Given an approved spec, when `/plan-feature` writes the plan, then each group's tasks are consecutive in plan order.
- **GROUP-AC75**: Given 2 consecutive tasks that name the same file and a group with room for both, when `/plan-feature` writes the plan, then both tasks are in one group.
- **GROUP-AC6**: Given a plan whose group holds 4 tasks, when a build starts, then no group session starts and the run log's closing line names that group and `at most 3 tasks`.
- **GROUP-AC7**: Given a plan whose tasks 1 and 3 are in group A and task 2 in group B, when a build starts, then no group session starts and the run log's closing line names group A and `not consecutive`.
- **GROUP-AC8**: Given a plan with a Group column and a task with an empty Group cell, when a build starts, then no group session starts and the run log's closing line names that task.
- **GROUP-AC158**: Given a feature plan without a `## Bug` section and a Tasks table without a Group column, when `plan-lint` runs, then a finding on the table's header line names the Group column.
- **GROUP-AC159**: Given a plan whose group A holds 4 tasks, when `plan-lint` runs, then a finding names group A and `at most 3 tasks`.
- **GROUP-AC160**: Given a plan whose tasks 1 and 3 are in group A and task 2 in group B, when `plan-lint` runs, then a finding names group A and `not consecutive`.
- **GROUP-AC161**: Given a plan with a Group column and a task with an empty Group cell, when `plan-lint` runs, then a finding names that task.
- **GROUP-AC162**: Given a group whose highest task tier is above the default tier and no `Group <id> <tier>: <reason>` line under the table, when `plan-lint` runs, then a finding on the group's first row names the missing line.
- **GROUP-AC163**: Given that group with its `Group <id> <tier>: <reason>` line, when `plan-lint` runs, then there is no finding for the group.
- **GROUP-AC164**: Given a plan with an `Approved size:` line that does not read `Approved size: <n> lines`, when `plan-lint` runs, then a finding on that line shows the form `Approved size: <n> lines`.
- **GROUP-AC165**: Given a plan with `Approved size: 3000 lines`, when `plan-lint` runs, then there is no finding for that line.
- **GROUP-AC166**: Given a fix plan, or a plan with a `## Bug` section, without a Group column, when `plan-lint` runs, then there is no finding for the Group column.

Group sessions:

- **GROUP-AC9**: Given a plan with group A (tasks 1 to 3) and group B (task 4), when a build runs, then exactly one session for group A starts, followed by exactly one for group B.
- **GROUP-AC10**: Given a group with a standard and a deep task, when its group session starts, then it runs on the model of the deep tier.
- **GROUP-AC76**: Given a deep-tier group whose session the watchdog stopped, when the fresh session starts, then it runs on the model of the deep tier.
- **GROUP-AC77**: Given a deep-tier group whose session ended with an answered question, when that session is resumed, then it runs on the model of the deep tier.
- **GROUP-AC78**: Given a deep-tier group whose session the usage limit stopped, when its next session starts, then it runs on the model of the deep tier.
- **GROUP-AC11**: Given a group session that completes 3 tasks with passing checks, when it ends, then the session dispatched no agent whose description starts with `task <n>`.
- **GROUP-AC12**: Given a group session that completes 3 tasks, when it ends, then the branch holds one commit per task whose message contains `task <n>`, in addition to any simplify and fix commits.
- **GROUP-AC79**: Given a completed task, when its session moves on, then the Verify log has filled Red seen and Green cells for each of the task's criteria.
- **GROUP-AC80**: Given a completed task, when its session moves on, then Notes holds a line for that task.
- **GROUP-AC142**: Given a group session ticks a task, when Progress is read, then the branch already holds a commit naming that task.
- **GROUP-AC13**: Given a plan with 2 groups, when a group's tasks are ticked, then the session dispatches a reviewer on the group diff with a description that starts with `group <id> review round 1`.
- **GROUP-AC14**: Given a plan with 2 groups, when a group's tasks are ticked, then the session dispatches the implementer with a description that starts with `simplify`, before its review.
- **GROUP-AC81**: Given a group review, when the reviewer is dispatched, then its prompt holds the Verify log rows of the group's criteria.
- **GROUP-AC82**: Given a group review, when the reviewer reports, then a criterion that belongs only to another group's tasks is not a finding.
- **GROUP-AC15**: Given a group on the standard tier, when its session dispatches the reviewer, then the reviewer runs on the model of the standard tier.
- **GROUP-AC16**: Given a group on the deep tier, when its session dispatches the reviewer, then the reviewer runs on the model of the deep tier.
- **GROUP-AC83**: Given a group on the lowest tier, when its session dispatches the reviewer, then the reviewer runs on the model of the standard tier.
- **GROUP-AC84**: Given a standard-tier group with a task retried on the deep tier, when its session dispatches the reviewer, then the reviewer runs on the model of the deep tier.
- **GROUP-AC17**: Given a group review round has ended, when the state file is read, then Rounds holds a line that starts with `- group <id> review <n> | `.
- **GROUP-AC18**: Given 3 of 7 tasks ticked and Rounds holding only `- group A review 1 | delta | a..b | pass`, when the status command runs with `--line`, then the stage part reads `build`.
- **GROUP-AC19**: Given a group session's review reports a high finding, when the session fixes it, then the session reviews again before it ends.
- **GROUP-AC20**: Given a group with open high findings after 2 review rounds, when its session ends, then Stops holds a new line of class `hotfix` for that group and the build's closing line starts with `Stopped at `.

Task failures:

- **GROUP-AC21**: Given a task in a standard-tier group that still fails after the session's second fix attempt, when the session retries it, then it dispatches the implementer on the deep tier with `retry` in the description.
- **GROUP-AC22**: Given a retried task fails its checks again, when the session ends, then the task stays unticked.
- **GROUP-AC85**: Given a retried task fails its checks again, when the session ends, then Stops holds a new line of class `tier` for that task.
- **GROUP-AC86**: Given a retried task fails its checks again, when the build continues, then no session is resumed or started and the run log's closing line starts with `Stopped at `.

The build's own checks:

- **GROUP-AC23**: Given a group session that left a done group, when the build continues, then it has run the typecheck and the related tests for the group diff's files before any other session starts.
- **GROUP-AC24**: Given a standard-tier group with a failed check after its session, when the build continues, then it resumes that same session on the model of the deep tier with the failure output in the prompt.
- **GROUP-AC87**: Given a group on the lowest tier with a failed check after its session, when the build continues, then it resumes that same session on the model of the standard tier.
- **GROUP-AC25**: Given a deep-tier group with a failed check after its session, when the build continues, then it resumes that same session on the deep tier's model with effort `max`.
- **GROUP-AC26**: Given a failed check after a group's session, and passing checks with the group still done after the resume, when the build continues, then the next group's session starts.
- **GROUP-AC27**: Given a failed check after a group's session and again after the resume, when the build continues, then no further session starts and the run log's closing line starts with `Stopped at `.
- **GROUP-AC88**: Given a failed check after a group's session and again after the resume, when the build has stopped, then Stops holds a new line for that group.
- **GROUP-AC89**: Given a project with an empty `KIT_TYPECHECK` and passing related tests, when a group's checks run, then the next session starts without a resume.
- **GROUP-AC90**: Given a baseline that records type errors and a group that adds none, when a group's checks run, then the next session starts without a resume.
- **GROUP-AC91**: Given a related test that fails and a whole-suite baseline comparison that passes, when a group's checks run, then the next session starts without a resume.
- **GROUP-AC92**: Given a related test that fails and a whole-suite baseline comparison that fails, when a group's checks run, then the build resumes the session.
- **GROUP-AC93**: Given a group whose diff holds no file, when a group's checks run, then the related tests do not run.
- **GROUP-AC94**: Given a check still running after `AUTOPILOT_MAX_SESSION_SECONDS`, when the build's limit is reached, then the check has ended and the run log's closing line starts with `Stopped at `.
- **GROUP-AC95**: Given group A is done and the next group or final session has not started, when a new build runs, then the build's checks for group A run before any session starts.
- **GROUP-AC96**: Given group A is done, the next group or final session has not started and group A's checks fail, when a new build runs, then its first session is group A's with the failure output in the prompt.

Final session:

- **GROUP-AC28**: Given the last group is done, when the build continues, then exactly one final session starts.
- **GROUP-AC29**: Given a final session starts, when its model is read, then it is the model of the verify role.
- **GROUP-AC30**: Given a plan with 2 groups, when the final session runs its review, then the reviewer gets the whole diff against the base on the model of the review role.
- **GROUP-AC97**: Given `KIT_ROUTE_REVIEW` on the standard tier and a deep-tier group on the branch, when the final session runs its review, then the reviewer runs on the model of the deep tier.
- **GROUP-AC31**: Given a plan with one group whose tasks are ticked and whose Rounds holds no group line, when the build continues, then the final session starts.
- **GROUP-AC32**: Given a plan with one group, when its group session ends, then the session dispatched no reviewer.
- **GROUP-AC98**: Given a plan with one group, when its group session ends, then the session dispatched no agent whose description starts with `simplify`.
- **GROUP-AC33**: Given a plan with one group, when the final session runs, then it dispatches the implementer with a description that starts with `simplify`, before its review.
- **GROUP-AC34**: Given a plan with 2 groups and no clones reported by the duplicate checks, when the final session runs, then it dispatches no agent whose description starts with `simplify`.
- **GROUP-AC99**: Given a plan with 2 groups and clones reported by the duplicate checks, when the final session runs, then it dispatches the implementer with a description that starts with `simplify`, before its review.
- **GROUP-AC100**: Given a push gate that prints `auto`, when the final session has verified the feature, then a PR exists and the run log's closing line starts with `Every feature has a PR`.

`/ship-feature` without `--group` or `--final`:

- **GROUP-AC35**: Given an approved plan and a token budget, when `/ship-feature` has finished planning, then a build runs and the session prints the run log's path.
- **GROUP-AC36**: Given a build started by `/ship-feature`, when the terminal session that started it ends, then the group session goes on writing its transcript.
- **GROUP-AC37**: Given a build started by `/ship-feature`, when it starts, then the session prints `Do not edit this checkout until the build ends.`
- **GROUP-AC38**: Given a project with no token budget, when `/ship-feature` starts, then it writes no spec and no plan and prints how to set `KIT_BUDGET_TOKENS`.
- **GROUP-AC101**: Given an uncommitted spec and status row on the feature's branch, when `/ship-feature` starts the build, then both are committed before the build's first session.
- **GROUP-AC102**: Given a failed preflight, when `/ship-feature` starts the build, then the session prints the reason and no lock remains.
- **GROUP-AC103**: Given a feature on branch `12-invite`, when `/ship-feature` starts the build, then its group sessions run on branch `12-invite`.
- **GROUP-AC104**: Given a plan with `Base: develop`, when `/ship-feature` starts the build, then its group sessions run with `KIT_BASE` set to `develop`.
- **GROUP-AC105**: Given `KIT_IMPROVE` empty in the project's config, when a group session of a build started by `/ship-feature` runs, then its `KIT_IMPROVE` is empty.
- **GROUP-AC106**: Given `CLAUDECODE` set in the terminal session, when a build started by `/ship-feature` starts a group session, then that session's environment has no `CLAUDECODE` from the terminal.
- **GROUP-AC107**: Given a running build, when `/ship-feature` runs in that checkout, then it makes no commit.
- **GROUP-AC108**: Given a running build, when `/ship-feature` runs in that checkout, then it does not ask to push.
- **GROUP-AC109**: Given project files older than the plugin, when `/ship-feature` starts, then it prints how to update them and starts no build.

Approval gates:

- **GROUP-AC39**: Given approval level `strict`, when a group session of a build started by `/ship-feature` runs `.claude/bin/gate commit`, then it prints `auto`.
- **GROUP-AC110**: Given `KIT_GATE_COMMIT="ask"` in the project's config, when a group session of a build started by `/ship-feature` runs `.claude/bin/gate commit`, then it prints `auto`.
- **GROUP-AC147**: Given approval level `strict`, when a final session of a build started by `/ship-feature` runs `.claude/bin/gate commit`, then it prints `auto`.
- **GROUP-AC148**: Given `KIT_GATE_COMMIT="ask"` in the project's config, when a final session of a build started by `/ship-feature` runs `.claude/bin/gate commit`, then it prints `auto`.
- **GROUP-AC111**: Given approval level `strict`, when a group session of a build started by `/ship-feature` runs `.claude/bin/gate deps`, then it prints `auto`.
- **GROUP-AC112**: Given approval level `strict`, when a group session of a build started by `/ship-feature` runs `.claude/bin/gate config`, then it prints `auto`.
- **GROUP-AC113**: Given `KIT_GATE_DEPS="ask"` in the project's config, when a group session of a build started by `/ship-feature` runs `.claude/bin/gate deps`, then it prints `ask`.
- **GROUP-AC114**: Given `KIT_GATE_CONFIG="ask"` in the project's config, when a group session of a build started by `/ship-feature` runs `.claude/bin/gate config`, then it prints `ask`.
- **GROUP-AC115**: Given a group session passes the deps gate at `auto`, when the state file is read, then Decisions to review holds a line for that decision.
- **GROUP-AC40**: Given approval level `strict`, when a final session of a build started by `/ship-feature` runs `.claude/bin/gate push`, then it prints `ask`.
- **GROUP-AC43**: Given a build started from a shell, when a group session runs `.claude/bin/gate level`, then it prints `autonomous`.

Asking before a push:

- **GROUP-AC41**: Given a push gate that prints `ask`, when the final session has verified the feature, then no push happens and the run log's closing line starts with `Stopped at `.
- **GROUP-AC116**: Given a push gate that prints `ask`, when the final session has verified the feature, then Stops holds a new line of class `push`.
- **GROUP-AC117**: Given a Stops line of class `push` from the final session, when the build continues, then no answer session starts.
- **GROUP-AC42**: Given a verified feature with no PR and a push gate that prints `ask`, when `/ship-feature` runs, then it asks to push and starts no session.
- **GROUP-AC118**: Given a verified feature with no PR and a push gate that prints `ask`, when the developer approves the push in `/ship-feature`, then a PR exists and no new commit was made.
- **GROUP-AC119**: Given a verified feature with no PR and a push gate that prints `ask`, when `.claude/bin/autopilot` runs from a shell, then no session starts and the run log's closing line names `push`.

Budget:

- **GROUP-AC44**: Given a budget of 100000 and 100001 counted tokens after a group, when the build continues, then no further session starts and the run log's closing line names `budget`.
- **GROUP-AC45**: Given a budget of 100000 and 99999 counted tokens after a group, when the build continues, then the next session starts.
- **GROUP-AC120**: Given a budget of 100000 and exactly 100000 counted tokens after a group, when the build continues, then no further session starts.
- **GROUP-AC121**: Given a group over budget with a failed check, when the build continues, then no resume starts and the run log's closing line names `budget`.
- **GROUP-AC122**: Given a budget of 100000 and 100001 counted tokens, when a new build starts, then no session starts.
- **GROUP-AC149**: Given counted tokens at or over the budget when any session ends, when the build continues, then no session is started or resumed and the run log's closing line names `budget`.
- **GROUP-AC123**: Given a session stopped by the watchdog whose transcript holds 5000 tokens, when the build continues, then the usage command's total includes them.
- **GROUP-AC46**: Given no token budget, when `.claude/bin/autopilot` starts, then it exits with code 2 and starts no session.
- **GROUP-AC124**: Given `KIT_BUDGET_TOKENS=100k`, when `.claude/bin/autopilot` starts, then it exits with code 2 and starts no session.
- **GROUP-AC125**: Given `KIT_BUDGET_TOKENS=0`, when `.claude/bin/autopilot` starts, then it exits with code 2 and starts no session.
- **GROUP-AC126**: Given `KIT_BUDGET_TOKENS=100k`, when `/ship-feature` starts, then it writes no spec and no plan.

Size limit:

- **GROUP-AC150**: Given a plan kept as one PR with an estimate over the default size limit, when `/plan-feature` writes the plan, then it holds a line `Approved size: <n> lines`.
- **GROUP-AC151**: Given a plan gate that prints `auto` and a plan with `Approved size: <n> lines`, when `/plan-feature` ends, then Decisions to review holds a line for that size.
- **GROUP-AC152**: Given `Approved size: 3000 lines` and 3000 changed lines, when the verify gates run, then the size gate passes.
- **GROUP-AC153**: Given `Approved size: 3000 lines` and 3001 changed lines, when the verify gates run, then the size gate fails.
- **GROUP-AC154**: Given no approved size, `KIT_MAX_CHANGED_LINES` of 400 and 801 changed lines, when the verify gates run, then the size gate fails.
- **GROUP-AC155**: Given a branch over its size limit after a group, when the build continues, then no further session starts and the run log's closing line names `size limit`.
- **GROUP-AC156**: Given a session that changes the plan's `Approved size` line, when the build continues, then no further session starts and the run log's closing line names `Approved size`.

## Edge cases

Resuming:

- **GROUP-AC47**: Given group A is done and group B open, when a new build runs, then its first session is group B's.
- **GROUP-AC48**: Given group A with task 1 ticked and tasks 2 and 3 open, when a new build runs, then the first session's prompt names group A.
- **GROUP-AC127**: Given group A's tasks ticked with no group round and group B open, when a new build runs, then its first session is group A's.
- **GROUP-AC128**: Given a plan with a Group column, group A's last round holding open high findings and group B open, when a new build runs, then no session of group B starts.
- **GROUP-AC145**: Given a plan with a Group column and group A's last round holding open high findings, when a new build runs, then group A's session starts with a full review numbered on from the last round.
- **GROUP-AC146**: Given a plan with a Group column and group A's last round holding open high findings, when a new build runs, then group A's session runs at most 2 review rounds before it ends.
- **GROUP-AC129**: Given group A with task 1 ticked in an earlier session, when its review is dispatched, then the group diff holds task 1's changes.
- **GROUP-AC49**: Given every group done and no PR, when a new build runs, then its first session is the final session.
- **GROUP-AC50**: Given a group session stopped once by the watchdog, when the build continues, then a fresh session starts for the same group.
- **GROUP-AC130**: Given a group session stopped twice by the watchdog, when the build continues, then no further session starts and the run log's closing line starts with `Stopped at `.

Uncommitted changes:

- **GROUP-AC131**: Given uncommitted tracked changes outside `.claude/` on the branch of a feature with no PR, whose first group that is not done has an open task, when a new build starts, then the changes are in a stash entry whose name starts with `autopilot `.
- **GROUP-AC132**: Given uncommitted tracked changes outside `.claude/` on the branch of a feature with no PR, whose first group that is not done has an open task, when a new build starts, then the run log holds a line that names the stash entry.
- **GROUP-AC133**: Given uncommitted tracked changes on a branch that is no queued feature's, when `.claude/bin/autopilot` starts, then it exits with code 2 and prints `autopilot: commit or stash your changes first.`
- **GROUP-AC141**: Given uncommitted tracked changes on a feature's branch with no open task in its first group that is not done, when a new build starts, then it exits with code 2 and no stash entry is added.
- **GROUP-AC157**: Given a build that stopped because a finished group left uncommitted changes, with those changes still uncommitted, when a new build starts, then it exits with code 2 and no stash entry is added.
- **GROUP-AC144**: Given uncommitted tracked changes under `.claude/`, when `.claude/bin/autopilot` starts, then it exits with code 2 and no stash entry is added.

Unfinished sessions:

- **GROUP-AC51**: Given a group session that ends with a task of its group unticked and a Stops line of class `env`, when the build continues, then no further session starts and the run log's closing line starts with `Stopped at `.
- **GROUP-AC52**: Given a group session that ticks all its tasks, leaves a tracked file uncommitted and ends on its own, when the build continues, then no session is resumed or started and the run log's closing line starts with `Stopped at `.
- **GROUP-AC53**: Given a plan with a Group column and 2 groups, and a session that ticks all its group's tasks, records no group round and ends on its own, when the build continues, then no session is resumed or started and the run log's closing line starts with `Stopped at `.
- **GROUP-AC54**: Given no state file, or one without tasks under Progress, and no PR after planning, when the build continues, then no session starts and the run log's closing line starts with `Stopped at `.
- **GROUP-AC134**: Given a group session that ends with an unticked task, a question and no new Stops line, when the build continues, then the answer session runs on that question.
- **GROUP-AC135**: Given a group session that ends on another branch than the feature's, when the build continues, then no further session starts and the run log's closing line starts with `Stopped at `.
- **GROUP-AC143**: Given a plan session that set the feature's status, when the build continues, then the status row is committed before the first group session.

Plans without groups:

- **GROUP-AC55**: Given a plan without a Group column and 7 open tasks, when a build runs, then 3 group sessions start with tasks 1 to 3, 4 to 6, and 7.
- **GROUP-AC56**: Given a plan without a Group column, when a build runs, then the run log holds the line `- <feature>: the plan has no Group column; grouped by threes.`
- **GROUP-AC57**: Given a plan without a Group column whose task 5 is on the deep tier, when the session for tasks 4 to 6 starts, then it runs on the model of the deep tier.
- **GROUP-AC136**: Given a plan without a Group column, 7 tasks and tasks 1 and 2 ticked, when a build runs, then the first session holds task 3 only.
- **GROUP-AC137**: Given a plan without a Group column, tasks 1 to 3 ticked and no group line in Rounds, when a build runs, then the first session holds tasks 4 to 6.

One build at a time:

- **GROUP-AC58**: Given a running build, when `.claude/bin/autopilot` starts in the same checkout, then it exits with code 2 and prints `autopilot: a build is already running (pid <pid>). Stop it with .claude/bin/autopilot --stop.`
- **GROUP-AC138**: Given a second build refused by the lock, when a third starts in the same checkout, then it is also refused.
- **GROUP-AC59**: Given a lock left by a build whose process is gone, when `.claude/bin/autopilot` starts, then the build runs.
- **GROUP-AC60**: Given a running build, when `.claude/bin/autopilot --stop` runs, then the build's process and its current session have ended.
- **GROUP-AC139**: Given a running build, when `.claude/bin/autopilot --stop` runs, then the run log's closing line starts with `Stopped at `.
- **GROUP-AC61**: Given a running build, when `.claude/bin/autopilot --stop` has run, then a new build starts in that checkout without a lock message.
- **GROUP-AC62**: Given no running build, when `.claude/bin/autopilot --stop` runs, then it prints `autopilot: no build is running.` and exits with 0.
- **GROUP-AC140**: Given a lock whose pid now belongs to a process that is no build, when `.claude/bin/autopilot --stop` runs, then that process gets no signal.
- **GROUP-AC63**: Given a build that ended, when `.claude/bin/autopilot` starts in that checkout, then the build runs.

Steering (`kit-steering.md`, PR #36):

- **GROUP-AC167**: Given a running build, when `.claude/bin/autopilot --steer "keep the CSV columns as in the spec"` runs, then `.work/autopilot/steer/` holds a message with that text named after the build's run, and it exits 0 with `autopilot: message queued; the session reads it after its next tool call.`
- **GROUP-AC168**: Given a running build, when `.claude/bin/autopilot --steer` runs with no text or only spaces, then it exits 2 and queues nothing.
- **GROUP-AC169**: Given no running build, when `.claude/bin/autopilot --steer <text>` runs, then it exits 1 with `autopilot: no build is running.` and queues nothing.
- **GROUP-AC170**: Given a build, when it starts a plan, group, final or stack session, then the session runs with `KIT_AUTOPILOT_RUN` set to the build's run, so the steer hook hands it that run's messages as STEER-AC14 to STEER-AC18 say; the answer session runs without it.
- **GROUP-AC171**: Given a running build, when `.claude/bin/autopilot --stop` has run, then Decisions to review in the feature's state file has `- stopped-by-user | <phase> session | <DD.MM.YYYY HH:MM>`.
- **GROUP-AC172**: Given a session that wrote no result line yet, when `.claude/bin/autopilot --stop` has run, then the run log's stopped row names the session ID from the session's first line.
- **GROUP-AC178**: Given a running build, when `.claude/bin/autopilot --stop` has run, then it printed `Resume it with: claude --resume <session>` with the last session of the run log's stopped row, followed by when to run the build again.
- **GROUP-AC173**: Given a feature branch whose state file has 2 `steered-by-user` and 1 `stopped-by-user` lines under Decisions to review, when the run records are written and reported, then that run counts 3 interventions.
- **GROUP-AC174**: Given a running build, when the status command runs with `--json`, then `autopilot.running` and `autopilot.active` are `true`, and `autopilot.stop_requested` is `true` once `--stop` has asked it to end; with no lock, a dead build or a reused pid, `running` is `false`.
- **GROUP-AC175**: Given the newest run has one delivered and one undelivered message, when the status command runs with `--json`, then `autopilot.messages` lists both, oldest first, as `{ text, delivered }`.
- **GROUP-AC176**: Given the newest run has a plan session, two group sessions, a watchdog restart of the plan and an answer session, when the status command runs with `--json`, then `autopilot.sessions` lists the five transcripts oldest first as `{ file, feature, phase, kind }` with kinds `session`, `session`, `session`, `restart` and `answer`, `file` relative to the project.
- **GROUP-AC177**: Given the newest run log ends with `Stopped at <feature>` and the stopped row's Sessions cell names `s1 s3`, when the status command runs with `--json`, then `autopilot.resume` is `s3`; for a run without a stop it is `null`.

Sessions and records:

- **GROUP-AC64**: Given a feature with 2 groups, a watchdog restart and a resume, when the build has ended, then every session of the feature has its own transcript file.
- **GROUP-AC65**: Given a running group session of feature `invite-users`, when the status command runs with `--json`, then `autopilot.current` is feature `invite-users` with phase `build`.
- **GROUP-AC66**: Given 3 ticked tasks under Progress and no `task <n>` dispatches, when the usage command runs with `tsv`, then its tasks field is 3.
- **GROUP-AC67**: Given a queue of features `a` and `b`, when `a` has a PR, then the first session of `b` starts on a branch stacked on `a`'s.

## Out of scope
- Changing the current plugin `agentic-workflow-kit`, or replacing it with this version. That is a separate step after the test runs.
- Classifying work at the start as a small feature or a sprint. Until that exists, every feature uses this flow.
- Showing the current group in the cockpit or in the status command's output.
- Running groups in parallel, or a build in its own worktree.
- Letting a project use both plugins at once.

## Open questions

## Decisions
- 03.11.2026: The session's main thread implements a group's tasks, because subagents share no context and shared context is the point of a group.
- 03.11.2026: The model is fixed for the whole group in the plan, as its highest task tier, because a running session cannot change its own model and a headless session can start on any model.
- 03.11.2026: A group holds at most 3 consecutive tasks and groups run one after another, because a fresh session already starts large (111k tokens of context at the smallest in the `ui-einui` run) and the working tree and hooks are shared.
- 03.11.2026: Group reviews run on the group's tier, at least standard, and the final review on the review role, to limit cost. A reviewer is never below the highest tier that wrote the code it reads, including a retry.
- 03.11.2026: A group review judges only its own group's criteria, because the reviewer otherwise reports every later group's criteria as unmet. The final review judges them all.
- 03.11.2026: A terminal `/ship-feature` runs every group headless, so there is one build flow. Approving the plan covers commits and other build decisions; a push still follows the project's approval level.
- 03.11.2026: Commits are always `auto` in a build's group and final sessions, because a headless session cannot ask per commit. An explicit `ask` for deps or config in the project's config stays, because a team set it on purpose; the session stops there.
- 03.11.2026: A token budget is always required, also in a terminal, because a started build keeps running on its own after the terminal closes. The budget hook only fires on subagent dispatches, so the build also checks it between groups, with the hook's own limit: reaching the budget stops. An over-budget build never resumes a session.
- 03.11.2026: The build's own checks run outside the session, and a failed check resumes that session once on a stronger model or effort, because the session that wrote the code should not be the only judge of it and it still holds the context to fix it.
- 03.11.2026: Failing related tests are confirmed against the baseline where one exists, so a project with legacy failures can finish a build. The whole suite only runs when a related test has failed.
- 03.11.2026: A rerun continues at the first group that is not done, not at the first open task, and re-checks the last done group if nothing has built on it, so a stopped group cannot be skipped.
- 03.11.2026: A task is ticked only after its commit, because `.work` is not committed and a tick without a commit would hide unfinished work after a stash.
- 03.11.2026: The answer session no longer answers Stops of class `tier`, because a failed retry is not a question another model can settle. Open high findings after two rounds use class `hotfix`.
- 03.11.2026: The verify size gate can follow a limit the plan approves, because a 13-point feature cannot finish under the default (`ui-einui` changed 8086 lines against a limit of 800). The build stops as soon as a group passes the limit, and stops if a session changes it, because a session may never relax a threshold. Splitting sprints into several PRs is left to the later classification work.
- 03.11.2026: A new build stashes uncommitted tracked changes left on a feature's own branch and redoes the task, so reruns stay hands-off and nothing is deleted. It refuses as before on any other branch, when no open task would redo the work, and for changes under `.claude/`, so it never stashes unrelated work, a finished fix or the kit's own update.
- 03.11.2026: A group that ticks its tasks but leaves changes uncommitted, or records no group round, stops the build rather than going to the answer session, because its result is not a question.
- 03.11.2026: Plans without a Group column are grouped by threes and do not need group rounds, so a feature in progress when a project updates never blocks or repeats finished work.
- 03.11.2026: This ships as a second plugin next to the current one, not behind a flag or on a branch. Fixes land twice until the release; the release needs two real runs (one small feature and one 13-point sprint), compared with the current version.
- 04.11.2026: Kit 0.3.1 (plan-lint, `/fix-bug`, PR #40) lands in this plugin too, and `plan-lint` checks the group rules the plan must follow (GROUP-AC158 to GROUP-AC166), so a plan breaks them at planning, not at the build's start. GROUP-AC1 compares with `main`, because `main` now holds 0.3.1 of the current plugin. Autopilot keeps its own narrower check, so plans written before this never block.
- 04.11.2026: Steering from PR #36 (stable kit 0.4.0) lands here as `--steer`, next to this plugin's `--ship` and `--stop`, which already start a detached build and end it by signal, and it is part of 0.4.1. The steer hook and the interventions in the run records are the stable kit's; the status fields have the same shape, so a pane reads either plugin. Group and stack sessions are numbered, so their transcripts never have the kind `resumed`. When this plugin replaces the current one, the current one's `autopilot start`, `stop` and `steer` become `--ship`, `--stop` and `--steer`.
- 04.11.2026: The e2e map, stacked group pull requests, the stack stage and the risk gates (`e2e-map.md`, `stacked-groups.md`, `stack-stage.md`, `risk-gates.md`) ship on top of this feature as 0.4.1, together with the fixes of PR #39; RISK-AC50 names the version.
