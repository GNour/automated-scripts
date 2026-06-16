<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# `usage-report` — AI/API usage & spend (T1)

**Parent:** doc 16 · **Depends on:** task-01

## Routing

**Runtime:** codex
<!-- Codex: well-scoped single Python CLI. Follow repo AGENTS.md conventions. -->

## Files / areas

- `python/src/scripts/usage_report.py` + `manifest.yaml` entry (`usage_report`,
  tier t1)

## Acceptance criteria (this task's slice)

- [ ] Reports the Claude Pro pool usage via **`ccusage`** (doc 10 §1.3) and, if
      keys are present in the env, OpenRouter + FAL spend via their APIs — as JSON.
      Read-only (T1).
- [ ] Each source is **optional**: a missing key/tool degrades to
      `"<source>": "unavailable"`, never an error.
- [ ] API keys from env only, never logged (`secrets-scan`); typed, ruff/mypy
      clean, pytest with sources mocked.
- [ ] `manifest.yaml` entry added.

## Notes

Gives "what am I spending on AI?" at a glance and feeds the weekly summary
(task-14). Quality & Review, security-auditor mandatory (reads API keys).
