# LUPY 3 — your check list, in order

Everything below is what you should SEE on your Mac (Sequoia 15.7.4, your M1 2020).
If any step looks different: screenshot it, circle it, send it. That's your whole job;
the rest is proven by 1,298 automated checks before it reaches you.

**Run it once:** Terminal → `git clone -b arena/47c739ab-lupy https://github.com/buildthewayback/lupy.git lupy3 && cd lupy3 && bash scripts/run-mac.sh` → Xcode opens → **⌘R**. Say yes to any permission prompts.

1. **The capsule.** Top centre, 4 pt under the menu bar (your Mac has no notch): a dark
   pill with LUPY in it, breathing. No text. Move your mouse around — he stays put.
2. **Demo mode** (app menu bar → *Demo mode*): the island **grows** from the capsule —
   one spring, no teleport — into a card. You'll see an approval card: command in mono,
   session line, **Allow once** / **Deny**.
3. **Answer it:** click *Deny* (or press **⌘N**) — the island melts back to the capsule.
   Demo again and press **⌘Y** — same, the other way. The shortcuts were never printed
   on the buttons; they just work, like macOS.
4. **Talk to him:** click the typing line, write anything, press return. The band shows
   one animated line (*Thinking…* with breathing dots), then the conversation surface
   opens with your words and his answer. (Needs your chat provider keys set in
   Settings, same as v0.2 — without keys you'll get the error card, which is also
   correct behaviour and also worth circling if it looks ugly.)
5. **The glass:** change your wallpaper to something white, then something black.
   The island stays readable on both — that's the derived-alpha law, not luck.
6. **Accessibility:** System Settings → Accessibility → Display → *Reduce transparency*
   ON: the glass becomes a solid, designed dark surface — never clear, never broken.
   OFF again: glass returns.
7. **Old island, for comparison:** Terminal →
   `defaults write com.tinyastronauts.lupy lupy3LegacyIsland -bool true` (your bundle id
   may differ — ask me if the command bounces), relaunch: v0.2 island returns untouched.
   `-bool false` brings LUPY 3 back.

**When Arena needs compile evidence (or you want the app without Xcode):** one more
line in Terminal, from inside the `lupy3` folder:

```
bash scripts/build-mac-app.sh && bash scripts/smoke-mac-app.sh
```

It builds the real `Lupy.app` and then checks it like a picky user: does it launch,
does the window appear, does LUPY actually move. If anything prints **red text**:
copy everything from the first red line to the end and paste it to Arena. The fix
comes back here; you run the line again. Thirty seconds a loop, zero dollars.

Circle anything. The council (three of them: pictures, all-surfaces, wiring) and I
will fix exactly what you circle, and only that.
