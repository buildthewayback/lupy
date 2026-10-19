#!/usr/bin/env bash
# One command from clone to running island on the founder's Mac.
#   bash scripts/run-mac.sh
# Needs: macOS 15+ (Sequoia, his floor), Xcode from the App Store, Homebrew.
set -euo pipefail
cd "$(dirname "$0")/../Mac"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "[run-mac] installing XcodeGen, once…"
  brew install xcodegen
fi
echo "[run-mac] generating the Xcode project…"
xcodegen generate
echo "[run-mac] opening Xcode — press ⌘R to run LUPY."
open Lupy.xcodeproj
