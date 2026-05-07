#!/usr/bin/env bash
# F15 — Cross-OS home directory support (macOS/Linux/Windows)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F15 — Cross-OS support"

for os in macOS Linux Windows; do
  if kit_grep "$os" -q; then
    pass "F15: $os referenced"
  else
    fail "F15: $os not referenced"
  fi
done

if kit_grep "symlink" -qi; then
  pass "F15: symlinks discussed (Mac/Linux)"
else
  fail "F15: symlinks not discussed"
fi
