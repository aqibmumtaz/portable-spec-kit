#!/usr/bin/env bash
# F14 — 12 edge cases for profile setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F14 — Profile setup edge cases"

if kit_grep "Edge Cases" -q; then
  pass "F14: Edge Cases section present"
else
  fail "F14: Edge Cases section missing"
fi

# A few specific edge cases mentioned in framework or skill
for edge in "gh CLI" "GitHub" "skip" "Profile file"; do
  if kit_grep "$edge" -q; then
    pass "F14: edge case '$edge' documented"
  else
    fail "F14: edge case '$edge' missing"
  fi
done
