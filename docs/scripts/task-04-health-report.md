<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# `health-report` — VPS host metrics (T1)

**Parent:** doc 16 · **Depends on:** task-01

## Routing

**Runtime:** codex
<!-- Codex: well-scoped single script (doc 09 §4.3). No subagent — follow the
     shell conventions in the repo AGENTS.md skill-mirror (task-01). -->

## Files / areas

- `shell/health-report.sh` + `manifest.yaml` entry (`vps_health`, tier t1)

## Acceptance criteria (this task's slice)

- [ ] Reports disk (`/`), RAM, CPU/load, uptime, and `systemctl is-active` for
      `hermes-ops`, `docker` — as **JSON on stdout** (doc 16 §2).
- [ ] Read-only (T1); no args from the caller; `set -euo pipefail`, quoted,
      `shellcheck`-clean (`shell-scripting`).
- [ ] Usage header comment; exits non-zero with a clear message if a probe fails.
- [ ] `manifest.yaml` entry added so `ops_scripts` can expose it.

## Notes

Generalizes doc 14 §9 `host_status` into the scripts library. PR reviewed by
Quality & Review (security-auditor mandatory).
