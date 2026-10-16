#!/usr/bin/env bash
# Compile and run the LupyCore test suite.
#  - macOS (Xcode installed): native swiftc.
#  - Anywhere else (e.g. the Arena Linux sandbox): Swift 6.3.3 compiled to WebAssembly, run by Node.
# Usage: scripts/test-core.sh [test-name-filter]
set -euo pipefail
cd "$(dirname "$0")/.."
sources=$(find LupyCore/Sources/LupyCore -name '*.swift' | sort)
tests=$(find LupyCore/Tests/LupyCoreTests -name '*.swift' | sort)

if [ "$(uname -s)" = "Darwin" ] && command -v swiftc >/dev/null 2>&1; then
  out="$(mktemp -d)/lupy-core-tests"
  echo "[test-core] native swiftc $(swiftc --version 2>&1 | head -1)"
  swiftc -swift-version 6 -module-name LupyCoreTests -target "$(uname -m)-apple-macos14.0" $sources $tests -o "$out"
  "$out" "$@"
else
  dev=tools/swiftwasm
  if [ ! -d "$dev/node_modules/@live-codes/swift-wasm" ]; then
    (cd "$dev" && npm ci --no-audit --no-fund >/dev/null)
  fi
  echo "[test-core] Swift-on-WebAssembly (dev tool, see THIRD_PARTY_NOTICES.md)"
  node --no-warnings "$dev/swiftc-wasm.mjs" --run $sources $tests -- "$@"
fi
