# Work packages — dependency and acceptance ledger

Status: `NOT_STARTED` · `IN_PROGRESS` · `BLOCKED` · `READY_FOR_REVIEW` · `VERIFIED` · `ACCEPTED` · `DEFERRED_WITH_REASON`.
Owner for all packages: the Arena agent (one coordinated workstream; no parallel agents, so no file-ownership conflicts).
`VERIFIED` = acceptance criteria met by automated evidence; `ACCEPTED` requires the founder.

| WP | Objective | Depends on | Status | Evidence |
|---|---|---|---|---|
| WP-0 | Environment, repo, licence, billing verification | — | VERIFIED | `docs/ENVIRONMENT_VERIFICATION.md` (billing usage Unknown: HTTP 403 → L-01) |
| WP-1 | Coucou reuse map + app foundation | WP-0 | VERIFIED | `docs/COUCOU_REUSE_MAP.md`; app builds natively (runs 38792443609, 38793640196) |
| WP-2 | Durable state, project boundaries, recovery, backup/export/import | WP-1 | VERIFIED | Store tests 14/14; native self-test (real disk, torn write, backup) |
| WP-3 | Provider-neutral cloud reasoning + spend controls | WP-2 | READY_FOR_REVIEW | Provider/budget tests pass with fixtures; **no live call** (L-05) |
| WP-4 | Executive planning, prioritization, task ownership | WP-2 | VERIFIED | Work + engine tests |
| WP-5 | Evidence, handoffs, verification, adaptive recovery, reliability | WP-2, WP-4 | VERIFIED | "agent says done vs GitHub" scenario; native self-test claim check |
| WP-6 | Tools and integrations (GitHub evidence, manual relay, files, action ledger) | WP-5 | READY_FOR_REVIEW | Fixture-tested; live GitHub needs token (L-07); email/social/browser deferred (L-09) |
| WP-7 | Security, resource control, observability, usability | WP-2..6 | READY_FOR_REVIEW | Policy/redaction/injection tests; 49.5 MB footprint; CPU on real hardware pending (L-12) |
| WP-8 | Regression, performance, backup, end-to-end workflow | WP-2..7 | VERIFIED | 83/83 tests in sandbox and natively; self-test 12/12 |
| WP-9 | Native macOS build + distributable candidate | WP-1, WP-8 | VERIFIED (build) | Ad-hoc-signed zip + SHA-256 from known commits; Mac runtime on founder hardware pending |
| WP-10 | Final delivery package | all | READY_FOR_REVIEW | `LUPY_STATUS.md`, guides, reports; PR for review (not merged) |

---

## WP-0 — Verification
- **Acceptance:** environment, repo, licence boundary, budget rules recorded before changes. **Met.**
- **Result:** sandbox capabilities, repo access, Coucou licence split (MIT code vs reserved assets), billing docs; billing usage unreadable (403).
- **Commits:** `028bc75`.

## WP-1 — Reuse map and foundation
- **Areas:** `docs/COUCOU_REUSE_MAP.md`, `App/project.yml`, `App/Sources/Theme.swift`, `Island.swift`, `LupyCharacter.swift`, `Platform.swift`.
- **Acceptance:** documented reuse/modify/replace; no reserved assets; app builds. **Met** (first native build succeeded).
- **Limitations:** notch layout untested (L-13); Swift 5 mode for the shell (L-14).
- **Commits:** `eda0a7f`, `3747b84`.

## WP-2 — Durable state
- **Acceptance:** survives quit/crash/restart; no silent loss; idempotent; backup/restore/export/import; project isolation. **Met.**
- **Tests:** Store suite (torn write, disk failure, corruption, snapshot crash, rotation crash, idempotency across restarts, migration, backup tamper, project export isolation) + native self-test on real disk.
- **Commits:** `028bc75`, `ed2d140`.

## WP-3 — Providers and spend
- **Acceptance:** provider-neutral adapters, Keychain keys, ceilings, usage ledger, bounded retries, global pause, data-sent notice. **Met in tests; live call pending.**
- **Tests:** request shapes and parsing for 4 API styles, error taxonomy, routing to approved providers only, budget guard, usage exactly once, retries/fallback/offline fallback, JSON repair.
- **Limitations:** L-05, L-06, L-19.

## WP-4 — Planning and ownership
- **Acceptance:** goal → plan with dependencies/criteria; explainable priority; lifecycle with distinct sent/delivered/acknowledged/submitted/verified/accepted states; pause/resume/cancel. **Met.**

## WP-5 — Assurance
- **Acceptance:** claims never verify; delivery unconfirmed when unobservable; ambiguous ≠ contradicted; stale evidence; escalation; task-specific reliability not affecting permissions. **Met.**

## WP-6 — Integrations
- **Acceptance:** honest connector status; direct API first; manual fallback. **Met for GitHub (read-only, fixtures), manual relay, local file action with read-back.** Email/social/browser deferred with reason (L-09, `docs/EXECUTION_STRATEGY.md`).

## WP-7 — Security and resources
- **Acceptance:** approvals in code, scoped expiring permissions, injection defense, secrets hygiene, low footprint, diagnostics. **Met except real-hardware CPU confirmation (L-12).**

## WP-8 — Regression
- **Result:** 83 cases / 515 checks pass in sandbox and natively; native self-test 12/12; launch smoke OK.

## WP-9 — Native build
- **Result:** builds from known commits with checksums (see `LUPY_STATUS.md` for the current candidate). Not notarized (L-04).

## WP-10 — Delivery package
- `LUPY_STATUS.md`, `docs/INSTALL_GUIDE.md`, `docs/MAC_ACCEPTANCE_CHECKLIST.md`, `docs/TEST_REPORT.md`, `docs/REQUIREMENTS_STATUS.md, `docs/PERFORMANCE.md`, `docs/KNOWN_LIMITATIONS.md`, `docs/CI_BUDGET.md`, `docs/EXECUTION_STRATEGY.md`, `docs/ARCHITECTURE.md`; pull request (draft, not merged).
