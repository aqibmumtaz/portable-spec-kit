#!/usr/bin/env bash
# F49 — Scope change recording — 4 types + R→F traceability
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/pipeline-rules.sh"

section "F49 — Scope change recording"

assert_all_scope_change_types
assert_rf_traceability_documented

if kit_grep "Format:" -qi || kit_grep "change type" -qi; then
  pass "F49: scope-change format documented"
else
  fail "F49: scope-change format missing"
fi
