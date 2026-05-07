#!/usr/bin/env bash
# F58 — Progress Dashboard
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F58 — Progress Dashboard"

if [ -f "$PROJ/.portable-spec-kit/skills/dashboard.md" ]; then
  pass "F58: dashboard skill present"
else
  fail "F58: dashboard skill missing"
fi

if kit_grep "progress" -qi || kit_grep "dashboard" -qi || kit_grep "burndown" -qi; then
  pass "F58: dashboard triggers documented"
else
  fail "F58: dashboard triggers missing"
fi

# Dashboard sections (BY VERSION + OVERALL are mandatory; others advisory)
for sec in "BY VERSION" "OVERALL" "BY CONTRIBUTOR"; do
  if kit_grep "$sec" -q; then
    pass "F58: dashboard section '$sec' documented"
  else
    fail "F58: dashboard section '$sec' missing"
  fi
done

# Current/next sections — tolerant of phrasing variation
if kit_grep "Current" -qi || kit_grep "NEXT ACTIONS" -q || kit_grep "current tasks" -qi; then
  pass "F58: current/next sections documented"
else
  fail "F58: current/next sections missing"
fi
