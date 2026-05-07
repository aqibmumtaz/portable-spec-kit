#!/usr/bin/env bash
# F64 — Feature Design Pipeline
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/agent-files.sh"

section "F64 — Feature Design Pipeline"

if [ -d "$PROJ/agent/design" ]; then
  pass "F64: agent/design/ dir present"
else
  fail "F64: agent/design/ dir missing"
fi

if kit_grep "agent/design" -q; then
  pass "F64: agent/design referenced in framework"
else
  fail "F64: agent/design not referenced"
fi

if kit_grep "f{N}" -q || kit_grep "f{n}" -q; then
  pass "F64: f{N} naming convention documented"
else
  fail "F64: f{N} naming convention missing"
fi

if kit_grep "feature plan" -qi || kit_grep "design plan" -qi; then
  pass "F64: feature/design plan concept documented"
else
  fail "F64: feature/design plan concept missing"
fi

if kit_grep "Plan Ref" -q; then
  pass "F64: ADL Plan Ref column documented"
else
  fail "F64: ADL Plan Ref column missing"
fi
