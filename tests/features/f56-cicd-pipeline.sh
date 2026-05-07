#!/usr/bin/env bash
# F56 — CI/CD pipeline (kit + framework rules)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F56 — CI/CD pipeline"

if [ -f "$PROJ/.github/workflows/ci.yml" ]; then
  pass "F56: kit ci.yml present"
else
  fail "F56: kit ci.yml missing"
fi

if [ -f "$PROJ/.portable-spec-kit/skills/ci-setup.md" ]; then
  pass "F56: ci-setup skill present"
else
  fail "F56: ci-setup skill missing"
fi

if kit_grep "CI" -q; then
  pass "F56: CI documented"
else
  fail "F56: CI not documented"
fi

if kit_grep "GitHub Actions" -qi || kit_grep "ci.yml" -q; then
  pass "F56: GitHub Actions referenced"
else
  fail "F56: GitHub Actions not referenced"
fi
