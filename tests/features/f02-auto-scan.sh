#!/usr/bin/env bash
# F2 — Auto-scan and agent file creation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/agent-files.sh"

section "F2 — Auto-scan and agent file creation"

if kit_grep "Auto-Scan" -qi; then
  pass "F2: framework documents auto-scan"
else
  fail "F2: framework missing auto-scan documentation"
fi

if kit_grep "WORKSPACE_CONTEXT.md" -q; then
  pass "F2: WORKSPACE_CONTEXT.md referenced in framework"
else
  fail "F2: WORKSPACE_CONTEXT.md not referenced"
fi

if kit_grep "First Session" -q; then
  pass "F2: framework documents first-session flow"
else
  fail "F2: first-session flow missing"
fi

# Project-setup skill must exist as documented entry point
if [ -f "$PROJ/.portable-spec-kit/skills/project-setup.md" ]; then
  pass "F2: project-setup skill file present"
else
  fail "F2: project-setup skill file missing"
fi
