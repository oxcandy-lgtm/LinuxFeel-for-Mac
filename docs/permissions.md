# Permissions

## mouse-selection

- Accessibility is required so the helper can observe mouse events and send the
  copy/paste shortcuts it synthesizes.
- On some macOS versions, Input Monitoring may also be required for event taps
  to see mouse input reliably.
- If the helper does not start after you grant permission, run the install
  script again.

## battery

- Administrator privileges are required because the helper writes SMC
  charge-limit settings.
- The current prototype is hardware-specific and should be reviewed before
  enabling a persistent LaunchDaemon on a machine you have not tested.

## focus

- Accessibility is required so the helper can request focus for apps and
  windows under the pointer.
- The helper runs as a per-user LaunchAgent and does not require root.
- Review the behavior before enabling it as a login helper.

## General notes

- Grant permissions to the app that actually launches the helper.
- If you change a permission in System Settings, relaunch the helper or rerun
  the install script so launchd picks up the new state.
