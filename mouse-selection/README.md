# mouse-selection

Experimental middle-click paste helper for macOS.

This helper approximates Linux or X11-style behavior:

- select text, release, and the helper sends `Cmd+C` after a short delay
- middle-click sends `Cmd+V`
- the middle-click event is swallowed so paste wins over the app's own middle-
  click action

This is not a real PRIMARY selection. macOS does not provide one, so the helper
uses the normal clipboard.

## Files

- `selection_paste.c`: main source file
- `build.sh`: build script
- `install-launch-agent.sh`: install a LaunchAgent that starts at login
- `uninstall-launch-agent.sh`: remove the LaunchAgent

## Behavior

- Left-drag a selection and release: send `Cmd+C` after a short delay
- Middle-click: send `Cmd+V`
- Middle-click is swallowed so the paste action takes priority

## Build

```sh
./build.sh
```

The binary is written to:

```text
.build/release/selection-paste
```

## Install

```sh
./install-launch-agent.sh
```

The first run needs Accessibility permission.

On macOS, open:

```text
System Settings
-> Privacy & Security
-> Accessibility
-> allow selection-paste or the app you use to launch it
```

If needed, rerun the install script after granting permission.

## Uninstall

```sh
./uninstall-launch-agent.sh
```

## Check

```sh
launchctl print "gui/$(id -u)/org.linuxfeel.selection-paste"
tail -n 50 "$HOME/Library/Logs/selection-paste.log"
tail -n 50 "$HOME/Library/Logs/selection-paste.err"
```

## Notes

- The normal clipboard is overwritten each time a selection is copied.
- Password fields and copy-protected UI may not work.
- Non-text drags, such as Finder file drags, may still trigger a `Cmd+C`.
- On some macOS versions, Input Monitoring may also be required for the event
  tap to see mouse input.
