#!/usr/bin/env bash
# F32 — Version bump BEFORE push rule
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F32 — Version bump BEFORE push"

if kit_grep "Version bump BEFORE push" -q || kit_grep "BEFORE push" -q; then
  pass "F32: 'BEFORE push' rule documented"
else
  fail "F32: 'BEFORE push' rule missing"
fi

if kit_grep "bump → commit → push" -q || kit_grep "bump.*commit.*push" -q; then
  pass "F32: bump→commit→push order documented"
else
  fail "F32: bump→commit→push order missing"
fi
