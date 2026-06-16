# Contributing

Thanks for helping improve LinuxFeel for Mac.

## What to keep in mind

- Keep changes small and reviewable.
- Keep the public surface clean.
- Avoid secrets, private paths, hostnames, usernames, credentials, or unrelated
  private project context.
- Update the relevant README or docs when behavior or permissions change.

## Working style

- Prefer ASCII unless the file already uses something else.
- Keep shell scripts POSIX `sh` and use `set -eu`.
- Keep C code explicit and warning-clean.
- Prefer simple, easy-to-review changes over clever abstractions.

## Before opening a PR

- Run the relevant build scripts.
- Inspect `git diff`.
- Search the changed files for secrets, private identifiers, and private
  instructions.

## Pull Requests

- One logical change per PR.
- Describe any macOS permission or installation impact clearly.
- Call out anything that was not verified locally.
