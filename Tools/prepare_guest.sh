#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

APP="${FACTORIO_APP:-/Applications/factorio.app}"
SOURCE="$APP/Contents/MacOS/factorio"

DESTINATION="$ROOT/Vendor/FactorioGuest.framework"

if [ ! -f "$SOURCE" ]; then
    echo "ERROR: Factorio executable not found:"
    echo "$SOURCE"
    exit 1
fi

GAME_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"

echo "=== SOURCE ==="
echo "$SOURCE"

mkdir -p "$ROOT/Vendor"
PREPARATION_LOCK="$ROOT/Vendor/.factorio-guest.lock"
if ! mkdir "$PREPARATION_LOCK"; then
    echo "ERROR: Another preparation is running, or a previous run left $PREPARATION_LOCK. Inspect it before retrying." >&2
    exit 1
fi
STAGING_ROOT=""
cleanup() {
    if [ -n "$STAGING_ROOT" ]; then
        if [ -d "$STAGING_ROOT/previous.framework" ] && [ ! -e "$DESTINATION" ]; then
            if ! mv "$STAGING_ROOT/previous.framework" "$DESTINATION"; then
                echo "ERROR: Restore failed. The previous framework is preserved at $STAGING_ROOT/previous.framework" >&2
                return 1
            fi
        fi
        rm -rf "$STAGING_ROOT"
    fi
    rmdir "$PREPARATION_LOCK"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
STAGING_ROOT="$(mktemp -d "$ROOT/Vendor/.factorio-guest.XXXXXX")"
FRAMEWORK="$STAGING_ROOT/FactorioGuest.framework"
BINARY="$FRAMEWORK/FactorioGuest"
mkdir "$FRAMEWORK"

echo
echo "=== EXTRACT ARM64 ==="

lipo \
    "$SOURCE" \
    -thin arm64 \
    -output "$BINARY"

chmod +x "$BINARY"

echo
echo "=== BEFORE PATCH ==="
file "$BINARY"
otool -hv "$BINARY"

echo
echo "=== PATCH ==="

python3 \
    "$ROOT/Tools/patch_factorio.py" \
    "$BINARY"

echo
echo "=== REMOVE OLD SIGNATURE ==="

codesign --remove-signature "$BINARY" 2>/dev/null || true

cat > "$FRAMEWORK/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC
"-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>

    <key>CFBundleExecutable</key>
    <string>FactorioGuest</string>

    <key>CFBundleIdentifier</key>
    <string>pl.adrian.FactorioPad.FactorioGuest</string>

    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>

    <key>CFBundleName</key>
    <string>FactorioGuest</string>

    <key>CFBundlePackageType</key>
    <string>FMWK</string>

    <key>CFBundleShortVersionString</key>
    <string>$GAME_VERSION</string>

    <key>CFBundleVersion</key>
    <string>1</string>

    <key>MinimumOSVersion</key>
    <string>17.0</string>
</dict>
</plist>
PLIST

echo
echo "=== AFTER PATCH ==="

file "$BINARY"

echo
otool -hv "$BINARY"

echo
echo "--- LC_ID_DYLIB ---"
otool -D "$BINARY"

echo
echo "--- BUILD VERSION ---"
vtool -show-build "$BINARY"

echo
echo "--- LIBRARIES ---"
otool -L "$BINARY"

echo
echo "--- PAGEZERO ---"
otool -l "$BINARY" | grep -A12 '__PAGEZERO'

echo
echo "--- LC_ID_DYLIB ---"
otool -l "$BINARY" | grep -A8 'LC_ID_DYLIB'

echo
echo "=== DONE ==="
if [ -e "$DESTINATION" ]; then
    mv "$DESTINATION" "$STAGING_ROOT/previous.framework"
fi
mv "$FRAMEWORK" "$DESTINATION"
echo "$DESTINATION"
