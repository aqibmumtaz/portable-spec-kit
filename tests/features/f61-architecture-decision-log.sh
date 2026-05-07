#!/usr/bin/env bash
# F61 — Architecture Decision Log
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/pipeline-rules.sh"

section "F61 — Architecture Decision Log"

assert_adl_format_documented

if kit_grep "ADR" -q; then
  pass "F61: ADR format documented"
else
  fail "F61: ADR format missing"
fi

# Kit's own PLANS.md has ADL section
if grep -qiE "(Architecture Decision Log|ADL|ADR-[0-9]+)" "$PROJ/agent/PLANS.md" 2>/dev/null; then
  pass "F61: kit PLANS.md has ADL"
else
  fail "F61: kit PLANS.md missing ADL"
fi

if kit_grep "Plan Ref" -qi; then
  pass "F61: 'Plan Ref' column documented"
else
  fail "F61: 'Plan Ref' column missing"
fi
