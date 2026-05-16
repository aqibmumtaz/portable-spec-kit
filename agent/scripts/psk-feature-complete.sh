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

# §Workflow Fidelity (portable-spec-kit.md): this is an executable kit workflow.
# The agent executes its defined steps faithfully and completely — no phase
# compression, no inline substitution where a sub-agent is specified, no scope
# reduction under rate/context pressure. Pause-and-resume, never reduce-scope.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
WFS="$SCRIPT_DIR/psk-workflow-state.sh"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

FEATURE="${1:-}"
[ -z "$FEATURE" ] && { echo "Usage: bash psk-feature-complete.sh <FEATURE_ID>  (e.g. F12)"; exit 4; }
[[ "$FEATURE" =~ ^F[0-9]+$ ]] || { echo "Feature ID must match F<n>, got: $FEATURE"; exit 4; }

echo -e "${CYAN}═══ Feature Completion: $FEATURE ═══${NC}"

# §Workflow Fidelity B2 — init state machine + register gates per feature.
WF_NAME="psk-feature-complete-$FEATURE"
if [ -x "$WFS" ]; then
  bash "$WFS" init "$WF_NAME" "preflight,review,validation" >/dev/null 2>&1 || true
  bash "$WFS" register-gate "$WF_NAME" preflight "true" >/dev/null 2>&1 || true
  bash "$WFS" register-gate "$WF_NAME" review "bash $SCRIPT_DIR/psk-sync-check.sh --full && bash $PROJ_ROOT/tests/test-release-check.sh $PROJ_ROOT/agent/SPECS.md" >/dev/null 2>&1 || true
  bash "$WFS" register-gate "$WF_NAME" validation "bash $SCRIPT_DIR/psk-validate.sh feature-complete" >/dev/null 2>&1 || true
fi

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

if [ -x "$WFS" ]; then
  bash "$WFS" verify-gate "$WF_NAME" preflight >/dev/null 2>&1 || true
  bash "$WFS" mark-done "$WF_NAME" preflight >/dev/null 2>&1 || true
  bash "$WFS" mark-in-progress "$WF_NAME" review >/dev/null 2>&1 || true
fi

echo -e "\n${CYAN}═══ Pre-gate: mechanical code review ═══${NC}"
if [ -x "$SCRIPT_DIR/psk-code-review.sh" ]; then
  bash "$SCRIPT_DIR/psk-code-review.sh" 2>&1 | tail -20
else
  echo -e "  ${YELLOW}⚠ psk-code-review.sh not found — skipping${NC}"
fi

if [ -x "$WFS" ]; then
  bash "$WFS" verify-gate "$WF_NAME" review >/dev/null 2>&1 \
    && bash "$WFS" mark-done "$WF_NAME" review >/dev/null 2>&1 \
    && bash "$WFS" mark-in-progress "$WF_NAME" validation >/dev/null 2>&1 || true
fi

echo -e "\n${CYAN}═══ Final gate: dual validation ═══${NC}"
bash "$SCRIPT_DIR/psk-validate.sh" feature-complete
rc=$?
if [ "$rc" -eq 0 ] && [ -x "$WFS" ]; then
  bash "$WFS" verify-gate "$WF_NAME" validation >/dev/null 2>&1 \
    && bash "$WFS" mark-done "$WF_NAME" validation >/dev/null 2>&1 || true
fi
exit $rc
