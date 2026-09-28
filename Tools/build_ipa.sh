#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${FACTORIO_APP:-/Applications/factorio.app}"
GAME_DATA="$APP/Contents/data"
DESTINATION="$ROOT/Vendor/FactorioData"
OUTPUT="$ROOT/dist/FactorioPad.ipa"

if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != '--prepare-only' ]; }; then
    echo "Usage: bash Tools/build_ipa.sh [--prepare-only]" >&2
    exit 2
fi

if [ ! -f "$APP/Contents/MacOS/factorio" ] || [ ! -d "$GAME_DATA/base" ]; then
    echo "ERROR: Set FACTORIO_APP to your installed Mac Factorio.app." >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"

mkdir -p "$ROOT/Vendor"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/factoriopad-ipa.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

if [ ! -d "$DESTINATION" ]; then
    echo "Copying game data from your local installation..."
    /usr/bin/ditto "$GAME_DATA" "$WORK/FactorioData"
    mv "$WORK/FactorioData" "$DESTINATION"
fi

DATA_VERSION="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["version"])' "$DESTINATION/base/info.json")"
if [ "$DATA_VERSION" != "$VERSION" ]; then
    echo "ERROR: Local game data is $DATA_VERSION, but the installed game is $VERSION." >&2
    echo "Move Vendor/FactorioData aside, then run this script again." >&2
    exit 1
fi

ICON="$ROOT/FactorioPad/Assets.xcassets/AppIcon.appiconset/icon.png"
if [ ! -f "$ICON" ]; then
    /usr/bin/sips -s format png -z 1024 1024 \
        "$APP/Contents/Resources/factorio.icns" --out "$ICON" >/dev/null
fi

FACTORIO_APP="$APP" "$ROOT/Tools/prepare_guest.sh"

if [ "${1:-}" = '--prepare-only' ]; then
    echo "Game files ready. Open FactorioPad.xcodeproj in Xcode."
    exit 0
fi

mkdir -p "$ROOT/dist"

xcodebuild -quiet \
    -project "$ROOT/FactorioPad.xcodeproj" \
    -scheme FactorioPad \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$WORK/DerivedData" \
    CODE_SIGNING_ALLOWED=NO build

PRODUCT="$WORK/DerivedData/Build/Products/Release-iphoneos/FactorioPad.app"
test -f "$PRODUCT/FactorioPad"
test -f "$PRODUCT/Frameworks/FactorioGuest.framework/FactorioGuest"
test -d "$PRODUCT/FactorioData/base"

mkdir -p "$WORK/Payload"
mv "$PRODUCT" "$WORK/Payload/FactorioPad.app"
/usr/bin/ditto -c -k --keepParent "$WORK/Payload" "$WORK/FactorioPad.ipa"
/usr/bin/unzip -tq "$WORK/FactorioPad.ipa" >/dev/null
mv -f "$WORK/FactorioPad.ipa" "$OUTPUT"

echo "Unsigned IPA ready: $OUTPUT"
echo "Install it through AltStore Classic or SideStore, which signs it with your Apple Account."
