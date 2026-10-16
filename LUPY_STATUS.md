# LUPY_STATUS

_Last updated: 2026-10-16 19:45 UTC · branch `arena/48b1c2c3-lupy` · delivered commit `735de9b` (build F11) — LUPY 2: simple front, monster back_

## Where things stand (plain language)

**Lupy 2: simple front, monster back.** The character is **Lupy** (no Mochi/Coucou text left). The real Coucou app (by Louis Raillé) with its
animated Mochi, its icon, its sounds, its island and its window — extended with Lupy's assistant
inside it. **Click the island (or press ⌃⌥Space) and Lupy's conversation opens right there**:
type, or dictate and correct the transcript before sending. One shared conversation lives in the
island and in Today's panel; goals become plans, plans become tasks after your approval, questions
need your cloud-model key and say so honestly without one, and **computer control you can watch**
runs with Lupy's own orange cursor while your mouse stays yours — asking before anything that
sends, deletes, pays, publishes or signs in. The exact file behind the link below was downloaded
and checked on two fresh Macs (macOS 14 and macOS 26): installed, opened, quit, reopened,
self-tested, **its conversation loop exercised end-to-end (19/19 checks) and its computer control
exercised for real (9/9)** on both machines. It has **not yet been tried on your MacBook** or with
a live microphone, and it has **not yet talked to a real AI provider or your GitHub** — those need
your keys and your hands (the acceptance checklist walks you through it).

## Download the app (one link)

**https://github.com/toastmangoapp-cloud/lupy/actions/runs/38938047078/artifacts/12062097803**
(sign in to GitHub first; works until **14 Jan 2027**)

- You get one file: **`Lupy-0.2.0-735de9b36b-macOS-arm64.zip`** — 19,570,456 bytes, SHA-256
  `269543964d21f8bec7f61c635246eb365d8e7749ca22881e5cf9315ef683009c`. Inside: **Lupy.app** only.
- Install and first open: `docs/INSTALL_GUIDE.md` §1–2 (no Terminal; first open via “Open Anyway”).
- **Not** the green “Code → Download ZIP” button — that is the source code, not the app.
- **Please keep this build to yourself:** it contains Coucou's character, icon and sounds, included
  for your private use with your decision of 2026-10-16 (see `Mac/CoucouAssets/NOTICE.md`).

Provenance: GitHub Actions run 38938047078 (16 Oct 2026), built on macOS 26.6.2 (Apple M1, arm64)
with Xcode 26.6 from commit `735de9b36b58737fd2ca6482871eea52fcbe4070`; Coucou f09ac0b + Lupy
(`docs/COUCOU_FIDELITY.md`: 169 of 187 Coucou files byte-identical); ad-hoc signed (not Developer
ID, not notarized); Apple-silicon only; requires macOS 14+.

## Status gates

| Gate | State | Evidence |
|---|---|---|
| **Implemented** | Yes — Coucou's app + Lupy's assistant + computer control with the Lupy cursor (≈ 100k lines Coucou incl. Lupy hooks, ≈ 4.7k lines Lupy app-side, ≈ 9k lines LupyCore incl. tests) | this branch; `docs/COUCOU_FIDELITY.md` |
| **Sandbox-validated** | Yes — 96 test cases / 608 checks (incl. 13 computer-control rule cases) | `scripts/test-core.sh` (Swift 6.3.3 on WebAssembly) |
| **Native-build-validated** | Yes — **106 tests** (conversation routing included) natively; Coucou's 13 unit suites for touched areas + the OK-Lupy wake test; app builds with Xcode 26.6 for macOS 14.0+ | runs 38835587936 … 38916058766 (F1–F8) |
| **Installable artifact produced** | Yes — one ad-hoc-signed zip containing only Lupy.app (with Coucou's artwork, sounds and notices), behind a direct link | run 38938047078, artifact 12062097803 |
| **Mac runtime validated** | Partly — the **downloaded file** verified on fresh GitHub macOS **14.8.9** and **26.6.2** VMs (Apple M1, virtual): **36/36 download checks each**, self-test 12/12, **conversation self-test 19/19** (goal→plan→approve, status, honest no-model, control blocker, pause/resume, stop, follow-up history, persistence), **computer control 9/9** (typing with read-back, Stop, honesty, declined/approved Send, password refusal), Mochi animated, CPU unchanged from F5, quits cleanly. **Not yet on the founder's Mac.** | check runs of run 38938047078 |
| **Founder accepted** | No — pending `docs/MAC_ACCEPTANCE_CHECKLIST.md` (now Coucou-fidelity- and computer-control-aware) | — |

## What Lupy is, in one minute

- **The Coucou you know**: Mochi animated in the island (a compact top bar on your notch-less Air;
  draggable onto the desktop), Coucou's icon in the menu bar and Dock, its dark cards and buttons,
  its sounds, its Flow dictation and Notetaker, "OK Lupy" (or "OK Coucou") voice.
- **Lupy's assistant** in Coucou's window: Today (capture a goal, dictate, approve plans), Needs
  you, Tasks, Projects, Handoffs, Memory, Activity, Usage & budget, Assistant settings — all the
  honesty rules of the campaign (evidence over claims, budgets, approvals, durable journal).
- **Computer control**: Lupy → Computer control. Off until you turn it on. "Show me" demonstrates
  the cursor; "Deliver with Lupy" types a handoff brief into an agent and asks before Send; "Do
  something on screen" lets your approved cloud model drive, one gated step at a time. Esc or Stop
  always ends it; your typing pauses it; it never types passwords or touches CAPTCHA/2FA.

## Resource use (GitHub's virtual M1, 3 CPUs — a real M1 is expected lower)

| | macOS 14.8.9 | macOS 26.6.2 |
|---|---|---|
| Memory, first launch / demo peak | 46 MB / 85 MB | 58 MB / 93 MB |
| CPU, window frontmost (Mochi walking) | ~30 % | ~60 % |
| CPU, background (window open, island alive) | ~17 % | ~32 % |

The window's Mochis and band particles pause while another app is frontmost (Lupy's addition);
what remains is Coucou's island, which is alive by design — hide it in General settings for 0 %
(hide it any time you want quiet; Lupy's pages don't depend on it).

## GitHub Actions usage

11 macOS runs this campaign (1 accidental; builds #1–#5 of the old shell, F1–F5 of the fork) ≈
**55 billed macOS minutes ≈ 888 Linux-equivalent minutes ≈ 44 %** of a 2,000-minute Free allowance.
The account's real remaining balance is **unknown** (billing API not accessible to the agent).
Ledger: `docs/CI_BUDGET.md`.

## Decisions for you (none block using Lupy)

1. **Try it** with `docs/MAC_ACCEPTANCE_CHECKLIST.md` — especially the Coucou-fidelity and
   computer-control rows — and tell me what feels wrong.
2. **Optional:** an Apple Developer membership (paid, yearly) would remove the “Open Anyway” step
   via notarization. Not bought; your call.
3. **Reminder:** this build is personal-use (Coucou's artwork). If you ever want to share or
   publish Lupy, tell me and we swap the artwork or ask Louis Raillé for permission first.
