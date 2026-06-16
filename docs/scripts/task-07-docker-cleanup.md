<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# `docker-cleanup` — prune dangling images/volumes (**T3**)

**Parent:** doc 16 · **Depends on:** task-01

## Routing

**Runtime:** claude-code
Use the **shell-engineer** subagent.
<!-- claude-code: it's a T3 mutation — route to Claude for care, not Codex. -->

## Files / areas

- `shell/docker-cleanup.sh` + `manifest.yaml` entry (`docker_cleanup`, tier t3)

## Acceptance criteria (this task's slice)

- [ ] Prunes **dangling** images + unused volumes/build cache — never running
      containers or in-use volumes. Targets are conservative and explicit.
- [ ] **`--dry-run` is the default**: prints exactly what WOULD be removed (+
      reclaimable space) as JSON and exits 0. Requires explicit `--yes` to act.
- [ ] `set -euo pipefail`, `shellcheck`-clean, usage header.
- [ ] `manifest.yaml` entry **tier t3** so `ops_scripts` enforces echo-and-confirm
      (doc 07 §8, doc 16 §4).

## Notes

The mutation contract is the point of this task — verify the dry-run/`--yes`
split in the PR. PR reviewed by Quality & Review (security-auditor mandatory).
