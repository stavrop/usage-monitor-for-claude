#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="ClaudeUsage"
APP_DIR="$APP_NAME.app"
BIN="$APP_DIR/Contents/MacOS/$APP_NAME"

echo "Compiling…"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
swiftc -O main.swift -o "$BIN" \
    -framework AppKit -framework Foundation

# App icon (shown in Finder / Login Items; menu bar app has no Dock icon)
if [ -f Resources/ClaudeUsage.icns ]; then
    cp Resources/ClaudeUsage.icns "$APP_DIR/Contents/Resources/ClaudeUsage.icns"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>Usage Monitor for Claude</string>
    <key>CFBundleIdentifier</key><string>com.local.claudeusage</string>
    <key>CFBundleVersion</key><string>0.2.0</string>
    <key>CFBundleShortVersionString</key><string>0.2.0</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>ClaudeUsage</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "Built $APP_DIR"
