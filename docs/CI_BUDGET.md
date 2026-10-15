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
3. The only workflow is `mac-build.yml` (macOS): it runs **only** when a commit message contains
   `[mac-build]` or when started manually from the Actions tab. Pushes without the tag create a
   skipped job (0 billed minutes).
4. `timeout-minutes: 25` caps the worst case at ≈ 258 Linux-eq minutes (12.9 %) per run.
5. `concurrency` with `cancel-in-progress: true` prevents overlapping runs.
6. Target: ≤ 4 macOS runs in this campaign (expected 4–7 min each ⇒ ≈ 40–75 Linux-eq each).
7. Artifacts: one small zip (the app), `retention-days: 14`.
8. No paid runners, no overage, no public repo, no paid services.

## Usage ledger

| Date (UTC) | Run | Trigger | Wall time | Billable (from API timing) | Linux-eq est. | Cumulative est. | Result |
|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | 0 | No runs yet |
