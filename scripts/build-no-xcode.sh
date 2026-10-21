#!/usr/bin/env bash
# LUPY without Xcode — the founder's low-data road. See Mac/Package.swift's header:
# Command Line Tools carry the compiler; this script builds with SwiftPM and assembles
# the .app bundle by hand (Info.plist stamped below, menu-bar icon + sounds as loose
# resources), ad-hoc signs, launches. Xcode stays the reference build; same binary.
set -euo pipefail
cd "$(dirname "$0")/../Mac"
mkdir -p ../build-noxcode
LOG=../build-noxcode/build.log
# Credential silence. Everything SwiftPM fetches for this build is PUBLIC
# (FluidAudio's repo + its ready-made component), so no download may ever ask
# about passwords. Left alone, git's osxkeychain helper pops a macOS keychain
# window for github.com mid-fetch (it froze the founder's first 3.2 build for
# ~33 min — build.log: "Fetched ... (1995.92s)"), and SwiftPM's own keychain
# lookup turns a dismissed prompt into the fatal "Failed to find credentials
# for 'https://github.com' in keychain: status -128". The belt, all
# env-scoped so the founder's git/keychain setup is never modified:
#   · git: never prompt; credential-helper list reset to empty (Apple's git
#     defaults to osxkeychain — an empty value disables it for our processes);
#   · SwiftPM: --disable-keychain (its own first-party off-switch for the
#     keychain authorization lookup; probed in case a future name changes).
export GIT_TERMINAL_PROMPT=0
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0=credential.helper
export GIT_CONFIG_VALUE_0=
export GIT_CONFIG_KEY_1=credential.https://github.com.helper
export GIT_CONFIG_VALUE_1=
# Native architecture, forced. The founder's first 3.3 field report reads
# "macOS 15.7.4 · x86_64" on his APPLE SILICON Mac: LaunchServices runs a
# script-based .app under Rosetta translation, so everything beneath the
# installer inherited a pretend-Intel world — and SwiftPM builds for the
# architecture it thinks it is. Left alone, the rebuild would have produced
# an Intel Lupy (or failed linking an arm64-only component). `arch -arm64`
# makes the toolchain itself run native whatever the parent shell believes;
# Intel Macs never reach this line (the installer's preflight refuses them).
SWIFT="arch -arm64 swift"
SWIFT_AUTH_FLAGS=""
if $SWIFT build --help 2>/dev/null | grep -q -- '--disable-keychain'; then
  SWIFT_AUTH_FLAGS="--disable-keychain"
fi
# Progress for the double-click installer (Install LUPY.app's face reads this
# file; the installer refines the long compile stretch from build.log itself).
# Unset = silent; the .command road is unchanged.
status() { if [ -n "${LUPY_INSTALL_STATUS_FILE:-}" ]; then printf '%s|%s|%s\n' "$1" "$2" "${3:-}" > "$LUPY_INSTALL_STATUS_FILE" || true; fi; }
echo "== swift build -c release (first run fetches FluidAudio; some minutes of text)"
status 25 "Compiling LUPY" "first build also downloads one small library (needs internet)"
if ! $SWIFT build $SWIFT_AUTH_FLAGS -c release > "$LOG" 2>&1; then
  echo "BUILD FAILED — last lines:"; tail -40 "$LOG"; exit 1
fi
BIN=$($SWIFT build $SWIFT_AUTH_FLAGS -c release --show-bin-path)
# stamp the truth into the log (it lands in the founder's install report):
{ echo "== built binary (must say arm64):"; file "$BIN/Lupy"; } >> "$LOG" 2>&1 || true
status 70 "Assembling Lupy.app" "his face, his sounds, his name"
APP=../build-noxcode/Lupy.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Lupy" "$APP/Contents/MacOS/Lupy"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# the plist carries Xcode variables; Xcode expands them at build time, this
# road must stamp the same values by hand. Without this, LaunchServices looks
# for a program literally named "$(EXECUTABLE_NAME)" and the installed app
# "cannot be opened because its executable is missing" — proven by the CI
# oracle on macOS 15.7.9 (2026-10-21) BEFORE it could cost a founder run.
# No "|| true": if the stamp fails, the build must fail loudly here.
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Lupy" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion en" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
# his face: the forged icon of the locked character (tools/ui/make_appicon.py).
# Info.plist names it via CFBundleIconFile=AppIcon; without this copy the
# hand-assembled bundle would wear macOS's generic icon — never, per brand law.
# (This line was once lost between an editing tool and a merge without anyone
# noticing; body-checks step 6a now refuses green if it ever goes missing.)
cp LupyAppIcon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# named image lookups read loose files in Resources: give the icon its catalogue name
cp CoucouAssets/Assets.xcassets/MenuBarIcon.imageset/menubar@2x.png "$APP/Contents/Resources/MenuBarIcon.png"
cp -R CoucouAssets/sounds "$APP/Contents/Resources/sounds"
codesign --force -s - "$APP" 2>/dev/null || true
if [ "${1:-}" = "--install" ]; then
  echo "== installing to /Applications"
  status 90 "Installing into Applications" "placing him next to your other apps"
  rm -rf /Applications/Lupy.app
  cp -R "$APP" /Applications/Lupy.app
  # he was compiled on THIS Mac: no quarantine nag, and make Finder/Dock pick up
  # his icon + name now, not after a logout (stale icon caches are the classic
  # "generic icon" trap for hand-installed apps).
  xattr -dr com.apple.quarantine /Applications/Lupy.app 2>/dev/null || true
  touch /Applications/Lupy.app
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Lupy.app 2>/dev/null || true
  status 97 "Launching LUPY" "look at the top centre of your screen, under the menu bar"
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
