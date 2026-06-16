#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$ROOT_DIR/.build/release/mac-charge-limiter"
LABEL="org.linuxfeel.mac-charge-limiter"
LEGACY_LABEL="local.mac-charge-limiter"
PLIST="/Library/LaunchDaemons/$LABEL.plist"
LEGACY_PLIST="/Library/LaunchDaemons/$LEGACY_LABEL.plist"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run with sudo: sudo ./battery/uninstall-daemon.sh" >&2
  exit 1
fi

launchctl disable "system/$LABEL" >/dev/null 2>&1 || true
launchctl disable "system/$LEGACY_LABEL" >/dev/null 2>&1 || true
launchctl bootout system "$LEGACY_PLIST" >/dev/null 2>&1 || true
launchctl bootout system "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST" "$LEGACY_PLIST"

if [ -x "$BIN" ]; then
  "$BIN" set 100
fi

echo "Uninstalled. Charge limit is back to 100%."
