#!/usr/bin/env bash
# F66 — Scope Drift Detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F66 — Scope Drift Detection"

if [ -f "$PROJ/agent/scripts/psk-scope-check.sh" ]; then
  pass "F66: psk-scope-check.sh present"
else
  fail "F66: psk-scope-check.sh missing"
fi

if kit_grep "Scope Drift" -q; then
  pass "F66: Scope Drift section documented"
else
  fail "F66: Scope Drift section missing"
fi

# 5 dimensions
for dim in "Feature drift" "Requirement gaps" "Scope creep" "Architecture drift" "Plan staleness"; do
  if kit_grep "$dim" -q; then
    pass "F66: dimension '$dim' documented"
  else
    fail "F66: dimension '$dim' missing"
  fi
done
