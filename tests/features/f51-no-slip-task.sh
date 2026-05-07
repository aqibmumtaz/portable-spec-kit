#!/usr/bin/env bash
# F51 — No-slip task rule
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F51 — No-slip task rule"

if kit_grep "no-slip" -qi || kit_grep "Never let a task slip" -qi; then
  pass "F51: no-slip rule documented"
else
  fail "F51: no-slip rule missing"
fi

if kit_grep "scan for any task" -qi || kit_grep "scan back through" -qi; then
  pass "F51: scan-every-message rule documented"
else
  fail "F51: scan-every-message rule missing"
fi

if kit_grep "Before ending any session" -qi || kit_grep "session-end" -qi; then
  pass "F51: session-end verification documented"
else
  fail "F51: session-end verification missing"
fi
