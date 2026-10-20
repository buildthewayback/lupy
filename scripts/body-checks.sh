#!/usr/bin/env bash
# THE BODY, ONE COMMAND — every proof that the product works, not just looks right.
# Linux-sandbox-safe (no macOS needed): real Swift frontend syntax-parses all 220
# files; the wiring council cross-checks every cross-file reference; the character
# rig and the design law run headless; the picture councils judge rendered pixels.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== 1 · Swift frontend parses every Swift file (syntax gate)"
find Mac/Sources Mac/Tests -name '*.swift' | sort > /tmp/lupy_all_swift.txt
node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --parse $(cat /tmp/lupy_all_swift.txt)
echo "== 1b · the hundred-thousand audit (property fuzz of the kernel)"
node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --run \
  Mac/Sources/Lupy/Character/LupyGeometry.swift \
  Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
  Mac/Sources/Lupy/UI/LupyIslandDesign.swift tools/ui/fuzz_kernel.swift | tail -2
echo "== 2 · core + character rig"
bash scripts/test-core.sh | tail -1
echo "== 3 · island design law"
bash tools/ui/test-design.sh | tail -1
echo "== 3b · security + beta councils"
python3 tools/ui/audit_security.py | tail -1
python3 tools/ui/audit_beta.py | tail -1
echo "== 4 · wiring council (whole body)"
python3 tools/ui/audit_wiring.py | tail -1
echo "== 5 · emits (regenerated every run — /tmp resets cannot break the chain)"
node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --run \
  Mac/Sources/Lupy/Character/LupyGeometry.swift \
  Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
  tools/character/rig_states.swift > /tmp/states.txt
node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --run \
  Mac/Sources/Lupy/Character/LupyGeometry.swift \
  Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
  Mac/Sources/Lupy/UI/LupyIslandDesign.swift \
  tools/ui/layout_emit.swift > /tmp/island_layout.txt
echo "== 6 · picture councils"
python3 -c "import PIL, numpy" 2>/dev/null || \
  pip install --quiet --break-system-packages pillow numpy
echo "== 6a · icon forge (the shipped icon IS the locked character, byte for byte)"
python3 tools/ui/make_appicon.py --check | tail -1
python3 tools/ui/audit_ui.py | tail -1
python3 tools/ui/audit_all.py | tail -1
python3 tools/ui/audit_micro.py | tail -1
echo "BODY GREEN"
