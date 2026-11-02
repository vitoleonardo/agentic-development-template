# Kit greenfield MVP

ID prefix: MVP

Status: draft. Findings from the analysis on 02.11.2026; criteria follow once the open questions are settled.

## Goal
A founder or team starts a new product with the kit instead of an existing repository. In one guided flow they define the MVP, pick a stack, get a scaffold whose checks run, and end with an approved feature list the kit can build feature by feature, by hand or with autopilot.

## What the kit does today
- Brownfield is covered from spec to PR: `install.sh`, `/onboard`, `/spec-feature`, `/plan-feature`, `/ship-feature`, `/verify-feature`, `/pr-description`, `bin/autopilot`, `/improve-kit`.
- There is no MVP flow. The only product-level fact is the `Product:` line in `CLAUDE.md`, which a person fills in. `/spec-feature` writes one feature at a time.
- `/onboard` does not fit an empty repository. A repository without commits has no HEAD for the baseline. Every check command stays "not configured", and `evidence` fails such gates, so `/verify-feature` cannot pass until someone writes the commands by hand. There is no empty-repository fixture.
- The kit has no stack choice and no scaffold. The TypeScript adapter assumes a `package.json` that already defines `typecheck`, `lint`, `test` and `build`.
- `templates/greenfield-nextjs` is a separate, manual process: `product/brief.md`, `product/scope.yaml`, slices and `PENDING`/`COMPLETE` states. It has no feature rows, no criterion IDs and no evidence pack, and nothing hands it over to the kit.
- The docs disagree: `plugins/agentic-workflow-kit/docs/SPEC-v1.1.md` says v1 only fits greenfield repositories, while `README.md` sends new apps to the template and existing projects to the kit.
- After the PR, nothing follows in either mode: no merge, deploy or release stage, and no backlog step that orders features or records their dependencies.

## User flow (proposal)
1. `/define-mvp` interviews the founder: who uses it, the problem, the smallest version that proves it, and what is out.
2. It writes `product/brief.md` and proposes the MVP as feature rows in `specs/README.md`, in build order, each with a one-line goal and its dependencies.
3. It proposes a stack from the kit's adapters and presets, and scaffolds it so `typecheck`, `lint`, `test` and `build` run green on the first commit.
4. It runs `/onboard` on the scaffold, which now has commands to record.
5. The founder approves the feature rows; `/spec-feature` writes each spec, and autopilot builds the approved ones on stacked branches.

## Open questions
- Does `/define-mvp` replace `templates/greenfield-nextjs`, or does the template become one scaffold the flow can pick?
- Which stacks get a scaffold in the first version: only the TypeScript preset, or Python too?
- Does the feature list get a dependency column, so autopilot orders by dependency instead of file order?
- Should `/onboard` accept an empty repository itself (no HEAD, no commands yet), or only run after the scaffold?
- Is a merge and release stage part of this, or a separate spec?

## Decisions
