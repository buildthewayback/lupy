# Work packages — dependency and acceptance ledger

Status: `NOT_STARTED` · `IN_PROGRESS` · `BLOCKED` · `READY_FOR_REVIEW` · `VERIFIED` · `ACCEPTED` · `DEFERRED_WITH_REASON`.
Owner for all packages in this session: Arena agent (single coordinated workstream, no parallel agents → no file-ownership conflicts).

| WP | Objective | Depends on | Status | Evidence / notes |
|---|---|---|---|---|
| WP-0 | Environment, repo, licence, billing verification | — | VERIFIED | `docs/ENVIRONMENT_VERIFICATION.md` (billing usage itself Unknown: HTTP 403) |
| WP-1 | Coucou reuse map + app foundation | WP-0 | IN_PROGRESS | `docs/COUCOU_REUSE_MAP.md`, `docs/DECISIONS.md` |
| WP-2 | Durable state, project boundaries, recovery, backup/export/import | WP-1 | NOT_STARTED | |
| WP-3 | Provider-neutral cloud reasoning + spend controls | WP-2 | NOT_STARTED | |
| WP-4 | Executive planning, prioritization, task ownership | WP-2 | NOT_STARTED | |
| WP-5 | Evidence, handoffs, verification, adaptive recovery, reliability | WP-2, WP-4 | NOT_STARTED | |
| WP-6 | Tools and external integrations (GitHub evidence, manual relay, files) | WP-5 | NOT_STARTED | |
| WP-7 | Security, resource control, observability, usability | WP-2..6 | NOT_STARTED | |
| WP-8 | Regression, performance, backup, end-to-end workflow | WP-2..7 | NOT_STARTED | |
| WP-9 | Native macOS build + distributable candidate | WP-1, WP-8 | NOT_STARTED | |
| WP-10 | Final delivery package | all | NOT_STARTED | |

Per-package detail (objective, touched areas, acceptance criteria, tests, results, limitations,
commits) is appended below as each package progresses.
