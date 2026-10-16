#!/usr/bin/env bash
# CI: run Lupy's computer-control self-test from the installed app and photograph the Lupy cursor
# at its key moments (overlay, typing in TextEdit, waiting for approval before Send, after Send).
#   scripts/ci-control-selftest.sh [/Applications/Lupy.app] [output-dir]
# Exit 0 only when every real check passed (checks that could not run are reported BLOCKED).
set -uo pipefail
APP="${1:-/Applications/Lupy.app}"
OUT="${2:-verify-out}"
mkdir -p "$OUT"
STATUS="$OUT/control-status.txt"
REPORT="$OUT/control-report.txt"
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

# `open` (not the binary directly) so macOS treats Lupy itself as the app using Accessibility.
open -W -n "$APP" --args --control-self-test --report "$REPORT" --status "$STATUS" --data-dir "$DATA" &
OPEN_PID=$!
seen="|"
for _ in $(seq 1 360); do   # at most ~3 minutes
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
  kill -0 "$OPEN_PID" 2>/dev/null || break
  sleep 0.5
done
if kill -0 "$OPEN_PID" 2>/dev/null; then
  echo "FAIL control self-test did not finish in time" >> "$REPORT"
  pkill -x Lupy 2>/dev/null
fi
wait "$OPEN_PID" 2>/dev/null
rm -f "$OUT"/control-*.png
echo "phases: $(tr '\n' ' ' < "$STATUS")"
cat "$REPORT" 2>/dev/null || echo "(no control report)"
grep -q "^CONTROLTEST PASSED" "$REPORT" 2>/dev/null
