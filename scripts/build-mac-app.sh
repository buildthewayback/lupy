#!/usr/bin/env bash
# Build Lupy.app (Release, Apple Silicon) and package it for download.
#   Output: dist/Lupy-<version>-<commit>-macOS-arm64.zip, .sha256, BUILD_INFO.txt
# Requires macOS with Xcode and XcodeGen (brew install xcodegen). Used by CI; also runnable on a Mac.
# Signing: ad-hoc only (no Apple Developer ID, no notarization) — see docs/INSTALL_GUIDE.md.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(grep -m1 'MARKETING_VERSION' App/project.yml | sed -E 's/.*"([^"]+)".*/\1/')
COMMIT=$(git rev-parse --short=10 HEAD 2>/dev/null || echo "local")
NAME="Lupy-${VERSION}-${COMMIT}-macOS-arm64"
APP="build/DerivedData/Build/Products/Release/Lupy.app"

rm -rf build dist
mkdir -p build dist

echo "== Generating Xcode project (XcodeGen $(xcodegen --version 2>/dev/null | tail -1))"
(cd App && xcodegen generate --quiet)

echo "== Building Release (arm64)"
set +e
xcodebuild -project App/Lupy.xcodeproj -scheme Lupy -configuration Release \
  -derivedDataPath build/DerivedData -destination 'generic/platform=macOS' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  build > build/xcodebuild.log 2>&1
status=$?
set -e
grep -E "error:|BUILD (SUCCEEDED|FAILED)" build/xcodebuild.log | sort -u | head -120 || true
grep -cE "warning:" build/xcodebuild.log | sed 's/^/warnings: /' || true
if [ $status -ne 0 ]; then
  echo "xcodebuild failed with status $status"
  tail -40 build/xcodebuild.log
  exit $status
fi

echo "== Adding third-party licence notices (Coucou MIT text must travel with every copy)"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/THIRD_PARTY_NOTICES.txt"

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
rm -rf "$CHECK"
echo "package OK: contains only Lupy.app, executable present, signature intact"
{
  echo "Lupy ${VERSION}"
  echo "commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(sw_vers -productName) $(sw_vers -productVersion) ($(uname -m))"
  echo "xcode: $(xcodebuild -version | tr '\n' ' ')"
  echo "architecture: $(lipo -archs "$APP/Contents/MacOS/Lupy")"
  echo "minimum macOS: $(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
  echo "bundle id: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
  echo "app size: ${SIZE}"
  echo "signing: ad-hoc (not Developer ID, not notarized)"
  echo "package: ${NAME}.zip — contains only Lupy.app ($(stat -f %z "dist/${NAME}.zip") bytes)"
  echo "sha256: $(cut -d' ' -f1 "dist/${NAME}.zip.sha256")  ${NAME}.zip"
} > dist/BUILD_INFO.txt
cat dist/BUILD_INFO.txt
