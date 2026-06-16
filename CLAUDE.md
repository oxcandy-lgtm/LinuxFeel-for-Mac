# CLAUDE.md

## Overview

LinuxFeel for Mac is an experimental macOS utility project that explores
Linux-like mouse, clipboard, and power behavior on Apple hardware.

## Public scope

- `mouse-selection/`: middle-click paste and drag-to-copy helper
- `battery/`: battery charge-limit helper
- Focus-follows-mouse / auto-raise stays planned unless it is explicitly
  implemented and documented

## Build and test

- Build middle-click paste helper: `./mouse-selection/build.sh`
- Build battery helper: `./battery/build.sh`
- If `shellcheck` is installed, run it on any changed shell scripts.
- Before committing, run `git status --short`, inspect `git diff`, and search
  changed files for secrets and private identifiers.

## Code style

- Prefer ASCII unless the file already uses other characters.
- Keep shell scripts POSIX `sh` with `set -eu`.
- Keep C code small, explicit, and warning-clean.
- Prefer simple, reviewable changes over clever abstractions.

## macOS permissions

- The mouse helper needs Accessibility permission and may also need Input
  Monitoring on some macOS versions.
- The battery helper needs administrator privileges because it writes SMC
  charge-limit settings.
- Document any new launchd, background, or permission behavior in the relevant
  README.

## Safety rules

- Never commit secrets, private keys, `.env` files, tokens, credentials, or
  generated artifacts.
- Never add private infrastructure details, local-only paths, hostnames, user
  names, or unrelated private project names.
- Never include private instructions or unrelated personal/project context in
  code, docs, PRs, or comments.
- Keep public docs generic and OSS-facing.
- Keep PRs small and reviewable.
