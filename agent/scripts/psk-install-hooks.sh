#!/bin/bash
# mechanical-script: deterministic, no AI prompts (Dim 28 allowlist — v0.6.60 HF7b)
# =============================================================
# psk-install-hooks.sh — Install Claude Code + Git Hooks
#
# Installs reliability architecture hooks:
#   - .claude/settings.json (PostToolUse warning hook)
#   - .git/hooks/pre-commit (blocking hook — runs psk-sync-check.sh --full)
#   - .git/hooks/post-commit (refreshes PSK029 resume-bootstrap marker)
#
# Wraps existing hooks, never overwrites:
#   - Existing .git/hooks/pre-commit → chains our check before it
#   - Husky detected → adds our check to .husky/pre-commit
#   - pre-commit framework → suggests adding our check
#
# Usage:
#   bash agent/scripts/psk-install-hooks.sh          # install if missing
#   bash agent/scripts/psk-install-hooks.sh --force  # reinstall even if present
#   bash agent/scripts/psk-install-hooks.sh --status # check what's installed
#
# Exit codes:
#   0 = installed successfully (or already installed)
#   1 = installation failed
#   2 = configuration error (not in a git repo)
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
PROJ_ROOT="$(cd "$AGENT_DIR/.." 2>/dev/null && pwd)"

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
FORCE=false
STATUS_ONLY=false
while [ $# -gt 0 ]; do
  case "$1" in
    --force)   FORCE=true; shift ;;
    --status)  STATUS_ONLY=true; shift ;;
    *)         shift ;;
  esac
done

# --- Validate environment ---
GIT_ROOT=$(cd "$PROJ_ROOT" && git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$GIT_ROOT" ]; then
  echo -e "${RED}Error: Not inside a git repository (cd to project first)${NC}"
  exit 2
fi

if [ ! -f "$AGENT_DIR/scripts/psk-sync-check.sh" ]; then
  echo -e "${RED}Error: psk-sync-check.sh not found at $AGENT_DIR/scripts/${NC}"
  echo -e "${RED}       Install scripts first, then run this installer.${NC}"
  exit 2
fi

# Claude settings live in project dir; git hooks live in actual git root
CLAUDE_SETTINGS="$PROJ_ROOT/.claude/settings.json"
GIT_HOOK="$GIT_ROOT/.git/hooks/pre-commit"
GIT_POST_COMMIT_HOOK="$GIT_ROOT/.git/hooks/post-commit"
HUSKY_HOOK="$PROJ_ROOT/.husky/pre-commit"
PRE_COMMIT_CONFIG="$PROJ_ROOT/.pre-commit-config.yaml"

# --- Status check ---
show_status() {
  echo ""
  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  PSK HOOKS STATUS${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"

  if [ -f "$CLAUDE_SETTINGS" ]; then
    if grep -q "psk-sync-check" "$CLAUDE_SETTINGS" 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} Claude Code hook: .claude/settings.json (PostToolUse wired)"
    else
      echo -e "  ${YELLOW}⚠${NC} Claude Code settings exist but PSK hook not wired"
    fi
  else
    echo -e "  ${RED}✗${NC} Claude Code hook: .claude/settings.json (not installed)"
  fi

  if [ -f "$GIT_HOOK" ]; then
    if grep -q "psk-sync-check" "$GIT_HOOK" 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} Git pre-commit hook: .git/hooks/pre-commit (PSK wired)"
    else
      echo -e "  ${YELLOW}⚠${NC} Git pre-commit hook exists but PSK check not wired"
    fi
  else
    echo -e "  ${RED}✗${NC} Git pre-commit hook: .git/hooks/pre-commit (not installed)"
  fi

  if [ -f "$GIT_POST_COMMIT_HOOK" ]; then
    if grep -q "psk-resume-bootstrap-marker-refresh" "$GIT_POST_COMMIT_HOOK" 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} Git post-commit hook: .git/hooks/post-commit (PSK029 marker-refresh wired)"
    else
      echo -e "  ${YELLOW}⚠${NC} Git post-commit hook exists but PSK marker-refresh not wired"
    fi
  else
    echo -e "  ${RED}✗${NC} Git post-commit hook: .git/hooks/post-commit (not installed)"
  fi

  if [ -f "$HUSKY_HOOK" ]; then
    echo -e "  ${CYAN}ℹ${NC} Husky detected: .husky/pre-commit exists"
  fi

  if [ -f "$PRE_COMMIT_CONFIG" ]; then
    echo -e "  ${CYAN}ℹ${NC} pre-commit framework detected: .pre-commit-config.yaml exists"
  fi

  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
}

if [ "$STATUS_ONLY" = true ]; then
  show_status
  exit 0
fi

# --- Install Claude Code hooks ---
install_claude_hook() {
  echo -e "${CYAN}Installing Claude Code hooks...${NC}"

  mkdir -p "$PROJ_ROOT/.claude"

  if [ -f "$CLAUDE_SETTINGS" ]; then
    if grep -q "psk-sync-check" "$CLAUDE_SETTINGS" 2>/dev/null && [ "$FORCE" = false ]; then
      echo -e "  ${YELLOW}⚠${NC} Already installed. Use --force to reinstall."
      return 0
    fi

    # Back up existing settings
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.psk-backup.$(date +%s)" 2>/dev/null || true
    echo -e "  ${CYAN}ℹ${NC} Backed up existing .claude/settings.json"
  fi

  # Write new settings (minimal, just our hook)
  cat > "$CLAUDE_SETTINGS" <<'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash agent/scripts/psk-sync-check.sh --quick"
          }
        ]
      }
    ]
  }
}
EOF

  echo -e "  ${GREEN}✓${NC} Created .claude/settings.json"
}

# --- Safe hook write helper (KIT-GAP-0013 fix, v0.6.67) ---
# Writes a hook atomically with a bash -n syntax check before committing.
# If syntax check fails, restores from .psk-backup (if any) and exits 1.
#
# Usage: safe_install_hook <dest> <tmp_content_file>
safe_install_hook() {
  local dest="$1"
  local tmp="$2"

  # Syntax check the proposed content BEFORE moving into place
  if ! bash -n "$tmp" 2>/tmp/psk-hook-syntax.err; then
    echo -e "  ${RED}✗${NC} Generated hook has syntax errors — aborting install:" >&2
    sed 's/^/    /' < /tmp/psk-hook-syntax.err >&2
    # Restore latest backup if exists
    local latest_backup
    latest_backup=$(ls -t "${dest}.psk-backup."* 2>/dev/null | head -1)
    if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
      cp "$latest_backup" "$dest" 2>/dev/null || true
      echo -e "  ${YELLOW}⚠${NC} Restored from $latest_backup" >&2
    fi
    rm -f "$tmp"
    return 1
  fi

  # Atomic move
  mv "$tmp" "$dest"
  chmod +x "$dest"
  return 0
}

# --- Install git pre-commit hook ---
install_git_hook() {
  echo -e "${CYAN}Installing git pre-commit hook...${NC}"

  local tmp
  tmp=$(mktemp)

  if [ -f "$GIT_HOOK" ]; then
    if grep -q "psk-sync-check" "$GIT_HOOK" 2>/dev/null && [ "$FORCE" = false ]; then
      echo -e "  ${YELLOW}⚠${NC} Already installed. Use --force to reinstall."
      rm -f "$tmp"
      return 0
    fi

    # Back up existing hook
    cp "$GIT_HOOK" "$GIT_HOOK.psk-backup.$(date +%s)" 2>/dev/null || true
    echo -e "  ${CYAN}ℹ${NC} Backed up existing .git/hooks/pre-commit"

    # Wrap existing hook: extract original content, drop shebang + any prior PSK marker line
    local existing_content
    existing_content=$(grep -v "^#!" "$GIT_HOOK" 2>/dev/null | grep -v "psk-sync-check")

    # KIT-GAP-0013 fix: validate existing_content before splicing. If the
    # extracted body is non-trivial but has unbalanced quotes / backticks /
    # unterminated heredocs, splicing it into our template will produce a
    # broken hook. Test the body in isolation first.
    if [ -n "$existing_content" ]; then
      local body_check
      body_check=$(mktemp)
      printf '#!/bin/bash\n%s\nexit 0\n' "$existing_content" > "$body_check"
      if ! bash -n "$body_check" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} Existing hook body has syntax issues — skipping preservation, installing PSK-only hook" >&2
        existing_content=""
      fi
      rm -f "$body_check"
    fi

    cat > "$tmp" <<EOF
#!/bin/bash
# PSK pre-commit hook (installed by psk-install-hooks.sh)
# Emergency bypass: PSK_SYNC_CHECK_DISABLED=1 git commit ...
# Or: git commit --no-verify

# KIT-GAP-0015 fix (v0.6.68): skip sync-check during merge commits.
# Big merges (100+ files) caused sync-check's internal git operations to
# fan out into hundreds of parallel sub-processes that exhausted system
# resources before completing. Merge commits don't introduce logical
# drift on their own — the constituent commits already ran the check.
REPO_ROOT="\$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "\$REPO_ROOT" ] && [ -f "\$REPO_ROOT/.git/MERGE_HEAD" ]; then
  echo "PSK pre-commit: skipping sync-check during merge commit (KIT-GAP-0015)" >&2
  exit 0
fi

SCRIPT="\$REPO_ROOT/agent/scripts/psk-sync-check.sh"
if [ -x "\$SCRIPT" ]; then
  bash "\$SCRIPT" --full || exit 1
fi

# --- Original pre-commit hook content (preserved) ---
$existing_content
exit 0
EOF
  else
    # Fresh install
    cat > "$tmp" <<'EOF'
#!/bin/bash
# PSK pre-commit hook (installed by psk-install-hooks.sh)
# Emergency bypass: PSK_SYNC_CHECK_DISABLED=1 git commit ...
# Or: git commit --no-verify

# KIT-GAP-0015 fix (v0.6.68): skip sync-check during merge commits.
# Big merges (100+ files) caused sync-check's internal git operations to
# fan out into hundreds of parallel sub-processes that exhausted system
# resources before completing. Merge commits don't introduce logical
# drift on their own — the constituent commits already ran the check.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.git/MERGE_HEAD" ]; then
  echo "PSK pre-commit: skipping sync-check during merge commit (KIT-GAP-0015)" >&2
  exit 0
fi

SCRIPT="$REPO_ROOT/agent/scripts/psk-sync-check.sh"
if [ -x "$SCRIPT" ]; then
  bash "$SCRIPT" --full || exit 1
fi
exit 0
EOF
  fi

  if safe_install_hook "$GIT_HOOK" "$tmp"; then
    echo -e "  ${GREEN}✓${NC} Created .git/hooks/pre-commit"
  else
    return 1
  fi
}

# --- Install git post-commit hook (refreshes PSK029 resume-bootstrap marker) ---
# QA-D15 fix: PSK029 re-stales after every commit. The marker is meant to
# detect "session started without resume-bootstrap", not "commit landed
# without resume-bootstrap". A post-commit hook refreshes the marker
# automatically so normal kit activity keeps PSK029 clean.
install_git_post_commit_hook() {
  echo -e "${CYAN}Installing git post-commit hook (PSK029 marker refresh)...${NC}"

  local tmp
  tmp=$(mktemp)

  if [ -f "$GIT_POST_COMMIT_HOOK" ]; then
    if grep -q "psk-resume-bootstrap-marker-refresh" "$GIT_POST_COMMIT_HOOK" 2>/dev/null && [ "$FORCE" = false ]; then
      echo -e "  ${YELLOW}⚠${NC} Already installed. Use --force to reinstall."
      rm -f "$tmp"
      return 0
    fi

    # Back up existing hook
    cp "$GIT_POST_COMMIT_HOOK" "$GIT_POST_COMMIT_HOOK.psk-backup.$(date +%s)" 2>/dev/null || true
    echo -e "  ${CYAN}ℹ${NC} Backed up existing .git/hooks/post-commit"

    # Wrap existing hook: add our marker refresh before it
    local existing_content
    existing_content=$(grep -v "^#!" "$GIT_POST_COMMIT_HOOK" 2>/dev/null | grep -v "psk-resume-bootstrap-marker-refresh")

    # KIT-GAP-0013 fix: validate existing_content syntax before splicing.
    if [ -n "$existing_content" ]; then
      local body_check
      body_check=$(mktemp)
      printf '#!/bin/bash\n%s\nexit 0\n' "$existing_content" > "$body_check"
      if ! bash -n "$body_check" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} Existing hook body has syntax issues — skipping preservation, installing PSK-only hook" >&2
        existing_content=""
      fi
      rm -f "$body_check"
    fi

    cat > "$tmp" <<EOF
#!/bin/bash
# PSK post-commit hook (installed by psk-install-hooks.sh)
# Marker: psk-resume-bootstrap-marker-refresh
# Refreshes session-audit.log marker so PSK029 stays clean on every commit.
# Emergency bypass: PSK_POST_COMMIT_DISABLED=1 git commit ...

if [ "\${PSK_POST_COMMIT_DISABLED:-0}" != "1" ]; then
  ROOT="\$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "\$ROOT" ] && [ -d "\$ROOT" ]; then
    LOG_DIR="\$ROOT/agent/.workflow-state"
    if [ -d "\$LOG_DIR" ]; then
      LOG_FILE="\$LOG_DIR/session-audit.log"
      TS=\$(date -u +%Y-%m-%dT%H:%M:%SZ)
      echo "\$TS session-start-resume-check ran (auto: post-commit hook)" >> "\$LOG_FILE"
    fi
  fi
fi

# --- Original post-commit hook content (preserved) ---
$existing_content
exit 0
EOF
  else
    # Fresh install
    cat > "$tmp" <<'EOF'
#!/bin/bash
# PSK post-commit hook (installed by psk-install-hooks.sh)
# Marker: psk-resume-bootstrap-marker-refresh
# Refreshes session-audit.log marker so PSK029 stays clean on every commit.
# Emergency bypass: PSK_POST_COMMIT_DISABLED=1 git commit ...

if [ "${PSK_POST_COMMIT_DISABLED:-0}" != "1" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$ROOT" ] && [ -d "$ROOT" ]; then
    LOG_DIR="$ROOT/agent/.workflow-state"
    if [ -d "$LOG_DIR" ]; then
      LOG_FILE="$LOG_DIR/session-audit.log"
      TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      echo "$TS session-start-resume-check ran (auto: post-commit hook)" >> "$LOG_FILE"
    fi
  fi
fi
exit 0
EOF
  fi

  if safe_install_hook "$GIT_POST_COMMIT_HOOK" "$tmp"; then
    echo -e "  ${GREEN}✓${NC} Created .git/hooks/post-commit"
  else
    return 1
  fi
}

# --- Detect Husky and advise ---
check_husky() {
  if [ -f "$HUSKY_HOOK" ]; then
    echo ""
    echo -e "${YELLOW}⚠ Husky detected at .husky/pre-commit${NC}"
    echo -e "  PSK installed a git hook at .git/hooks/pre-commit."
    echo -e "  If Husky manages your hooks, add this line to .husky/pre-commit:"
    echo ""
    echo -e "    ${CYAN}bash agent/scripts/psk-sync-check.sh --full || exit 1${NC}"
    echo ""
  fi
}

# --- Detect pre-commit framework and advise ---
check_pre_commit_framework() {
  if [ -f "$PRE_COMMIT_CONFIG" ]; then
    echo ""
    echo -e "${YELLOW}⚠ pre-commit framework detected at .pre-commit-config.yaml${NC}"
    echo -e "  PSK installed a git hook at .git/hooks/pre-commit."
    echo -e "  If pre-commit framework manages your hooks, add this to .pre-commit-config.yaml:"
    echo ""
    echo -e "    ${CYAN}- repo: local${NC}"
    echo -e "    ${CYAN}  hooks:${NC}"
    echo -e "    ${CYAN}    - id: psk-sync-check${NC}"
    echo -e "    ${CYAN}      name: psk-sync-check${NC}"
    echo -e "    ${CYAN}      entry: bash agent/scripts/psk-sync-check.sh --full${NC}"
    echo -e "    ${CYAN}      language: system${NC}"
    echo -e "    ${CYAN}      pass_filenames: false${NC}"
    echo ""
  fi
}

# --- Smoke test: run sync-check ---
smoke_test() {
  echo ""
  echo -e "${CYAN}Smoke test: running psk-sync-check.sh --quick...${NC}"
  if bash "$AGENT_DIR/scripts/psk-sync-check.sh" --quick 2>&1; then
    echo -e "  ${GREEN}✓${NC} Sync-check passes — hooks are ready"
  else
    echo -e "  ${YELLOW}⚠${NC} Sync-check reported issues (not a failure — hooks still installed)"
  fi
}

# --- Main ---
main() {
  echo ""
  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  PSK HOOKS INSTALLER${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"

  install_claude_hook
  install_git_hook
  install_git_post_commit_hook
  check_husky
  check_pre_commit_framework
  smoke_test

  echo ""
  echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✓ HOOKS INSTALLED${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  Your commits are now protected by psk-sync-check.sh."
  echo -e "  Edit notifications via PostToolUse in Claude Code."
  echo -e ""
  echo -e "  Emergency bypass: ${YELLOW}PSK_SYNC_CHECK_DISABLED=1 git commit ...${NC}"
  echo -e "  Full bypass:      ${YELLOW}git commit --no-verify${NC}"
  echo ""
}

main
