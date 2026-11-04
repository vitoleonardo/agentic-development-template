---
name: plan-feature
description: Turn an approved spec into a short implementation plan (tasks, files, tests, risks, which criterion each task covers), approved before any code is written. Use when the user asks to plan a feature.
argument-hint: <feature name or spec path>
---

# Plan a feature

Feature: $ARGUMENTS

Do not edit source files in this step. The only files you write are the state file and the status row.

## 1. Read

- The spec in `specs/`. If its status in `specs/README.md` is not `approved`, stop and say so. For a fix without a spec, title the plan `# Plan: <slug> (fix)` and write one to three criteria under `## Criteria` (`- **<PREFIX>-ACn**: Given …, when …, then …`, a prefix no spec uses); they are approved with the plan. `/fix-bug` does this from a bug report.
- The code the feature touches. For a large codebase, explore the affected areas with parallel `Explore` subagents, passing `model` from `.claude/bin/route explore`, so you read their conclusions, not file dumps. Collect `path:line` anchors, existing pieces to reuse, and the pattern to mirror.

## 2. Write the plan

Write it to `.work/<branch>.md`, using the current branch or, if you are on `main`, the branch name you propose (`<issue>-<slug>`). Do not create the branch yet.

```markdown
# Plan: <feature> (spec: specs/<feature>.md)
Base: <the branch this one builds on; /ship-feature fills it in>

## Design
- Parts: <which UI, server and data pieces change, and how they connect>
- Data: <new or changed tables/fields/types, precise enough that nobody has to guess>
- Contract: <only when a frontend and a backend talk: route, method, request, response, errors, required role>
- Permissions: <who may see and change what; how user A is kept out of user B's data>
- States and errors: <loading, empty, failure; what the user sees in each>
- Side effects: <each write and external call: what must hold before it (authorization, the final outcome), where it runs (request, job, event loop, thread), and what happens on failure, timeout or client disconnect>
- Decisions: <choice, the alternatives considered, and why>
- Reused: <existing modules and patterns this builds on, with path:line>
- Approved dependencies: <none, or the new packages that were approved (by the user, or logged when `.claude/bin/gate deps` is auto), comma-separated; verify fails on any other>
- Architecture: <none, or what changes in the architecture: a new pattern or layer, a public contract, the database schema, a module boundary (see `.claude/rules/architecture.md`)>
- Estimate: <n> lines

Approved size: <only when this plan stays one PR above the default limit: <n> lines>

## Tasks
| # | Task | Files | Criteria | Test cases | Depends on | Tier | Group |
|---|------|-------|----------|------------|------------|------|-------|
| 1 | <one concern> | <paths> | INVITE-AC1, INVITE-AC5 | <file>: duplicate email, missing role | – | standard | A |

## Risks
- <What could break, and how the plan guards against it.>

## Human-only steps
- <Dashboards, keys, DNS, third-party settings: what, where, which value.>

## Progress
- [ ] 1 <task>

## Verify log
| Criterion | Test | Red seen | Green | Notes |
|-----------|------|----------|-------|-------|

## Stops
- <step> | <class> | <trigger> | <what was tried> | <resolution>

## Rounds
- <review|verify> <n> | <full|delta> | <commit range> | <pass, or fail: <classes>>

## Decisions to review
- <gate> | <what was decided> | <why>

## Notes
- <Per finished task, one or two lines that later tasks need: deviations from the plan, open issues, new helpers or interfaces with path:line.>
```

Rules for the plan:

- `Architecture` and `Estimate` are always there: the plan gate ranks them. Write `Architecture: none` when nothing in the architecture changes, and the estimate of the changed lines as a number.

- The design covers every criterion; it introduces nothing the spec does not ask for.
- Every criterion appears in at least one task. List the coverage; if a criterion has no task, the plan is not done.
- Every write and external call the feature adds is listed under Side effects. A write that must wait for a permission check or the final outcome says so, and a blocking call says where it runs instead of the request or event loop.
- Every file in the Files column sits in its kind's home in `.claude/rules/structure.md`. Run `.claude/bin/structure <every new file the plan names>`; a failure means a different path, or a new home under Decisions whose task adds it to the Map. Paths are relative to the root, also in a monorepo.
- `Reused` names what you searched for, also when nothing fit (`searched src/lib for money formatting: none`).
- Each task is one concern: at most about five files. Split anything bigger. Fold a pure rename or a one-line change into the task whose files it touches.
- Name the test cases, not just "add tests".
- When `KIT_E2E_MAP` is set (`.claude/kit.conf`) and a task adds an e2e test for source paths no row of the map matches, that task adds the row (`<source pattern> TAB <e2e test patterns>`) and names the map file in its Files cell. Without the row, every change to those paths runs the whole e2e suite.
- Order the tasks so nothing is built before what it depends on. Tasks run one after another, in this order.
- Tier: the model tier a task needs. The default is `.claude/bin/route tier implement`. Raise a task to `deep` when it touches auth, data migrations, concurrency, money or a protected contract, or when there is no existing pattern to copy. Lower it to `fast` for pure renames and copy tasks. Every tier other than the default gets a one-line reason under the table (`Task 3 deep: changes the permission check`).
- Group: one headless session implements each group with shared context, so tasks that share files or depend directly on each other go together. A group holds at most 3 consecutive tasks, in plan order. Every task has a group; ids are short (`A`, `B`). The group runs on its highest task tier: one deep task puts the whole group on deep. A group above the default tier gets one line under the table with the reason (`Group B deep: task 5 changes the permission check`).

## 3. Check it

Run `.claude/bin/plan-lint .work/<branch>.md` and fix every finding: a criterion without a task, an ID the spec does not have, test cases not named, a tier without its reason line, a dependency on a later task, a new file outside the Map, a Design line still holding its placeholder. Delete a Design line that does not apply (`Contract` without a contract) instead of leaving its placeholder. This is a hard gate: never ask for approval while it fails.

## 4. Ask for approval

Summarise: the design decisions, the groups and their tiers, the tasks, the files touched, the risks, the human-only steps, and an estimate of the changed lines. If the estimate is over `KIT_MAX_CHANGED_LINES`, propose how to split it into several PRs.

The verify gate fails a branch above twice `KIT_MAX_CHANGED_LINES`, and the build stops as soon as a group passes that limit. If the plan stays one PR above it, add `Approved size: <n> lines` with a margin over the estimate. Only this approval can raise the limit; a session never changes it later.

Then run `.claude/bin/gate plan`, and `.claude/bin/gate split` when the estimate is over `KIT_MAX_CHANGED_LINES`. At `autonomous`, `gate plan` ranks the plan with `.claude/bin/risk plan` (`specs/risk-gates.md`): an `Architecture` line other than `none`, a file in a risky path, or very complex work makes it `ask`, and it prints the reasons. Show them with the summary: a person approves the spec and the plan together.

In a headless session (an autopilot build) an `ask` from `gate plan` has nobody to answer it: write the Stops line `- plan | approval | <the rank and its reasons> | – | user: approve the plan`, end the session with the reasons as your last message, and do not set the status. The build stops there; the developer approves the plan in a terminal.

- `ask`: stop and wait. When the user approves, set the feature's status in `specs/README.md` to `planned`.
- `auto`: choose the split yourself (one PR per independently reviewable part), set the status to `planned`, and log the plan approval, the split and any approved size under Decisions to review.
