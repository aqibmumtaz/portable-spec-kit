#!/bin/bash
# =============================================================
# psk-code-review.sh — Automated Code Review (Mechanical Layer)
#
# Checks project code against Portable Spec Kit rules:
# security anti-patterns, naming conventions, TODO/FIXME,
# hardcoded secrets, directory structure, agent file integrity.
#
# The AI agent adds semantic review (architecture compliance,
# design decision match) on top of this script's output.
#
# Usage:
#   bash agent/scripts/psk-code-review.sh              # full review
#   bash agent/scripts/psk-code-review.sh --changed     # only changed files
#   bash agent/scripts/psk-code-review.sh --ci          # CI mode (exit 1 on issues)
#
# Exit codes:
#   0 = no issues found
#   1 = issues found (advisory in normal mode, failure in CI)
#   2 = configuration error
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
PROJ_ROOT="$(cd "$AGENT_DIR/.." 2>/dev/null && pwd)"

# --- Options ---
CHANGED_ONLY=false
CI_MODE=false
while [ $# -gt 0 ]; do
  case "$1" in
    --changed)  CHANGED_ONLY=true; shift ;;
    --ci)       CI_MODE=true; shift ;;
    --project)  PROJ_ROOT="$2"; AGENT_DIR="$PROJ_ROOT/agent"; shift 2 ;;
    *)          shift ;;
  esac
done

# --- Counters ---
PASS=0
ISSUES=0
TOTAL=0
ISSUE_DETAILS=""

# --- Color output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass_check() {
  PASS=$((PASS + 1))
  TOTAL=$((TOTAL + 1))
  echo -e "  ${GREEN}✓${NC} $1"
}

fail_check() {
  ISSUES=$((ISSUES + 1))
  TOTAL=$((TOTAL + 1))
  echo -e "  ${RED}✗${NC} $1"
  ISSUE_DETAILS="${ISSUE_DETAILS}\n  - $1"
}

warn_check() {
  echo -e "  ${YELLOW}~${NC} $1"
}

# --- Detect source directories (skip agent/, node_modules, .git, etc.) ---
find_source_dirs() {
  local dirs=""
  for d in "$PROJ_ROOT"/*/; do
    local base
    base=$(basename "$d")
    case "$base" in
      agent|node_modules|.git|.next|cache|logs|output|ard|docs|.portable-spec-kit) continue ;;
      *) dirs="$dirs $d" ;;
    esac
  done
  # Also check root-level source files
  echo "$dirs"
}

# --- Get file list (all or changed only) ---
get_file_list() {
  local ext="$1"
  if [ "$CHANGED_ONLY" = true ] && git -C "$PROJ_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$PROJ_ROOT" diff --name-only --diff-filter=ACMR HEAD 2>/dev/null | grep "\.$ext$" | while read -r f; do
      [ -f "$PROJ_ROOT/$f" ] && echo "$PROJ_ROOT/$f"
    done
  else
    local src_dirs
    src_dirs=$(find_source_dirs)
    for d in $src_dirs; do
      find "$d" -name "*.$ext" -type f 2>/dev/null
    done
    # Root-level source files
    find "$PROJ_ROOT" -maxdepth 1 -name "*.$ext" -type f 2>/dev/null
  fi
}

get_all_code_files() {
  for ext in js jsx ts tsx py go rs java kt swift sh rb; do
    get_file_list "$ext"
  done
}

# --- Detect stack from AGENT.md ---
detect_stack() {
  if [ -f "$AGENT_DIR/AGENT.md" ]; then
    STACK_JS=false; STACK_PY=false; STACK_GO=false; STACK_BASH=false
    grep -qi "node\|react\|next\|javascript\|typescript\|jest\|vitest" "$AGENT_DIR/AGENT.md" 2>/dev/null && STACK_JS=true
    grep -qi "python\|flask\|fastapi\|django\|pytest" "$AGENT_DIR/AGENT.md" 2>/dev/null && STACK_PY=true
    grep -qi "go\|golang" "$AGENT_DIR/AGENT.md" 2>/dev/null && STACK_GO=true
    grep -qi "bash\|shell" "$AGENT_DIR/AGENT.md" 2>/dev/null && STACK_BASH=true
  else
    # Auto-detect from files
    STACK_JS=false; STACK_PY=false; STACK_GO=false; STACK_BASH=false
    [ -f "$PROJ_ROOT/package.json" ] && STACK_JS=true
    [ -f "$PROJ_ROOT/requirements.txt" ] || [ -f "$PROJ_ROOT/pyproject.toml" ] && STACK_PY=true
    [ -f "$PROJ_ROOT/go.mod" ] && STACK_GO=true
  fi
}

# =============================================================
# CHECK 1: Security Anti-Patterns
# =============================================================
check_security() {
  echo ""
  echo "  SECURITY ANTI-PATTERNS"
  echo "  ─────────────────────────────────────────────────"

  local all_files
  all_files=$(get_all_code_files)
  [ -z "$all_files" ] && { warn_check "No code files found — security checks skipped"; return; }

  # eval() usage
  local eval_hits
  eval_hits=$(echo "$all_files" | xargs grep -ln 'eval\s*(' 2>/dev/null | grep -v 'node_modules\|test\|spec\|__pycache__' || true)
  [ -z "$eval_hits" ] \
    && pass_check "No eval() usage" \
    || fail_check "eval() found: $(echo "$eval_hits" | tr '\n' ', ' | sed 's/,$//')"

  # pickle (Python)
  if [ "$STACK_PY" = true ]; then
    local pickle_hits
    pickle_hits=$(echo "$all_files" | xargs grep -ln 'import pickle\|pickle\.load\|pickle\.loads' 2>/dev/null || true)
    [ -z "$pickle_hits" ] \
      && pass_check "No pickle usage" \
      || fail_check "pickle found: $(echo "$pickle_hits" | tr '\n' ', ' | sed 's/,$//')"
  fi

  # shell=True (Python)
  if [ "$STACK_PY" = true ]; then
    local shell_hits
    shell_hits=$(echo "$all_files" | xargs grep -ln 'shell\s*=\s*True' 2>/dev/null || true)
    [ -z "$shell_hits" ] \
      && pass_check "No shell=True in subprocess" \
      || fail_check "shell=True found: $(echo "$shell_hits" | tr '\n' ', ' | sed 's/,$//')"
  fi

  # dangerouslySetInnerHTML (React)
  if [ "$STACK_JS" = true ]; then
    local danger_hits
    danger_hits=$(echo "$all_files" | xargs grep -ln 'dangerouslySetInnerHTML' 2>/dev/null | grep -v 'test\|spec' || true)
    [ -z "$danger_hits" ] \
      && pass_check "No dangerouslySetInnerHTML without sanitization" \
      || fail_check "dangerouslySetInnerHTML found: $(echo "$danger_hits" | tr '\n' ', ' | sed 's/,$//')"
  fi

  # Native browser dialogs
  if [ "$STACK_JS" = true ]; then
    local dialog_hits
    dialog_hits=$(echo "$all_files" | xargs grep -ln '\balert\s*(\|\bconfirm\s*(\|\bprompt\s*(' 2>/dev/null | grep -v 'node_modules\|test\|spec' || true)
    [ -z "$dialog_hits" ] \
      && pass_check "No native browser dialogs (alert/confirm/prompt)" \
      || fail_check "Native browser dialogs found: $(echo "$dialog_hits" | tr '\n' ', ' | sed 's/,$//')"
  fi

  # Hardcoded secrets patterns
  local secret_hits
  secret_hits=$(echo "$all_files" | xargs grep -lnE "(api[_-]?key|api[_-]?secret|password|token)\s*=\s*['\"][a-zA-Z0-9]{16,}" 2>/dev/null | grep -v 'test\|spec\|example\|\.env' || true)
  [ -z "$secret_hits" ] \
    && pass_check "No hardcoded secrets detected" \
    || fail_check "Possible hardcoded secrets: $(echo "$secret_hits" | tr '\n' ', ' | sed 's/,$//')"
}

# =============================================================
# CHECK 2: Code Quality (TODO, console.log, commented code)
# =============================================================
check_quality() {
  echo ""
  echo "  CODE QUALITY"
  echo "  ─────────────────────────────────────────────────"

  local all_files
  all_files=$(get_all_code_files)
  [ -z "$all_files" ] && { warn_check "No code files found — quality checks skipped"; return; }

  # Filter out test files for production checks
  local prod_files
  prod_files=$(echo "$all_files" | grep -v 'test\|spec\|__test__\|_test\.' || true)

  # console.log in production (JS/TS only)
  if [ "$STACK_JS" = true ] && [ -n "$prod_files" ]; then
    local console_hits
    console_hits=$(echo "$prod_files" | xargs grep -ln 'console\.log' 2>/dev/null || true)
    [ -z "$console_hits" ] \
      && pass_check "No console.log in production code" \
      || fail_check "console.log in production: $(echo "$console_hits" | wc -l | tr -d ' ') file(s)"
  fi

  # Unresolved TODO/FIXME in source (not tests, not agent/)
  if [ -n "$prod_files" ]; then
    local todo_count
    todo_count=$(echo "$prod_files" | xargs grep -c 'TODO\|FIXME' 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
    [ "$todo_count" -eq 0 ] \
      && pass_check "No unresolved TODO/FIXME markers" \
      || fail_check "$todo_count unresolved TODO/FIXME marker(s) in source"
  fi

  # .env files committed to git
  if git -C "$PROJ_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    local env_committed
    env_committed=$(git -C "$PROJ_ROOT" ls-files '*.env' '.env' '.env.*' 2>/dev/null | wc -l | tr -d ' ')
    [ "$env_committed" -eq 0 ] \
      && pass_check "No .env files committed to git" \
      || fail_check "$env_committed .env file(s) committed — add to .gitignore"
  fi

  # .gitignore includes .env*
  if [ -f "$PROJ_ROOT/.gitignore" ]; then
    grep -q '\.env' "$PROJ_ROOT/.gitignore" 2>/dev/null \
      && pass_check ".gitignore includes .env patterns" \
      || fail_check ".gitignore missing .env* pattern"
  fi
}

# =============================================================
# CHECK 3: Directory Structure & Agent Files
# =============================================================
check_structure() {
  echo ""
  echo "  DIRECTORY STRUCTURE"
  echo "  ─────────────────────────────────────────────────"

  # Agent management files
  local agent_ok=true
  for file in AGENT.md AGENT_CONTEXT.md SPECS.md PLANS.md TASKS.md RELEASES.md; do
    [ ! -f "$AGENT_DIR/$file" ] && { fail_check "Missing agent/$file"; agent_ok=false; }
  done
  [ "$agent_ok" = true ] && pass_check "All 6 agent management files present"

  # No .sh files at agent/ root
  local root_sh
  root_sh=$(find "$AGENT_DIR" -maxdepth 1 -name "*.sh" -type f 2>/dev/null | wc -l | tr -d ' ')
  [ "$root_sh" -eq 0 ] \
    && pass_check "No .sh files at agent/ root (all in scripts/)" \
    || fail_check "$root_sh .sh file(s) at agent/ root — move to agent/scripts/"

  # agent/scripts/ exists if scripts are expected
  if [ -d "$AGENT_DIR/scripts" ]; then
    pass_check "agent/scripts/ directory exists"
  fi

  # agent/design/ exists
  if [ -d "$AGENT_DIR/design" ]; then
    pass_check "agent/design/ directory exists"
  fi
}

# =============================================================
# CHECK 4: Naming Conventions (file-level)
# =============================================================
check_naming() {
  echo ""
  echo "  NAMING CONVENTIONS"
  echo "  ─────────────────────────────────────────────────"

  local src_dirs
  src_dirs=$(find_source_dirs)
  [ -z "$src_dirs" ] && { warn_check "No source directories — naming checks skipped"; return; }

  # Python files should be snake_case
  if [ "$STACK_PY" = true ]; then
    local bad_py
    bad_py=$(find $src_dirs -name "*.py" -type f 2>/dev/null | xargs -I{} basename {} | grep '[A-Z]' | grep -v '__' || true)
    [ -z "$bad_py" ] \
      && pass_check "Python files follow snake_case naming" \
      || fail_check "Python naming violations: $(echo "$bad_py" | tr '\n' ', ' | sed 's/,$//')"
  fi

  # JS/TS non-component files should be kebab-case
  if [ "$STACK_JS" = true ]; then
    local bad_js
    bad_js=$(find $src_dirs -name "*.js" -o -name "*.ts" 2>/dev/null | xargs -I{} basename {} | grep '[A-Z]' | grep -v '\.test\.\|\.spec\.\|\.d\.ts' || true)
    # Note: React components (PascalCase .tsx/.jsx) are exempt
    if [ -n "$bad_js" ]; then
      warn_check "JS/TS files with uppercase: $(echo "$bad_js" | wc -l | tr -d ' ') (verify: components=PascalCase, utils=kebab-case)"
    else
      pass_check "JS/TS utility files follow kebab-case naming"
    fi
  fi
}

# =============================================================
# MAIN
# =============================================================
main() {
  # Verify project exists
  if [ ! -d "$PROJ_ROOT" ]; then
    echo "Error: Project root not found at $PROJ_ROOT"
    exit 2
  fi

  detect_stack

  echo ""
  echo "══════════════════════════════════════════════════════════"
  echo "  CODE REVIEW — $(basename "$PROJ_ROOT")"
  echo "══════════════════════════════════════════════════════════"

  if [ "$CHANGED_ONLY" = true ]; then
    echo "  Mode: changed files only (git diff)"
  fi

  check_security
  check_quality
  check_structure
  check_naming

  # Summary
  echo ""
  echo "  ────────────────────────────────────────────────────"
  echo -e "  SUMMARY: ${GREEN}$PASS passed${NC}, ${RED}$ISSUES issue(s)${NC}, $TOTAL total"
  echo "  ────────────────────────────────────────────────────"

  if [ "$ISSUES" -eq 0 ]; then
    echo -e "  ${GREEN}✅ CODE REVIEW PASSED${NC}"
    echo ""
    exit 0
  else
    echo -e "  ${YELLOW}⚠  $ISSUES issue(s) found — review recommended${NC}"
    echo ""
    [ "$CI_MODE" = true ] && exit 1
    exit 0  # Advisory in normal mode
  fi
}

main
