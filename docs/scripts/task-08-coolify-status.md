<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# `coolify-status` — app health across the server (T1)

**Parent:** doc 16 · **Depends on:** task-01

## Routing

**Runtime:** claude-code
Use the **devops-engineer** subagent.
<!-- claude-code: scoped Coolify token handling — establish the infra pattern here. -->

## Files / areas

- `python/src/scripts/coolify_status.py` + `manifest.yaml` entry
  (`coolify_status`, tier t1)

## Acceptance criteria (this task's slice)

- [ ] Lists each Coolify app with status (running/exited/unhealthy) + last deploy,
      as JSON. Read-only (T1).
- [ ] Uses the **scoped Coolify API token** from the env (doc 04 §5); never host
      admin creds; token never logged (`secrets-scan`).
- [ ] Typed, `ruff` + `mypy` clean, `pytest` with the API mocked (no live call in
      tests).
- [ ] `manifest.yaml` entry added.

## Notes

Establishes the Coolify-token pattern that task-09 reuses. Complements doc 14's
`coolify` plugin (this is the broader status view). PR reviewed by Quality &
Review (security-auditor mandatory — handles the Coolify token).
