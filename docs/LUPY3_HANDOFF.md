# LUPY 3 HANDOFF — READ THIS FIRST (ignition key for the next AI session)

Written 17 Oct 2026 by the previous session's agent for whoever continues this work.
The founder starts a fresh Arena session and says: **"Read docs/LUPY3_HANDOFF.md first."**
Everything below is also in the repo — nothing that matters was lost.

## Who you're working for
A solo founder, non-coder. He types fast, loose English — decode his intent, don't read him
literally, and when his need is unclear, ASK him (he explicitly wants to be asked; short
multiple-choice questions work best). Never fake delivery. Never show him broken things as
done. Be honest about costs, limits, and what is not finished. He gave days of room to do
this properly — quality over speed.

## What Lupy 3 is (one paragraph)
A lightweight Mac app: the island is the conversation with Lupy; behind that one face Lupy
runs a **swarm** — a pool of models from every free tier the founder connects, plus
sub-agents spun up per task — through a fixed pipeline: **clarify → research-first → plan →
preview → approve → delegate (exact briefs) → hard-verify → deliver → learn.** A second
brain that never forgets and never repeats mistakes. Earned autonomy ladder (L0 everything
through him → L3 morning-start). Chat is NEVER gated behind approvals; approvals are only
for consequential actions (send/post/delete/pay/screen control/big spends). Model budget
~$15/month. Full contract: docs/LUPY3_PLAN.md (his verbatim words) and
docs/LUPY3_BLUEPRINT.md (the spec).

## Repo map (read in this order)
1. docs/LUPY3_PLAN.md — founder contract + all interview quotes (rounds 1–4)
2. docs/LUPY3_BLUEPRINT.md — the spec (pipeline, swarm, second brain, autonomy ladder)
3. docs/LUPY3_AUDIT.md — the dismantle map: KEEP-CHASSIS / KEEP-FEATURE / REBUILD / REMOVE
4. docs/LUPY3_UI_RESEARCH.md — the design system for the new UI (he demands "amazing")
5. docs/DECISIONS.md, docs/WORK_LOG.md — history; docs/CI_BUDGET.md — minutes ledger
6. Code: LupyCore/ (engine + 108 tests), Mac/Sources/ (app; chassis credited to Coucou,
   private-use artwork — do not publish)

## State at handoff
- LUPY 2 (rebrand, island UX, universal AI-APIs hub) is DONE: merged to main via PR #1
  (merge commit 04c4693). F11 build artifact link is in LUPY_STATUS.md.
- LUPY 3 is in Phase 1 (audit + blueprint drafted; founder reviewing). All decisions from
  the interview are recorded; utilities were decided 17 Oct (music/mail/notes/clipboard/
  iPhone link/Flow daily pages STAY, rebuilt island-first).
- The previous session's branch (arena/48b1c2c3-lupy) ended with local-only commits that
  could not be pushed (session closed after PR merge). If those commits are present in this
  repo, use them; if not, the doc contents were re-committed here — either way this file
  being readable means the transfer worked.
- **Google Drive copy (the safety net)**: the founder's Drive has a folder
  **"Lupy LUPY3 Handoff"** containing every LUPY 3 doc, the character reference image,
  LUPY3_AGENT_MEMORY.md, and `lupy3-local-commits.bundle` (the local-only commits in git
  form — `git fetch <bundle> HEAD` in a clone restores them). If the repo lacks the LUPY 3
  docs, restore from Drive first.

## The GitHub account migration (why a new account)
The old account's Actions minutes are spent (~1,932/2,000, resets 1 Nov 2026). The founder
created a NEW GitHub account for fresh minutes; the repo was moved there (GitHub → repo →
Settings → Transfer ownership — keeps all code, history, issues, PRs; stays private).
House rules that carry over: **batch CI builds** (one green build beats many red ones),
sandbox tests are free (swiftwasm syntax check + engine self-tests), **heavily test before
any merge**, never burn minutes on a build you haven't syntax-checked.

## Rules of engagement (standing, from the founder)
- Repo is PRIVATE. Apple platforms only (his Mac is macOS 15; CI also covers macOS 26).
- No local LLMs — cloud APIs only; he connects many free tiers; engine picks per step.
- Keep the character, animations, and sounds. Keep dictation. Keep the island machinery.
- Never gate chat behind approvals. Research-first always; anchor on the best reference.
- One-time instructions only: corrections become rules, mistakes never repeat.
- Don't specialize the product to his specific work — his routine info only tunes UI.
- Budget honesty: per-task cost visible; ~$15/month ceiling; free tiers drained first.
- He tests with a real API key before anything is called delivered.

## Immediate next steps (in order) — UPDATED 17 Oct night for the vision session
0. **You should have vision. The previous session did not** — it could generate images but
   not view them, so all visual concept work was paused and handed to you. FIRST ACTION:
   open **docs/LUPY3_REFERENCES.md** — visit every link, watch the videos, and VIEW the
   founder's character reference (docs/concepts/founder-ref-20261017.jpg). His rule: the
   answers are all in those links; ask him, never assume (the "mango" lesson).
1. Character base first (his build order): exactly his reference shape — NO hands, NO legs,
   white body, tall solid-black capsule eyes, no pupils. Candidates → he approves → lock the
   approved render as the persistent reference for all future generations. Then traits
   (crown + 5–6 accessories, ~5 seasonal, pyjama set — fancy, never overloaded).
2. UI concepts per use case (horizontal smart-canvas island, Synvy/Milkinside style) →
   founder approves each.
3. Only then backend: finish docs/LUPY3_AUDIT.md edge-by-edge, founder sign-off on the
   blueprint, Phase 3 (dismantle) + Phase 4 (build) with engine tests green at every stage.
4. One batched CI build per coherent milestone; founder tests the artifact with a real key.

## Honesty notes carried over
- Never fake delivery; never show broken things as done; ask when unclear (short
  multiple-choice questions work best — he answers those).
- If YOU also cannot view images, say so immediately — do not guess at visuals.
