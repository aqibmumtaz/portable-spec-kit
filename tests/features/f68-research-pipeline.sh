#!/usr/bin/env bash
# F68 — Research Pipeline
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/agent-files.sh"

section "F68 — Research Pipeline"

assert_agent_file "RESEARCH.md"
assert_agent_file "DESIGN.md"

if kit_grep "RESEARCH.md" -q; then
  pass "F68: RESEARCH.md documented"
else
  fail "F68: RESEARCH.md not documented"
fi

if kit_grep "DESIGN.md" -q; then
  pass "F68: DESIGN.md documented"
else
  fail "F68: DESIGN.md not documented"
fi

if kit_grep "research" -qi; then
  pass "F68: research concept documented"
else
  fail "F68: research concept missing"
fi
