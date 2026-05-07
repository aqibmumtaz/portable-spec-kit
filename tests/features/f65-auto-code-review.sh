#!/usr/bin/env bash
# F65 — Auto Code Review
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F65 — Auto Code Review"

if [ -f "$PROJ/agent/scripts/psk-code-review.sh" ]; then
  pass "F65: psk-code-review.sh present"
else
  fail "F65: psk-code-review.sh missing"
fi

if [ -x "$PROJ/agent/scripts/psk-code-review.sh" ]; then
  pass "F65: psk-code-review.sh executable"
else
  fail "F65: psk-code-review.sh not executable"
fi

if kit_grep "Code Review" -qi; then
  pass "F65: Code Review documented"
else
  fail "F65: Code Review not documented"
fi

if kit_grep "advisory" -qi || kit_grep "not blocking" -qi; then
  pass "F65: advisory-not-blocking principle documented"
else
  fail "F65: advisory principle missing"
fi
