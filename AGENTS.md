# Scripts Repo Agent Handbook

## Project

This repository is the reviewed shell + Python toolkit that Hermes uses for VPS operations, infrastructure checks, subscription reporting, and other named ops workflows. Hermes consumes only curated manifest entries through fixed-argv tools; Multica agents build and review the scripts here.

## Team

```yaml
stack: shell + python
runtimes: claude-code, codex
agents: shell-engineer, python-engineer, devops-engineer
```

Shared review roles are always available. Because these scripts can run on the host, every PR requires Quality & Review, including security-auditor review.

## Commands

- Python setup: `cd python && uv sync`
- Python tests: `cd python && uv run pytest`
- Python lint: `cd python && uv run ruff check .`
- Python types: `cd python && uv run mypy src`
- Shell lint: run `shellcheck` on changed shell scripts when shell code is added

## Rules

- NEVER commit to main. Branch `feat/<issue>` or `fix/<issue>`, open a PR.
- NEVER touch `.env*` or commit secrets, tokens, host credentials, account data, or private subscription details.
- Hermes gets named tools only: no open shell, no user-composed command lines, no unchecked argv passthrough.
- Manifest entries are the repo-to-plugin contract and must be reviewed with the script they expose.
- Mutations must be T3, default to `--dry-run`, require an explicit `--yes`, and print the planned action before execution.
- Every script writes machine-readable JSON to stdout. Human-readable diagnostics may go to stderr.
- Validate all external input at the boundary before use. Prefer explicit parsing and typed models for Python.
- Keep diffs focused. Add tests with the code that changes behavior.

## Definition of done

- Acceptance criteria met and the relevant tests ship in the same commit.
- `cd python && uv run pytest` passes for Python changes.
- `cd python && uv run ruff check .` passes for Python changes.
- `cd python && uv run mypy src` passes for Python changes.
- Shell changes pass `shellcheck` where applicable.
- PR describes what changed, why it changed, and the verification evidence.

## Conventions for Codex-routed work

- Bash scripts use strict mode: `set -euo pipefail`; set `IFS` defensively when iterating over shell-split input.
- Bash scripts keep shared helpers in `shell/lib/` and source them by repo-relative path.
- CLIs must support `--help`; mutating commands must default to `--dry-run` and require `--yes` for execution.
- JSON is the stdout contract. Emit one JSON document and keep prose, progress, and warnings on stderr.
- Python code lives in `python/src/`, is typed, and stays ruff + mypy clean.
- Python CLIs validate config, files, argv, and environment at the boundary; do not pass raw external input deeper into the program.
- Tests cover the happy path and the main failure path for each new behavior.
- No secrets in code, tests, fixtures, examples, logs, or comments. Example config uses placeholders only.

## Architecture notes

- `manifest.yaml` lists exposed tools and maps each tool name to a script path, tier, language, and fixed argv.
- `shell/` contains bash/POSIX scripts and `shell/lib/` shared helpers.
- `python/` is a uv-managed Python project using a `src/` layout for typed CLIs.
- `config/subscriptions.yaml.example` documents non-secret subscription metadata shape only.
- `tests/` is reserved for cross-language and integration-style tests; `python/tests/` holds Python project tests.

## Critical flows

- T1 report tools return JSON without mutation or confirmation.
- T3 mutation tools show the exact planned action, dry-run by default, and execute only after Hermes echo-and-confirm passes `--yes`.
- The ops Hermes profile may call exposed tools; family profiles must not receive the ops scripts plugin.
