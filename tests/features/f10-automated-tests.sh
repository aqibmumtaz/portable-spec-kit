#!/usr/bin/env bash
# F10 — 122 automated tests (kit baseline)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F10 — Automated test suite"

if [ -f "$PROJ/tests/test-spec-kit.sh" ]; then
  pass "F10: test-spec-kit.sh exists"
else
  fail "F10: test-spec-kit.sh missing"
fi

if grep -q "SECTIONS=(" "$PROJ/tests/test-spec-kit.sh"; then
  pass "F10: orchestrator declares SECTIONS array"
else
  fail "F10: SECTIONS array missing"
fi

if [ -d "$PROJ/tests/sections" ]; then
  pass "F10: sections/ dir present"
else
  fail "F10: sections/ dir missing"
fi

# Count section files
sec_count=$(ls "$PROJ/tests/sections/"*.sh 2>/dev/null | wc -l)
if [ "$sec_count" -ge 4 ]; then
  pass "F10: $sec_count section files (>=4)"
else
  fail "F10: too few section files ($sec_count)"
fi
