---
name: python-best-practices
description: Python playbook for building or learning: project layout, uv, pytest, ruff, typing, common pitfalls. Use when asked how to structure, set up, test, lint or improve a Python project, or to explain Python practice.
---

Use only for Python. Answer from this, adapted to what the project already does.

## Layout
- `src/<package>/`, `tests/`, `pyproject.toml`, `uv.lock`. The `src` layout stops the in-development copy being imported by accident; a flat layout can import fine locally and fail once installed.

## Workflow
- `uv init`, `uv add <pkg>` (`--dev` for tools), `uv run pytest`, `uv lock --upgrade-package <name>`.
- Lint and format: `ruff check --fix` then `ruff format`; in CI use `ruff check` and `ruff format --check`.

## Testing (pytest)
- Put pytest in a dev dependency group and install the project in editable mode.
- For new projects use `--import-mode=importlib` (the default `prepend` mode needs unique test file names); set `strict = true` and `pythonpath = ["src"]` in the pytest config.
- Name files `test_*.py`; one behaviour per test; fixtures over repeated setup.

## Typing
- Annotate public APIs; run a type checker, because hints are not enforced at runtime.

## Pitfalls
- Using system `pip`; running tests via `setup.py test`; lint rules that fight the formatter (COM812, W191); `ruff --unsafe-fixes` changing behaviour; mutable default arguments; bare `except:`.

Sources: PEP 8, ruff linter and formatter docs, pytest good practices, Python Packaging guide (src vs flat layout), uv projects guide, Python typing docs.
<!-- managed by claude-code-setup -->
