#!/usr/bin/env bash
# F39 — Paper accuracy fixes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F39 — Paper accuracy"

# Paper artifacts present
if ls "$PROJ/ard/"*.html >/dev/null 2>&1; then
  pass "F39: ard/ HTML papers present"
else
  fail "F39: ard/ HTML papers missing"
fi

if ls "$PROJ/ard/"*.pdf >/dev/null 2>&1; then
  pass "F39: ard/ PDF papers present"
else
  fail "F39: ard/ PDF papers missing"
fi

# Pipeline reframing — REQS counts as part of pipeline now (6 stages)
for stage in REQS SPECS PLANS DESIGN TASKS RELEASES; do
  if kit_grep "$stage" -q; then
    pass "F39: pipeline stage $stage referenced"
  else
    fail "F39: pipeline stage $stage missing"
  fi
done
