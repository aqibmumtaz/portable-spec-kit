#!/usr/bin/env bash
# F12 — First-session profile setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F12 — First-session profile setup"

if kit_grep "First Session" -q; then
  pass "F12: first-session flow documented"
else
  fail "F12: first-session flow missing"
fi

if kit_grep "RECOMMENDED" -q; then
  pass "F12: RECOMMENDED marker documented"
else
  fail "F12: RECOMMENDED marker missing"
fi

if kit_grep "CURRENT" -q; then
  pass "F12: CURRENT marker documented"
else
  fail "F12: CURRENT marker missing"
fi

if [ -f "$PROJ/.portable-spec-kit/skills/profile-setup.md" ]; then
  pass "F12: profile-setup skill present"
else
  fail "F12: profile-setup skill missing"
fi
