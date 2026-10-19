#!/bin/bash
# LUPY 3 — the double-click installer.
# Builds LUPY on THIS Mac with Apple's free Command Line Tools (no Xcode, no 8 GB),
# installs him to /Applications like any app, and launches him.
# Full log: /tmp/lupy-install.log
cd "$(cd "$(dirname "$0")" && pwd)" || exit 1
LOG=/tmp/lupy-install.log
bash scripts/build-no-xcode.sh --install 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
echo
if [ "$STATUS" -eq 0 ]; then
  echo "DONE — LUPY is in Applications and running. You can close this window."
else
  echo "INSTALL FAILED — last 40 lines of the build log:"
  tail -40 build-noxcode/build.log 2>/dev/null
  echo "Screenshot this window and send it to Arena; the fix comes as a new kit."
fi
echo
read -r -p "Press Return to close this window… " _
