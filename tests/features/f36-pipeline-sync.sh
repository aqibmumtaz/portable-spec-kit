#!/usr/bin/env bash
# F36 — Pipeline sync rules — all files stay in sync
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F36 — Pipeline sync"

if kit_grep "Sync rule" -qi; then
  pass "F36: §Sync rule documented"
else
  fail "F36: §Sync rule missing"
fi

if kit_grep "in sync" -qi || kit_grep "stay in sync" -qi; then
  pass "F36: 'stay in sync' rule documented"
else
  fail "F36: 'stay in sync' rule missing"
fi

if [ -f "$PROJ/agent/scripts/psk-sync-check.sh" ]; then
  pass "F36: psk-sync-check.sh present"
else
  fail "F36: psk-sync-check.sh missing"
fi
