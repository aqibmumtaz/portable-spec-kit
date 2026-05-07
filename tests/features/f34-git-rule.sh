#!/usr/bin/env bash
# F34 — Git rule — check .git/ before committing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F34 — Git rule (.git check)"

if kit_grep "Git rule" -qi || kit_grep ".git/" -q; then
  pass "F34: git-rule documented"
else
  fail "F34: git-rule missing"
fi

if kit_grep "before committing" -qi || kit_grep "Before Committing" -qi; then
  pass "F34: pre-commit checklist documented"
else
  fail "F34: pre-commit checklist missing"
fi
