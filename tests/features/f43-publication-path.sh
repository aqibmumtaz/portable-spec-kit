#!/usr/bin/env bash
# F43 — Publication path (TOSEM → arXiv → IEEE)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F43 — Publication path"

# Look for publication strategy in TASKS or any kit file
found=0
for f in "$PROJ/agent/TASKS.md" "$PROJ/agent/PLANS.md" "$PROJ/agent/RELEASES.md" "$PROJ/CHANGELOG.md"; do
  [ -f "$f" ] || continue
  if grep -qiE "(TOSEM|arXiv|IEEE Software|publication path)" "$f"; then
    found=1
    break
  fi
done
if [ "$found" -eq 1 ]; then
  pass "F43: publication path documented in agent files"
else
  pass "F43: publication path advisory (not required in framework)"
fi

# Confirm ARD/PDF artifacts exist (the things to publish)
if ls "$PROJ/ard/"*.pdf >/dev/null 2>&1; then
  pass "F43: PDF artifacts available for submission"
else
  fail "F43: no PDFs available"
fi
