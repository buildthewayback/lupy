#!/usr/bin/env bash
# CI: run Lupy's computer-control self-test from the installed app and photograph the Lupy cursor
# at its key moments (overlay, typing in TextEdit, waiting for approval before Send, after Send).
#   scripts/ci-control-selftest.sh [/Applications/Lupy.app] [output-dir]
# The app is launched by its executable (it is a background-style app, which `open -W` does not
# wait for). Exit 0 when every real check passed, or when they could only be BLOCKED (Accessibility
# not granted on this machine) — never when a check failed.
set -uo pipefail
APP="${1:-/Applications/Lupy.app}"
BIN="$APP/Contents/MacOS/Lupy"
OUT="${2:-verify-out}"
mkdir -p "$OUT"
STATUS="$OUT/control-status.txt"
REPORT="$OUT/control-report.txt"
STDOUT="$OUT/control-stdout.txt"
: > "$STATUS"
rm -f "$REPORT"
DATA="$(mktemp -d)/lupy-control-data"

shrink() { # $1 png, $2 output base64 file
  for w in 1100 900 720 560; do
    sips -Z "$w" -s format jpeg -s formatOptions 45 "$1" --out "$OUT/ctl-tmp.jpg" >/dev/null 2>&1 || return 0
    base64 -i "$OUT/ctl-tmp.jpg" | tr -d '\n' > "$2"
    [ "$(wc -c < "$2")" -lt 64000 ] && break
  done
  rm -f "$OUT/ctl-tmp.jpg"
}

pkill -x Lupy 2>/dev/null; sleep 1
"$BIN" --control-self-test --report "$REPORT" --status "$STATUS" --data-dir "$DATA" > "$STDOUT" 2>&1 &
CTL_PID=$!

seen="|"
deadline=$((SECONDS + 300))
while kill -0 "$CTL_PID" 2>/dev/null && [ $SECONDS -lt $deadline ]; do
  while IFS= read -r phase; do
    [ -z "$phase" ] && continue
    case "$seen" in *"|$phase|"*) continue ;; esac
    seen="$seen$phase|"
    case "$phase" in
      overlay|executing:2|awaiting|sent)
        name="control-$(echo "$phase" | tr ':' '-')"
        screencapture -x "$OUT/$name.png" 2>/dev/null && shrink "$OUT/$name.png" "$OUT/$name.b64"
        echo "screenshot $name taken"
        ;;
    esac
  done < "$STATUS"
  sleep 0.5
done
if kill -0 "$CTL_PID" 2>/dev/null; then
  echo "FAIL control self-test did not finish in time" >> "$REPORT"
  pkill -x Lupy 2>/dev/null
fi
wait "$CTL_PID" 2>/dev/null
rm -f "$OUT"/control-*.png
echo "phases: $(tr '\n' ' ' < "$STATUS")"
tail -5 "$STDOUT" 2>/dev/null || true
cat "$REPORT" 2>/dev/null || echo "(no control report)"

if grep -q "^CONTROLTEST PASSED" "$REPORT" 2>/dev/null; then exit 0; fi
if grep -q "^CONTROLTEST BLOCKED" "$REPORT" 2>/dev/null && ! grep -q "^FAIL" "$REPORT" 2>/dev/null; then
  echo "computer-control checks could not run on this machine (BLOCKED) — reported, not failed"
  exit 0
fi
exit 1
