#!/bin/bash
# workflow-router: psk-new-setup.sh — new-project setup (fresh scaffold)
# workflow-decl: .portable-spec-kit/workflows/new-setup/phases.yml
# =============================================================
# psk-new-setup.sh — New Project Setup (dispatcher-driven, v0.6.62+)
#
# Dual-mode router:
#   • bash psk-new-setup.sh             → delegate to psk-dispatch.sh new-setup
#   • bash psk-new-setup.sh preflight   → dir-empty + kit-present checks
#   • bash psk-new-setup.sh scaffold    → scaffold guidance (gate test -d agent verifies)
#   • bash psk-new-setup.sh <verb> ...  → forward dispatcher verbs
#
# Phase sequence + gates live in the declaration; psk-dispatch.sh is the executor.
#
# §Workflow Fidelity (portable-spec-kit.md): this is an executable kit workflow.
# It executes its declared phases faithfully and completely via psk-dispatch.sh —
# no phase compression, no inline substitution, no scope reduction under pressure.
# Pause-and-resume, never reduce-scope.
# =============================================================

# QA-D5-P8 (cycle-01-pass-008): full errexit. Branches are echo + exit/exec
# only; the non-zero exits (preflight missing-kit) are deliberate hard fails,
# and there is no tolerable-non-zero command used as control flow, so -e is
# safe here and aligns with the kit's strictest-shell convention.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

case "${1:-}" in
  preflight)
    echo -e "${CYAN}═══ New Project Setup — Preflight ═══${NC}"
    # Preflight 1: directory should be mostly empty (or kit-only)
    # QA-D5-P8: under `set -euo pipefail`, a non-zero `find` (e.g. a perms
    # error) would otherwise abort via pipefail — the `|| true` keeps the
    # count-or-zero contract intact.
    non_kit=$( { find "$PROJ_ROOT" -maxdepth 1 -mindepth 1 \
      ! -name ".git" ! -name "portable-spec-kit.md" ! -name "CLAUDE.md" \
      ! -name ".cursorrules" ! -name ".windsurfrules" ! -name ".clinerules" \
      ! -name ".github" ! -name ".portable-spec-kit" ! -name "agent" \
      2>/dev/null || true; } | wc -l | tr -d ' ')
    if [ "$non_kit" -gt 3 ]; then
      echo -e "  ${YELLOW}⚠${NC} $non_kit non-kit entries in project root — consider existing-setup instead of new-setup"
    else
      echo -e "  ${GREEN}✓${NC} Project root suitable for fresh scaffold ($non_kit non-kit entries)"
    fi
    # Preflight 2: portable-spec-kit.md present
    if [ -e "$PROJ_ROOT/portable-spec-kit.md" ]; then
      echo -e "  ${GREEN}✓${NC} portable-spec-kit.md present"
    else
      echo -e "  ${RED}✗${NC} portable-spec-kit.md missing — install the kit first (curl or install.sh)"
      exit 1
    fi
    echo -e "\n${CYAN}Next:${NC} scaffold dirs + files per docs/work-flows/03-new-project-setup.md, then: bash agent/scripts/psk-new-setup.sh next"
    exit 0
    ;;
  scaffold)
    echo -e "${CYAN}═══ New Project Setup — Scaffold ═══${NC}"
    echo -e "  Scaffold the standard structure (agent/*, README, .gitignore, src/, tests/, docs/)"
    echo -e "  per docs/work-flows/03-new-project-setup.md + the project-setup skill."
    echo -e "  The phase gate (test -d agent) confirms the scaffold landed."
    echo -e "  Then: ${CYAN}bash agent/scripts/psk-new-setup.sh next${NC} to advance to validation."
    exit 0
    ;;
  ""|new-setup)
    exec bash "$SCRIPT_DIR/psk-dispatch.sh" new-setup
    ;;
  *)
    exec bash "$SCRIPT_DIR/psk-dispatch.sh" new-setup "$@"
    ;;
esac
