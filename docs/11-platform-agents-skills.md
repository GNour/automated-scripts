# 11 — Platform Engineer Agents & Skills Catalog

**Goal:** the platform engineers — seven stack engineers (§1–7) plus a shell/automation engineer (§7.5) — each with its own skills catalog, and the verification reality of running them from a Linux VPS. Companion to doc 09 (which defines the pipeline, shared roles, and the Team-block selection mechanism).

**Conventions for all:**
- Agent file: `~/.claude/agents/<name>.md`, `tools: full` unless noted, `model: inherit`.
- All inherit the common header (CLAUDE.md compliance, small diffs, tests with code, branch+PR, stop-and-ask when blocked).
- Skills live in `~/.claude/skills/<skill>/`; each ≤150 lines; built/refined the doc-09 way — every repeated correction becomes a skill line. The lists below are the **starter catalog**: create the ⭐ ones on day one of using that agent; add the rest as the projects demand.
- A skill marked *(shared)* is written once and loaded by several agents.
- **Token posture (doc 13 §7 canonical; doc 09 §4.2 tables the shared/management roles):** all platform engineers default to `model: inherit` (→ `sonnet` on Max/API), `effort: medium`, `maxTurns: 30` — coding is many small steps and sonnet handles code well; escalate to `opus`/`effort: high` only on a genuinely complex task. Preload only ⭐ skills (the `skills:` field injects full content every run); pull the rest on-demand via the Skill tool.

---

## 0. The verification matrix (read first — it shapes every definition of done)

The VPS is Linux. What an agent can *prove* before opening a PR differs by platform, and each agent's skills encode its honest definition of done:

| Platform | Build on VPS | Tests on VPS | Full verification path |
|---|---|---|---|
| Laravel / Node / Python | ✅ | ✅ (+ Playwright E2E) | entirely on-server |
| React / Next.js | ✅ | ✅ (+ Playwright) | entirely on-server |
| React Native | JS layer ✅ | unit/JS ✅ | native binaries via **EAS Build** (Expo cloud); device testing manual/cloud |
| Android | ⚠️ possible (Gradle on Linux) but RAM-hungry on a shared 12 GB box | unit ✅; instrumented ❌ (emulator impractical here) | **GitHub Actions** Linux runners for builds; emulator tests in CI |
| iOS | ❌ impossible (Xcode/macOS only) | ❌ XCTest needs macOS | **GitHub Actions macOS runners** or **Xcode Cloud** (check current free-tier minutes) |

**Design consequence:** mobile agents' "done" = *code complete + unit tests green locally + cloud build pipeline green* — never "ran on device." The devops-engineer owns the CI pipelines that make this checkable; treat that as a prerequisite task the tech-lead schedules before the first mobile feature task.

---

## 1. laravel-backend-engineer

**Mandate:** Laravel server-side end to end — migrations → models → services/actions → form requests → controllers → routes — plus queues, scheduling, notifications, APIs. PHP 8.4, Pest tests mandatory.

| Skill | Purpose |
|---|---|
| ⭐ `laravel-feature` | The build order, thin-controller/action-class conventions, definition of done (already drafted in doc 09 §5) |
| ⭐ `db-migration-safety` *(shared with node/python)* | Additive-first migrations, rollback-tested, zero-downtime patterns, never destructive without an explicit task |
| ⭐ `pest-testing` | Factories, feature vs unit tests, HTTP assertions, database truncation strategy |
| `api-conventions` | REST resource design, API Resources/transformers, versioning, pagination, error envelope |
| `eloquent-performance` | N+1 detection, eager loading, chunking, indexes — with the read-only MySQL MCP as its measuring tool |
| `queues-and-jobs` | Job idempotency, retries/backoff, failure handling, when to queue vs inline |
| `laravel-security` | Policies/gates, form-request validation as the only input path, mass-assignment guards, file-upload handling |
| `multitenancy-patterns` | (when a SaaS project declares it) scoping, tenant isolation testing |

## 2. node-backend-engineer

**Mandate:** TypeScript-first Node services — APIs, webhooks, workers, integrations (the natural stack for Telegram/automation glue). Framework per repo's CLAUDE.md (Express/Fastify/Nest).

| Skill | Purpose |
|---|---|
| ⭐ `node-service-structure` | Layered layout (routes→handlers→services→data), config, graceful shutdown, health endpoint |
| ⭐ `typescript-strictness` *(shared with web/RN)* | strict tsconfig, types at boundaries, no `any` escapes, zod parsing for all external input |
| ⭐ `node-testing` | Vitest + supertest patterns, test doubles, contract tests for integrations |
| `async-correctness` | Promise hygiene, error propagation, timeouts/AbortController, queue/backpressure basics |
| `node-db-access` | Prisma/Drizzle conventions, migration discipline (pairs with `db-migration-safety`), transactions |
| `api-conventions-node` | OpenAPI-first routes, validation middleware, error envelope consistent with the Laravel one |
| `node-security` | helmet/rate-limit defaults, secret handling, SSRF/injection awareness in integration code |

## 3. python-engineer

**Mandate:** Python services, automation scripts, CLI tools, data work — and **Hermes plugins** (this agent is how the dev team extends your orchestrator).

| Skill | Purpose |
|---|---|
| ⭐ `python-project-structure` | uv-managed projects, src layout, typing required, ruff+mypy clean as definition of done |
| ⭐ `hermes-plugin-dev` | The Hermes plugin API: tool plugins, image backends, config conventions, testing a plugin without a live gateway |
| ⭐ `pytest-conventions` | Fixtures, parametrize, tmp_path patterns, coverage expectations |
| `fastapi-patterns` | (when a repo declares FastAPI) pydantic models, dependency injection, async endpoints |
| `cli-tools` | typer/argparse conventions, exit codes, --dry-run flags for anything destructive |
| `data-scripts` | pandas/ETL hygiene: idempotent runs, explicit dtypes, sample-validate-full pattern |
| `python-packaging` | Making scripts installable/reusable across the toolbox image Hermes execs in |

## 4. frontend-web-engineer (React / Next.js)

**Mandate:** React and Next.js apps — components, routing, data fetching, forms, styling — verified in a real browser via Playwright before any PR.

| Skill | Purpose |
|---|---|
| ⭐ `react-component-patterns` | Composition over props-drilling, hooks rules, state placement (local vs server-state vs URL) |
| ⭐ `nextjs-conventions` | App Router, server vs client components, data fetching/caching, route handlers |
| ⭐ `playwright-verify` *(shared with qa)* | Self-verification protocol: spin dev server, walk the acceptance criteria in-browser, attach evidence to PR |
| `styling-system` | Tailwind conventions, design tokens, dark mode, no ad-hoc CSS |
| `forms-and-validation` | react-hook-form + zod, optimistic UI, error display patterns |
| `api-integration` | Typed clients against the backend's OpenAPI/error envelope, TanStack Query caching |
| `web-accessibility` | Semantic HTML, keyboard paths, ARIA only when needed — checked in Playwright runs |
| `web-performance` | Bundle discipline, image handling, Core Web Vitals basics |

## 5. hybrid-mobile-engineer (React Native)

**Mandate:** React Native apps via **Expo** (the workflow that makes mobile viable from a Linux box) — UI, navigation, device APIs, releases through EAS.

| Skill | Purpose |
|---|---|
| ⭐ `rn-expo-workflow` | Expo project conventions, **EAS Build/Submit/Update** as the build-and-ship path, the verification matrix's rules for "done" |
| ⭐ `rn-navigation` | react-navigation/expo-router stacks, deep links, auth-gated flows |
| ⭐ `mobile-ui-patterns` | Platform-adaptive components, safe areas, lists performance, loading/offline states |
| `rn-state-and-storage` | Server-state caching, AsyncStorage/SecureStore boundaries, offline-first basics |
| `rn-native-modules` | When JS isn't enough: choosing maintained native deps vs writing a module; config-plugin hygiene |
| `rn-testing` | Jest + RN Testing Library on-VPS; Maestro/Detox flows delegated to CI/cloud |
| `push-notifications` | Expo notifications end-to-end incl. backend trigger contract |
| `app-release` | Versioning, store metadata, signing via EAS, staged rollouts |

## 6. android-engineer

**Mandate:** Native Android — Kotlin, Jetpack Compose, modern app architecture. Writes code on the VPS; builds verified through CI (see matrix).

| Skill | Purpose |
|---|---|
| ⭐ `kotlin-conventions` | Idiomatic Kotlin, coroutines/Flow patterns, null-safety discipline |
| ⭐ `jetpack-compose-ui` | Composable structure, state hoisting, theming, previews as documentation |
| ⭐ `android-ci-builds` | The verification path: Gradle on GitHub Actions, build caching, unit tests in CI, artifact APK/AAB per PR |
| `android-architecture` | MVVM + Hilt, module boundaries, repository pattern |
| `android-data` | Room migrations, DataStore, encrypted storage for secrets |
| `android-testing` | JUnit/Turbine/Compose tests locally; instrumented tests only in CI emulators |
| `play-release` | AAB signing, Play Console tracks, staged rollout discipline |

## 7. ios-engineer

**Mandate:** Native iOS — Swift, SwiftUI, modern concurrency. **Writes and reasons on the VPS; never claims a build** — all compilation/tests via macOS CI (the matrix's hard rule).

| Skill | Purpose |
|---|---|
| ⭐ `swift-conventions` | Idiomatic Swift, async/await concurrency, value-type bias, error handling |
| ⭐ `swiftui-patterns` | View composition, state ownership (@State/@Observable), navigation, previews |
| ⭐ `ios-ci-builds` | The verification path: macOS runners or Xcode Cloud, XCTest in CI, signing handled in pipeline — "done" = CI green, explicitly never "ran locally" |
| `ios-architecture` | MVVM, dependency injection without frameworks, module boundaries |
| `ios-data` | SwiftData/CoreData decisions, Keychain for secrets, migration discipline |
| `ios-testing` | XCTest/XCUITest structure (executed in CI), snapshot-test pragmatics |
| `app-store-release` | TestFlight flow, App Store metadata, review-guideline awareness, staged release |

---

## 7.5 shell-engineer (automation & ops scripts)

**Mandate:** automation and operational shell scripts — bash/POSIX, cron jobs, glue, CI steps, maintenance tasks. Not a stack engineer; the "platform" is the shell. Verifies on the VPS (it's where scripts run). Codex-eligible (well-scoped, single-area — doc 09 §4.3).

| Skill | Purpose |
|---|---|
| ⭐ `shell-scripting` | Strict mode (`set -euo pipefail`), quoting, command/arg checks, idempotency, `--dry-run`-by-default for destructive actions, `shellcheck`-clean, usage header |

**Definition of done:** shellcheck clean, idempotent re-run, dry-run shown in the PR. Anything touching SSH/firewall/infra obeys the safety ordering (doc 01) and T3 confirm rules (doc 07) — never a lockout path, destructive ops echo + confirm.

## 8. Cross-platform consistency skills (shared library)

These are written once and listed in multiple agents' loads — they're what makes the org feel like *one* company across stacks:

| Skill | Loaded by | Purpose |
|---|---|---|
| `error-envelope` | laravel, node, python, web, RN | One error shape across every API and client |
| `db-migration-safety` | laravel, node, python | One migration discipline everywhere |
| `typescript-strictness` | node, web, RN | One TS standard |
| `playwright-verify` | web, qa | One browser-evidence protocol |
| `api-contract-first` | all backend + all clients | Backend publishes OpenAPI; clients generate types from it — the contract is the hand-off artifact between platform agents on multi-platform projects |

`api-contract-first` is the quiet keystone: when a project declares `laravel + react-native`, the tech-lead sequences "update OpenAPI contract" as its own task, and both platform agents build against it instead of guessing at each other's shapes.

## 9. Rollout guidance

1. **Today:** create `laravel-backend-engineer` fully (all ⭐ + `api-conventions`) — it serves your live project.
2. **With the Hermes build-out:** `python-engineer` + `hermes-plugin-dev` (the dev team starts extending the orchestrator).
3. **Per future project:** create the platform agent the repo's Team block declares, ⭐ skills only; let corrections grow the rest.
4. **Before any mobile project:** devops-engineer task to stand up the CI pipeline first (EAS / Actions / macOS runners) — the verification matrix is policy, and policy needs plumbing.

## 10. Validation

- [ ] Each created agent appears in `/agents` with the right tool limits.
- [ ] A repo's Team block correctly constrains the tech-lead's routing (test by declaring only one agent and submitting a cross-cutting issue — it must plan within the declared team or flag the gap).
- [ ] Mobile agents' PRs state CI status, never "tested on device/simulator".
- [ ] Shared skills exist once on disk (no per-agent copies drifting apart).

## 11. Reuse notes

- This catalog is your **service menu**: each platform agent = a line item you can sell ("we cover Laravel, Node, Python, web, RN, Android, iOS"). The skills are the quality system behind it.
- Per-client: agents stay generic; client-specific conventions go into *their* repos' CLAUDE.md + a thin client-conventions skill — same separation as doc 09 §9.
- The verification matrix doubles as honest client-facing scoping: native iOS work requires macOS CI minutes — a real cost line for the unit-economics sheet.
