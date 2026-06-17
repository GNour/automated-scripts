# Automated Scripts

This repository is the versioned scripts library for Hermes ops workflows. Multica agents build and review the shell and Python tools here; Hermes consumes only reviewed entries exposed through `manifest.yaml`.

## Repo and Plugin Contract

`manifest.yaml` is the contract between this repo and the Hermes `ops_scripts` plugin. Each manifest entry gives Hermes a named tool with fixed argv, a script path, and a tier:

- `t1` tools are read-only reports and return JSON without confirmation.
- `t3` tools may mutate host state, default to `--dry-run`, and execute only after Hermes echo-and-confirm passes an explicit `--yes`.

Hermes must never receive a generic shell runner or model-composed command line. Add a script and its manifest entry in the same PR when a tool should become callable.

## Layout

- `AGENTS.md` is the canonical agent handbook; `CLAUDE.md` imports it.
- `manifest.yaml` maps named Hermes tools to reviewed script entrypoints.
- `shell/` is for shell scripts; shared bash helpers belong in `shell/lib/`.
- `python/` is a uv-managed Python project using `src/` layout, ruff, mypy, and pytest.
- `config/subscriptions.yaml.example` documents non-secret subscription metadata shape.
- `tests/` is reserved for cross-language and integration-style tests.

## Conventions

All scripts print one machine-readable JSON document to stdout. Diagnostics and human summaries go to stderr. External input is validated at the boundary. Secrets stay in the ops environment and must not be committed in code, tests, fixtures, examples, logs, or comments.

Mutating commands are read-only by default: provide `--dry-run` behavior and require `--yes` before changing host state. Manifest entries for mutating commands must use `tier: t3`.


## Hermes `ops_scripts` Plugin

`hermes/plugins/ops_scripts/` reads `/home/dev/projects/automated-scripts/manifest.yaml` at runtime and registers one named Hermes tool for each manifest entry. T1 tools run immediately with fixed argv. T3 tools return the exact action and target until Hermes calls them with `confirm=true`, then execute the reviewed fixed argv on the host.

The plugin is ops-profile only. Family profiles must not load `ops_scripts`.

## Python Checks

```bash
cd python
uv sync
uv run pytest
uv run ruff check .
uv run mypy src
```

## Shell Checks

When shell scripts are added, run `shellcheck` on changed scripts and keep shared logic in `shell/lib/`.
