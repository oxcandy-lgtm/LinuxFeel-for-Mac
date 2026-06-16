#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$ROOT_DIR/.build/release"
clang \
  "$ROOT_DIR/focus_follows_mouse.c" \
  -Wall \
  -Wextra \
  -Werror \
  -O2 \
  -framework ApplicationServices \
  -framework CoreFoundation \
  -o "$ROOT_DIR/.build/release/focus-follows-mouse"

echo "$ROOT_DIR/.build/release/focus-follows-mouse"
