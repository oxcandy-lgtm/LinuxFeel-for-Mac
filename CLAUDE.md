# CLAUDE.md

## Overview

LinuxFeel for Mac is an experimental macOS utility project that explores
Linux-like mouse, clipboard, and power behavior on Apple hardware.

## Public scope

- `mouse-selection/`: middle-click paste and drag-to-copy helper
- `battery/`: battery charge-limit helper
- `focus/`: initial focus-follows-mouse helper
- `ui/`: manual Control Center surface for helper inspection and command copying
- Auto-raise stays planned unless it is explicitly implemented and documented

## Build and test

Run the standard local checks before opening a PR:

```sh
./scripts/public-surface-scrub.sh
find . -type f -name '*.sh' -not -path './.git/*' -not -path '*/.build/*' -print0 | xargs -0 -n1 sh -n
./mouse-selection/build.sh
./battery/build.sh
./focus/build.sh
./ui/build.sh
```

Before committing, run `git status --short` and inspect `git diff`.

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
- The focus helper needs Accessibility permission to request focus changes.
- The Control Center UI does not request special permissions; it only copies
  commands and opens local docs.
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
