#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$ROOT_DIR/.build/release"
clang \
  "$ROOT_DIR/selection_paste.c" \
  -Wall \
  -Wextra \
  -O2 \
  -framework ApplicationServices \
  -framework CoreFoundation \
  -o "$ROOT_DIR/.build/release/selection-paste"

echo "$ROOT_DIR/.build/release/selection-paste"
