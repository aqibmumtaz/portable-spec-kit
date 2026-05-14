#!/usr/bin/env bash
# F16 — 22 work flow documents in docs/work-flows/ (per SPECS.md F16 acceptance criteria)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/repo-structure.sh"

section "F16 — Work flow documents"

assert_kit_root_dir "docs/work-flows" "F16: docs/work-flows"

# Read expected count from SPECS.md F16 acceptance criteria so this test
# stays in sync with the spec automatically (cross-reference instead of hardcode).
SPECS_FILE="$PROJ/agent/SPECS.md"
expected_count=22
if [ -f "$SPECS_FILE" ]; then
  # Parse "22 work flow documents" or "N work flow documents" from F16 row
  parsed=$(grep '| F16 |' "$SPECS_FILE" | grep -oE '[0-9]+ work flow' | grep -oE '^[0-9]+')
  [ -n "$parsed" ] && expected_count="$parsed"
fi

# Exclude 00-template.md — it is the authoring template, not a workflow doc.
# SPECS.md F16 counts numbered workflow docs (01-NN) only.
flow_count=$(ls "$PROJ/docs/work-flows/"*.md 2>/dev/null | grep -cv '00-template' || echo 0)
if [ "$flow_count" -eq "$expected_count" ]; then
  pass "F16: $flow_count flow docs (==$expected_count per SPECS.md F16)"
else
  fail "F16: $flow_count flow docs (SPECS.md F16 requires exactly $expected_count — catches both under- and over-count)"
fi

# Specific anchor flows must exist
for f in 01-first-session-workspace 03-new-project-setup 13-release-workflow 17-reflex; do
  if ls "$PROJ/docs/work-flows/${f}"*.md >/dev/null 2>&1; then
    pass "F16: flow $f present"
  else
    fail "F16: flow $f missing"
  fi
done
