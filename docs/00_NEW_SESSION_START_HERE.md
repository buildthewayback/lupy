# 00 NEW SESSION START HERE (post-transfer, 17 Oct 2026)

Written for the NEXT Arena session AFTER the GitHub-account transfer. Two prior agents (LUPY 2 campaign + first LUPY 3 planner) handed off everything you need into THIS Drive folder. Read THIS file first; it supersedes the older READ_ME.

## 1. Where the code lives now

- **Repo was TRANSFERRED to a NEW GitHub account** because the old account's CI minutes were spent (~1,932/2,000, resets 1 Nov 2026). Do NOT rely on the old `toastmangoapp-cloud/lupy` remote; the founder may disconnect or delete it.
- **New repo location:** ASK the founder for the **new owner/repo name** (e.g. `<newaccount>/lupy`) in your first message. It was transferred via GitHub Settings → Transfer ownership, so all commits, branches, PRs and the LUPY 2 merge commit `04c4693` are intact.
- **Working branch:** start a fresh branch `arena/<your-session-id>-lupy` off main. The session you're replacing was on `arena/f855ebe1-lupy`; push was blocked by the transfer so its LUPY3 doc commits may not be on remote — if `ls docs/LUPY3_*.md` in a fresh clone is empty, copy the docs in from THIS Drive folder (list in §2).

## 2. First thing you do (DO NOT SKIP ANY STEP)

1. List contents of this Drive folder (`"Lupy LUPY3 Handoff"` in the founder's Google Drive).
2. `git clone` the new GitHub repo the founder gives you, onto a fresh branch.
3. If `docs/` is missing the LUPY3 files (likely — this session couldn't push), download THESE files from THIS Drive folder and place them:
   - `LUPY3_HANDOFF.md` → `docs/LUPY3_HANDOFF.md`
   - `LUPY3_PLAN.md` → `docs/LUPY3_PLAN.md` (founder verbatim rounds 1–8)
   - `LUPY3_BLUEPRINT.md` → `docs/LUPY3_BLUEPRINT.md`
   - `LUPY3_AUDIT.md` → `docs/LUPY3_AUDIT.md`
   - `LUPY3_UI_RESEARCH.md` → `docs/LUPY3_UI_RESEARCH.md`
   - `LUPY3_REFERENCES.md` → `docs/LUPY3_REFERENCES.md`
   - `LUPY3_ROUND8_ADDENDUM.md` → `docs/LUPY3_ROUND8_ADDENDUM.md` (skills/god-mode system, HIGH NEED)
   - `LUPY3_MEMORY_FULL.md` → `docs/LUPY3_MEMORY_FULL.md` ← **this file is the identity clone. Read it like your own memory.**
   - `LUPY3_AGENT_MEMORY.md` → `docs/LUPY3_AGENT_MEMORY.md`
   - `00_READ_ME_FIRST.md` → `docs/` (historical — superseded by this file)
   - `WORK_LOG.md` → `docs/` (append new entries; don't overwrite existing)
   - `founder-ref-20261017.jpg` → `docs/concepts/founder-ref-20261017.jpg`
4. **IMPORTANT: git bundle `lupy3-local-commits.bundle` is PRE-TRANSFER and may not be useful now** (the new main already has LUPY 2 but may be missing LUPY 3 commits). Don't fight it — just copy the .md files from Drive if the clone doesn't have them, commit, push EARLY so nothing is local-only again.
5. **PROVE YOU HAVE VISION.** Open `docs/concepts/founder-ref-20261017.jpg` with the image-reading tool and describe it back to the founder in your own words. Expected (and what the last session confirmed):
   - It is a sprite sheet titled **TRI-TRI MOCHI / UI & Animation Asset Kit** (11 states, 64×64px).
   - The **base shape** is a plump rounded-triangle mochi / onigiri / gumdrop blob — wide rounded base, soft peaked top.
   - **NO hands, NO legs, NO limbs** — one whole piece of body. This is non-negotiable.
   - **Body color:** white / warm-cream (the idle-state color — base over dark notch).
   - **Eyes are THE signature: tall solid-black CAPSULES (vertical pill), no pupils, no white highlights inside.**
   - Material: soft glossy mochi/jelly, top-front specular highlight, two pink cheek-blush dots lower down, gentle outer halo.
   - States (color-shift + one small overlay + possible eye-swap): idle / working / thinking / searching / approval / question / error / finished / ratelimit / sleeping / dizzy. The silhouette never grows limbs.
   If you cannot see images, SAY SO IMMEDIATELY and stop visual work.
6. Read `LUPY3_MEMORY_FULL.md` §9 (how we work) and §8 (dead ends, never repeat).
7. Read `LUPY3_REFERENCES.md` — visit EVERY link (watch the Milkinside Gen-UI video — he said “this video show exactly the best ui we need”).

## 3. State of the project (so you start in the right place)

- **LUPY 2 is DONE and shipped** — F11 build, all green macOS 14 + 26; merge commit `04c4693`. Founder tested with a real API key; key system works. F11 download link and SHA are in `LUPY_STATUS.md` (still on main).
- **LUPY 3 Phase 1 (paperwork) is DONE** — audit, blueprint (v2+), UI research (3 rounds, horizontal smart canvas, Synvy glassmorphism, Milkinside palette), references map, round 8 skills addendum.
- **Phase 2 begins now: CHARACTER BASE.** Build order (founder's standing directive, non-negotiable):
  1. **Character base** → candidates → he approves → lock approved render as persistent reference.
  2. **UI per use case** (horizontal smart-canvas island, Synvy glassmorphism, Milkinside palette #374772 #576692 #989FAB #C0C5D4 #253256 #5D5D69 #7F8493) → he approves each.
  3. **Backend** (deepen audit edge-by-edge → blueprint sign-off → dismantle → build; engine tests first). Round-8 skills/god-mode system + MCP client lands here (BLUEPRINT §6A).
- **CI budget: NEW account = fresh 2,000 free minutes.** Batch macOS builds. Sandbox swiftwasm tests are FREE — use them heavily. Never burn CI on an unverified build.
- git push / gh / CI should work normally in your session once the founder connects the new GitHub account.

## 4. How we work (the identity)

- Call him **"boss"**. Tone: warm, direct, playful, never corporate.
- **Verify everything** — grep after edits; tests before claims; no green without seen green.
- Commit small, **push early** (no local-only work ever again — that's why these Drive handoffs exist).
- **Ask short multiple-choice questions** when unsure. He answers those. Always leave a custom-text door.
- Honest reports: what's done, what's not, cost, what broke. Bad news first. Never fake delivery.
- Research-first; anchor on the best reference; never low-effort to make him happy.
- One-time instructions become rules; mistakes never repeat.
- Chat is **NEVER** gated behind approvals (that bug killed the F11 experience). Approvals only for consequential actions: send/post/delete/pay/screen control/big spends.
- Present the deliverable; summarize with short sections, simple words.

## 5. Hard DO-NOT list (each one burned a previous session)

- NO vertical/phone-style panels (rejected hard: “the ui u make is so bad”). HORIZONTAL laptop-first, widget-like.
- NO mango anything (org name is toastmango; nothing to do with the character or accent color).
- NO hands / NO legs / NO pupils on the character. Exactly his reference.
- NO generating concepts before studying the references with eyes.
- NO assuming from names (mango lesson). ASK.
- NO gating chat behind approvals.
- NO fake delivery. He tests with a real API key before calling anything delivered.
- NO burning CI minutes on unverified builds — sandbox tests first.
- NO trusting `edit_file` success without grepping to prove it persisted.

## 6. Immediate first deliverable after the vision proof

After describing `founder-ref-20261017.jpg` back to him and getting confirmation, generate **3 character-base candidates** for approval:

- Shape: plump rounded-triangle mochi blob (same family as the reference sheet).
- Limbs: NONE. Body only.
- Color: white / warm-cream base (idle tone from the reference; reads over dark notch).
- Eyes: tall solid-black capsules, rounded ends, evenly spaced — NO pupils, NO inner highlights. This is the signature.
- Material: soft jelly/mochi gloss, top-front specular highlight, two soft pink blush dots on the lower cheeks, gentle outer glow (calm, not neon).
- Render style: clean 3D, dark backdrop (so the white body reads against a notch-like dark surface).
- Do NOT add crown / accessories / seasonal items / pyjamas yet — those are TRAITS, added only AFTER he locks the base.

Workflow: 3 candidates → present → he picks/patches → iterate → he approves → **save the approved render and pass it as a reference image into every future character generation call** (so renders stay consistent). Then UI concepts per use case, then backend.

No blind building.

---

_Drop a short “I'm in, new repo cloned, I can see the reference, here's my read of it” as your opening message — that's the proof-of-eyes gate. Then start._

## 7. Session handoff chain (for context only)

- LUPY 2 agent (arena/48b1c2c3-lupy) → shipped F11, merged PR #1, wrote first Drive handoff because it had no image vision.
- Vision session (arena/f855ebe1-lupy, this one) → confirmed vision, read every reference, performed the vision proof, but git/CI were severed by the account transfer mid-session before any character candidates could be generated or code pushed. Hence THIS file — a clean re-start doc pointing at the new repo.
