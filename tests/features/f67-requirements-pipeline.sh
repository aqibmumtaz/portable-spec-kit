#!/usr/bin/env bash
# F67 — Requirements Pipeline
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/agent-files.sh"

section "F67 — Requirements Pipeline"

assert_agent_file "REQS.md"

if kit_grep "REQS.md" -q; then
  pass "F67: REQS.md documented in framework"
else
  fail "F67: REQS.md not documented"
fi

# REQS.md uses R{N} format
if [ -f "$PROJ/agent/REQS.md" ] && grep -qE "R[0-9]+" "$PROJ/agent/REQS.md"; then
  pass "F67: kit REQS.md uses R{N} format"
else
  fail "F67: kit REQS.md missing R{N} format"
fi

# raw input dir
if kit_grep "reqs/" -q || kit_grep "raw input" -qi; then
  pass "F67: reqs/ raw-input concept documented"
else
  fail "F67: reqs/ raw-input concept missing"
fi
