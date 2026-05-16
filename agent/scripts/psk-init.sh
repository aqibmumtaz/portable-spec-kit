#!/bin/bash
# =============================================================
# psk-init.sh — Init Workflow Orchestrator
#
# Preflight checks before `init` fills agent/* from codebase,
# followed by final dual-gate validation.
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

MODE="${1:-complete}"   # start | complete

case "$MODE" in
  start)
    echo -e "${CYAN}═══ Init — Preflight ═══${NC}"

    # §Workflow Fidelity B2 — init the resumable state machine + register gates.
    # Phase preflight has no clean completion check (interactive) so its gate is `true`.
    # Phase work's gate is sync-check --full (project pipeline files consistent).
    # Phase validation's gate is psk-validate.sh init (dual critic exit 0).
    if [ -x "$WFS" ]; then
      bash "$WFS" init psk-init "preflight,work,validation" >/dev/null 2>&1 || true
      bash "$WFS" register-gate psk-init preflight "true" >/dev/null 2>&1 || true
      bash "$WFS" register-gate psk-init work "bash $SCRIPT_DIR/psk-sync-check.sh --full" >/dev/null 2>&1 || true
      bash "$WFS" register-gate psk-init validation "bash $SCRIPT_DIR/psk-validate.sh init" >/dev/null 2>&1 || true
      bash "$WFS" verify-gate psk-init preflight >/dev/null 2>&1 || true
      bash "$WFS" mark-done psk-init preflight >/dev/null 2>&1 || true
      bash "$WFS" mark-in-progress psk-init work >/dev/null 2>&1 || true
    fi


    # Preflight 1: codebase has some content (non-trivial repo)
    src_count=$(find "$PROJ_ROOT" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" -o -name "*.rb" -o -name "*.java" \) 2>/dev/null | grep -v node_modules | grep -v __pycache__ | wc -l | tr -d ' ')
    if [ "$src_count" -lt 2 ]; then
      echo -e "  ${YELLOW}⚠${NC} Only $src_count source file(s) — init may be trivial. Consider new-setup instead."
    else
      echo -e "  ${GREEN}✓${NC} $src_count source file(s) detected — enough for retroactive fill"
    fi

    # Preflight 2: agent/ structure
    if [ -d "$PROJ_ROOT/agent" ] && [ -n "$(ls -A "$PROJ_ROOT/agent" 2>/dev/null | grep -v '^scripts$' | grep -v '^design$' | grep -v '^\.release-state$' | grep -v '^\.bypass-log$')" ]; then
      echo -e "  ${YELLOW}⚠${NC} agent/ already has content — use reinit instead of init, or confirm overwrite"
    else
      echo -e "  ${GREEN}✓${NC} agent/ ready for init"
    fi

    echo -e "\n${CYAN}Next:${NC} do the init work (fill agent/*.md from codebase per docs/work-flows/05-project-init.md)"
    echo -e "${CYAN}Then:${NC} bash agent/scripts/psk-init.sh complete"
    ;;

  complete)
    echo -e "${CYAN}═══ Init — Final Gate ═══${NC}"
    # B2: verify work-phase gate first (sync-check), then run final dual gate.
    if [ -x "$WFS" ] && [ -f "$PROJ_ROOT/agent/.workflow-state/psk-init.state" ]; then
      bash "$WFS" verify-gate psk-init work >/dev/null 2>&1 \
        && bash "$WFS" mark-done psk-init work >/dev/null 2>&1 \
        && bash "$WFS" mark-in-progress psk-init validation >/dev/null 2>&1 || true
    fi
    bash "$SCRIPT_DIR/psk-validate.sh" init
    rc=$?
    if [ "$rc" -eq 0 ] && [ -x "$WFS" ] && [ -f "$PROJ_ROOT/agent/.workflow-state/psk-init.state" ]; then
      bash "$WFS" verify-gate psk-init validation >/dev/null 2>&1 \
        && bash "$WFS" mark-done psk-init validation >/dev/null 2>&1 || true
    fi
    exit $rc
    ;;

  *)
    echo "Usage: bash psk-init.sh [start|complete]"
    exit 4
    ;;
esac
