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
4. Time caps: `build` 25 min + two `verify` jobs 12 min each ⇒ worst case 49 macOS min ≈ 506 Linux-eq
   (25 %) per run. Typical since build #4: 7–9 billed macOS minutes per run (three jobs, each rounded up).
5. `concurrency` with `cancel-in-progress: true` prevents overlapping runs. The agent token cannot
   call the cancel API (HTTP 403), so concurrency is the only cancellation lever.
6. Target: ≤ 4 macOS runs in the original campaign (met: 4). The founder's delivery request of
   2026-10-16 (“the ZIP is source code”) needed new builds: #4 (single-file download + verification;
   found a quit defect) and #5 (fix; delivered). Actual total: 6 runs ≈ 29 billed macOS minutes
   ≈ 300 Linux-eq (15.0 % of 2,000). Remaining for the account: unknown (billing API 403); ≈ 1,700
   if nothing else ran this month.
7. Artifacts: one unwrapped ≈ 2 MB zip per build (the app), `retention-days: 90` (builds #1–#3: 14 days).
   Free plan artifact storage is 500 MB; 5 artifacts ≈ 10 MB.
8. No paid runners, no overage, no public repo, no paid services.

## Usage ledger

| Date (UTC) | Run | Trigger | Wall time | Billable (from API timing) | Linux-eq est. | Cumulative est. | Result |
|---|---|---|---|---|---|---|---|
| 2026-10-15 18:26 | 38785570076 | push b2b0524 — **accidental** (commit message quoted the trigger keyword) | 34 s job (61 s run) | API `timing` reports 0 ms; docs say jobs round up → **1 macOS min** assumed | ≈ 10.3 | ≈ 10.3 (0.5 %) | Native core tests **24/24 passed** (Swift 6.3.3, macOS 26 arm64); app build step failed (script not written yet). Ended before cancellation took effect. |
| 2026-10-15 19:15 | 38792443609 | request file (build #1) | 2 m 54 s job | API reports 0 ms → **3 macOS min** assumed | ≈ 31.0 | ≈ 41.3 (2.1 %) | **App built first try**; self-test 12/12; launch OK; artifact 2.0 MB (retained to 10-29) |
| 2026-10-15 19:24 | 38793640196 | request file (build #2) | 4 m 07 s job | API reports 0 ms → **5 macOS min** assumed | ≈ 51.7 | ≈ 93.0 (4.6 %) | Build OK; self-test 12/12; footprint 49.5 MB; CPU 12.4 % front / 5.5 % back (VM) |
| 2026-10-15 19:31 | 38794651725 | request file (final build #3) | 3 m 40 s job | API reports 0 ms → **4 macOS min** assumed | ≈ 41.3 | ≈ 134.3 (6.7 %) | **Final candidate** from 50c31bc; self-test 12/12; footprint 50.0 MB; CPU 8.3 % front / 3.9 % back (VM); artifact 2.0 MB until 10-29 |
| 2026-10-15 22:17 | 38816041405 | request file (build #4 — single-file download + verification on fresh macOS 14 and 26) | build 2 m 56 s · verify 2 m 12 s (macos-latest) · 2 m 06 s (macos-14) | per-job round-up → **9 macOS min** (3+3+3) | ≈ 93.0 | ≈ 227.3 (11.4 %) | Build OK; downloaded file 33/34 on each Mac — **first-launch quit blocked by the welcome sheet** (fixed in 09c8c75) |
| 2026-10-15 22:30 | 38817528779 | request file (build #5 — quit fix) | build 2 m 26 s · verify 1 m 41 s (macos-latest) · 1 m 30 s (macos-14) | **7 macOS min** (3+2+2) | ≈ 72.3 | ≈ 299.6 (15.0 %) | **Delivered build**: 34/34 + self-test 12/12 on both Macs; artifact 12011451588 (2,066,069 B) until 2027-01-13 |

## Incident 2026-10-15 18:26 — accidental macOS run

The commit that introduced the workflow described its trigger keyword in its own message, so the
job ran. The agent token cannot cancel runs (HTTP 403 on the cancel endpoint), so the run was
cancelled through the workflow's `concurrency: cancel-in-progress` by pushing another commit.
Fix: the trigger no longer depends on commit-message text; a build is requested only by changing
`ci/mac-build-request.txt` (or by clicking "Run workflow").
