<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# `ansible-drift` — detect config drift via --check (T1)

**Parent:** doc 16 · **Depends on:** task-01

## Routing

**Runtime:** claude-code
Use the **devops-engineer** subagent.

## Files / areas

- `shell/ansible-drift.sh` + `manifest.yaml` entry (`ansible_drift`, tier t1)

## Acceptance criteria (this task's slice)

- [ ] Runs the infra playbook in **check mode** (`ansible-playbook --check
      --diff`) against the inventory and reports the count + summary of would-
      change tasks as JSON. **Read-only — `--check` never mutates** (doc 01).
- [ ] Paths to playbook/inventory from env; `set -euo pipefail`, `shellcheck`-clean.
- [ ] Safe to run repeatedly; clear message if ansible/inventory is absent.
- [ ] `manifest.yaml` entry added.

## Notes

Surfaces "has the server drifted from the Ansible toolkit?" for the briefing.
`--check` is the safety guarantee — confirm it in the PR. Quality & Review,
security-auditor mandatory.
