#!/bin/bash
# Rebuild the menu bar app and restart it cleanly.
#
# Overwriting the app binary while an instance is still running invalidates its
# (ad-hoc) code signature, so macOS kills the process with
# OS_REASON_CODESIGNING on the next launch. Avoid that by STOPPING the running
# instance first, then rebuilding, then starting it again.
set -euo pipefail
cd "$(dirname "$0")"

LABEL="com.local.claudeusage"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"
APP="ClaudeUsage.app"

echo "==> Stopping any running instance…"
if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
fi
# Belt-and-suspenders: kill any stray copy launched outside launchd.
pkill -f "$APP/Contents/MacOS/ClaudeUsage" 2>/dev/null || true
sleep 1

echo "==> Building…"
./build.sh

echo "==> Starting…"
if [ -f "$PLIST" ]; then
    launchctl bootstrap "$DOMAIN" "$PLIST"
    echo "Started via LaunchAgent ($LABEL)."
else
    open "$APP"
    echo "Started via 'open' (no LaunchAgent at $PLIST)."
fi
