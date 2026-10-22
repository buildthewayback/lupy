#!/usr/bin/env bash
# Build the SELF-CONTAINED Install LUPY app.
#
# The repository app is only the installer shell: at package time this script
# puts a complete, SHA-256-verified source kit inside the staged app at
# Contents/Resources/LupyKit.zip. The clicked app therefore keeps working when
# macOS translocates it, when it is launched from a DMG, or when it is copied
# completely away from the folder it was downloaded with.
#
# Outputs (default: dist/installer/):
#   LUPY-Installer-<installer-version>-<commit>-macOS-arm64.dmg
#   LUPY-Installer-<installer-version>-<commit>-macOS-arm64.zip
#   matching .sha256 files, BUILD_INFO.txt, self-test transcripts
#
# macOS only (ditto, hdiutil, PlistBuddy are the packaging tools).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "package-installer.sh must run on macOS" >&2
  exit 2
fi
for tool in ditto hdiutil shasum git /usr/libexec/PlistBuddy; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing packaging tool: $tool" >&2; exit 2; }
done

OUT="${1:-dist/installer}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
rm -rf "$OUT/stage" "$OUT"/LUPY-Installer-*.dmg "$OUT"/LUPY-Installer-*.zip \
       "$OUT"/LUPY-Installer-*.sha256 "$OUT/BUILD_INFO.txt" "$OUT"/*.txt
mkdir -p "$OUT/stage"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' 'Install LUPY.app/Contents/Info.plist')"
COMMIT="$(git rev-parse --short=10 HEAD 2>/dev/null || echo local)"
FULL_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
NAME="LUPY-Installer-${VERSION}-${COMMIT}-macOS-arm64"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/lupy-package.XXXXXX")"
MOUNT="$WORK/mount"
MOUNTED=0
cleanup() {
  if [ "$MOUNTED" = "1" ]; then
    hdiutil detach -quiet "$MOUNT" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "== Snapshotting the complete source kit"
PAYLOAD_SRC="$WORK/source/lupy-kit"
mkdir -p "$PAYLOAD_SRC"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Tracked files plus untracked, non-ignored files: exactly the source tree a
  # release checkout has, and safe to use from a developer tree before commit.
  git ls-files -co --exclude-standard -z | while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    mkdir -p "$PAYLOAD_SRC/$(dirname "$f")"
    cp -p "$f" "$PAYLOAD_SRC/$f"
  done
else
  echo "package-installer.sh needs a git checkout so the payload is exact" >&2
  exit 2
fi
# The payload's own installer must not contain a nested packaged payload.
rm -f "$PAYLOAD_SRC/Install LUPY.app/Contents/Resources/LupyKit.zip" \
      "$PAYLOAD_SRC/Install LUPY.app/Contents/Resources/LupyKit.sha256"
for required in \
  "$PAYLOAD_SRC/scripts/build-no-xcode.sh" \
  "$PAYLOAD_SRC/Mac/Package.swift" \
  "$PAYLOAD_SRC/LupyCore/Package.swift" \
  "$PAYLOAD_SRC/Install LUPY.app/Contents/MacOS/Install-LUPY"; do
  test -f "$required" || { echo "payload is missing: $required" >&2; exit 1; }
done

ditto -c -k --keepParent "$PAYLOAD_SRC" "$WORK/LupyKit.zip"
(cd "$WORK" && shasum -a 256 LupyKit.zip > LupyKit.sha256)
PAYLOAD_SHA="$(cut -d' ' -f1 "$WORK/LupyKit.sha256")"

echo "== Staging the self-contained installer app"
STAGE="$OUT/stage"
ditto "Install LUPY.app" "$STAGE/Install LUPY.app"
cp "$WORK/LupyKit.zip" "$STAGE/Install LUPY.app/Contents/Resources/LupyKit.zip"
cp "$WORK/LupyKit.sha256" "$STAGE/Install LUPY.app/Contents/Resources/LupyKit.sha256"
cp README-INSTALL.txt "$STAGE/READ ME FIRST.txt"

# The installer executable is intentionally left as the field-proven shell
# app. An ad-hoc signature gives no Gatekeeper benefit without Developer ID
# notarization and can make a script bundle's launch validation less, not
# more, predictable. Integrity here is the payload SHA-256 plus the published
# DMG/ZIP SHA-256 files; the locally built Lupy.app is ad-hoc signed later by
# build-no-xcode.sh on the founder's own Mac.
echo "== Installer integrity: payload SHA-256 $PAYLOAD_SHA"

self_test_app() { # $1 app path · $2 transcript name · $3 fake HOME
  local app="$1" transcript="$OUT/$2" fake_home="$3"
  mkdir -p "$fake_home/Downloads" "$fake_home/Desktop" "$fake_home/Documents"
  HOME="$fake_home" LUPY_INSTALLER_NONINTERACTIVE=1 \
    "$app/Contents/MacOS/Install-LUPY" --self-test-kit > "$transcript" 2>&1
  grep -qx 'LUPY_KIT_OK' "$transcript"
  grep -qx 'ORIGIN=embedded payload' "$transcript"
}

launchservices_self_test_app() { # $1 app · $2 transcript · $3 fake HOME · $4 TMPDIR root
  local app="$1" transcript="$OUT/$2" fake_home="$3" tmp_root="$4"
  mkdir -p "$fake_home/Downloads" "$fake_home/Desktop" "$fake_home/Documents" "$tmp_root"
  rm -f /tmp/lupy-install.log
  # This is the actual Finder/LaunchServices route, not a terminal invocation:
  # it proves Info.plist really names a launchable executable in the bundle.
  open -W -n \
    --env "HOME=$fake_home" \
    --env "TMPDIR=$tmp_root" \
    --env "LUPY_INSTALLER_NONINTERACTIVE=1" \
    "$app" --args --self-test-kit > "$transcript" 2>&1
  grep -q 'payload: verified embedded kit' /tmp/lupy-install.log
  { echo "LAUNCHSERVICES-SELF-TEST-OK"; grep 'payload: verified embedded kit' /tmp/lupy-install.log; } >> "$transcript"
}

echo "== Self-testing the staged app alone in a deep translocation-shaped root"
ISOLATED="$WORK/Private Folders/AppTranslocation/RANDOM/d"
mkdir -p "$ISOLATED"
ditto "$STAGE/Install LUPY.app" "$ISOLATED/Install LUPY.app"
self_test_app "$ISOLATED/Install LUPY.app" self-test-isolated.txt "$WORK/Fake Home Isolated"
launchservices_self_test_app "$ISOLATED/Install LUPY.app" self-test-launchservices.txt "$WORK/Fake Home LaunchServices" "$WORK/LaunchServices TMP"

echo "== Building the DMG"
DMG="$OUT/$NAME.dmg"
hdiutil create -volname "Install LUPY" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null
mkdir -p "$MOUNT"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$DMG" >/dev/null
MOUNTED=1
test -x "$MOUNT/Install LUPY.app/Contents/MacOS/Install-LUPY"
test -f "$MOUNT/Install LUPY.app/Contents/Resources/LupyKit.zip"
self_test_app "$MOUNT/Install LUPY.app" self-test-dmg.txt "$WORK/Fake Home DMG"
hdiutil detach -quiet "$MOUNT"
MOUNTED=0

echo "== Building the ZIP"
ZIPROOT="$WORK/ziproot/LUPY Installer"
mkdir -p "$ZIPROOT"
ditto "$STAGE/Install LUPY.app" "$ZIPROOT/Install LUPY.app"
cp "$STAGE/READ ME FIRST.txt" "$ZIPROOT/READ ME FIRST.txt"
ZIP="$OUT/$NAME.zip"
ditto -c -k --keepParent "$ZIPROOT" "$ZIP"
ZIPCHECK="$WORK/zipcheck"
mkdir -p "$ZIPCHECK"
ditto -x -k "$ZIP" "$ZIPCHECK"
self_test_app "$ZIPCHECK/LUPY Installer/Install LUPY.app" self-test-zip.txt "$WORK/Fake Home ZIP"

(cd "$OUT" && shasum -a 256 "$NAME.dmg" > "$NAME.dmg.sha256")
(cd "$OUT" && shasum -a 256 "$NAME.zip" > "$NAME.zip.sha256")

{
  echo "LUPY self-contained installer $VERSION"
  echo "commit: $FULL_COMMIT"
  echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(sw_vers -productName) $(sw_vers -productVersion) ($(uname -m))"
  echo "payload: LupyKit.zip embedded in Install LUPY.app/Contents/Resources"
  echo "payload sha256: $PAYLOAD_SHA"
  echo "dmg: $NAME.dmg ($(stat -f %z "$DMG") bytes)"
  echo "dmg sha256: $(cut -d' ' -f1 "$OUT/$NAME.dmg.sha256")"
  echo "zip: $NAME.zip ($(stat -f %z "$ZIP") bytes)"
  echo "zip sha256: $(cut -d' ' -f1 "$OUT/$NAME.zip.sha256")"
  echo "self-tests: isolated translocation-shaped root (direct + LaunchServices), mounted DMG, unzipped ZIP"
  echo "installer signing: unsigned shell app (payload and downloads SHA-256 verified; final Lupy.app is built and ad-hoc signed on the user's Mac)"
} > "$OUT/BUILD_INFO.txt"

echo "PACKAGE-INSTALLER-OK"
cat "$OUT/BUILD_INFO.txt"
