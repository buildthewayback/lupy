# Why the status bubble moves the way it does

Short notes from the research that shaped it, so the reasons survive.

## Three dots, not a frozen "…"

A static ellipsis is indistinguishable from a crashed app. The established pattern
is three dots that light in sequence:

- **stagger = one third of the cycle**, so the dots read as one travelling wave
  instead of three separate blinks;
- **never rest at opacity 0** — dots that vanish make the bubble look empty for
  most of the cycle, so the resting dots sit at 0.28;
- **one clock drives all three** (a single `TimelineView`), not three independent
  animations that drift when the window is occluded and resumed;
- **Reduce Motion is honoured**: the wave stops, the text stays, no information is
  lost.

## Transitions

A new state slides in from the leading edge with a short spring
(`response 0.34, damping 0.86`) and fades out — it never pops. The bubble is keyed
on the state (`id(state)`), so SwiftUI treats a state change as a replacement
bubble rather than a text mutation, which is what allows the slide at all.

## Type and surface

- The sentence is the only thing at full white; everything around it is 0.10–0.16
  white, so the eye lands on the words first.
- The capsule is a two-stop vertical gradient with a bright top edge: that is what
  makes it read as glass under a light source instead of a flat card.
- The state's colour appears on the bubble only as a **0.30 hairline rim**, never as
  a fill — the colour has to stay the character's, not the bubble's.
- The tail points at him and stops short of touching him.

## Crispness

The founder's note was that the character looked pixelated. Cause: scenes were
rasterised at final size and then shown at 2x. Now every sheet and the GIF draw at
**4x (sheets) / 2x (animation) and down-sample with LANCZOS**, and the in-app
renderer stays fully vector. A vector character rendered through a fixed-resolution
bitmap is a bitmap; that was the bug, not the Bézier maths.

PIL's `joint="curve"` spikes when the stroke is far thicker than the point spacing,
which is exactly the case for Lupy's fat eye arcs — so the offline renderer now
**stamps** strokes (overlapping discs) instead of line-joining them.
