# THE ISLAND LAW — how LUPY's canvas decides what it is (18 Oct 2026)

Supersedes the fixed-height table (`IslandConst.viewLayouts`) wherever the two disagree.
The table was 22 hand-tuned heights; the founder's rule is that **the canvas grows per
need, never fixed**. A growth rule cannot live in a table. It lives in
`Mac/Sources/Lupy/UI/LupyIslandDesign.swift`, and it is tested.

## Why a kernel, and why now

GitHub Actions stopped paying for itself mid-rebuild ("recent account payments have
failed"), and the founder's instruction was right: *GitHub is a file shelf, not a
gatekeeper.* So the island's rules were written as **pure math** — no SwiftUI, no
Foundation — exactly like the character kernel. That means:

    node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --run \
      Mac/Sources/Lupy/Character/LupyGeometry.swift \
      Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
      Mac/Sources/Lupy/UI/LupyIslandDesign.swift \
      tools/ui/design_tests.swift          →  DESIGNTESTS PASSED (473 checks)

on any machine, in seconds, with no CI and no Mac. On the founder's Mac the same tests
run natively: `tools/ui/test-design.sh`.

The picture is proven the same way. `tools/ui/layout_emit.swift` prints every rectangle
the law computes; `tools/ui/render_island.py` only fills those rectangles (plus LUPY,
from the rig's emitted geometry). Nothing in the proof images is drawn by hand, so a
wrong pixel means a wrong law:

    docs/concepts/lupy-island-glass.png      the glass, over both desktops it can float on
    docs/concepts/lupy-island-canvas.png     the growth law, avatar-first
    docs/concepts/lupy-island-surfaces.png   the answer / chat / question / error / voice canvases
    docs/concepts/lupy-island-all.png        every surface at once

## The rules, as assertions

1. **Avatar-first.** Rest *is* the device's notch band — LUPY centred under the camera,
   20 pt, motion and colour only. No text: at that size text is mush and state must read
   in a quarter second.
2. **The canvas grows per need.** Size is a function of what the card must show
   (`LupyCanvasNeed`), never of which screen is open. Stepped on an 8 pt grid, so it
   never jitters. Rounding is *up*: rounding a height down rounds a card row out of its
   own box — the same family of bug as the label the island's corner once ate.
3. **Horizontal law.** `maxWidth (816) > maxHeight (416)`, and if content ever asks for
   more height than the cap, the canvas buys the room back sideways. A portrait island is
   a phone panel; the founder rejected phone panels twice. When even that is not enough,
   the card scrolls — a decision, not an accident.
4. **Composer is the only permanent control.** Present in every open canvas, at the
   foot, full width; absent while collapsed. No toolbars, no tab bars.
5. **One status sentence, one home.** `.motion` (rest), `.whisper` (one line beside him
   in the compact band, drawn as island UI type at 13 pt), or `.headline` (the card's
   first line). Never two at once. The character's body-relative bubble is *not* used
   inside the island: it scales off his width and is unreadable below 46 pt — which is
   exactly why it kept getting sliced by the island's rounded corner ("…your OK").
6. **The status sentence survives the clip.** `LupyBox.containsRounded` tests the four
   corners against the rounded rectangle, which is what `clipShape(IslandShape)`
   actually does. The naive first version of that test was wrong in both directions and
   the picture caught it.
7. **LUPY's face is the law's problem too.** The island hands him a frame; the character
   fits his body at `min(w,h) × 0.72` inside it. Below 30 pt of *body* his ∪∪ fuses into
   one dash, so the island's 46 pt frame (33 pt body) is the smallest that keeps his face
   his face — with margin, tested.
8. **Glass is derived, not decorated.** See below.
9. **Two colour families, kept apart.** Milkinside is the room; LUPY's vivid status RGB
   is the meaning. A Milkinside tone never means a state and a status colour is never
   chrome. The app's accent *is* his working blue #0A84FF — one colour, one meaning.
   No mango, no Coucou orange, in any role that means something.

## The glass, argued

Synvy Neuro is the style target: dark glassmorphism, frosted cards, soft glow, rounded
corners. The craft recipe (blur + saturation boost, 10–25% white hairline, soft shadow,
8–24 pt radius) is craft. The one number that is *arithmetic* is the fill's opacity.

The island floats over the desktop, which can be a white document or a black terminal.
A translucent dark panel loses contrast against a bright desktop, so text legibility
depends on what is behind it. Measured over Milkinside ink `#253256`:

| text            | min opacity for WCAG AA (4.5:1) |
|-----------------|---------------------------------|
| paper #FFFFFF   | 0.66                            |
| chalk #C0C5D4   | 0.84  ← at that opacity there is no glass left |
| mist  #989FAB   | 0.98  ← effectively a solid rectangle          |

Two levers trade against each other: base depth and fill opacity. Deepening the base buys
the transparency back. At **0.55 toward black** (`LupyGlass.panelDepth`, base `#111627`),
body text clears AA at **0.78 opacity** — 22% of the desktop still comes through, blurred
28 pt and saturation-boosted 1.55×, which is what makes it read as glass and not as a
dark rectangle. Both numbers are solved by bisection from the contrast floor, and the
tests pin the trade-off (a lighter base must need at least as much opacity) and the
identity (the base must stay blue-family, never neutral black).

Consequence for the palette, proven not promised: of Milkinside's seven tones only two
may carry a word — `paper` (primary) and `chalk` (body). `mist` reaches only 3.4:1, which
is WCAG's *large-text* floor and nothing on the island is large text, so it draws icons,
dividers and disabled affordances. `fog` clears nothing and draws structure. A grey that
cannot be read is not a quieter design, it is a broken one.

## Adoption

`Mac/Sources/Lupy/UI/LupyIslandCanvas.swift` is the SwiftUI face of the law: glass
surfaces, type ramp, the composer, and `LupyCanvasChrome`, which lays out LUPY, the
status sentence, the card and the composer from `canvas(need:)`. Views move onto it **one
use case at a time, with the founder's approval each**, because a canvas frame must
follow the content actually drawn in it — switching a view's frame before its content
moves would give him dead space or a clipped card. `LupyIslandNeedMapping` records the
judged mapping from every `IslandView` to its need.

## What the law will not do

- Invent a silhouette: rest follows the device's own notch width, tested at 120–320 pt.
- Show a control "just in case": progressive disclosure is asserted (collapsed canvases
  carry no composer and no card).
- Say anything twice: two surfaces for one sentence is a test failure.
- Let any text drop below 11 pt, the measured mush floor from the character work.
