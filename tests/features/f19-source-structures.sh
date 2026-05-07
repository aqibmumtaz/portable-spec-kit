#!/usr/bin/env bash
# F19 — 8 source code structure templates
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F19 — Source code structure templates"

if [ -f "$PROJ/.portable-spec-kit/skills/source-structures.md" ]; then
  pass "F19: source-structures skill present"
else
  fail "F19: source-structures skill missing"
fi

# 8 stack types referenced
for stack in Web Python Mobile "Full Stack"; do
  if kit_grep "$stack" -q; then
    pass "F19: stack '$stack' documented"
  else
    fail "F19: stack '$stack' missing"
  fi
done
