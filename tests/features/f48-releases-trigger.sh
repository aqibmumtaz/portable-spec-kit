#!/usr/bin/env bash
# F48 — RELEASES.md trigger rule
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F48 — RELEASES.md trigger"

if kit_grep "RELEASES.md" -q; then
  pass "F48: RELEASES.md referenced"
else
  fail "F48: RELEASES.md not referenced"
fi

if kit_grep "trigger rule" -qi || kit_grep "add a release entry" -qi || kit_grep "release entry" -qi; then
  pass "F48: release-entry trigger documented"
else
  fail "F48: release-entry trigger missing"
fi

if [ -f "$PROJ/agent/RELEASES.md" ]; then
  pass "F48: kit's RELEASES.md present"
else
  fail "F48: kit's RELEASES.md missing"
fi
