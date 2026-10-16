# LUPY_STATUS

_Last updated: 2026-10-16 02:35 UTC · branch `arena/48b1c2c3-lupy` · delivery candidate commit `c8bad17` (build F5)_

## Where things stand (plain language)

**Lupy is now Coucou.** The real Coucou app (by Louis Raillé) with its animated Mochi, its icon,
its sounds, its island and its window — extended with Lupy's assistant inside it, and with
**computer control you can watch**: Lupy's own orange cursor presses and types in other apps while
your mouse stays yours, and it asks you before anything that sends, deletes, pays, publishes or
signs in. The exact file behind the link below was downloaded and checked on two fresh Macs
(macOS 14 and macOS 26): installed, opened, quit, reopened, self-tested, **and its computer
control was exercised for real on both machines (9/9 checks)**. It has **not yet been tried on your
MacBook**, and it has **not yet talked to a real AI provider or your GitHub** — those need your
keys and your hands (the acceptance checklist walks you through it).

## Download the app (one link)

**https://github.com/toastmangoapp-cloud/lupy/actions/runs/38839867821/artifacts/12021610015**
(sign in to GitHub first; works until **14 Jan 2027**)

- You get one file: **`Lupy-0.2.0-c8bad17274-macOS-arm64.zip`** — 19,370,871 bytes, SHA-256
  `be51da82a3c1bb6abf505a80a6746baa84714f62686a71f6c6c1728a82f67fd5`. Inside: **Lupy.app** only.
- Install and first open: `docs/INSTALL_GUIDE.md` §1–2 (no Terminal; first open via “Open Anyway”).
- **Not** the green “Code → Download ZIP” button — that is the source code, not the app.
- **Please keep this build to yourself:** it contains Coucou's character, icon and sounds, included
  for your private use with your decision of 2026-10-16 (see `Mac/CoucouAssets/NOTICE.md`).

Provenance: GitHub Actions run 38839867821 (16 Oct 2026), built on macOS 26.6.2 (Apple M1, arm64)
with Xcode 26.6 from commit `c8bad17274bdaa4ba477a17d031d7a80d3a6085d`; Coucou f09ac0b + Lupy
(`docs/COUCOU_FIDELITY.md`: 169 of 187 Coucou files byte-identical); ad-hoc signed (not Developer
ID, not notarized); Apple-silicon only; requires macOS 14+.

## Status gates

| Gate | State | Evidence |
|---|---|---|
| **Implemented** | Yes — Coucou's app + Lupy's assistant + computer control with the Lupy cursor (≈ 100k lines Coucou incl. Lupy hooks, ≈ 4.7k lines Lupy app-side, ≈ 9k lines LupyCore incl. tests) | this branch; `docs/COUCOU_FIDELITY.md` |
| **Sandbox-validated** | Yes — 96 test cases / 608 checks (incl. 13 computer-control rule cases) | `scripts/test-core.sh` (Swift 6.3.3 on WebAssembly) |
| **Native-build-validated** | Yes — same 96 tests natively; Coucou's 13 unit suites for touched areas + the OK-Lupy wake test; app builds with Xcode 26.6 for macOS 14.0+ | runs 38835587936, 38836083750, 38837448095, 38838652274, 38839867821 |
| **Installable artifact produced** | Yes — one ad-hoc-signed zip containing only Lupy.app (with Coucou's artwork, sounds and notices), behind a direct link | run 38839867821, artifact 12021610015 |
| **Mac runtime validated** | Partly — the **downloaded file** verified on fresh GitHub macOS **14.8.9** and **26.6.2** VMs (Apple M1, virtual): 34/34 download checks each, self-test 12/12, **computer control 9/9** (typing with read-back, Stop, honesty, declined/approved Send, password refusal), Mochi animated, quits cleanly. **Not yet on the founder's Mac.** | check runs of run 38839867821 |
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
