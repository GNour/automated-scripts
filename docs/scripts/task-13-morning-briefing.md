<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# `morning-briefing` — the W5 data aggregator (T1)

**Parent:** doc 16 · **Depends on:** task-04, task-08, task-11 (+ multica plugin)

## Routing

**Runtime:** claude-code
Use the **python-engineer** subagent.
<!-- claude-code: multi-source aggregation, planning-heavy (doc 09 §4.5). -->

## Files / areas

- `python/src/scripts/morning_briefing.py` + `manifest.yaml` entry
  (`morning_briefing`, tier t1)

## Acceptance criteria (this task's slice)

- [ ] Aggregates into **one JSON object**: host health (`health-report`), app
      health (`coolify-status`), open Multica PRs awaiting review (multica CLI),
      upcoming subscription renewals (`subs-report`), cert warnings (`cert-expiry`).
- [ ] Each source is **independent + optional** — one failing source yields a
      `null`/`"unavailable"` field, never a failed briefing. Read-only (T1).
- [ ] Typed, ruff/mypy clean, pytest with each source mocked.
- [ ] `manifest.yaml` entry added; output shape documented (it's the W5 contract,
      doc 07 §3).

## Notes

This is the keystone — Hermes calls one tool to assemble your morning report.
Build after its sources exist. Quality & Review, security-auditor mandatory.
