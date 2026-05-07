#!/usr/bin/env bash
# F33 — Context management rule
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F33 — Context management"

if kit_grep "Context Management" -qi; then
  pass "F33: §Context Management present"
else
  fail "F33: §Context Management missing"
fi

if kit_grep "AGENT_CONTEXT" -q; then
  pass "F33: AGENT_CONTEXT.md referenced"
else
  fail "F33: AGENT_CONTEXT.md not referenced"
fi

if kit_grep "Two-tier" -qi || kit_grep "Tier 1" -q; then
  pass "F33: two-tier update rule documented"
else
  fail "F33: two-tier update rule missing"
fi
