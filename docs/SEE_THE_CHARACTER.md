# Where to look — LUPY character (non-technical)

Everything below is a click. No tools, no terminal, unless you want to run the app.

## 1. Watch him work (animated, 7 seconds)

https://github.com/buildthewayback/lupy/blob/arena/47c739ab-lupy/docs/concepts/lupy-rig-story.gif

GitHub plays the GIF right in the page. This is the **real Swift rig** — the same
code the app draws with — stepped frame by frame while a mouse moves across him:

1. **Ready** — white. Nothing is happening.
2. **Working…** — blue. The eyes follow the pointer.
3. **Overloaded** — pink, spiral eyes. The Mac ran out of memory.
4. **Done** — mint, closed happy eyes.

Watch the little bubble above his head: it always says what he is doing.

## 2. Every state, with colour

https://github.com/buildthewayback/lupy/blob/arena/47c739ab-lupy/docs/concepts/lupy-states-coloured.png

Eleven states, six per row. The colour is the first thing you see — that is the
point. You should be able to tell "working" from "broken" from across the room
without reading a word:

- white — ready
- blue — working
- violet — thinking
- indigo — searching
- amber — waiting for your OK
- cyan — has a question
- red — something broke
- mint — done
- orange — rate limited
- grey-blue — asleep
- pink — overloaded

The eyes are always solid black capsules. A state can reshape them (a slit, a
dash, a smile, a spiral) but never gives them pupils, highlights or gloss.

## 3. When the Mac itself is struggling

https://github.com/buildthewayback/lupy/blob/arena/47c739ab-lupy/docs/concepts/lupy-states-coloured-machine.png

Four states driven by real system readings, not by a task:

- **Calm** — nothing is wrong.
- **CPU pinned** — the processor has been above 80 % for two readings in a row.
  He breathes faster and trembles.
- **RAM critical** — memory pressure hit critical. He goes pink with spiral
  eyes, exactly as you asked.
- **Too hot** — the Mac is thermally throttled. A warm flush.

## 4. How he looks small (menu bar)

https://github.com/buildthewayback/lupy/blob/arena/47c739ab-lupy/docs/concepts/rig-notch-legibility.png

Shown at **actual size**: 24 px, 32 px, 64 px, 128 px. Both eyes are still
readable at 24 px, which is what the menu bar needs.

## 5. Run it on your Mac

1. Open this page and download the newest build:
   https://github.com/buildthewayback/lupy/actions/workflows/mac-build.yml
2. Unzip it, then drag **Lupy.app** into Applications.
3. Open Terminal (⌘-Space, type "Terminal"), paste this line, press Return:

   ```
   /Applications/Lupy.app/Contents/MacOS/Lupy --character-preview
   ```

A window opens with the character, a bubble above his head, and a row of chips
at the bottom.

- **Click any chip** to see that state.
- **← →** arrow keys walk through all eleven.
- **Live** hands him over to your actual Mac: you will see the real processor,
  memory pressure and battery change his mood.

Resize the window from tiny to huge — the shape is vector geometry, so it stays
sharp at every size.

## 6. What is not built yet

Outfits, and the island itself. The character comes first, then the island, then
the assistant behind it.
