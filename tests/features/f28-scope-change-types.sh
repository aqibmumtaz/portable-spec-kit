#!/usr/bin/env bash
# F28 — 4 scope change types (DROP, ADD, MODIFY, REPLACE)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/pipeline-rules.sh"

section "F28 — Scope change types"

assert_all_scope_change_types

if kit_grep "Scope Change" -q; then
  pass "F28: §Scope Change Recording present"
else
  fail "F28: §Scope Change Recording missing"
fi
