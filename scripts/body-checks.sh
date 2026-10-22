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
echo "== 6b · install wiring (the icon must actually REACH the app; the face must exist)"
# These greps are tombstones for a real loss: the icns-copy line once vanished
# between an editing tool and a merge, and the founder's app shipped faceless
# while everything reported green. Wiring that is not machine-checked will be
# lost again; wiring that is, cannot be lost silently.
grep -q 'cp LupyAppIcon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"' scripts/build-no-xcode.sh
grep -q 'lsregister -f /Applications/Lupy.app' scripts/build-no-xcode.sh
grep -q 'xattr -dr com.apple.quarantine /Applications/Lupy.app' scripts/build-no-xcode.sh
# the plist's Xcode variables must be stamped on the no-Xcode road, or the
# installed app cannot be opened at all (oracle-proven, macOS 15.7.9)
grep -q 'PlistBuddy -c "Set :CFBundleExecutable Lupy"' scripts/build-no-xcode.sh
grep -q 'PlistBuddy -c "Set :CFBundleDevelopmentRegion en"' scripts/build-no-xcode.sh
# LAG LAW: the character rig never renders at full rate unseen (founder lag,
# 2026-10-22) — every island face must carry a real pause.
grep -q "TimelineView(.animation(paused: paused))" Mac/Sources/Lupy/Character/LupyCanvasView.swift
grep -q "paused: paused || state.mode == .hidden" Mac/Sources/Lupy/Character/IslandCharacterView.swift
grep -q "paused: !viewActive" Mac/Sources/App/BotCanvasView.swift
# the string catalog must reach the bundle as .lproj, or raw keys show in the UI
grep -q 'Localizable.xcstrings' scripts/build-no-xcode.sh
grep -q 'lproj' scripts/build-no-xcode.sh
grep -q 'CFBundleIconFile' Mac/Resources/Info.plist
grep -q 'face_start' "Install LUPY.app/Contents/MacOS/Install-LUPY"
# SELF-CONTAINED INSTALLER LAW (3.4 field failure): the clicked app may be
# translocated or separated from its download folder. It must resolve a
# complete kit from every root, including its verified embedded payload.
grep -q 'LupyKit.zip' "Install LUPY.app/Contents/MacOS/Install-LUPY"
grep -q 'resolve_kit' "Install LUPY.app/Contents/MacOS/Install-LUPY"
grep -q -- '--self-test-kit' "Install LUPY.app/Contents/MacOS/Install-LUPY"
grep -q 'LUPY_INSTALLER_NONINTERACTIVE' "Install LUPY.app/Contents/MacOS/Install-LUPY"
test -x scripts/package-installer.sh
grep -q 'PACKAGE-INSTALLER-OK' scripts/package-installer.sh
# ONE-WINDOW LAW (founder 2026-10-22): the face compiles behind the welcome
# and the window carries steps 2-6; the 3-second popup train stays dead.
grep -q 'face_precompile' "Install LUPY.app/Contents/MacOS/Install-LUPY"
! grep -q '"Stop" "Stop" 3)' "Install LUPY.app/Contents/MacOS/Install-LUPY"
test -f "Install LUPY.app/Contents/Resources/LupyProgress.swift"
# credential-blind builds (3.2's field death): no keychain may ever be asked
grep -q 'disable-keychain' scripts/build-no-xcode.sh
grep -q 'GIT_TERMINAL_PROMPT=0' scripts/build-no-xcode.sh
# native build even under a Rosetta-translated installer (3.3 report: "x86_64" on Apple Silicon)
grep -q 'arch -arm64 swift' scripts/build-no-xcode.sh
# the Setup window's standard manners (3.2 floated, unclosable — founder-rejected)
grep -q 'win.level = .normal' "Install LUPY.app/Contents/Resources/LupyProgress.swift"
grep -q '.miniaturizable' "Install LUPY.app/Contents/Resources/LupyProgress.swift"
grep -q 'applicationShouldHandleReopen' "Install LUPY.app/Contents/Resources/LupyProgress.swift"
grep -q 'badgeLabel' "Install LUPY.app/Contents/Resources/LupyProgress.swift"
# proof + report + stall watchdog
grep -q 'verify_install' "Install LUPY.app/Contents/MacOS/Install-LUPY"
grep -q 'write_report' "Install LUPY.app/Contents/MacOS/Install-LUPY"
grep -q 'STUCK' "Install LUPY.app/Contents/MacOS/Install-LUPY"
# the six step names: one source in each language, byte-identical — never drift
for STEPN in "Check this Mac" "Apple's free tools" "Download one small library" "Compile LUPY" "Install into Applications" "Launch & prove he's alive"; do
  grep -q "$STEPN" "Install LUPY.app/Contents/MacOS/Install-LUPY"
  grep -q "$STEPN" "Install LUPY.app/Contents/Resources/LupyProgress.swift"
done
echo "INSTALL WIRING: SATISFIED (icon ships, registers; standard Setup window; credential-blind; self-contained kit roots; steps in sync)"
echo "== 6c · installer rehearsal (the step machine, stress-run in simulation)"
bash tools/ui/installer-harness.sh | tail -1
echo "== 6c2 · installer roots (beside, nested, translocated, payload, download)"
bash tools/ui/installer-roots-test.sh | tail -1
echo "== 6d · isolation census (the sandbox can parse AppKit, not type-check it —
          no controller may ever again miss its @MainActor: kit 3.3 field, 2026-10-20)"
python3 tools/ui/audit_isolation.py | tail -1
echo "== 6e · declaration census (one module, one name: the two-LupyIslandChatView collision)"
python3 tools/ui/audit_decls.py | tail -1
echo "== 6f · cross-reference audit (no imagined APIs in the never-compiled frontier)"
python3 tools/ui/audit_xref.py | tail -1
echo "== 6g · text bounds council (dynamic text declares its bound)"
python3 tools/ui/audit_text.py | tail -2
echo "== 6h · white-label brand council (donor brand/dev-layer stays invisible)"
python3 tools/ui/audit_brand.py | tail -2
python3 tools/ui/audit_ui.py | tail -1
python3 tools/ui/audit_all.py | tail -1
python3 tools/ui/audit_micro.py | tail -1
echo "BODY GREEN"
