#!/usr/bin/env bash
# F38 — Combined framework + benchmarking test suites
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F38 — Combined test suites"

if [ -f "$PROJ/tests/test-spec-kit.sh" ]; then
  pass "F38: test-spec-kit.sh (framework) present"
else
  fail "F38: test-spec-kit.sh missing"
fi

if [ -f "$PROJ/tests/test-spd-benchmarking.sh" ]; then
  pass "F38: test-spd-benchmarking.sh present"
else
  fail "F38: test-spd-benchmarking.sh missing"
fi

if [ -f "$PROJ/tests/test-release-check.sh" ]; then
  pass "F38: test-release-check.sh present"
else
  fail "F38: test-release-check.sh missing"
fi
