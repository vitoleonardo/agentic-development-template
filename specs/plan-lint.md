# Plan lint

ID prefix: PLANLINT

## Goal
A plan in `.work/<branch>.md` is approved only after a script has checked it. `/plan-feature` already states the rules in prose: every criterion appears in at least one task, every raised tier has its reason line, every new file sits in a home of the Map. Today the model is trusted to follow them. `plan-lint` makes them a hard gate of the same shape as `spec-lint`: it prints one finding per problem and exits with 1, and `/plan-feature` never asks for approval while it fails.

## User flow
1. `/plan-feature` writes the plan and runs `.claude/bin/plan-lint .work/<branch>.md`.
2. The script prints one finding per problem, as `<plan>:<line>: <message>`, and exits with 1.
3. Claude fixes every finding and runs the script again until it prints `plan-lint: <plan> passes.`.
4. Only then does `/plan-feature` ask for approval of the plan.
5. `/fix-bug` runs the same check on a fix plan, whose criteria live in the plan itself.

## Terms
- **Plan**: the file given on the command line, else `.work/<branch>.md` for the current branch.
- **Title**: the plan's first line, `# Plan: <name> (spec: specs/<feature>.md)` for a feature or `# Plan: <name> (fix)` for a fix.
- **Named spec**: the file the title names.
- **Plan criteria**: the `- **<ID>**: …` lines under `## Criteria` in the plan.
- **Expected criteria**: the plan criteria when there are any; else the IDs of the named spec's criteria that are not marked removed.
- **Task row**: a row of the table under `## Tasks`. Columns are found by the header names `#`, `Task`, `Files`, `Criteria`, `Test cases`, `Depends on` and `Tier`; other columns are ignored.
- **Default tier**: what `.claude/bin/route tier implement` prints, or `standard` when it prints nothing. An empty Tier cell, or one that is `-` or `–`, means the default tier.
- **Tier reason line**: a line `Task <n> <tier>: <reason>`, with or without a leading `- `, between the Tasks table and the next `## ` heading.
- **No dependency**: a Depends on cell that is empty, `-`, `–` or `none`.
- **Named test cases**: a Test cases cell that is not empty, `-` or `–`, and whose text is not only `tests`, `add tests`, `write tests`, `unit tests`, `tbd` or `todo`.
- **Placeholder**: a cell or value whose text starts with `<`.
- **Design line**: a `- <Name>: <value>` line under `## Design`.
- **Path** of a Files cell: each backticked string; when the cell has no backticks, each comma- or space-separated token that contains `/` or a dot. A token with `*` or `<` is a placeholder, not a path.
- **New path**: a path that does not exist on disk.
- **Finding**: one line `<plan>:<line>: <message>`.

## Acceptance criteria

Running it:

- **PLANLINT-AC1**: Given a plan that follows every rule below, when `plan-lint` runs on it, then it prints `plan-lint: <plan> passes.` and exits with 0.
- **PLANLINT-AC2**: Given a plan that breaks two rules on different lines, when `plan-lint` runs on it, then it prints one finding per broken rule and exits with 1.
- **PLANLINT-AC3**: Given the current branch is `12-invite` and `.work/12-invite.md` exists, when `plan-lint` runs without an argument, then its summary line or its findings name `.work/12-invite.md`.
- **PLANLINT-AC4**: Given a plan with CRLF line endings, when `plan-lint` runs on it, then it prints the same findings as for the same plan with LF line endings.

Title and spec:

- **PLANLINT-AC5**: Given a title that names `specs/invite.md` and no such file, when `plan-lint` runs, then a finding on line 1 names `specs/invite.md` as missing.
- **PLANLINT-AC6**: Given a first line in neither title form, when `plan-lint` runs, then a finding on line 1 shows both title forms.

Criteria coverage:

- **PLANLINT-AC7**: Given a spec with `INVITE-AC1` to `INVITE-AC3` and task rows that name only `INVITE-AC1` and `INVITE-AC3`, when `plan-lint` runs, then a finding names `INVITE-AC2` as a criterion without a task.
- **PLANLINT-AC8**: Given the spec marks `INVITE-AC2` as removed and no task row names it, when `plan-lint` runs, then there is no finding for `INVITE-AC2`.
- **PLANLINT-AC9**: Given a task row that names `INVITE-AC9` and a spec without it, when `plan-lint` runs, then a finding on that row's line says the spec has no `INVITE-AC9`.
- **PLANLINT-AC10**: Given a plan whose `## Criteria` holds only `INVITE-AC3` and whose task rows name `INVITE-AC3`, when `plan-lint` runs, then there is no finding for `INVITE-AC1` or `INVITE-AC2`.
- **PLANLINT-AC11**: Given a plan whose `## Criteria` holds `INVITE-AC9` and a named spec without it, when `plan-lint` runs, then a finding on that criterion's line says the spec has no `INVITE-AC9`.

Criteria of a fix:

- **PLANLINT-AC12**: Given a `(fix)` plan with a criterion that is not written as state, action and result in that order, when `plan-lint` runs, then a finding on its line asks for the same three-part form that `spec-lint` requires.
- **PLANLINT-AC13**: Given a `(fix)` plan with a criterion that holds a word from `spec-lint`'s list of untestable words, when `plan-lint` runs, then a finding on its line names that word in quotes.
- **PLANLINT-AC14**: Given a `(fix)` plan whose criteria use the prefix of the `ID prefix:` line of `specs/invite.md`, when `plan-lint` runs, then a finding names `specs/invite.md` as the spec that owns the prefix.
- **PLANLINT-AC15**: Given a `(fix)` plan with the same criterion ID on two lines, when `plan-lint` runs, then a finding on the second line says the ID is already used.

Tasks table:

- **PLANLINT-AC16**: Given a Tasks table whose header lacks the `Test cases` column, when `plan-lint` runs, then a finding on the header line names `Test cases`.
- **PLANLINT-AC17**: Given task 2 with an empty Files cell, when `plan-lint` runs, then a finding names task 2 and `Files`.
- **PLANLINT-AC18**: Given a task row whose Test cases cell is `add tests`, when `plan-lint` runs, then a finding on its line asks to name the cases.
- **PLANLINT-AC19**: Given task 2 depends on task 3, when `plan-lint` runs, then a finding on its line says a task depends only on earlier tasks.
- **PLANLINT-AC20**: Given three tasks and task 3 depends on task 7, when `plan-lint` runs, then a finding on its line says task 7 does not exist.
- **PLANLINT-AC27**: Given a Files cell that is `<paths>`, when `plan-lint` runs, then a finding on its line says the cell still holds a placeholder.

Tiers:

- **PLANLINT-AC21**: Given a Tier cell `opus`, when `plan-lint` runs, then a finding on its line lists the three tier names of `.claude/bin/route`.
- **PLANLINT-AC22**: Given the default tier is `standard`, task 3 has Tier `deep` and no tier reason line names task 3, when `plan-lint` runs, then a finding names the missing line `Task 3 deep:`.
- **PLANLINT-AC23**: Given the default tier is `standard`, task 3 has Tier `deep` and the line `Task 3 deep: changes the permission check` follows the table, when `plan-lint` runs, then there is no finding about task 3's tier.
- **PLANLINT-AC24**: Given `KIT_ROUTE_IMPLEMENT="deep"` in `.claude/kit.conf`, task 3 has Tier `deep` and no tier reason line, when `plan-lint` runs, then there is no finding about task 3's tier.

New files:

- **PLANLINT-AC25**: Given a Files cell with a new path that has no home in the Map, when `plan-lint` runs, then a finding on that row's line quotes the line `.claude/bin/structure` prints for that path.
- **PLANLINT-AC26**: Given a Files cell with a path that exists on disk and has no home in the Map, when `plan-lint` runs, then there is no finding for that path.

Design:

- **PLANLINT-AC28**: Given a `## Design` section without an `- Approved dependencies:` line, when `plan-lint` runs, then a finding names `Approved dependencies`.
- **PLANLINT-AC29**: Given the Design line `- Reused: <what you searched for, with path:line>`, when `plan-lint` runs, then a finding on its line says `Reused` still holds its placeholder.

Progress:

- **PLANLINT-AC30**: Given tasks 1 to 3 and a Progress section that lists tasks 1 and 2, when `plan-lint` runs, then a finding names task 3 as missing from Progress.
- **PLANLINT-AC31**: Given a Progress section that lists task 1 twice, when `plan-lint` runs, then a finding on the second line says task 1 is listed twice.

Wiring:

- **PLANLINT-AC32**: Given `/plan-feature` has written the plan, when it checks the plan, then it runs `.claude/bin/plan-lint` on it and asks for approval only once the script passes.
- **PLANLINT-AC33**: Given the kit's `settings.json`, when a skill runs `.claude/bin/plan-lint`, then the allow list permits it without a prompt, through `Bash(.claude/bin/plan-lint *)`.

## Edge cases
- **PLANLINT-AC34**: Given no argument and no `.work/<branch>.md`, when `plan-lint` runs, then it prints `plan-lint: no plan at .work/<branch>.md` and exits with 2.
- **PLANLINT-AC35**: Given a `(fix)` title and no `## Criteria` section, when `plan-lint` runs, then a finding says a fix plan needs its criteria under `## Criteria`.
- **PLANLINT-AC36**: Given a `## Tasks` section with a header and no task row, when `plan-lint` runs, then a finding says the plan has no task.
- **PLANLINT-AC37**: Given a Tier cell `–` and no tier reason line, when `plan-lint` runs, then there is no finding about that task's tier.
- **PLANLINT-AC38**: Given a new path in a Files cell and no Map in `.claude/rules/structure.md`, when `plan-lint` runs, then it prints `plan-lint: structure not configured; new paths not checked` on stderr and there is no finding for that path.
- **PLANLINT-AC39**: Given the line `Base: <the branch this plan was approved on>`, when `plan-lint` runs, then there is no finding for that line.
- **PLANLINT-AC40**: Given a `## Design` section without a `- Contract:` line, when `plan-lint` runs, then there is no finding about `Contract`.
- **PLANLINT-AC41**: Given a Progress section that holds the template line `- [ ] 1 <task>`, when `plan-lint` runs, then a finding on its line says it is still the template line.
- **PLANLINT-AC42**: Given a Files cell `` `src/features/invite/send.ts` (new), `src/lib/mail.ts` `` whose paths both have a home in the Map, when `plan-lint` runs, then there is no finding for that row.

## Out of scope
- Checking the `Base:` line; `/ship-feature` fills it after approval.
- Judging whether a test case is the right one or a task is small enough; the human does that at the plan gate.
- Checking existing files against the Map; only new paths go to `.claude/bin/structure`.
- Plans approved by older kit versions; the check runs only before approval.
- A fix of the plan; the script only reports.

## Open questions

## Decisions
- 04.11.2026: The plan's own `## Criteria` replace the spec's set for coverage, because a fix reuses one criterion of a long spec and the others have their tasks elsewhere.
- 04.11.2026: An empty or `–` Tier cell means the default tier, because `/plan-feature` writes a reason line only for raised tiers.
- 04.11.2026: Every placeholder under `## Design` is a finding, because a plan that keeps the template's angle brackets was not finished.
- 04.11.2026: `Base:` is never checked, because `/ship-feature` fills it after approval.
- 04.11.2026: The default tier comes from `.claude/bin/route tier implement`, because the plan's `–` must mean what the dispatch will do in that project.
