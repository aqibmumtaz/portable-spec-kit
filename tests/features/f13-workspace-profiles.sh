#!/usr/bin/env bash
# F13 — Per-user workspace profiles committed to repo (team-ready)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F13 — Per-user workspace profiles"

if kit_grep "user-profile-{username}" -q || kit_grep "user-profile-" -q; then
  pass "F13: per-username naming documented"
else
  fail "F13: per-username naming missing"
fi

if kit_grep "team" -qi; then
  pass "F13: team-readiness mentioned"
else
  fail "F13: team-readiness not mentioned"
fi

if kit_grep "workspace" -qi; then
  pass "F13: workspace concept documented"
else
  fail "F13: workspace concept missing"
fi

if kit_grep "committed" -qi; then
  pass "F13: 'committed' to repo documented"
else
  fail "F13: 'committed' rule missing"
fi
