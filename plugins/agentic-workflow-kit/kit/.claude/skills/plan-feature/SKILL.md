---
name: plan-feature
description: Turn an approved spec into a short implementation plan (tasks, files, tests, risks, criteria per task), approved before any code is written. Use when the user asks to plan a feature.
argument-hint: <feature name or spec path>
---

# Plan a feature

Feature: $ARGUMENTS

Write only the state file and the status row; no source files.

## 1. Read

- The spec in `specs/`. If its status in `specs/README.md` is not `approved`, stop and say so. A small fix without a spec gets two or three acceptance criteria in the plan, approved with it.
- The code the feature touches. In a large codebase, use parallel `Explore` subagents (`model` from `.claude/bin/route explore`) and keep their conclusions, not file dumps. Collect `path:line` anchors, existing pieces to reuse, and the pattern to mirror.

## 2. Write the plan

Write it to `.work/<branch>.md`: the current branch, or on `main` the branch name you propose (`<issue>-<slug>`). Do not create the branch yet.

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

## Tasks
| # | Task | Files | Criteria | Test cases | Depends on | Tier |
|---|------|-------|----------|------------|------------|------|
| 1 | <one concern> | <paths> | INVITE-AC1, INVITE-AC5 | <file>: duplicate email, missing role | – | standard |

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

- The design covers every criterion and adds nothing the spec does not ask for.
- Every criterion appears in at least one task. List the coverage; a criterion without a task means the plan is not done.
- Every write and external call the feature adds is under Side effects, including one that must wait for a permission check or the final outcome, and where a blocking call runs instead of the request or event loop.
- Every file in the Files column sits in its kind's home in `.claude/rules/structure.md`. Run `.claude/bin/structure <every new file the plan names>`; a failure means a different path, or a new home under Decisions whose task adds it to the Map.
- `Reused` names what you searched for, also when nothing fit (`searched src/lib for money formatting: none`).
- Each task is one concern of at most about five files; split anything bigger. Fold a pure rename or a one-line change into the task whose files it touches.
- Name the test cases, not just "add tests".
- Order the tasks so nothing is built before what it depends on; they run one after another in this order.
- Tier: the implementer's model tier, default `.claude/bin/route tier implement`. `deep` for auth, data migrations, concurrency, money, a protected contract, or no existing pattern to copy; `fast` for pure renames and copy tasks. Every non-default tier gets a one-line reason under the table (`Task 3 deep: changes the permission check`).

## 3. Ask for approval

Summarise the design decisions, tasks, files touched, risks, human-only steps, and an estimate of the changed lines. Over 400 lines, propose a split into several PRs.

Then run `.claude/bin/gate plan`, and `.claude/bin/gate split` when the estimate is over 400 lines.

- `ask`: stop and wait. When the user approves, set the feature's status in `specs/README.md` to `planned`.
- `auto`: choose the split yourself (one PR per independently reviewable part), set the status to `planned`, and log the plan approval and the split under Decisions to review.
