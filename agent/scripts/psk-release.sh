#!/bin/bash
# workflow-router: psk-release.sh — release ceremony (10-step pipeline)
# workflow-decl: .portable-spec-kit/workflows/release/phases.yml
# script-class: orchestrator
#
# Thin CLI wrapper — delegates to psk-dispatch.sh (unified phase driver).
# Phase logic, state machine, and spawn routing all live in:
#   .portable-spec-kit/workflows/release/phases.yml  (declarations)
#   agent/scripts/psk-dispatch.sh                    (executor)
#
# This wrapper keeps only the logic that MUST run before/around dispatch:
#   • Bootstrap gate (pre-Step-0) — refuse to start a release if the kit was
#     never installed in this project (catches the "agent/ files created by
#     hand, install.sh never run" failure mode). Bypass:
#     PSK_BOOTSTRAP_CHECK_DISABLED=1 (genuine emergencies only).
#   • Stale-state detection (v0.5.20) — refuse to resume a release state file
#     older than 24h (version-drift risk if STEP_6_VERSION still pending).
#
# Verbs forwarded to psk-dispatch.sh release <verb>:
#   prepare  → bootstrap gate + init + next (start the release pipeline)
#   refresh  → bootstrap gate + init --refresh + next (no version bump)
#   next     → advance to next phase (stale-state check runs here)
#   done     → mark agent step done
#   status   → show pipeline progress
#   reset    → clear state
#   (resume / abandon / --validate ... also forwarded)
#
# Usage:
#   bash agent/scripts/psk-release.sh prepare
#   bash agent/scripts/psk-release.sh refresh
#   bash agent/scripts/psk-release.sh next
#   bash agent/scripts/psk-release.sh done
#   bash agent/scripts/psk-release.sh status
#   bash agent/scripts/psk-release.sh reset
#
# Exit codes: same as psk-dispatch.sh (0=ok, 1=error, 2=schema, 3=gate-fail, 4=arbitration)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# KIT-GAP-0093: canonical run-state lives in .workflow-state/ after the v0.6.62
# dispatcher migration. The legacy agent/.release-state/state is vestigial (only
# this script read it) and is NOT refreshed by prepare, so a stale sentinel there
# made the staleness guard misfire. Point it at the dispatcher's state file so
# state_is_stale reflects the actual run.
_RELEASE_STATE="$PROJ_ROOT/agent/.workflow-state/release.state"
START_VERSION=

if [ -t 2 ]; then
  RED='\033[0;31m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
  RED=''; CYAN=''; YELLOW=''; NC=''
fi

# === BOOTSTRAP GATE (pre-Step-0) ===
# Ensures the kit was actually installed in this project before any release
# work begins. Without this, a partially-bootstrapped project can run
# prep-release + reflex end-to-end and ship a v0.N.N commit without any kit
# infrastructure ever being in place. Bypass: PSK_BOOTSTRAP_CHECK_DISABLED=1.
run_bootstrap_gate() {
  local bootstrap_check="$SCRIPT_DIR/psk-bootstrap-check.sh"
  if [ ! -x "$bootstrap_check" ]; then
    # Script missing — skip silently (older projects); install.sh lands it next run.
    return 0
  fi
  if [ "${PSK_BOOTSTRAP_CHECK_DISABLED:-0}" = "1" ]; then
    # HF9 (v0.6.60): record bypass to agent/.bypass-log for PSK027 audit.
    local _bypass_log_script="$SCRIPT_DIR/psk-bypass-log.sh"
    if [ -x "$_bypass_log_script" ]; then
      bash "$_bypass_log_script" log \
        --env-var "PSK_BOOTSTRAP_CHECK_DISABLED" \
        --command "psk-release.sh (bootstrap gate)" \
        --justification "${PSK_BYPASS_REASON:-not provided}" \
        2>/dev/null || true
    fi
    echo -e "${YELLOW}⚠ psk-bootstrap-check bypassed (PSK_BOOTSTRAP_CHECK_DISABLED=1)${NC}" >&2
    return 0
  fi
  if ! bash "$bootstrap_check" --quiet; then
    echo "" >&2
    echo -e "${RED}✗ Cannot start release — kit is not fully installed in this project.${NC}" >&2
    echo "" >&2
    bash "$bootstrap_check" | sed 's/^/  /' >&2
    echo "" >&2
    echo -e "${CYAN}→ Fix by running the kit installer from its source checkout, then retry.${NC}" >&2
    exit 1
  fi
}

# Stale release state detection — returns 0 (true) if state file is >24h old.
# Uses RUN_ID (Unix timestamp written at prepare time) to compute age.
state_is_stale() {
  local state_file="${1:-$_RELEASE_STATE}"
  [ ! -f "$state_file" ] && return 1
  local run_id
  run_id=$(grep "^RUN_ID=" "$state_file" | head -1 | cut -d= -f2-)
  [ -z "$run_id" ] && return 1
  local now_epoch age_sec
  now_epoch=$(date +%s)
  age_sec=$(( now_epoch - run_id ))
  [ "$age_sec" -gt 86400 ]
}

run_next() {
  if state_is_stale "$_RELEASE_STATE"; then
    # If STEP_6_VERSION is still pending, warn about version drift risk.
    local step6; step6=$(grep "^STEP_6_VERSION=pending" "$_RELEASE_STATE" 2>/dev/null | head -1)
    if [ -n "$step6" ]; then
      echo "Refusing to resume stale release state (STEP_6_VERSION pending — version drift risk)" >&2
    else
      echo "Refusing to resume stale release state — state is over 24h old" >&2
    fi
    echo "  Run 'bash agent/scripts/psk-release.sh prepare' to start fresh." >&2
    exit 1
  fi
  exec bash "$SCRIPT_DIR/psk-dispatch.sh" release next
}

show_status() {
  echo "=== RELEASE PROGRESS ===" >&2
  if state_is_stale "$_RELEASE_STATE"; then
    echo "State is stale (>24h old) — run 'prepare release' to start fresh" >&2
  fi
  exec bash "$SCRIPT_DIR/psk-dispatch.sh" release status
}

case "${1:-}" in
  prepare)
    run_bootstrap_gate
    START_VERSION="$(git -C "$PROJ_ROOT" describe --tags --abbrev=0 2>/dev/null || echo "")"
    rm -f "$PROJ_ROOT/agent/.release-state/.validate-stamp"
    rm -f "$PROJ_ROOT/agent/.release-state/.validation-passed.release"  # KIT-GAP-0068: stale idempotency marker
    bash "$SCRIPT_DIR/psk-dispatch.sh" release init
    exec bash "$SCRIPT_DIR/psk-dispatch.sh" release next
    ;;
  refresh)
    run_bootstrap_gate
    START_VERSION="$(git -C "$PROJ_ROOT" describe --tags --abbrev=0 2>/dev/null || echo "")"
    rm -f "$PROJ_ROOT/agent/.release-state/.validate-stamp"
    rm -f "$PROJ_ROOT/agent/.release-state/.validation-passed.release"  # KIT-GAP-0068: stale idempotency marker
    bash "$SCRIPT_DIR/psk-dispatch.sh" release init --refresh
    exec bash "$SCRIPT_DIR/psk-dispatch.sh" release next
    ;;
  next)
    run_next
    ;;
  status)
    show_status
    ;;
  *)
    exec bash "$SCRIPT_DIR/psk-dispatch.sh" release "$@"
    ;;
esac
