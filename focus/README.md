# focus

Experimental focus-follows-mouse helper for macOS.

The helper watches the pointer position and, after a short delay, asks
Accessibility to focus the app or window under the pointer. It is a conservative
prototype for Linux/X11-style focus behavior.

## What it does

- Polls the pointer at a modest interval.
- Finds a visible window under the pointer using public CoreGraphics window
  information.
- Focuses the target through Accessibility after the pointer stays over it
  briefly.
- Avoids repeated focus calls when the target has not changed.
- Skips focus changes while a mouse button is held down.

## What it does not do

- It is not a full X11 window-manager clone.
- It does not synthesize clicks.
- It does not call a window raise action or implement auto-raise yet.
- It does not require root, use networking, collect telemetry, or store user
  data.

## Permissions

Accessibility permission is required so the helper can focus apps and windows.

On macOS, open:

```text
System Settings
-> Privacy & Security
-> Accessibility
-> allow focus-follows-mouse or the app you use to launch it
```

## Build

```sh
./build.sh
```

The binary is written to:

```text
.build/release/focus-follows-mouse
```

## Install

```sh
./install-launch-agent.sh
```

If needed, rerun the install script after granting Accessibility permission.

## Uninstall

```sh
./uninstall-launch-agent.sh
```

## Check

```sh
launchctl print "gui/$(id -u)/org.linuxfeel.focus-follows-mouse"
tail -n 50 "$HOME/Library/Logs/focus-follows-mouse.log"
tail -n 50 "$HOME/Library/Logs/focus-follows-mouse.err"
```

## Known limitations

- Some apps may reject Accessibility focus requests.
- Minimized, hidden, or unusual window types may not be detected.
- The helper focuses only after a delay to reduce accidental focus changes.
- Focus requests may activate the target app, depending on app and macOS
  behavior.
- Auto-raise is planned, but not implemented in this prototype.

Review the behavior before enabling it as a login helper.
