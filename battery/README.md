# battery

Experimental battery protection helper for macOS laptops.

The helper adjusts charge limits through Apple SMC keys when they are available.
On machines that expose `CHWA`, it only supports 80% or 100%. On machines that
expose `CHLS`, it can use finer stop thresholds.

## Files

- `mac_charge_limiter.c`: main source file
- `build.sh`: build script
- `install-home-daemon.sh`: install a LaunchDaemon that survives reboot
- `uninstall-daemon.sh`: remove the LaunchDaemon and restore charging to 100%

## Build

```sh
./build.sh
```

The binary is written to:

```text
.build/release/mac-charge-limiter
```

## Modes

```sh
sudo ./.build/release/mac-charge-limiter mode desk
```

Desk mode keeps the limit at 80%.

```sh
sudo ./.build/release/mac-charge-limiter mode home
```

Home mode uses a conservative 60% / 75% cycle on hardware that supports
`CHLS`.

```sh
sudo ./.build/release/mac-charge-limiter mode travel
```

Travel mode allows charging to 100%.

## Keep After Reboot

Install the default home mode:

```sh
sudo ./install-home-daemon.sh
```

Install desk mode instead:

```sh
sudo ./install-home-daemon.sh desk
```

Remove the daemon and restore 100% charging:

```sh
sudo ./uninstall-daemon.sh
```

## Current Behavior

Home mode watches the battery and switches between 75% and 65% limits:

- 60% or below: switch back to 75%
- 75% or above: switch down to 65%

The macOS battery UI may still show charging while the current is effectively
zero. Use `status` or `read-key` to inspect the actual limit and SMC values.

```sh
./.build/release/mac-charge-limiter status
./.build/release/mac-charge-limiter read-key CHLS
```

## Notes

- SMC writes require root privileges.
- Shutdown and deep sleep can let the battery drift above the requested limit.
- macOS updates may change SMC behavior.
- Review before enabling a persistent daemon on hardware you have not tested.
