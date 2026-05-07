#!/usr/bin/env bash
# F44 — Submission process documented in TASKS.md
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F44 — Submission process"

if [ -f "$PROJ/agent/TASKS.md" ]; then
  pass "F44: agent/TASKS.md present"
else
  fail "F44: agent/TASKS.md missing"
fi

# TASKS.md is non-trivial
if [ -f "$PROJ/agent/TASKS.md" ] && [ $(wc -l < "$PROJ/agent/TASKS.md") -gt 20 ]; then
  pass "F44: TASKS.md > 20 lines"
else
  fail "F44: TASKS.md too short"
fi
