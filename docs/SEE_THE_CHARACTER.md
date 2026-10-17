# Where to look — LUPY character (non-technical)

Everything below is a click. No tools, no terminal, unless you want to run the app.

## 1. Watch him move (animated)

https://github.com/buildthewayback/lupy/blob/arena/47c739ab-lupy/docs/concepts/lupy-rig-interaction.gif

GitHub plays the GIF right in the page. This is the **real Swift rig** — the exact
geometry the app draws — driven along a mouse path at 60 frames a second.

## 2. The 11 states

https://github.com/buildthewayback/lupy/blob/arena/47c739ab-lupy/docs/concepts/lupy-rig-states.png

idle · working · thinking · searching · approval · question · error · finished ·
rate_limit · sleeping · dizzy

Each state changes **only** three things: the eye shape, the colour of the light
around him, and one small badge. The body never changes. It stays pure white.

## 3. How he looks small (notch sizes)

https://github.com/buildthewayback/lupy/blob/arena/47c739ab-lupy/docs/concepts/rig-notch-legibility.png

Shown at **actual size**: 24 px, 32 px, 64 px, 128 px. Both eyes are still readable
at 24 px, which is what the menu bar needs.

## 4. Get the Mac app

1. Open https://github.com/buildthewayback/lupy/actions/runs/39013132829
2. Scroll to the bottom, section **Artifacts**
3. Click **Lupy-0.2.0-7f93a64d77-macOS-arm64.zip** (GitHub downloads it)
4. Double-click the zip, then drag **Lupy.app** to Applications
5. First launch: **right-click → Open** (the app is ad-hoc signed, not notarised)

## 5. See the character on its own (best way to judge him)

In Terminal:

```
/Applications/Lupy.app/Contents/MacOS/Lupy --character-preview
```

A window opens with only LUPY. **Move your mouse around it** — the eyes follow you.
Resize the window from tiny to huge: he stays sharp, because he is drawn from
curves, not pixels.

## What is not done yet

- The emotes (love, wink, surprised, proud, annoyed, yawn, listening, happy) are
  designed but not wired into the app.
- The island UI (the horizontal smart canvas) is still Coucou's.
- Dizzy's spiral turns are static — no rotation yet.
