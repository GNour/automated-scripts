<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# `cert-expiry` — TLS certificate expiry (T1)

**Parent:** doc 16 · **Depends on:** task-01

## Routing

**Runtime:** codex
<!-- Codex: well-scoped single script. Follow repo AGENTS.md shell conventions. -->

## Files / areas

- `shell/cert-expiry.sh` + `manifest.yaml` entry (`cert_expiry`, tier t1)

## Acceptance criteria (this task's slice)

- [ ] For each configured domain (env `CERT_DOMAINS`, space/comma list), reports
      days until the TLS cert expires, as JSON; flags any with `days < 14`.
- [ ] Read-only (T1); uses `openssl s_client` (or reads Traefik's ACME store if
      preferred) with a fixed flag set; no caller args beyond the env list.
- [ ] `set -euo pipefail`, `shellcheck`-clean, usage header, timeout per host.
- [ ] `manifest.yaml` entry added.

## Notes

Feeds the morning briefing (task-13). PR reviewed by Quality & Review
(security-auditor mandatory).
