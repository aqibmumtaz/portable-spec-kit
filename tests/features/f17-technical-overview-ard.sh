#!/usr/bin/env bash
# F17 — Technical Overview ARD (HTML + PDF)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/repo-structure.sh"

section "F17 — Technical Overview ARD"

assert_kit_root_dir "ard" "F17: ard/"

# Find any technical overview HTML
if ls "$PROJ/ard/"*echnical*.html >/dev/null 2>&1 || ls "$PROJ/ard/"*Overview*.html >/dev/null 2>&1; then
  pass "F17: Technical Overview HTML found"
else
  fail "F17: Technical Overview HTML missing"
fi

if ls "$PROJ/ard/"*echnical*.pdf >/dev/null 2>&1 || ls "$PROJ/ard/"*Overview*.pdf >/dev/null 2>&1; then
  pass "F17: Technical Overview PDF found"
else
  fail "F17: Technical Overview PDF missing"
fi

# Total ARD HTMLs >= 2 (Guide + Technical Overview at minimum)
ard_html=$(ls "$PROJ/ard/"*.html 2>/dev/null | wc -l)
if [ "$ard_html" -ge 2 ]; then
  pass "F17: $ard_html ARD HTML files"
else
  fail "F17: too few ARD HTMLs ($ard_html)"
fi
