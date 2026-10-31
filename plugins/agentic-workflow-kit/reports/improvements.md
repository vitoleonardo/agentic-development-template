# Kit improvements

The values before come from the pilot run on a NestJS and React monorepo (M2 to M7, headless with `KIT_APPROVAL=autonomous`, 28.10.2026 and 29.10.2026; 14 verify rounds over six milestones). Copy this file into the project's `reports/` with the kit update; `/improve-kit` checks each entry after three more runs.

- 29.10.2026 | baseline compare keeps an earlier package's failure (coverage, lint, typecheck) | coverage gate passes whose detail prints a value below the threshold | 2 (M4 0%, M5 43.8%)
- 29.10.2026 | coverage leaves test and e2e files out; a gate that prints a failing value fails | changed Playwright flows measured as source files | M4, M5 (apps/client)
- 29.10.2026 | secret pattern scan: key formats fail, name = value only warns; exact allowlist; reports/runs/ never scanned | verify rounds caused by kit false positives | about 8 of 14
- 29.10.2026 | gitleaks scans the branch's commits with the allowlist as a generated config | gitleaks findings on fake values, per milestone against its own base | M3 2 (ai-token.service.spec.ts), M4 0, M5 0
- 29.10.2026 | /onboard reports a missing gitleaks as a setup gap | milestones that ran on the pattern scan | M2 to M7, all
- 29.10.2026 | one base per run, written as Base: in the state file and read by every script | verify rounds caused by the wrong base | 2
- 29.10.2026 | verify failures classified as kit, test, hotfix or spec; gate round decides | verify rounds per milestone | median 2.5, mean 2.3
- 29.10.2026 | screenshots judged by the implementer and in review, verify only confirms | verify rounds caused by screenshot findings | 4
- 29.10.2026 | base screenshot run gets KIT_BASE_ENV; a base without the feature is n/a | base screenshot runs that failed | all of them
- 29.10.2026 | e2e results count in the edge-case matrix (KIT_E2E_REPORT) | edge cases marked "n/a: e2e only" | 26
- 29.10.2026 | the test-writer may edit e2e and screenshot flows | edits the main session made for the test-writer | 1 (M5)
- 29.10.2026 | duplicates: pieces of a legacy clone are legacy; NestJS constructor pattern documented | placements and refactors to satisfy the duplicates gate | 4 placements and 1 refactor
- 29.10.2026 | test stack declares its own database, Redis db and port | verify rounds caused by test-stack collisions | 2 (M5)
- 29.10.2026 | later review and verify rounds scoped to what changed (evidence scope, gates --only) | reviewer tokens per review round after round 1 | not recorded before; M5: 4 review and 4 verify rounds, 52.88 USD
- 29.10.2026 | later review and verify rounds scoped to what changed (evidence scope, gates --only) | cost per milestone | M3 26.01, M4 33.19, M5 52.88, M6 25.49, M7 38.89+ USD
- 29.10.2026 | autopilot watchdog, usage-limit waits, sessions.tsv with summed turns | sessions whose recorded turns are wrong | M6: 3 recorded, 152 in its five result lines
- 31.10.2026 | duplicates: a clone inside constructor parameter lists passes, *.e2e-spec.* left out, the edit hook runs the same helper | duplicates `kit` stops; refactors to satisfy the gate | 3 stops in 9 runs (M7, M8); 4 refactors (M8)
- 31.10.2026 | red gate warns when a new criterion test passes on the base | runs with a weak-test review finding; median review rounds | 7 of 9 runs; 4
- 31.10.2026 | the plan lists each side effect: what it waits for, where it runs, what happens on failure | `plan` stops from ordering and blocking calls | 4 in 9 runs
- 31.10.2026 | /onboard names an empty KIT_SETUP, KIT_BASE_ENV and token budget | `env` stops; failed base screenshot runs | 5 in 9 runs; every base run since M5
