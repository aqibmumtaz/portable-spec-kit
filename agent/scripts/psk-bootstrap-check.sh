#!/usr/bin/env bash
# mechanical-script: psk-bootstrap-check.sh — kit-install verification (no AI invocation)
# =============================================================
# psk-bootstrap-check.sh — Kit Installation Integrity Gate
#
# Verifies that the portable-spec-kit was properly installed into
# the current project. Catches the "project created by non-kit-aware
# agent (Copilot/plain-Claude) that skipped install.sh" failure mode.
#
# Called by:
#   - agent/scripts/psk-release.sh       (Step 0, before init_state)
#   - reflex/lib/preconditions.sh        (Gate 0, before clean-tree check)
#   - reflex/prompts/qa-agent.md         (Dim-16 reference)
#   - tests/test-spec-kit.sh             (structural gate tests)
#
# Checks (all must pass):
#   C1. Framework file present (portable-spec-kit.md OR CLAUDE.md symlink)
#   C2. Kit config present (.portable-spec-kit/config.md)
#   C3. Kit scripts present (agent/scripts/psk-*.sh — core set)
#   C4. Kit skills cached (.portable-spec-kit/skills/ non-empty)
#   C5. Git pre-commit hook installed (.git/hooks/pre-commit executable)
#   C6. Agent pipeline files present (agent/*.md — all 9)
#   C7. Test harness present (tests/test-spec-kit.sh, tests/test-release-check.sh)
#
# Usage:
#   bash agent/scripts/psk-bootstrap-check.sh              # check + print report
#   bash agent/scripts/psk-bootstrap-check.sh --quiet      # exit codes only
#   bash agent/scripts/psk-bootstrap-check.sh --json       # machine-readable
#   bash agent/scripts/psk-bootstrap-check.sh --remediate  # auto-run install.sh if missing
#
# Exit codes:
#   0 = fully bootstrapped, reflex/prep-release safe to run
#   1 = one or more critical gaps — kit not properly installed
#   2 = kit partially installed (minor gaps, warn but allow)
# =============================================================

set -uo pipefail

# --- Locate project root ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
PROJ_ROOT="${PSK_PROJ_ROOT:-$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)}"

# --- Mode flags ---
MODE="report"  # report | quiet | json | remediate
for arg in "$@"; do
  case "$arg" in
    --quiet|-q)     MODE="quiet" ;;
    --json)         MODE="json" ;;
    --remediate|-r) MODE="remediate" ;;
    --help|-h)
      sed -n '/^# =====/,/^# =====/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
  esac
done

# --- Colors (only in report mode, only on TTY) ---
if [ "$MODE" = "report" ] && [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

# --- Collectors ---
critical_gaps=()
minor_gaps=()
passed_checks=()

note_critical() { critical_gaps+=("$1"); }
note_minor()    { minor_gaps+=("$1"); }
note_pass()     { passed_checks+=("$1"); }

# --- Kit-self detection ---
# The kit IS portable-spec-kit.md (real file, not symlink) + has install.sh +
# has reflex/ directory. When checking the kit itself, CLAUDE.md/.cursorrules
# symlinks are not required (the kit is the source, not a consumer) and
# .portable-spec-kit/config.md is not required (kit doesn't configure itself).
IS_KIT_SELF=false
if [ -f "$PROJ_ROOT/portable-spec-kit.md" ] && [ ! -L "$PROJ_ROOT/portable-spec-kit.md" ] \
   && [ -f "$PROJ_ROOT/install.sh" ] \
   && [ -d "$PROJ_ROOT/reflex" ] \
   && [ -d "$PROJ_ROOT/agent/scripts" ]; then
  IS_KIT_SELF=true
fi

# --- C1: Framework file + agent entry point ---
check_framework_file() {
  local kit_md="$PROJ_ROOT/portable-spec-kit.md"
  local entry_points=("CLAUDE.md" ".cursorrules" ".windsurfrules" ".clinerules" ".github/copilot-instructions.md")
  local has_kit_file=false
  local has_entry=false

  [ -f "$kit_md" ] && has_kit_file=true
  for ep in "${entry_points[@]}"; do
    if [ -e "$PROJ_ROOT/$ep" ]; then
      has_entry=true
      break
    fi
  done

  # On the kit itself, portable-spec-kit.md IS the canonical source — no
  # CLAUDE.md symlink needed (symlinks are installed into user projects).
  if [ "$IS_KIT_SELF" = true ]; then
    if [ "$has_kit_file" = true ]; then
      note_pass "C1 framework file present (kit self — no symlink required)"
    else
      note_critical "C1 portable-spec-kit.md missing from kit root (kit integrity failure)"
    fi
    return
  fi

  if [ "$has_kit_file" = true ] && [ "$has_entry" = true ]; then
    note_pass "C1 framework file + agent entry point"
  elif [ "$has_kit_file" = false ]; then
    note_critical "C1 portable-spec-kit.md missing at project root"
  else
    note_critical "C1 no agent entry point found (expected one of: CLAUDE.md, .cursorrules, .windsurfrules, .clinerules, .github/copilot-instructions.md)"
  fi

  # --- C1.5: Entry-point symlink target validity (closes QA-INT-F70-F1-ARB) ---
  # C1 verifies the symlink exists; C1.5 verifies it actually points to the
  # local portable-spec-kit.md. Catches: dangling symlinks, symlinks to a
  # stale fork, symlinks to /dev/null, symlinks pointing outside the project.
  # Skip on kit-self (no symlinks expected) and when no entry points exist
  # (already failed C1).
  if [ "$IS_KIT_SELF" != true ] && [ "$has_entry" = true ] && [ "$has_kit_file" = true ]; then
    # QA-D19-01: portable realpath resolver. `readlink -f` is GNU-only — BSD
    # readlink (default on macOS ≤10.12 + FreeBSD + NetBSD) silently exits 1
    # with no output. The prior `2>/dev/null || echo ""` swallowed the error,
    # making C1.5 spuriously pass on broken symlinks. Try `readlink -f` first
    # (GNU + recent macOS), fall back to `realpath`, then Python.
    _psk_realpath() {
      local _p="$1"
      [ -z "$_p" ] && return 1
      local _r
      _r="$(readlink -f "$_p" 2>/dev/null || true)"  # host-portability-exempt: fallback chain (readlink -f || realpath || pwd -P)
      if [ -n "$_r" ]; then printf '%s\n' "$_r"; return 0; fi
      if command -v realpath >/dev/null 2>&1; then
        _r="$(realpath "$_p" 2>/dev/null || true)"
        if [ -n "$_r" ]; then printf '%s\n' "$_r"; return 0; fi
      fi
      if command -v python3 >/dev/null 2>&1; then
        _r="$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$_p" 2>/dev/null || true)"
        if [ -n "$_r" ]; then printf '%s\n' "$_r"; return 0; fi
      fi
      return 1
    }
    local kit_md_abs
    kit_md_abs="$(cd "$PROJ_ROOT" && _psk_realpath portable-spec-kit.md || true)"
    if [ -z "$kit_md_abs" ]; then
      # Last-resort fallback: assume the file lives at PROJ_ROOT (e.g. kit-self
      # checkout where portable-spec-kit.md is a regular file, not a symlink).
      kit_md_abs="$(cd "$PROJ_ROOT" && pwd)/portable-spec-kit.md"
    fi
    local broken=()
    for ep in "${entry_points[@]}"; do
      local ep_path="$PROJ_ROOT/$ep"
      [ -e "$ep_path" ] || continue
      # Only check symlinks (regular file copies on Windows pass C1.5 trivially)
      [ -L "$ep_path" ] || continue
      local target_abs
      target_abs="$(_psk_realpath "$ep_path" || true)"
      if [ -z "$target_abs" ] || [ "$target_abs" != "$kit_md_abs" ]; then
        broken+=("$ep")
      fi
    done
    if [ ${#broken[@]} -eq 0 ]; then
      note_pass "C1.5 entry-point symlinks resolve to local portable-spec-kit.md"
    else
      note_critical "C1.5 broken entry-point symlink(s): ${broken[*]} — re-run install.sh to re-symlink"
    fi
  fi
}

# --- C2: Kit config file ---
check_kit_config() {
  # Kit-self does not configure itself as a user project — skip.
  if [ "$IS_KIT_SELF" = true ]; then
    note_pass "C2 kit config not required (kit self)"
    return
  fi
  local cfg="$PROJ_ROOT/.portable-spec-kit/config.md"
  if [ -f "$cfg" ]; then
    note_pass "C2 .portable-spec-kit/config.md present"
  else
    note_critical "C2 .portable-spec-kit/config.md missing (kit config never created)"
  fi
}

# --- C3: Core kit scripts ---
check_kit_scripts() {
  local core_scripts=(
    "psk-sync-check.sh"
    "psk-release.sh"
    "psk-validate.sh"
    "psk-doc-sync.sh"
    "psk-critic-spawn.sh"
    "psk-code-review.sh"
  )
  local missing=()
  for s in "${core_scripts[@]}"; do
    local path="$PROJ_ROOT/agent/scripts/$s"
    if [ ! -f "$path" ]; then
      missing+=("$s")
    elif [ ! -x "$path" ]; then
      missing+=("$s (not executable)")
    fi
  done
  if [ ${#missing[@]} -eq 0 ]; then
    note_pass "C3 core kit scripts present (${#core_scripts[@]} scripts)"
  else
    note_critical "C3 missing/non-executable kit scripts in agent/scripts/: ${missing[*]}"
  fi
}

# --- C4: Kit skills cached ---
check_kit_skills() {
  local skills_dir="$PROJ_ROOT/.portable-spec-kit/skills"
  if [ ! -d "$skills_dir" ]; then
    note_critical "C4 .portable-spec-kit/skills/ directory missing"
    return
  fi
  local count
  count=$(find "$skills_dir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -eq 0 ]; then
    note_critical "C4 .portable-spec-kit/skills/ is empty (0 cached skill files — expected ≥10)"
  elif [ "$count" -lt 10 ]; then
    note_minor "C4 .portable-spec-kit/skills/ has only $count files (expected ≥10 — may indicate stale/partial cache)"
  else
    note_pass "C4 kit skills cached ($count files)"
  fi
}

# --- C5: Git pre-commit hook ---
check_precommit_hook() {
  # Handle nested-repo case: project is a subdir of a larger git repo.
  # Find the git dir for this project (may be parent).
  local git_dir=""
  if [ -d "$PROJ_ROOT/.git" ]; then
    git_dir="$PROJ_ROOT/.git"
  elif command -v git >/dev/null 2>&1; then
    git_dir="$(cd "$PROJ_ROOT" 2>/dev/null && git rev-parse --git-dir 2>/dev/null || true)"
    # Resolve to absolute
    [ -n "$git_dir" ] && [ -d "$PROJ_ROOT/$git_dir" ] && git_dir="$PROJ_ROOT/$git_dir"
  fi
  if [ -z "$git_dir" ] || [ ! -d "$git_dir" ]; then
    note_minor "C5 not a git repository (pre-commit hook check skipped)"
    return
  fi
  # QA-D8-P7-001: honor core.hooksPath FIRST. A subtree / nested-repo install can
  # legitimately point hooks at the parent workspace's .git/hooks via core.hooksPath;
  # checking only $git_dir/hooks would false-flag hooks-missing on such installs.
  local hooks_dir
  hooks_dir="$(cd "$PROJ_ROOT" 2>/dev/null && git config core.hooksPath 2>/dev/null || true)"
  [ -z "$hooks_dir" ] && hooks_dir="$git_dir/hooks"
  local hook="$hooks_dir/pre-commit"
  if [ ! -f "$hook" ]; then
    note_critical "C5 pre-commit hook missing at $hook (sync-check will not run before commits)"
    return
  fi
  if [ ! -x "$hook" ]; then
    note_critical "C5 pre-commit hook not executable ($hook)"
    return
  fi
  if ! grep -q "psk-sync-check" "$hook" 2>/dev/null; then
    note_minor "C5 pre-commit hook present but does not reference psk-sync-check.sh"
    return
  fi
  note_pass "C5 pre-commit hook installed and wired to psk-sync-check.sh"
}

# --- C6: Agent pipeline files ---
check_pipeline_files() {
  local files=(AGENT.md AGENT_CONTEXT.md REQS.md SPECS.md PLANS.md RESEARCH.md DESIGN.md TASKS.md RELEASES.md)
  local missing=()
  for f in "${files[@]}"; do
    [ -f "$PROJ_ROOT/agent/$f" ] || missing+=("$f")
  done
  if [ ${#missing[@]} -eq 0 ]; then
    note_pass "C6 agent pipeline files present (${#files[@]} files)"
  else
    note_critical "C6 missing agent/ pipeline files: ${missing[*]}"
  fi
}

# --- C7: Test harness ---
# v0.6.27+ fix: tests/test-spec-kit.sh is the KIT'S OWN self-test suite,
# not shipped to user projects (install.sh only ships test-release-check.sh).
# Kit-self detection: presence of `examples/` AND `tests/test-spec-kit.sh`
# AND `tests/sections/` indicates we're running inside the canonical kit
# checkout, not a user project (which has portable-spec-kit.md as a real
# file too — that's NOT a reliable kit-self signal).
check_test_harness() {
  local missing=()
  [ -f "$PROJ_ROOT/tests/test-release-check.sh" ] || missing+=("tests/test-release-check.sh")
  # Kit-self mode also needs the internal self-test suite
  if [ -d "$PROJ_ROOT/examples" ] && [ -d "$PROJ_ROOT/tests/sections" ]; then
    [ -f "$PROJ_ROOT/tests/test-spec-kit.sh" ] || missing+=("tests/test-spec-kit.sh")
  fi
  if [ ${#missing[@]} -eq 0 ]; then
    note_pass "C7 test harness present"
  else
    note_critical "C7 missing test files: ${missing[*]}"
  fi
}

# --- Run all checks ---
check_framework_file
check_kit_config
check_kit_scripts
check_kit_skills
check_precommit_hook
check_pipeline_files
check_test_harness

# --- Compute verdict ---
n_crit=${#critical_gaps[@]}
n_minor=${#minor_gaps[@]}
n_pass=${#passed_checks[@]}

if [ "$n_crit" -gt 0 ]; then
  verdict="FAIL"
  exit_code=1
elif [ "$n_minor" -gt 0 ]; then
  verdict="WARN"
  exit_code=2
else
  verdict="PASS"
  exit_code=0
fi

# --- Remediation path: auto-run install.sh if available, else curl from GitHub ---
#
# Three-tier resolution:
#   Tier 1 — project-local install.sh (rare; user explicitly copied it)
#   Tier 2 — walk up 5 levels for a parent kit checkout (common dev layout)
#   Tier 3 — curl the canonical installer from GitHub (catches cold-machine
#            agents that scaffolded a project without any local kit nearby)
#
# Any tier that succeeds remediates; falls through on failure to the next.
INSTALL_URL="${PSK_INSTALL_URL:-https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/install.sh}"

remediate_attempt() {
  local installer=""

  # Tier 1 — project-local install.sh
  [ -x "$PROJ_ROOT/install.sh" ] && installer="$PROJ_ROOT/install.sh"

  # Tier 2 — walk up from CWD looking for a parent kit repo
  if [ -z "$installer" ]; then
    local d="$PROJ_ROOT"
    for _ in 1 2 3 4 5; do
      d="$(dirname "$d")"
      [ "$d" = "/" ] && break
      if [ -x "$d/install.sh" ] && [ -f "$d/portable-spec-kit.md" ]; then
        installer="$d/install.sh"
        break
      fi
    done
  fi

  if [ -n "$installer" ]; then
    echo -e "${YELLOW}→ Running local installer: $installer --yes --from $(dirname "$installer")${NC}"
    (cd "$PROJ_ROOT" && bash "$installer" --yes --from "$(dirname "$installer")") || return 1
    echo -e "${GREEN}✓ Installer completed — re-run bootstrap check to verify${NC}"
    return 0
  fi

  # Tier 3 — curl the canonical installer from GitHub
  if command -v curl >/dev/null 2>&1; then
    echo -e "${YELLOW}→ No local installer found. Fetching canonical installer:${NC}"
    echo -e "  ${CYAN}curl $INSTALL_URL${NC}"
    if [ "${PSK_BOOTSTRAP_CURL_DISABLED:-0}" = "1" ]; then
      echo -e "${YELLOW}  (PSK_BOOTSTRAP_CURL_DISABLED=1 — network install disabled)${NC}"
    else
      local tmp
      tmp="$(mktemp 2>/dev/null || mktemp -t psk-install)"
      if curl -fsSL "$INSTALL_URL" -o "$tmp" 2>/dev/null; then
        echo -e "${YELLOW}→ Running fetched installer from $tmp${NC}"
        (cd "$PROJ_ROOT" && bash "$tmp" --yes)
        local rc=$?
        rm -f "$tmp"
        if [ "$rc" -eq 0 ]; then
          echo -e "${GREEN}✓ Network installer completed — re-run bootstrap check to verify${NC}"
          return 0
        fi
        echo -e "${RED}✗ Network installer exited $rc${NC}"
      else
        echo -e "${RED}✗ Failed to download installer from $INSTALL_URL${NC}"
      fi
      rm -f "$tmp"
    fi
  else
    echo -e "${RED}✗ curl not available; cannot fall back to network install${NC}"
  fi

  echo -e "${RED}✗ Cannot auto-remediate${NC}"
  echo -e "${CYAN}  Manual install: curl -fsSL $INSTALL_URL | bash${NC}"
  return 1
}

# --- Emit report ---
case "$MODE" in
  quiet)
    exit "$exit_code"
    ;;
  json)
    printf '{"verdict":"%s","critical":%d,"minor":%d,"passed":%d,' \
      "$verdict" "$n_crit" "$n_minor" "$n_pass"
    printf '"critical_gaps":['
    if [ ${#critical_gaps[@]} -gt 0 ]; then
      for i in "${!critical_gaps[@]}"; do
        [ "$i" -gt 0 ] && printf ','
        printf '"%s"' "$(echo "${critical_gaps[$i]}" | sed 's/"/\\"/g')"
      done
    fi
    printf '],"minor_gaps":['
    if [ ${#minor_gaps[@]} -gt 0 ]; then
      for i in "${!minor_gaps[@]}"; do
        [ "$i" -gt 0 ] && printf ','
        printf '"%s"' "$(echo "${minor_gaps[$i]}" | sed 's/"/\\"/g')"
      done
    fi
    printf ']}\n'
    exit "$exit_code"
    ;;
  remediate)
    if [ "$exit_code" -eq 0 ]; then
      echo -e "${GREEN}✓ Kit bootstrap already complete${NC}"
      exit 0
    fi
    echo -e "${YELLOW}⚠ Bootstrap gaps detected — attempting auto-remediation${NC}"
    if remediate_attempt; then
      exit 0
    else
      exit 1
    fi
    ;;
  report|*)
    echo -e "${CYAN}═══ psk-bootstrap-check ═══${NC}"
    echo "Project root: $PROJ_ROOT"
    echo ""
    for p in ${passed_checks[@]+"${passed_checks[@]}"}; do
      echo -e "  ${GREEN}✓${NC} $p"
    done
    for m in ${minor_gaps[@]+"${minor_gaps[@]}"}; do
      echo -e "  ${YELLOW}⚠${NC} $m"
    done
    for c in ${critical_gaps[@]+"${critical_gaps[@]}"}; do
      echo -e "  ${RED}✗${NC} $c"
    done
    echo ""
    case "$verdict" in
      PASS)
        echo -e "${GREEN}✓ Kit bootstrap: PASS${NC} — prep-release and reflex safe to run"
        ;;
      WARN)
        echo -e "${YELLOW}⚠ Kit bootstrap: WARN${NC} — $n_minor minor gap(s), allowed but should be fixed"
        ;;
      FAIL)
        echo -e "${RED}✗ Kit bootstrap: FAIL${NC} — $n_crit critical gap(s) · kit was not properly installed"
        echo ""
        echo -e "${CYAN}Remediation:${NC}"
        echo "  # Option 1 — from a parent kit checkout:"
        echo "  bash <path-to-kit>/install.sh --yes --from <path-to-kit>"
        echo ""
        echo "  # Option 2 — one-shot network install:"
        echo "  curl -fsSL https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/install.sh | bash"
        echo ""
        echo "  # Option 3 — attempt auto-remediation:"
        echo "  bash agent/scripts/psk-bootstrap-check.sh --remediate"
        ;;
    esac
    exit "$exit_code"
    ;;
esac
