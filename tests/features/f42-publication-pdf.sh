#!/usr/bin/env bash
# F42 — Publication-ready PDF
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F42 — Publication-ready PDF"

pdf_count=$(ls "$PROJ/ard/"*.pdf 2>/dev/null | wc -l)
if [ "$pdf_count" -ge 1 ]; then
  pass "F42: $pdf_count PDF(s) in ard/"
else
  fail "F42: no PDFs in ard/"
fi

# Each PDF has reasonable size (>10KB indicates real publication PDF)
ok=0
for p in "$PROJ/ard/"*.pdf; do
  [ -f "$p" ] || continue
  size=$(wc -c < "$p")
  if [ "$size" -gt 10000 ]; then
    ok=$((ok+1))
  fi
done
if [ "$ok" -ge 1 ]; then
  pass "F42: $ok PDF(s) > 10KB (non-trivial)"
else
  fail "F42: no non-trivial PDFs"
fi
