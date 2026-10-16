#!/usr/bin/env bash
# Build Lupy.app (Coucou's macOS app extended with Lupy — Mac/project.yml), Release, Apple Silicon,
# and package it for download.
#   Output: dist/Lupy-<version>-<commit>-macOS-arm64.zip, .sha256, BUILD_INFO.txt
# Requires macOS with Xcode and XcodeGen (brew install xcodegen). Used by CI; also runnable on a Mac.
# Signing: ad-hoc only (no Apple Developer ID, no notarization) — see docs/INSTALL_GUIDE.md.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(grep -m1 'CFBundleShortVersionString' Mac/project.yml | sed -E 's/.*"([^"]+)".*/\1/')
COMMIT=$(git rev-parse --short=10 HEAD 2>/dev/null || echo "local")
NAME="Lupy-${VERSION}-${COMMIT}-macOS-arm64"
APP="build/DerivedData/Build/Products/Release/Lupy.app"

rm -rf build/DerivedData/Build dist
mkdir -p build dist

echo "== Generating Xcode project (XcodeGen $(xcodegen --version 2>/dev/null | tail -1))"
(cd Mac && xcodegen generate --quiet)

echo "== Building Release (arm64, macOS 14.0+)"
set +e
xcodebuild -project Mac/Lupy.xcodeproj -scheme Lupy -configuration Release \
  -derivedDataPath build/DerivedData -clonedSourcePackagesDirPath build/SourcePackages \
  -destination 'generic/platform=macOS' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  build > build/xcodebuild.log 2>&1
status=$?
set -e
# Every distinct compiler error with its file and line (the CI report shows this list).
grep -E "error:|BUILD (SUCCEEDED|FAILED)" build/xcodebuild.log | sed -E 's#^/Users/[^ ]*/(Mac|LupyCore)/#\1/#' | sort -u | head -250 | tee build/errors.txt || true
grep -cE "warning:" build/xcodebuild.log | sed 's/^/warnings: /' || true
if [ $status -ne 0 ]; then
  echo "xcodebuild failed with status $status"
  grep -B2 -A6 -m5 -E "error:" build/xcodebuild.log | sed -E 's#^/Users/[^ ]*/(Mac|LupyCore)/#\1/#' | head -80 || true
  tail -25 build/xcodebuild.log
  exit $status
fi

echo "== Adding licence notices (Coucou MIT text, FluidAudio Apache-2.0, Coucou artwork terms)"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/THIRD_PARTY_NOTICES.txt"
cp Mac/LICENSE-COUCOU-MIT.txt "$APP/Contents/Resources/LICENSE-COUCOU-MIT.txt"
cp Mac/CoucouAssets/NOTICE.md "$APP/Contents/Resources/COUCOU_ARTWORK_PERSONAL_USE.txt"

echo "== Ad-hoc signing"
xattr -cr "$APP"   # no stray extended attributes: they would end up as __MACOSX entries in the zip
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "== Packaging"
# One zip whose only top-level item is Lupy.app. ditto keeps the executable bit, symlinks and the
# code signature intact (a plain artifact upload of the .app folder would strip them).
ditto -c -k --keepParent "$APP" "dist/${NAME}.zip"
(cd dist && shasum -a 256 "${NAME}.zip" > "${NAME}.zip.sha256")
SIZE=$(du -sh "$APP" | cut -f1)

echo "== Checking the package (unzip a copy the way Finder does)"
CHECK="$(mktemp -d)"
ditto -x -k "dist/${NAME}.zip" "$CHECK"
TOP="$(ls -A "$CHECK")"
if [ "$TOP" != "Lupy.app" ]; then
  echo "package must contain exactly Lupy.app at the top level, found: $TOP"
  exit 1
fi
test -x "$CHECK/Lupy.app/Contents/MacOS/Lupy" || { echo "program file missing or not executable in the package"; exit 1; }
codesign --verify --deep --strict "$CHECK/Lupy.app" || { echo "code signature broken inside the package"; exit 1; }
SOUNDS=$(find "$CHECK/Lupy.app/Contents/Resources/sounds" -name '*.wav' 2>/dev/null | wc -l | tr -d ' ')
rm -rf "$CHECK"
echo "package OK: contains only Lupy.app, executable present, signature intact, ${SOUNDS} Coucou sounds"
{
  echo "Lupy ${VERSION} (Coucou $(head -1 Mac/UPSTREAM.txt | cut -d' ' -f2 | cut -c1-7) + Lupy assistant)"
  echo "commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(sw_vers -productName) $(sw_vers -productVersion) ($(uname -m))"
  echo "xcode: $(xcodebuild -version | tr '\n' ' ')"
  echo "architecture: $(lipo -archs "$APP/Contents/MacOS/Lupy")"
  echo "minimum macOS: $(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
  echo "bundle id: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
  echo "app size: ${SIZE}"
  echo "signing: ad-hoc (not Developer ID, not notarized)"
  echo "contains Coucou artwork (icon, sounds, Mochi) for the founder's private personal build only"
  echo "package: ${NAME}.zip — contains only Lupy.app ($(stat -f %z "dist/${NAME}.zip") bytes)"
  echo "sha256: $(cut -d' ' -f1 "dist/${NAME}.zip.sha256")  ${NAME}.zip"
} > dist/BUILD_INFO.txt
cat dist/BUILD_INFO.txt
