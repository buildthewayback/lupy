#!/usr/bin/env bash
# Native evidence for a Lupy.app (macOS only):
#  1. code-signing and Gatekeeper status (honest: ad-hoc apps are not notarized)
#  2. --self-test inside the real app binary (LupyCore + real disk adapter + Keychain)
#  3. GUI launch with demo data in a throwaway folder: alive?, the Lupy window (Today), the island
#     (expanded once), memory, CPU, and an animation check: two captures 0.8 s apart below the
#     menu bar must differ (Coucou's Mochi animates — a static cat would fail this check)
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

shrink() { # $1 png, $2 output base64 file
  for w in 1100 900 720 560; do
    sips -Z "$w" -s format jpeg -s formatOptions 45 "$1" --out "$OUT/tmp.jpg" >/dev/null 2>&1 || return 0
    base64 -i "$OUT/tmp.jpg" | tr -d '\n' > "$2"
    [ "$(wc -c < "$2")" -lt 64000 ] && break
  done
  rm -f "$OUT/tmp.jpg"
}

echo "== GUI launch (demo data, temporary folder; Lupy window on Today; island expanded once)" >> "$REPORT"
SMOKE_DIR="$(mktemp -d)/lupy-smoke-data"
open -n "$APP" --args --data-dir "$SMOKE_DIR" --demo --open-window lupyToday --show-island
sleep 11
PID=$(pgrep -x Lupy | head -1 || true)
if [ -n "${PID}" ]; then
  echo "running: yes (pid $PID)" >> "$REPORT"
  if screencapture -x "$OUT/screen.png" 2>>"$REPORT"; then
    W=$(sips -g pixelWidth "$OUT/screen.png" | awk '/pixelWidth/ {print $2}')
    H=$(sips -g pixelHeight "$OUT/screen.png" | awk '/pixelHeight/ {print $2}')
    shrink "$OUT/screen.png" "$OUT/screenshot.b64"
    echo "screenshot (window + island): captured (${W}x${H}px)" >> "$REPORT"
    # The island area, top centre, at full resolution.
    IW=$(( W < 900 ? W : 900 ))
    screencapture -x -R "$(( (W - IW) / 2 )),0,${IW},300" "$OUT/island.png" 2>/dev/null && shrink "$OUT/island.png" "$OUT/island.b64"
  else
    echo "screenshot: not available on this machine" >> "$REPORT"
  fi
  sleep 6   # the island folds back; Mochi keeps living in the window's band and the resting island
  # Animation check: two captures below the menu bar, 0.8 s apart.
  if screencapture -x "$OUT/frameA.png" 2>/dev/null; then
    sleep 0.8
    screencapture -x "$OUT/frameB.png" 2>/dev/null
    FH=$(sips -g pixelHeight "$OUT/frameA.png" | awk '/pixelHeight/ {print $2}')
    FW=$(sips -g pixelWidth "$OUT/frameA.png" | awk '/pixelWidth/ {print $2}')
    for f in frameA frameB; do
      sips --cropToHeightWidth $(( FH - 60 )) "$FW" --cropOffset 60 0 "$OUT/$f.png" --out "$OUT/$f-crop.png" >/dev/null 2>&1 || cp "$OUT/$f.png" "$OUT/$f-crop.png"
    done
    HA=$(shasum -a 256 "$OUT/frameA-crop.png" | cut -c1-16)
    HB=$(shasum -a 256 "$OUT/frameB-crop.png" | cut -c1-16)
    if [ "$HA" != "$HB" ]; then
      echo "animation: frames 0.8 s apart differ ($HA vs $HB) — Mochi is animated, not static" >> "$REPORT"
    else
      echo "animation: frames 0.8 s apart are IDENTICAL ($HA) — nothing moved on screen" >> "$REPORT"
      fail=1
    fi
    shrink "$OUT/frameB.png" "$OUT/rest.b64"
  fi
  ps -o rss= -p "$PID" | awk '{printf "resident memory (RSS, includes shared system frameworks): %.1f MB\n", $1/1024}' >> "$REPORT"
  vmmap --summary "$PID" 2>/dev/null | grep -E "^Physical footprint" | sed 's/^/Activity Monitor "Memory" (physical footprint): /' >> "$REPORT" || true
  # Instantaneous CPU: last of several top samples, 3 s apart (ps %cpu is a lifetime average).
  top -l 4 -s 3 -pid "$PID" -stats pid,cpu | awk '$1 ~ /^[0-9]+$/ {c=$2} END {print "CPU with the window in front (3 s sample): " c "%"}' >> "$REPORT"
  osascript -e 'tell application "Finder" to activate' >/dev/null 2>&1 || true
  sleep 3
  top -l 4 -s 3 -pid "$PID" -stats pid,cpu | awk '$1 ~ /^[0-9]+$/ {c=$2} END {print "CPU in background (3 s sample): " c "%"}' >> "$REPORT"
  ls "$SMOKE_DIR" >> "$REPORT" 2>&1 && echo "data folder created: yes" >> "$REPORT"
else
  echo "running: NO — the app exited or failed to launch" >> "$REPORT"
  log show --last 2m --style compact --predicate 'process == "Lupy"' 2>/dev/null | tail -40 >> "$REPORT" || true
  fail=1
fi

if [ -n "${PID:-}" ]; then
  osascript -e 'tell application id "app.lupy.Lupy" to quit' >/dev/null 2>&1 &
  QPID=$!
  for _ in 1 2 3 4 5 6 7 8; do pgrep -x Lupy >/dev/null || break; sleep 1; done
  kill "$QPID" 2>/dev/null
  pgrep -x Lupy >/dev/null && { echo "quit: forced" >> "$REPORT"; pkill -x Lupy; } || echo "quit: clean" >> "$REPORT"
fi
echo "== Island conversation (the quick interaction surface) — demo launch with the chat open" >> "$REPORT"
SMOKE_DIR2="$(mktemp -d)/lupy-smoke-chat"
open -n "$APP" --args --data-dir "$SMOKE_DIR2" --demo --show-island-chat
sleep 11
PID2=$(pgrep -x Lupy | head -1 || true)
if [ -n "${PID2:-}" ]; then
  echo "running: yes (pid $PID2)" >> "$REPORT"
  if screencapture -x "$OUT/chat-full.png" 2>/dev/null; then
    W2=$(sips -g pixelWidth "$OUT/chat-full.png" | awk '/pixelWidth/ {print $2}')
    IW2=$(( W2 < 1000 ? W2 : 1000 ))
    screencapture -x -R "$(( (W2 - IW2) / 2 )),0,${IW2},380" "$OUT/island-chat.png" 2>/dev/null && shrink "$OUT/island-chat.png" "$OUT/island-chat.b64"
    echo "screenshot (island conversation): captured (${W2}px wide screen)" >> "$REPORT"
  else
    echo "screenshot: not available on this machine" >> "$REPORT"
  fi
else
  echo "running: NO — the app exited or failed to launch" >> "$REPORT"
  fail=1
fi
if [ -n "${PID2:-}" ]; then
  osascript -e 'tell application id "app.lupy.Lupy" to quit' >/dev/null 2>&1 &
  Q2=$!
  for _ in 1 2 3 4 5 6 7 8; do pgrep -x Lupy >/dev/null || break; sleep 1; done
  kill "$Q2" 2>/dev/null
  pgrep -x Lupy >/dev/null && { echo "quit: forced" >> "$REPORT"; pkill -x Lupy; } || echo "quit: clean" >> "$REPORT"
fi
rm -f "$OUT"/*.png
cat "$REPORT"
exit $fail
