<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# `subs-report` — subscription renewals & spend (T1) + schema

**Parent:** doc 16 · **Depends on:** task-01

## Routing

**Runtime:** claude-code
Use the **python-engineer** subagent.
<!-- claude-code: defines the subscriptions.yaml schema (a little design). -->

## Files / areas

- `python/src/scripts/subs_report.py`, `config/subscriptions.yaml.example`
  (finalize schema) + `manifest.yaml` entry (`subs_report`, tier t1)

## Acceptance criteria (this task's slice)

- [ ] Reads `config/subscriptions.yaml` (name, renewal date, billing cycle,
      monthly cost, currency); reports **upcoming renewals** (next 30 days) +
      **total monthly spend** as JSON. Read-only (T1).
- [ ] Schema validated (typed, clear error on a malformed entry); **no secrets**
      in the config — renewal metadata only (doc 16 §3, §8).
- [ ] Typed, ruff/mypy clean, pytest over a fixture `subscriptions.yaml`.
- [ ] `manifest.yaml` entry added.

## Notes

Subscriptions = VPS, domains, APIs you pay for (not credentials). Feeds the
morning briefing (task-13). Quality & Review, security-auditor mandatory.
