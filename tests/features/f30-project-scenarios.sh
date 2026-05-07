#!/usr/bin/env bash
# F30 — Project scenarios table
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F30 — Project scenarios"

if kit_grep "Project Scenarios" -qi; then
  pass "F30: §Project Scenarios documented"
else
  fail "F30: §Project Scenarios missing"
fi

# Several scenario keywords
for scenario in "Brand new" "Existing" "Monorepo" "Cloned" "Partial"; do
  if kit_grep "$scenario" -qi; then
    pass "F30: scenario '$scenario' covered"
  else
    fail "F30: scenario '$scenario' missing"
  fi
done
