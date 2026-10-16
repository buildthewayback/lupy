# WP-0 — Environment, repository, licence and budget verification

Recorded 2026-10-15 (UTC) by the Arena agent at the start of the build campaign.
Labels: **Observed** (inspected directly), **Tested** (command executed), **Documented**
(official docs, not executed), **Inferred**, **Unknown / blocked**.

## Handoff package

| Item | State | Evidence |
|---|---|---|
| Six package files received; SHA-256 of all five Markdown docs matches `SHA256SUMS.txt` | Tested | `sha256sum *.md` vs manifest |
| `PASTE_TO_ARENA.txt` listed in manifest but not attached | Observed | not present in upload dir; the founder's chat message served as the prompt |
| `LUPY_COMPLETE_ARENA_HANDOFF.md` is an exact concatenation of the 5 docs | Tested | per-section `diff -w -B` = 0 lines |
| Copies kept in `docs/handoff/` for provenance | Observed | this repo |

## Sandbox (Arena Agent Mode)

| Item | State | Evidence |
|---|---|---|
| Linux x86_64, Debian 12, 2 vCPU, 3.8 GiB RAM, no swap | Tested | `uname -a`, `free -h`, `nproc` |
| No Swift, Xcode, xcodebuild, clang, sqlite3 CLI, docker | Tested | `command -v` |
| Node 22.22.3, npm 10.9.8, Python 3.11.2, gcc 12, git 2.39.5, gh 2.23.0 | Tested | `--version` |
| Egress only to github.com, api.github.com, codeload.github.com, registry.npmjs.org, pypi.org | Observed + Tested | `download.swift.org` → no connection; GitHub release assets redirect to `release-assets.githubusercontent.com` → TLS connection refused |
| **Swift 6.3.3 compiler running under Node via WebAssembly works** (npm `@live-codes/swift-wasm`) | Tested | compiled + ran generics/protocols/Codable/actors/Regex programs; `-swift-version 6` strict concurrency diagnostics observed |
| That toolchain has the Swift stdlib, Concurrency, StringProcessing — **no Foundation, no XCTest/Testing, no macros, no SwiftUI/AppKit** | Observed | sysroot listing |
| Node's built-in WASI segfaults while running `wasm-ld`; pure-JS `browser_wasi_shim` works | Tested | segfault exit 139 reproduced 3×; shim link succeeds |

Consequence (Decision D-003): Lupy's core logic is written in **stdlib-only Swift** so it is compiled
and tested here for real; the macOS shell (SwiftUI/AppKit/Foundation/Security) can only be compiled
on macOS.

## GitHub repository and access

| Item | State | Evidence |
|---|---|---|
| Repo `toastmangoapp-cloud/lupy`, **private**, created 2026-10-15T17:28Z, default branch `main`, initial commit `d940012` (README only) | Observed | `gh api repos/...` |
| Not a fork of Coucou; Coucou upstream never modified (read-only clone outside the repo) | Observed | `isFork=false`; upstream clone at `/home/user/upstream/coucou` |
| Session token: GitHub App user token, `viewerPermission=ADMIN`, expires 2026-10-16 01:29 UTC | Observed | `gh auth status`, response headers |
| Work branch `arena/48b1c2c3-lupy` (session-fixed) | Observed | `git branch` |
| Actions permissions endpoint → HTTP 403 "Resource not accessible by integration" | Tested | `gh api repos/.../actions/permissions` |
| 0 workflows, 0 runs in this repo before this campaign | Tested | `gh api repos/.../actions/workflows`, `/runs` |

## GitHub Actions billing (hard constraint)

| Item | State | Evidence |
|---|---|---|
| Account plan, current-month usage, remaining minutes, payment method, budgets | **Unknown / blocked** | `users/{u}/settings/billing/actions`, `/billing/usage`, `/billing/usage/summary` → HTTP 403 for this token |
| GitHub Free: 2,000 min/month, 500 MB artifact storage (shared with Packages) | Documented | docs.github.com/en/billing/concepts/product-billing/github-actions (fetched 2026-10-15) |
| Rates: Linux 2-core $0.006/min, **macOS (M1 3-core) $0.062/min** (≈10.3× Linux); jobs rounded up to whole minutes | Documented | docs.github.com/en/billing/reference/actions-runner-pricing |
| Without a payment method, usage is blocked at quota (no surprise charges) | Documented | same billing page |
| `macos-latest` = macOS 26 arm64 (M1, 3 CPU, 7 GB), default Xcode 26.6 | Documented | actions/runner-images README + macos-26-arm64 readme |
| Real reference: Coucou's Release compile ≈ 10 min, its swiftc test binaries ≈ 1 min on `macos-latest` | Observed | public run 38770703821 step timings |

Budget policy adopted: see `docs/CI_BUDGET.md`.

## Coucou upstream

| Item | State | Evidence |
|---|---|---|
| `https://github.com/Louis-CFM/coucou` @ `f09ac0b451128781b88b0f8a77f69bab622b9f24` (2026-10-15 19:30 +0200), 592 commits | Observed | `git log -1` (prior assessment saw `a95d309…`; upstream moved) |
| `LICENSE`: MIT, © 2026 Louis Raillé (code) | Observed | file content |
| `LICENSE-ASSETS.md`: reserves names Coucou/Mochi, Mochi character (design, look, expressions, animations as a character), app + menu bar icons, sounds, docs/media + design images; explicitly welcomes forks with "your own name, icon, character and sounds" | Observed | file content |
| Native macOS app `NotchBuddy/`: Swift 6, SwiftUI + AppKit, macOS 15.0 deployment target, XcodeGen `project.yml`, ~48k lines Mac Swift; one SwiftPM dependency (FluidAudio — local Parakeet speech model) | Observed | `project.yml`, `wc -l` |
| Tests = standalone `swiftc` test binaries (`scripts/test-*.sh`), CI on `macos-latest` | Observed | `.github/workflows/build.yml` |
| Release signing uses the author's Apple team; Lupy cannot use it | Observed | `project.yml` `DEVELOPMENT_TEAM` |

Reuse decisions: `docs/COUCOU_REUSE_MAP.md`.
