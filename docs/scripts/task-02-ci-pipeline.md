<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# CI pipeline — shellcheck + ruff/mypy/pytest

**Parent:** doc 16 · **Depends on:** task-01

## Routing

**Runtime:** claude-code
Use the **devops-engineer** subagent.

## Files / areas

- `.github/workflows/ci.yml`

## Acceptance criteria (this task's slice)

- [ ] One workflow: install (cached uv) → `shellcheck` over `shell/**` →
      `ruff check` + `mypy` + `pytest` over `python/`. Fails fast (`ci-pipelines`).
- [ ] Pinned action versions; no secrets in logs; runs on PRs to `main`.
- [ ] Branch protection on `main` requires the workflow green (doc 04 §3) —
      documented in the PR if it can't be set from code.

## Notes

Keep it lean — this is the gate that lets the Codex tasks (04–06, 12, 14) be
trusted. PR reviewed by Quality & Review.
