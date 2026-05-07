#!/usr/bin/env bash
# F27 — R→F traceability
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/pipeline-rules.sh"

section "F27 — R→F traceability"

assert_rf_traceability_documented

# Kit's own SPECS.md follows R→F format
if [ -f "$PROJ/agent/SPECS.md" ] && grep -qE "^\| F[0-9]+" "$PROJ/agent/SPECS.md"; then
  pass "F27: kit SPECS.md uses F{N} feature IDs"
else
  fail "F27: kit SPECS.md missing F{N} format"
fi

if [ -f "$PROJ/agent/SPECS.md" ] && grep -qE "R[0-9]" "$PROJ/agent/SPECS.md"; then
  pass "F27: kit SPECS.md references R{N} requirements"
else
  fail "F27: kit SPECS.md missing R{N} references"
fi

if [ -f "$PROJ/agent/REQS.md" ]; then
  pass "F27: kit REQS.md present"
else
  fail "F27: kit REQS.md missing"
fi
