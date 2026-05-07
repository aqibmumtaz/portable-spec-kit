#!/usr/bin/env bash
# F60 — Persistent Memory Architecture
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F60 — Persistent Memory Architecture"

if kit_grep "Persistent Memory" -q; then
  pass "F60: Persistent Memory term documented"
else
  fail "F60: Persistent Memory term missing"
fi

# 5 properties
for prop in Durable Shared Portable Team Auditable; do
  if kit_grep "$prop" -q; then
    pass "F60: property '$prop' documented"
  else
    fail "F60: property '$prop' missing"
  fi
done

if kit_grep "agent-agnostic" -qi || kit_grep "agent-agnostic by design" -qi; then
  pass "F60: agent-agnostic property documented"
else
  fail "F60: agent-agnostic property missing"
fi
