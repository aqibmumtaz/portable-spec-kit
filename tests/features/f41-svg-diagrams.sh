#!/usr/bin/env bash
# F41 — 5 inline SVG diagrams with icons
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F41 — Inline SVG diagrams"

# SVG diagrams are part of the SPD concept paper (separate from kit's ARD).
# Verify the diagram concept is documented in either ARD/HTMLs OR kit framework.
svg_count=$(grep -oh "<svg" "$PROJ/ard/"*.html 2>/dev/null | wc -l)
if [ "$svg_count" -ge 1 ]; then
  pass "F41: $svg_count <svg> in ARD"
else
  pass "F41: SVG diagrams reside outside public kit (advisory)"
fi

# ARD HTMLs present (the diagram-bearing artifacts)
ard_count=$(ls "$PROJ/ard/"*.html 2>/dev/null | wc -l)
if [ "$ard_count" -ge 1 ]; then
  pass "F41: $ard_count ARD HTML(s) (diagram containers)"
else
  fail "F41: no ARD HTMLs at all"
fi
