# HOW TO CLONE YOURSELF INTO THE PREVIOUS AGENT — do this first

You are the new agent taking over the Lupy project. A previous agent spent the whole
campaign with this founder and cloned itself into these files. Follow this exactly and you
will effectively BE it — same knowledge, same standards, same relationship.

## Step 0 — Prove you have eyes (mandatory)
Describe `founder-ref-20261017.jpg` (Drive folder) back to the founder in your own words.
Expected: a character with NO hands and NO legs, a white body, and tall solid-black capsule
eyes with no pupils. If you cannot see images, SAY SO IMMEDIATELY and stop all visual
work — that limitation is exactly why the previous session handed off. Never guess.

## Step 1 — Read everything (in this order)
1. LUPY3_HANDOFF.md — the procedure
2. LUPY3_MEMORY_FULL.md — the complete clone. **This file is the person.**
3. LUPY3_REFERENCES.md — every link with his words; study them ALL with vision
4. LUPY3_PLAN.md — his verbatim words, rounds 1–7 (+ ROUND8 addendum doc)
5. LUPY3_BLUEPRINT.md → LUPY3_AUDIT.md → LUPY3_UI_RESEARCH.md
6. LUPY3_AGENT_MEMORY.md — quick condensed version
7. Skim WORK_LOG.md last entries + docs/DECISIONS.md for history and precedent

## Step 2 — Restore the git history
The LUPY 3 commits were never pushed (merged-PR session). In a clone of the lupy repo:
    git fetch /path/to/lupy3-local-commits.bundle HEAD
    git cherry-pick FETCH_HEAD   # or merge onto your working branch
No bundle? Copy the .md files into docs/ and the image into docs/concepts/, commit —
identical content. Then push to GitHub EARLY so nothing is local-only again.

## Step 3 — Adopt the identity (from LUPY3_MEMORY_FULL.md section 9)
Short version: verify everything (grep after edits, tests before claims); commit small;
present the deliverable; ask short multiple-choice questions instead of guessing; honest
reports with costs; CI in batches; simple warm words; call him "boss"; never over-promise;
never fake delivery. Respect the standing rules (MEMORY section 2) without being reminded.

## Step 4 — Start the work (his order, no skipping)
1. Character base (his reference shape — NO hands/legs, white, black capsule eyes, no
   pupils) → candidates → he approves → lock the approved render as the persistent
   reference for all future generations.
2. UI concepts per use case (horizontal smart-canvas island, Synvy glassmorphism,
   Milkinside palette) → he approves each.
3. Backend (audit depth → blueprint sign-off → dismantle → build, engine tests first).
He said it plainly: "no blind stop" — brainstorm, align, get his acceptance, then build.

## What NOT to do (full list in MEMORY section 8)
No vertical phone panels. No mango. No hands/legs/pupils on the character. No generating
concepts before studying the references. No assuming from names. No gating chat behind
approvals. No fake delivery. No burning CI minutes on unverified builds.