#!/usr/bin/env bash
# Verifies the DOWNLOADABLE Lupy zip the way a person uses it, on a fresh Mac (a CI VM that never
# saw the build). CI runs it on the file fetched back from GitHub's artifact storage.
#
# Pass/fail checks:
#   1. the file: SHA-256 equals what the build produced; zip integrity
#   2. contents: Lupy.app is the only top-level item (no zip inside a zip, no source code)
#   3. unzipped like Finder: Info.plist keys and privacy texts, executable, Apple-silicon code,
#      minimum macOS, bundled libraries present, icon, intact ad-hoc code signature
#   4. installed into /Applications: first launch with NO demo data (normal data folder), quit,
#      second launch, then scripts/smoke-mac-app.sh (native self-test + demo-data launch metrics)
# Informational only (never pass/fail): what Gatekeeper says about a browser-downloaded copy.
#
# Usage: scripts/verify-mac-download.sh <downloaded.zip> [expected-sha256] [output-dir] [expected-file-name]
# Writes <output-dir>/verify-report.txt (+ smoke-report.txt, selftest.txt) and base64 JPEG
# screenshots (first-launch.b64, screenshot.b64, island.b64, gatekeeper.b64) for the CI report.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

ZIP="${1:?usage: verify-mac-download.sh <downloaded.zip> [expected-sha256] [output-dir] [expected-file-name]}"
EXPECTED="${2:-}"
OUT="${3:-verify-out}"
EXPECTED_NAME="${4:-}"
INSTALL_DIR="${LUPY_INSTALL_DIR:-/Applications}"          # override only to test without touching /Applications
PLISTBUDDY="${PLISTBUDDY:-/usr/libexec/PlistBuddy}"
mkdir -p "$OUT" && OUT="$(cd "$OUT" && pwd)"
REPORT="$OUT/verify-report.txt"
: > "$REPORT"
fails=0

say()  { printf '%s\n' "$*" >> "$REPORT"; }
pass() { say "PASS  $*"; return 0; }
bad()  { say "FAIL  $*"; fails=$((fails + 1)); }

finish() {
  say ""
  if [ "$fails" -eq 0 ]; then say "RESULT: ALL CHECKS PASSED"; else say "RESULT: $fails CHECK(S) FAILED"; fi
  cat "$REPORT"
  [ "$fails" -eq 0 ]
  exit $?
}

shot() { # shot <name>: full-screen capture -> <name>.b64 (JPEG, < 64 KB of base64 for the CI report)
  local png="$OUT/$1.png" w
  if ! screencapture -x "$png" 2>/dev/null; then say "screenshot $1: not available on this machine"; return 0; fi
  for w in 1100 900 720 560; do
    sips -Z "$w" -s format jpeg -s formatOptions 45 "$png" --out "$OUT/tmp.jpg" >/dev/null 2>&1 || break
    base64 -i "$OUT/tmp.jpg" | tr -d '\n' > "$OUT/$1.b64"
    [ "$(wc -c < "$OUT/$1.b64")" -lt 64000 ] && break
  done
  rm -f "$OUT/tmp.jpg" "$png"
  say "screenshot $1: captured"
}

quit_lupy() { # polite quit (like Cmd-Q); returns 1 if it had to be forced
  pgrep -x Lupy >/dev/null || return 0
  osascript -e 'tell application id "app.lupy.Lupy" to quit' >/dev/null 2>&1 &
  local q=$!
  for _ in 1 2 3 4 5 6 7 8; do pgrep -x Lupy >/dev/null || break; sleep 1; done
  kill "$q" 2>/dev/null
  if pgrep -x Lupy >/dev/null; then pkill -x Lupy; sleep 1; pkill -9 -x Lupy 2>/dev/null; return 1; fi
  return 0
}

running_copy() { # command line of the running Lupy (starts with the full path of its executable)
  local pid; pid=$(pgrep -x Lupy | head -1)
  [ -n "$pid" ] && ps -o command= -p "$pid"
}

why_not_running() {
  say "      last log lines from Lupy:"
  log show --last 2m --style compact --predicate 'process == "Lupy"' 2>/dev/null | tail -25 | sed 's/^/      /' >> "$REPORT"
  find ~/Library/Logs/DiagnosticReports -maxdepth 1 -iname '*lupy*' 2>/dev/null | sed 's/^/      crash report: /' >> "$REPORT"
}

# ---------------------------------------------------------------------------------------------
say "== Machine (fresh GitHub-hosted Mac that never saw the build)"
say "macOS $(sw_vers -productVersion) (build $(sw_vers -buildVersion)) · $(uname -m) · $(sysctl -n machdep.cpu.brand_string 2>/dev/null) · $(sysctl -n hw.ncpu) CPUs · $(( $(sysctl -n hw.memsize) / 1073741824 )) GB"

# ---------------------------------------------------------------------------------------------
say ""
say "== 1. The downloaded file"
NAME="$(basename "$ZIP")"
if [ ! -f "$ZIP" ]; then bad "downloaded file not found: $ZIP"; finish; fi
SIZE=$(stat -f %z "$ZIP")
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
say "file:   $NAME"
say "size:   $SIZE bytes ($(du -h "$ZIP" | cut -f1 | tr -d ' '))"
say "sha256: $SHA"
if [ -n "$EXPECTED_NAME" ]; then
  if [ "$NAME" = "$EXPECTED_NAME" ]; then pass "saved under the expected name (the name a browser uses): $NAME"
  else bad "saved as '$NAME' instead of '$EXPECTED_NAME'"; fi
fi
case "$NAME" in *.zip) pass "file name ends in .zip, so double-clicking it opens Archive Utility" ;; *) bad "file name does not end in .zip" ;; esac
if [ -n "$EXPECTED" ]; then
  if [ "$SHA" = "$EXPECTED" ]; then pass "SHA-256 is identical to the zip the build job produced"
  else bad "SHA-256 differs from the build job's zip ($EXPECTED)"; fi
fi
if unzip -tq "$ZIP" >/dev/null 2>&1; then pass "zip integrity test (unzip -t): no errors"
else bad "zip integrity test failed: $(unzip -tq "$ZIP" 2>&1 | tail -2 | tr '\n' ' ')"; fi

# ---------------------------------------------------------------------------------------------
say ""
say "== 2. What is inside the zip"
zipinfo -1 "$ZIP" > "$OUT/zip-listing.txt" 2>/dev/null
cut -d/ -f1 "$OUT/zip-listing.txt" | sort -u > "$OUT/zip-top.txt"
say "top-level items: $(tr '\n' ' ' < "$OUT/zip-top.txt")"
say "entries: $(wc -l < "$OUT/zip-listing.txt" | tr -d ' ')"
if [ "$(cat "$OUT/zip-top.txt")" = "Lupy.app" ]; then pass "Lupy.app is the only top-level item"
else bad "expected only Lupy.app at the top level"; fi
if grep -qx 'Lupy.app/Contents/MacOS/Lupy' "$OUT/zip-listing.txt"; then pass "contains Lupy.app/Contents/MacOS/Lupy (the program)"
else bad "program file Lupy.app/Contents/MacOS/Lupy is missing"; fi
if grep -qx 'Lupy.app/Contents/Info.plist' "$OUT/zip-listing.txt"; then pass "contains Lupy.app/Contents/Info.plist"
else bad "Info.plist is missing"; fi
if grep -qiE '\.(zip|swift|yml|md)$|__MACOSX|/\._' "$OUT/zip-listing.txt"; then
  bad "unexpected content (nested zip, source code, docs or Finder metadata): $(grep -iE '\.(zip|swift|yml|md)$|__MACOSX|/\._' "$OUT/zip-listing.txt" | head -5 | tr '\n' ' ')"
else pass "no nested zip, no source code, no stray metadata"; fi
if grep -qx 'Lupy.app/Contents/Resources/THIRD_PARTY_NOTICES.txt' "$OUT/zip-listing.txt" \
   && grep -qx 'Lupy.app/Contents/Resources/LICENSE-COUCOU-MIT.txt' "$OUT/zip-listing.txt"; then
  pass "licence notices included (Coucou MIT licence, third-party notices)"
else bad "licence notices missing (THIRD_PARTY_NOTICES.txt / LICENSE-COUCOU-MIT.txt)"; fi
# Lupy is Coucou's app: its original sounds ship in this private build (founder decision 2026-10-16),
# together with the notice that keeps that build personal.
NSOUNDS=$(grep -cE '^Lupy.app/Contents/Resources/sounds/[a-z]+\.wav$' "$OUT/zip-listing.txt" || true)
if [ "${NSOUNDS:-0}" -ge 25 ]; then pass "Coucou's original sounds included ($NSOUNDS .wav files)"
else bad "Coucou's sounds missing or incomplete ($NSOUNDS .wav files)"; fi
if grep -qx 'Lupy.app/Contents/Resources/COUCOU_ARTWORK_PERSONAL_USE.txt' "$OUT/zip-listing.txt"; then
  pass "the personal-use notice for Coucou's artwork travels with the app"
else bad "COUCOU_ARTWORK_PERSONAL_USE.txt is missing"; fi

# ---------------------------------------------------------------------------------------------
say ""
say "== 3. Unzip like Finder (ditto, the engine behind Archive Utility) and inspect Lupy.app"
UNZ="$OUT/unzipped"
rm -rf "$UNZ" && mkdir -p "$UNZ"
if ditto -x -k "$ZIP" "$UNZ"; then pass "unzips cleanly"; else bad "unzip failed"; fi
APP="$UNZ/Lupy.app"
if [ ! -d "$APP" ]; then bad "Lupy.app did not appear after unzipping"; finish; fi
pass "Lupy.app appears after unzipping"
plist() { "$PLISTBUDDY" -c "Print :$1" "$APP/Contents/Info.plist" 2>/dev/null; }
[ "$(plist CFBundleExecutable)" = "Lupy" ] && pass "Info.plist: program name is Lupy" || bad "Info.plist CFBundleExecutable='$(plist CFBundleExecutable)'"
[ "$(plist CFBundleIdentifier)" = "app.lupy.Lupy" ] && pass "Info.plist: bundle id app.lupy.Lupy" || bad "Info.plist CFBundleIdentifier='$(plist CFBundleIdentifier)'"
[ "$(plist CFBundlePackageType)" = "APPL" ] && pass "Info.plist: it is an application (APPL)" || bad "Info.plist CFBundlePackageType='$(plist CFBundlePackageType)'"
say "      version $(plist CFBundleShortVersionString) (build $(plist CFBundleVersion))"
MINOS=$(plist LSMinimumSystemVersion)
[ "$MINOS" = "14.0" ] && pass "Info.plist: needs macOS 14.0 or newer" || bad "Info.plist LSMinimumSystemVersion='$MINOS'"
[ -n "$(plist NSMicrophoneUsageDescription)" ] && pass "microphone permission text present (dictation)" || bad "NSMicrophoneUsageDescription missing (dictation would crash)"
[ -n "$(plist NSSpeechRecognitionUsageDescription)" ] && pass "speech-recognition permission text present (dictation)" || bad "NSSpeechRecognitionUsageDescription missing (dictation would crash)"

BIN="$APP/Contents/MacOS/Lupy"
[ -x "$BIN" ] && pass "program file is executable" || bad "program file is not executable"
ARCHS=$(lipo -archs "$BIN" 2>/dev/null)
case " $ARCHS " in
  *" arm64 "*) pass "Apple-silicon code (architectures: $ARCHS) — runs natively on an M1, no Rosetta" ;;
  *) bad "no arm64 code in the program (architectures: '$ARCHS')" ;;
esac
BINMIN=$(otool -l "$BIN" 2>/dev/null | awk '/cmd LC_BUILD_VERSION/ {f=1} f && $1 == "minos" {print $2; exit}')
[ "$BINMIN" = "14.0" ] && pass "program built for macOS 14.0+ (matches Info.plist)" || bad "program minimum macOS is '$BINMIN'"

otool -L "$BIN" 2>/dev/null | tail -n +2 | awk '{print $1}' > "$OUT/libs.txt"
say "      linked libraries: $(wc -l < "$OUT/libs.txt" | tr -d ' ') ($(grep -c '^/System/' "$OUT/libs.txt") Apple frameworks, $(grep -c '^/usr/lib/' "$OUT/libs.txt") Apple system libraries, $(grep -c '^@' "$OUT/libs.txt") bundled)"
missing=""
while read -r lib; do
  case "$lib" in
    @rpath/*) [ -e "$APP/Contents/Frameworks/${lib#@rpath/}" ] || missing="$missing $lib" ;;
    @executable_path/*) [ -e "$APP/Contents/MacOS/${lib#@executable_path/}" ] || missing="$missing $lib" ;;
    @loader_path/*) [ -e "$APP/Contents/MacOS/${lib#@loader_path/}" ] || missing="$missing $lib" ;;
    /System/*|/usr/lib/*) ;;  # provided by macOS itself (dyld shared cache)
    *) missing="$missing $lib" ;;
  esac
done < "$OUT/libs.txt"
grep '^@' "$OUT/libs.txt" | sed 's/^/      bundled: /' >> "$REPORT"
[ -z "$missing" ] && pass "every library the program needs is either part of macOS or inside the app" || bad "missing libraries:$missing"

ICONFILE=$(plist CFBundleIconFile); ICONNAME=$(plist CFBundleIconName)
if [ -n "$ICONFILE" ] && [ -f "$APP/Contents/Resources/${ICONFILE%.icns}.icns" ]; then pass "app icon present (${ICONFILE%.icns}.icns)"
elif [ -n "$ICONNAME" ] && [ -f "$APP/Contents/Resources/Assets.car" ]; then pass "app icon present (asset catalog: $ICONNAME)"
else bad "app icon missing (CFBundleIconFile='$ICONFILE', CFBundleIconName='$ICONNAME')"; fi
# The icon as macOS will show it (rendered from the downloaded bundle) for the report.
if [ -f "$APP/Contents/Resources/AppIcon.icns" ]; then
  sips -s format png -Z 256 "$APP/Contents/Resources/AppIcon.icns" --out "$OUT/appicon.png" >/dev/null 2>&1 \
    && base64 -i "$OUT/appicon.png" | tr -d '\n' > "$OUT/appicon.b64" && say "      app icon rendered for the report"
fi
[ -f "$APP/Contents/_CodeSignature/CodeResources" ] && pass "code-signature seal present (_CodeSignature/CodeResources)" || bad "code-signature seal missing"

if codesign --verify --deep --strict --verbose=2 "$APP" > "$OUT/codesign.txt" 2>&1; then
  pass "code signature intact after download + unzip (codesign --verify --deep --strict)"
else bad "code signature broken after download + unzip: $(tail -2 "$OUT/codesign.txt" | tr '\n' ' ')"; fi
codesign -dv "$APP" > "$OUT/codesign-info.txt" 2>&1
grep -E '^(Identifier|Format|Signature|TeamIdentifier)=' "$OUT/codesign-info.txt" | sed 's/^/      /' >> "$REPORT"
grep -q '^Signature=adhoc' "$OUT/codesign-info.txt" && pass "signed ad-hoc, as documented (no paid Apple Developer ID, not notarized)" || bad "unexpected signature type"
say "      app size on disk: $(du -sh "$APP" | cut -f1 | tr -d ' '), $(find "$APP" -type f | wc -l | tr -d ' ') files"
say "      bundle layout:"
(cd "$UNZ" && find Lupy.app -maxdepth 3 | sort | sed 's/^/        /') >> "$REPORT"

# ---------------------------------------------------------------------------------------------
say ""
say "== 4. Install into /Applications (what dragging Lupy.app there does) and launch"
DEST="$INSTALL_DIR/Lupy.app"
quit_lupy
rm -rf "$DEST" 2>/dev/null || sudo rm -rf "$DEST"
ditto "$APP" "$DEST" 2>/dev/null || sudo ditto "$APP" "$DEST"
[ -x "$DEST/Contents/MacOS/Lupy" ] && pass "installed to $DEST" || bad "could not install into $INSTALL_DIR"
codesign --verify --deep --strict "$DEST" >/dev/null 2>&1 && pass "signature still intact after installing" || bad "signature broken after install"

DATA="$HOME/Library/Application Support/Lupy"
[ -e "$DATA" ] && say "      note: $DATA already existed before the first launch"
say "-- first launch (no demo data, normal data folder — like a new user)"
open "$DEST"
sleep 12
EXE="$(running_copy)"
if [ -n "$EXE" ]; then
  pass "Lupy is running 12 s after the first launch"
  case "$EXE" in
    "$DEST"/*) pass "the running copy is the one installed from the download ($EXE)" ;;
    *) bad "the running copy is not the installed download ($EXE)" ;;
  esac
  PID=$(pgrep -x Lupy | head -1)
  say "      memory (physical footprint): $(vmmap --summary "$PID" 2>/dev/null | awk '/^Physical footprint:/ {print $3}')"
else
  bad "Lupy is not running 12 s after the first launch"
  why_not_running
fi
if [ -d "$DATA/store" ]; then pass "data folder created: ~/Library/Application Support/Lupy/store ($(ls "$DATA/store" | tr '\n' ' '))"
else bad "data folder ~/Library/Application Support/Lupy/store was not created"; fi
shot first-launch
if [ -n "$EXE" ]; then
  if quit_lupy; then pass "quits cleanly (like Cmd-Q)"; else bad "did not quit within 8 s (forced)"; fi
fi

say "-- second launch (reopens with the data saved by the first launch)"
open "$DEST"
sleep 8
if [ -n "$(running_copy)" ]; then pass "Lupy reopens with its saved data folder"; else bad "Lupy did not reopen"; why_not_running; fi
quit_lupy || say "      second quit: forced"

say "-- native self-test and demo-data launch (scripts/smoke-mac-app.sh on the installed copy)"
if bash scripts/smoke-mac-app.sh "$DEST" "$OUT" > /dev/null 2>&1; then
  pass "self-test $(grep -c '^PASS' "$OUT/selftest.txt" 2>/dev/null)/$(grep -cE '^(PASS|FAIL)' "$OUT/selftest.txt" 2>/dev/null) and demo-data launch passed"
else bad "smoke test failed (see smoke report below)"; fi
grep -E '^(running|resident|Activity|CPU|quit|screenshot|animation)' "$OUT/smoke-report.txt" 2>/dev/null | sed 's/^/      /' >> "$REPORT"

# ---------------------------------------------------------------------------------------------
say ""
say "== 5. Gatekeeper preview for a browser-downloaded copy (INFORMATIONAL — not a pass/fail check)"
say "Gatekeeper on this VM: $(spctl --status 2>&1 | tr '\n' ' ')"
GK="$HOME/Downloads/gatekeeper-preview"
rm -rf "$GK" && mkdir -p "$GK"
cp "$ZIP" "$GK/$NAME"
QVAL="0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)"
xattr -w com.apple.quarantine "$QVAL" "$GK/$NAME"            # what a browser stamps on a download
open -a "Archive Utility" "$GK/$NAME" >> "$REPORT" 2>&1      # what double-clicking the zip does
for _ in $(seq 1 20); do [ -x "$GK/Lupy.app/Contents/MacOS/Lupy" ] && break; sleep 1; done
sleep 1
pkill -x "Archive Utility" 2>/dev/null
if [ -d "$GK/Lupy.app" ]; then
  QAPP="$GK/Lupy.app"
  say "double-click unzip (Archive Utility): Lupy.app appeared next to the zip"
  codesign --verify --deep --strict "$QAPP" >/dev/null 2>&1 && say "signature of the Archive Utility copy: intact" || say "signature of the Archive Utility copy: BROKEN"
else
  say "Archive Utility did not finish on this VM; using ditto plus a manual quarantine stamp instead"
  ditto -x -k "$GK/$NAME" "$GK/x"
  xattr -w -r com.apple.quarantine "$QVAL" "$GK/x/Lupy.app"
  QAPP="$GK/x/Lupy.app"
fi
say "quarantine flag on the unzipped app: $(xattr -p com.apple.quarantine "$QAPP" 2>/dev/null | cut -d';' -f1,3 || echo none)"
say "spctl assessment:"
spctl --assess --type execute -vv "$QAPP" 2>&1 | sed 's/^/  /' >> "$REPORT"
if command -v syspolicy_check >/dev/null 2>&1; then
  say "syspolicy_check distribution (Apple's notarization readiness check):"
  syspolicy_check distribution "$QAPP" 2>&1 | head -20 | sed 's/^/  /' >> "$REPORT"
fi
XPV=$(defaults read /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist CFBundleShortVersionString 2>/dev/null)
say "XProtect malware definitions on this VM: version ${XPV:-unknown}"
open "$QAPP" >> "$REPORT" 2>&1 &
OPID=$!
sleep 8
# Judge by what is on screen. While macOS shows its security prompt, the blocked Lupy process
# already exists (it is held at launch), so "is a Lupy process running?" cannot tell the two
# cases apart (build #4's report got this wrong; its screenshots showed the prompt).
# Window owner names need no screen-recording permission; the prompt belongs to CoreServicesUIAgent.
cat > "$OUT/onscreen.swift" <<'SWIFT'
import CoreGraphics
let info = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
for w in info { print(w[kCGWindowOwnerName as String] as? String ?? "?") }
SWIFT
ONSCREEN=$(swift "$OUT/onscreen.swift" 2>/dev/null | sort -u | paste -sd, -)
say "apps with windows on screen 8 s after double-clicking: ${ONSCREEN:-unknown}"
if [[ ",$ONSCREEN," == *",CoreServicesUIAgent,"* ]]; then
  say "result: macOS blocked the double-click and showed its security prompt (screenshot) — expected for an app that is not notarized; the Open Anyway steps in INSTALL_GUIDE get past it"
  shot gatekeeper
  pkill -x Lupy 2>/dev/null
elif [[ ",$ONSCREEN," == *",Lupy,"* ]]; then
  say "result: the quarantined copy opened WITHOUT a security prompt on this VM (real Macs normally show one)"
  shot gatekeeper
  quit_lupy
else
  say "result: no security prompt and no Lupy window detected — see screenshot"
  shot gatekeeper
  pkill -x Lupy 2>/dev/null
fi
kill "$OPID" 2>/dev/null

finish
