#!/bin/bash
# =============================================================
# psk-sync-check.sh — Consistency Verifier (Bash Critic)
#
# Runs deterministic checks to catch denormalized data drift:
#   1. Version consistency across files
#   2. Test count consistency
#   3. Flow doc count (kit mode)
#   4. Feature count (SPECS [x] rows)
#   5. R→F→T gate (every [x] feature has test ref)
#   5b. Per-feature acceptance criteria block (every | F{N} | row has ### F{N})
#       — advisory by default; PSK_FEATURE_CRITERIA_STRICT=1 promotes to hard fail
#   6. Script permissions (agent/scripts/*.sh executable)
#   7. Required directories exist
#   8. Current version in CHANGELOG + RELEASES
#
# Modes (auto-detected):
#   kit      — full 8 checks (kit repo itself)
#   node     — version + test + perms + dirs (user node project)
#   python   — version + test + perms + dirs (user python project)
#   go       — version + test + perms + dirs (user go project)
#   rust     — version + test + perms + dirs (user rust project)
#   generic  — version + R→F→T + perms + dirs
#   custom   — user-defined checks from .portable-spec-kit/sync-check-config.md
#
# Usage:
#   bash agent/scripts/psk-sync-check.sh              # --full default
#   bash agent/scripts/psk-sync-check.sh --quick      # fast: version + tests only
#   bash agent/scripts/psk-sync-check.sh --full       # all 8 checks
#   bash agent/scripts/psk-sync-check.sh --ci         # non-interactive, exit 1 on issues
#   bash agent/scripts/psk-sync-check.sh --mode kit   # override auto-detection
#   bash agent/scripts/psk-sync-check.sh --help       # show error codes
#
# Exit codes:
#   0 = no issues (silent on clean when --quick)
#   1 = issues found
#   2 = configuration error
#
# Emergency bypass:
#   PSK_SYNC_CHECK_DISABLED=1  → script exits 0 immediately
#
# Sensitive data: This script NEVER reads .env, credentials, secrets, or API keys.
# Excluded patterns: .env*, *.pem, *.key, credentials.*, secrets.*, .aws/, .ssh/
# =============================================================

set -uo pipefail

# --- Emergency bypass ---
if [ "${PSK_SYNC_CHECK_DISABLED:-0}" = "1" ]; then
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
PROJ_ROOT="$(cd "$AGENT_DIR/.." 2>/dev/null && pwd)"

# --- Colors (TTY only) ---
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
MODE_ARG=""
QUICK=false
FULL=true
CI_MODE=false
SHOW_HELP=false
VERIFY_REFACTOR=""
WITH_TESTS=false

while [ $# -gt 0 ]; do
  case "$1" in
    --quick)            QUICK=true; FULL=false; shift ;;
    --full)             FULL=true; QUICK=false; shift ;;
    --ci)               CI_MODE=true; shift ;;
    --with-tests)       WITH_TESTS=true; shift ;;
    --mode)             MODE_ARG="$2"; shift 2 ;;
    --help|-h)          SHOW_HELP=true; shift ;;
    --project)          PROJ_ROOT="$2"; AGENT_DIR="$PROJ_ROOT/agent"; shift 2 ;;
    --verify-refactor)  VERIFY_REFACTOR="$2"; shift 2 ;;
    *)                  shift ;;
  esac
done

# --- Refactor straggler detection (Gap 12) ---
if [ -n "$VERIFY_REFACTOR" ]; then
  echo ""
  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  REFACTOR STRAGGLER CHECK — searching for: $VERIFY_REFACTOR${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
  matches=$(cd "$PROJ_ROOT" && grep -rn --include="*.md" --include="*.sh" --include="*.html" --include="*.json" --include="*.yml" --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir=".release-state" "$VERIFY_REFACTOR" . 2>/dev/null)
  if [ -z "$matches" ]; then
    echo -e "${GREEN}  ✓ No stragglers found — refactor is complete${NC}"
    exit 0
  else
    count=$(echo "$matches" | wc -l | tr -d ' ')
    echo -e "${RED}  ✗ $count occurrence(s) of '$VERIFY_REFACTOR' remain:${NC}"
    echo "$matches" | head -30
    [ "$count" -gt 30 ] && echo -e "${YELLOW}  (... $((count - 30)) more)${NC}"
    echo ""
    echo -e "${CYAN}  Update all occurrences in one session, then re-run:${NC}"
    echo -e "${CYAN}    bash agent/scripts/psk-sync-check.sh --verify-refactor '$VERIFY_REFACTOR'${NC}"
    exit 1
  fi
fi

if [ "$SHOW_HELP" = true ]; then
  cat <<'EOF'
psk-sync-check.sh — Consistency Verifier

Error codes:
  PSK001: Version mismatch across files
  PSK002: Test count mismatch
  PSK003: Flow doc count mismatch
  PSK004: Feature count mismatch (cross-file)
  PSK004B: SPECS staleness vs TASKS (completed tasks not in SPECS)
  PSK005: R→F→T gate failure (done feature missing test ref)
  PSK006: Script not executable
  PSK007: Required directory missing
  PSK008: CHANGELOG/RELEASES — missing version OR sparse content (<3 items)
  PSK009: ARD missing section for current minor version
  PSK010: AGENT.md Stack table doesn't match package.json/requirements.txt
  PSK011: secrets detected in tracked files (API keys, private keys, tokens)
  PSK012: README "Latest Release" section missing, stale, or accumulated across versions
  PSK013: README Quick Start install list has stale counts (scripts / skills / CI templates)
  PSK014: README agent directory table row count ≠ actual agent/*.md file count
  PSK015: README flow table row count ≠ actual docs/work-flows/*.md file count
  PSK016: Executable-workflow orchestrator scripts not mentioned in their corresponding flow doc
  PSK017: Critic prompts (Step 4 / Step 9) missing omission-detection language
  PSK018: Per-feature acceptance criteria block missing for one or more `| F{N} |` rows
          in SPECS.md (advisory by default; PSK_FEATURE_CRITERIA_STRICT=1 makes hard fail)

Modes:
  --full         all 11 checks
  --quick        version + test count only (<500ms)
  --ci           non-interactive, exit 1 on any issue
  --with-tests   also run tests/test-spec-kit.sh + tests/test-spd-benchmarking.sh
                 and assert doc test count matches actual (doc-to-reality gate)
  --verify-refactor <term>   find straggler occurrences after rename

Exit codes:
  0 = clean
  1 = issues found
  2 = configuration error

Bypass: PSK_SYNC_CHECK_DISABLED=1
EOF
  exit 0
fi

# --- Sensitive data exclusion ---
SENSITIVE_PATTERNS=".env .env.* *.pem *.key credentials.* secrets.* .aws .ssh"
is_sensitive() {
  local file="$1"
  local base
  base=$(basename "$file")
  for pat in $SENSITIVE_PATTERNS; do
    case "$base" in $pat) return 0 ;; esac
  done
  case "$file" in
    */.env|*/.env.*|*/credentials.*|*/secrets.*|*/.aws/*|*/.ssh/*) return 0 ;;
  esac
  return 1
}

# --- Cross-platform helpers ---
get_mtime() {
  local file="$1"
  stat -f "%m" "$file" 2>/dev/null || stat -c "%Y" "$file" 2>/dev/null
}

# --- Counters + output ---
ISSUES=0
CHECKS_RUN=0
CHECKS_PASSED=0
ISSUE_LINES=""

emit_issue() {
  local code="$1"
  local location="$2"
  local message="$3"
  local fix="${4:-}"
  ISSUES=$((ISSUES + 1))
  local line="${RED}✗${NC} $code: $location — $message"
  [ -n "$fix" ] && line="$line
    ${CYAN}Fix:${NC} $fix"
  ISSUE_LINES="${ISSUE_LINES}
${line}"
}

emit_pass() {
  local label="$1"
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
  if [ "$QUICK" = false ]; then
    echo -e "  ${GREEN}✓${NC} $label"
  fi
}

# emit_warn — advisory (non-blocking) note. Used for class-of-bug findings
# where the kit is incrementally backfilling debt; surfaces the gap without
# failing the gate. Promote to emit_issue by setting PSK_STRICT=1 OR by passing
# the dedicated env-var named in the message.
emit_warn() {
  local label="$1"
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
  if [ "$QUICK" = false ]; then
    echo -e "  ${YELLOW}⚠${NC} $label"
  fi
}

run_check() {
  CHECKS_RUN=$((CHECKS_RUN + 1))
}

# --- Mode auto-detection ---
detect_mode() {
  if [ -n "$MODE_ARG" ]; then
    echo "$MODE_ARG"; return
  fi
  if [ -f "$PROJ_ROOT/.portable-spec-kit/sync-check-config.md" ]; then
    echo "custom"; return
  fi
  if [ -f "$PROJ_ROOT/portable-spec-kit.md" ] && [ -d "$PROJ_ROOT/ard" ]; then
    echo "kit"; return
  fi
  if [ -f "$PROJ_ROOT/package.json" ]; then
    echo "node"; return
  fi
  if [ -f "$PROJ_ROOT/pyproject.toml" ] || [ -f "$PROJ_ROOT/requirements.txt" ]; then
    echo "python"; return
  fi
  if [ -f "$PROJ_ROOT/go.mod" ]; then
    echo "go"; return
  fi
  if [ -f "$PROJ_ROOT/Cargo.toml" ]; then
    echo "rust"; return
  fi
  echo "generic"
}

MODE=$(detect_mode)

# --- CHECK 1: Version consistency ---
check_version() {
  run_check
  local v_context v_readme v_psk v_changelog v_releases
  local sources=""
  local unique_count=0
  local all_versions=""

  if [ -f "$AGENT_DIR/AGENT_CONTEXT.md" ]; then
    v_context=$(grep '^\- \*\*Version:\*\*' "$AGENT_DIR/AGENT_CONTEXT.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$v_context" ] && { sources="$sources AGENT_CONTEXT=$v_context"; all_versions="$all_versions $v_context"; }
  fi

  if [ -f "$PROJ_ROOT/README.md" ]; then
    v_readme=$(grep -oE 'version-v[0-9]+\.[0-9]+\.[0-9]+' "$PROJ_ROOT/README.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$v_readme" ] && { sources="$sources README=$v_readme"; all_versions="$all_versions $v_readme"; }
  fi

  if [ "$MODE" = "kit" ] && [ -f "$PROJ_ROOT/portable-spec-kit.md" ]; then
    v_psk=$(grep '^\*\*Version:\*\*' "$PROJ_ROOT/portable-spec-kit.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$v_psk" ] && { sources="$sources portable-spec-kit.md=$v_psk"; all_versions="$all_versions $v_psk"; }
  fi

  if [ "$FULL" = true ] && [ -f "$PROJ_ROOT/CHANGELOG.md" ]; then
    v_changelog=$(grep -m1 'Built over:' "$PROJ_ROOT/CHANGELOG.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | tail -1)
    [ -n "$v_changelog" ] && { sources="$sources CHANGELOG=$v_changelog"; all_versions="$all_versions $v_changelog"; }
  fi

  if [ "$FULL" = true ] && [ -f "$AGENT_DIR/RELEASES.md" ]; then
    v_releases=$(grep -m1 '^Kit:' "$AGENT_DIR/RELEASES.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | tail -1)
    [ -n "$v_releases" ] && { sources="$sources RELEASES=$v_releases"; all_versions="$all_versions $v_releases"; }
  fi

  unique_count=$(echo "$all_versions" | tr ' ' '\n' | grep -v '^$' | sort -u | wc -l | tr -d ' ')

  if [ "$unique_count" -le 1 ]; then
    emit_pass "Version consistent ($v_context)"
  else
    local mismatch_detail
    mismatch_detail=$(echo "$sources" | tr ' ' '\n' | grep -v '^$' | tr '\n' ' ')
    emit_issue "PSK001" "version" "mismatch across files: $mismatch_detail" "Update all files to match AGENT_CONTEXT.md version"
  fi
}

# --- CHECK 2: Test count consistency ---
check_test_count() {
  run_check
  local counts=""
  local sources=""

  if [ -f "$PROJ_ROOT/README.md" ]; then
    local readme_tests
    readme_tests=$(grep -oE 'tests-[0-9]+' "$PROJ_ROOT/README.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    [ -n "$readme_tests" ] && { counts="$counts $readme_tests"; sources="$sources README=$readme_tests"; }
  fi

  if [ "$FULL" = true ] && [ -f "$PROJ_ROOT/CHANGELOG.md" ]; then
    local ch_tests
    ch_tests=$(grep -oE 'Tests:\*\* [0-9]+' "$PROJ_ROOT/CHANGELOG.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    [ -n "$ch_tests" ] && { counts="$counts $ch_tests"; sources="$sources CHANGELOG=$ch_tests"; }
  fi

  if [ "$FULL" = true ] && [ -f "$AGENT_DIR/RELEASES.md" ]; then
    local rel_tests
    rel_tests=$(grep -oE '[0-9]+ tests passing' "$AGENT_DIR/RELEASES.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    [ -n "$rel_tests" ] && { counts="$counts $rel_tests"; sources="$sources RELEASES=$rel_tests"; }
  fi

  if [ "$FULL" = true ] && [ "$MODE" = "kit" ] && [ -f "$PROJ_ROOT/portable-spec-kit.md" ]; then
    local psk_tests
    psk_tests=$(grep -oE 'Tests:\*\* [0-9]+' "$PROJ_ROOT/portable-spec-kit.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    [ -n "$psk_tests" ] && { counts="$counts $psk_tests"; sources="$sources portable-spec-kit.md=$psk_tests"; }
  fi

  if [ -z "$counts" ]; then
    emit_pass "Test count (no references found)"
    return
  fi

  local unique
  unique=$(echo "$counts" | tr ' ' '\n' | grep -v '^$' | sort -u | wc -l | tr -d ' ')

  if [ "$unique" -le 1 ]; then
    local first_count
    first_count=$(echo "$counts" | awk '{print $1}')
    emit_pass "Test count consistent ($first_count)"
  else
    emit_issue "PSK002" "test-count" "mismatch: $sources" "Update all test count references to latest value"
    return
  fi

  # --- Doc-to-reality gate (QA-KIT-03): compare doc count to actual test run
  # Runs only under --with-tests or CI (not default --full to keep local fast).
  if [ "$WITH_TESTS" = true ] || [ "$CI_MODE" = true ]; then
    if [ -f "$PROJ_ROOT/tests/test-spec-kit.sh" ]; then
      local actual_fw actual_bench actual_total doc_total
      actual_fw=$(bash "$PROJ_ROOT/tests/test-spec-kit.sh" 2>&1 | grep -oE '[0-9]+ passed' | head -1 | grep -oE '[0-9]+')
      actual_bench=0
      if [ -f "$PROJ_ROOT/tests/test-spd-benchmarking.sh" ]; then
        actual_bench=$(bash "$PROJ_ROOT/tests/test-spd-benchmarking.sh" 2>&1 | grep -oE '[0-9]+ passed' | head -1 | grep -oE '[0-9]+')
        actual_bench=${actual_bench:-0}
      fi
      actual_total=$((${actual_fw:-0} + actual_bench))
      doc_total=$(echo "$counts" | awk '{print $1}')
      if [ "$actual_total" -ne "$doc_total" ]; then
        emit_issue "PSK002" "test-count-reality" \
          "docs=$doc_total actual=$actual_total (fw=$actual_fw + bench=$actual_bench)" \
          "Doc test count drifted from real test run. Update docs to $actual_total."
      else
        emit_pass "Test count matches actual run ($actual_total)"
      fi
    fi
  fi
}

# --- CHECK 3: Flow doc count (kit mode only) ---
check_flow_count() {
  [ "$MODE" != "kit" ] && return
  [ ! -d "$PROJ_ROOT/docs/work-flows" ] && return
  run_check

  local actual readme_mention
  actual=$(find "$PROJ_ROOT/docs/work-flows" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  readme_mention=$(grep -oE '[0-9]+ flow' "$PROJ_ROOT/README.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)

  if [ -z "$readme_mention" ]; then
    emit_pass "Flow doc count (no README mention)"
    return
  fi

  if [ "$actual" = "$readme_mention" ]; then
    emit_pass "Flow doc count ($actual)"
  else
    emit_issue "PSK003" "flow-count" "README says $readme_mention, actual is $actual" "Update README flow count to $actual"
  fi
}

# --- CHECK 4: Feature count consistency (Gap 8) ---
check_feature_count() {
  [ ! -f "$AGENT_DIR/SPECS.md" ] && return
  run_check

  local done_features
  done_features=$(grep -cE '^\| F[0-9]+ .*\[x\]' "$AGENT_DIR/SPECS.md" 2>/dev/null || echo 0)

  # Cross-check mentions in README, RELEASES, CHANGELOG
  [ "$FULL" = false ] && { emit_pass "Feature count ($done_features done features in SPECS.md)"; return; }

  local mismatches=""
  # Only check authoritative sources (summary tables, release entries) — not examples or trees
  if [ -f "$AGENT_DIR/RELEASES.md" ]; then
    # Match "69 features" in release notes context (not trees or examples)
    local rel_feat
    rel_feat=$(grep -E '^\- [0-9]+ features|^\*\*Features:\*\* [0-9]+|shipped: [0-9]+ features' "$AGENT_DIR/RELEASES.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    if [ -n "$rel_feat" ] && [ "$rel_feat" != "$done_features" ]; then
      mismatches="$mismatches RELEASES=$rel_feat"
    fi
  fi
  if [ -f "$PROJ_ROOT/CHANGELOG.md" ]; then
    # Match "69 features" in changelog context (avoid trees/examples)
    local ch_feat
    ch_feat=$(grep -E '^\*\*Features:\*\* [0-9]+|^\- [0-9]+ features' "$PROJ_ROOT/CHANGELOG.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    if [ -n "$ch_feat" ] && [ "$ch_feat" != "$done_features" ]; then
      mismatches="$mismatches CHANGELOG=$ch_feat"
    fi
  fi

  if [ -z "$mismatches" ]; then
    emit_pass "Feature count consistent ($done_features done features)"
  else
    emit_issue "PSK004" "feature-count" "SPECS=$done_features, mismatches:$mismatches" "Update feature count references to match SPECS.md [x] rows"
  fi
}

# --- CHECK 4.5: SPECS staleness vs TASKS (Gap 9) ---
check_specs_staleness() {
  [ "$FULL" = false ] && return
  [ ! -f "$AGENT_DIR/SPECS.md" ] && return
  [ ! -f "$AGENT_DIR/TASKS.md" ] && return
  run_check

  local specs_done tasks_done
  specs_done=$(grep -cE '^\| F[0-9]+ .*\[x\]' "$AGENT_DIR/SPECS.md" 2>/dev/null || echo 0)
  # Count [x] tasks in TASKS.md excluding Backlog section
  tasks_done=$(awk '/^## Backlog/{b=1} /^## [^B]/{b=0} !b && /^- \[x\]/{c++} END{print c+0}' "$AGENT_DIR/TASKS.md" 2>/dev/null)
  [ -z "$tasks_done" ] && tasks_done=0

  # Heuristic: if tasks_done >> specs_done by more than 20%, SPECS may be stale
  # But many tasks aren't features. Only fail if tasks have 2+ more than features AND specs are clearly incomplete
  if [ "$tasks_done" -gt 0 ] && [ "$specs_done" = 0 ]; then
    emit_issue "PSK004B" "specs-staleness" "TASKS has $tasks_done completed but SPECS has 0 features marked [x]" "Retroactively fill SPECS.md with features from completed tasks"
  else
    emit_pass "SPECS staleness (specs=$specs_done features, tasks=$tasks_done completed)"
  fi
}

# --- CHECK 5: R→F→T gate (v0.5.16 Opt 10 — mtime-invalidated cache) ---
#
# Layered R→F→T model (closes QA-INT-F70-F52-ARB, v0.6.11):
#
# This is the SHALLOW gate — fast, mechanical, runs on every commit.
# Verifies: every [x] feature has a test reference + the file exists +
# the test file passes when invoked. Returns binary pass/fail.
#
# The DEEP audit lives at `reflex/lib/check-rft-integrity.sh` and runs
# only during reflex passes (not on every commit). It verifies seven
# semantic conditions per feature: R→F map, criteria block, design plan,
# test ref, non-trivial test (no TODO/skip markers), file exists, TASKS.md
# mark. Returns yaml with per-feature break details.
#
# Two-source-of-truth is INTENTIONAL: every-commit checks must be fast
# (<2s); per-pass audits can be slower and stricter. The shallow gate
# keeps the pre-commit hook responsive; the deep audit catches gray-area
# breaks that escape the shallow gate. Documented here + in
# `docs/work-flows/17-reflex.md` so future maintainers don't try to
# unify them and accidentally either slow down commits or weaken audits.
check_rft_gate() {
  [ ! -f "$AGENT_DIR/SPECS.md" ] && return
  [ ! -f "$PROJ_ROOT/tests/test-release-check.sh" ] && return
  run_check

  # Cache file lives in agent/.release-state/ (already gitignored)
  local cache_dir="$AGENT_DIR/.release-state"
  local cache="$cache_dir/rft-cache.txt"

  # Cache is fresh if it exists AND no relevant file is newer.
  # Relevant files: SPECS.md, all tests/*.sh (so changes to
  # test-release-check.sh or any referenced test file invalidate).
  local cache_fresh=false
  if [ -f "$cache" ] && [ "${PSK_RFT_NO_CACHE:-0}" != "1" ]; then
    # `find ... -newer $cache` returns any file newer than cache mtime
    local newer_files
    newer_files=$(find "$AGENT_DIR/SPECS.md" "$PROJ_ROOT/tests" -type f \( -name "*.sh" -o -name "SPECS.md" \) -newer "$cache" 2>/dev/null | head -1)
    [ -z "$newer_files" ] && cache_fresh=true
  fi

  local result
  if [ "$cache_fresh" = true ]; then
    result=$(cat "$cache" 2>/dev/null)
    # Sanity: result must be 0 or 1; fall through to re-run if malformed
    if [ "$result" != "0" ] && [ "$result" != "1" ]; then
      cache_fresh=false
    fi
  fi

  if [ "$cache_fresh" = false ]; then
    mkdir -p "$cache_dir"
    if (cd "$PROJ_ROOT" && bash tests/test-release-check.sh agent/SPECS.md >/dev/null 2>&1); then
      result=0
    else
      result=1
    fi
    echo "$result" > "$cache"
  fi

  if [ "$result" = "0" ]; then
    emit_pass "R→F→T gate (all done features have test refs)"
  else
    emit_issue "PSK005" "rft-gate" "some done features missing test references" "Run: bash tests/test-release-check.sh agent/SPECS.md"
  fi
}

# --- CHECK 5b: Per-feature acceptance criteria blocks (PSK018) ---
# Pairwise check: every `| F{N} |` row in SPECS.md should have a matching
# `### F{N}` block under `## Feature Acceptance Criteria`. Closes the
# Layer-4 gap surfaced in field-test-v0.6.8/QA-TEST-INADEQUATE-F1: the old
# existence-only test passed if ANY ### F block existed even when 55/70 were
# missing. By default this check WARNS (advisory) so the kit can backfill
# debt without blocking unrelated commits. Set PSK_FEATURE_CRITERIA_STRICT=1
# (or PSK_STRICT=1) to promote to a hard fail (PSK018).
check_feature_criteria_blocks() {
  [ ! -f "$AGENT_DIR/SPECS.md" ] && return
  run_check

  local rows blocks missing
  rows=$(grep -cE '^\| F[0-9]+ ' "$AGENT_DIR/SPECS.md" 2>/dev/null | tr -d ' ')
  blocks=$(grep -cE '^### F[0-9]+' "$AGENT_DIR/SPECS.md" 2>/dev/null | tr -d ' ')
  [ -z "$rows" ] && rows=0
  [ -z "$blocks" ] && blocks=0
  missing=$((rows - blocks))

  if [ "$missing" -le 0 ]; then
    emit_pass "Feature criteria blocks (every feature has ### F{N} block: $rows/$rows)"
    return
  fi

  # Compute which feature numbers are missing blocks (first 5 for the message)
  local missing_list
  missing_list=$(awk '
    /^\| F[0-9]+ / {
      match($0, /F[0-9]+/)
      fn = substr($0, RSTART, RLENGTH)
      rows[fn] = 1
    }
    /^### F[0-9]+/ {
      match($0, /F[0-9]+/)
      fn = substr($0, RSTART, RLENGTH)
      blocks[fn] = 1
    }
    END {
      out = ""
      n = 0
      for (fn in rows) {
        if (!(fn in blocks)) {
          if (n < 5) {
            out = (out == "" ? fn : out " " fn)
            n++
          }
        }
      }
      print out
    }
  ' "$AGENT_DIR/SPECS.md")

  # v0.6.10: flipped from advisory to strict by default after kit's own backfill landed
  # (55 missing blocks closed in v0.6.10 prep-release). Opt-out: PSK_FEATURE_CRITERIA_STRICT=0
  local strict="${PSK_FEATURE_CRITERIA_STRICT:-1}"
  if [ "$strict" = "1" ]; then
    emit_issue "PSK018" "feature-criteria-blocks" \
      "$missing of $rows features lack '### F{N}' acceptance criteria block in agent/SPECS.md (first missing: ${missing_list:-N/A})" \
      "Add '### F{N} — Name' block per portable-spec-kit.md §Spec-Based Test Generation. Bypass: PSK_FEATURE_CRITERIA_STRICT=0."
  else
    emit_warn "Feature criteria blocks: $missing of $rows features missing '### F{N}' block (first: ${missing_list:-N/A}) — opt-out via PSK_FEATURE_CRITERIA_STRICT=0"
  fi
}

# --- CHECK 6: Script permissions ---
check_script_perms() {
  [ ! -d "$AGENT_DIR/scripts" ] && return
  run_check

  local bad_count=0
  local bad_list=""
  for sh in "$AGENT_DIR"/scripts/*.sh; do
    [ -f "$sh" ] || continue
    if is_sensitive "$sh"; then continue; fi
    if [ ! -x "$sh" ]; then
      bad_count=$((bad_count + 1))
      bad_list="$bad_list $(basename "$sh")"
    fi
  done

  if [ "$bad_count" -eq 0 ]; then
    emit_pass "Script permissions (all executable)"
  else
    emit_issue "PSK006" "script-perms" "$bad_count script(s) not executable:$bad_list" "chmod +x agent/scripts/*.sh"
  fi
}

# --- CHECK 7: Required directories ---
check_required_dirs() {
  run_check

  local required_base="agent agent/scripts"
  [ "$MODE" = "kit" ] && required_base="$required_base agent/design docs/work-flows"
  local missing=""
  for d in $required_base; do
    if [ ! -d "$PROJ_ROOT/$d" ]; then
      missing="$missing $d"
    fi
  done

  if [ -z "$missing" ]; then
    emit_pass "Required directories exist"
  else
    emit_issue "PSK007" "required-dirs" "missing:$missing" "mkdir -p$missing"
  fi
}

# --- CHECK 8: Current version in CHANGELOG + RELEASES + content validation (Gaps 1, 2) ---
check_current_version_docs() {
  [ "$FULL" = false ] && return
  [ ! -f "$AGENT_DIR/AGENT_CONTEXT.md" ] && return
  run_check

  local cur_ver minor_ver
  cur_ver=$(grep '^\- \*\*Version:\*\*' "$AGENT_DIR/AGENT_CONTEXT.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  [ -z "$cur_ver" ] && return
  minor_ver=$(echo "$cur_ver" | grep -oE 'v[0-9]+\.[0-9]+')

  local issues=""

  # Check CHANGELOG: version present + content non-trivial
  if [ -f "$PROJ_ROOT/CHANGELOG.md" ]; then
    if ! grep -q "$minor_ver" "$PROJ_ROOT/CHANGELOG.md" 2>/dev/null; then
      issues="$issues CHANGELOG.md(missing-version)"
    else
      # Content check: extract section for this version, verify substantial content
      local ch_lines
      ch_lines=$(awk "/^## $minor_ver /{flag=1;next} /^## v[0-9]/{flag=0} flag" "$PROJ_ROOT/CHANGELOG.md" 2>/dev/null | grep -cE '^-|^\*|^###' || echo 0)
      if [ "$ch_lines" -lt 3 ]; then
        issues="$issues CHANGELOG.md(content-sparse:$ch_lines items)"
      fi
    fi
  fi

  # Check RELEASES: version present + content non-trivial
  if [ -f "$AGENT_DIR/RELEASES.md" ]; then
    if ! grep -q "$minor_ver" "$AGENT_DIR/RELEASES.md" 2>/dev/null; then
      issues="$issues RELEASES.md(missing-version)"
    else
      # Content check: extract section for this version, verify substantial content
      local rel_lines
      # Accept either `## v0.6 ` (minor heading) or `## v0.6.N ` (per-patch heading).
      rel_lines=$(awk -v mv="$minor_ver" '
        $0 ~ "^## " mv "([. ]|$)" { flag=1; next }
        /^## v[0-9]/ { flag=0 }
        flag
      ' "$AGENT_DIR/RELEASES.md" 2>/dev/null | grep -cE '^-|^\*|^###')
      rel_lines=${rel_lines:-0}
      if [ "$rel_lines" -lt 3 ]; then
        issues="$issues RELEASES.md(content-sparse:$rel_lines items)"
      fi
    fi
  fi

  if [ -z "$issues" ]; then
    emit_pass "Current version ($minor_ver) present + content validated in CHANGELOG + RELEASES"
  else
    emit_issue "PSK008" "current-version" "$minor_ver:$issues" "Add substantive entry (3+ items/subsections) for $minor_ver"
  fi
}

# --- CHECK 9: ARD content freshness (Gap 5) ---
check_readme_content() {
  [ "$FULL" = false ] && return
  [ ! -f "$PROJ_ROOT/README.md" ] && return
  run_check

  local readme="$PROJ_ROOT/README.md"

  # Get current minor version from AGENT_CONTEXT.md
  local cur_ver minor_ver
  cur_ver=$(grep -E '^\- \*\*Version:\*\*' "$AGENT_DIR/AGENT_CONTEXT.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  [ -z "$cur_ver" ] && { emit_pass "README content (no current version found — skipped)"; return; }
  minor_ver=$(echo "$cur_ver" | grep -oE 'v[0-9]+\.[0-9]+')

  # Check 1: README must have a "## Latest Release" or "## What's New in v0.N" heading
  if ! grep -qE "^## (Latest Release|What's New in $minor_ver)" "$readme"; then
    emit_issue "PSK012" "readme-content" "README missing 'Latest Release' or 'What's New in $minor_ver' heading" "Add a '## Latest Release' section near the top referencing $minor_ver. See release-process.md skill for template."
    return
  fi

  # Check 2: the section body must reference the current minor version (not just be copied forward stale)
  # Extract section body (between the heading and next ## heading)
  local section
  section=$(awk -v minor="$minor_ver" '
    /^## (Latest Release|What'"'"'s New in v[0-9]+\.[0-9]+)/ { in_section=1; next }
    /^## / && in_section { in_section=0 }
    in_section { print }
  ' "$readme")

  if ! echo "$section" | grep -qF "$minor_ver"; then
    emit_issue "PSK012" "readme-content" "README 'Latest Release' section doesn't mention current minor $minor_ver" "Update section body to describe $minor_ver — likely stale from previous release cycle."
    return
  fi

  # Check 3: section must be substantive (not a placeholder) — at least 200 chars
  local section_len=${#section}
  if [ "$section_len" -lt 200 ]; then
    emit_issue "PSK012" "readme-content" "README 'Latest Release' section is too short ($section_len chars, expected ≥200)" "Expand with 1–2 sentence highlight paragraph. See release-process.md skill."
    return
  fi

  # Check 4: section must end with links to CHANGELOG and GitHub releases (enforces the "release details page" pattern)
  if ! echo "$section" | grep -q "CHANGELOG.md"; then
    emit_issue "PSK012" "readme-content" "README 'Latest Release' section missing link to CHANGELOG.md" "Full release notes belong in CHANGELOG — section must link to it."
    return
  fi

  # Check 5: no accumulated old 'What's New in vX' headings (enforce replace-don't-accumulate)
  local wn_count
  wn_count=$(grep -cE "^## What's New in v[0-9]+" "$readme" 2>/dev/null)
  if [ "$wn_count" -gt 1 ]; then
    emit_issue "PSK012" "readme-content" "README has $wn_count 'What's New in vX' sections — replace-don't-accumulate rule violated" "Move older 'What's New' sections to CHANGELOG.md and keep only the current release in README."
    return
  fi

  emit_pass "README 'Latest Release' references $minor_ver, substantive, links to CHANGELOG"
}

check_readme_install_list() {
  [ "$FULL" = false ] && return
  [ ! -f "$PROJ_ROOT/README.md" ] && return
  [ ! -d "$PROJ_ROOT/agent/scripts" ] && return
  run_check

  local readme="$PROJ_ROOT/README.md"

  # Extract declared counts from the "Installs:" line in Quick Start
  local installs_line
  installs_line=$(grep -E "^Installs:" "$readme" | head -1)
  [ -z "$installs_line" ] && { emit_pass "README install list (no 'Installs:' line — skipped)"; return; }

  # Parse "NN reliability scripts · NN skill files · NN stack-aware CI templates"
  local declared_scripts declared_skills declared_ci
  declared_scripts=$(echo "$installs_line" | grep -oE '[0-9]+ reliability scripts' | grep -oE '^[0-9]+')
  declared_skills=$(echo "$installs_line" | grep -oE '[0-9]+ skill files' | grep -oE '^[0-9]+')
  declared_ci=$(echo "$installs_line" | grep -oE '[0-9]+ stack-aware CI templates' | grep -oE '^[0-9]+')

  # Actual counts on disk
  # "Reliability scripts" = psk-*.sh excluding optional Jira/tracker helpers
  # (install.sh distinguishes these: `scripts` vs `optional` variables)
  local actual_scripts actual_skills actual_ci
  actual_scripts=$(ls "$PROJ_ROOT"/agent/scripts/psk-*.sh 2>/dev/null | grep -vE '(jira|tracker)' | wc -l | tr -d ' ')
  actual_skills=$(ls "$PROJ_ROOT"/.portable-spec-kit/skills/*.md 2>/dev/null | wc -l | tr -d ' ')
  actual_ci=$(ls "$PROJ_ROOT"/.portable-spec-kit/templates/ci/ci-*.yml 2>/dev/null | wc -l | tr -d ' ')

  local fails=""
  [ -n "$declared_scripts" ] && [ "$declared_scripts" != "$actual_scripts" ] && fails="${fails} scripts:${declared_scripts}→${actual_scripts}"
  [ -n "$declared_skills" ] && [ "$declared_skills" != "$actual_skills" ] && fails="${fails} skills:${declared_skills}→${actual_skills}"
  [ -n "$declared_ci" ] && [ "$declared_ci" != "$actual_ci" ] && fails="${fails} ci-templates:${declared_ci}→${actual_ci}"

  if [ -n "$fails" ]; then
    emit_issue "PSK013" "readme-install-list" "README Quick Start install list has stale counts:${fails}" "Update the 'Installs:' line in README Quick Start section to match actual file counts."
  else
    emit_pass "README install list (scripts=$actual_scripts · skills=$actual_skills · ci-templates=$actual_ci)"
  fi
}

check_readme_agent_table() {
  [ "$FULL" = false ] && return
  [ ! -f "$PROJ_ROOT/README.md" ] && return
  [ ! -d "$PROJ_ROOT/agent" ] && return
  run_check

  local readme="$PROJ_ROOT/README.md"

  # Count rows in "The Agent Directory" table (lines starting with `| Pipeline |` or `| Support |`)
  local declared_pipeline declared_support
  declared_pipeline=$(awk '/^### The Agent Directory/,/^### Project Structure/' "$readme" | grep -cE '^\| Pipeline \|' 2>/dev/null)
  declared_support=$(awk '/^### The Agent Directory/,/^### Project Structure/' "$readme" | grep -cE '^\| Support \|' 2>/dev/null)

  # Actual: .md files directly in agent/ (not agent/design/ or agent/scripts/)
  local actual_md
  actual_md=$(ls "$PROJ_ROOT"/agent/*.md 2>/dev/null | wc -l | tr -d ' ')

  local declared_total=$((declared_pipeline + declared_support))

  # If no table found (zero declared), pass — table might be in non-standard form
  if [ "$declared_total" -eq 0 ]; then
    emit_pass "README agent directory table (no table found — skipped)"
    return
  fi

  if [ "$declared_total" != "$actual_md" ]; then
    emit_issue "PSK014" "readme-agent-table" "README agent directory table has $declared_total rows (Pipeline=$declared_pipeline + Support=$declared_support) but agent/ has $actual_md .md files" "Add/remove row(s) in the README 'The Agent Directory' table to match agent/*.md on disk."
  else
    emit_pass "README agent directory table ($declared_total rows matches $actual_md agent/*.md files)"
  fi
}

check_readme_flow_table() {
  [ "$FULL" = false ] && return
  [ ! -f "$PROJ_ROOT/README.md" ] && return
  [ ! -d "$PROJ_ROOT/docs/work-flows" ] && return
  run_check

  local readme="$PROJ_ROOT/README.md"

  # Count table rows that reference docs/work-flows/NN-*.md
  local declared_rows
  declared_rows=$(grep -cE '\[.*\]\(docs/work-flows/[0-9]+-[a-z-]+\.md\)' "$readme" 2>/dev/null)

  local actual_flows
  actual_flows=$(ls "$PROJ_ROOT"/docs/work-flows/*.md 2>/dev/null | wc -l | tr -d ' ')

  # No flow table in README — skip
  if [ "$declared_rows" -eq 0 ]; then
    emit_pass "README flow table (no flow table found — skipped)"
    return
  fi

  if [ "$declared_rows" != "$actual_flows" ]; then
    emit_issue "PSK015" "readme-flow-table" "README flow table has $declared_rows rows but docs/work-flows/ has $actual_flows files" "Add/remove row(s) in the README Flows table to match docs/work-flows/*.md on disk."
  else
    emit_pass "README flow table ($declared_rows rows matches $actual_flows flow docs)"
  fi
}

check_flow_docs_content() {
  [ "$FULL" = false ] && return
  [ ! -d "$PROJ_ROOT/docs/work-flows" ] && return
  [ ! -d "$PROJ_ROOT/agent/scripts" ] && return
  run_check

  # Executable-workflow orchestrator scripts MUST be mentioned in their corresponding flow doc.
  # This catches the "new script shipped but flow doc doesn't describe it" drift pattern.
  # Format: <script>:<flow-doc>:<must-also-mention>
  local mappings=(
    "psk-release.sh:13-release-workflow.md:psk-validate.sh"
    "psk-new-setup.sh:03-new-project-setup.md:"
    "psk-existing-setup.sh:04-existing-project-setup.md:"
    "psk-init.sh:05-project-init.md:psk-reinit.sh"
    "psk-feature-complete.sh:11-spec-persistent-development.md:"
  )

  local fails=""
  for m in "${mappings[@]}"; do
    local script="${m%%:*}"
    local rest="${m#*:}"
    local flow_doc="${rest%%:*}"
    local must_also="${rest#*:}"

    # Script doesn't exist → skip this mapping (not a failure)
    [ ! -f "$PROJ_ROOT/agent/scripts/$script" ] && continue

    # Flow doc doesn't exist → skip this mapping
    [ ! -f "$PROJ_ROOT/docs/work-flows/$flow_doc" ] && continue

    if ! grep -q "$script" "$PROJ_ROOT/docs/work-flows/$flow_doc" 2>/dev/null; then
      fails="${fails} ${flow_doc}→missing $script"
    fi
    if [ -n "$must_also" ] && ! grep -q "$must_also" "$PROJ_ROOT/docs/work-flows/$flow_doc" 2>/dev/null; then
      fails="${fails} ${flow_doc}→missing $must_also"
    fi
  done

  if [ -n "$fails" ]; then
    emit_issue "PSK016" "flow-docs-content" "Flow doc(s) missing required script mentions:${fails}" "Add the script name to the corresponding flow doc. See release-process.md skill — flow docs must describe the orchestrator they workflow."
  else
    emit_pass "Flow doc content (all executable-workflow orchestrators referenced in their flow docs)"
  fi
}

check_critic_prompts_comprehensive() {
  [ "$FULL" = false ] && return
  [ ! -f "$PROJ_ROOT/agent/scripts/psk-critic-spawn.sh" ] && return
  run_check

  # Meta-check: the sub-agent critic prompts (Step 4 + Step 9) must include
  # explicit omission-detection language. This prevents future edits from
  # accidentally weakening the prompts and re-opening the drift loophole.
  local critic="$PROJ_ROOT/agent/scripts/psk-critic-spawn.sh"

  local fails=""

  # STEP_4_FLOW_DOCS must have omission detection
  if ! awk '/STEP_4_FLOW_DOCS\)/,/;;/' "$critic" | grep -qi "OMISSION DETECTION"; then
    fails="${fails} STEP_4_FLOW_DOCS→missing OMISSION DETECTION section"
  fi
  if ! awk '/STEP_4_FLOW_DOCS\)/,/;;/' "$critic" | grep -qi "cross-reference"; then
    fails="${fails} STEP_4_FLOW_DOCS→missing orchestrator cross-reference"
  fi

  # STEP_9_VALIDATION must have cross-doc feature coverage
  if ! awk '/STEP_9_VALIDATION\)/,/;;/' "$critic" | grep -qi "CROSS-DOC FEATURE COVERAGE"; then
    fails="${fails} STEP_9_VALIDATION→missing CROSS-DOC FEATURE COVERAGE"
  fi
  if ! awk '/STEP_9_VALIDATION\)/,/;;/' "$critic" | grep -qi "Orchestrator script flow doc cross-check"; then
    fails="${fails} STEP_9_VALIDATION→missing orchestrator cross-check"
  fi

  if [ -n "$fails" ]; then
    emit_issue "PSK017" "critic-prompts" "Critic prompts missing omission-detection language:${fails}" "Restore the OMISSION DETECTION + cross-reference sections in STEP_4_FLOW_DOCS / CROSS-DOC FEATURE COVERAGE in STEP_9_VALIDATION. These prompts catch drift during prepare release."
  else
    emit_pass "Critic prompts comprehensive (Step 4 + Step 9 include omission detection)"
  fi
}

check_secrets() {
  [ "$FULL" = false ] && return
  run_check

  # Require git (scan is scoped to tracked files)
  if ! (cd "$PROJ_ROOT" && git rev-parse --git-dir >/dev/null 2>&1); then
    emit_pass "Secret scan skipped (not a git repo)"
    return
  fi

  # Placeholder markers — any matching line containing these is a known-safe example
  local placeholder_re='paste-your|your-api-key|your-key-here|<your-|example\.com|example\.org|changeme|placeholder|XXXX|REDACTED|\*\*\*|dummy|test-key|fake-|sample-|MY_API_KEY|abc123|deadbeef|0123456789abcdef'

  # Combined high-signal secrets regex (alternation for single grep pass)
  local secrets_re='AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82}|gho_[A-Za-z0-9]{36}|ghs_[A-Za-z0-9]{36}|sk-ant-api[0-9]+-[a-zA-Z0-9_-]{80,}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9]+-[0-9]+-[0-9a-zA-Z]{20,}|sk_live_[0-9a-zA-Z]{24,}|rk_live_[0-9a-zA-Z]{24,}|-----BEGIN (RSA|OPENSSH|EC|DSA|PGP|ENCRYPTED) PRIVATE KEY-----|aws_secret_access_key[[:space:]]*=[[:space:]]*["'"'"']?[A-Za-z0-9/+=]{40}'

  # Named pattern count for the pass message (kept in sync with alternation above)
  local pattern_count=12

  # Single git grep call — parallelized, no per-file fork storm.
  # Exclude noisy/binary paths via pathspec magic.
  local hits
  hits=$(cd "$PROJ_ROOT" && git grep -nE "$secrets_re" -- \
    ':!*.env.example' ':!*.env.sample' ':!node_modules/**' ':!vendor/**' \
    ':!tests/fixtures/**' ':!__pycache__/**' ':!*.min.js' ':!*.lock' \
    ':!*.pdf' ':!*.png' ':!*.jpg' ':!*.jpeg' ':!*.gif' ':!*.zip' \
    ':!*.tar' ':!*.tar.gz' ':!*.tgz' ':!*.ico' ':!*.woff' ':!*.woff2' \
    ':!*.ttf' ':!*.mp3' ':!*.mp4' ':!*.mov' ':!*.svg' \
    ':!agent/scripts/psk-sync-check.sh' \
    2>/dev/null || true)

  if [ -z "$hits" ]; then
    emit_pass "No secrets detected ($pattern_count patterns scanned across tracked files)"
    return
  fi

  # Filter out lines that contain placeholder markers (examples/docs/tests)
  local real_hits
  real_hits=$(echo "$hits" | grep -vE "$placeholder_re" || true)

  if [ -z "$real_hits" ]; then
    emit_pass "No secrets detected ($pattern_count patterns scanned; matches were all placeholders)"
    return
  fi

  local found
  found=$(echo "$real_hits" | wc -l | tr -d ' ')

  emit_issue "PSK011" "secrets" "$found potential secret(s) found in tracked files" "Remove value (use env var or .env.example placeholder), rewrite history if committed, rotate the credential"
  if [ "$QUICK" = false ]; then
    # Show file:line with secret value masked (first 8 chars of matching line)
    echo "$real_hits" | awk -F: '{
      line = $0;
      # extract file (1) and line number (2); keep rest masked
      n = split(line, parts, ":");
      if (n >= 3) {
        masked = substr(parts[3], 1, 8);
        printf "    %s:%s: %s...\n", parts[1], parts[2], masked;
      }
    }' | head -20
  fi
}

check_ard_content() {
  [ "$MODE" != "kit" ] && return
  [ "$FULL" = false ] && return
  [ ! -d "$PROJ_ROOT/ard" ] && return
  [ ! -f "$AGENT_DIR/AGENT_CONTEXT.md" ] && return
  run_check

  local cur_ver minor_ver
  cur_ver=$(grep '^\- \*\*Version:\*\*' "$AGENT_DIR/AGENT_CONTEXT.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  minor_ver=$(echo "$cur_ver" | grep -oE 'v[0-9]+\.[0-9]+')
  [ -z "$minor_ver" ] && return

  local issues=""
  for f in "$PROJ_ROOT"/ard/*.html; do
    [ -f "$f" ] || continue
    # ARD must mention current minor version in body content (section headings, content)
    # Accept: "v0.5 —", "v0.5 ", "v0.5.x", "v0.5+" — any contextual mention beyond just badge
    if ! grep -qE "$minor_ver[. +—]" "$f" 2>/dev/null; then
      issues="$issues $(basename "$f")(no-$minor_ver-section)"
    fi
  done

  if [ -z "$issues" ]; then
    emit_pass "ARD content includes $minor_ver section"
  else
    emit_issue "PSK009" "ard-content" "$issues" "Add $minor_ver Version Changelog section describing features shipped"
  fi
}

# --- CHECK 10: AGENT.md Stack freshness (Gap 11) ---
check_agent_md_stack() {
  [ "$FULL" = false ] && return
  [ ! -f "$AGENT_DIR/AGENT.md" ] && return
  run_check

  # Simple check: if package.json exists, AGENT.md should mention at least one core dep
  if [ -f "$PROJ_ROOT/package.json" ]; then
    local top_deps
    top_deps=$(grep -oE '"(react|vue|next|express|fastify|svelte|angular|typescript)"' "$PROJ_ROOT/package.json" 2>/dev/null | head -3 | tr -d '"' | sort -u)
    if [ -n "$top_deps" ]; then
      local missing_deps=""
      while IFS= read -r dep; do
        [ -z "$dep" ] && continue
        if ! grep -qi "$dep" "$AGENT_DIR/AGENT.md" 2>/dev/null; then
          missing_deps="$missing_deps $dep"
        fi
      done <<< "$top_deps"
      if [ -n "$missing_deps" ]; then
        emit_issue "PSK010" "agent-md-stack" "package.json has$missing_deps but AGENT.md Stack doesn't mention them" "Update AGENT.md Stack table"
        return
      fi
    fi
  fi

  emit_pass "AGENT.md Stack table consistent with project config"
}

# --- CHECK: Reflex protected-files write-ban (N52) ---
# On reflex/dev-(cycle-NN-|standalone-)?pass-* branches, agent/AGENT.md and agent/AGENT_CONTEXT.md
# are owned by the spec-persistent pipeline — reflex findings never drive
# edits to them. Any staged change to these files on a reflex dev branch
# is blocked here. Runs only when the current branch matches the pattern;
# on main / feature branches this check is a no-op (it would be too
# aggressive to block all edits to these files everywhere).
# ───────────────────────────────────────────────────────────────────
# check_reqs_coverage (v0.6.19+, ADR-031)
# Enforces P4 — Bidirectional R→F→T (PHILOSOPHY.md). Every R-row in
# agent/REQS.md maps to ≥1 F-row in agent/SPECS.md (or has a documented
# scope-change in SPECS.md "Out of scope" section). Numeric drift between
# REQS-acceptance and SPECS-acceptance / code constants flagged.
#
# Skip silently if agent/REQS.md or agent/SPECS.md missing (kit projects
# may not have user-style REQS structure). Bypass via env:
#   PSK_REQS_COVERAGE_DISABLED=1
# ───────────────────────────────────────────────────────────────────
check_reqs_coverage() {
  if [ "${PSK_REQS_COVERAGE_DISABLED:-0}" = "1" ]; then
    return 0
  fi

  local reqs="$PROJ_ROOT/agent/REQS.md"
  local specs="$PROJ_ROOT/agent/SPECS.md"

  # Skip if either file missing — kit's own REQS may not follow this pattern
  if [ ! -f "$reqs" ] || [ ! -f "$specs" ]; then
    return 0
  fi

  # Skip if REQS.md doesn't have R{N} pattern (kit's own REQS uses prose, not R{N})
  if ! grep -qE "^#### R[0-9]+ —|^### R[0-9]+ —|^## R[0-9]+ —" "$reqs" 2>/dev/null; then
    return 0
  fi

  # Extract R-row IDs from REQS
  local r_ids
  r_ids=$(grep -oE "^#+ R[0-9]+ — " "$reqs" | grep -oE "R[0-9]+" | sort -u)
  local r_count
  r_count=$(echo "$r_ids" | wc -l | tr -d ' ')

  # Extract F-row IDs from SPECS
  local f_ids
  f_ids=$(grep -oE "^#+ F[0-9]+ — " "$specs" | grep -oE "F[0-9]+" | sort -u)
  local f_count
  f_count=$(echo "$f_ids" | wc -l | tr -d ' ')

  # For each R-row, check if it has a "Maps to: F{N}" pointing to an existing F-row
  # OR if it appears in SPECS "Out of scope" section as scope-change
  local uncovered_rs=""
  local uncovered_count=0
  for rid in $r_ids; do
    # Find the "Maps to:" line for this R-row
    local maps_to_line
    maps_to_line=$(awk -v rid="$rid" '
      /^#+ '"$rid"' — / { found=1; next }
      found && /^#+ R[0-9]+ — / { exit }
      found && /^- \*\*Maps to:\*\*/ { print; exit }
    ' "$reqs" 2>/dev/null)

    if [ -z "$maps_to_line" ]; then
      uncovered_rs="$uncovered_rs $rid(no-maps-to)"
      uncovered_count=$((uncovered_count + 1))
      continue
    fi

    # Check if it maps to "Cross-cut" without a real F-row
    if echo "$maps_to_line" | grep -qiE "Cross-cut|cluster" && ! echo "$maps_to_line" | grep -qoE "F[0-9]+"; then
      uncovered_rs="$uncovered_rs $rid(cross-cut-orphan)"
      uncovered_count=$((uncovered_count + 1))
      continue
    fi

    # Extract F-id from Maps to: line
    local f_target
    f_target=$(echo "$maps_to_line" | grep -oE "F[0-9]+" | head -1)
    if [ -z "$f_target" ]; then
      uncovered_rs="$uncovered_rs $rid(no-f-target)"
      uncovered_count=$((uncovered_count + 1))
      continue
    fi

    # Check the F-target actually exists in SPECS
    if ! echo "$f_ids" | grep -qF "$f_target"; then
      # F-target referenced but doesn't exist as a feature in SPECS
      # Check if R-row is documented in SPECS "Out of scope" section as scope-change
      if ! awk '/^## .*Out of scope/,/^## /' "$specs" 2>/dev/null | grep -qF "$rid"; then
        uncovered_rs="$uncovered_rs $rid(maps-to-missing-$f_target)"
        uncovered_count=$((uncovered_count + 1))
      fi
    fi
  done

  if [ "$uncovered_count" -eq 0 ]; then
    emit_pass "REQS coverage: all $r_count R-rows mapped to existing F-rows in SPECS (P4 Bidirectional R→F→T)"
  else
    emit_issue "PSK016" "reqs-coverage" \
      "$uncovered_count of $r_count R-rows uncovered:$uncovered_rs" \
      "Either add F-row to SPECS that owns the R-row · OR document scope-change in SPECS §Out of scope · OR fix Maps to: line. Bypass: PSK_REQS_COVERAGE_DISABLED=1"
  fi
}

check_ui_requirements_coverage() {
  if [ "${PSK_UI_REQS_COVERAGE_DISABLED:-0}" = "1" ]; then
    return 0
  fi

  local reqs="$PROJ_ROOT/agent/REQS.md"
  local specs="$PROJ_ROOT/agent/SPECS.md"

  if [ ! -f "$reqs" ] || [ ! -f "$specs" ]; then
    return 0
  fi

  if ! grep -qE "^#### R[0-9]+ —|^### R[0-9]+ —" "$reqs" 2>/dev/null; then
    return 0
  fi

  # Extract UI/UX-tagged R-rows. Match `**Category:** UI/UX` (and minor variants).
  local ui_rows
  ui_rows=$(awk '
    /^#+ R[0-9]+ — / { rid=$0; sub(/^#+ /, "", rid); sub(/ —.*/, "", rid); next }
    rid && /Category:\*\*[[:space:]]+UI\/UX|Category:\*\*[[:space:]]+UI[[:space:]]*\/[[:space:]]*UX|Category:\*\*[[:space:]]+UX\/UI/ { print rid; rid="" }
    /^#+ R[0-9]+ — / { rid=$0; sub(/^#+ /, "", rid); sub(/ —.*/, "", rid) }
  ' "$reqs" 2>/dev/null | sort -u)

  local ui_count
  ui_count=$(echo "$ui_rows" | grep -c '^R' 2>/dev/null || echo 0)

  if [ "$ui_count" = "0" ]; then
    # Project has no UI/UX-tagged rows. If REQS uses the new categorization,
    # this may itself be a finding — but we don't enforce here unless the
    # project ships UI surface. Detection deferred to psk-ui-polish-check.sh.
    return 0
  fi

  # Enforce 12-row minimum for projects that ship UI (Phase 7 mandate).
  if [ "$ui_count" -lt 12 ]; then
    emit_issue "PSK017-UI-MIN" "ui-reqs-coverage" \
      "Only $ui_count UI/UX R-rows in REQS.md (Phase 7 mandates ≥12 unless explicit no-UI confirm). Rows: $(echo "$ui_rows" | tr '\n' ' ')" \
      "Add R-rows for missing UI/UX areas (layout / components / interactions / a11y / responsive / dark-mode / motion / loading-empty-error / onboarding / brand / i18n / forms). Bypass: PSK_UI_REQS_COVERAGE_DISABLED=1 (also accepts no-UI projects after explicit user confirm)."
    return
  fi

  # Each UI R-row must map to ≥1 F-row that exists in SPECS.
  local f_ids
  f_ids=$(grep -oE "^#+ F[0-9]+ — " "$specs" | grep -oE "F[0-9]+" | sort -u)

  local uncovered=""
  local uncovered_count=0
  for rid in $ui_rows; do
    local maps_to_line
    maps_to_line=$(awk -v rid="$rid" '
      /^#+ '"$rid"' — / { found=1; next }
      found && /^#+ R[0-9]+ — / { exit }
      found && /^- \*\*Maps to:\*\*/ { print; exit }
    ' "$reqs" 2>/dev/null)

    if [ -z "$maps_to_line" ]; then
      uncovered="$uncovered $rid(no-maps-to)"
      uncovered_count=$((uncovered_count + 1))
      continue
    fi

    local f_target
    f_target=$(echo "$maps_to_line" | grep -oE "F[0-9]+" | head -1)
    if [ -z "$f_target" ]; then
      uncovered="$uncovered $rid(no-f-target)"
      uncovered_count=$((uncovered_count + 1))
      continue
    fi

    if ! echo "$f_ids" | grep -qF "$f_target"; then
      uncovered="$uncovered $rid(maps-to-missing-$f_target)"
      uncovered_count=$((uncovered_count + 1))
    fi
  done

  if [ "$uncovered_count" = "0" ]; then
    emit_pass "UI/UX REQS coverage: all $ui_count UI/UX R-rows owned by F-rows in SPECS (P8 Client-Grade Output)"
  else
    emit_issue "PSK017" "ui-reqs-coverage" \
      "$uncovered_count of $ui_count UI/UX R-rows have no F-row owner:$uncovered" \
      "Each UI/UX R-row must own a feature in SPECS that delivers it. Either add the F-row · or refactor the R-row · or move it to §Out of scope. Bypass: PSK_UI_REQS_COVERAGE_DISABLED=1"
  fi
}

# Closes QA-AUDIT-CSV-01 (v0.6.28): every reflex pass dir whose cycle has
# advanced (i.e. a later cycle exists) must have a corresponding row in
# summary.csv. Drift means the cycle-close orchestration didn't invoke
# score.sh — Dim 23.2 audit-trail-integrity flagged this when cycle-03/pass-001
# was missing from summary.csv after cycle-04 started. Kit-mode only.
#
# Heuristic for "closed enough to score":
#   - If a later cycle dir exists, every pass in earlier cycles is closed.
#   - Within the latest cycle, the latest pass may still be in-flight; all
#     prior passes in that cycle are closed (cycle advances pass-by-pass).
check_summary_csv_completeness() {
  [ "$MODE" != "kit" ] && return
  local csv="$PROJ_ROOT/reflex/history/summary.csv"
  local hist="$PROJ_ROOT/reflex/history"
  [ -f "$csv" ] || return
  [ -d "$hist" ] || return
  run_check
  local max_cycle pd cycle_num pass_num missing_passes scored_count
  max_cycle=0
  for pd in "$hist"/cycle-*; do
    [ -d "$pd" ] || continue
    cycle_num=$(basename "$pd" | sed -nE 's/^cycle-0*([0-9]+)$/\1/p')
    [ -z "$cycle_num" ] && continue
    [ "$cycle_num" -gt "$max_cycle" ] && max_cycle="$cycle_num"
  done
  missing_passes=""
  scored_count=0
  for pd in "$hist"/cycle-*/pass-*; do
    [ -d "$pd" ] || continue
    [ -f "$pd/signoff.md" ] || continue
    cycle_num=$(basename "$(dirname "$pd")" | sed -nE 's/^cycle-0*([0-9]+)$/\1/p')
    pass_num=$(basename "$pd" | sed -nE 's/^pass-0*([0-9]+)$/\1/p')
    [ -z "$cycle_num" ] || [ -z "$pass_num" ] && continue
    # Skip latest pass of latest cycle (may be in-flight)
    if [ "$cycle_num" = "$max_cycle" ]; then
      local latest_pass_in_cycle
      latest_pass_in_cycle=$(ls -1d "$hist/cycle-$(printf '%02d' "$cycle_num")/pass-"*/ 2>/dev/null | sort -V | tail -1 | xargs -I{} basename {} | sed -nE 's/^pass-0*([0-9]+)$/\1/p')
      [ "$pass_num" = "$latest_pass_in_cycle" ] && continue
    fi
    scored_count=$((scored_count + 1))
    if ! grep -qE "^${cycle_num},${pass_num}," "$csv" 2>/dev/null; then
      missing_passes="${missing_passes} cycle-${cycle_num}/pass-${pass_num}"
    fi
  done
  if [ -z "$missing_passes" ]; then
    emit_pass "summary.csv completeness ($scored_count closed pass dirs all have rows)"
  else
    emit_issue "PSK002" "summary-csv-incomplete" \
      "missing rows for:$missing_passes" \
      "Run score.sh for each missing pass: REFLEX_PASS_DIR=reflex/history/cycle-NN/pass-NNN bash reflex/lib/score.sh"
  fi
}

check_reflex_protected_files() {
  local branch staged_files offending
  branch=$(git -C "$PROJ_ROOT" symbolic-ref --short HEAD 2>/dev/null || echo "")
  if [[ ! "$branch" =~ ^reflex/dev-(cycle-[0-9]+-|standalone-)?pass- ]]; then
    return 0
  fi
  # Staged files for the current commit (pre-commit context) OR last commit's
  # diff when running --full manually on the branch.
  staged_files=$(git -C "$PROJ_ROOT" diff --cached --name-only 2>/dev/null)
  [ -z "$staged_files" ] && \
    staged_files=$(git -C "$PROJ_ROOT" diff --name-only HEAD~1..HEAD 2>/dev/null || true)
  offending=$(echo "$staged_files" | grep -xE 'agent/AGENT\.md|agent/AGENT_CONTEXT\.md' || true)
  if [ -z "$offending" ]; then
    emit_pass "Reflex protected-files (AGENT.md + AGENT_CONTEXT.md untouched on $branch)"
  else
    emit_issue "PSK011" "reflex-protected-files" "$offending" "agent/AGENT.md and agent/AGENT_CONTEXT.md are owned by the spec-persistent pipeline and cannot be modified on reflex dev branches. File the finding as Bucket D + route to human-arbitration via agent/TASKS.md instead."
  fi
}

# --- Main dispatch ---
main() {
  # Header (only in non-quick mode)
  if [ "$QUICK" = false ]; then
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  PSK SYNC CHECK — mode: $MODE${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
  fi

  if [ "$QUICK" = true ]; then
    # Quick: version + test count only
    check_version
    check_test_count
    check_reflex_protected_files
  else
    # Full: all checks (expanded v0.5.9 with content validation, v0.5.13 with secrets)
    check_version
    check_test_count
    check_flow_count
    check_feature_count
    check_specs_staleness
    check_rft_gate
    check_feature_criteria_blocks
    check_script_perms
    check_required_dirs
    check_current_version_docs
    check_ard_content
    check_agent_md_stack
    check_readme_content
    check_readme_install_list
    check_readme_agent_table
    check_readme_flow_table
    check_flow_docs_content
    check_critic_prompts_comprehensive
    check_secrets
    check_reflex_protected_files
    check_reqs_coverage
    check_ui_requirements_coverage
    check_summary_csv_completeness
  fi

  # Bypass-log surface: warn if any bypass recorded in the last 24h
  local bypass_log="$PROJ_ROOT/agent/.bypass-log"
  if [ -f "$bypass_log" ] && [ "$QUICK" = false ]; then
    local recent_bypass
    recent_bypass=$(tail -20 "$bypass_log" 2>/dev/null | awk -v cutoff="$(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" '$1 >= cutoff' | wc -l | tr -d ' ')
    if [ -n "$recent_bypass" ] && [ "$recent_bypass" -gt 0 ]; then
      echo ""
      echo -e "  ${YELLOW}⚠ $recent_bypass gate bypass(es) logged in the last 24h (agent/.bypass-log)${NC}"
    fi
  fi

  # Unpushed-commit surface: advisory warning when commits pile up locally
  # Threshold: 10 unpushed commits on current branch (configurable via PSK_UNPUSHED_WARN)
  if [ "$QUICK" = false ] && git -C "$PROJ_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    local upstream unpushed warn_threshold
    warn_threshold="${PSK_UNPUSHED_WARN:-10}"
    upstream=$(git -C "$PROJ_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo "")
    if [ -n "$upstream" ]; then
      unpushed=$(git -C "$PROJ_ROOT" rev-list --count "$upstream..HEAD" 2>/dev/null || echo "0")
      if [ "$unpushed" -ge "$warn_threshold" ]; then
        echo ""
        echo -e "  ${YELLOW}⚠ $unpushed unpushed commit(s) on $(git -C "$PROJ_ROOT" rev-parse --abbrev-ref HEAD) — consider pushing (threshold: $warn_threshold, override via PSK_UNPUSHED_WARN)${NC}"
      fi
    fi
  fi

  # Output
  if [ "$ISSUES" -eq 0 ]; then
    if [ "$QUICK" = false ]; then
      echo ""
      echo -e "  ${GREEN}✓ $CHECKS_PASSED/$CHECKS_RUN checks passed${NC}"
      echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    fi
    # Silent on clean in --quick mode (Section 21 Optimization 4)
    exit 0
  fi

  # Issues found — always output
  if [ "$QUICK" = true ]; then
    echo ""
    echo -e "${YELLOW}⚠ psk-sync-check: $ISSUES issue(s) found${NC}"
    echo -e "$ISSUE_LINES"
  else
    echo ""
    echo -e "${RED}══════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  $ISSUES ISSUE(S) FOUND ($CHECKS_PASSED/$CHECKS_RUN passed)${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════${NC}"
    echo -e "$ISSUE_LINES"
    echo ""
    echo -e "  ${YELLOW}Emergency bypass: PSK_SYNC_CHECK_DISABLED=1 git commit ...${NC}"
    echo -e "  ${YELLOW}Or: git commit --no-verify${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
  fi

  exit 1
}

main
