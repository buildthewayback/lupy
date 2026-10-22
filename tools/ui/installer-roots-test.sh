#!/usr/bin/env bash
# installer-roots-test.sh — every place a downloaded installer can wake up.
#
# The 3.3 field failure behind this test: the founder clicked Install LUPY and
# was told the files were not found. The old resolver only handled the tidy
# cases (kit beside the app, or shallow in Downloads/Desktop/Documents). This
# harness extracts the installer's exact kit-resolution section and drives it
# through the untidy real roots: beside, nested, translocation-shaped, deep
# download folders with spaces, an embedded payload, a bad payload, the newest
# of several kits, an explicit override, and the official-download recovery.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INST="$ROOT/Install LUPY.app/Contents/MacOS/Install-LUPY"
FAILURES=0
CHECKS=0
CASE_ID=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
NEUTRAL="$T/neutral"
mkdir -p "$NEUTRAL"
cd "$NEUTRAL" || exit 1

# Extract the resolver verbatim.
sed -n '/^# ── kit resolution/,/^# ── end kit resolution/p' "$INST" > "$T/kit-resolution.sh"
if ! grep -q 'resolve_kit' "$T/kit-resolution.sh" || ! grep -q 'prepare_payload_kit' "$T/kit-resolution.sh"; then
  echo "FAIL: could not extract kit resolution from Install-LUPY (markers moved?)"
  exit 1
fi

# Globals the extracted section expects from the installer.
HOME="$T/Founder Home"
APP_BUNDLE="$T/isolated/Install LUPY.app"
KIT="$(dirname "$APP_BUNDLE")"
KIT_ORIGIN="unresolved"
KIT_CANDIDATE=""
KIT_PAYLOAD="$APP_BUNDLE/Contents/Resources/LupyKit.zip"
KIT_PAYLOAD_SHA256="$APP_BUNDLE/Contents/Resources/LupyKit.sha256"
KIT_CACHE_DIR="$HOME/Library/Caches/app.lupy.installer"
KIT_URL=""
INSTALLER_NONINTERACTIVE=1
LUPY_INSTALLER_NO_DOWNLOAD=1
unset LUPY_KIT_DIR

compose_face() { :; }
# shellcheck disable=SC1091
. "$T/kit-resolution.sh"

check() { # $1 what · $2 actual · $3 expected
  CHECKS=$((CHECKS + 1))
  if [ "$2" = "$3" ]; then
    echo "  ok   $1"
  else
    FAILURES=$((FAILURES + 1))
    echo "  FAIL $1"
    echo "       expected: $3"
    echo "       actual:   $2"
  fi
}

check_true() { # $1 what · $2 1/0
  check "$1" "$2" "1"
}

make_kit() {
  mkdir -p "$1/scripts" "$1/Mac/Sources" "$1/LupyCore" "$1/Install LUPY.app"
  : > "$1/scripts/build-no-xcode.sh"
  : > "$1/Mac/Package.swift"
  : > "$1/Mac/Sources/.keep"
  : > "$1/LupyCore/Package.swift"
  : > "$1/Install LUPY.app/.keep"
}

make_payload() { # $1 source kit · $2 zip destination
  python3 - "$1" "$2" <<'PY'
import os
import sys
import zipfile

src, dest = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(dest), exist_ok=True)
with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _dirs, files in os.walk(src):
        for name in files:
            path = os.path.join(root, name)
            z.write(path, os.path.join("lupy-kit", os.path.relpath(path, src)))
PY
}

reset_case() {
  CASE_ID=$((CASE_ID + 1))
  HOME="$T/Founder Home $CASE_ID"
  mkdir -p "$HOME/Downloads" "$HOME/Desktop" "$HOME/Documents"
  APP_BUNDLE="$T/isolated/Install LUPY.app"
  KIT="$(dirname "$APP_BUNDLE")"
  KIT_ORIGIN="unresolved"
  KIT_CANDIDATE=""
  KIT_PAYLOAD="$APP_BUNDLE/Contents/Resources/LupyKit.zip"
  KIT_PAYLOAD_SHA256="$APP_BUNDLE/Contents/Resources/LupyKit.sha256"
  KIT_CACHE_DIR="$HOME/Library/Caches/app.lupy.installer"
  KIT_URL=""
  LUPY_INSTALLER_NO_DOWNLOAD=1
  unset LUPY_KIT_DIR
  cd "$NEUTRAL" || return 1
}

expect_resolve() { # $1 what · $2 expected kit · $3 expected origin
  if resolve_kit; then rc=0; else rc=1; fi
  check "$1 resolves" "$rc" "0"
  check "$1 kit" "$KIT" "$2"
  check "$1 origin" "$KIT_ORIGIN" "$3"
}

echo "== 1. Complete-kit validation"
reset_case
PARTIAL="$T/partial"
mkdir -p "$PARTIAL/scripts" "$PARTIAL/Mac/Sources" "$PARTIAL/Install LUPY.app"
: > "$PARTIAL/scripts/build-no-xcode.sh"
: > "$PARTIAL/Mac/Package.swift"
if looks_like_kit "$PARTIAL"; then partial_ok=0; else partial_ok=1; fi
check_true "partial folder without LupyCore is refused" "$partial_ok"

echo "== 2. Beside the installer"
reset_case
BESIDE="$T/beside kit"
make_kit "$BESIDE"
APP_BUNDLE="$BESIDE/Install LUPY.app"
KIT="$(dirname "$APP_BUNDLE")"
expect_resolve "beside app" "$BESIDE" "beside installer"

echo "== 3. Installer nested below the kit root"
reset_case
ANCESTOR_KIT="$T/ancestor kit"
make_kit "$ANCESTOR_KIT"
APP_BUNDLE="$ANCESTOR_KIT/Tools/Double Click/Install LUPY.app"
mkdir -p "$APP_BUNDLE"
KIT="$(dirname "$APP_BUNDLE")"
expect_resolve "ancestor" "$ANCESTOR_KIT" "installer ancestor"

echo "== 4. Explicit nested override"
reset_case
OVERRIDE_PARENT="$HOME/Downloads/Wrapper Folder"
OVERRIDE_KIT="$OVERRIDE_PARENT/Inner/lupy-lupy3-final"
make_kit "$OVERRIDE_KIT"
LUPY_KIT_DIR="$OVERRIDE_PARENT"
expect_resolve "explicit override" "$OVERRIDE_KIT" "LUPY_KIT_DIR (nested)"

echo "== 5. Direct Downloads root"
reset_case
DOWNLOAD_KIT="$HOME/Downloads/lupy-lupy3-final"
make_kit "$DOWNLOAD_KIT"
expect_resolve "direct Downloads" "$DOWNLOAD_KIT" "found in a download place"

echo "== 6. Deep Desktop root with spaces"
reset_case
DEEP_KIT="$HOME/Desktop/Founder Files/Downloads 2026/October/New Folder/lupy-lupy3-final"
make_kit "$DEEP_KIT"
expect_resolve "deep Desktop" "$DEEP_KIT" "found in a download place"

echo "== 7. Newest complete kit wins"
reset_case
OLD_KIT="$HOME/Downloads/old/lupy-lupy3-final"
NEW_KIT="$HOME/Documents/new/lupy-lupy3-final"
make_kit "$OLD_KIT"
make_kit "$NEW_KIT"
touch -t 202401010000 "$OLD_KIT"
touch -t 202510010000 "$NEW_KIT"
expect_resolve "newest kit" "$NEW_KIT" "found in a download place"

echo "== 8. Verified embedded payload from a translocation-shaped root"
reset_case
PAYLOAD_SOURCE="$T/payload source"
make_kit "$PAYLOAD_SOURCE"
APP_BUNDLE="$T/Private Folders/AppTranslocation/RANDOM/d/Install LUPY.app"
mkdir -p "$APP_BUNDLE/Contents/Resources"
KIT="$(dirname "$APP_BUNDLE")"
KIT_PAYLOAD="$APP_BUNDLE/Contents/Resources/LupyKit.zip"
KIT_PAYLOAD_SHA256="$APP_BUNDLE/Contents/Resources/LupyKit.sha256"
make_payload "$PAYLOAD_SOURCE" "$KIT_PAYLOAD"
printf '%s  LupyKit.zip\n' "$(sha256_file "$KIT_PAYLOAD")" > "$KIT_PAYLOAD_SHA256"
if resolve_kit; then rc=0; else rc=1; fi
check "embedded payload resolves" "$rc" "0"
check "embedded payload origin" "$KIT_ORIGIN" "embedded payload"
if looks_like_kit "$KIT"; then payload_ok=1; else payload_ok=0; fi
check_true "embedded payload extracts a complete kit under the cache" "$payload_ok"
case "$KIT" in
  "$KIT_CACHE_DIR"*) cache_ok=1 ;;
  *) cache_ok=0 ;;
esac
check_true "embedded payload uses the controlled cache root" "$cache_ok"

echo "== 9. Corrupt embedded payload is refused"
reset_case
APP_BUNDLE="$T/corrupt/Install LUPY.app"
mkdir -p "$APP_BUNDLE/Contents/Resources"
KIT="$(dirname "$APP_BUNDLE")"
KIT_PAYLOAD="$APP_BUNDLE/Contents/Resources/LupyKit.zip"
KIT_PAYLOAD_SHA256="$APP_BUNDLE/Contents/Resources/LupyKit.sha256"
make_payload "$PAYLOAD_SOURCE" "$KIT_PAYLOAD"
printf '%s\n' "0000000000000000000000000000000000000000000000000000000000000000  LupyKit.zip" > "$KIT_PAYLOAD_SHA256"
if resolve_kit; then rc=0; else rc=1; fi
check "corrupt payload does not resolve" "$rc" "1"

echo "== 10. Working-folder root"
reset_case
CWD_KIT="$T/current working kit"
make_kit "$CWD_KIT"
cd "$CWD_KIT" || exit 1
expect_resolve "working folder" "$CWD_KIT" "working folder"
cd "$NEUTRAL" || exit 1

echo "== 11. Official-download recovery when separated from every local kit"
reset_case
OFFICIAL_ZIP="$T/official.zip"
make_payload "$PAYLOAD_SOURCE" "$OFFICIAL_ZIP"
KIT_URL="file://$OFFICIAL_ZIP"
LUPY_INSTALLER_NO_DOWNLOAD=0
if resolve_kit; then rc=0; else rc=1; fi
check "official download resolves" "$rc" "0"
check "official download origin" "$KIT_ORIGIN" "official download"
if looks_like_kit "$KIT"; then download_ok=1; else download_ok=0; fi
check_true "official download extracts a complete kit" "$download_ok"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "INSTALLER ROOTS: SATISFIED ($CHECKS checks)"
  exit 0
fi

echo "INSTALLER ROOTS: $FAILURES of $CHECKS checks FAILED"
exit 1
