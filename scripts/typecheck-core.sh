#!/usr/bin/env bash
# Fast feedback: type-check LupyCore sources + tests without code generation.
set -euo pipefail
cd "$(dirname "$0")/.."
sources=$(find LupyCore/Sources/LupyCore -name '*.swift' | sort)
tests=$(find LupyCore/Tests/LupyCoreTests -name '*.swift' | sort)
if [ "$(uname -s)" = "Darwin" ] && command -v swiftc >/dev/null 2>&1; then
  swiftc -typecheck -swift-version 6 $sources $tests
else
  node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --typecheck $sources $tests
fi
