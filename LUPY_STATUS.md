# LUPY_STATUS

_Last updated: 2026-10-15 22:45 UTC · branch `arena/48b1c2c3-lupy` · download candidate commit `09c8c75`_

## Where things stand (plain language)

Lupy v0.1.0 is built. It is a real Mac app: it compiles on Apple's tools, its built-in self-test
passes inside the finished app, and it launches with a small memory footprint (about 30–50 MB). You can
download it today with one link (below). The exact file that link serves was downloaded and
checked on two fresh GitHub Mac machines (macOS 14 and macOS 26): it contains only **Lupy.app**,
installs, opens, quits and reopens, and passes its self-test. It has **not yet been tried on your
own MacBook**, and it has **not yet talked to a real AI provider or to your GitHub** — those need
your keys and your hands (15–30 minutes with `docs/MAC_ACCEPTANCE_CHECKLIST.md`).

## Download the app (one link)

**https://github.com/toastmangoapp-cloud/lupy/actions/runs/38817528779/artifacts/12011451588**
(sign in to GitHub first; works until **13 Jan 2027**)

- You get one file: **`Lupy-0.1.0-09c8c7571c-macOS-arm64.zip`** — 2,066,069 bytes, SHA-256
  `161f022e39deccc5467c6d7861c9b43b22ad01b1d6c80bfe1a4da2476968d747`. Inside: **Lupy.app** only.
- Install and first open: `docs/INSTALL_GUIDE.md` §1–2 (no Terminal; first open via “Open Anyway”).
- **Not** the green “Code → Download ZIP” button — that is the source code, not the app.

Provenance: GitHub Actions run 38817528779 (15 Oct 2026), built on macOS 26.6.2 (Apple M1, arm64)
with Xcode 26.6 from commit `09c8c7571cecaff65047e9c5ad71387dee277e1b`; ad-hoc signed (not
Developer ID, not notarized); Apple-silicon only; requires macOS 14+. Download verification
evidence: `docs/TEST_REPORT.md` → “Download verification”.

## Status gates

| Gate | State | Evidence |
|---|---|---|
| **Implemented** | Yes — core + Mac app (≈ 8.9k lines core incl. tests, ≈ 2.6k lines app) | this branch |
| **Sandbox-validated** | Yes — 83 test cases / 515 checks pass | `docs/TEST_REPORT.md` (Swift 6.3.3 on WebAssembly) |
| **Native-build-validated** | Yes — same 83 tests pass natively; app builds with Xcode 26.6 (5 successful builds) | runs 38792443609, 38793640196, 38794651725, 38816041405, 38817528779 |
| **Installable artifact produced** | Yes — one ad-hoc-signed zip containing only Lupy.app, with SHA-256, behind a direct link (not notarized) | run 38817528779, artifact 12011451588 |
| **Mac runtime validated** | Partly — the **downloaded file** was verified on fresh GitHub macOS **14.8.9** and **26.6.2** VMs (Apple M1, virtual): 34/34 checks each — contents, signature, install to Applications, first launch, quit, relaunch — plus self-test 12/12; Gatekeeper prompt seen as expected; screenshots reviewed. **Not yet on the founder's Mac.** | download-check check runs of run 38817528779 |
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

6 macOS runs (1 accidental 34-second run, 5 deliberate builds; builds #4–#5 also verified the
download on two fresh Macs) ≈ **29 billed macOS minutes ≈ 300 Linux-equivalent minutes ≈ 15 %** of a
2,000-minute Free allowance. The account's real remaining balance is **unknown** (billing API not
accessible to the agent); if nothing else used minutes this month, about 1,700 remain. Ledger:
`docs/CI_BUDGET.md`.

## Decisions for you (none block using Lupy)

1. **Try it** with the acceptance checklist and report what you see.
2. **Optional:** an Apple Developer membership (paid, yearly) would remove the “Open Anyway” step
   via notarization. Not bought; your call.
3. **Optional:** add an AI provider key and/or a read-only GitHub token (guide §5–6).
4. **Merge:** a pull request into `main` is open as a draft for your review; nothing is merged.
