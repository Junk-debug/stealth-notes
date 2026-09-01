#!/bin/bash
# Builds Stealth Notes.app from the Swift package and bundled resources.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="Stealth Notes.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/StealthNotes "$APP/Contents/MacOS/StealthNotes"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/Fonts "$APP/Contents/Resources/Fonts"

echo "Built: $APP"
if [[ "${1:-}" == "--install" ]]; then
    pkill -x StealthNotes || true
    rm -rf "/Applications/$APP"
    cp -R "$APP" "/Applications/$APP"
    echo "Installed to /Applications/$APP"
fi
