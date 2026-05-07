#!/usr/bin/env bash
# F55 — Release command aliases (update/refresh release)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F55 — Release command aliases"

if kit_grep "prepare release" -q; then
  pass "F55: 'prepare release' documented"
else
  fail "F55: 'prepare release' missing"
fi

if kit_grep "update release" -q; then
  pass "F55: 'update release' alias documented"
else
  fail "F55: 'update release' alias missing"
fi

if kit_grep "refresh release" -q; then
  pass "F55: 'refresh release' (no version bump) documented"
else
  fail "F55: 'refresh release' missing"
fi

if [ -f "$PROJ/agent/scripts/psk-release.sh" ]; then
  pass "F55: psk-release.sh present"
else
  fail "F55: psk-release.sh missing"
fi
