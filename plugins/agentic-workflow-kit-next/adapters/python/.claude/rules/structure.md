# Structure

Every kind of code has one home. The Map below says where; `.claude/bin/structure` enforces it for new source files (the guard blocks a misplaced write, `/verify-feature` and CI fail on one). `/onboard` rewrites the Map from the repository's own layout; until then these are the kit's defaults.

- New code goes to its kind's home. Do not add a new top-level folder or a second home for a kind without asking: the plan names it under Decisions, and the same change adds it to the Map.
- Before writing a function, class, type or schema, search its home and the names it would have (`rg`). Extend what exists instead of writing a second one.
- Code moves to a shared home when a second feature needs it, not before. Move it; never copy it.
- No grab-bag modules or packages (`utils`, `helpers`, `common`, `misc`). Name them after what they hold. A file the Map lists by its full path is allowed.
- `## Legacy` lists old homes. Their code stays until a task moves it; they take no new files.
- `.claude/bin/check duplicates` fails on code the branch copies, also with renamed variables. Reuse the original instead.
- Paths are relative to the root, or to a package with its own `.claude/kit.conf`. `<name>` stands for any name; a path ending in `/` covers everything below it; a pattern without `/` matches the file name anywhere.

## Map

| Kind | Home | Naming |
|------|------|--------|
| Package root | `src/<package>/__init__.py` | – |
| Entry points (CLI, API routes, workers) | `src/<package>/cli.py`, `src/<package>/__main__.py`, `src/<package>/api/` | thin (see `architecture.md`) |
| Feature logic | `src/<package>/<domain>/`, `src/<package>/<module>.py` | a module per concept; a subpackage per domain once there are several |
| Shared helpers (two or more features use them) | `src/<package>/lib/<topic>.py` | the topic |
| Config and environment | `src/<package>/config.py` | the one module that reads the environment |
| Tests | `tests/`, `conftest.py` | `tests/<domain>/test_<module>.py`, mirroring the package; the test name carries the criterion ID |
| Scripts | `scripts/` | verb and noun (`seed_db.py`) |

## Legacy

None.
