#!/usr/bin/env bash
# Native evidence for a built Lupy.app (macOS only; used by CI after build-mac-app.sh):
#  1. code-signing and Gatekeeper status (honest: ad-hoc apps are not notarized)
#  2. --self-test inside the real app binary (LupyCore + real disk adapter + Keychain)
#  3. GUI launch with demo data in a throwaway folder: alive?, memory, CPU, screenshots
# Writes dist/smoke-report.txt and base64 JPEG screenshots for the CI report.
set -uo pipefail
cd "$(dirname "$0")/.."
APP="build/DerivedData/Build/Products/Release/Lupy.app"
BIN="$APP/Contents/MacOS/Lupy"
OUT=dist
REPORT="$OUT/smoke-report.txt"
mkdir -p "$OUT"
fail=0

{
  echo "== Signature"
  codesign -dv "$APP" 2>&1 | grep -E "Identifier|Format|Signature|TeamIdentifier|Runtime" || true
  echo "== Gatekeeper assessment (expected to be rejected: not notarized)"
  spctl --assess --type execute -vv "$APP" 2>&1 | tail -3 || true
  echo "== Self-test (native)"
} > "$REPORT"

"$BIN" --self-test --report "$OUT/selftest.txt" >> "$REPORT" 2>&1
st=$?
echo "self-test exit code: $st" >> "$REPORT"
[ $st -eq 0 ] || fail=1

echo "== GUI launch (demo data, temporary folder)" >> "$REPORT"
SMOKE_DIR="$(mktemp -d)/lupy-smoke-data"
open -n "$APP" --args --data-dir "$SMOKE_DIR" --demo
sleep 12
PID=$(pgrep -x Lupy | head -1 || true)
if [ -n "${PID}" ]; then
  echo "running: yes (pid $PID)" >> "$REPORT"
  ps -o rss=,%cpu= -p "$PID" | awk '{printf "memory (RSS): %.1f MB, CPU: %s%%\n", $1/1024, $2}' >> "$REPORT"
  sleep 5
  ps -o rss=,%cpu= -p "$PID" | awk '{printf "after 5 s idle — memory (RSS): %.1f MB, CPU: %s%%\n", $1/1024, $2}' >> "$REPORT"
  ls "$SMOKE_DIR" >> "$REPORT" 2>&1 && echo "data folder created: yes" >> "$REPORT"
else
  echo "running: NO — the app exited or failed to launch" >> "$REPORT"
  log show --last 2m --style compact --predicate 'process == "Lupy"' 2>/dev/null | tail -40 >> "$REPORT" || true
  fail=1
fi

# Screenshots (may be blank if the CI machine denies screen capture — reported, not fatal).
shrink() { # $1 png, $2 output base64 file
  for w in 1100 900 720 560; do
    sips -Z "$w" -s format jpeg -s formatOptions 45 "$1" --out "$OUT/tmp.jpg" >/dev/null 2>&1 || return 0
    base64 -i "$OUT/tmp.jpg" | tr -d '\n' > "$2"
    [ "$(wc -c < "$2")" -lt 64000 ] && break
  done
  rm -f "$OUT/tmp.jpg"
}
if screencapture -x "$OUT/screen.png" 2>>"$REPORT"; then
  shrink "$OUT/screen.png" "$OUT/screenshot.b64"
  W=$(sips -g pixelWidth "$OUT/screen.png" | awk '/pixelWidth/ {print $2}')
  echo "screenshot: captured (${W}px wide)" >> "$REPORT"
  if screencapture -x -R "0,0,${W:-1920},220" "$OUT/island.png" 2>/dev/null; then shrink "$OUT/island.png" "$OUT/island.b64"; fi
else
  echo "screenshot: not available on this machine" >> "$REPORT"
fi

if [ -n "${PID:-}" ]; then
  osascript -e 'tell application id "app.lupy.Lupy" to quit' >/dev/null 2>&1 || kill "$PID" 2>/dev/null
  sleep 2
  pgrep -x Lupy >/dev/null && { echo "quit: forced" >> "$REPORT"; pkill -x Lupy; } || echo "quit: clean" >> "$REPORT"
fi
rm -f "$OUT"/*.png
cat "$REPORT"
exit $fail
