#!/usr/bin/env bash
# F25 — SPD benchmarking test suite
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F25 — SPD benchmarking"

if [ -f "$PROJ/tests/test-spd-benchmarking.sh" ]; then
  pass "F25: test-spd-benchmarking.sh exists"
else
  fail "F25: test-spd-benchmarking.sh missing"
fi

if [ -x "$PROJ/tests/test-spd-benchmarking.sh" ] || [ -r "$PROJ/tests/test-spd-benchmarking.sh" ]; then
  pass "F25: test-spd-benchmarking.sh readable"
else
  fail "F25: test-spd-benchmarking.sh not readable"
fi

# Benchmarking suite mentions key methodology terms
if [ -f "$PROJ/tests/test-spd-benchmarking.sh" ]; then
  if grep -qiE "(SPD|spec-persistent|methodolog)" "$PROJ/tests/test-spd-benchmarking.sh"; then
    pass "F25: benchmarking references SPD methodology"
  else
    fail "F25: benchmarking missing SPD reference"
  fi
fi
