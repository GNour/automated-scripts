<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# `weekly-summary` — weekly ops & cost digest (T1)

**Parent:** doc 16 · **Depends on:** task-01, task-08

## Routing

**Runtime:** codex
<!-- Codex: well-scoped single Python CLI. Follow repo AGENTS.md conventions. -->

## Files / areas

- `python/src/scripts/weekly_summary.py` + `manifest.yaml` entry
  (`weekly_summary`, tier t1)

## Acceptance criteria (this task's slice)

- [ ] Reports the week's deploys (from `coolify-status`/Coolify), completed
      Multica issues (multica CLI), and AI/API cost trend (reuse `usage-report`
      output if present) — as JSON. Read-only (T1).
- [ ] Sources optional/degrading; typed, ruff/mypy clean, pytest with sources
      mocked.
- [ ] `manifest.yaml` entry added.

## Notes

Runs on a weekly cron via Hermes (doc 07). Quality & Review, security-auditor
mandatory.
