# Coucou artwork in this folder — private, personal build only

This folder holds artwork from **Coucou** (https://github.com/Louis-CFM/coucou), © 2026 Louis Raillé,
covered by Coucou's `LICENSE-ASSETS.md` (copied here), not by the MIT licence of Coucou's code:

- `Assets.xcassets/AppIcon.appiconset` — **no longer Coucou artwork**: since
  2026-10-20 these PNGs are Lupy's own icon, forged from his locked character by
  `tools/ui/make_appicon.py` (see `Mac/LupyAppIcon/README.md`). The folder and set
  name are unchanged so `Mac/project.yml` and both build roads work untouched.
- `Assets.xcassets/MenuBarIcon.imageset` — the menu-bar icon (still Coucou's);
- `sounds/` — the 29 Coucou sounds (still Coucou's).

The Mochi character itself is drawn by Coucou's code. The files that embody it (its design,
expressions and animations) are `Mac/Sources/CoucouKit/BotEngine.swift`, `MochiOutfitDrawing.swift`,
`MochiMood.swift`, `MochiStill.swift`, `MochiWardrobe.swift`, `Mac/Sources/App/BotCanvasView.swift`,
`DesktopMochi.swift`, `GreetingCanvasView.swift` and `FlowHubMochis.swift`.

**Why it is here.** The founder decided on 2026-10-16 to restore Coucou's original character,
icon and sounds in Lupy for his own use, on his own Mac, in a private repository: never published,
shared, sold or distributed. Coucou's asset terms allow building and running Coucou for yourself;
they do not explicitly cover a modified private build, and the founder accepted that.

**To distribute Lupy** (or share a build with anyone): replace this folder and the Mochi drawing
with Lupy's own artwork, or obtain written permission from Louis Raillé (raillelouis@gmail.com).
Swapping the folder needs no other code change except the files listed above for the character.
