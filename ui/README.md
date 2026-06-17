# LinuxFeel Control Center

LinuxFeel Control Center is a manually launched AppKit prototype for inspecting
the existing LinuxFeel helpers from one place.

This is a read/copy surface, not a background service.

## What it shows

- `mouse-selection`
- `focus`
- `battery`

For each helper, the Control Center shows a short description, build output
path, commands to copy, permission notes, and a link to the helper README.

## What it does not do

- It does not add a menu bar status item.
- It does not move or replace the native macOS menu bar.
- It does not create a floating panel.
- It does not start or stop helpers automatically.
- It does not run `sudo`.
- It does not request Accessibility permission itself.

## Build

```sh
./ui/build.sh
```

The preferred output is:

```text
ui/.build/release/LinuxFeelControlCenter.app
```

## Launch

After building, open the app bundle:

```sh
open ui/.build/release/LinuxFeelControlCenter.app
```

## Helper sections

### mouse-selection

Description:

`Middle-click paste and drag-to-copy helper.`

Build output:

```text
mouse-selection/.build/release/selection-paste
```

Commands:

```sh
./mouse-selection/build.sh
./mouse-selection/install-launch-agent.sh
./mouse-selection/uninstall-launch-agent.sh
launchctl print "gui/$(id -u)/org.linuxfeel.selection-paste"
tail -n 50 "$HOME/Library/Logs/selection-paste.log"
tail -n 50 "$HOME/Library/Logs/selection-paste.err"
```

Permission note:

`Requires Accessibility permission. Some macOS versions may also require Input Monitoring.`

### focus

Description:

`Experimental focus-follows-mouse helper.`

Build output:

```text
focus/.build/release/focus-follows-mouse
```

Commands:

```sh
./focus/build.sh
./focus/install-launch-agent.sh
./focus/uninstall-launch-agent.sh
launchctl print "gui/$(id -u)/org.linuxfeel.focus-follows-mouse"
tail -n 50 "$HOME/Library/Logs/focus-follows-mouse.log"
tail -n 50 "$HOME/Library/Logs/focus-follows-mouse.err"
```

Permission note:

`Requires Accessibility permission. Does not implement auto-raise yet.`

### battery

Description:

`Experimental battery charge-limit helper.`

Build output:

```text
battery/.build/release/mac-charge-limiter
```

Commands:

```sh
./battery/build.sh
sudo ./battery/install-home-daemon.sh
sudo ./battery/install-home-daemon.sh home
sudo ./battery/uninstall-daemon.sh
./battery/.build/release/mac-charge-limiter status
./battery/.build/release/mac-charge-limiter read-key CHLS
```

Permission note:

`Battery helper requires administrator privileges for persistent daemon install and SMC writes. The UI does not run these commands automatically.`

## Native menu bar

LinuxFeel Control Center does not move, replace, or reposition the native macOS
menu bar.

Native menu bar placement is controlled by macOS system behavior and settings,
not LinuxFeel.

Future LinuxFeel-owned UI surfaces may be explored separately, but this PR only
adds a manually launched Control Center.
