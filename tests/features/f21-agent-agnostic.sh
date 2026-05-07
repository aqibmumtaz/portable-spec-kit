#!/usr/bin/env bash
# F21 — Fully agent-agnostic — no hardcoded tools
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F21 — Agent-agnostic"

# Multi-agent table — Claude/Cursor/Copilot/Windsurf/Cline all referenced
for agent in "Claude" "Cursor" "Copilot" "Windsurf" "Cline"; do
  if kit_grep "$agent" -q; then
    pass "F21: $agent referenced (multi-agent table)"
  else
    fail "F21: $agent not referenced"
  fi
done

if kit_grep "agent-agnostic" -qi || kit_grep "agnostic" -qi; then
  pass "F21: agnostic property declared"
else
  fail "F21: agnostic property missing"
fi
