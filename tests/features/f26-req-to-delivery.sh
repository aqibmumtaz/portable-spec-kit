#!/usr/bin/env bash
# F26 — Requirements-to-delivery work flow
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/pipeline-rules.sh"

section "F26 — Requirements-to-delivery work flow"

assert_rf_traceability_documented

if kit_grep "REQS.md" -q; then
  pass "F26: REQS.md upstream stage documented"
else
  fail "F26: REQS.md not documented"
fi

# 6-pipeline-stage flow
for stage in REQS SPECS PLANS DESIGN TASKS RELEASES; do
  if kit_grep "$stage" -q; then
    pass "F26: pipeline stage $stage documented"
  else
    fail "F26: pipeline stage $stage missing"
  fi
done
