#!/bin/sh
set -eu

LABEL="org.linuxfeel.selection-paste"
LEGACY_LABEL="local.selection-paste"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LEGACY_PLIST="$HOME/Library/LaunchAgents/$LEGACY_LABEL.plist"

launchctl disable "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl disable "gui/$(id -u)/$LEGACY_LABEL" >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)" "$LEGACY_PLIST" >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST" "$LEGACY_PLIST"

echo "Uninstalled selection-paste LaunchAgent."
