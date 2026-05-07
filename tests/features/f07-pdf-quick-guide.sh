#!/usr/bin/env bash
# F7 — PDF Quick Guide
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/repo-structure.sh"

section "F7 — PDF Quick Guide"

if [ -f "$PROJ/ard/Portable_Spec_Kit_Guide.html" ]; then
  pass "F7: Guide HTML exists"
else
  fail "F7: Guide HTML missing"
fi

if [ -f "$PROJ/ard/Portable_Spec_Kit_Guide.pdf" ]; then
  pass "F7: Guide PDF exists"
else
  fail "F7: Guide PDF missing"
fi

# Guide HTML non-trivial
if [ -f "$PROJ/ard/Portable_Spec_Kit_Guide.html" ] && \
   [ $(wc -l < "$PROJ/ard/Portable_Spec_Kit_Guide.html") -gt 20 ]; then
  pass "F7: Guide HTML non-trivial"
else
  fail "F7: Guide HTML too short or missing"
fi

assert_kit_root_dir "ard" "F7: ard/ directory"
