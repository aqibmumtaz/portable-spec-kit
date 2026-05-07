#!/usr/bin/env bash
# F59 — Multi-Agent Task Tracking
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F59 — Multi-Agent Task Tracking"

if [ -f "$PROJ/.portable-spec-kit/skills/multi-agent.md" ]; then
  pass "F59: multi-agent skill present"
else
  fail "F59: multi-agent skill missing"
fi

if kit_grep "@username" -q || kit_grep "@user" -q; then
  pass "F59: @username syntax documented"
else
  fail "F59: @username syntax missing"
fi

if kit_grep "my tasks" -qi || kit_grep "assign" -qi || kit_grep "delegate" -qi; then
  pass "F59: ownership commands documented"
else
  fail "F59: ownership commands missing"
fi
