#!/bin/sh
set -eu

LABEL="org.linuxfeel.focus-follows-mouse"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl disable "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST"

echo "Uninstalled focus-follows-mouse LaunchAgent."
