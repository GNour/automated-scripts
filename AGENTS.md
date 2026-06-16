# AGENTS.md

<!-- The CANONICAL handbook for application repos (docs 04 §7.3, 09 §4.1).
     Copy to the app repo root as AGENTS.md and fill every <placeholder>;
     pair it with app-repo-CLAUDE.md (a one-line import) so Claude Code
     reads the same truth Codex does. Keep under ~100 lines — long content
     belongs in skills (doc 10 §3.2). Delete these comments. -->

## Project

<one paragraph: what this app is, who uses it, stack:
Laravel 12 / PHP 8.4 / MySQL / Vite>

## Team

```yaml
stack: shell + python                       
runtimes: claude-code, codex                
agents: shell-engineer, python-engineer, devops-engineer
```

## Commands

- setup: `composer install && npm ci`
- test: `php artisan test`            # run before every commit
- lint: `./vendor/bin/pint`
- build: `npm run build`

## Rules

- NEVER commit to main. Branch `feat/<issue>` or `fix/<issue>`, open a PR.
- NEVER touch `.env*` or commit secrets.
- Migrations: additive only unless the task explicitly says otherwise.
- Follow existing code style; small focused diffs; update tests with code.

## Definition of done (every task, every runtime)

- Acceptance criteria met; tests for the change ship in the same commit and
  pass — paste the evidence in the PR.
- Lint clean; build green where applicable.
- PR describes what + why with test evidence, readable from a phone.


## Conventions for Codex-routed work (the skill-mirror)

- Build order: <e.g. migration → model+factory → action/service → form
  request → thin controller → route → feature test → lint>
- Input & errors: <e.g. all external input validated at the boundary; error
  envelope shape `{ "error": { "code", "message" } }`>
- Tests: <what "complete" means — happy path + the main failure path>
- <add one line per Codex-eligible role's must-knows as they get routed>

## Architecture notes

<key directories, domain language, gotchas>

## Critical flows

<!-- The flows qa-engineer covers with E2E (e2e-critical-flows skill).
     List only flows whose breakage is a business incident. -->
- <e.g. login, checkout>
