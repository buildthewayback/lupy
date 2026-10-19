#!/usr/bin/env bash
# Prove the island's design law, with no CI and no Mac required.
#   - macOS with Xcode: native swiftc.
#   - anywhere else: Swift compiled to WebAssembly, run by Node (tools/swiftwasm).
# Same trick as scripts/test-core.sh — the founder's rule is that GitHub is a file
# shelf, not a gatekeeper, so the proof has to run wherever he is.
set -euo pipefail
cd "$(dirname "$0")/../.."

sources="Mac/Sources/Lupy/Character/LupyGeometry.swift
Mac/Sources/Lupy/Character/LupyCharacterMath.swift
Mac/Sources/Lupy/UI/LupyIslandDesign.swift"
tests="tools/ui/design_tests.swift"

if [ "$(uname -s)" = "Darwin" ] && command -v swiftc >/dev/null 2>&1; then
  out="$(mktemp -d)/lupy-design-tests"
  echo "[test-design] native swiftc $(swiftc --version 2>&1 | head -1)"
  swiftc -swift-version 6 -module-name LupyDesignTests $sources $tests -o "$out"
  "$out" "$@"
else
  dev=tools/swiftwasm
  if [ ! -d "$dev/node_modules/@live-codes/swift-wasm" ] && [ ! -d "$dev/node_modules/@scalar/swift-fmt" ]; then
    (cd "$dev" && npm ci --no-audit --no-fund >/dev/null)
  fi
  echo "[test-design] Swift-on-WebAssembly (dev tool)"
  node --no-warnings "$dev/swiftc-wasm.mjs" --run $sources $tests -- "$@"
fi
