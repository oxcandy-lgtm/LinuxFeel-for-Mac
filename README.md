# LinuxFeel for Mac

Linux-like mouse, focus, clipboard, and power behavior for macOS.

LinuxFeel for Mac is an early experimental OSS prototype that explores a few
Linux-style desktop behaviors on Apple hardware.

## Current Status

- Early experimental OSS prototype

## Features

- Middle-click paste: implemented in `mouse-selection/`
- Battery protection helper: implemented in `battery/`
- Focus-follows-mouse: initial experimental prototype in `focus/`
- Control Center UI: manual launch prototype in `ui/`
- Auto-raise: planned

## macOS Permissions

- `mouse-selection` needs Accessibility permission to observe mouse events and
  send copy/paste keystrokes.
- On some macOS releases, Input Monitoring may also be required for event taps.
- `battery` needs administrator privileges because it writes SMC charge-limit
  settings.
- `focus` needs Accessibility permission to focus apps and windows under the
  pointer.

See [docs/permissions.md](docs/permissions.md) for more detail.

## Build

From the repo root:

```sh
./mouse-selection/build.sh
./battery/build.sh
./focus/build.sh
./ui/build.sh
```

The helper binaries are written under each folder's `.build/release/`
directory. The Control Center app bundle is written under `ui/.build/release/`.
To launch it after building:

```sh
open ui/.build/release/LinuxFeelControlCenter.app
```

## Install

Middle-click paste:

```sh
./mouse-selection/install-launch-agent.sh
```

Battery protection helper:

```sh
sudo ./battery/install-home-daemon.sh
```

The default persistent install is `desk`. To opt into CHLS-only `home` mode on
supported hardware:

```sh
sudo ./battery/install-home-daemon.sh home
```

Remove the daemon:

```sh
sudo ./battery/uninstall-daemon.sh
```

Focus-follows-mouse helper:

```sh
./focus/install-launch-agent.sh
```

Remove the focus helper:

```sh
./focus/uninstall-launch-agent.sh
```

## Security and Privacy

This repository is public and should stay free of secrets, private
infrastructure details, local-only paths, private instructions, and unrelated
private project context.

If you think you found a security issue, please follow [SECURITY.md](SECURITY.md)
and use GitHub Security Advisories when available.

## Documentation

- [CLAUDE.md](CLAUDE.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [SECURITY.md](SECURITY.md)
- [docs/permissions.md](docs/permissions.md)
- [docs/roadmap.md](docs/roadmap.md)
- [focus/README.md](focus/README.md)
- [ui/README.md](ui/README.md)

## License

MIT. See [LICENSE](LICENSE).
