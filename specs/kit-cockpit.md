# Kit cockpit

ID prefix: COCKPIT

## Goal
A developer who builds features with the Agentic Workflow Kit sees at a glance where the current branch's feature stands. The cockpit shows the feature's stage, tasks, criteria, failing checks and budget, and any unattended autopilot run. The developer does not need to open the state file or the feature list. The cockpit only shows; it never changes the workflow's files.

## User flow
1. The developer installs the kit and the cockpit plugin, starts a session on a feature branch, and sees a status line such as `invite-users · build · tasks 3/7 · 1 red · budget 42%`.
2. While Claude works, the status line follows each finished edit, subagent and turn.
3. The developer runs `/cockpit`. A pane beside the chat shows the feature in seven sections: Criteria, Tasks, Stops, Rounds, Decisions to review, Evidence, Autopilot.
4. While an autopilot run is going on in another terminal and the pane is open, the Autopilot section follows that run on its own: the feature and phase it is working on, and each finished feature's result.
5. Outside a kit project, or with a kit that is too old, the status line stays empty and `/cockpit` says how to update the kit.
6. When reading the state fails, the status line shows `cockpit: error` and the pane shows the reason.

## Terms
- **Feature**: the spec's file name without `.md` (`invite-users`).
- **Feature row**: the row of the feature list whose Branch column is the current branch. A row with an empty Branch, or one that is `-`, `–` or starts with `_`, matches when its feature equals the branch name. Rows whose Feature column starts with `_` are examples and never match.
- **Tasks**: the `- [ ]` and `- [x]` lines under Progress in the state file (`[X]` counts as ticked). Lines that still hold a template placeholder (`<`) do not count.
- **Section lines** (Stops, Rounds, Decisions to review): the `- ` lines of that section, without lines that start with `- <`.
- **Red and green**: a Verify log cell is filled when it is not empty, `-`, `–` or `no`. A criterion is `green` when any of its rows has a filled Green cell, `red` when it is not green and any row has a filled Red seen cell, and `open` otherwise. A row that names several criteria counts for each of them. Criteria marked removed in the spec are not listed.
- **Red checks**: the distinct checks whose last result in the current turn of the session is a fail, counted as the kit's summary hook counts them.
- **Budget used**: the branch's counted tokens as the kit's usage command totals them, divided by the token budget, rounded down to a whole percent. A budget that is unset, 0 or not a number counts as no budget.
- **Closing line** of an autopilot run log: a line that starts with `Every feature has a PR` or with `Stopped at `.
- **Idle limit**: the autopilot's idle limit as set in the kit's config, else 1200 s.
- **Active autopilot run**: the newest run log has no closing line, and either the newest session transcript of the autopilot changed within the idle limit, or the run log's last line says the run waits for the usage limit to reset and that reset time plus the idle limit has not passed.
- **Current autopilot feature and phase**: taken from the newest session transcript's name, `<run>-<feature>-<phase>` with an optional `-restart-<n>`, `-wait-<n>` or `-<n>` ending, or `<run>-<feature>-answer-<n>`. The phase is `plan`, `build` or `answer`; the feature is everything between the run and the phase, hyphens included.
- **Stage**: the first rule of this list that matches:
  1. `done`: the feature row has status `done`.
  2. `pr`: a PR description exists for the branch.
  3. `verify`: a verify round is recorded, or the feature row has status `in-review`.
  4. `review`: a review round is recorded, or there is at least one task and all tasks are ticked.
  5. `build`: at least one task is ticked, or the feature row has status `building`.
  6. `plan`: a state file exists, or the feature row has status `planned`.
  7. `spec`: a feature row exists.

## Acceptance criteria

Status command, short form (the kit's status command with `--line`, run on the feature's branch):

- **COCKPIT-AC1**: Given a feature row with status `draft` and no state file, when the status command runs with `--line`, then it prints `<feature> · spec`.
- **COCKPIT-AC2**: Given a feature row with status `planned`, a state file with 0 of 7 tasks ticked and no rounds, when the status command runs with `--line`, then it prints `<feature> · plan · tasks 0/7`.
- **COCKPIT-AC3**: Given a feature row with status `planned`, 3 of 7 tasks ticked and no rounds, when the status command runs with `--line`, then it prints `<feature> · build · tasks 3/7`.
- **COCKPIT-AC4**: Given a feature row with status `building`, 0 of 7 tasks ticked and no rounds, when the status command runs with `--line`, then it prints `<feature> · build · tasks 0/7`.
- **COCKPIT-AC5**: Given a feature row with status `building`, 7 of 7 tasks ticked, no rounds and no PR description, when the status command runs with `--line`, then it prints `<feature> · review · tasks 7/7`.
- **COCKPIT-AC6**: Given a feature row with status `building`, 6 of 7 tasks ticked, one review round and no PR description, when the status command runs with `--line`, then it prints `<feature> · review · tasks 6/7`.
- **COCKPIT-AC7**: Given a feature row with status `in-review`, 7 of 7 tasks ticked, no verify round and no PR description, when the status command runs with `--line`, then it prints `<feature> · verify · tasks 7/7`.
- **COCKPIT-AC8**: Given a feature row with status `in-review`, a recorded verify round and a PR description for the branch, when the status command runs with `--line`, then the stage part reads `pr`.
- **COCKPIT-AC9**: Given a feature row with status `done` and a PR description for the branch, when the status command runs with `--line`, then the stage part reads `done`.
- **COCKPIT-AC10**: Given a token budget of 200000 and 84300 counted tokens on the branch, when the status command runs with `--line`, then the line ends with ` · budget 42%`.
- **COCKPIT-AC11**: Given a token budget of 200000 and 230000 counted tokens on the branch, when the status command runs with `--line`, then the line ends with ` · budget 115%`.
- **COCKPIT-AC12**: Given a session whose current turn has 2 red checks, when the status command runs with `--line --session <id>`, then ` · 2 red` follows the tasks part, or the stage part when there is no tasks part.

Status command, full form (`--json`):

- **COCKPIT-AC13**: Given a spec with criteria AC1 to AC3 and a Verify log where AC1 has a filled Green cell, AC2 only a filled Red seen cell and AC3 no row, when the status command runs with `--json`, then `criteria` lists AC1 `green`, AC2 `red` and AC3 `open`, in spec order.
- **COCKPIT-AC14**: Given a state file with 2 Stops lines, 3 Rounds lines and 4 Decisions to review lines plus the template placeholder line in each section, when the status command runs with `--json`, then `stops`, `rounds` and `decisions` hold exactly those 2, 3 and 4 lines as written.
- **COCKPIT-AC15**: Given an evidence pack made on the current commit, when the status command runs with `--json`, then `evidence.current` is `true` and `evidence.gates` lists each gate of the pack with its result.
- **COCKPIT-AC16**: Given an evidence pack made on an earlier commit, when the status command runs with `--json`, then `evidence.current` is `false` and `evidence.head` is that commit's full hash.
- **COCKPIT-AC17**: Given an active autopilot run whose newest session transcript belongs to feature `b` in phase `build`, when the status command runs with `--json`, then `autopilot.current` is feature `b` with phase `build`.
- **COCKPIT-AC18**: Given an active autopilot run whose run log holds a finished row for feature `a`, when the status command runs with `--json`, then `autopilot.active` is `true` and `autopilot.features` holds feature `a` with that row's result.
- **COCKPIT-AC19**: Given the newest autopilot run log ends with a closing line, when the status command runs with `--json`, then `autopilot.active` is `false` and `autopilot.features` lists that run's rows.

Workflow:

- **COCKPIT-AC20**: Given a feature with status `planned`, when `/ship-feature` commits its first build task, then that commit holds the feature list with status `building` for the feature.

Cockpit plugin:

- **COCKPIT-AC21**: Given a kit project on a feature branch, when a session starts, then the status line shows the status command's `--line` output.
- **COCKPIT-AC22**: Given the status line shows `tasks 3/7`, when an edit, write or subagent call finishes after which the state file has 4 ticked tasks, then the status line shows `tasks 4/7`.
- **COCKPIT-AC23**: Given the state changed during a turn, when the turn ends, then the status line shows the status command's output from after that change.
- **COCKPIT-AC24**: Given a kit project, when the developer runs `/cockpit`, then a pane titled `Cockpit` opens with the sections Criteria, Tasks, Stops, Rounds, Decisions to review, Evidence and Autopilot, in that order.
- **COCKPIT-AC25**: Given criterion AC2 is `red` with test `AC2: rejects a duplicate email`, when the pane is open, then the Criteria section shows AC2 as `red` next to `AC2: rejects a duplicate email`.
- **COCKPIT-AC26**: Given the state file has 3 of 7 tasks ticked, when the pane is open, then the Tasks section shows all 7 tasks, 3 with a ticked mark and 4 with an open mark.
- **COCKPIT-AC27**: Given a state file without Stops lines, when the pane is open, then the Stops section shows `none`.
- **COCKPIT-AC28**: Given the pane is open on an active autopilot run working on feature `a`, when the autopilot moves to feature `b` and 10 seconds pass without any action, then the Autopilot section shows feature `b` as current.

## Edge cases
- **COCKPIT-AC29**: Given the current branch has no feature row and no state file, when the status command runs with `--line`, then it prints nothing and exits with 0.
- **COCKPIT-AC30**: Given a detached HEAD, when the status command runs with `--line`, then it prints nothing and exits with 0.
- **COCKPIT-AC31**: Given a state file without a feature row whose title names spec `specs/fix-login.md` and that has no ticked task and no rounds, when the status command runs with `--line`, then the line starts with `fix-login · plan`.
- **COCKPIT-AC32**: Given two feature rows that match the current branch, when the status command runs with `--json`, then it reports the first row's feature and `warnings` contains `2 feature rows match branch <branch>`.
- **COCKPIT-AC33**: Given only the feature list's example row, when the status command runs with `--line` on the branch that example names, then it prints nothing.
- **COCKPIT-AC34**: Given a state file without a Progress section, when the status command runs with `--line`, then the line contains no `tasks` part.
- **COCKPIT-AC35**: Given a Progress section that holds only the template line `- [ ] 1 <task>`, when the status command runs with `--line`, then the line contains no `tasks` part.
- **COCKPIT-AC36**: Given a token budget of 0, when the status command runs with `--line`, then the line contains no `budget` part.
- **COCKPIT-AC37**: Given a session whose current turn has no red checks, when the status command runs with `--line --session <id>`, then the line contains no `red` part.
- **COCKPIT-AC38**: Given the state file names a spec that does not exist, when the status command runs with `--json`, then it exits with 0, `criteria` is empty and `warnings` contains `spec not found: <path>`.
- **COCKPIT-AC39**: Given no evidence pack for the branch, when the status command runs with `--json`, then `evidence` is `null`.
- **COCKPIT-AC40**: Given the newest autopilot run log has no closing line and its newest session transcript changed 1200 or more seconds ago, when the status command runs with `--json`, then `autopilot.active` is `false`.
- **COCKPIT-AC41**: Given the newest autopilot run log has no closing line, its last line says the run waits for the usage limit to reset, with a reset time 1 hour from now, and its newest transcript changed 3 hours ago, when the status command runs with `--json`, then `autopilot.active` is `true`.
- **COCKPIT-AC55**: Given the newest autopilot run log has no closing line and its last line says the run waits for a usage limit reset that passed more than the idle limit ago, when the status command runs with `--json`, then `autopilot.active` is `false`.
- **COCKPIT-AC42**: Given no autopilot run log exists, when the status command runs with `--json`, then `autopilot` is `null`.
- **COCKPIT-AC43**: Given a kit project with a state file, a session record and an evidence pack, when the status command runs 10 times, then every file in the project outside `.git/` has the same content and modification time as before.
- **COCKPIT-AC44**: Given a project without the kit's status command, when a session starts, then the status line stays empty.
- **COCKPIT-AC45**: Given a project without the kit's status command, when the developer runs `/cockpit`, then the pane shows `kit-cockpit needs the Agentic Workflow Kit 0.3.0 or newer. Run ./install.sh <project> --update from the kit's repository.`
- **COCKPIT-AC46**: Given the status command exits with a non-zero code, when the cockpit refreshes, then the status line shows `cockpit: error`.
- **COCKPIT-AC47**: Given the status command exits with code 3 and an error output whose first line is `cannot read specs/README.md`, when the pane is open and the cockpit refreshes, then the pane shows `cannot read specs/README.md`.
- **COCKPIT-AC48**: Given the status command exits with code 3 and an empty error output, when the pane is open and the cockpit refreshes, then the pane shows `status exited with code 3`.
- **COCKPIT-AC49**: Given the status command runs longer than 5 seconds, when the cockpit refreshes, then the status line shows `cockpit: error`.
- **COCKPIT-AC50**: Given the status command runs longer than 5 seconds and the pane is open, when the cockpit refreshes, then the pane shows `status timed out after 5 s`.
- **COCKPIT-AC51**: Given the pane is closed, when 5 seconds pass without any action, then the status command does not run.
- **COCKPIT-AC52**: Given the pane is open and no autopilot run is active, when 5 seconds pass without any action, then the status command does not run.
- **COCKPIT-AC53**: Given the pane is already open, when the developer runs `/cockpit` again, then exactly one Cockpit pane is open.
- **COCKPIT-AC54**: Given a kit project, when the cockpit refreshes 10 times and opens its pane, then the only command it has run is the kit's status command and it has written no file.

## Out of scope
- Writing any workflow file: no ticking tasks, setting statuses or approving gates from the cockpit.
- Starting, stopping or answering an autopilot run.
- Features of other branches than the session's current one, except the features of an autopilot run in its Autopilot section, and history or trends across features.
- A package's own feature list or budget in a monorepo: the cockpit reads the root's.
- A web dashboard, or drawing specific to surfaces other than the terminal and the desktop app.

## Open questions

## Decisions
- 31.10.2026: The kit owns the parsing in one status command, and the plugin only draws, because the formats of the state file and the feature list belong to the kit and change with its skills.
- 31.10.2026: The cockpit ships as a separate plugin, because it needs a newer Claude Code than the kit and must not put the kit's enforcing hooks at risk.
- 31.10.2026: The stage is the first matching rule of one ordered list, and `/ship-feature` also writes `building`. Before this, no skill wrote `building`, so `planned` covered the whole build. With the kit as a plugin, the skill and the status command can be on different versions; the file rules still give `build`, so this is accepted.
- 31.10.2026: `in-review` counts as `verify`, not `pr`, because `/verify-feature` sets it before its gates run.
- 31.10.2026: An autopilot run counts as active within the autopilot's own idle limit after its last transcript change, or while it waits for a usage limit, so that a killed run does not show as active forever.
- 31.10.2026: Evidence counts as current when it was made on the current commit, as CI judges it; uncommitted changes are not checked.
- 31.10.2026: Red checks drop to 0 once the kit's Stop hook clears the turn's record; the status line shows what the record holds at refresh time.
- 31.10.2026: The pane polls every 5 seconds only while it is open and a run is active; everything else refreshes on events, so an idle session runs no command.
- 31.10.2026: The kit's version goes to 0.3.0 with the status command, so the cockpit can name the version it needs.
