# Reference Analysis (Phase 0)

Status: **approved** (23.10.2026) with the default decisions in section 6. No own rules, hooks or settings were provided, so G1 to G3 are built from scratch.

## Sources

`references/` is gitignored. Source folders were renamed to neutral labels before analysis; no client names, hosts or people appear below.

| Label | What it is |
|---|---|
| `builder` | Generic generator skill that scaffolds a project SDLC pipeline, plus agent, eval and orchestrator templates and a retro dashboard script |
| `project-a` | Pipeline skill and 4 agents for a multi-repo project (JVM backend, two React SPAs, self-hosted GitLab) |
| `project-b` | Pipeline skill, 4 agents and 2 stack rubrics with evals for a single-repo project (JVM backend and React SPA) |
| `project-b-branch` | Older revision of `project-b` (6 phases, rubrics loaded by file path) |
| `nextjs-guideline` | Next.js 16 SDLC guideline: pipeline, baseline facts, layout, review checklist, gate order |
| `greenfield` | The sibling template in this repo (`templates/greenfield-nextjs`) |
| `external/` | Empty so far |

**Missing from the references:** there is no `settings.json`, no hook script, no `CLAUDE.md`/rules file, no CI workflow and no MCP config in the private references. Everything in those areas is a gap (see section 4).

## 1. Inventory and recommendation

Decision key: **Include** (take the pattern as is) · **Adapt** (take the idea, change the shape) · **Drop**.

### 1.1 Pipeline and orchestration

| # | Item | Source | Purpose | Decision | Reason |
|---|---|---|---|---|---|
| P1 | 7-phase pipeline: intake, plan, implement, simplify, review, PR, retro | builder, project-a, project-b, nextjs-guideline | Fixed flow per change | Adapt | Becomes `/ship-feature`: spec, plan, build, review, PR. Simplify is a step inside build and retro is dropped (P16) |
| P2 | Mandatory gates at plan approval and before push | all pipelines | Human approves the HOW and anything outward-facing | Include | Core of the workflow; matches the spec and the Blueprint |
| P3 | Intake: restate, ask only what code cannot answer, Given/When/Then criteria, explicit out of scope | project-a, project-b | Turns a request into a checkable brief | Adapt | Becomes `/spec-feature`. Adds stable criterion IDs, open questions and decisions, and is committed as `specs/<feature>.md` instead of a throwaway scratch note |
| P4 | Plan in plan mode, with parallel Explore agents returning `file:line` anchors and reuse candidates | project-a, project-b | Grounds the plan in real code | Include | `/plan-feature` |
| P5 | Each plan step names its files and the criterion it satisfies | project-a, project-b | Coverage of every criterion | Include | This is the plan link in the traceability chain |
| P6 | Explicit edge-case test list per step (invalid input, empty, duplicate, auth denied) | project-a | Better tests than "write a spec" | Include | Goes into the plan template and the `test-writer` prompt |
| P7 | Contract between frontend and backend written down before parallel work | project-a, project-b | Prevents drift | Adapt | Optional plan section, used only when a change spans a Next.js app and an API. The demo app exercises it |
| P8 | Per-task state file outside the repo, read by every subagent, survives compaction | project-a, project-b, builder | Resume after a crash or compaction; shared context | Adapt | `.work/<branch>.md`, gitignored, holds plan progress and the verify log. The spec itself is committed separately |
| P9 | Verify log: one row per criterion with the evidence and pass/fail | project-a, project-b, builder | Proof instead of claims | Include | Feeds the reviewer report and the PR description's evidence table |
| P10 | "What does green really mean" check: are tests real or stubs, does CI run them, can a command exit 0 on failure | builder, project-a, project-b | Stops "pipeline green" being read as "verified" | Include | Becomes an install checklist item and a reviewer check ("0 tests ran" counts as a failure) |
| P11 | Runtime verification: run the app, smoke an endpoint, check the boot log | project-a, project-b | Primary gate when tests are weak | Adapt | Optional `/ship-feature` step. Generic `next build` plus a smoke check. Drop the project-specific scripts |
| P12 | Model per slice: stronger model for logic and auth, cheaper model for 1:1 copies | project-a, project-b | Cost control | Adapt | One line of guidance in `/ship-feature`. Agents use `model: inherit` by default |
| P13 | Implementers never branch or push; the orchestrator owns git | all agents | Single owner of outward actions | Include | Rule in the agent prompts |
| P14 | Agent return contract: files changed, criterion coverage, tests and results, deviations | builder, project-a, project-b | Orchestrator can verify without re-reading everything | Include | Shared return format for `implementer` and `test-writer` |
| P15 | Report faithfully: skipped tests, unmet criteria and red builds are stated at the gate | project-a, project-b | Honesty under pressure to advance | Include | Goes in `CLAUDE.md` |
| P16 | Retro ledger (`retro.jsonl`), graduation after 3 recurrences, propose-only edits | builder, project-a, project-b | Self-improvement loop | Adapt | Drop the ledger for v1. Keep "never auto-edit the rules you are judged against" as a rule. `docs/build-log.md` covers the dogfooding story |
| P17 | Retro dashboard script, email delivery, external ingest | builder, project-a | Reporting | Drop | Non-goal (no dashboard), and the delivery is personal infrastructure |
| P18 | Pre-authenticated preview links via a dev-only token bootstrap | project-a, builder | Lets the user test the change themselves | Drop | Project-specific and security-sensitive |
| P19 | UI screenshots at mobile and desktop width for PRs | project-a | Visual evidence | Adapt | Optional hint in `/pr-description` for UI diffs. No upload automation |
| P20 | Merge request mechanics: glab, push options, URL fallbacks | project-a, project-b | Deliver to self-hosted GitLab | Drop | v1 is GitHub-only. `/pr-description` writes text and does not push |

### 1.2 Agents and rubrics

| # | Item | Source | Purpose | Decision | Reason |
|---|---|---|---|---|---|
| A1 | Read-only reviewer (`tools: Read, Grep, Glob`), reports `file:line` and severity, did not write the code | builder, project-a, project-b | Independent review | Include | `reviewer`. Adds a pass / fail / not-checkable verdict per criterion |
| A2 | Reviewer flags thin tests (happy path only) | project-a | Test quality | Include | Reviewer checklist. Red-before-green check added (gap G8) |
| A3 | `/code-review` as primary reviewer with the agent as fallback (one source names a third-party tool as primary instead) | project-a, project-b | Second engine | Drop | Depends on tooling outside the kit. The kit's own `reviewer` is primary; other tools stay optional |
| A4 | One implementer per framework | builder, project-a, project-b | Stack expertise per workstream | Adapt | One generic `implementer` that preloads the active preset's rules. Used per plan task for a fresh context |
| A5 | Simplifier agent (reuse, DRY, KISS) limited to changed code | builder, project-a, project-b | Behaviour-preserving cleanup | Adapt | No separate agent. A simplify step inside `/ship-feature` with the same scope rule |
| A6 | Rubric preloaded through the agent's `skills:` frontmatter, which fails loudly, instead of hand-reading a path, which fails silently | builder, project-b (the older branch used the fragile way) | Rubric always present | Include | Confirmed by current docs (section 5) |
| A7 | Stack rubric per framework: layout, layering, security, testing, anti-pattern checklist, sources | project-b | How code is written here | Adapt | Becomes `presets/<stack>/` rules. Content is rewritten for Next.js, NestJS and Node; nothing from the source domain carries over |
| A8 | Version filter over a popular rubric (APPLY / TRANSLATE / SKIP plus forbidden newer APIs) | builder, project-b | Reuse rubrics on older stacks | Adapt | Documented as a pattern in `customizing.md` |
| A9 | Evals: at least 3 scenarios per rubric, baselined without the skill first | builder, project-b | Regression set for rule changes | Adapt | Documented in `customizing.md`; shipping evals is a v2 candidate |
| A10 | Builder flow: detect stack, pick rubrics by trust signals, scaffold agents and orchestrator | builder | Tailor a pipeline to any repo | Drop | This is the paid tailoring service; the kit ships the generic result |
| A11 | Install scope: reusable rubrics global, agents and orchestrator per project | builder | One copy of shared rubrics | Adapt | Kit installs per project (team-shared via git); the plugin covers reuse across projects |

### 1.3 Conventions and stack rules

| # | Item | Source | Purpose | Decision | Reason |
|---|---|---|---|---|---|
| C1 | Read the project's own docs and scripts first; never invent commands it already documents | builder, project-a, project-b | Correct commands | Include | Kit hooks and CI call `package.json` scripts (`typecheck`, `lint`, `test`, `build`) |
| C2 | Sync the base branch first; never pull over a dirty tree; never commit to the base branch | project-a, project-b | Safe git | Include | `rules/git.md` |
| C3 | Branch `<issue>-<slug>`; imperative commit subject, rationale in the body | project-a, project-b, nextjs-guideline | Readable history | Include | `rules/git.md` (branch pattern is configurable) |
| C4 | Stay inside the scoped directory; never touch other repos | all agents | Blast radius | Adapt | Becomes the `test-writer` path restriction and the implementer's task scope |
| C5 | Dates DD.MM.YYYY, German UI, two locales, toolchain quirks, seed data, DB reconcile steps | project-a, project-b | Project facts | Drop | Project-specific. The pattern "an ops-facts section in `CLAUDE.md`" is kept |
| C6 | Add a dependency only when the platform does not cover it; note the tradeoff | nextjs-guideline | Dependency discipline | Include | Combined with "ask before adding dependencies" |
| C7 | No `any` or `@ts-ignore` without a linked reason | nextjs-guideline, project-b | Type safety | Include | `rules/code-style.md` |
| C8 | Next.js 16 facts: async request APIs, `proxy.ts`, `next lint` removed, `cacheComponents`, React Compiler flag | nextjs-guideline | Current platform | Include | Next.js preset. Re-verify against the Next.js docs when writing it |
| C9 | Layout: `app/` routes only, `features/<domain>`, server-only `data/` access layer | nextjs-guideline | Structure | Include | Next.js preset (marked as convention) |
| C10 | Server Actions are public endpoints: authenticate, authorize and validate in each one; return minimal fields; revalidate after mutations | nextjs-guideline | Security | Include | Next.js preset; the generic part ("authz and validation at every boundary") goes in `rules/security.md` |
| C11 | Gate order, cheapest first: typecheck, lint, unit, build, e2e; CI only counts if it runs them | nextjs-guideline | What green means | Include | Hooks run typecheck and related tests only; CI runs the full order |
| C12 | Vitest cannot test async Server Components; cover them with E2E | nextjs-guideline | Test strategy | Include | Next.js preset |
| C13 | Each criterion maps to the test or command that proved it, in the PR description | nextjs-guideline | Evidence | Include | `/pr-description` evidence table |
| C14 | Upgrade routine: read the guide, codemod on a branch, run all gates, update the preset | nextjs-guideline | Keeps rules current | Adapt | "Maintenance" section in `customizing.md` |
| C15 | Machine-readable gate list (`quality-gates.yaml`) and validator scripts | greenfield | Structural checks | Drop | Too opinionated for existing projects; CI calls npm scripts directly |
| C16 | Kebab-case naming and markdown-location validators | greenfield | Repo hygiene | Drop | Imposes a convention; the kit respects the project's own |
| C17 | GitHub MCP server example | greenfield (`.cursor/mcp.json`) | MCP setup | Adapt | Basis for `.mcp.example.json`, plus a read-only database entry |

## 2. Duplicates and conflicts

| Topic | Conflict | Resolution |
|---|---|---|
| Pipeline text | Five near-copies (builder template, project-a, project-b, project-b-branch, nextjs-guideline) | Base on `project-b` (newest) plus the builder template; ignore `project-b-branch` |
| Phase count | `project-b-branch` has 6 phases (no retro); the others have 7 | Kit uses spec, plan, build, review, PR, with optional runtime verify |
| Rubric loading | Hand-read file paths ("Skill tool not reliable in subagents") vs `skills:` preload | Use preload (confirmed, section 5) |
| Primary reviewer | Pipeline text says `/code-review`; one agent description names a different external tool | Kit `reviewer` agent is primary |
| Frontend tests | project-a: "no harness, do not scaffold tests"; project-b: "write Jest/RTL tests" | Kit: new features need tests in the same PR |
| Reviewer model | project-a uses a cheaper model; project-b uses a stronger one | `model: inherit`; documented as a tuning knob |
| MR shape | project-a: one MR per repo; project-b: one MR for both subprojects | Not relevant (single repo, GitHub PR) |
| File naming | nextjs-guideline: camelCase or kebab-case, one per repo; greenfield: kebab-case enforced | Kit does not impose naming |
| Lint tool | nextjs-guideline: ESLint or Biome; greenfield: Biome | Kit calls the project's `lint` script |

## 3. Kit components and their sources

| Kit component | Built from |
|---|---|
| `CLAUDE.md` | P15, C1, ops-facts pattern from C5 |
| `rules/architecture.md` | C9 (generic part), C10 (generic part), P7 |
| `rules/testing.md` | P6, A2, C11, C12 (generic part), G8 |
| `rules/security.md` | C10, gap G1 |
| `rules/code-style.md` | C6, C7 |
| `rules/git.md` | C2, C3, P13 |
| `/spec-feature` | P3, gaps G7, G9 |
| `/plan-feature` | P4, P5, P6, P7 |
| `/ship-feature` | P1, P2, P8, P9, P11, P12, A5 |
| `/write-tests`, `/review-diff`, `/pr-description` | A2, C13, P19; gap G6 |
| `reviewer` | A1, A2, A6, P10 |
| `test-writer` | P6, C4; gap G5 |
| `implementer` | A4, A6, P13, P14 |
| `presets/nextjs` | C8, C9, C10, C12 |
| `.mcp.example.json` | C17 |

## 4. Gaps (required by the spec or the Blueprint, covered by no reference)

| # | Gap | Required by |
|---|---|---|
| G1 | `settings.json` permissions: allow / ask / deny, `.env*` read deny, destructive-command deny, network limits | Spec 5.3 |
| G2 | All four hooks: dangerous-command block, typecheck and related tests after edits, format after edits, stop summary | Spec 5.4 |
| G3 | `CLAUDE.md` and rule modules as files; references only have rule content scattered inside pipeline skills | Spec 5.2 |
| G4 | CI workflow: typecheck, lint, tests, coverage on changed files, diff-size warning. Both reference projects' CI runs **no tests** | Spec 5.7 |
| G5 | `test-writer` limited to test folders: no reference restricts edit paths | Spec 5.6 |
| G6 | Standalone `/write-tests` and `/pr-description` commands outside a full pipeline | Spec 5.5 |
| G7 | Stable criterion IDs that survive spec edits; tests and the review report reference them | Blueprint (traceability). Built: IDs, `spec-lint`, reviewer verdict per criterion |
| G8 | Red-before-green: evidence that a new test failed before the fix | Blueprint (build) |
| G9 | One spec per feature, committed, with decisions and open questions; extended, not duplicated | Blueprint (spec) |
| G10 | Feature status overview (one line per feature, current state only) | Blueprint (project memory) |
| G11 | NestJS and plain Node presets | Spec 5.1 |
| G12 | `.mcp.example.json` with a read-only database entry | Spec 5.8 |
| G13 | Plugin packaging | Spec 5.9 |
| G14 | Setup audit: overlong `CLAUDE.md`, orphaned specs, criteria without tests | Blueprint (maintenance). Candidate for v2; v1 documents a manual checklist |
| G15 | Demo app, README, team playbook, customizing guide | Spec 5.10, 6 |

## 5. Platform facts that change the spec layout

Checked against code.claude.com/docs on 23.10.2026. Re-check before Phase 1 writes files.

| Fact | Effect on the kit |
|---|---|
| Custom commands are merged into skills. `.claude/commands/*.md` still works, but `.claude/skills/<name>/SKILL.md` is the current form | Commands ship as `.claude/skills/<name>/SKILL.md` instead of `.claude/commands/` |
| `.claude/rules/**/*.md` loads automatically, and `paths:` frontmatter scopes a rule to matching files | Rules move from `rules/` to `.claude/rules/`. Presets become path-scoped rules (e.g. `paths: ["app/**"]`). `CLAUDE.md` stays short and does not need imports |
| Deny wins over ask over allow, across all scopes. A `Read(.env)` deny turns `cat .env` into an approval prompt, not a denial (tested), and Bash denies miss `sh -c`, full-path calls and scripts | The deny list has explicit Bash patterns for `.env`, and the dangerous-command hook is a real second layer, not just a backup |
| No native per-path edit restriction for subagents. Use a PreToolUse hook in the agent's frontmatter, or a settings hook that checks `agent_type` | `test-writer` gets a frontmatter hook. Plugin subagents ignore frontmatter hooks, so the plugin needs the `agent_type` hook variant |
| Subagent `skills:` frontmatter preloads skills by name | Confirms A6 |
| Plugins can ship skills, agents, hooks and MCP servers, but **not permissions** (plugin `settings.json` only applies `agent` and `subagentStatusLine`) | `settings.json` stays a manual copy step in the plugin install path. Plugin hooks still block dangerous commands |
| PostToolUse exit 2 sends stderr back to Claude; Stop exit 2 keeps Claude working, so check `stop_hook_active` to avoid loops | Edit hooks report failures with exit 2; the stop hook prints its summary and does not block |

## 6. Change after approval: language-neutral core

Decided 23.10.2026. The kit splits into a core that works in any language and stack adapters. v1 ships and tests only the TypeScript adapter.

- `kit/` (core): `CLAUDE.md`, the workflow, the general rules, `settings.json`, `specs/`, and `.claude/bin/check`, one entry point for typecheck, lint, test, related tests, format and build.
- `adapters/<stack>/` overlays the core. Its `.claude/kit.conf` (POSIX sh) defines what each check runs; it also adds language rules and stack presets, and later its CI workflow.
- Hooks and CI call `.claude/bin/check`, never a package manager directly, so `settings.json` needs one allow line for checks and nothing is merged at install time.

## 7. Decisions for approval

1. Specs live in `specs/<feature>.md` (committed). Plan progress and the verify log live in `.work/<branch>.md`, which ignores itself through `.work/.gitignore`. (First planned as `.claude/state/`, but Claude Code protects `.claude/` against writes; see the build log.)
2. Criterion IDs are `<FEATURE>-AC<n>` (for example `INVITE-AC3`). IDs are never reused after deletion. Test names include the ID.
3. Three agents (`reviewer`, `test-writer`, `implementer`). The simplifier is a step, not an agent.
4. Retro ledger and evals are deferred to v2 (P16, A9).
5. Feature status is a table in `specs/README.md`, one row per spec, current state only (G10).
6. **Missing material:** the spec expects your own rules, hooks and settings among the private references, but the archive contains none. If they exist, add them before Phase 1; otherwise G1 to G3 are built from scratch.
