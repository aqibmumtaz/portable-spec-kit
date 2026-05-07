#!/usr/bin/env bash
# F16 — 16+ work flow documents in docs/work-flows/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/repo-structure.sh"

section "F16 — Work flow documents"

assert_kit_root_dir "docs/work-flows" "F16: docs/work-flows"

flow_count=$(ls "$PROJ/docs/work-flows/"*.md 2>/dev/null | wc -l)
if [ "$flow_count" -ge 16 ]; then
  pass "F16: $flow_count flow docs (>=16)"
else
  fail "F16: only $flow_count flow docs (need >=16)"
fi

# Specific anchor flows must exist
for f in 01-first-session-workspace 03-new-project-setup 13-release-workflow 17-reflex; do
  if ls "$PROJ/docs/work-flows/${f}"*.md >/dev/null 2>&1; then
    pass "F16: flow $f present"
  else
    fail "F16: flow $f missing"
  fi
done
