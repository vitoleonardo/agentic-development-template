# E2e map

ID prefix: E2EMAP

## Goal
A change runs only the e2e tests of the parts it touches. Today `evidence e2e-select` runs the whole suite as soon as a changed source file is not named by a criterion of the change, which in a real project (os.home, 20 to 23 minutes per run) means the whole suite on almost every feature. A project-owned map says which e2e tests cover which source paths, so the selection can vouch for a source file without guessing. A file the map does not know still runs everything, so a gap in the map costs time, never coverage.

## User flow
1. The team writes `.kit/e2e-map.tsv`: one row per area, a source pattern and the e2e tests that cover it.
2. `KIT_E2E_MAP` in `.claude/kit.conf` names that file.
3. `/plan-feature` adds a row in the task that adds an e2e test for a new area.
4. `evidence e2e-select` (and every step that uses it: `evidence data`, `evidence screenshots`) runs the tests the map selects for the changed files.
5. `evidence gates` fails while a row names a pattern that matches no file, so a renamed test or folder is found at the next verify.

## Terms
- **Map**: the file `KIT_E2E_MAP` names, relative to the root. Rows are `<source pattern> TAB <targets>`. Lines that are empty or start with `#` are not rows.
- **Source pattern**: a shell pattern as in `KIT_SOURCE_PATTERNS`, matched against a changed file's path relative to the root.
- **Targets**: `all`, `-`, or space-separated shell patterns matched against the paths of e2e files (files matching `KIT_E2E_PATTERNS`).
- **Row of a file**: the first row whose source pattern matches the file.
- **Source change**: a changed file that matches neither `KIT_E2E_PATTERNS` nor the test patterns, and is not a `.md` file.
- **Selection**: the first line `evidence e2e-select` prints (`all: …`, `related: …`, `none: …`) and, for `related`, the selected files.

## Acceptance criteria

Selection with a map:

- **E2EMAP-AC1**: Given a map row `src/invoices/* TAB e2e/invoice-*` and a branch that changes only `src/invoices/total.ts`, when `evidence e2e-select` runs, then the selection is `related` and lists every e2e file matching `e2e/invoice-*` and no other file.
- **E2EMAP-AC2**: Given map rows `src/invoices/* TAB e2e/invoice-*` and `src/time/* TAB e2e/time-*`, and a branch that changes a file under each folder, when `evidence e2e-select` runs, then the selection lists the e2e files of both rows.
- **E2EMAP-AC3**: Given a map row `src/db/schema.ts TAB -` and a branch that changes only `src/db/schema.ts`, when `evidence e2e-select` runs, then the selection starts with `none:` and names `src/db/schema.ts`.
- **E2EMAP-AC4**: Given a map row `src/layout/* TAB all` and a branch that changes `src/layout/nav.tsx`, when `evidence e2e-select` runs, then the selection starts with `all:` and names `src/layout/nav.tsx`.
- **E2EMAP-AC5**: Given a map without a row for `src/other.ts` and a branch that changes it, when `evidence e2e-select` runs, then the selection starts with `all:` and names `src/other.ts` and the map file.
- **E2EMAP-AC6**: Given the row `src/invoices/pdf/* TAB e2e/pdf-*` above the row `src/invoices/* TAB e2e/invoice-*`, and a branch that changes only `src/invoices/pdf/render.ts`, when `evidence e2e-select` runs, then the selection lists the files of `e2e/pdf-*` and no file of `e2e/invoice-*`.
- **E2EMAP-AC7**: Given a map row `src/invoices/* TAB e2e/invoice-*` and a branch that changes `src/invoices/total.ts` and adds a criterion `SHOP-AC4` named in `e2e/shop.spec.ts`, when `evidence e2e-select` runs, then the selection lists `e2e/shop.spec.ts` and the files of `e2e/invoice-*`.
- **E2EMAP-AC8**: Given a map row `package.json TAB -` and `KIT_E2E_FULL_PATTERNS` holding `package.json`, when a branch changes `package.json` and `evidence e2e-select` runs, then the selection starts with `all:`.
- **E2EMAP-AC9**: Given `KIT_E2E_FULL_PATTERNS` holding `tests/e2e/*.ts` and `KIT_E2E_PATTERNS` holding `tests/e2e/*.spec.ts`, when a branch changes only `tests/e2e/time.spec.ts` and `evidence e2e-select` runs, then the selection is `related` and lists only `tests/e2e/time.spec.ts`.
- **E2EMAP-AC10**: Given a map with CRLF line endings, a comment line and an empty line, when `evidence e2e-select` runs, then the selection is the same as for the map without them.

Without a map:

- **E2EMAP-AC11**: Given `KIT_E2E_MAP` is empty and a branch that changes a source file no criterion of the change names, when `evidence e2e-select` runs, then the selection starts with `all:` and names that file.
- **E2EMAP-AC12**: Given `KIT_E2E_MAP` names a file that does not exist, when `evidence e2e-select` runs, then the selection starts with `all:` and names the missing map file.

Checking the map:

- **E2EMAP-AC13**: Given a map whose rows all match at least one tracked file and whose targets all match at least one e2e file, when `evidence gates` runs, then the `e2e map` gate passes.
- **E2EMAP-AC14**: Given a map row whose target `e2e/billing-*` matches no e2e file, when `evidence gates` runs, then the `e2e map` gate fails and names `e2e/billing-*` and the row's line number.
- **E2EMAP-AC15**: Given a map row whose source pattern `src/billing/*` matches no tracked file, when `evidence gates` runs, then the `e2e map` gate fails and names `src/billing/*`.
- **E2EMAP-AC16**: Given a map row without a TAB, when `evidence gates` runs, then the `e2e map` gate fails and names the row's line number.
- **E2EMAP-AC17**: Given `KIT_E2E_MAP` is empty, when `evidence gates` runs, then the `e2e map` gate is `n/a` and does not fail.

Planning:

- **E2EMAP-AC18**: Given `KIT_E2E_MAP` is set, when `/plan-feature` plans a task that adds an e2e file for source paths no row matches, then that task's Files cell names the map file.

## Edge cases
- **E2EMAP-AC19**: Given a map row whose source pattern has a space in it, when `evidence e2e-select` runs, then the row's source pattern is read up to the TAB.
- **E2EMAP-AC20**: Given a branch that changes only the map file, when `evidence e2e-select` runs, then the selection starts with `all:` and names the map file.

## Out of scope
- Building the map from coverage data or imports. The map is written by hand and by the plan.
- Selecting tests inside a file (by line or by grep). The unit of selection stays the e2e file.
- Where and how often e2e runs; that is the stack stage (`specs/stack-stage.md`).

## Open questions

## Decisions
- 04.11.2026: A file the map does not know runs the whole suite, as os.home's `scripts/e2e-select.mjs` does (ADR-065), because a missing row may only cost time, never skip a test.
- 04.11.2026: `KIT_E2E_FULL_PATTERNS` wins over the map, and changed e2e files are checked before them, because the map may never lower the bar set by the full patterns, while a changed test file alone should never run the whole suite.
- 04.11.2026: The map lives outside `.claude/`, so a plan's task can add a row; a change to the map runs the whole suite, and the risk gates (`specs/risk-gates.md`) treat it as a change a person approves.
- 04.11.2026: Criterion matching stays as an addition, so tests named after the change's criteria still run when the map points elsewhere.
