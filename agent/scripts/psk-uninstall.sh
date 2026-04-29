#!/bin/bash
# =============================================================
# psk-uninstall.sh — Clean Uninstall of Portable Spec Kit
#
# Removes kit infrastructure from a project. Preserves user work.
#
# What it removes:
#   - portable-spec-kit.md (framework file)
#   - Symlinks: CLAUDE.md, .cursorrules, .windsurfrules, .clinerules,
#     .github/copilot-instructions.md
#   - .claude/settings.json (if installed by PSK)
#   - .git/hooks/pre-commit (if installed by PSK)
#   - .portable-spec-kit/ directory (skills + config)
#   - agent/scripts/psk-*.sh (kit scripts)
#   - install.sh
#
# What it preserves (never deleted):
#   - agent/*.md files (user's pipeline work — SPECS, PLANS, TASKS, etc.)
#   - agent/design/ (user's feature plans)
#   - tests/ (user's tests)
#   - src/, docs/, README.md (user's code and docs)
#   - .env, .gitignore (user config)
#
# Usage:
#   bash agent/scripts/psk-uninstall.sh          # interactive
#   bash agent/scripts/psk-uninstall.sh --yes    # non-interactive
#   bash agent/scripts/psk-uninstall.sh --full   # also remove agent/*.md (asks first)
#
# Exit codes:
#   0 = uninstalled successfully
#   1 = user aborted
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"

if [ -t 1 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; CYAN=''; NC=''
fi

AUTO_YES=false
FULL_MODE=false
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y) AUTO_YES=true; shift ;;
    --full)   FULL_MODE=true; shift ;;
    *)        shift ;;
  esac
done

confirm() {
  if [ "$AUTO_YES" = true ]; then return 0; fi
  echo -e -n "${YELLOW}$1 (y/N) ${NC}"
  read -r answer
  case "$answer" in y|Y|yes) return 0 ;; *) return 1 ;; esac
}

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  PSK UNINSTALLER${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Project: ${GREEN}$PROJ_ROOT${NC}"
echo ""
echo -e "  ${YELLOW}Will remove:${NC}"
echo -e "    - portable-spec-kit.md + symlinks (CLAUDE.md, .cursorrules, etc.)"
echo -e "    - .claude/settings.json, .git/hooks/pre-commit (if PSK-installed)"
echo -e "    - .portable-spec-kit/ (skills + config)"
echo -e "    - agent/scripts/psk-*.sh + install.sh"
echo ""
echo -e "  ${GREEN}Will preserve:${NC}"
echo -e "    - agent/*.md (your pipeline files — SPECS, PLANS, TASKS, etc.)"
echo -e "    - agent/design/ (your feature plans)"
echo -e "    - All your code, tests, docs, README"
echo ""

if ! confirm "Proceed with uninstall?"; then
  echo -e "${YELLOW}Aborted.${NC}"
  exit 1
fi

REMOVED=0

# Remove symlinks
for f in CLAUDE.md .cursorrules .windsurfrules .clinerules; do
  if [ -L "$PROJ_ROOT/$f" ] || [ -f "$PROJ_ROOT/$f" ]; then
    rm -f "$PROJ_ROOT/$f"
    REMOVED=$((REMOVED + 1))
  fi
done
[ -L "$PROJ_ROOT/.github/copilot-instructions.md" ] && rm -f "$PROJ_ROOT/.github/copilot-instructions.md" && REMOVED=$((REMOVED + 1))

# Remove framework file
[ -f "$PROJ_ROOT/portable-spec-kit.md" ] && rm -f "$PROJ_ROOT/portable-spec-kit.md" && REMOVED=$((REMOVED + 1))

# Remove install.sh
[ -f "$PROJ_ROOT/install.sh" ] && rm -f "$PROJ_ROOT/install.sh" && REMOVED=$((REMOVED + 1))

# Remove Claude Code hooks (only if PSK-installed)
if [ -f "$PROJ_ROOT/.claude/settings.json" ] && grep -q "psk-sync-check" "$PROJ_ROOT/.claude/settings.json" 2>/dev/null; then
  rm -f "$PROJ_ROOT/.claude/settings.json"
  rmdir "$PROJ_ROOT/.claude" 2>/dev/null || true
  REMOVED=$((REMOVED + 1))
  echo -e "  ${GREEN}✓${NC} Removed .claude/settings.json"
fi

# Remove git pre-commit hook (only if PSK-installed)
GIT_ROOT=$(cd "$PROJ_ROOT" && git rev-parse --show-toplevel 2>/dev/null)
if [ -n "$GIT_ROOT" ] && [ -f "$GIT_ROOT/.git/hooks/pre-commit" ] && grep -q "psk-sync-check" "$GIT_ROOT/.git/hooks/pre-commit" 2>/dev/null; then
  rm -f "$GIT_ROOT/.git/hooks/pre-commit"
  REMOVED=$((REMOVED + 1))
  echo -e "  ${GREEN}✓${NC} Removed .git/hooks/pre-commit"
fi

# Remove .portable-spec-kit directory
if [ -d "$PROJ_ROOT/.portable-spec-kit" ]; then
  rm -rf "$PROJ_ROOT/.portable-spec-kit"
  REMOVED=$((REMOVED + 1))
  echo -e "  ${GREEN}✓${NC} Removed .portable-spec-kit/"
fi

# Remove PSK scripts (keep non-PSK scripts like user's own sync.sh)
for s in "$PROJ_ROOT"/agent/scripts/psk-*.sh; do
  [ -f "$s" ] && rm -f "$s" && REMOVED=$((REMOVED + 1))
done
[ -f "$PROJ_ROOT/agent/scripts/install-tracker.sh" ] && rm -f "$PROJ_ROOT/agent/scripts/install-tracker.sh"
[ -f "$PROJ_ROOT/agent/scripts/uninstall-tracker.sh" ] && rm -f "$PROJ_ROOT/agent/scripts/uninstall-tracker.sh"

# Remove test-release-check.sh (kit-distributed)
[ -f "$PROJ_ROOT/tests/test-release-check.sh" ] && rm -f "$PROJ_ROOT/tests/test-release-check.sh"

# Remove release state
rm -rf "$PROJ_ROOT/agent/.release-state" 2>/dev/null

# Full mode: also remove agent/*.md (user's work — confirm separately)
if [ "$FULL_MODE" = true ]; then
  echo ""
  echo -e "${RED}  --full mode: also removing agent/*.md (your pipeline files)${NC}"
  if confirm "  Delete agent/ directory entirely (IRREVERSIBLE)?"; then
    rm -rf "$PROJ_ROOT/agent"
    REMOVED=$((REMOVED + 1))
    echo -e "  ${RED}✓${NC} Removed agent/ directory"
  else
    echo -e "  ${YELLOW}Skipped agent/ deletion — pipeline files preserved${NC}"
  fi
fi

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ UNINSTALLED ($REMOVED items removed)${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Your agent/ pipeline files are preserved (SPECS, PLANS, TASKS, etc.)."
echo -e "  To re-install: curl -fsSL https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/install.sh | bash"
echo ""
