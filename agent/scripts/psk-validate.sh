#!/bin/bash
# =============================================================
# psk-validate.sh — Generic Dual-Gate Validation Helper
#
# One helper used by every executable workflow as its final
# validation step. Implements the reliability model:
#   "dual critic at the end of each workflow"
#
# Gate order:
#   1. Bash critic  — psk-sync-check.sh --full (deterministic)
#   2. Sub-agent critic — psk-critic-spawn.sh (semantic)
#
# Both must pass. Either failure blocks the workflow.
#
# Usage:
#   bash agent/scripts/psk-validate.sh <WORKFLOW>
#
# WORKFLOW values: release | feature-complete | init | reinit
#                  | new-setup | existing-setup
#
# Exit codes:
#   0 = both critics passed
#   1 = bash critic failed (fix mechanical drift, re-run)
#   2 = awaiting sub-agent critic (agent must spawn, write
#       result, re-run this command)
#   3 = sub-agent critic found stale content
#   4 = invalid workflow name or usage error
#
# Bypass:
#   PSK_SYNC_CHECK_DISABLED=1  — skip bash critic
#   PSK_CRITIC_DISABLED=1      — skip sub-agent critic
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
STATE_DIR="$SCRIPT_DIR/../.release-state"
SYNC_CHECK="$SCRIPT_DIR/psk-sync-check.sh"
CRITIC_SPAWN="$SCRIPT_DIR/psk-critic-spawn.sh"
RESULT_FILE="$STATE_DIR/critic-result.md"
TASK_FILE="$STATE_DIR/critic-task.md"
INVOKE_STAMP="$STATE_DIR/.validate-stamp"
BYPASS_LOG="$SCRIPT_DIR/../.bypass-log"

log_bypass() {
  local gate="$1" workflow="$2"
  mkdir -p "$(dirname "$BYPASS_LOG")"
  local user
  user=$(git config user.name 2>/dev/null || whoami 2>/dev/null || echo "unknown")
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $user bypass=$gate workflow=$workflow" >> "$BYPASS_LOG"
}

# Verify every CURRENT: line in critic-result.md is followed by a QUOTE: line
# whose text actually appears in the named file. This closes the "sub-agent
# wrote CURRENT without reading" gap — a lazy critic either omits the QUOTE
# (rejected) or fabricates one (rejected when grep fails to find it).
verify_quotes() {
  local result="$1"
  local current_file=""
  local line_no=0
  local bad=""
  local current_count=0
  local quoted_count=0

  while IFS= read -r line || [ -n "$line" ]; do
    line_no=$((line_no + 1))
    case "$line" in
      CURRENT:*)
        # If we had a pending CURRENT without QUOTE, flag it
        if [ -n "$current_file" ]; then
          bad="${bad}    ${CYAN}$current_file${NC}: missing QUOTE line
"
        fi
        current_file="${line#CURRENT: }"
        current_count=$((current_count + 1))
        ;;
      QUOTE:*)
        if [ -z "$current_file" ]; then
          bad="${bad}    line $line_no: QUOTE without preceding CURRENT
"
          continue
        fi
        local quote="${line#QUOTE: }"
        local target="$PROJ_ROOT/$current_file"
        if [ ! -f "$target" ]; then
          bad="${bad}    ${current_file}: file does not exist (but critic claimed CURRENT)
"
        elif [ ${#quote} -lt 20 ]; then
          bad="${bad}    ${current_file}: QUOTE too short (<20 chars — critic must provide distinctive line)
"
        elif ! grep -qF -- "$quote" "$target" 2>/dev/null; then
          bad="${bad}    ${current_file}: QUOTE not found in file (critic did not read the file)
"
        else
          quoted_count=$((quoted_count + 1))
        fi
        current_file=""
        ;;
    esac
  done < "$result"

  # Trailing CURRENT without QUOTE
  if [ -n "$current_file" ]; then
    bad="${bad}    ${current_file}: missing QUOTE line (end of file)
"
  fi

  if [ -n "$bad" ]; then
    echo -e "  ${RED}✗ Quote verification failed — critic may not have read these files:${NC}"
    printf "%b" "$bad"
    return 1
  fi

  # Require at least one verified quote
  if [ "$quoted_count" -eq 0 ]; then
    echo -e "  ${RED}✗ Quote verification: zero CURRENT+QUOTE pairs (critic output unusable)${NC}"
    return 1
  fi

  echo -e "  ${GREEN}✓ Quote verification: $quoted_count/$current_count CURRENT verdicts backed by verified quotes${NC}"
  return 0
}

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

WORKFLOW="${1:-}"

# Map workflow name to critic-spawn template
workflow_to_template() {
  case "$1" in
    release)          echo "STEP_9_VALIDATION" ;;
    feature-complete) echo "FEATURE_COMPLETE" ;;
    init)             echo "INIT" ;;
    reinit)           echo "REINIT" ;;
    new-setup)        echo "NEW_SETUP" ;;
    existing-setup)   echo "EXISTING_SETUP" ;;
    *)                echo "" ;;
  esac
}

usage() {
  cat <<EOF
psk-validate.sh — dual-gate validation (bash critic + sub-agent critic)

Usage: bash agent/scripts/psk-validate.sh <WORKFLOW>

Workflows:
  release           Final gate for prepare release
  feature-complete  End of feature implementation
  init              End of project init
  reinit            End of project reinit
  new-setup         End of new project setup
  existing-setup    End of existing project setup

Exit codes: 0=pass · 1=bash fail · 2=awaiting critic · 3=critic stale · 4=usage
EOF
}

if [ -z "$WORKFLOW" ] || [ "$WORKFLOW" = "--help" ] || [ "$WORKFLOW" = "-h" ]; then
  usage
  exit 4
fi

TEMPLATE=$(workflow_to_template "$WORKFLOW")
if [ -z "$TEMPLATE" ]; then
  echo -e "${RED}Unknown workflow: $WORKFLOW${NC}"
  usage
  exit 4
fi

mkdir -p "$STATE_DIR"

echo -e "${CYAN}═══ psk-validate: $WORKFLOW ═══${NC}"

# --- Layer 2A: Bash critic ---
echo -e "\n${CYAN}  [Layer 2A] Bash critic (psk-sync-check.sh --full)${NC}"

if [ "${PSK_SYNC_CHECK_DISABLED:-0}" = "1" ]; then
  echo -e "  ${YELLOW}⚠ Bash critic BYPASSED (PSK_SYNC_CHECK_DISABLED=1)${NC}"
  log_bypass "PSK_SYNC_CHECK_DISABLED" "$WORKFLOW"
elif [ -x "$SYNC_CHECK" ]; then
  if ! bash "$SYNC_CHECK" --full; then
    echo -e "\n${RED}Bash critic FAILED — fix mismatches above, then re-run.${NC}"
    exit 1
  fi
  echo -e "  ${GREEN}✓ Bash critic clean${NC}"
else
  echo -e "  ${YELLOW}⚠ psk-sync-check.sh not executable — bash critic skipped${NC}"
fi

# --- Layer 2B: Sub-agent critic ---
echo -e "\n${CYAN}  [Layer 2B] Sub-agent critic ($TEMPLATE)${NC}"

if [ "${PSK_CRITIC_DISABLED:-0}" = "1" ]; then
  echo -e "  ${YELLOW}⚠ Sub-agent critic BYPASSED (PSK_CRITIC_DISABLED=1)${NC}"
  log_bypass "PSK_CRITIC_DISABLED" "$WORKFLOW"
  echo -e "\n${GREEN}Validation PASSED (bypass mode) — bash critic clean${NC}"
  exit 0
fi

if [ ! -x "$CRITIC_SPAWN" ]; then
  echo -e "  ${YELLOW}⚠ psk-critic-spawn.sh not executable — sub-agent critic skipped${NC}"
  echo -e "\n${GREEN}Validation PASSED (bash-only) — sub-agent critic unavailable${NC}"
  exit 0
fi

# Freshness: critic-result.md must be newer than the invocation stamp from THIS run.
# The stamp is written at the start of each validate call; if result file is older
# than stamp, it's stale (e.g., from a prior workflow or prior iteration).
invoke_time=$(date +%s)

result_is_fresh() {
  [ -f "$RESULT_FILE" ] || return 1
  local mtime
  mtime=$(stat -f "%m" "$RESULT_FILE" 2>/dev/null || stat -c "%Y" "$RESULT_FILE" 2>/dev/null)
  [ -n "$mtime" ] || return 1
  # Must be newer than stamp from a PRIOR invocation of this workflow
  if [ -f "$INVOKE_STAMP" ]; then
    local stamp
    stamp=$(cat "$INVOKE_STAMP" 2>/dev/null)
    [ -n "$stamp" ] && [ "$mtime" -ge "$stamp" ]
  else
    return 1
  fi
}

if ! result_is_fresh; then
  # Write task file and exit AWAITING_CRITIC
  echo "$invoke_time" > "$INVOKE_STAMP"
  bash "$CRITIC_SPAWN" write "$TEMPLATE" >/dev/null 2>&1
  echo -e "  ${YELLOW}⏳ AWAITING_CRITIC — agent must spawn sub-agent${NC}"
  echo ""
  echo -e "  ${YELLOW}Agent protocol:${NC}"
  echo -e "    1. Read:  ${CYAN}$TASK_FILE${NC}"
  echo -e "    2. Spawn sub-agent via Task tool with that exact prompt"
  echo -e "    3. Write response to: ${CYAN}$RESULT_FILE${NC}"
  echo -e "    4. Re-run: ${CYAN}bash agent/scripts/psk-validate.sh $WORKFLOW${NC}"
  echo ""
  echo -e "  ${YELLOW}Bypass (emergencies only): ${NC}PSK_CRITIC_DISABLED=1 bash agent/scripts/psk-validate.sh $WORKFLOW"
  exit 2
fi

# Fresh result exists — evaluate
if grep -q "^STALE:" "$RESULT_FILE" 2>/dev/null; then
  echo -e "  ${RED}✗ Sub-agent critic: stale content found${NC}"
  grep "^STALE:" "$RESULT_FILE" | while IFS= read -r line; do
    echo -e "    ${RED}$line${NC}"
  done
  echo -e "\n${RED}Validation FAILED on sub-agent critic.${NC}"
  echo -e "  ${YELLOW}Fix flagged items, clear result, re-run:${NC}"
  echo -e "  ${CYAN}  rm $RESULT_FILE${NC}"
  echo -e "  ${CYAN}  bash agent/scripts/psk-validate.sh $WORKFLOW${NC}"
  exit 3
fi

if ! grep -q "^CURRENT:" "$RESULT_FILE" 2>/dev/null; then
  echo -e "  ${RED}✗ Sub-agent critic: result has no CURRENT/STALE verdicts${NC}"
  echo -e "  ${YELLOW}  Re-spawn sub-agent and ensure structured output.${NC}"
  exit 3
fi

current_count=$(grep -c "^CURRENT:" "$RESULT_FILE" 2>/dev/null)

# v0.5.15: verify every CURRENT has a QUOTE that actually exists in the file
if ! verify_quotes "$RESULT_FILE"; then
  echo -e "\n${RED}Validation FAILED — critic verdicts not backed by verifiable quotes.${NC}"
  echo -e "  ${YELLOW}Each CURRENT: must be followed by QUOTE: <verbatim line from file>.${NC}"
  echo -e "  ${YELLOW}The bash verifier greps the file for the exact quote — fake quotes fail.${NC}"
  echo -e "  ${YELLOW}Re-spawn critic with the updated prompt format in critic-task.md.${NC}"
  exit 3
fi

echo -e "  ${GREEN}✓ Sub-agent critic: $current_count file(s) CURRENT, 0 STALE${NC}"

# Clean up stamp so next invocation (next workflow) starts fresh
rm -f "$INVOKE_STAMP"

echo -e "\n${GREEN}Validation PASSED — dual gate clean (bash + sub-agent critic)${NC}"
exit 0
