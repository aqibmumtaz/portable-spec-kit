#!/usr/bin/env bash
# F63 — Jira Integration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F63 — Jira Integration"

if [ -f "$PROJ/.portable-spec-kit/skills/jira-integration.md" ]; then
  pass "F63: jira-integration skill present"
else
  fail "F63: jira-integration skill missing"
fi

if [ -f "$PROJ/agent/scripts/psk-jira-sync.sh" ]; then
  pass "F63: psk-jira-sync.sh present"
else
  fail "F63: psk-jira-sync.sh missing"
fi

if [ -f "$PROJ/agent/scripts/psk-tracker.sh" ]; then
  pass "F63: psk-tracker.sh present"
else
  fail "F63: psk-tracker.sh missing"
fi

if kit_grep "Jira" -q; then
  pass "F63: Jira documented in framework"
else
  fail "F63: Jira not documented"
fi
