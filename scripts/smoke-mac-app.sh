#!/usr/bin/env bash
# Native evidence for a Lupy.app (macOS only):
#  1. code-signing and Gatekeeper status (honest: ad-hoc apps are not notarized)
#  2. --self-test inside the real app binary (LupyCore + real disk adapter + Keychain)
#  3. GUI launch with demo data in a throwaway folder: alive?, memory, CPU, screenshots
# Usage: scripts/smoke-mac-app.sh [path/to/Lupy.app] [output-dir]
#   Defaults: the freshly built app (build/…/Release/Lupy.app) and dist/.
#   CI runs it on the copy installed from the DOWNLOADED zip (scripts/verify-mac-download.sh).
# Writes <output-dir>/smoke-report.txt, selftest.txt and base64 JPEG screenshots for the CI report.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
APP="${1:-build/DerivedData/Build/Products/Release/Lupy.app}"
BIN="$APP/Contents/MacOS/Lupy"
OUT="${2:-dist}"
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
  ps -o rss= -p "$PID" | awk '{printf "resident memory (RSS, includes shared system frameworks): %.1f MB\n", $1/1024}' >> "$REPORT"
  vmmap --summary "$PID" 2>/dev/null | grep -E "^Physical footprint" | sed 's/^/Activity Monitor "Memory" (physical footprint): /' >> "$REPORT" || true
  # Instantaneous CPU: last of several top samples, 3 s apart (ps %cpu is a lifetime average).
  top -l 4 -s 3 -pid "$PID" -stats pid,cpu | awk '$1 ~ /^[0-9]+$/ {c=$2} END {print "CPU while frontmost (3 s sample): " c "%"}' >> "$REPORT"
  osascript -e 'tell application "Finder" to activate' >/dev/null 2>&1 || true
  sleep 3
  top -l 4 -s 3 -pid "$PID" -stats pid,cpu | awk '$1 ~ /^[0-9]+$/ {c=$2} END {print "CPU in background (3 s sample): " c "%"}' >> "$REPORT"
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
  osascript -e 'tell application id "app.lupy.Lupy" to quit' >/dev/null 2>&1 &
  QPID=$!
  for _ in 1 2 3 4 5 6 7 8; do pgrep -x Lupy >/dev/null || break; sleep 1; done
  kill "$QPID" 2>/dev/null
  pgrep -x Lupy >/dev/null && { echo "quit: forced" >> "$REPORT"; pkill -x Lupy; } || echo "quit: clean" >> "$REPORT"
fi
rm -f "$OUT"/*.png
cat "$REPORT"
exit $fail
