#!/bin/bash
# =============================================================
# psk-feature-complete.sh — Feature Completion Orchestrator
# Workflow doc: docs/work-flows/11-spec-persistent-development.md
#
# Thin wrapper over psk-validate.sh feature-complete with preflight
# checks that catch common feature-completion mistakes earlier and
# with more specific feedback than the dual gate alone.
#
# Usage: bash agent/scripts/psk-feature-complete.sh <FEATURE_ID>
#        e.g.  bash agent/scripts/psk-feature-complete.sh F12
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

FEATURE="${1:-}"
[ -z "$FEATURE" ] && { echo "Usage: bash psk-feature-complete.sh <FEATURE_ID>  (e.g. F12)"; exit 4; }
[[ "$FEATURE" =~ ^F[0-9]+$ ]] || { echo "Feature ID must match F<n>, got: $FEATURE"; exit 4; }

echo -e "${CYAN}═══ Feature Completion: $FEATURE ═══${NC}"

fails=0

# Preflight 1: feature exists in SPECS.md
if ! grep -qE "^\| $FEATURE " "$PROJ_ROOT/agent/SPECS.md" 2>/dev/null; then
  echo -e "  ${RED}✗${NC} $FEATURE not found in agent/SPECS.md features table"
  fails=$((fails + 1))
else
  echo -e "  ${GREEN}✓${NC} $FEATURE in SPECS.md"
fi

# Preflight 2: design plan exists
flow_lc=$(echo "$FEATURE" | tr '[:upper:]' '[:lower:]')
plan=$(ls "$PROJ_ROOT/agent/design/"${flow_lc}*.md 2>/dev/null | head -1)
if [ -z "$plan" ] || [ ! -f "$plan" ]; then
  echo -e "  ${RED}✗${NC} No design plan at agent/design/${flow_lc}*.md"
  echo -e "    ${YELLOW}Create one — every feature must have a design plan${NC}"
  fails=$((fails + 1))
else
  echo -e "  ${GREEN}✓${NC} Design plan: $(basename "$plan")"
fi

# Preflight 3: SPECS.md Tests column populated
tests_col=$(grep -E "^\| $FEATURE " "$PROJ_ROOT/agent/SPECS.md" 2>/dev/null | awk -F'|' '{print $NF}')
if ! echo "$tests_col" | grep -qE "tests/|test_|_test\."; then
  echo -e "  ${RED}✗${NC} $FEATURE Tests column empty in SPECS.md"
  echo -e "    ${YELLOW}Add test file ref before marking done (R→F→T rule)${NC}"
  fails=$((fails + 1))
else
  echo -e "  ${GREEN}✓${NC} Tests column: $(echo "$tests_col" | tr -d ' ' | head -c 40)"
fi

# Preflight 4: referenced test file has no TODO stubs
# Extract first test file ref from Tests column
test_ref=$(echo "$tests_col" | grep -oE "tests/[^ ,|]*" | head -1)
if [ -n "$test_ref" ] && [ -f "$PROJ_ROOT/$test_ref" ]; then
  if grep -qE "^\s*(#|//|/\*)\s*TODO|test\.skip|xit\(|xtest\(|it\.skip|assert False|expect\(true\)\.toBe\(false\)|t\.Skip\(" "$PROJ_ROOT/$test_ref" 2>/dev/null; then
    echo -e "  ${RED}✗${NC} Test file $test_ref has incomplete stubs (TODO/skip/false)"
    fails=$((fails + 1))
  else
    echo -e "  ${GREEN}✓${NC} Test file $test_ref: no stubs"
  fi
fi

# Preflight 5: corresponding task in TASKS.md
if ! grep -qE "^- \[[ x]\].*$FEATURE" "$PROJ_ROOT/agent/TASKS.md" 2>/dev/null; then
  echo -e "  ${YELLOW}⚠${NC}  No matching task in agent/TASKS.md for $FEATURE"
  echo -e "    ${YELLOW}Add one so work is tracked${NC}"
fi

if [ "$fails" -gt 0 ]; then
  echo -e "\n${RED}Preflight FAILED ($fails issues) — fix before running final gate.${NC}"
  exit 1
fi

echo -e "\n${CYAN}═══ Pre-gate: mechanical code review ═══${NC}"
if [ -x "$SCRIPT_DIR/psk-code-review.sh" ]; then
  bash "$SCRIPT_DIR/psk-code-review.sh" 2>&1 | tail -20
else
  echo -e "  ${YELLOW}⚠ psk-code-review.sh not found — skipping${NC}"
fi

echo -e "\n${CYAN}═══ Final gate: dual validation ═══${NC}"
bash "$SCRIPT_DIR/psk-validate.sh" feature-complete
exit $?
