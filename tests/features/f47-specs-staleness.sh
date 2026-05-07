#!/usr/bin/env bash
# F47 — SPECS.md staleness check
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F47 — SPECS.md staleness check"

if kit_grep "Staleness check" -qi || kit_grep "staleness" -qi; then
  pass "F47: staleness check rule documented"
else
  fail "F47: staleness check rule missing"
fi

if kit_grep "non-empty ≠ current" -q || kit_grep "Non-empty.*not.*current" -qi; then
  pass "F47: 'non-empty ≠ current' principle present"
else
  fail "F47: 'non-empty ≠ current' principle missing"
fi

if kit_grep "TASKS.md" -q && kit_grep "SPECS.md" -q; then
  pass "F47: TASKS↔SPECS cross-check documented"
else
  fail "F47: TASKS↔SPECS cross-check missing"
fi
