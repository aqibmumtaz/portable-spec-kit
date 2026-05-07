#!/usr/bin/env bash
# F23 — Automated tests across multiple sections
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F23 — Automated test suite (multi-section)"

if [ -d "$PROJ/tests/sections" ]; then
  pass "F23: sections/ dir present"
else
  fail "F23: sections/ dir missing"
fi

sec_count=$(ls "$PROJ/tests/sections/"*.sh 2>/dev/null | wc -l)
if [ "$sec_count" -ge 4 ]; then
  pass "F23: $sec_count thematic sections (>=4)"
else
  fail "F23: too few sections ($sec_count)"
fi

# Each section runnable independently (has shebang)
for s in "$PROJ"/tests/sections/*.sh; do
  if head -1 "$s" | grep -q "bash"; then
    pass "F23: $(basename $s) has shebang"
  else
    fail "F23: $(basename $s) missing shebang"
  fi
done
