# Stacked groups

ID prefix: STACK

## Goal
A feature built in groups reaches review as small pull requests, one per group, stacked on each other with GitHub's stacked pull requests. A reviewer reads one group's change at a time, the size limit applies to what one reviewer reads, and an autopilot run stacks the next feature on top. The build itself stays as it is: one branch per feature, one state file, one usage record. The layers are cut from that branch's history when the feature is submitted.

## User flow
1. The developer approves a plan with groups, as today. The build runs one session per group and a final session, as today.
2. The final session reviews and verifies the whole feature, then submits it: one pull request per group, each based on the one below, linked as one stack.
3. A reviewer opens the bottom pull request and reads up the stack. Each pull request names its group's criteria and shows only that group's diff.
4. In an autopilot run, the next feature's first pull request sits on top of the previous feature's last one, in the same stack.
5. Where `gh stack` is missing or the repository has stacked pull requests turned off, the same pull requests are opened as a plain chain, each based on the one below, and the run log says why.

## Terms
- **Layer**: one pull request of a stack and the branch it comes from.
- **Feature branch**: the branch the build works on, as today (`.work/<branch>.md` is its state file).
- **Layered plan**: a plan with a Group column and more than one group.
- **Group end**: for every group but the last, the commit before the first commit that names a task of the next group (`group_from` of the next group).
- **Layer branch**: `<feature branch>-g<group id>` at the group end, for every group of a layered plan but the last. The last group's layer is the feature branch itself, which also holds the final session's commits.
- **Layers of a feature**: its layer branches in plan order, then the feature branch. A plan that is not layered has one layer: the feature branch.
- **Stack base**: the `Base:` line of the first feature's plan in the chain; a feature whose Base is another feature's branch continues that feature's stack.
- **Submit**: `.claude/bin/stack submit`, which the final session runs at gate push.
- **Layer diff**: the changes from the layer below (or the Base, for the first layer) to the layer's head.
- **Layer pack**: the evidence pack of the feature, pushed under the layer's key with an `evidence.json` whose `head` is the layer's head and whose `stack_top` is the feature branch's head.

## Acceptance criteria

Layers:

- **STACK-AC1**: Given a layered plan with group A (tasks 1 to 3) and group B (tasks 4 and 5) on branch `12-invite`, when submit runs, then branch `12-invite-gA` points at the parent of the first commit that names task 4.
- **STACK-AC2**: Given that plan, when submit runs, then no branch `12-invite-gB` is created.
- **STACK-AC3**: Given a plan with one group, when submit runs, then no layer branch is created and exactly one pull request exists, for the feature branch.
- **STACK-AC4**: Given a plan without a Group column and 7 tasks, when submit runs, then no layer branch is created.
- **STACK-AC5**: Given a layered plan where a ticked task of group B has no commit naming it, when `stack layers` runs, then it prints one layer, the feature branch, and a line naming group B and `one layer`.
- **STACK-AC6**: Given a layer branch left by an earlier submit at another commit, when submit runs again, then the layer branch points at the current group end.

Pull requests:

- **STACK-AC7**: Given a layered plan with groups A and B, `Base: main` and `gh stack` available, when submit runs, then `gh stack link` ran with `--base main`, `12-invite-gA` and `12-invite`, in that order.
- **STACK-AC8**: Given that plan, when submit has run, then the pull request of `12-invite-gA` has base `main` and the pull request of `12-invite` has base `12-invite-gA`.
- **STACK-AC9**: Given `gh extension list` without `gh stack`, when submit runs, then each layer's pull request is created with `gh pr create --base <the layer below>` and submit prints a line naming `gh extension install github/gh-stack`.
- **STACK-AC10**: Given `gh stack link` exits with 9, when submit runs, then the pull requests are created as a plain chain and submit prints a line saying stacked pull requests are turned off for the repository.
- **STACK-AC11**: Given the pull request of `12-invite-gA` exists and the one of `12-invite` does not, when submit runs, then exactly one pull request is created, for `12-invite`.
- **STACK-AC12**: Given feature `a` on branch `10-a` with a pull request, and feature `b` with `Base: 10-a` and groups A and B, when `b` is submitted, then `gh stack link` ran with `10-a` before `11-b-gA` and `11-b`.

Descriptions:

- **STACK-AC13**: Given a layered plan, when the final session writes the descriptions, then `.work/<branch>/pr/<group id>.md` exists for every group but the last, and `.work/<branch>-pr.md` exists for the last.
- **STACK-AC14**: Given group A covers `INVITE-AC1` and group B covers `INVITE-AC2`, when submit has run, then the evidence table of `12-invite-gA`'s pull request names `INVITE-AC1` and not `INVITE-AC2`.
- **STACK-AC15**: Given a layered plan with 3 groups, when submit has run, then the title of the second layer's pull request ends with `(2/3)`.
- **STACK-AC16**: Given a layered plan, when submit has run, then the description of every layer but the last says that review and verify ran on the stack top and names the feature branch.

Evidence:

- **STACK-AC17**: Given a verified layered plan with groups A and B, when submit runs, then the `kit-evidence` branch holds `12-invite-gA/<head of 12-invite-gA>/evidence.json` whose `head` is that head.
- **STACK-AC18**: Given that layer pack, when it is read, then its `stack_top` is the head of `12-invite`.
- **STACK-AC19**: Given a layer pack under `12-invite-gA/<head>`, when `evidence ci-check --head <head> --key 12-invite-gA` runs, then it exits with 0.
- **STACK-AC20**: Given submit runs, when the first `gh stack link` or `gh pr create` call starts, then every layer pack is already on `kit-evidence`.

Size:

- **STACK-AC21**: Given `KIT_MAX_CHANGED_LINES` of 400, no approved size and layers of 700 and 700 changed lines, when the verify gates run, then the size gate passes.
- **STACK-AC22**: Given `KIT_MAX_CHANGED_LINES` of 400, no approved size and a layer of 801 changed lines against the layer below, when the verify gates run, then the size gate fails and names that layer.
- **STACK-AC23**: Given `Approved size: 1200 lines` and a layer of 1100 changed lines, when the verify gates run, then the size gate passes.
- **STACK-AC24**: Given a group whose group diff has 801 changed lines with `KIT_MAX_CHANGED_LINES` of 400 and no approved size, when the build continues after that group, then no further session starts and the run log's closing line names `size limit` and the group.

Gates and setup:

- **STACK-AC25**: Given a push gate that prints `ask`, when the final session has verified the feature, then no layer branch is pushed and no pull request is created.
- **STACK-AC26**: Given approval level `strict`, when a session runs `gh stack link`, then the guard asks before it runs.
- **STACK-AC27**: Given approval level `strict`, when a session runs `.claude/bin/stack submit`, then the guard asks before it runs.
- **STACK-AC28**: Given `gh stack` is not installed, when `.claude/bin/autopilot --ready` runs, then it prints a warning that names `gh extension install github/gh-stack` and exits with 0.
- **STACK-AC32**: Given `gh stack` is not installed, when a build starts, then the run log holds a line saying `gh stack is not installed`.

## Edge cases
- **STACK-AC29**: Given a feature branch named `feat/invite`, when submit runs, then the layer branch of group A is `feat/invite-gA`.
- **STACK-AC30**: Given a layered plan whose final session added review fixes for group A's code, when submit runs, then those fix commits are in the feature branch's layer and `12-invite-gA` does not contain them.
- **STACK-AC31**: Given protected paths in `KIT_PROTECTED_PATHS`, when the size gate measures a layer, then the protected paths are left out as for the whole branch.
- **STACK-AC33**: Given layer `13-chain-gA` was pushed at one commit and the plan now puts it at another, when submit runs, then it exits with 1, moves no branch, and prints that fixes go on the top layer.
- **STACK-AC34**: Given no evidence pack for the feature branch, when submit runs, then the pull requests are opened and submit prints that CI's evidence job fails until `/verify-feature` pushes the pack.

## Out of scope
- Running e2e and mutation tests once per stack, and posting screenshots into the pull requests; that is the stack stage (`specs/stack-stage.md`).
- Merging a stack and deciding when a person must approve it; that is `specs/risk-gates.md`.
- Building groups on separate branches, or in parallel.
- Moving a fix down into the layer whose code it fixes.

## Open questions

## Decisions
- 04.11.2026: The build keeps one branch per feature and cuts the layers at submit, because the state file, the usage record, `base_ref`, `group_from` and resuming are all keyed by that branch; a branch per group would reset the budget and lose earlier groups' commits.
- 04.11.2026: Fixes after a group go on the top layer, because a commit on a lower layer rebases every layer above it, which invalidates their packs, checks and approvals and stops a headless run on a conflict.
- 04.11.2026: A plan without a Group column, or with one group, stays one pull request, because its groups had no review of their own.
- 04.11.2026: The size limit applies per layer, because a reviewer reads one layer at a time. This replaces the size part of the group-sessions decision "Splitting sprints into several PRs is left to the later classification work".
- 04.11.2026: `gh stack` is used when it is there and falls back to a plain chain of pull requests, because the extension and the repository setting are new (generally available on 06.10.2026) and the chain gives the same review order.
