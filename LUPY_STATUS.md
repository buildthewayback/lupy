# LUPY_STATUS

_Last updated: 2026-10-15 18:25 UTC · branch `arena/48b1c2c3-lupy`_

## Where things stand (plain language)

Lupy is being built as a native Mac app with a tested "brain" (LupyCore) and a Coucou-style
notch interface. The brain's durable memory — the part that makes sure nothing is lost when the
Mac crashes or restarts — is built and passes all its tests. The planning, judgment, safety,
evidence and model-provider parts are next, then the Mac interface, then a real Mac build.

**No installable app exists yet.** Nothing has been built on a Mac yet. No GitHub Actions minutes
have been used.

## Status by gate

| Gate | State |
|---|---|
| Implemented | Core storage + recovery + backup/export (WP-2 part 1) |
| Sandbox-validated | 24/24 LupyCore tests (Swift 6.3.3 on WebAssembly, in the Arena sandbox) |
| Native-build-validated | Not yet |
| Installable artifact produced | Not yet |
| Mac runtime validated | Not yet |
| Founder accepted | Not yet |

## Work packages

| WP | Status |
|---|---|
| WP-0 Environment / licences / billing | VERIFIED (billing usage unreadable → conservative plan) |
| WP-1 Reuse map + foundation | IN_PROGRESS |
| WP-2 Durable state, recovery, backup | IN_PROGRESS (store, recovery, backup, project export done & tested) |
| WP-3 Providers + spend controls | NOT_STARTED |
| WP-4 Planning, priority, ownership | NOT_STARTED |
| WP-5 Evidence, handoffs, verification, reliability | NOT_STARTED |
| WP-6 Integrations | NOT_STARTED |
| WP-7 Security, resources, observability, usability | NOT_STARTED |
| WP-8 Regression / end-to-end | NOT_STARTED |
| WP-9 Native Mac build | NOT_STARTED |
| WP-10 Final package | NOT_STARTED |

## GitHub Actions usage

0 runs, 0 minutes used by this campaign. Account remaining minutes: **unknown** (billing API
returns 403 for this session). Plan: `docs/CI_BUDGET.md`.

## Blockers / founder decisions

None blocking. Optional: if you want Lupy to look *exactly* like Coucou's Mochi character, that
needs written permission from Coucou's author (Lupy uses its own original character instead).
