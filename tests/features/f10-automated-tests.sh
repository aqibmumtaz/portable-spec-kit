#!/usr/bin/env bash
# F10 — 3070 automated tests (2925 framework + 145 benchmarking — kit baseline)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F10 — Automated test suite"

if [ -f "$PROJ/tests/test-spec-kit.sh" ]; then
  pass "F10: test-spec-kit.sh exists"
else
  fail "F10: test-spec-kit.sh missing"
fi

if grep -q "SECTIONS=(" "$PROJ/tests/test-spec-kit.sh"; then
  pass "F10: orchestrator declares SECTIONS array"
else
  fail "F10: SECTIONS array missing"
fi

if [ -d "$PROJ/tests/sections" ]; then
  pass "F10: sections/ dir present"
else
  fail "F10: sections/ dir missing"
fi

# Count section files
sec_count=$(ls "$PROJ/tests/sections/"*.sh 2>/dev/null | wc -l)
if [ "$sec_count" -ge 4 ]; then
  pass "F10: $sec_count section files (>=4)"
else
  fail "F10: too few section files ($sec_count)"
fi

# QA-D12-P5-001: cross-surface test-count consistency. The previous version only
# checked structure (script exists, dir present, >=4 sections) — a regression that
# dropped the published count would have passed. Assert the documented total
# (2925 framework + 145 benchmarking = 3070) is consistent across the public
# surfaces. Derive the count from the README badge rather than freezing a literal,
# then require portable-spec-kit.md to agree — so the test stays correct across
# future count changes (it checks consistency, not a frozen number).
readme_count=$(grep -oE 'tests-[0-9]+%20passing' "$PROJ/README.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)
if [ -n "$readme_count" ]; then
  pass "F10: README test-count badge present ($readme_count)"
  if grep -q "$readme_count" "$PROJ/portable-spec-kit.md" 2>/dev/null; then
    pass "F10: test count $readme_count consistent across README + portable-spec-kit.md"
  else
    fail "F10: README badge count ($readme_count) not found in portable-spec-kit.md — count drift"
  fi
else
  fail "F10: README test-count badge missing or unparseable"
fi
