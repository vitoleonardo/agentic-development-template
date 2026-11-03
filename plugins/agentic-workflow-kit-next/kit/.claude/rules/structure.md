# Structure

Every kind of code has one home. The Map below says where; `.claude/bin/structure` enforces it for new source files (the guard blocks a misplaced write, `/verify-feature` and CI fail on one). `/onboard` rewrites the Map from the repository's own layout; until then these are the kit's defaults.

- New code goes to its kind's home. Do not add a new top-level folder or a second home for a kind without asking: the plan names it under Decisions, and the same change adds it to the Map.
- Before writing a function, component, hook, type or schema, search its home and the names it would have (`rg`). Extend what exists instead of writing a second one.
- Code moves to a shared home when a second feature needs it, not before. Move it; never copy it.
- No grab-bag files or folders (`utils`, `helpers`, `common`, `misc`). Name them after what they hold. A file the Map lists by its full path is allowed.
- `## Legacy` lists old homes. Their code stays until a task moves it; they take no new files.
- `.claude/bin/check duplicates` fails on code the branch copies, also with renamed variables. Reuse the original instead.
- Paths are relative to the root, or to a package with its own `.claude/kit.conf`. `<name>` stands for any name; a path ending in `/` covers everything below it; a pattern without `/` matches the file name anywhere. Presets add their framework's homes in their own `## Map`.

## Map

| Kind | Home | Naming |
|------|------|--------|
| Entry points (pages, routes, handlers, actions, CLI, jobs) | `src/app/`, `bin/` | the framework's file names; thin (see `architecture.md`) |
| Feature logic | `src/features/<domain>/` | one concept per file, named after it |
| Data access | `src/data/<entity>.ts` | the entity |
| Shared UI components | `src/components/` | the component; a component one feature uses stays in that feature |
| Shared helpers (two or more features use them) | `src/lib/<topic>.ts` | the topic |
| Config and environment | `src/config.ts` | the one module that reads the environment |
| Unit tests | `*.test.*`, `*.spec.*` | next to the source; the test name starts with the criterion ID |
| E2E tests and fixtures | `e2e/` | `<feature>.spec.ts` |
| Scripts | `scripts/` | verb and noun (`seed-db.ts`) |
| Tool config | `*.config.*` | the tool's name |

## Legacy

None.
