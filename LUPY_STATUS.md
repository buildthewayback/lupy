# LUPY_STATUS

_Last updated: 2026-10-15 19:40 UTC · branch `arena/48b1c2c3-lupy` · final candidate commit `50c31bc`_

## Where things stand (plain language)

Lupy v0.1.0 is built. It is a real Mac app: it compiles on Apple's tools, its built-in self-test
passes inside the finished app, and it launches with a small memory footprint (about 50 MB). You can
download it today. It has **not yet been tried on your own MacBook**, and it has **not yet talked to
a real AI provider or to your GitHub** — those need your keys and your hands (15–30 minutes with
`docs/MAC_ACCEPTANCE_CHECKLIST.md`).

## Download the candidate

1. GitHub → **Actions** → “Mac build (manual)” → run **38794651725** (15 Oct 2026, green).
2. Artifact **`Lupy-macOS-50c31bca33d2b52760302097ba1c602bb375933b`** (2.0 MB; available until **29 Oct 2026**).
3. Inside: **`Lupy-0.1.0-50c31bca33-macOS-arm64.zip`** — SHA-256
   `a40441c6f7b65a7bb5ffb28779ef4f9a577516053353cf6093493275f358338c`.
4. Install: `docs/INSTALL_GUIDE.md` (no Terminal; first open via System Settings → “Open Anyway”).

Provenance: built by GitHub Actions on macOS 26.6.2 (Apple M1, arm64), Xcode 26.6, from commit
`50c31bca33d2b52760302097ba1c602bb375933b`; ad-hoc signed (not Developer ID, not notarized);
requires macOS 14+.

## Status gates

| Gate | State | Evidence |
|---|---|---|
| **Implemented** | Yes — core + Mac app (≈ 8.9k lines core incl. tests, ≈ 2.6k lines app) | this branch |
| **Sandbox-validated** | Yes — 83 test cases / 515 checks pass | `docs/TEST_REPORT.md` (Swift 6.3.3 on WebAssembly) |
| **Native-build-validated** | Yes — same 83 tests pass natively; app builds with Xcode 26.6 (3 successful builds, first try) | runs 38792443609, 38793640196, 38794651725 |
| **Installable artifact produced** | Yes — ad-hoc-signed zip with SHA-256 and build info (not notarized) | run 38794651725 |
| **Mac runtime validated** | Partly — launched and self-tested **on a GitHub macOS VM**: self-test 12/12 (real-disk crash recovery, backup, Keychain), launch OK, 50 MB footprint, screenshots reviewed. **Not yet on the founder's Mac.** | build report check runs |
| **Founder accepted** | No — pending `docs/MAC_ACCEPTANCE_CHECKLIST.md` | — |

## What works, what needs you, what isn't built

- **Works without any setup:** projects (your 10), goals → offline plans → approval, explainable
  priorities, task lifecycle, handoffs to Arena/Muse/Orin by copy-paste with honest status, evidence
  and verification, follow-ups and notifications, approvals, memory, backups/export, diagnostics,
  dictation (after macOS permission), saving drafts with verified read-back.
- **Needs your key or token:** cloud-model planning/drafting/briefs/answers (OpenAI, Anthropic,
  Gemini, DeepSeek, OpenRouter…), GitHub proof of coding work.
- **Not built in v1 (by design, documented):** sending email/social/Displate posts, browser/app
  automation, direct Arena/Muse/ChatGPT connections (no usable APIs), notarized signing.
  See `docs/KNOWN_LIMITATIONS.md` (19 items) and `docs/FUNCTIONAL_MATRIX.md`.

## Work packages

| WP | Status |
|---|---|
| WP-0 Environment / licences / billing | VERIFIED (billing usage unreadable → estimates) |
| WP-1 Reuse map + foundation | VERIFIED |
| WP-2 Durable state, recovery, backup | VERIFIED |
| WP-3 Providers + spend controls | READY_FOR_REVIEW (no live call yet) |
| WP-4 Planning, priority, ownership | VERIFIED |
| WP-5 Evidence, handoffs, verification, reliability | VERIFIED |
| WP-6 Integrations | READY_FOR_REVIEW (GitHub live check needs token; sending/automation deferred) |
| WP-7 Security, resources, observability | READY_FOR_REVIEW (real-hardware CPU pending) |
| WP-8 Regression / end-to-end | VERIFIED |
| WP-9 Native Mac build | VERIFIED (build); runtime on your Mac pending |
| WP-10 Final package | READY_FOR_REVIEW |

## GitHub Actions usage

4 macOS runs (1 accidental 34-second run, 3 deliberate builds) ≈ **13 billed macOS minutes ≈ 134
Linux-equivalent minutes ≈ 6.7 %** of a 2,000-minute Free allowance. The account's real remaining
balance is **unknown** (billing API not accessible to the agent); if nothing else used minutes this
month, about 1,866 remain. Ledger: `docs/CI_BUDGET.md`.

## Decisions for you (none block using Lupy)

1. **Try it** with the acceptance checklist and report what you see.
2. **Optional:** an Apple Developer membership (paid, yearly) would remove the “Open Anyway” step
   via notarization. Not bought; your call.
3. **Optional:** add an AI provider key and/or a read-only GitHub token (guide §5–6).
4. **Merge:** a pull request into `main` is open as a draft for your review; nothing is merged.
