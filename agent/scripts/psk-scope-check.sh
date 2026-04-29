#!/bin/bash
# =============================================================
# psk-scope-check.sh — Scope Drift Detection (5 Dimensions)
#
# Reads SPECS.md + TASKS.md + PLANS.md + agent/design/ and
# detects drift across: feature mapping, requirement gaps,
# scope creep, architecture drift, plan staleness.
#
# Usage:
#   bash agent/scripts/psk-scope-check.sh              # full check
#   bash agent/scripts/psk-scope-check.sh --quick       # feature drift + plan staleness only
#   bash agent/scripts/psk-scope-check.sh --ci          # exit 1 on any drift
#
# Exit codes:
#   0 = no drift (score 0)
#   1 = drift detected (score > 0)
#   2 = configuration error (SPECS.md missing)
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
PROJ_ROOT="$(cd "$AGENT_DIR/.." 2>/dev/null && pwd)"

SPECS="$AGENT_DIR/SPECS.md"
TASKS="$AGENT_DIR/TASKS.md"
PLANS="$AGENT_DIR/PLANS.md"
DESIGN_DIR="$AGENT_DIR/design"

# --- Options ---
QUICK_MODE=false
CI_MODE=false
while [ $# -gt 0 ]; do
  case "$1" in
    --quick)    QUICK_MODE=true; shift ;;
    --ci)       CI_MODE=true; shift ;;
    --project)  PROJ_ROOT="$2"; AGENT_DIR="$PROJ_ROOT/agent"; SPECS="$AGENT_DIR/SPECS.md"; TASKS="$AGENT_DIR/TASKS.md"; PLANS="$AGENT_DIR/PLANS.md"; DESIGN_DIR="$AGENT_DIR/design"; shift 2 ;;
    *)          shift ;;
  esac
done

# --- Counters ---
DRIFT_SCORE=0
DIM_SCORES=""

# --- Color output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Validate required files ---
if [ ! -f "$SPECS" ]; then
  echo "Error: SPECS.md not found at $SPECS"
  exit 2
fi

if [ ! -f "$TASKS" ]; then
  echo "Error: TASKS.md not found at $TASKS"
  exit 2
fi

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  SCOPE CHECK — $(basename "$PROJ_ROOT")"
echo "══════════════════════════════════════════════════════════"

# =============================================================
# DIMENSION 1: Feature Drift (TASKS.md [x] → SPECS.md Fn)
# =============================================================
check_feature_drift() {
  echo ""
  echo "  1. FEATURE DRIFT (TASKS.md → SPECS.md)"
  echo "  ─────────────────────────────────────────────────"

  # Count completed tasks (excluding Backlog section)
  local completed_tasks=0
  local in_backlog=false
  local unmapped=0
  local unmapped_list=""

  # Build feature name lookup file (one-time, fast)
  local tmpnames
  tmpnames=$(mktemp)
  grep "^| F[0-9]" "$SPECS" 2>/dev/null | awk -F'|' '{gsub(/^ +| +$/,"",$3); print tolower($3)}' > "$tmpnames" 2>/dev/null || true
  trap "rm -f $tmpnames" RETURN

  # Process TASKS.md — simple line-by-line, minimal subshells
  while IFS= read -r line; do
    case "$line" in
      *[Bb]acklog*) in_backlog=true; continue ;;
      "## v"*) in_backlog=false ;;
    esac

    [ "$in_backlog" = true ] && continue
    case "$line" in
      "- [x]"*) ;;  # completed task
      *) continue ;;
    esac

    completed_tasks=$((completed_tasks + 1))

    # Match strategy (any of these = mapped):
    # 1. Task contains F{N} reference (F1, F63, **F65**)
    # 2. Task text matches a feature name from SPECS.md
    # 3. Task is under a version heading that has features in SPECS.md for that version

    # Fast match: F{N} reference
    case "$line" in
      *F[0-9]*|*"**F"[0-9]*) continue ;;
    esac

    # Fast match: ASSESS, Section, test suite, paper — these are meta-tasks, always mapped
    case "$line" in
      *ASSESS*|*Section*|*"test suite"*|*"Test suite"*|*"automated tests"*|*paper*|*Paper*|*"Full CI"*) continue ;;
    esac

    # Feature name match
    local task_lower
    task_lower=$(echo "$line" | tr '[:upper:]' '[:lower:]')
    local matched=false
    while IFS= read -r fname; do
      [ -z "$fname" ] && continue
      case "$task_lower" in
        *"$fname"*) matched=true; break ;;
      esac
    done < "$tmpnames"

    if [ "$matched" = false ]; then
      unmapped=$((unmapped + 1))
      local short_text="${line#- \[x\] }"
      unmapped_list="${unmapped_list}\n     - ${short_text:0:60}"
    fi
  done < "$TASKS"

  local feature_count
  feature_count=$(grep -c "^| F[0-9]" "$SPECS" 2>/dev/null || echo 0)

  printf "     Completed tasks:    %d\n" "$completed_tasks"
  printf "     Features defined:   %d\n" "$feature_count"
  printf "     Unmapped tasks:     %d\n" "$unmapped"

  if [ "$unmapped" -gt 0 ]; then
    echo -e "$unmapped_list"
  fi

  DRIFT_SCORE=$((DRIFT_SCORE + unmapped))
  DIM_SCORES="${DIM_SCORES}${unmapped} feature"
}

# =============================================================
# DIMENSION 2: Requirement Gaps (Rn → Fn)
# =============================================================
check_requirement_gaps() {
  echo ""
  echo "  2. REQUIREMENT GAPS (Rn → Fn)"
  echo "  ─────────────────────────────────────────────────"

  # Count requirements
  local req_count
  req_count=$(grep -c "^| R[0-9]" "$SPECS" 2>/dev/null || echo 0)

  if [ "$req_count" -eq 0 ]; then
    echo "     No requirements defined — R→F check skipped"
    return
  fi

  # For each requirement, check if at least one feature references it
  local gaps=0
  local gap_list=""
  while IFS= read -r line; do
    local req_id
    req_id=$(echo "$line" | awk -F'|' '{gsub(/ /,"",$2); print $2}')
    local req_text
    req_text=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')

    # Check if any feature row references this Rn
    if ! grep "^| F[0-9]" "$SPECS" | grep -q "$req_id"; then
      gaps=$((gaps + 1))
      gap_list="${gap_list}\n     - $req_id: $req_text"
    fi
  done < <(grep "^| R[0-9]" "$SPECS" 2>/dev/null)

  printf "     Requirements:       %d\n" "$req_count"
  printf "     With features:      %d\n" "$((req_count - gaps))"
  printf "     Gaps:               %d\n" "$gaps"

  if [ "$gaps" -gt 0 ]; then
    echo -e "$gap_list"
  else
    echo "     ✓ All requirements have features"
  fi

  DRIFT_SCORE=$((DRIFT_SCORE + gaps))
  DIM_SCORES="${DIM_SCORES} + ${gaps} req"
}

# =============================================================
# DIMENSION 3: Scope Creep (features without Rn reference)
# =============================================================
check_scope_creep() {
  echo ""
  echo "  3. SCOPE CREEP (features without requirements)"
  echo "  ─────────────────────────────────────────────────"

  local total_features=0
  local no_req=0
  local creep_list=""

  while IFS= read -r line; do
    total_features=$((total_features + 1))
    local fn
    fn=$(echo "$line" | awk -F'|' '{gsub(/ /,"",$2); print $2}')
    local fname
    fname=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')
    local req_col
    req_col=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')

    if [ -z "$req_col" ] || [ "$req_col" = "—" ] || [ "$req_col" = "-" ]; then
      no_req=$((no_req + 1))
      creep_list="${creep_list}\n     - $fn: $fname"
    fi
  done < <(grep "^| F[0-9]" "$SPECS" 2>/dev/null)

  printf "     Features with Rn:   %d\n" "$((total_features - no_req))"
  printf "     Without Rn:         %d\n" "$no_req"

  if [ "$no_req" -gt 0 ]; then
    echo -e "$creep_list"
  else
    echo "     ✓ All features trace to requirements"
  fi

  DRIFT_SCORE=$((DRIFT_SCORE + no_req))
  DIM_SCORES="${DIM_SCORES} + ${no_req} creep"
}

# =============================================================
# DIMENSION 4: Architecture Drift (PLANS.md → codebase)
# =============================================================
check_architecture_drift() {
  [ "$QUICK_MODE" = true ] && return

  echo ""
  echo "  4. ARCHITECTURE DRIFT (PLANS.md → codebase)"
  echo "  ─────────────────────────────────────────────────"

  if [ ! -f "$PLANS" ]; then
    echo "     No PLANS.md — architecture check skipped"
    return
  fi

  local drift=0
  local drift_list=""

  # Extract stack from PLANS.md (lines after "## Stack" until next ##)
  local stack_section
  stack_section=$(awk '/^## Stack/,/^## [^S]/' "$PLANS" 2>/dev/null | grep "^|" | grep -v "^|.*Layer\|^|.*---" || true)

  # Check for common tech in codebase not in PLANS.md
  if [ -f "$PROJ_ROOT/package.json" ]; then
    # Check for major deps not in Stack table
    for dep in redis mongodb mysql postgresql sqlite prisma; do
      if grep -qi "$dep" "$PROJ_ROOT/package.json" 2>/dev/null; then
        if ! echo "$stack_section" | grep -qi "$dep"; then
          drift=$((drift + 1))
          drift_list="${drift_list}\n     - $dep found in package.json — not in PLANS.md Stack"
        fi
      fi
    done
  fi

  if [ -f "$PROJ_ROOT/requirements.txt" ]; then
    for dep in redis pymongo mysql psycopg sqlalchemy celery; do
      if grep -qi "$dep" "$PROJ_ROOT/requirements.txt" 2>/dev/null; then
        if ! echo "$stack_section" | grep -qi "$dep"; then
          drift=$((drift + 1))
          drift_list="${drift_list}\n     - $dep found in requirements.txt — not in PLANS.md Stack"
        fi
      fi
    done
  fi

  if [ -f "$PROJ_ROOT/go.mod" ]; then
    for dep in redis mongo mysql postgres gorm; do
      if grep -qi "$dep" "$PROJ_ROOT/go.mod" 2>/dev/null; then
        if ! echo "$stack_section" | grep -qi "$dep"; then
          drift=$((drift + 1))
          drift_list="${drift_list}\n     - $dep found in go.mod — not in PLANS.md Stack"
        fi
      fi
    done
  fi

  printf "     Architecture drift:  %d item(s)\n" "$drift"
  if [ "$drift" -gt 0 ]; then
    echo -e "$drift_list"
  else
    echo "     ✓ Codebase matches PLANS.md Stack"
  fi

  DRIFT_SCORE=$((DRIFT_SCORE + drift))
  DIM_SCORES="${DIM_SCORES} + ${drift} arch"
}

# =============================================================
# DIMENSION 5: Plan Staleness (agent/design/ → SPECS.md)
# =============================================================
check_plan_staleness() {
  echo ""
  echo "  5. PLAN STALENESS (agent/design/ → SPECS.md)"
  echo "  ─────────────────────────────────────────────────"

  if [ ! -d "$DESIGN_DIR" ]; then
    echo "     No agent/design/ — plan staleness check skipped"
    return
  fi

  local plan_count=0
  local mismatches=0
  local mismatch_list=""

  for plan_file in "$DESIGN_DIR"/f*.md; do
    [ ! -f "$plan_file" ] && continue
    plan_count=$((plan_count + 1))

    local plan_name
    plan_name=$(basename "$plan_file" .md)
    local fn
    fn=$(echo "$plan_name" | grep -o 'f[0-9]*' | tr '[:lower:]' '[:upper:]')

    # Get plan state
    local plan_state
    plan_state=$(grep -i "^## Current State" "$plan_file" -A1 2>/dev/null | tail -1 | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//')

    # Get SPECS.md feature status
    local specs_status=""
    if grep -q "^| $fn " "$SPECS" 2>/dev/null; then
      if grep "^| $fn " "$SPECS" | grep -q '\[x\]'; then
        specs_status="done"
      else
        specs_status="pending"
      fi
    fi

    # Detect mismatches
    if echo "$plan_state" | grep -qi "done" && [ "$specs_status" = "pending" ]; then
      mismatches=$((mismatches + 1))
      mismatch_list="${mismatch_list}\n     - $plan_name: plan says 'Done' but SPECS.md $fn still [ ]"
    elif echo "$plan_state" | grep -qi "plan only" && [ "$specs_status" = "done" ]; then
      mismatches=$((mismatches + 1))
      mismatch_list="${mismatch_list}\n     - $plan_name: plan says 'Plan only' but SPECS.md $fn is [x]"
    fi
  done

  printf "     Design plans:        %d\n" "$plan_count"
  printf "     Status mismatches:   %d\n" "$mismatches"

  if [ "$mismatches" -gt 0 ]; then
    echo -e "$mismatch_list"
  else
    echo "     ✓ All plans aligned with SPECS.md"
  fi

  DRIFT_SCORE=$((DRIFT_SCORE + mismatches))
  DIM_SCORES="${DIM_SCORES} + ${mismatches} plan"
}

# =============================================================
# MAIN
# =============================================================
check_feature_drift
check_requirement_gaps
check_scope_creep
check_architecture_drift
check_plan_staleness

# Summary
echo ""
echo "  ────────────────────────────────────────────────────"
printf "  DRIFT SCORE: %d (%s)\n" "$DRIFT_SCORE" "$(echo "$DIM_SCORES" | sed 's/^ + //')"

if [ "$DRIFT_SCORE" -eq 0 ]; then
  echo -e "  ${GREEN}STATUS: ✅ ALIGNED — no scope drift detected${NC}"
  echo ""
  exit 0
else
  echo -e "  ${YELLOW}STATUS: ⚠  DRIFT DETECTED — review recommended${NC}"
  echo ""
  [ "$CI_MODE" = true ] && exit 1
  exit 1
fi
