#!/bin/zsh
# Wrap the Lantern executable in a minimal .app bundle.
# Needed because macOS won't show a status item (or post notifications)
# for a bare, unbundled executable.
set -euo pipefail

cd "$(dirname "$0")/.."
swift build

APP=.build/Lantern.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/debug/Lantern "$APP/Contents/MacOS/Lantern"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>io.angie.lantern</string>
    <key>CFBundleName</key><string>Lantern</string>
    <key>CFBundleExecutable</key><string>Lantern</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "built $APP"
