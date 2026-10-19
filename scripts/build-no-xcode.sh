#!/usr/bin/env bash
# LUPY without Xcode — the founder's low-data road. See Mac/Package.swift's header:
# Command Line Tools carry the compiler; this script builds with SwiftPM and assembles
# the .app bundle by hand (Info.plist verbatim, menu-bar icon + sounds as loose
# resources), ad-hoc signs, launches. Xcode stays the reference build; same binary.
set -euo pipefail
cd "$(dirname "$0")/../Mac"
mkdir -p ../build-noxcode
LOG=../build-noxcode/build.log
echo "== swift build -c release (first run fetches FluidAudio; some minutes of text)"
if ! swift build -c release > "$LOG" 2>&1; then
  echo "BUILD FAILED — last lines:"; tail -40 "$LOG"; exit 1
fi
BIN=$(swift build -c release --show-bin-path)
APP=../build-noxcode/Lupy.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Lupy" "$APP/Contents/MacOS/Lupy"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
# named image lookups read loose files in Resources: give the icon its catalogue name
cp CoucouAssets/Assets.xcassets/MenuBarIcon.imageset/menubar@2x.png "$APP/Contents/Resources/MenuBarIcon.png"
cp -R CoucouAssets/sounds "$APP/Contents/Resources/sounds"
codesign --force -s - "$APP" 2>/dev/null || true
if [ "${1:-}" = "--install" ]; then
  echo "== installing to /Applications"
  rm -rf /Applications/Lupy.app
  cp -R "$APP" /Applications/Lupy.app
  open /Applications/Lupy.app
  echo "LUPY is in Applications and running — the pill under your menu bar is him."
  exit 0
fi
if [ "${1:-}" = "--no-launch" ]; then
  echo "== built (no launch): $APP"
else
  echo "== launching"
  open "$APP"
  echo "LUPY should now be the pill under your menu bar."
fi
