#!/usr/bin/env bash
# F5 — README template
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/repo-structure.sh"

section "F5 — README template"

assert_kit_root_file "README.md" "F5: kit README"

# README has minimum content
if [ $(wc -l < "$PROJ/README.md") -gt 50 ]; then
  pass "F5: README.md > 50 lines (non-trivial)"
else
  fail "F5: README.md too short"
fi

if grep -q "Portable Spec Kit" "$PROJ/README.md"; then
  pass "F5: README mentions product"
else
  fail "F5: README missing product mention"
fi

if grep -qiE "install" "$PROJ/README.md"; then
  pass "F5: README has install section"
else
  fail "F5: README missing install"
fi

if kit_grep "README template" -qi; then
  pass "F5: framework references README template"
else
  fail "F5: README template not referenced"
fi
