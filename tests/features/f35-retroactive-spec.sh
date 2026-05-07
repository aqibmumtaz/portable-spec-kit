#!/usr/bin/env bash
# F35 — Retroactive spec filling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F35 — Retroactive spec filling"

if kit_grep "retroactiv" -qi || kit_grep "Retroactive" -q; then
  pass "F35: retroactive concept documented"
else
  fail "F35: retroactive concept missing"
fi

if kit_grep "Staleness" -qi || kit_grep "stale" -q; then
  pass "F35: staleness check documented"
else
  fail "F35: staleness check missing"
fi

if kit_grep "Fill gaps proactively" -qi || kit_grep "fill gaps" -qi; then
  pass "F35: 'fill gaps' rule documented"
else
  fail "F35: 'fill gaps' rule missing"
fi
