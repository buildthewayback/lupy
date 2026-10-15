# GitHub Actions budget plan and usage ledger

## Facts (see ENVIRONMENT_VERIFICATION.md)

- Billing usage for this account is **not readable** with the session token (HTTP 403). Remaining
  minutes are therefore **unknown**. Per the directive, conservative estimates are used.
- Documented: GitHub Free = 2,000 included minutes/month; macOS minutes cost $0.062 vs $0.006 for
  Linux, so for budgeting **1 macOS minute ≈ 10.3 Linux-equivalent minutes**. 2,000 included
  minutes ≈ **194 macOS minutes** at most.
- Thresholds: stop-and-review at 70 % of the allowance (1,400 Linux-eq min); keep ≥ 30 % in reserve.

## Rules this campaign follows

1. All portable tests (LupyCore: state, policy, verification, planning, providers, recovery…) run
   **inside the Arena sandbox** using the Swift-on-WebAssembly compiler — **0 Actions minutes**.
2. No Linux CI workflow is run routinely (the sandbox runs the same suite).
3. The only workflow is `mac-build.yml` (macOS): it runs **only** when a commit changes
   `ci/mac-build-request.txt` or when started manually from the Actions tab. Other pushes do not
   start it. (Changed after the 18:26 incident; commit text no longer matters.)
4. `timeout-minutes: 25` caps the worst case at ≈ 258 Linux-eq minutes (12.9 %) per run.
5. `concurrency` with `cancel-in-progress: true` prevents overlapping runs. The agent token cannot
   call the cancel API (HTTP 403), so concurrency is the only cancellation lever.
6. Target: ≤ 4 macOS runs in this campaign (expected 4–7 min each ⇒ ≈ 40–75 Linux-eq each).
   Actual: 4 runs (1 accidental, 3 deliberate), ≈ 13 billed macOS minutes ≈ 134 Linux-eq (6.7 % of 2,000).
   Remaining for the account: unknown (billing API 403); ≈ 1,866 if nothing else ran this month.
7. Artifacts: one small zip (the app), `retention-days: 14`.
8. No paid runners, no overage, no public repo, no paid services.

## Usage ledger

| Date (UTC) | Run | Trigger | Wall time | Billable (from API timing) | Linux-eq est. | Cumulative est. | Result |
|---|---|---|---|---|---|---|---|
| 2026-10-15 18:26 | 38785570076 | push b2b0524 — **accidental** (commit message quoted the trigger keyword) | 34 s job (61 s run) | API `timing` reports 0 ms; docs say jobs round up → **1 macOS min** assumed | ≈ 10.3 | ≈ 10.3 (0.5 %) | Native core tests **24/24 passed** (Swift 6.3.3, macOS 26 arm64); app build step failed (script not written yet). Ended before cancellation took effect. |
| 2026-10-15 19:15 | 38792443609 | request file (build #1) | 2 m 54 s job | API reports 0 ms → **3 macOS min** assumed | ≈ 31.0 | ≈ 41.3 (2.1 %) | **App built first try**; self-test 12/12; launch OK; artifact 2.0 MB (retained to 10-29) |
| 2026-10-15 19:24 | 38793640196 | request file (build #2) | 4 m 07 s job | API reports 0 ms → **5 macOS min** assumed | ≈ 51.7 | ≈ 93.0 (4.6 %) | Build OK; self-test 12/12; footprint 49.5 MB; CPU 12.4 % front / 5.5 % back (VM) |
| 2026-10-15 19:31 | 38794651725 | request file (final build #3) | 3 m 40 s job | API reports 0 ms → **4 macOS min** assumed | ≈ 41.3 | ≈ 134.3 (6.7 %) | **Final candidate** from 50c31bc; self-test 12/12; footprint 50.0 MB; CPU 8.3 % front / 3.9 % back (VM); artifact 2.0 MB until 10-29 |

## Incident 2026-10-15 18:26 — accidental macOS run

The commit that introduced the workflow described its trigger keyword in its own message, so the
job ran. The agent token cannot cancel runs (HTTP 403 on the cancel endpoint), so the run was
cancelled through the workflow's `concurrency: cancel-in-progress` by pushing another commit.
Fix: the trigger no longer depends on commit-message text; a build is requested only by changing
`ci/mac-build-request.txt` (or by clicking "Run workflow").
