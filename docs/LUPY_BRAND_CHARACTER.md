# LUPY — brand and character law

**Status: v1, 17 Oct 2026.** Written after the founder's correction: *"now on there is no
call coucou or mochi — my character name is Lupy… this is V3 we making whole new own
LUPY… none of u make is correct and the white one 4th image u make is correct as character
— eye can't be anything else… character its need character consistent over all where…
there is no chance for character error is branding."*

This file is LAW. If any other doc, prompt, render or code path disagrees with it, this
file wins. Read it before generating a single frame.

---

## 1. Names

| Thing | Correct | Never |
|---|---|---|
| The character | **Lupy** | "Mochi", "Tri-Tri", "mochi character", "Mango", "the blob" |
| The app | **Lupy** | "Coucou", "NotchBuddy" |
| The project | **LUPY 3** — the rebuild | "Lupy 2", "lupy3 doc" as a character name |
| Coucou | The **engineering base + credited chassis** only | a source of names, artwork or identity |

Coucou remains in the repo as credited MIT code and as the *engineering reference* for the
rig/animation quality bar. **Nothing user-facing is called Coucou, and the character is
never called Mochi again.** `THIRD_PARTY_NOTICES.md` keeps the legal credit; that file is
about code licences, not product naming.

## 2. The character — non-negotiable spec

Source of truth: **`docs/concepts/lupy-master-M2-softapex.png`** (locked master) and
**`docs/concepts/lupy-character-spec-v1.json`** (measured numbers).

### Shape
- Plump **rounded-triangle dome** — a soft gumdrop / onigiri.
- Rounded apex (never a sharp point), smooth sloping shoulders, broad softly flattened base.
- **Wider than tall: body height = 0.802 × body width** (measured from the founder's reference).
- **One continuous piece. NO arms, NO hands, NO legs, NO feet, NO mouth, NO ears, NO nose.**
  This is non-negotiable and was corrected twice.

### Body colour
- **Base = pure neutral white `#FFFFFF`.**
- Shading is a soft vertical gradient only: `#FFFFFF` top → `#E8E8EF` bottom (≈ -10% at the base).
- Soft white specular on the upper-front. Never grey, never cream as the base tone.
- The founder's own reference sheet was cream because *he generated it in other colours* —
  the canonical Lupy is white.

### Eyes — THE signature
> "eye is the key capsule full black no pupils… eye cant be anything else specifically my
> example given image kinda"

- **Two tall vertical capsules (rounded pills).** Rounded ends, straight sided.
- **Solid flat matte black `#000000`.** No gradient, no gloss, no highlight, no glint,
  **no pupil, no iris, no white dot inside.** This was the exact failure of candidate A —
  a glossy eye is a rejected eye.
- Proportions (measured): **width = 0.139 × body width**, **height = 0.2888 × body width**
  → **height = 2.08 × eye width**.
- Position: **centre ±0.1644 × body width** horizontally, eye centre at
  **0.572 of the body height from the top**. Upright vertical axis. Evenly spaced.
- Always symmetric about the body midline. (The founder's reference is very slightly
  turned — eyes 25px right of centre — that is a render artifact, **not** design intent.
  The rig is symmetric.)

### Blush
- Two soft dusty-pink smudges low on the cheeks, colour `#F78E86`, opacity ≈ 0.34,
  radius 0.075 × 0.058 body width, centred ±0.24 body width at 0.192 body height from base.
- Soft-edged. Never a hard circular disc.

### Halo
- Gentle glow of the *body colour* hugging the silhouette, at 0.18–0.55 opacity depending
  on state. Calm. Never neon, never a spotlight.

## 3. The animation system — one body, expression in the eyes

**This is the whole system, and it is what keeps Lupy consistent:** the silhouette never
changes. A state changes only four things:

1. **Eye shape** (the expression)
2. **Body tint** (colour shift)
3. **Halo intensity**
4. **One small overlay** — a badge, sparkles, a sweat drop, bubbles, Z's

The founder's reference says it outright: *"body colors and thing to it is fine but eyes
change"*.

### States (11 — must match the reference sheet)
| State | Body | Eyes | Overlay |
|---|---|---|---|
| idle | white | tall capsule | — |
| working | blue `#3B9EFF` | tall capsule | dots bubble |
| thinking | violet `#8B5CF6` | tall capsule | dots bubble |
| searching | indigo `#635FF2` | tall capsule | dots bubble |
| approval | amber `#F5A523` | wide capsule (taller/wider) | `!` bubble |
| question | cyan `#22D3EE` | tall capsule | `?` bubble |
| error | red `#F4505E` | flat dash | dot badge |
| finished | green `#34D399` | happy arcs (∪∪) | sparkles + dot |
| ratelimit | orange `#F0923C` | half-lidded | sweat drop |
| sleeping | slate `#94A2B8` | closed arcs (∩∩) | Z z |
| dizzy | pink `#F472B6` | spirals | bubbles |

### Emotes (extra, same body)
`love` (heart eyes), `surprised` (wide), `wink`, `happy`, `annoyed` (line eyes),
`yawn` (closed + Zz), `proud` (star eyes + sparkles), `listening` (wide, attentive).

### Hard rules for animators
- The silhouette **never grows a limb**, never stretches into a rectangle, never becomes a
  different creature. Morphs (e.g. the mailbox/file-slot form) are a separate sanctioned
  transformation and must return to the exact base geometry.
- Between any two states, the body path is identical and interpolates from the same
  control points — the body is drawn from **one** path, always.
- Eyes are drawn clipped to the body. They never overflow the silhouette.
- Blink = vertical squash of the capsules; it must never turn them into dots.

## 4. Production pipeline

1. **Geometry lives in one place:** `docs/concepts/lupy-character-spec-v1.json`
   (symmetrised outline + measured eye/blush numbers). Any generator reads this file; no
   one hand-keys the shape again.
2. **Design-time renders:** `tools/character/render_states.py` draws all 19 states from the
   spec → `docs/concepts/states/` + contact sheet `docs/concepts/lupy-character-states.png`.
   This is how variations are explored without the character drifting.
3. **Approved renders become locked references.** Any AI image generation for Lupy must
   pass `lupy-master-M2-softapex.png` (and the idle crop) as input references. Never
   generate Lupy from text alone.
4. **Shipping code draws procedurally**, the way Coucou's `BotEngine` does — same geometry,
   real-time, resolution independent. Reference engineering:
   `Mac/Sources/CoucouKit/BotEngine.swift` (`mochiPath` superellipse,
   `MochiConst.eyeW/eyeH/eyeSp/eyeP`, `EyeShape` enum, `BotStates` table).
   **Our numbers differ from Coucou's** (their eye is 0.25×0.27 of R; Lupy's is
   0.139×0.2888 of body width, clearly taller) — copy the *approach*, never the values.

## 5. Quality bar

- Same rig/animation quality and interactivity as Coucou — *"same quality nothing less like
  better way"*. Idle breathing, blinks, gaze that follows the mouse, tilt, bounce, particles.
- Apple-grade polish. Nothing flat and cheap.
- The character is branding: **there is no chance for a character error.** When unsure,
  ask the founder — never ship a guess.

## 6. Open questions for the founder

- Pupil-less capsules confirmed forever, even at large sizes? (Working assumption: yes.)
- Should the halo be colour-tinted per state, or stay neutral white? (Current: tinted.)
- Character naming in code: rename `Mochi*` types to `Lupy*` during the Phase 3 dismantle,
  or keep type names and only change user-facing strings? (Proposal: rename in Phase 3.)
