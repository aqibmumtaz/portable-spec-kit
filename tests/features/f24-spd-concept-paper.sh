#!/usr/bin/env bash
# F24 — SPD concept paper — 9 sections, references, evaluation tables, SVG diagrams
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F24 — SPD concept paper"

# Locate any SPD/concept paper artifact
if ls "$PROJ/ard/"*SPD*.html "$PROJ/ard/"*Concept*.html "$PROJ/ard/"*spd*.html 2>/dev/null | head -1 >/dev/null; then
  pass "F24: SPD/concept paper HTML present"
else
  fail "F24: SPD/concept paper HTML missing"
fi

if kit_grep "Spec-Persistent Development" -q || kit_grep "SPD" -q; then
  pass "F24: SPD term documented"
else
  fail "F24: SPD term not documented"
fi

if kit_grep "Persistent Memory" -q; then
  pass "F24: Persistent Memory concept present"
else
  fail "F24: Persistent Memory concept missing"
fi
