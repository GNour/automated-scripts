<!-- [task] — child of doc 16. One task = one agent session = one PR (doc 04 §1.2). -->

# Scaffold the scripts repo (layout, Team block, manifest)

**Parent:** doc 16 · **Depends on:** none (do this first, alone)

## Routing

**Runtime:** claude-code
Use the **python-engineer** subagent.

## Files / areas

- `~/projects/scripts/` root: `AGENTS.md` (+ `CLAUDE.md` = `@AGENTS.md`),
  `manifest.yaml`, `shell/`, `python/` (uv project, `src/` layout),
  `config/subscriptions.yaml.example`, `tests/`, `README.md`.

## Acceptance criteria (this task's slice)

- [ ] Repo layout per doc 16 §2; `python/` is a uv project (ruff + mypy + pytest
      wired), `shell/` has a `lib/` for shared bash helpers.
- [ ] `AGENTS.md` carries the **Team block** (doc 16 §5.2: `stack: shell +
      python`, `runtimes: claude-code, codex`, `agents: shell-engineer,
      python-engineer, devops-engineer`) **and** the filled "Conventions for
      Codex-routed work" skill-mirror (doc 09 §4.4) — strict-mode bash, JSON
      output, `--dry-run` default for mutations, no secrets.
- [ ] `manifest.yaml` schema defined (per doc 16 §4: `name` → script path +
      `tier: t1|t3`); empty/example entries documented.
- [ ] `subscriptions.yaml.example` shows the schema (name, renewal date, monthly
      cost, currency) — **no real data, no secrets** (doc 16 §3).
- [ ] `README.md` explains the repo↔plugin contract and the conventions.

## Notes

This unblocks every other task — the Codex tasks (04–06, 12, 14) depend on the
skill-mirror written here. No scripts yet; structure only. Definition of done:
ruff/mypy clean on the empty project, repo branch-protected, PR reviewed by
Quality & Review.
