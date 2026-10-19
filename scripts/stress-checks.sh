#!/usr/bin/env bash
# THE TEN-MILLION STRESS — separate from body-checks because it earns its minutes:
# 10,000,010 randomised + adversarial cases, 40,000,080 measurements (~7 min).
set -euo pipefail
cd "$(dirname "$0")/.."
node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --run \
  Mac/Sources/Lupy/Character/LupyGeometry.swift \
  Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
  Mac/Sources/Lupy/UI/LupyIslandDesign.swift tools/ui/stress_kernel.swift | tail -3
