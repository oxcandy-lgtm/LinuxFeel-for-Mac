#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$ROOT_DIR/.build/release/mac-charge-limiter"
LABEL="org.linuxfeel.mac-charge-limiter"
LEGACY_LABEL="local.mac-charge-limiter"
PLIST="/Library/LaunchDaemons/$LABEL.plist"
LEGACY_PLIST="/Library/LaunchDaemons/$LEGACY_LABEL.plist"
MODE="${1:-desk}"

cleanup_existing_install() {
  launchctl disable "system/$LABEL" >/dev/null 2>&1 || true
  launchctl disable "system/$LEGACY_LABEL" >/dev/null 2>&1 || true
  launchctl bootout system "$LEGACY_PLIST" >/dev/null 2>&1 || true
  launchctl bootout system "$PLIST" >/dev/null 2>&1 || true
  rm -f "$PLIST" "$LEGACY_PLIST"
}

mode_supported() {
  case "$1" in
    desk|travel)
      if "$BIN" read-key CHLS >/dev/null 2>&1; then
        return 0
      fi
      if "$BIN" read-key CHWA >/dev/null 2>&1; then
        return 0
      fi
      return 1
      ;;
    home)
      "$BIN" read-key CHLS >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

case "$MODE" in
  desk|home)
    ;;
  *)
    echo "Usage: sudo ./battery/install-home-daemon.sh [desk|home] (default: desk)" >&2
    exit 1
    ;;
esac

if [ "$(id -u)" -ne 0 ]; then
  echo "Run with sudo: sudo ./battery/install-home-daemon.sh [desk|home] (default: desk)" >&2
  exit 1
fi

if [ ! -x "$BIN" ]; then
  "$ROOT_DIR/build.sh"
fi

if ! mode_supported "$MODE"; then
  cleanup_existing_install
  if [ "$MODE" = "home" ]; then
    echo "Home mode requires CHLS on this Mac, so no LaunchDaemon was installed." >&2
  else
    echo "Requested battery mode '$MODE' is not supported on this Mac." >&2
  fi
  exit 1
fi

cleanup_existing_install

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN</string>
EOF

if [ "$MODE" = "home" ]; then
  cat >> "$PLIST" <<EOF
    <string>watch-home</string>
EOF
else
  cat >> "$PLIST" <<EOF
    <string>watch</string>
    <string>80</string>
EOF
fi

cat >> "$PLIST" <<EOF
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/var/log/mac-charge-limiter.log</string>
  <key>StandardErrorPath</key>
  <string>/var/log/mac-charge-limiter.err</string>
</dict>
</plist>
EOF

chown root:wheel "$PLIST"
chmod 644 "$PLIST"
launchctl bootstrap system "$PLIST"
launchctl enable "system/$LABEL"
"$BIN" mode "$MODE"

echo "Installed. Mode is set to $MODE."
