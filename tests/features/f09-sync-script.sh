#!/usr/bin/env bash
# F9 — Sync script (sync.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/repo-structure.sh"

section "F9 — Sync script (sync.sh)"

if [ -f "$PROJ/agent/scripts/sync.sh" ]; then
  pass "F9: sync.sh exists"
else
  fail "F9: sync.sh missing"
fi

if [ -x "$PROJ/agent/scripts/sync.sh" ]; then
  pass "F9: sync.sh executable"
else
  fail "F9: sync.sh not executable"
fi

assert_kit_root_file "install.sh" "F9: install.sh"

if [ -x "$PROJ/install.sh" ]; then
  pass "F9: install.sh executable"
else
  fail "F9: install.sh not executable"
fi
