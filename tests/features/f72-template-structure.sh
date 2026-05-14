#!/usr/bin/env bash
# F72 — Template structure completeness: all agent file templates have required sections
# Verifies the externalized template files under .portable-spec-kit/templates/ carry the
# gold-standard v1 sections (REQS: Raw Input + Clarifying Assumptions, SPECS: R→F Mapping
# + Scope-Change Record, AGENT: Security + Definition of Done, etc.). Post-v0.6.54 the
# templates live as standalone files; skills/templates.md is a pointer index.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/repo-structure.sh"

section "F72 — Template structure completeness"

TEMPLATES_DIR="$PROJ/.portable-spec-kit/templates"
INDEX="$PROJ/.portable-spec-kit/skills/templates.md"

if [ ! -d "$TEMPLATES_DIR" ]; then
  fail "F72: .portable-spec-kit/templates/ directory not found — cannot validate template structure"
  return 0 2>/dev/null || exit 1
fi

if [ ! -f "$INDEX" ]; then
  fail "F72: skills/templates.md (pointer index) not found"
  return 0 2>/dev/null || exit 1
fi

# Helper: check that a pattern appears in a specific template file
check_in_file() {
  local label="$1" file="$2" pattern="$3"
  local path="$TEMPLATES_DIR/$file"
  if [ ! -f "$path" ]; then
    fail "F72: $label — template file $file missing"
    return
  fi
  if grep -q "$pattern" "$path" 2>/dev/null; then
    pass "F72: $label present in $file"
  else
    fail "F72: $label missing from $file"
  fi
}

# REQS.md template sections
check_in_file "REQS ## Raw Input"              "agent-reqs-template.md"          "## Raw Input"
check_in_file "REQS ## Clarifying Assumptions" "agent-reqs-template.md"          "## Clarifying Assumptions"
check_in_file "REQS R-Row Summary"             "agent-reqs-template.md"          "## R-Row Summary"
check_in_file "REQS per-req Statement field"   "agent-reqs-template.md"          "Statement:"

# SPECS.md template sections
check_in_file "SPECS ## R→F Mapping"           "agent-specs-template.md"         "## R.F Mapping\|## R→F Mapping"
check_in_file "SPECS ## Scope-Change Record"   "agent-specs-template.md"         "## Scope-Change Record"
check_in_file "SPECS tests/features path"      "agent-specs-template.md"         "tests/features/f"

# AGENT.md template sections
check_in_file "AGENT ## Security"              "agent-AGENT-template.md"         "## Security"
check_in_file "AGENT Definition of Done"       "agent-AGENT-template.md"         "## Definition of Done"

# TASKS.md template sections
check_in_file "TASKS QA Findings format"       "agent-tasks-template.md"         "QA Findings\|@reflex-dev"
check_in_file "TASKS Evidence line"            "agent-tasks-template.md"         "Evidence:"

# RESEARCH.md template sections
check_in_file "RESEARCH ## Open Research Questions" "agent-research-template.md" "## Open Research Questions"
check_in_file "RESEARCH grouped by topic"           "agent-research-template.md" "### Domain\|### Technical Stack"

# AGENT_CONTEXT.md template sections
check_in_file "AGENT_CONTEXT tests/features in File Structure" "agent-AGENT_CONTEXT-template.md" "tests/features"
check_in_file "AGENT_CONTEXT config.md in File Structure"      "agent-AGENT_CONTEXT-template.md" "config.md"

# Pointer-index sanity: skills/templates.md must reference the externalized location
if grep -q 'portable-spec-kit/templates/' "$INDEX" 2>/dev/null; then
  pass "F72: skills/templates.md references externalized templates/ directory"
else
  fail "F72: skills/templates.md missing pointer to .portable-spec-kit/templates/"
fi
