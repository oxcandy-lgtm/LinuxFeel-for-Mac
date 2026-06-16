#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

tmp_files="${TMPDIR:-/tmp}/linuxfeel-public-surface-files.$$"
trap 'rm -f "$tmp_files"' EXIT HUP INT TERM

find . \
  \( \
    -path './.git' -o \
    -path './.git/*' -o \
    -path '*/.build' -o \
    -path '*/.build/*' -o \
    -path './.vscode' -o \
    -path './.vscode/*' -o \
    -path './.idea' -o \
    -path './.idea/*' \
  \) -prune -o \
  -type f \
  ! -name '*.o' \
  ! -name '*.a' \
  ! -name '*.dylib' \
  ! -name '*.so' \
  ! -name '*.dSYM' \
  ! -name '*.log' \
  ! -name '*.err' \
  ! -name '*.tmp' \
  ! -name '*.swp' \
  ! -name '*.swo' \
  -print > "$tmp_files"

scanned_count="$(wc -l < "$tmp_files" | tr -d ' ')"
failures=0

report_failure() {
  label="$1"
  file="$2"
  line="$3"

  failures=1
  printf 'public-surface-scrub: %s: %s:%s\n' "$label" "$file" "$line" >&2
}

check_pattern() {
  label="$1"
  pattern="$2"

  while IFS= read -r file; do
    if ! grep -Iq . "$file"; then
      continue
    fi

    matches="$(grep -n -E "$pattern" "$file" || true)"
    if [ -n "$matches" ]; then
      failures=1
      printf '%s\n' "$matches" | while IFS= read -r line; do
        printf 'public-surface-scrub: %s: %s:%s\n' "$label" "$file" "$line" >&2
      done
    fi
  done < "$tmp_files"
}

check_env_files() {
  while IFS= read -r file; do
    case "$(basename "$file")" in
      .env|.env.*)
        report_failure "environment file" "$file" "1:.env files must not be committed"
        ;;
    esac
  done < "$tmp_files"
}

private_key_pattern='BEGIN [^-]*PRIVATE KEY|END [^-]*PRIVATE KEY'
token_pattern='ghp_[[:alnum:]_]{20,}|github_pat_[[:alnum:]_]{20,}|glpat-[[:alnum:]_-]{20,}|xox[baprs]-[[:alnum:]-]{20,}|AKIA[0-9A-Z]{16}|sk-[[:alnum:]]{20,}'
secret_assignment_pattern='(API_?KEY|ACCESS_?TOKEN|AUTH_?TOKEN|SECRET|PASSWORD|PASSWD)[[:alnum:]_ -]*=[[:space:]]*[^[:space:]]{8,}'
local_path_pattern='/(Users|home|var/www)/[[:graph:]]+'
network_pattern='([0-9]{1,3}\.){3}[0-9]{1,3}'
private_surface_pattern="control""-plane|hidden pro""mpt|system pro""mpt|handoff tem""plate|private govern""ance|internal govern""ance|operator con""text|V""PS|private serv""er|private dom""ain|internal""-only"

check_env_files
check_pattern "private key marker" "$private_key_pattern"
check_pattern "token-like string" "$token_pattern"
check_pattern "secret-like assignment" "$secret_assignment_pattern"
check_pattern "local absolute path" "$local_path_pattern"
check_pattern "IP address" "$network_pattern"
check_pattern "private/internal wording" "$private_surface_pattern"

if [ "$failures" -ne 0 ]; then
  printf 'public-surface-scrub: scanned %s files; failures found\n' "$scanned_count" >&2
  exit 1
fi

printf 'public-surface-scrub: scanned %s files; clean\n' "$scanned_count"
