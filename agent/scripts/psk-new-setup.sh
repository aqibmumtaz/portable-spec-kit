#!/bin/bash
# =============================================================
# psk-new-setup.sh — New Project Setup Orchestrator
#
# Preflight: confirm directory is empty / new, then final gate.
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

MODE="${1:-complete}"

case "$MODE" in
  start)
    echo -e "${CYAN}═══ New Project Setup — Preflight ═══${NC}"

    # Preflight 1: directory should be mostly empty (or kit-only)
    non_kit=$(find "$PROJ_ROOT" -maxdepth 1 -mindepth 1 \
      ! -name ".git" ! -name "portable-spec-kit.md" ! -name "CLAUDE.md" \
      ! -name ".cursorrules" ! -name ".windsurfrules" ! -name ".clinerules" \
      ! -name ".github" ! -name ".portable-spec-kit" ! -name "agent" \
      2>/dev/null | wc -l | tr -d ' ')
    if [ "$non_kit" -gt 3 ]; then
      echo -e "  ${YELLOW}⚠${NC} $non_kit non-kit entries in project root — consider existing-setup instead of new-setup"
    else
      echo -e "  ${GREEN}✓${NC} Project root suitable for fresh scaffold ($non_kit non-kit entries)"
    fi

    # Preflight 2: portable-spec-kit.md symlink or file present
    if [ -e "$PROJ_ROOT/portable-spec-kit.md" ]; then
      echo -e "  ${GREEN}✓${NC} portable-spec-kit.md present"
    else
      echo -e "  ${RED}✗${NC} portable-spec-kit.md missing — install the kit first (curl or install.sh)"
      exit 1
    fi

    echo -e "\n${CYAN}Next:${NC} scaffold directories + files per docs/work-flows/03-new-project-setup.md"
    echo -e "${CYAN}Then:${NC} bash agent/scripts/psk-new-setup.sh complete"
    ;;

  complete)
    echo -e "${CYAN}═══ New Project Setup — Final Gate ═══${NC}"
    bash "$SCRIPT_DIR/psk-validate.sh" new-setup
    exit $?
    ;;

  *)
    echo "Usage: bash psk-new-setup.sh [start|complete]"
    exit 4
    ;;
esac
