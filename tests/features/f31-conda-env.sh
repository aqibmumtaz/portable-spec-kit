#!/usr/bin/env bash
# F31 — Conda env per project (now generalized to env-management)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F31 — Environment management"

if [ -f "$PROJ/.portable-spec-kit/skills/env-management.md" ]; then
  pass "F31: env-management skill present"
else
  fail "F31: env-management skill missing"
fi

if [ -f "$PROJ/agent/scripts/psk-env.sh" ]; then
  pass "F31: psk-env.sh present"
else
  fail "F31: psk-env.sh missing"
fi

if kit_grep "Environment Selection" -qi; then
  pass "F31: §Environment Selection documented"
else
  fail "F31: §Environment Selection missing"
fi

# Multi-stack support
for stack in conda venv python npm; do
  if kit_grep "$stack" -qi; then
    pass "F31: env stack '$stack' referenced"
  else
    fail "F31: env stack '$stack' missing"
  fi
done
