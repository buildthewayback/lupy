# LUPY — Implementation Sequence, Work Packages and Release Gates

This document supports the authorized one-campaign build described in `ARENA_MASTER_BUILD_DIRECTIVE.md`. Work packages are internal coordination units, not reasons to stop for founder approval after every phase.

## Operating ledger

Maintain these files in the Lupy repository/branch:

- `LUPY_STATUS.md`: current overall status, current branch/commit, last verified build, top blockers, next three actions, artifact location.
- `WORK_LOG.md`: chronological entries with date/time, package, commit, tests, outcomes, evidence and decisions.
- `docs/WORK_PACKAGES.md`: package dependency/status ledger with owner and acceptance state.
- `docs/DECISIONS.md`: architecture/licensing/runtime decisions with rationale, status and reversibility.
- `docs/KNOWN_LIMITATIONS.md`: live integrations, permissions, packaging and platform gaps stated honestly.

Each item uses a compact status vocabulary: `NOT_STARTED`, `IN_PROGRESS`, `BLOCKED`, `READY_FOR_REVIEW`, `VERIFIED`, `ACCEPTED`, `DEFERRED_WITH_REASON`. Use `VERIFIED` only with supporting evidence.

## WP-0 — Environment, repository and license verification

**Work:** inspect actual Arena environment and connected GitHub access; check `git`, Swift/Xcode where applicable, Node/Python/test tooling, macOS runner access if exposed, CI billing/quota/visibility, repository permissions, Coucou current commit and license files. Confirm project/build/test commands from current source. Establish Lupy-owned source of truth, status log and dependency map.

**Acceptance:** report exact observed/tested/documented/unknown states; no secrets touched; no upstream Coucou modifications; repo/branch and current commit visible; license boundary documented. Continue coding once these facts are understood; do not spend the campaign only on assessment.

## WP-1 — Coucou reuse map and application foundation

**Work:** create Lupy codebase/branch; preserve required notices; identify reusable UI/view/state/provider/Keychain/approval/test components. Establish the Lupy app shell and build setup with minimal necessary dependencies. Keep a familiar Coucou interaction language and avoid gratuitous restyling. Add the minimum new Lupy navigation/status/approval/history patterns.

**Acceptance:** buildable source structure; licence notes; reuse/modify/replace matrix; smoke tests or platform-safe verification; no reserved assets included beyond verified permissions. Use a licensed/original placeholder only where an asset right is uncertain.

## WP-2 — Durable state, project boundaries and recovery

**Work:** define persisted schema and migrations; projects, tasks, preferences, decisions, evidence pointers, action log, permissions and integration/provider configuration. Choose simple portable local storage (e.g. SQLite plus readable exports) after checking the source. Implement startup recovery, migration/backups/export/import, idempotent event handling and error handling.

**Acceptance:** unit tests for schema, migration, restart persistence, corrupted/missing state behavior, import/export and duplicate-event prevention; sample fixtures contain no personal secrets; documented restore path.

## WP-3 — Provider-neutral cloud reasoning and spend controls

**Work:** implement one reliable API provider end-to-end first, then add other providers through an adapter interface where useful and feasible. Provide model/provider configuration, credential entry using Keychain, privacy/data-flow notice, errors/rate-limit handling, token/context bounds, per-task and global budgets, bounded retry/cancel, and visible usage/cost estimates where provider responses support them. No local LLM inference.

**Acceptance:** provider tests using mocks, one documented safe live smoke test only if an API key is configured by the founder outside Git, no secret leakage, provider switch does not reset task/memory/permission state, budget stops repeated calls correctly.

## WP-4 — Executive planning, prioritization and task ownership

**Work:** goal/request intake; split into actions/dependencies/checkpoints/acceptance criteria; priority based on urgency, consequence, value/income, strategy, dependency, effort, confidence, risk and compute/API budget; pause/resume/cancel/retarget; project-specific context; useful status view; notifications/reminders within realistic platform limits.

**Acceptance:** deterministic test cases for precedence and dependencies; restart preserves planned/in-progress state; blocked tasks do not prevent unrelated safe work; no noisy endless polling or unbounded model loops; user can inspect and correct important priorities.

## WP-5 — Evidence, handoffs, verification and adaptive recovery

**Work:** represent task lifecycle separately from worker narrative; handoff payload with scope, expected output, due/checkpoint, constraints, acceptance criteria and evidence requests. Track sent/delivery-unconfirmed/acknowledged/progress-evidenced/submitted/verified/accepted states as integration capability supports. Add evidence ledger with provenance and timestamp, review checklist, bounded retry, alternative route, recovery and human escalation. Start with rule-based task-specific reliability signals, not an opaque “trust score.”

**Acceptance:** tests prove that “agent says done” alone cannot pass verification; unobservable delivery stays unconfirmed; ambiguous evidence is distinct from contradicted evidence; recovery is bounded/idempotent; no trust score can override authorization; evidence references are retained across restart.

## WP-6 — Tools and external integrations

**Work:** inventory actual accessible APIs/connectors, browser control and agent channels; prefer direct supported API. Build adapters only for capabilities that can be tested in the current environment; otherwise supply a narrow interface, explicit unavailable/unconnected UI status and manual fallback. Do not claim Muse/Arena/Orin or generic computer control is connected unless real authorized communication and evidence are available. Safe browser session/profile boundaries and prompt-injection defense are mandatory where browser interaction is supported.

**Acceptance:** each claimed integration has an observed permission path, success/failure tests and evidence; mocked integrations are labeled; external actions require approval based on risk; no bypass of CAPTCHA/MFA; unrelated sessions aren’t closed/changed.

## WP-7 — Security, resource control, observability and usability

**Work:** policy enforcement outside LLM instructions, least-privilege access, secrets audit, untrusted-input handling, logs without secrets, settings/permissions screens, health/error messages understandable to a nontechnical user, bounded background work/concurrency, cancellation, crash recovery and diagnostic export with sensitive data excluded.

**Acceptance:** tests for prohibited actions/approval gates, permission expiry/scope, secret scanning, malformed model responses, provider outage, timeout, rate limiting, app restart, safe logging and resource controls. No hidden daemon or recurring poller without a clear reason and stop control.

## WP-8 — Regression, performance, backup and end-to-end workflow

**Work:** join UI/core/storage/provider/policy. Test representative journeys: create project → plan outcome → create dependencies → run authorized task → delegate with evidence requirements → accept output only after evidence → recover from tool failure → resume after restart → export backup → restore. Measure memory/CPU/startup/idle behavior where tools allow; avoid fabricated measurements.

**Acceptance:** automated tests pass in the verified environment; no unrelated feature regression; fail-fast on required checks; unresolved failures documented and fixed where possible. Real-Mac performance claims require measurements on the target Mac.

## WP-9 — Native macOS build and distributable candidate

**Work:** determine the lowest-cost honest build path. If Arena cannot compile native macOS code, test portable logic there and prepare a simple versioned build/packaging workflow. Use a standard macOS runner only when justified and with verified weighted-budget headroom; prefer one limited release/build validation run to repeated per-commit macOS jobs. Do not enable paid overage or public repo visibility without permission. Alternatively, prepare a founder-run build script that is short, safe, and nontechnical steps are documented; do not call the app installable until a binary is actually produced.

**Acceptance:** actual artifact (`.app` packaged in `.zip`, `.dmg`, or equivalent), version and source commit, SHA-256 checksum, launch/build evidence, install/update/uninstall instructions, exact macOS signing/notarization state, no embedded secrets. If the artifact cannot be built in Arena or CI, the report must say what exact single Mac step remains and must not invent a download.

## WP-10 — Final delivery package

**Required final package:**

1. Source branch/commit and PR (if GitHub connection supports it).
2. Native downloadable build candidate or a clear, fully prepared Mac build route if blocked by missing macOS execution.
3. Checksum, build provenance and version.
4. Plain-language install, first launch, cloud API setup, privacy/cost, update, backup/export/restore and uninstall guide.
5. Verified test report with command, environment, results and test coverage summary.
6. Functional matrix: working / mocked / needs credentials / needs macOS device test / blocked / deliberately deferred.
7. Known limitations and next most valuable improvements.
8. Actions budget usage and remaining verified allowance.

## CI budget and cadence

Before any Actions dispatch, inspect actual quota and settings. The baseline assumption is up to 2,000 included minutes per month, but the repository/account must confirm it. Use local/sandbox test first; Linux standard runners for portable checks; macOS runner only for native work that cannot be done elsewhere. GitHub’s published billing rates show macOS standard runners have a much higher per-minute rate than standard Linux, so treat available minute quota as weighted/billed usage, not wall-clock time. Preserve at least 30% of remaining quota for full integration/regression/release checks. Stop optional CI if 70% of monthly allowance has been used. Never enable overage without founder approval.

## Non-negotiable release gates

- The app does not run a local LLM.
- Secrets are not committed or logged.
- Worker messages alone never verify completion.
- Consequential actions remain approval-gated unless covered by narrow standing authorization.
- Tests are not weakened to make the pipeline green.
- Public release/main merge is not performed without founder approval.
- “Mac ready” means an actual macOS artifact and verified launch/install evidence, not just a Swift source tree or successful Linux tests.
