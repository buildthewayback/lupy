# Mac/LupyAppIcon — LUPY's own app icon, forged not pasted

`AppIcon.icns` and `AppIcon-1024.png` in this folder are **generated** — never edit
them by hand and never paste in an icon from anywhere else.

- **Forge:** `python3 tools/ui/make_appicon.py` — renders the locked character
  (geometry parsed live from `Mac/Sources/Lupy/Character/LupyGeometry.swift`,
  law in `docs/LUPY_BRAND_CHARACTER.md`) into:
  - this folder's `AppIcon.icns` (the no-Xcode road: `scripts/build-no-xcode.sh`
    copies it into `Lupy.app`, `Mac/Resources/Info.plist` names it),
  - `Mac/CoucouAssets/Assets.xcassets/AppIcon.appiconset/` (the Xcode road),
  - `Install LUPY.app/Contents/Resources/AppIcon.icns` (the installer's face).
- **Check:** `python3 tools/ui/make_appicon.py --check` — also step 6a of
  `scripts/body-checks.sh`; the shipped icon must equal the locked character,
  byte for byte.

This icon is Lupy's own artwork (the founder's character). It replaced Coucou's
icon on 2026-10-20 as the first step of the distribution swap described in
`Mac/CoucouAssets/NOTICE.md`.
