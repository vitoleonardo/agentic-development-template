---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
---

# Python

- Dependencies and commands go through uv: `uv add`, `uv run`. Never `pip install` into the environment, and never edit `uv.lock` by hand.
- Type hints on every public function. The typechecker in `.claude/kit.conf` must pass; do not silence it with `# type: ignore` without a comment that says why.
- Validate external input with the project's schema library (pydantic or the one already in use) at the boundary, not deep inside.
- Tests use pytest fixtures from `conftest.py` instead of setup code repeated in each test. Where they live: `structure.md`.
- Mock at the boundaries: HTTP with `respx` or the project's existing helper, time with a fixed clock, external services with fakes. Never mock the module under test.
- No bare `except:` or `except Exception: pass`. Catch what you can handle, or re-raise with context.
