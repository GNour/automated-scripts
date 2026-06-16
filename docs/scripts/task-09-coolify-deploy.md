<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# `coolify-deploy` — trigger an app deploy (**T3**)

**Parent:** doc 16 · **Depends on:** task-01, task-08

## Routing

**Runtime:** claude-code
Use the **devops-engineer** subagent.

## Files / areas

- `python/src/scripts/coolify_deploy.py` + `manifest.yaml` entry
  (`coolify_deploy`, tier t3)

## Acceptance criteria (this task's slice)

- [ ] Triggers a deploy for a **named** app (arg validated against the app list
      from `coolify_status`); refuses an unknown app.
- [ ] **`--dry-run` default**: prints the exact app + action it WOULD trigger as
      JSON; requires explicit `--yes` to fire.
- [ ] Scoped Coolify token from env; typed, ruff/mypy clean, pytest with the API
      mocked.
- [ ] `manifest.yaml` entry **tier t3** → `ops_scripts` echoes the target app and
      waits for `confirm` (doc 07 §8).

## Notes

Reuses the token pattern from task-08. The echo-and-confirm + dry-run is the
deliverable's core — verify in the PR. Quality & Review, security-auditor
mandatory.
