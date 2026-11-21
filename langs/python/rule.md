---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
---

# Python guardrails
The project's own config (pyproject.toml, ruff settings, CI) wins over these. For a fuller guide, use the python-best-practices skill.
- After editing: `ruff check --fix` (safe fixes only; do not pass `--unsafe-fixes` without saying so), then `ruff format`. Verify with `ruff check` and `ruff format --check`.
- Imports at the top, one per line, grouped stdlib / third-party / local, sorted; never `import *`.
- `is None` / `is not None`, never `== None` or `== True`. No bare `except:`: catch the specific exception, and keep `try` blocks small.
- Names: snake_case functions and variables, CapWords classes, UPPER_CASE constants. Follow the project's configured line length.
- Annotate public functions and return values (`X | None` over `Optional[X]` on 3.10+; `object` over `Any`). Hints are not checked at runtime: run the project's type checker (mypy or pyright) if it has one.
- Environment: use `uv` (`uv add`, `uv run`), commit `uv.lock` and never hand-edit it. Never install into the system Python.
<!-- managed by claude-code-setup -->
