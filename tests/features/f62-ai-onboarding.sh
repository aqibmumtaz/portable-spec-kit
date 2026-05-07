#!/usr/bin/env bash
# F62 — AI-Powered Onboarding
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F62 — AI-Powered Onboarding"

if [ -f "$PROJ/.portable-spec-kit/skills/onboarding-tour.md" ]; then
  pass "F62: onboarding-tour skill present"
else
  fail "F62: onboarding-tour skill missing"
fi

if kit_grep "Onboarding" -qi; then
  pass "F62: Onboarding documented"
else
  fail "F62: Onboarding missing"
fi

if [ -f "$PROJ/CONTRIBUTING.md" ]; then
  pass "F62: CONTRIBUTING.md present"
else
  fail "F62: CONTRIBUTING.md missing"
fi

if kit_grep "commit agent" -qi || kit_grep "commit the agent" -qi; then
  pass "F62: 'commit agent/' rule documented"
else
  fail "F62: 'commit agent/' rule missing"
fi
