#!/usr/bin/env bash
# F52 — R→F→T traceability
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/pipeline-rules.sh"

section "F52 — R→F→T traceability"

assert_rft_traceability_documented
assert_specs_has_tests_column

if kit_grep "Tests column" -qi; then
  pass "F52: Tests column rule documented"
else
  fail "F52: Tests column rule missing"
fi

if kit_grep "before marking" -qi || kit_grep "Never mark a feature" -qi; then
  pass "F52: 'before marking [x]' enforcement documented"
else
  fail "F52: 'before marking [x]' enforcement missing"
fi
