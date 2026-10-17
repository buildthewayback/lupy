# Coucou, studied properly — and what LUPY takes from it

Read from `Louis-CFM/coucou` at `434d6a2` (224 Swift files, ~64k lines). This is the
map of **why the character exists**, not a list of its code.

## 1. The character is not decoration. It is an instrument.

Mochi is the **readable output of a machine**. Three independent systems write into
him, in this priority:

| Input | Written by | What the user sees |
|---|---|---|
| **Agent state** (what a task is doing) | `AppState.focusTask.state` → `BotState` | eye shape, glow colour, island text |
| **Machine mood** (how the Mac feels) | `MachineVitals` → `MochiMood` | sweat, flush, puffing, tired lids, sleep |
| **Emotes** (momentary) | `BotEngine.triggerEmote` | short bursts: love, wink, proud, yawn |

The point: a glance at Mochi answers *"is anything wrong, and is it still working?"*
That is why he must be readable in a fraction of a second. Shape alone is not
enough — **colour is the fastest channel**, which is why every state owns a colour.

## 2. The state machine

`BotState` has exactly 11 cases — the same 11 as our sheet:
`idle, working, thinking, searching, approval, question, error, finished, ratelimit, sleeping, dizzy`.

Only four things change between states (`IslandRootView.botGlowColor`):

- **glow colour** per state — working `#3B9EFF`, thinking `#A78BFA`, searching `#6366F1`,
  approval `#F5A524`, error `#F4505E`, finished `#34D399`, ratelimit `#F59E0B`, else white
- **glow opacity** — 0.15 idle/sleeping, 0.65 everything active, **0.0 dizzy**
- **eye shape** (`BotEngine` + `EyeShape`)
- **one small overlay**

The body path is identical in every state. `bodyColor` exists separately and is used
for **per-agent identity** (each pill/agent has its own hex), not for state.

**LUPY deviation (deliberate):** we tint the body itself by state, because the
founder's rule is "a quarter of a second to understand". The hue is the state; the
pure white body is the *idle* identity.

## 3. Mood: the machine has a body

`MochiMood` — five continuous levels 0…1, sampled every 3 seconds:

```
busy  = CPU ≥ 80% for two consecutive samples → min(1, (cpu − 0.6) / 0.3)
hot   = ProcessInfo.thermalState: fair .4 · serious .8 · critical 1
full  = memory pressure: warning .6 · critical 1
tired = battery < 20% and unplugged
asleep = battery < 10% and unplugged
```

Behaviour attached to each:

- **busy** — panics. Hops side to side (0.22–0.4 s, random landing), leans into the
  hop, squashes on landing, eyes dart to random spots every 0.16–0.45 s, nervous
  double-blinks, constant tremble, throws sweat drops.
- **hot** — red gradient flush up the body + three rising heat waves.
- **full** — puffs up: `sx × 1.07`, `sy × 0.965`.
- **tired** — heavy lids, `pitch −= 0.06`, an occasional yawn every ~24 s.
- **asleep** — eyes closed, head down (`pitch −0.14`), a Z every 1.6 s.

Mood only shows in `idle, working, thinking, searching, finished` — never while Mochi
is asking you something (approval/question/error win).

**This is the part we were missing.** *RAM at ceiling ⇒ dizzy, coloured, emotional* is
exactly `full` in Coucou; CPU at ceiling is the panicking/hop behaviour.

## 4. Labels — the island says what is happening

The island is not just a face. `MochiActivityState.statusText` produces the words:

```
working · 3/7   ("working" when no steps)
✓ done
has a question
waiting for your OK
rate limited
error
```

and the hover line under the island is `MochiMood.describe`:
`CPU 94 % · node, Chrome`, `warm`, `memory short`, `battery 12 %`.

So every pixel of state has a **sentence** next to it. That is the "when working show
Working…, when thinking show Thinking…" requirement, and it already has a home.

## 5. Wardrobe

`MochiWardrobe` / `Outfit`: `auto, none, partyHat, beanie, crown, sunglasses,
roundGlasses, bow, scarf, witchHat, pumpkin, santaHat, bunnyEars`.

`auto` resolves by date — Halloween `#witchHat`, December `#santaHat`, New Year
`#partyHat`, Easter ±2 days `#bunnyEars`, summer `#sunglasses` — via the
Meeus/Jones/Butcher Easter algorithm. Accessories are drawn **in the same canvas**,
attached to the body's transform, with lag/centrifugal physics driven by yaw and roll
(`MochiOutfitDrawing`, `MochiH`). They are never sprites.

## 6. Sound

29 WAV cues, one per moment: `greet, hover, pop, tick, send, finish, error, dizzy,
sleep, yawn, gulp, love, proud, wink, …`. Sound is triggered by the *same* events as
the visuals, never independently.

## 7. The frame contract (already implemented in LUPY)

- one engine step per drawn frame, at display rate, clamped
- springs for gaze (`ω₀ 25, ζ 0.6` in Coucou's mouth; `16/0.88` in ours for the eyes)
- NSEvent-level hover/drag, not SwiftUI gestures
- the body is one path, always

## 8. What LUPY takes, and what LUPY does differently

**Takes:** the state set, the colour-per-state idea, mood → body language, the
vitals thresholds, labels + hover line, wardrobe seasons, sound-per-event, the frame
contract.

**Different:** LUPY is an assistant you *work with*, not a status toy — so the states
must also mean *our* work (a task running, a draft waiting for approval, a failing
build). We tint the body by state (faster read), keep the pure-white idle body as
brand, and our silhouette is measured from the founder's own reference.

## 9. What this means for the next build

1. `LupyState` carries **body colour + glow colour + label**, not just eyes.
2. `LupyMood` (busy/hot/full/tired/asleep) drives **body language**, sampled from real
   system signals, with Coucou's thresholds.
3. RAM critical → **dizzy** (spiral eyes, pink, no glow) — the founder's example.
4. Every state shows its **sentence** in the island.
5. Outfits come after the state system is honest.
