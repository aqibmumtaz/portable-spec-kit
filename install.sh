#!/bin/bash
# =============================================================
# install.sh — Portable Spec Kit Installer
#
# Installs the full reliability architecture into a project:
#   - portable-spec-kit.md (framework file)
#   - agent/scripts/*.sh (reliability infrastructure)
#   - .portable-spec-kit/skills/*.md (on-demand skill files)
#   - .claude/settings.json (PostToolUse hook)
#   - .git/hooks/pre-commit (blocking hook)
#   - Symlinks: CLAUDE.md, .cursorrules, .windsurfrules, .clinerules,
#     .github/copilot-instructions.md
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/install.sh | bash
#   bash install.sh                     # interactive install
#   bash install.sh --yes               # non-interactive install
#   bash install.sh --verify            # download SHA and print for audit
#   bash install.sh --from LOCAL        # use local directory as source (for testing)
#   bash install.sh --install-reflex  # also install F70 Reflex (QA+Dev loop)
#
# Exit codes:
#   0 = installed successfully
#   1 = installation failed
#   2 = user aborted or configuration error
# =============================================================

set -uo pipefail

# --- Config ---
REPO="aqibmumtaz/portable-spec-kit"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"

# --- Colors ---
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; CYAN=''; NC=''
fi

# --- Options ---
AUTO_YES=false
VERIFY_ONLY=false
LOCAL_SOURCE=""
INSTALL_REFLEX=false

while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)            AUTO_YES=true; shift ;;
    --verify)            VERIFY_ONLY=true; shift ;;
    --from)              LOCAL_SOURCE="$2"; shift 2 ;;
    --install-reflex)  INSTALL_REFLEX=true; shift ;;
    *)                   shift ;;
  esac
done

# --- Environment detection ---
OS=$(uname -s 2>/dev/null || echo unknown)
case "$OS" in
  Darwin)  PLATFORM="macOS" ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      PLATFORM="WSL"
    else
      PLATFORM="Linux"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="Windows (Git Bash)" ;;
  *) PLATFORM="$OS" ;;
esac

# --- Check required tools ---
check_tools() {
  local missing=""
  for tool in bash git; do
    command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
  done
  if [ -z "$LOCAL_SOURCE" ]; then
    command -v curl >/dev/null 2>&1 || missing="$missing curl"
  fi
  if [ -n "$missing" ]; then
    echo -e "${RED}Error: Required tools missing:$missing${NC}"
    echo -e "${RED}       Install them first, then re-run this script.${NC}"
    exit 1
  fi
}

# --- Print banner ---
print_banner() {
  echo ""
  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  PORTABLE SPEC KIT INSTALLER${NC}"
  echo -e "${CYAN}  Spec-Persistent Development for AI-Assisted Engineering${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  Platform: ${GREEN}$PLATFORM${NC}"
  echo -e "  Project:  ${GREEN}$(pwd)${NC}"
  echo -e "  Source:   ${GREEN}${LOCAL_SOURCE:-$REPO ($BRANCH)}${NC}"
  echo ""
}

# --- What will be installed ---
print_install_plan() {
  echo -e "${CYAN}This installer will:${NC}"
  echo ""
  echo -e "  1. Download ${YELLOW}portable-spec-kit.md${NC} (framework file)"
  echo -e "  2. Download ${YELLOW}agent/scripts/*.sh${NC} (reliability scripts)"
  echo -e "  3. Download ${YELLOW}.portable-spec-kit/skills/*.md${NC} (skill files)"
  echo -e "  4. Create ${YELLOW}.claude/settings.json${NC} (PostToolUse hook)"
  echo -e "  5. Create ${YELLOW}.git/hooks/pre-commit${NC} (blocking hook)"
  echo -e "  6. Create symlinks for all AI agents (CLAUDE.md, .cursorrules, etc.)"
  echo ""
  echo -e "  Nothing runs with ${RED}sudo${NC}. No network calls after install."
  echo -e "  Your existing files are preserved (backed up if overwritten)."
  echo ""
}

# --- Confirm with user ---
confirm() {
  if [ "$AUTO_YES" = true ]; then
    return 0
  fi
  echo -e -n "${YELLOW}Proceed with install? (y/N) ${NC}"
  read -r answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *)
      echo -e "${YELLOW}Aborted by user.${NC}"
      exit 2
      ;;
  esac
}

# --- Download or copy a file ---
fetch() {
  local src_path="$1"
  local dest_path="$2"
  mkdir -p "$(dirname "$dest_path")"

  if [ -n "$LOCAL_SOURCE" ]; then
    if [ -f "$LOCAL_SOURCE/$src_path" ]; then
      cp "$LOCAL_SOURCE/$src_path" "$dest_path"
      return 0
    else
      return 1
    fi
  fi

  if curl -fsSL "$RAW_BASE/$src_path" -o "$dest_path" 2>/dev/null; then
    return 0
  fi
  return 1
}

# --- Download phase ---
download_framework() {
  echo -e "${CYAN}[1/6] Downloading framework file...${NC}"
  if fetch "portable-spec-kit.md" "./portable-spec-kit.md"; then
    echo -e "  ${GREEN}✓${NC} portable-spec-kit.md"
  else
    echo -e "  ${RED}✗${NC} Failed to download portable-spec-kit.md"
    exit 1
  fi
}

download_scripts() {
  echo -e "${CYAN}[2/6] Downloading reliability scripts...${NC}"
  local scripts="psk-sync-check.sh psk-install-hooks.sh psk-code-review.sh psk-scope-check.sh psk-release.sh psk-critic-spawn.sh psk-validate.sh psk-feature-complete.sh psk-init.sh psk-reinit.sh psk-new-setup.sh psk-existing-setup.sh psk-uninstall.sh psk-doc-sync.sh psk-reflex.sh"
  local optional="psk-jira-sync.sh psk-tracker.sh psk-tracker-report.sh install-tracker.sh uninstall-tracker.sh"

  for s in $scripts; do
    if fetch "agent/scripts/$s" "./agent/scripts/$s"; then
      chmod +x "./agent/scripts/$s"
      echo -e "  ${GREEN}✓${NC} agent/scripts/$s"
    else
      echo -e "  ${RED}✗${NC} agent/scripts/$s (required)"
      exit 1
    fi
  done

  for s in $optional; do
    if fetch "agent/scripts/$s" "./agent/scripts/$s" 2>/dev/null; then
      chmod +x "./agent/scripts/$s"
      echo -e "  ${GREEN}✓${NC} agent/scripts/$s (optional)"
    fi
  done

  # tests/test-release-check.sh is called by psk-sync-check.sh
  if fetch "tests/test-release-check.sh" "./tests/test-release-check.sh"; then
    chmod +x "./tests/test-release-check.sh"
    echo -e "  ${GREEN}✓${NC} tests/test-release-check.sh"
  fi
}

download_skills() {
  echo -e "${CYAN}[3/6] Downloading skill files...${NC}"
  local skills="templates.md python-environment.md source-structures.md profile-setup.md document-generation.md test-release-check-template.md release-process.md hooks-and-critics.md init-process.md onboarding-tour.md dashboard.md multi-agent.md jira-integration.md project-setup.md self-help.md ci-setup.md config-details.md"

  for s in $skills; do
    if fetch ".portable-spec-kit/skills/$s" "./.portable-spec-kit/skills/$s" 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} .portable-spec-kit/skills/$s"
    else
      echo -e "  ${YELLOW}⊘${NC} .portable-spec-kit/skills/$s (will be cached on first use)"
    fi
  done

  # v0.5.16 — CI templates for user projects (Node/Python/Go/generic)
  echo -e "${CYAN}  Downloading CI templates...${NC}"
  mkdir -p ./.portable-spec-kit/templates/ci
  local ci_files="ci-node.yml ci-python.yml ci-go.yml ci-generic.yml README.md"
  for f in $ci_files; do
    if fetch ".portable-spec-kit/templates/ci/$f" "./.portable-spec-kit/templates/ci/$f" 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} .portable-spec-kit/templates/ci/$f"
    else
      echo -e "  ${YELLOW}⊘${NC} .portable-spec-kit/templates/ci/$f"
    fi
  done
}

# --- Create symlinks (or copies on Windows) ---
create_symlinks() {
  echo -e "${CYAN}[6/6] Creating agent symlinks...${NC}"
  local source_file="portable-spec-kit.md"
  local targets="CLAUDE.md .cursorrules .windsurfrules .clinerules"

  for t in $targets; do
    if [ -e "$t" ] && [ ! -L "$t" ]; then
      cp "$t" "$t.psk-backup.$(date +%s)" 2>/dev/null || true
      rm -f "$t"
    elif [ -L "$t" ]; then
      rm -f "$t"
    fi

    case "$PLATFORM" in
      "Windows (Git Bash)")
        cp "$source_file" "$t" 2>/dev/null && echo -e "  ${GREEN}✓${NC} $t (copied — Windows)" ;;
      *)
        ln -s "$source_file" "$t" 2>/dev/null && echo -e "  ${GREEN}✓${NC} $t → $source_file" ;;
    esac
  done

  # GitHub Copilot location
  mkdir -p .github
  local copilot=".github/copilot-instructions.md"
  if [ -e "$copilot" ] && [ ! -L "$copilot" ]; then
    cp "$copilot" "$copilot.psk-backup.$(date +%s)" 2>/dev/null || true
    rm -f "$copilot"
  elif [ -L "$copilot" ]; then
    rm -f "$copilot"
  fi
  case "$PLATFORM" in
    "Windows (Git Bash)")
      cp "$source_file" "$copilot" && echo -e "  ${GREEN}✓${NC} $copilot (copied)" ;;
    *)
      ln -s "../$source_file" "$copilot" && echo -e "  ${GREEN}✓${NC} $copilot → ../$source_file" ;;
  esac
}

install_hooks() {
  echo -e "${CYAN}[4/6] Installing Claude Code hooks and git pre-commit hook...${NC}"
  if [ -x "./agent/scripts/psk-install-hooks.sh" ]; then
    bash "./agent/scripts/psk-install-hooks.sh" 2>&1 | sed 's/^/  /'
  else
    echo -e "  ${RED}✗${NC} psk-install-hooks.sh not executable"
    exit 1
  fi
}

verify_install() {
  echo -e "${CYAN}[5/6] Verifying installation...${NC}"
  if [ -x "./agent/scripts/psk-sync-check.sh" ]; then
    if bash "./agent/scripts/psk-sync-check.sh" --quick 2>&1 | grep -v '^$' | sed 's/^/  /'; then
      echo -e "  ${GREEN}✓${NC} Sync-check verified"
    fi
  fi
}

# --- Next steps ---
print_next_steps() {
  echo ""
  echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✓ PORTABLE SPEC KIT INSTALLED${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  ${CYAN}Next steps:${NC}"
  echo ""
  echo -e "  1. Open your AI agent (Claude Code, Cursor, Copilot, etc.)"
  echo -e "  2. The agent reads ${YELLOW}CLAUDE.md${NC} (or equivalent) automatically"
  echo -e "  3. Run ${YELLOW}init${NC} command — agent will scan and set up agent/ files"
  echo -e "  4. Start describing what you want to build"
  echo ""
  echo -e "  ${CYAN}Reliability infrastructure is active:${NC}"
  echo -e "    • PreCommit hook blocks commits with factual drift"
  echo -e "    • PostToolUse hook warns on edits"
  echo -e "    • psk-release.sh enforces release process"
  echo ""
  echo -e "  ${CYAN}Learn more:${NC}"
  echo -e "    • Say 'help' to your agent"
  echo -e "    • Say 'show commands' to see what's available"
  echo -e "    • Emergency bypass: ${YELLOW}PSK_SYNC_CHECK_DISABLED=1${NC}"
  echo ""
}

# --- Main ---
main() {
  check_tools

  if [ "$VERIFY_ONLY" = true ]; then
    echo -e "${CYAN}install.sh integrity:${NC}"
    if command -v shasum >/dev/null 2>&1; then
      shasum -a 256 "$0" 2>/dev/null || echo "  (could not compute SHA-256)"
    elif command -v sha256sum >/dev/null 2>&1; then
      sha256sum "$0" 2>/dev/null || echo "  (could not compute SHA-256)"
    fi
    echo ""
    echo -e "  To verify: compare SHA-256 with published value in README.md"
    exit 0
  fi

  print_banner
  print_install_plan
  confirm

  download_framework
  download_scripts
  download_skills
  install_hooks
  verify_install
  create_symlinks

  if [ "$INSTALL_REFLEX" = true ]; then
    install_reflex
  fi

  print_next_steps
}

# --- Reflex opt-in installer (F70) ---
install_reflex() {
  echo ""
  echo -e "${CYAN}═══ Installing F70 Reflex (QA + Dev-Agent loop) ═══${NC}"
  mkdir -p reflex/lib reflex/prompts reflex/history reflex/sandbox

  local reflex_files=(run.sh install-into-project.sh update.sh README.md config.yml)
  for f in "${refine_files[@]}"; do
    if [ -n "$LOCAL_SOURCE" ] && [ -f "$LOCAL_SOURCE/reflex/$f" ]; then
      cp "$LOCAL_SOURCE/reflex/$f" "reflex/$f"
    else
      curl -fsSL "$RAW_BASE/reflex/$f" -o "reflex/$f" 2>/dev/null || {
        echo -e "  ${YELLOW}⚠ failed to fetch reflex/$f${NC}"
        continue
      }
    fi
    [ "${f##*.}" = "sh" ] && chmod +x "reflex/$f"
  done

  local lib_files=(preconditions.sh spawn-qa.sh spawn-dev.sh file-bugs.sh gates.sh regression-diff.sh score.sh)
  for f in "${lib_files[@]}"; do
    if [ -n "$LOCAL_SOURCE" ] && [ -f "$LOCAL_SOURCE/reflex/lib/$f" ]; then
      cp "$LOCAL_SOURCE/reflex/lib/$f" "reflex/lib/$f"
    else
      curl -fsSL "$RAW_BASE/reflex/lib/$f" -o "reflex/lib/$f" 2>/dev/null || continue
    fi
    chmod +x "reflex/lib/$f"
  done

  for f in qa-agent.md dev-agent.md; do
    if [ -n "$LOCAL_SOURCE" ] && [ -f "$LOCAL_SOURCE/reflex/prompts/$f" ]; then
      cp "$LOCAL_SOURCE/reflex/prompts/$f" "reflex/prompts/$f"
    else
      curl -fsSL "$RAW_BASE/reflex/prompts/$f" -o "reflex/prompts/$f" 2>/dev/null || continue
    fi
  done

  echo -e "  ${GREEN}✓ reflex/ installed${NC}"
  echo -e "  ${YELLOW}Next: review reflex/config.yml, then run${NC} bash reflex/run.sh ${YELLOW}after your next prepare release${NC}"
}

main
