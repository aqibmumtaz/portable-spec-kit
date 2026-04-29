#!/bin/bash
# =============================================================
# psk-init.sh — Init Workflow Orchestrator
#
# Preflight checks before `init` fills agent/* from codebase,
# followed by final dual-gate validation.
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

MODE="${1:-complete}"   # start | complete

case "$MODE" in
  start)
    echo -e "${CYAN}═══ Init — Preflight ═══${NC}"

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
    bash "$SCRIPT_DIR/psk-validate.sh" init
    exit $?
    ;;

  *)
    echo "Usage: bash psk-init.sh [start|complete]"
    exit 4
    ;;
esac
