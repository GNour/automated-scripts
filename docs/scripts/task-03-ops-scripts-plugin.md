<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# `ops_scripts` Hermes plugin — manifest-driven named tools

**Parent:** doc 16 · **Depends on:** task-01

## Routing

**Runtime:** claude-code
Use the **python-engineer** subagent.

## Files / areas

- `hermes/plugins/ops_scripts/` in the **infra repo** (the Hermes plugin home,
  doc 05) — `plugin.yaml`, `register(ctx)`, `schemas.py`, `tools.py`, tests.

## Acceptance criteria (this task's slice)

- [ ] Reads `~/projects/scripts/manifest.yaml`; registers **one named tool per
      exposed script** with **fixed argv** — the model never composes a shell
      line (doc 14 §11, doc 16 §4).
- [ ] **T1** tools run on request; **T3** tools echo the exact action + target
      and require a `confirm` before running (doc 07 §8). Tier read from manifest.
- [ ] Host subprocess (not the mount-less Docker sandbox, doc 14 §4); always
      returns a JSON string, never raises (repo plugin contract, doc 14 §4).
- [ ] Ops profile only; **family profile cannot load it** (assert in
      `hermes/tests/test_profiles.py`).
- [ ] Tested **without a live gateway** (`hermes-plugin-dev`): `uv run pytest &&
      uv run ruff check`.

## Notes

This is the run-side bridge. It complements doc 14's `coolify`/`host_status`/
`file_search` plugins — does not replace them. Secrets come from the ops env,
never from the model. PR reviewed by Quality & Review (security-auditor
mandatory — this is the privilege boundary).
