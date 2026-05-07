#!/usr/bin/env bash
# F53 — test-release-check.sh — pre-release R→F→T validation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F53 — test-release-check.sh"

if [ -f "$PROJ/tests/test-release-check.sh" ]; then
  pass "F53: test-release-check.sh exists"
else
  fail "F53: test-release-check.sh missing"
fi

if [ -x "$PROJ/tests/test-release-check.sh" ]; then
  pass "F53: test-release-check.sh executable"
else
  fail "F53: test-release-check.sh not executable"
fi

# Auto-detects test runner
if [ -f "$PROJ/tests/test-release-check.sh" ] && \
   grep -qiE "(pytest|jest|vitest|cargo|go test|bash)" "$PROJ/tests/test-release-check.sh"; then
  pass "F53: auto-detect runner heuristics present"
else
  fail "F53: auto-detect runner missing"
fi

# G21 — check_test_relevance + IRRELEVANT_TESTS counter (Loop 2)
if [ -f "$PROJ/tests/test-release-check.sh" ] && \
   grep -qE "(check_test_relevance|IRRELEVANT_TESTS)" "$PROJ/tests/test-release-check.sh"; then
  pass "F53: G21 test-relevance check present"
else
  fail "F53: G21 test-relevance check missing"
fi
