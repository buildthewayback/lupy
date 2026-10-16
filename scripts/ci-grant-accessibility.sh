#!/usr/bin/env bash
# CI only (GitHub-hosted Mac): allow /Applications/Lupy.app to use Accessibility, as the founder
# does in System Settings → Privacy & Security → Accessibility, so the computer-control self-test
# can run unattended. Writes a TCC entry bound to the app's exact code signature (its cdhash).
# Never used on the founder's Mac. If the machine refuses (SIP), the self-test reports BLOCKED.
set -uo pipefail
APP="${1:-/Applications/Lupy.app}"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")
echo "SIP: $(csrutil status 2>&1 | tail -1)"
REQ=$(codesign -d -r- "$APP" 2>&1 | sed -n 's/^designated => //p')
echo "designated requirement: $REQ"
echo "$REQ" | csreq -r- -b /tmp/lupy.csreq || { echo "could not compile the code requirement"; exit 0; }
HEX=$(xxd -p /tmp/lupy.csreq | tr -d '\n')
for DB in "/Library/Application Support/com.apple.TCC/TCC.db" "$HOME/Library/Application Support/com.apple.TCC/TCC.db"; do
  [ -f "$DB" ] || continue
  if [[ "$DB" == /Library/* ]]; then SQL="sudo sqlite3"; else SQL="sqlite3"; fi
  $SQL "$DB" "DELETE FROM access WHERE service='kTCCServiceAccessibility' AND client='$BUNDLE_ID';" 2>&1 | head -3
  if $SQL "$DB" "INSERT INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, flags) VALUES ('kTCCServiceAccessibility', '$BUNDLE_ID', 0, 2, 4, 1, X'$HEX', 0);" 2>/tmp/tcc-err.txt; then
    echo "TCC entry written: $DB"
  else
    echo "TCC entry refused for $DB: $(head -2 /tmp/tcc-err.txt)"
  fi
done
# tccd re-reads its database after a restart (launchd starts it again on demand).
sudo killall -9 tccd 2>/dev/null || true
killall -9 tccd 2>/dev/null || true
sleep 2
exit 0
