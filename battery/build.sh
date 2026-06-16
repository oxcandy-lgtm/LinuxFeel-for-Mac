#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$ROOT_DIR/.build/release"
clang \
  "$ROOT_DIR/mac_charge_limiter.c" \
  -Wall \
  -Wextra \
  -Werror \
  -O2 \
  -framework IOKit \
  -framework CoreFoundation \
  -o "$ROOT_DIR/.build/release/mac-charge-limiter"

echo "$ROOT_DIR/.build/release/mac-charge-limiter"
