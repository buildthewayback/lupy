# LUPY 3 AGENT MEMORY — the 99% clone of the first session's agent

Written 17 Oct 2026 (late night) for the next Arena session. Read AFTER the intro of
docs/LUPY3_HANDOFF.md, BEFORE doing anything. Everything the previous agent knew that the
other docs don't already say.

## Session mechanics you must know

- This handoff exists in two live places: (1) the founder's Google Drive folder
  **"Lupy LUPY3 Handoff"** (all docs + the character reference + a git bundle), and
  (2) the repo's local-only commits (restorable from the bundle). The first session's
  workspace itself is dead.
- The previous session ran on branch `arena/48b1c2c3-lupy`; its PR #1 was MERGED, so its
  remote GitHub access was BLOCKED ("session closed" rule) — every LUPY 3 commit
  (`2c2d013` … `ead083c` + this one) is **local-only, never pushed**.
- Remote truth: `main` = `04c4693` (merge of PR #1; contains everything through `8493846`,
  i.e. the full LUPY 2 campaign). The LUPY 3 planning docs are NOT on GitHub.
- CI minutes on the old GitHub account: ≈1,932/2,000 SPENT; resets 1 Nov 2026. The founder
  plans a NEW GitHub account (fresh minutes) and will transfer the repo there
  (github.com → repo → Settings → Transfer ownership — keeps code/history/PRs, stays
  private). Until then: sandbox tests only; they're free.
- Do not push or run `gh` on a session whose PR was merged/closed — it fails. Your own
  fresh session/branch should work normally.
- Restoring the local commits: in a clone of the lupy repo:
  `git fetch /path/to/lupy3-local-commits.bundle HEAD` then merge/cherry-pick onto your
  branch. No bundle? Copy the .md files into `docs/` and the image into `docs/concepts/`,
  commit — identical content.

## What's done (facts you'll need)

- **LUPY 2 shipped**: F11 build run `38938047078`, artifact `12062097803`
  (`Lupy-0.2.0-735de9b36b-macOS-arm64.zip`, SHA-256
  `269543964d21f8bec7f61c635246eb365d8e7749ca22881e5cf9315ef683009c`, expires 2027-01-14).
  All green on macOS 14.8.9 + 26.6.2 (download 36/36, chat 19/19, control 9/9, RAM 46–57 MB).
- Engine: 108/108 tests, 668 checks. Chat self-test: `--chat-self-test [--report p]
  [--data-dir d]`, pass line `CHATTEST PASSED (n checks)`. Control self-test:
  `Mac/Sources/Lupy/Control/LupyControlSelfTest.swift`.
- Swift syntax-check without a Mac: `node --no-warnings tools/swiftwasm/syntax-check.mjs
  <file>` (if broken: `cd tools/swiftwasm && npm install @scalar/swift-fmt`).
- Budget defaults: $1.50/day, $10/mo, $0.50/task; approval threshold >$0.20/call NEEDS
  REWORK — chat must never be gated behind approvals.
- Repo docs: DECISIONS.md (D-001…D-034, L-25…L-29), CI_BUDGET.md (F1–F11 ledger),
  TEST_REPORT.md, INSTALL_GUIDE.md, LUPY_STATUS.md, WORK_LOG.md (full history).

## Founder profile (how to work with him)

- Solo founder, non-coder. Types fast, loose English — decode intent, never read literally.
- **ASK short multiple-choice questions when unsure — he explicitly demands it**
  ("u need aks me lol"). Never assume: the org name "toastmango" has NOTHING to do with the
  character (the agent's mango guess was rejected, hard).
- Never fake delivery. Never show broken things as done. He tests with a real API key.
- Honest about costs and limits, always. He gave DAYS for quality — no rushing.
- Standing constraints: private repo; Apple platforms only (his Mac = macOS 15; CI covers
  macOS 14 + 26); cloud APIs only, no local LLM; keep character/animations/sounds; model
  budget ~$15/month with many free tiers; chat never gated; research-first (anchor on the
  best reference, Pinterest/Behance for design); one-time instructions (never repeat
  mistakes — corrections become rules); do NOT specialize the product to his work; heavy
  testing before merges; batch CI builds.

## Where the LUPY 3 plan lives

- Contract + ALL his verbatim words: `docs/LUPY3_PLAN.md` (rounds 1–7).
- Spec: `docs/LUPY3_BLUEPRINT.md` (v3: pipeline, swarm, second brain, autonomy ladder,
  smart-canvas island). Dismantle map: `docs/LUPY3_AUDIT.md`.
- UI: `docs/LUPY3_UI_RESEARCH.md` (3 rounds of research; Synvy glassmorphism + Milkinside
  palette; HORIZONTAL widget-like canvas; first vertical attempts rejected).
- References: `docs/LUPY3_REFERENCES.md` — every link with his words + character spec.
- Procedure: `docs/LUPY3_HANDOFF.md`.

## Immediate priorities (in order)

1. **VISION CHECK** — view `docs/concepts/founder-ref-20261017.jpg` and every link in
   LUPY3_REFERENCES.md (watch the Milkinside video: "this video show exactly the best ui we
   need"). If you cannot see images, SAY SO IMMEDIATELY and stop visual work — that is why
   the session was changed.
2. **Character base**: exactly his reference shape — NO hands, NO legs — white body, tall
   solid-black capsule eyes, no pupils (the signature). Candidates → he approves → lock the
   approved render as the persistent reference passed into every future generation. Traits
   only after: crown + 5–6 accessories, ~5 seasonal, pyjama set. Fancy, never overloaded.
3. **UI use-case concepts**: horizontal smart-canvas island (avatar-first, grows per need,
   persistent mic+composer), Synvy-Neuro glassmorphism, Milkinside palette
   (#374772 #576692 #989FAB #C0C5D4 #253256 #5D5D69 #7F8493). He approves each use case.
4. **Backend**: deepen LUPY3_AUDIT.md, founder sign-off on blueprint, dismantle, build —
   engine tests green at every stage, sandbox tests free, one batched CI build per milestone.
5. Get the local commits pushed to GitHub (new branch from the restored bundle or docs) so
   this never-risk repeats.

## Dead ends — do not repeat

- Vertical phone-style island panels: REJECTED ("the ui u make is so bad"). Laptop-first =
  horizontal, widget-like.
- Mango anything (character color, UI accent): REJECTED.
- Character with hands/legs or eye pupils: REJECTED — exactly his reference shape.
- Generating concepts without studying the references first: REJECTED. Study, then generate.
- `edit_file` can report success without persisting → always verify with grep.
- Sandbox restore can reset the branch → `git fetch origin <branch> && git reset --mixed FETCH_HEAD`.
- `node_modules` in tools/swiftwasm can be wiped → reinstall @scalar/swift-fmt.
- `gh pr edit` is broken (GraphQL Projects deprecation) → `gh api -X PATCH repos/<o>/<r>/pulls/<n>`.
- F10 macOS 26 control flake: closed by hardening in `43ce459`, F11 passed — don't re-investigate.
- The first session had NO image vision (generate yes, view no) — that limitation, not the
  founder's references, caused the rejected character candidates. You should have vision;
  prove it by describing his reference image back to him before generating anything.
