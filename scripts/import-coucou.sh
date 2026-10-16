#!/usr/bin/env bash
# Imports the Coucou macOS app (github.com/Louis-CFM/coucou, MIT code + reserved assets) into Mac/.
#
#   scripts/import-coucou.sh <path-to-coucou-checkout> [commit]
#
# Copies the Mac sources unmodified so every Lupy change is a reviewable diff against upstream:
#   NotchBuddy/Sources/App, Sources/CoucouKit   -> Mac/Sources/App, Mac/Sources/CoucouKit
#   NotchBuddy/Resources/{Info.plist,Localizable.xcstrings} -> Mac/Resources/
#   tests/*.swift + scripts/test-*.sh            -> Mac/Tests/coucou/ (paths rewritten to Mac/)
# Reserved artwork goes to ONE folder, Mac/CoucouAssets/, so it can be swapped out independently:
#   NotchBuddy/Assets.xcassets (app icon, menu-bar icon), NotchBuddy/Resources/sounds
# The Mochi character itself is drawn in code; the files that embody it are listed in
# Mac/CoucouAssets/NOTICE.md. iPhone, widgets, Android, Windows and Linux are not imported.
set -euo pipefail
SRC="${1:?usage: import-coucou.sh <coucou checkout> [commit]}"
REV="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Mac"

if [ -n "$REV" ]; then git -C "$SRC" checkout -q "$REV"; fi
COMMIT=$(git -C "$SRC" rev-parse HEAD)
UP="$SRC/NotchBuddy"
[ -d "$UP/Sources/App" ] || { echo "not a Coucou checkout: $SRC" >&2; exit 1; }

rm -rf "$DEST/Sources/App" "$DEST/Sources/CoucouKit" "$DEST/CoucouAssets/Assets.xcassets" \
       "$DEST/CoucouAssets/sounds" "$DEST/Tests/coucou"
mkdir -p "$DEST/Sources" "$DEST/Resources" "$DEST/CoucouAssets" "$DEST/Tests/coucou"

cp -R "$UP/Sources/App" "$DEST/Sources/App"
cp -R "$UP/Sources/CoucouKit" "$DEST/Sources/CoucouKit"
cp "$UP/Resources/Info.plist" "$UP/Resources/Localizable.xcstrings" "$DEST/Resources/"
cp -R "$UP/Assets.xcassets" "$DEST/CoucouAssets/Assets.xcassets"
cp -R "$UP/Resources/sounds" "$DEST/CoucouAssets/sounds"
cp "$SRC/LICENSE" "$DEST/LICENSE-COUCOU-MIT.txt"
cp "$SRC/LICENSE-ASSETS.md" "$DEST/CoucouAssets/LICENSE-ASSETS.md"

cp "$SRC"/tests/*.swift "$DEST/Tests/coucou/"
for t in "$SRC"/scripts/test-*.sh; do
  # Upstream scripts cd to the repo root and use NotchBuddy/Sources and tests/; ours live in Mac/Tests/coucou.
  sed -e 's#cd "$(dirname "$0")/.."#cd "$(dirname "$0")/../../.."#' \
      -e 's#NotchBuddy/Sources/#Mac/Sources/#g' \
      -e 's#\([ "]\)tests/#\1Mac/Tests/coucou/#g' \
      "$t" > "$DEST/Tests/coucou/$(basename "$t")"
  chmod +x "$DEST/Tests/coucou/$(basename "$t")"
done

printf 'Louis-CFM/coucou %s\nimported %s\n' "$COMMIT" "$(date -u +%Y-%m-%dT%H:%MZ)" > "$DEST/UPSTREAM.txt"
echo "imported Coucou $COMMIT into $DEST"
echo "swift files: $(find "$DEST/Sources" -name '*.swift' | wc -l)"
