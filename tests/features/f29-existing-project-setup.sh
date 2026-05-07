#!/usr/bin/env bash
# F29 — Existing project setup — guide don't force
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F29 — Existing project setup"

if kit_grep "Existing Project" -qi; then
  pass "F29: Existing Project section present"
else
  fail "F29: Existing Project section missing"
fi

if kit_grep "guide don't force" -qi || kit_grep "guide, don't force" -qi || kit_grep "Guide don't force" -q; then
  pass "F29: 'guide don't force' principle documented"
else
  fail "F29: 'guide don't force' principle missing"
fi

if [ -f "$PROJ/agent/scripts/psk-existing-setup.sh" ]; then
  pass "F29: psk-existing-setup.sh present"
else
  fail "F29: psk-existing-setup.sh missing"
fi
