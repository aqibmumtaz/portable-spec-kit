#!/usr/bin/env bash
# F4 — Agent guidance behavior rules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F4 — Agent guidance behavior rules"

if kit_grep "Agent Guidance" -qi; then
  pass "F4: framework documents agent guidance"
else
  fail "F4: agent guidance missing"
fi

if kit_grep "helpful guide" -qi; then
  pass "F4: 'helpful guide' philosophy present"
else
  fail "F4: 'helpful guide' philosophy missing"
fi

if kit_grep "Don't block the user" -qi || kit_grep "never blocks" -qi; then
  pass "F4: non-blocking principle documented"
else
  fail "F4: non-blocking principle missing"
fi

if kit_grep "Fill gaps proactively" -qi; then
  pass "F4: proactive gap-filling rule present"
else
  fail "F4: proactive gap-filling missing"
fi
