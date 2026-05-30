#!/bin/bash
# workflow-router: psk-feature-complete.sh — feature completion (R→F→T preflight + dual gate)
# workflow-decl: .portable-spec-kit/workflows/feature-complete/phases.yml
# =============================================================
# psk-feature-complete.sh — Feature Completion (dispatcher-driven, v0.6.62+)
# Workflow doc: docs/work-flows/11-spec-persistent-development.md
#
# Dual-mode router. This workflow is FEATURE-PARAMETERIZED — the feature id is
# threaded to the dispatcher's phases via a small state file (the dispatcher
# itself is feature-agnostic), so the preflight phase can re-read it:
#   • bash psk-feature-complete.sh F12     → store F12, delegate to psk-dispatch.sh
#   • bash psk-feature-complete.sh preflight → R→F→T preflight for the stored feature
#   • bash psk-feature-complete.sh <verb>  → forward dispatcher verbs (next/status/…)
#
# Phase sequence + gates live in the declaration; psk-dispatch.sh is the executor.
# Phase `review` runs psk-code-review.sh directly (external); `validation` is the dual gate.
#
# §Workflow Fidelity (portable-spec-kit.md): this is an executable kit workflow.
# It executes its declared phases faithfully and completely via psk-dispatch.sh —
# no phase compression, no inline substitution, no scope reduction under pressure.
# Pause-and-resume, never reduce-scope.
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
FEATURE_FILE="$PROJ_ROOT/agent/.workflow-state/feature-complete.feature"

run_preflight() {
  local FEATURE="$1"
  if [ -z "$FEATURE" ]; then
    echo -e "  ${RED}✗${NC} no feature id recorded — start with: bash agent/scripts/psk-feature-complete.sh F<n>"
    exit 1
  fi
  echo -e "${CYAN}═══ Feature Completion: $FEATURE — Preflight ═══${NC}"
  local fails=0
  # 1: feature in SPECS.md
  if ! grep -qE "^\| $FEATURE " "$PROJ_ROOT/agent/SPECS.md" 2>/dev/null; then
    echo -e "  ${RED}✗${NC} $FEATURE not found in agent/SPECS.md features table"; fails=$((fails+1))
  else echo -e "  ${GREEN}✓${NC} $FEATURE in SPECS.md"; fi
  # 2: design plan exists
  local flow_lc plan; flow_lc=$(echo "$FEATURE" | tr '[:upper:]' '[:lower:]')
  plan=$(ls "$PROJ_ROOT/agent/design/"${flow_lc}*.md 2>/dev/null | head -1)
  if [ -z "$plan" ] || [ ! -f "$plan" ]; then
    echo -e "  ${RED}✗${NC} No design plan at agent/design/${flow_lc}*.md (every feature needs one)"; fails=$((fails+1))
  else echo -e "  ${GREEN}✓${NC} Design plan: $(basename "$plan")"; fi
  # 3: SPECS Tests column populated
  local tests_col; tests_col=$(grep -E "^\| $FEATURE " "$PROJ_ROOT/agent/SPECS.md" 2>/dev/null | awk -F'|' '{print $NF}')
  if ! echo "$tests_col" | grep -qE "tests/|test_|_test\."; then
    echo -e "  ${RED}✗${NC} $FEATURE Tests column empty in SPECS.md (R→F→T rule)"; fails=$((fails+1))
  else echo -e "  ${GREEN}✓${NC} Tests column: $(echo "$tests_col" | tr -d ' ' | head -c 40)"; fi
  # 4: referenced test file has no TODO stubs
  local test_ref; test_ref=$(echo "$tests_col" | grep -oE "tests/[^ ,|]*" | head -1)
  if [ -n "$test_ref" ] && [ -f "$PROJ_ROOT/$test_ref" ]; then
    if grep -qE "^\s*(#|//|/\*)\s*TODO|test\.skip|xit\(|xtest\(|it\.skip|assert False|expect\(true\)\.toBe\(false\)|t\.Skip\(" "$PROJ_ROOT/$test_ref" 2>/dev/null; then
      echo -e "  ${RED}✗${NC} Test file $test_ref has incomplete stubs (TODO/skip/false)"; fails=$((fails+1))
    else echo -e "  ${GREEN}✓${NC} Test file $test_ref: no stubs"; fi
  fi
  # 5: matching task in TASKS.md (advisory)
  grep -qE "^- \[[ x]\].*$FEATURE" "$PROJ_ROOT/agent/TASKS.md" 2>/dev/null \
    || echo -e "  ${YELLOW}⚠${NC}  No matching task in agent/TASKS.md for $FEATURE (add one so work is tracked)"
  if [ "$fails" -gt 0 ]; then
    echo -e "\n${RED}Preflight FAILED ($fails issues) — fix before the final gate.${NC}"; exit 1
  fi
  echo -e "\n${CYAN}Next:${NC} bash agent/scripts/psk-feature-complete.sh next  (→ mechanical code review → dual validation)"
}

case "${1:-}" in
  preflight)
    run_preflight "$(cat "$FEATURE_FILE" 2>/dev/null | tr -d '[:space:]')"
    exit 0
    ;;
  F[0-9]*)
    [[ "$1" =~ ^F[0-9]+$ ]] || { echo "Feature ID must match F<n>, got: $1"; exit 4; }
    mkdir -p "$(dirname "$FEATURE_FILE")"; echo "$1" > "$FEATURE_FILE"
    echo -e "${CYAN}Feature completion for $1 — starting workflow.${NC}"
    exec bash "$SCRIPT_DIR/psk-dispatch.sh" feature-complete
    ;;
  ""|feature-complete)
    exec bash "$SCRIPT_DIR/psk-dispatch.sh" feature-complete
    ;;
  *)
    exec bash "$SCRIPT_DIR/psk-dispatch.sh" feature-complete "$@"
    ;;
esac
