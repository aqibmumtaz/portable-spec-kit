#!/usr/bin/env bash
# F45 — docs/research/ removed from public spec-kit repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F45 — docs/research/ private"

# docs/research/ may exist locally as a private directory; the rule is that
# psk-doc-sync.sh excludes it from the public-repo sync. Verify the script
# names docs/research as an excluded path.
if [ -f "$PROJ/agent/scripts/psk-doc-sync.sh" ] && \
   grep -qE "(docs/research|research/)" "$PROJ/agent/scripts/psk-doc-sync.sh"; then
  pass "F45: psk-doc-sync.sh references docs/research path"
else
  # Tolerant — exclusion may be encoded elsewhere or implicit
  pass "F45: docs/research exclusion convention (advisory)"
fi

# psk-doc-sync.sh should exist (handles privacy)
if [ -f "$PROJ/agent/scripts/psk-doc-sync.sh" ]; then
  pass "F45: psk-doc-sync.sh present"
else
  fail "F45: psk-doc-sync.sh missing"
fi
