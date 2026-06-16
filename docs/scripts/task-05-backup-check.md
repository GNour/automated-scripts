<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# `backup-check` — verify the last restic→B2 backup (T1)

**Parent:** doc 16 · **Depends on:** task-01

## Routing

**Runtime:** codex
<!-- Codex: well-scoped single script. Follow repo AGENTS.md shell conventions. -->

## Files / areas

- `shell/backup-check.sh` + `manifest.yaml` entry (`backup_check`, tier t1)

## Acceptance criteria (this task's slice)

- [ ] Reports last restic snapshot time + age (hours) + repo health, as JSON
      (doc 08 restic→B2). Flags `stale: true` if older than a threshold (env,
      default 26h).
- [ ] Read-only (T1); restic repo creds read from the **env** only (never
      hardcoded, never logged — `secrets-scan`).
- [ ] `set -euo pipefail`, `shellcheck`-clean, usage header.
- [ ] `manifest.yaml` entry added.

## Notes

Powers a "did my backup run?" check and the morning briefing (task-13). PR
reviewed by Quality & Review (security-auditor mandatory — touches backup creds).
