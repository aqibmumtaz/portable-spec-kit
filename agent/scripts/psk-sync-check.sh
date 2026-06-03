#!/bin/bash
# mechanical-script: psk-sync-check.sh — consistency rule engine (no AI invocation)
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
  # HF9 (v0.6.60): durable bypass-tamper audit trail. Failure tolerant
  # — logger errors must not block emergency bypass path.
  _bypass_log_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/psk-bypass-log.sh"
  if [ -x "$_bypass_log_script" ]; then
    bash "$_bypass_log_script" log \
      --env-var "PSK_SYNC_CHECK_DISABLED" \
      --command "psk-sync-check.sh $*" \
      --justification "${PSK_BYPASS_REASON:-not provided}" 2>/dev/null || true
  fi
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
  PSK019: Flow doc missing required sections (## Overview, ## Flow Diagram, ## Key Rules)
          — checked against all docs/work-flows/*.md except 00-template.md
  PSK023: Template fails 7-criterion Quality Bar — runs psk-template-quality.sh --all --strict
          across .portable-spec-kit/templates/. Criteria: 1=stack-agnostic, 2=domain-agnostic,
          3=scale-agnostic, 4=useful-and-complete, 5=lifecycle-aware, 6=self-documenting,
          7=round-trippable. See portable-spec-kit.md §Template Quality Bar.
  PSK024: Executable-plan schema conformance — every plan in agent/plans/ that is detected
          executable (frontmatter phases: OR ## Implementation Order OR ## Phase headings OR
          slug in .workflow-state/run-plan-*.state) MUST conform to the §Plan Execution
          Protocol schema. Sub-codes:
            V=schema_version field present (integer)
            P=phases array present + non-empty
            I=phase id present + unique + kebab/alphanumeric
            N=phase name present
            R=phase prompt path under agent/plans/<slug>/prompts/<id>.md
            A=phase artifact path under agent/plans/<slug>/artifacts/<id>.done.md
            G=phase gate command present
            C=phase commit_required boolean present
            D=depends_on references exist + no cycles
            M=prompt file actually exists on disk (warn in --quick, error in --full)
            X=compat-mode plan advisory (conversion required on next start)
          Bypass: PSK_PLAN_EXEC_DISABLED=1
  PSK026: Critic-result.md synthesis-detection (v0.6.60+ HF6). Counterpart
          to HF5's check-audit-completeness.sh probe applied to release-
          ceremony / feature-complete / init / reinit / new-setup /
          existing-setup workflow critic-result.md files. Three signatures:
          (a) missing QUOTE: evidence pairs for CURRENT: entries (WARNING),
          (b) impossibly-fast mtime diff vs parent commit <10s (ERROR), and
          (c) zero path overlap with critic-task.md (ERROR). Fires --full
          mode only; recursion-guarded against tests/sections/ and /tmp/.
          Bypass: PSK_PSK026_DISABLED=1
  PSK028: Cascade-as-user-update anti-pattern detection (v0.6.60+). The canonical
          user-project update path is `psk-orchestrate.sh build` (v0.6.62+ — one
          command for new + existing; `--update` was removed). Cascade
          wording is reserved for kit-internal version-anchor sync
          (psk-version-cascade.sh) and reflex Dev-Agent auto-closure
          (cascade-check). Other "cascade kit into project" wording in kit's
          normative surfaces (portable-spec-kit.md, docs/work-flows/, reflex/lib/,
          reflex/prompts/, reflex/config.yml, agent/scripts/) is flagged.
          Bypass: PSK_PSK028_DISABLED=1
  PSK029: Resume-on-session-start audit (v0.6.60+ HF4). When a project has
          AWAITING:* phases in agent/.workflow-state/*.state and commits
          landed without a matching session-start-resume-check ran marker
          in agent/.workflow-state/session-audit.log → flagged. Forces
          agents to run psk-resume-bootstrap.sh at session start so paused
          sub-agent work resumes durably across context-compact / session-end.
          Severity: ADVISORY in --quick, ERROR in --full.
          Recursion guard: only fires when *.state files have STARTED= newer
          than the last commit touching .workflow-state/.
          Bypass: PSK_RESUME_BOOTSTRAP_DISABLED=1
  PSK030: Script class declaration audit (v0.6.60+ HF11 cycle-19 — §Spawn
          Fidelity Dim 28 Probe 4). Every agent/scripts/psk-*.sh MUST declare
          its class in the header lines 1-5: mechanical-script (no AI
          invocation), workflow-router (routes spawns through psk-spawn.sh /
          psk-critic-spawn.sh), or ai-invoker (direct AI invocation).
          Alternative: script contains `psk-spawn.sh request` (implicit
          workflow-router). Closes the discovery-surface contract Probe 4
          relies on — without this gate, future PRs can land undeclared
          psk-* scripts that bypass §Spawn Fidelity audit.
          Bypass: PSK_PSK030_DISABLED=1
  PSK031: Findings-registry de-dup audit (v0.6.61+ P3 — §Spawn Fidelity
          audit-trail integrity). The kit ships a cross-pass canonical-ID
          registry at reflex/history/findings-registry.yaml. PSK031 scans
          recent reflex/history/cycle-*/pass-*/findings.yaml files for two
          regressions:
            (a) duplicate fingerprints assigned different canonical IDs
                across passes (the cycle-17 → cycle-20 -RESIDUAL/-WIDENED
                pattern that motivated the registry)
            (b) findings whose ID is a suffix-variant (-RESIDUAL-*,
                -WIDENED-*, -CYC<N>) of an existing registered canonical_id
                but not registered as that canonical's alias
          Severity: MAJOR (overlapping findings = audit-trail integrity gap).
          Bypass: PSK_PSK031_DISABLED=1
  PSK032: Cycle-numbering misuse (v0.6.61+ — kit's reflex cycle-tracking
          was bypassed). Contract: 1 cycle = 1 autoloop run with multiple
          passes (pass-001, pass-002, ...). When 3+ of the last 5 cycle-NN
          dirs in reflex/history/ contain ONLY pass-001 (with verdict.md
          present, i.e. not in-flight), it signals that the kit's
          find_next_pass_dir / .active-cycle state machine was bypassed —
          each reflex invocation created a new cycle-NN instead of
          incrementing pass-NNN within an active cycle.
          Severity: WARNING in --quick, ERROR in --full.
          Bypass: PSK_PSK032_DISABLED=1
  PSK033: Standalone-pass overuse (v0.6.61+ P2 — operator is mis-using
          single-pass mode). Contract: standalone/ is for ad-hoc / one-shot
          audits, not convergence. Repeated standalone invocations
          fragment the audit trail across flat passes instead of grouping
          them under cycle-NN. When reflex/history/standalone/ contains
          more than the configured threshold (default 10) of pass-* dirs,
          PSK033 surfaces as ADVISORY suggesting the operator switch to
          autoloop for convergence work. ADVISORY only — never blocks.
          Bypass: PSK_PSK033_DISABLED=1
  PSK034: Workflow-declaration linkage (v0.6.62+ — §Workflow Declaration
          Schema enforcement, previously documented but unimplemented). Every
          script carrying a `# workflow-router:` header MUST have a matching
          .portable-spec-kit/workflows/<name>/phases.yml (name from psk-<name>.sh)
          UNLESS it declares `# workflow-decl-exempt: <reason>` (dispatcher /
          plan-driver / session-helper / gate-helper). ERROR in --full.
          Bypass: PSK_PSK034_DISABLED=1
  PSK035: Workflow phases.yml schema validation (v0.6.62+ — §Workflow
          Declaration Schema). Every .portable-spec-kit/workflows/*/phases.yml
          MUST declare the required top-level fields schema_version, workflow,
          and phases. ERROR in --full. Bypass: PSK_PSK035_DISABLED=1

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
    # M4 (Loop-3) QA-KIT-PSK001-PARSER-01 — scope grep to the most-recent
    # `## v<x.y>` block only. Same pattern as PSK002 (Loop-2 H2 fix).
    # Previously `grep -m1 'Built over:'` could pick a "Built over:" line
    # from anywhere in the file; if the topmost block had no Built-over
    # line but an older block did, PSK001 used the older version and
    # fired a spurious mismatch. Now we extract the last v-version on the
    # first Built-over line within the topmost ## v block.
    v_changelog=$(awk '
      /^## v[0-9]+\.[0-9]+/ {
        if (in_block) exit
        in_block = 1
        next
      }
      in_block && /Built over:/ {
        s = $0
        while (match(s, /v[0-9]+\.[0-9]+\.[0-9]+/)) {
          last = substr(s, RSTART, RLENGTH)
          s = substr(s, RSTART + RLENGTH)
        }
        if (last) { print last; exit }
      }
    ' "$PROJ_ROOT/CHANGELOG.md" 2>/dev/null)
    [ -n "$v_changelog" ] && { sources="$sources CHANGELOG=$v_changelog"; all_versions="$all_versions $v_changelog"; }
  fi

  if [ "$FULL" = true ] && [ -f "$AGENT_DIR/RELEASES.md" ]; then
    # M4 (Loop-3) QA-KIT-PSK001-PARSER-01 — scope grep to the most-recent
    # `## v<x.y>` block only. Same pattern as PSK002 (Loop-2 H2 fix).
    v_releases=$(awk '
      /^## v[0-9]+\.[0-9]+/ {
        if (in_block) exit
        in_block = 1
        next
      }
      in_block && /^Kit:/ {
        s = $0
        while (match(s, /v[0-9]+\.[0-9]+\.[0-9]+/)) {
          last = substr(s, RSTART, RLENGTH)
          s = substr(s, RSTART + RLENGTH)
        }
        if (last) { print last; exit }
      }
    ' "$AGENT_DIR/RELEASES.md" 2>/dev/null)
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
    # QA-KIT-PSK002-CROSSVER-01 (searchsocialtruth-cycle-05): scope grep to
    # the topmost `## v<x.y>` block only. Previously ranged across all
    # version sections — when the most-recent block lacked Tests:** but an
    # older block had it, the grep returned an old number and PSK002 fired
    # spuriously. Now extract only between the first `## v` heading and
    # the next one (or EOF).
    ch_tests=$(awk '
      /^## v[0-9]+\.[0-9]+/ {
        if (in_block) exit
        in_block = 1
        next
      }
      in_block && match($0, /Tests:\*\*[[:space:]]+[0-9]+/) {
        s = substr($0, RSTART, RLENGTH)
        gsub(/[^0-9]/, "", s)
        print s
        exit
      }
    ' "$PROJ_ROOT/CHANGELOG.md" 2>/dev/null)
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
  # Exclude 00-template.md — infrastructure file, not a user-facing workflow doc
  actual=$(find "$PROJ_ROOT/docs/work-flows" -maxdepth 1 -name "*.md" -type f 2>/dev/null | grep -v '/00-template\.md$' | wc -l | tr -d ' ')
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
  # QA-D6-04: regex must include dot-suffix sub-features (F85.1, F85.2) so this
  # helper agrees with check-rft-integrity.sh and check_specs_staleness().
  done_features=$(grep -cE '^\| F[0-9]+(\.[0-9]+)* .*\[x\]' "$AGENT_DIR/SPECS.md" 2>/dev/null || echo 0)

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
  # QA-D6-04: dot-suffix sub-features (F85.1, F85.2) included to match rft-integrity.
  specs_done=$(grep -cE '^\| F[0-9]+(\.[0-9]+)* .*\[x\]' "$AGENT_DIR/SPECS.md" 2>/dev/null || echo 0)
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
  # KIT-GAP-0051 (v0.6.71): recursion guard. PSK005 invokes
  # tests/test-release-check.sh, which iterates SPECS.md feature
  # Tests refs, which (via 97-kit-fidelity.sh F-row) invokes
  # psk-sync-check.sh --full. Without this guard the cycle is
  # infinite — observed 2.6K+ procs + 8h gates.sh hang. The sentinel
  # is exported by tests/test-release-check.sh and inherited by every
  # descendant sync-check.
  if [ "${PSK_IN_TEST_RELEASE_CHECK:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK005: R→F→T gate skipped (already inside test-release-check.sh)"
    return
  fi
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
  # QA-D6-04: rows + criterion blocks both include dot-suffix sub-features.
  rows=$(grep -cE '^\| F[0-9]+(\.[0-9]+)* ' "$AGENT_DIR/SPECS.md" 2>/dev/null | tr -d ' ')
  blocks=$(grep -cE '^### F[0-9]+(\.[0-9]+)*' "$AGENT_DIR/SPECS.md" 2>/dev/null | tr -d ' ')
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
    # QA-D6-04: capture dot-suffix sub-features (F85.1) as their own keys
    # so rows + blocks indexes agree on dotted features.
    /^\| F[0-9]+(\.[0-9]+)* / {
      match($0, /F[0-9]+(\.[0-9]+)*/)
      fn = substr($0, RSTART, RLENGTH)
      rows[fn] = 1
    }
    /^### F[0-9]+(\.[0-9]+)*/ {
      match($0, /F[0-9]+(\.[0-9]+)*/)
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

# --- CHECK 6b: Required scripts present (PSK006b) ---
# Closes QA-C11P001-SYNCCHECK-MISSING-PLANSAVE-05: enumerate the kit-required
# scripts so install drift surfaces immediately. Kept narrow — only scripts
# whose absence would silently break a kit workflow (release, init, validate,
# plan-save lifecycle, etc.). Stack-specific or optional helpers (jira /
# tracker) are intentionally excluded.
check_required_scripts() {
  [ ! -d "$AGENT_DIR/scripts" ] && return
  run_check

  local required="psk-sync-check.sh psk-install-hooks.sh psk-release.sh psk-validate.sh psk-critic-spawn.sh psk-init.sh psk-reinit.sh psk-new-setup.sh psk-existing-setup.sh psk-bootstrap-check.sh psk-doc-sync.sh psk-plan-save.sh psk-env.sh"
  local missing=""
  for s in $required; do
    if [ ! -f "$AGENT_DIR/scripts/$s" ]; then
      missing="$missing $s"
    fi
  done

  if [ -z "$missing" ]; then
    emit_pass "Required scripts present (12 core + psk-plan-save.sh)"
  else
    emit_issue "PSK006b" "required-scripts" \
      "missing required script(s):$missing" \
      "Re-run install.sh from kit checkout to restore. Each listed script is part of the canonical install set."
  fi
}

# --- CHECK 7: Required directories ---
check_required_dirs() {
  run_check

  local required_base="agent agent/scripts"
  [ "$MODE" = "kit" ] && required_base="$required_base agent/design docs/work-flows tests/features tests/shared"
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

  # PSK015-CONFIG: .portable-spec-kit/config.md must exist (auto-created by install.sh)
  if [ ! -f "$PROJ_ROOT/.portable-spec-kit/config.md" ]; then
    emit_issue "PSK015-CONFIG" "required-config" \
      ".portable-spec-kit/config.md missing" \
      "run install.sh (creates config.md with defaults) or create manually from config-details.md template"
  fi
}

# --- CHECK PSK016: Stub path cross-reference — no bare tests/f{n} paths in framework ---
check_stub_paths() {
  [ "$MODE" != "kit" ] && return
  run_check

  local framework="$PROJ_ROOT/portable-spec-kit.md"
  [ ! -f "$framework" ] && return

  # Look for test stub path patterns that lack tests/features/ prefix
  # Match tests/f{n} or tests/test_f{n} but NOT tests/features/...
  local bad_lines
  bad_lines=$(grep -n 'tests/f{n}\|tests/f{N}\|tests/test_f{n}\|tests/test-f{n}' "$framework" 2>/dev/null \
    | grep -v 'tests/features/' | grep -v '^[[:space:]]*#' | head -5)

  if [ -z "$bad_lines" ]; then
    emit_pass "PSK016: all test stub paths in portable-spec-kit.md use tests/features/ prefix"
  else
    emit_issue "PSK016" "stub-paths" \
      "portable-spec-kit.md has bare stub paths missing tests/features/ prefix" \
      "Change tests/f{n} → tests/features/f{n} in: $(echo "$bad_lines" | awk -F: '{print $1}' | paste -sd, -)"
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

check_installer_manifest() {
  # PSK036 — install.sh is manifest-driven (QA-KIT-INSTALLER-01). The committed
  # manifests must equal disk reality, or a network install silently omits scripts.
  [ "$FULL" = false ] && return
  [ ! -f "$PROJ_ROOT/install.sh" ] && return  # only kit-self has install.sh
  run_check

  local fails=""

  # agent/scripts/.manifest must enumerate exactly the on-disk psk-*.sh set.
  local sm="$PROJ_ROOT/agent/scripts/.manifest"
  if [ -f "$sm" ]; then
    local disk_scripts manifest_scripts diff_scripts
    disk_scripts=$(find "$PROJ_ROOT/agent/scripts" -maxdepth 1 -name 'psk-*.sh' -type f -print0 2>/dev/null | xargs -0 -n1 basename 2>/dev/null | sort -u)
    manifest_scripts=$(grep -vE '^#' "$sm" 2>/dev/null | awk '{print $1}' | grep -E '^psk-.*\.sh$' | sort -u)
    diff_scripts=$(comm -3 <(echo "$disk_scripts") <(echo "$manifest_scripts") | tr -d '\t' | grep -v '^$' | tr '\n' ' ')
    [ -n "$diff_scripts" ] && fails="${fails} scripts-manifest-drift:[${diff_scripts% }]"
  else
    fails="${fails} scripts-manifest-missing"
  fi

  # reflex/lib/.manifest must enumerate exactly the on-disk reflex/lib helper set.
  local lm="$PROJ_ROOT/reflex/lib/.manifest"
  if [ -d "$PROJ_ROOT/reflex/lib" ]; then
    if [ -f "$lm" ]; then
      local disk_lib manifest_lib diff_lib
      disk_lib=$(find "$PROJ_ROOT/reflex/lib" -maxdepth 1 -type f \
        \( -name '*.sh' -o -name '*.ts' -o -name '*.js' -o -name '*.mjs' -o -name '*.py' \) -print0 \
        | xargs -0 -n1 basename 2>/dev/null | sort -u)
      manifest_lib=$(grep -vE '^#' "$lm" 2>/dev/null | awk '{print $1}' | grep -v '^$' | sort -u)
      diff_lib=$(comm -3 <(echo "$disk_lib") <(echo "$manifest_lib") | tr -d '\t' | grep -v '^$' | tr '\n' ' ')
      [ -n "$diff_lib" ] && fails="${fails} lib-manifest-drift:[${diff_lib% }]"
    else
      fails="${fails} lib-manifest-missing"
    fi
  fi

  if [ -n "$fails" ]; then
    emit_issue "PSK036" "installer-manifest-drift" "install.sh manifest drifted from disk:${fails}" "Run: bash agent/scripts/psk-gen-manifest.sh to regenerate the committed manifests."
  else
    emit_pass "Installer manifests current (agent/scripts/.manifest + reflex/lib/.manifest match disk)"
  fi
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
  # Exclude 00-template.md — it is infrastructure, not a user-facing workflow doc
  actual_flows=$(ls "$PROJ_ROOT"/docs/work-flows/*.md 2>/dev/null | grep -v '/00-template\.md$' | wc -l | tr -d ' ')

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

check_flow_doc_template() {
  [ "$FULL" = false ] && return
  [ ! -d "$PROJ_ROOT/docs/work-flows" ] && return
  run_check
  local fails=""
  local required_sections=("## Overview" "## Flow Diagram" "## Key Rules")
  while IFS= read -r -d '' doc; do
    local basename
    basename=$(basename "$doc")
    [ "$basename" = "00-template.md" ] && continue
    for section in "${required_sections[@]}"; do
      if ! grep -qF "$section" "$doc"; then
        fails="${fails}\n  $basename: missing '$section'"
      fi
    done
  done < <(find "$PROJ_ROOT/docs/work-flows" -maxdepth 1 -name "*.md" -print0 | sort -z)
  if [ -z "$fails" ]; then
    emit_pass "PSK019: all flow docs have required sections (Overview, Flow Diagram, Key Rules)"
  else
    emit_issue "PSK019" "flow-doc-template" \
      "Flow doc(s) missing required template sections:${fails}" \
      "Add ## Overview (table), ## Flow Diagram (ASCII boxed), and ## Key Rules (bullet list) to each flagged doc. See docs/work-flows/00-template.md for the canonical template."
  fi
}

check_template_choice() {
  # PSK022a — verify physical layout matches Stack-derived template choice
  [ "$FULL" = false ] && return
  [ ! -f "$PROJ_ROOT/agent/PLANS.md" ] && return
  run_check

  local plans="$PROJ_ROOT/agent/PLANS.md"
  local has_src=0 has_frontend=0 has_backend=0 has_packages=0 has_bin=0
  [ -d "$PROJ_ROOT/src" ] && has_src=1
  [ -d "$PROJ_ROOT/frontend" ] && has_frontend=1
  [ -d "$PROJ_ROOT/backend" ] && has_backend=1
  [ -d "$PROJ_ROOT/packages" ] && has_packages=1
  [ -d "$PROJ_ROOT/bin" ] && has_bin=1

  # Skip when no app-shape layout exists (kit-self, docs-only, library)
  if [ "$has_src" -eq 0 ] && [ "$has_frontend" -eq 0 ] && [ "$has_packages" -eq 0 ] && [ "$has_bin" -eq 0 ]; then
    emit_pass "PSK022a: template choice (no app-shape layout — kit/library/docs project)"
    return
  fi

  # Polyglot heuristic — ≥2 runtime declarations in Stack table.
  # Word boundaries (\b) on every keyword to prevent false matches inside
  # other words (e.g. "Gin" inside "messaGINg" / "enGINe", "Echo" inside
  # "etched", "Go" inside other identifiers). Library names (Drizzle,
  # Twilio, Upstash, NextAuth) are intentionally NOT runtimes — they
  # are services consumed by a single host runtime.
  local runtime_count=0
  grep -qi -E '\b(Python|FastAPI|Django|Flask)\b' "$plans" && runtime_count=$((runtime_count + 1))
  grep -qi -E '\b(Node|Express)\b|Next\.js|\bTypeScript\b' "$plans" && runtime_count=$((runtime_count + 1))
  grep -qi -E '\b(Go|Gin|Echo)\b' "$plans" && runtime_count=$((runtime_count + 1))
  grep -qi -E '\b(Rust|Cargo|Axum)\b' "$plans" && runtime_count=$((runtime_count + 1))
  grep -qi -E '\b(Ruby|Rails)\b' "$plans" && runtime_count=$((runtime_count + 1))

  if [ "$runtime_count" -ge 2 ] && [ "$has_frontend" -eq 1 ] && [ "$has_backend" -eq 1 ]; then
    emit_pass "PSK022a: template choice — Template 3 (separate services, ${runtime_count}-runtime polyglot)"
  elif [ "$has_packages" -eq 1 ]; then
    emit_pass "PSK022a: template choice — Template 4 (monorepo)"
  elif [ "$has_bin" -eq 1 ] && [ "$has_src" -eq 1 ]; then
    emit_pass "PSK022a: template choice — Template 6 (CLI)"
  elif [ "$has_src" -eq 1 ]; then
    if [ "$runtime_count" -ge 2 ]; then
      emit_issue "PSK022a" "template-choice" \
        "Stack table declares ${runtime_count} runtimes but physical layout is Template 1 (src/ colocated). Expected Template 3 (frontend/+backend/)." \
        "Either consolidate to a single runtime in PLANS.md Stack table, or restructure to Template 3 with frontend/ + backend/ at project root."
    else
      emit_pass "PSK022a: template choice — Template 1 (single-runtime colocated)"
    fi
  fi
}

check_src_subdir_layout() {
  # PSK022b — verify src/ opt-in subdirs match Stack-derived expectation
  [ "$FULL" = false ] && return
  [ ! -d "$PROJ_ROOT/src" ] && return
  [ ! -f "$PROJ_ROOT/agent/PLANS.md" ] && return
  run_check

  local plans="$PROJ_ROOT/agent/PLANS.md"
  local need_ui=0 need_api=0 need_integrations=0 need_platform=0
  grep -qi -E 'next\.js|react|vue|angular|svelte|astro' "$plans" && need_ui=1
  grep -qi -E 'next\.js|fastapi|django|express|flask|hono|rails' "$plans" && need_api=1
  grep -qi -E 'twilio|stripe|openai|anthropic|claude|gpt|grok|gemini|whatsapp' "$plans" && need_integrations=1
  grep -qi -E 'admin panel|rbac|role-based|multi-tenant' "$plans" && need_platform=1

  local missing=""
  # Required always
  [ ! -d "$PROJ_ROOT/src/core" ] && missing="$missing core/"
  [ ! -d "$PROJ_ROOT/src/shared" ] && missing="$missing shared/"
  # Opt-in
  [ "$need_ui" -eq 1 ] && [ ! -d "$PROJ_ROOT/src/ui" ] && missing="$missing ui/"
  [ "$need_api" -eq 1 ] && [ ! -d "$PROJ_ROOT/src/api" ] && missing="$missing api/"
  [ "$need_integrations" -eq 1 ] && [ ! -d "$PROJ_ROOT/src/integrations" ] && missing="$missing integrations/"
  [ "$need_platform" -eq 1 ] && [ ! -d "$PROJ_ROOT/src/platform" ] && missing="$missing platform/"

  # Kit-self skip — kit has src/ only via examples, not as Template 1 app
  if [ -f "$PROJ_ROOT/install.sh" ] && [ -d "$PROJ_ROOT/examples" ] && [ -d "$PROJ_ROOT/tests/sections" ]; then
    emit_pass "PSK022b: src/ subdir layout (kit-self skip — not a Template 1 app project)"
    return
  fi

  if [ -z "$missing" ]; then
    emit_pass "PSK022b: src/ subdir layout matches Stack-derived expectation"
  else
    emit_issue "PSK022b" "src-subdir-layout" \
      "src/ missing expected subdirs (Stack-derived):${missing}" \
      "Run: bash agent/scripts/psk-scaffold-src.sh \"\$PROJ_ROOT\" to create missing subdirs idempotently."
  fi
}

check_template_quality() {
  [ "$FULL" = false ] && return
  local templates_dir="$PROJ_ROOT/.portable-spec-kit/templates"
  [ ! -d "$templates_dir" ] && return
  [ ! -x "$PROJ_ROOT/agent/scripts/psk-template-quality.sh" ] && return
  run_check

  # KIT-GAP-0049 fix #1 (v0.6.70): mtime cache for psk-template-quality
  # invocation. The script costs ~1.5s every --full run, paying that
  # cost even when no template changed since last sync-check. Cache the
  # "all-pass" verdict under .portable-spec-kit/.template-quality-cache
  # keyed by max mtime of the templates dir; only re-run when stale.
  # The cache holds "PASS:<max_mtime>:<count>" or absence-means-rerun.
  local cache_file="$PROJ_ROOT/.portable-spec-kit/.template-quality-cache"
  local max_mtime
  max_mtime=$(find "$templates_dir" -type f \( -name '*.md' -o -name '*.yml' -o -name '*.yaml' \) -print0 2>/dev/null \
    | xargs -0 stat -f '%m' 2>/dev/null | sort -rn | head -1)
  if [ -n "$max_mtime" ] && [ -f "$cache_file" ]; then
    local cached_line cached_mtime cached_count
    cached_line=$(cat "$cache_file" 2>/dev/null | head -1)
    cached_mtime=$(echo "$cached_line" | awk -F: '{print $2}')
    cached_count=$(echo "$cached_line" | awk -F: '{print $3}')
    if [ "${cached_line%%:*}" = "PASS" ] && [ "$cached_mtime" = "$max_mtime" ]; then
      emit_pass "PSK023: all $cached_count template(s) pass 7-criterion Quality Bar (cached, mtime $max_mtime)"
      return
    fi
  fi

  local lint_output
  if ! lint_output=$(bash "$PROJ_ROOT/agent/scripts/psk-template-quality.sh" --all --strict 2>&1); then
    local failed_lines
    failed_lines=$(echo "$lint_output" | grep -E "^✗" | head -10)
    emit_issue "PSK023" "template-quality" \
      "One or more templates fail the 7-criterion Quality Bar:\n${failed_lines}" \
      "Run 'bash agent/scripts/psk-template-quality.sh <template>' on each failing file. Fix per-criterion failures (criterion 1=stack-agnostic, 2=domain-agnostic, 3=scale-agnostic, 4=useful-and-complete, 5=lifecycle-aware, 6=self-documenting, 7=round-trippable). See portable-spec-kit.md §Template Quality Bar for full criteria."
    # Invalidate cache on failure
    rm -f "$cache_file" 2>/dev/null
  else
    local count
    count=$(echo "$lint_output" | grep -cE "^✓" || true)
    emit_pass "PSK023: all $count template(s) pass 7-criterion Quality Bar"
    # Update cache on successful pass
    if [ -n "$max_mtime" ]; then
      mkdir -p "$(dirname "$cache_file")" 2>/dev/null || true
      echo "PASS:$max_mtime:$count" > "$cache_file" 2>/dev/null || true
    fi
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

# --- CHECK: Kit version drift (K3.1 advisory) ---
# Compares the kit version installed in portable-spec-kit.md against the
# Kit: field in agent/AGENT_CONTEXT.md. Warns when they diverge — purely
# advisory (never blocks), because user projects don't control kit updates.
check_kit_version_drift() {
  run_check
  local ctx_kit_ver="" installed_kit_ver=""

  # Read Kit: field from AGENT_CONTEXT.md (e.g. "- **Kit:** v0.6.30")
  if [ -f "$AGENT_DIR/AGENT_CONTEXT.md" ]; then
    ctx_kit_ver=$(grep -m1 -E '\*\*Kit:\*\*' "$AGENT_DIR/AGENT_CONTEXT.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
  fi

  # Read installed kit version from portable-spec-kit.md **Version:** header
  if [ -f "$PROJ_ROOT/portable-spec-kit.md" ]; then
    installed_kit_ver=$(grep -m1 '^\*\*Version:\*\*' "$PROJ_ROOT/portable-spec-kit.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  fi

  if [ -n "$ctx_kit_ver" ] && [ -n "$installed_kit_ver" ] && [ "$ctx_kit_ver" != "$installed_kit_ver" ]; then
    emit_warn "AGENT_CONTEXT.md Kit: field ($ctx_kit_ver) doesn't match installed kit ($installed_kit_ver) — run: grep -n 'Kit:' agent/AGENT_CONTEXT.md to update (advisory)"
  else
    emit_pass "Kit version drift (no drift detected)"
  fi
}

# --- CHECK PSK024: Executable-plan schema conformance ---
#
# Enforces §Plan Execution Protocol (5th reliability layer). Every plan in
# agent/plans/*.md that is detected executable must declare a `phases:`
# frontmatter block conforming to the v1 schema. Narrative plans (no execution
# signal) are skipped. Compat-mode plans (`compat_mode: true`) bypass schema
# validation with a single advisory — they get one one-shot legacy run before
# conversion is required at the next `start`.
#
# Detection signals (any one makes the plan executable):
#   - frontmatter has `phases:`
#   - body has a `## Implementation Order` heading
#   - body has ≥ 2 `## Phase ` headings (v5 template convention)
#   - the plan's slug appears in any agent/.workflow-state/run-plan-*.state
#
# Sub-codes:
#   V=schema_version  P=phases   I=id          N=name      R=prompt path
#   A=artifact path   G=gate     C=commit_req  D=depends_on  M=prompt file
#   X=compat-mode advisory
#
# Modes:
#   --quick: warnings, exit 0 even with violations (PostToolUse-friendly)
#   --full : errors block, exit 1 on violations (pre-commit gate)
#
# Bypass: PSK_PLAN_EXEC_DISABLED=1 short-circuits the entire check.
check_plan_schema() {
  if [ "${PSK_PLAN_EXEC_DISABLED:-0}" = "1" ]; then
    # HF9 (v0.6.60): durable bypass-tamper audit trail. Failure tolerant.
    local _bypass_log_script="$SCRIPT_DIR/psk-bypass-log.sh"
    if [ -x "$_bypass_log_script" ]; then
      bash "$_bypass_log_script" log \
        --env-var "PSK_PLAN_EXEC_DISABLED" \
        --command "psk-sync-check.sh check_plan_schema" \
        --justification "${PSK_BYPASS_REASON:-not provided}" 2>/dev/null || true
    fi
    return 0
  fi
  local plans_dir="$AGENT_DIR/plans"
  [ ! -d "$plans_dir" ] && return 0
  run_check

  local total=0
  local executable=0
  local violations=0
  local quick_mode=false
  [ "$QUICK" = true ] && quick_mode=true

  # Collect plan files (top-level *.md, skip empty dir / .gitkeep)
  local plan_files=()
  while IFS= read -r -d '' f; do
    plan_files+=("$f")
  done < <(find "$plans_dir" -maxdepth 1 -type f -name "*.md" -print0 2>/dev/null)

  for plan in "${plan_files[@]}"; do
    total=$((total + 1))
    local rel="${plan#$PROJ_ROOT/}"
    local slug
    slug=$(basename "$plan" .md)
    # Strip date prefix if present (YYYY-MM-DD-<slug>.md → <slug>)
    local plan_slug="$slug"
    if [[ "$plan_slug" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-(.+)$ ]]; then
      plan_slug="${BASH_REMATCH[1]}"
    fi

    # Extract frontmatter into a temp buffer (between first two --- markers).
    # If file has no frontmatter, awk returns empty string.
    local fm
    fm=$(awk '
      BEGIN { in_fm = 0; done = 0 }
      NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; next }
      in_fm && /^---[[:space:]]*$/ { done = 1; in_fm = 0; next }
      in_fm && !done { print }
    ' "$plan")

    # Detect executable plan
    local has_phases_fm=0
    local has_impl_order=0
    local has_phase_headings=0
    local in_state=0
    local compat_mode=0

    if echo "$fm" | grep -qE '^phases:[[:space:]]*$'; then
      has_phases_fm=1
    fi
    if grep -qE '^## Implementation Order[[:space:]]*$' "$plan" 2>/dev/null; then
      has_impl_order=1
    fi
    local phase_h_count
    phase_h_count=$(grep -cE '^## Phase [A-Za-z0-9]' "$plan" 2>/dev/null | tr -d '\n ')
    [ -z "$phase_h_count" ] && phase_h_count=0
    [ "$phase_h_count" -ge 2 ] 2>/dev/null && has_phase_headings=1

    # Workflow-state slug match
    if ls "$AGENT_DIR"/.workflow-state/run-plan-*.state >/dev/null 2>&1; then
      for sf in "$AGENT_DIR"/.workflow-state/run-plan-*.state; do
        [ -f "$sf" ] || continue
        local sname
        sname=$(basename "$sf" .state)
        # sname looks like run-plan-<slug>
        if [ "$sname" = "run-plan-$plan_slug" ] || [ "$sname" = "run-plan-$slug" ]; then
          in_state=1
          break
        fi
      done
    fi

    # Compat-mode flag in frontmatter (explicit)
    if echo "$fm" | grep -qE '^compat_mode:[[:space:]]*true[[:space:]]*$'; then
      compat_mode=1
    fi

    # Implicit compat-mode: pure-legacy plan with no schema awareness at all
    # (no schema_version, no phases:, no compat_mode flag). Per §Plan Execution
    # Protocol — "Plans without phases: frontmatter execute once under
    # compat_mode: true, set by the driver." PSK024 surfaces the same plans
    # as advisory rather than hard error, preserving the one-shot conversion
    # contract while keeping legacy plans from blocking the gate.
    local has_schema_version=0
    if echo "$fm" | grep -qE '^schema_version:[[:space:]]*[0-9]+[[:space:]]*$'; then
      has_schema_version=1
    fi
    if [ "$compat_mode" -eq 0 ] && [ "$has_phases_fm" -eq 0 ] && [ "$has_schema_version" -eq 0 ]; then
      compat_mode=1
    fi

    # Not executable → skip silently
    if [ "$has_phases_fm" -eq 0 ] && [ "$has_impl_order" -eq 0 ] \
       && [ "$has_phase_headings" -eq 0 ] && [ "$in_state" -eq 0 ]; then
      continue
    fi

    executable=$((executable + 1))

    # Compat-mode short-circuit (PSK024-X advisory only)
    if [ "$compat_mode" -eq 1 ]; then
      if [ "$quick_mode" = false ]; then
        emit_warn "PSK024 [$rel]: compat-mode plan — conversion required before next \`start\` (PSK024-X)"
      fi
      continue
    fi

    # Track per-plan violations
    local plan_violations=0

    # Honor lifecycle status for PSK024-M (missing-prompt-file) probe:
    #   - done | abandoned → historical, prompts not actionable (work in git history)
    #   - draft            → not yet approved; prompts written JIT when phase spawns
    #   - approved | executing → about to run / running, prompts ARE required
    # Schema lint (V/P/I/N/R/A/G/C/D) still applies to all statuses.
    local plan_status=""
    plan_status=$(echo "$fm" | grep -E '^status:[[:space:]]*' | head -1 | sed -E 's/^status:[[:space:]]*//' | tr -d '"' | tr -d "[:space:]")
    local skip_prompt_existence=0
    if [ "$plan_status" = "done" ] || [ "$plan_status" = "abandoned" ] || [ "$plan_status" = "draft" ]; then
      skip_prompt_existence=1
    fi

    # PSK024-V — schema_version field present + integer
    if [ "$has_schema_version" -eq 0 ]; then
      _psk024_emit "$rel" "missing or non-integer schema_version field (PSK024-V)" "$quick_mode"
      plan_violations=$((plan_violations + 1))
    fi

    # PSK024-P — phases: array present + non-empty
    if [ "$has_phases_fm" -eq 0 ]; then
      _psk024_emit "$rel" "executable plan lacks 'phases:' frontmatter array (PSK024-P)" "$quick_mode"
      plan_violations=$((plan_violations + 1))
      violations=$((violations + plan_violations))
      continue
    fi

    # Extract phases block + parse per-phase fields with awk.
    # Phase entries start with "  - id:" (2-space indent, dash, id key).
    # Within each entry, recognize id / name / prompt / artifact / gate /
    # commit_required / depends_on keys (4-space indent).
    local phases_dump
    phases_dump=$(echo "$fm" | awk '
      BEGIN { in_phases = 0 }
      /^phases:[[:space:]]*$/ { in_phases = 1; next }
      in_phases && /^[A-Za-z_][A-Za-z0-9_]*:/ { in_phases = 0 }
      in_phases { print }
    ')

    if [ -z "$phases_dump" ]; then
      _psk024_emit "$rel" "phases: array is empty (PSK024-P)" "$quick_mode"
      plan_violations=$((plan_violations + 1))
      violations=$((violations + plan_violations))
      continue
    fi

    # Parse phases into records. Each record: pipe-delimited
    # "id|name|prompt|artifact|gate|commit_required|depends_on"
    # PSK024-D fix: records are \x1f (Unit Separator) delimited, NOT pipe — gate
    # commands legitimately contain '|' / '||' which would corrupt pipe-split
    # fields (leaking the gate into depends_on / commit_required). \x1f never
    # appears in shell commands so field splitting is robust.
    local phases_records
    phases_records=$(echo "$phases_dump" | awk -v SEP=$'\x1f' '
      function strip(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); sub(/^"/, "", s); sub(/"$/, "", s); return s }
      function any_set() { return (id != "" || name != "" || prompt != "" || artifact != "" || gate != "" || commit_required != "" || depends_on != "") }
      BEGIN { started=0; id=""; name=""; prompt=""; artifact=""; gate=""; commit_required=""; depends_on="" }
      /^[[:space:]]*-[[:space:]]*id:/ {
        if (started && any_set()) {
          print id SEP name SEP prompt SEP artifact SEP gate SEP commit_required SEP depends_on
        }
        started=1
        sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "")
        id = strip($0); name=""; prompt=""; artifact=""; gate=""; commit_required=""; depends_on=""
        next
      }
      /^[[:space:]]+name:/ { sub(/^[[:space:]]+name:[[:space:]]*/, ""); name=strip($0); next }
      /^[[:space:]]+prompt:/ { sub(/^[[:space:]]+prompt:[[:space:]]*/, ""); prompt=strip($0); next }
      /^[[:space:]]+artifact:/ { sub(/^[[:space:]]+artifact:[[:space:]]*/, ""); artifact=strip($0); next }
      /^[[:space:]]+gate:/ { sub(/^[[:space:]]+gate:[[:space:]]*/, ""); gate=strip($0); next }
      /^[[:space:]]+commit_required:/ { sub(/^[[:space:]]+commit_required:[[:space:]]*/, ""); commit_required=strip($0); next }
      /^[[:space:]]+depends_on:/ { sub(/^[[:space:]]+depends_on:[[:space:]]*/, ""); depends_on=strip($0); next }
      END {
        if (started && any_set()) {
          print id SEP name SEP prompt SEP artifact SEP gate SEP commit_required SEP depends_on
        }
      }
    ')

    if [ -z "$phases_records" ]; then
      _psk024_emit "$rel" "phases: array is empty (PSK024-P)" "$quick_mode"
      plan_violations=$((plan_violations + 1))
      violations=$((violations + plan_violations))
      continue
    fi

    # Collect all ids first for dup + depends_on cross-check
    local all_ids=""
    local seen_ids=""
    while IFS=$'\x1f' read -r pid pname pprompt partifact pgate pcommit pdep; do
      all_ids="$all_ids $pid"
    done <<< "$phases_records"

    # Per-phase field checks
    while IFS=$'\x1f' read -r pid pname pprompt partifact pgate pcommit pdep; do
      # PSK024-I: id present + unique + kebab/alphanumeric
      if [ -z "$pid" ]; then
        _psk024_emit "$rel" "phase has empty id (PSK024-I)" "$quick_mode"
        plan_violations=$((plan_violations + 1))
        continue
      fi
      if ! echo "$pid" | grep -qE '^[A-Za-z0-9][A-Za-z0-9._-]*$'; then
        _psk024_emit "$rel" "phase id '$pid' not kebab/alphanumeric (PSK024-I)" "$quick_mode"
        plan_violations=$((plan_violations + 1))
      fi
      if echo "$seen_ids" | tr ' ' '\n' | grep -qxF "$pid"; then
        _psk024_emit "$rel" "phase id '$pid' duplicated (PSK024-I)" "$quick_mode"
        plan_violations=$((plan_violations + 1))
      else
        seen_ids="$seen_ids $pid"
      fi

      # PSK024-N: name present
      if [ -z "$pname" ]; then
        _psk024_emit "$rel" "phase '$pid' missing name field (PSK024-N)" "$quick_mode"
        plan_violations=$((plan_violations + 1))
      fi

      # PSK024-R: prompt path under agent/plans/<slug>/prompts/<id>.md
      local expected_prompt="agent/plans/$plan_slug/prompts/$pid.md"
      if [ -z "$pprompt" ]; then
        _psk024_emit "$rel" "phase '$pid' missing prompt field (PSK024-R)" "$quick_mode"
        plan_violations=$((plan_violations + 1))
      elif [ "$pprompt" != "$expected_prompt" ]; then
        _psk024_emit "$rel" "phase '$pid' prompt path '$pprompt' should be '$expected_prompt' (PSK024-R)" "$quick_mode"
        plan_violations=$((plan_violations + 1))
      fi

      # PSK024-A: artifact path under agent/plans/<slug>/artifacts/<id>.done.md
      local expected_artifact="agent/plans/$plan_slug/artifacts/$pid.done.md"
      if [ -z "$partifact" ]; then
        _psk024_emit "$rel" "phase '$pid' missing artifact field (PSK024-A)" "$quick_mode"
        plan_violations=$((plan_violations + 1))
      elif [ "$partifact" != "$expected_artifact" ]; then
        _psk024_emit "$rel" "phase '$pid' artifact path '$partifact' should be '$expected_artifact' (PSK024-A)" "$quick_mode"
        plan_violations=$((plan_violations + 1))
      fi

      # PSK024-G: gate command present
      if [ -z "$pgate" ]; then
        _psk024_emit "$rel" "phase '$pid' missing gate field (PSK024-G)" "$quick_mode"
        plan_violations=$((plan_violations + 1))
      fi

      # PSK024-C: commit_required boolean present
      if [ -z "$pcommit" ]; then
        _psk024_emit "$rel" "phase '$pid' missing commit_required field (PSK024-C)" "$quick_mode"
        plan_violations=$((plan_violations + 1))
      elif [ "$pcommit" != "true" ] && [ "$pcommit" != "false" ]; then
        _psk024_emit "$rel" "phase '$pid' commit_required must be boolean, got '$pcommit' (PSK024-C)" "$quick_mode"
        plan_violations=$((plan_violations + 1))
      fi

      # PSK024-D: depends_on references must be existing ids
      if [ -n "$pdep" ] && [ "$pdep" != "[]" ]; then
        # Strip brackets/quotes/spaces, split on comma
        local dep_clean
        dep_clean=$(echo "$pdep" | tr -d '[]"' | tr ',' ' ')
        for d in $dep_clean; do
          d=$(echo "$d" | tr -d ' ')
          [ -z "$d" ] && continue
          if ! echo "$all_ids" | tr ' ' '\n' | grep -qxF "$d"; then
            _psk024_emit "$rel" "phase '$pid' depends_on '$d' which is not a declared phase id (PSK024-D)" "$quick_mode"
            plan_violations=$((plan_violations + 1))
          fi
        done
      fi

      # PSK024-M: prompt file exists on disk (warn in quick, error in full).
      # Skipped for historical/not-yet-active plans (done|abandoned|draft) — see
      # skip_prompt_existence above; prompts for those are not actionable.
      if [ -n "$pprompt" ] && [ "$skip_prompt_existence" -eq 0 ]; then
        if [ ! -f "$PROJ_ROOT/$pprompt" ]; then
          if [ "$quick_mode" = true ]; then
            # warn-only — don't count as violation in --quick
            :
          else
            _psk024_emit "$rel" "phase '$pid' prompt file not found at $pprompt (PSK024-M)" "$quick_mode"
            plan_violations=$((plan_violations + 1))
          fi
        fi
      fi
    done <<< "$phases_records"

    # PSK024-D cycle detection (simple DFS over depends_on edges).
    # Build edge list "from -> to" pairs. \x1f-delimited (see PSK024-D fix above).
    local edges
    edges=$(echo "$phases_records" | awk -v SEP=$'\x1f' '
      BEGIN { FS = SEP }
      {
        from = $1
        dep = $7
        gsub(/[\[\]"]/, "", dep)
        gsub(/,/, " ", dep)
        n = split(dep, deps, " ")
        for (i = 1; i <= n; i++) {
          d = deps[i]
          gsub(/[[:space:]]/, "", d)
          if (d != "") print from " " d
        }
      }
    ')
    if [ -n "$edges" ]; then
      # Detect cycle via awk DFS — if any node revisits itself in its descendant set
      local cycle
      cycle=$(echo "$edges" | awk '
        { adj[$1] = adj[$1] " " $2; nodes[$1]=1; nodes[$2]=1 }
        END {
          for (n in nodes) {
            # DFS from n; if we revisit n, cycle exists
            split("", stack)
            split("", visited)
            stack[1] = n
            top = 1
            while (top > 0) {
              cur = stack[top]; top--
              split(adj[cur], children, " ")
              for (i in children) {
                c = children[i]
                if (c == "") continue
                if (c == n) { print "CYCLE:" n; exit }
                if (!visited[c]) {
                  visited[c] = 1
                  top++
                  stack[top] = c
                }
              }
            }
          }
        }
      ')
      if [ -n "$cycle" ]; then
        local cnode="${cycle#CYCLE:}"
        _psk024_emit "$rel" "depends_on cycle detected involving phase '$cnode' (PSK024-D)" "$quick_mode"
        plan_violations=$((plan_violations + 1))
      fi
    fi

    violations=$((violations + plan_violations))
  done

  # Aggregate report
  local summary="PSK024: $total plans checked, $executable executable, $violations violations"
  if [ "$violations" -eq 0 ]; then
    emit_pass "$summary"
  else
    if [ "$quick_mode" = true ]; then
      # Quick mode: warn only, do not emit a hard issue
      emit_warn "$summary (--quick: warnings only)"
    else
      emit_issue "PSK024" "plan-schema" \
        "$summary — see PSK024-* sub-codes above" \
        "Convert executable plans to the §Plan Execution Protocol schema (see .portable-spec-kit/templates/plan-executable.md). Bypass: PSK_PLAN_EXEC_DISABLED=1"
    fi
  fi
}

# Helper for check_plan_schema — emit one violation line, respecting quick mode.
_psk024_emit() {
  local rel="$1"
  local msg="$2"
  local quick="$3"
  if [ "$quick" = "true" ]; then
    # Quick: print as inline warning, no issue count
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK024 [$rel]: $msg"
  else
    # Full: print as warn line so user sees specifics, aggregate counted via violations
    echo -e "  ${YELLOW}⚠${NC} PSK024 [$rel]: $msg"
  fi
}

# --- CHECK PSK025: UI Completeness Gate (B1 of workflow-fidelity plan, v0.6.57+) ---
#
# Wraps agent/scripts/psk-ui-completeness.sh --json. Stack-aware: skips projects
# without a declared frontend framework. Frontend-declared projects must meet
# the 10-category UI completeness bar (P/L/D/S/A/T/F/I/R/E sub-codes).
#
# Bypass: PSK_UI_COMPLETENESS_DISABLED=1 short-circuits the check.
#
check_ui_completeness() {
  if [ "${PSK_UI_COMPLETENESS_DISABLED:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK025: skipped (PSK_UI_COMPLETENESS_DISABLED=1)"
    run_check
    return
  fi
  local script="$PROJ_ROOT/agent/scripts/psk-ui-completeness.sh"
  if [ ! -x "$script" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK025: psk-ui-completeness.sh not present — skip (advisory)"
    run_check
    return
  fi
  local json; json=$(bash "$script" --json 2>/dev/null)
  if [ -z "$json" ]; then
    run_check
    return
  fi
  # Check skip cases
  if echo "$json" | grep -q '"skipped"'; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK025: no frontend declared — skip"
    run_check
    return
  fi
  # Parse violations count
  local violations; violations=$(echo "$json" | grep -oE '"violations":[0-9]+' | head -1 | grep -oE '[0-9]+')
  local sub_codes; sub_codes=$(echo "$json" | grep -oE '"sub_codes":\[[^]]*\]' | head -1)
  if [ "${violations:-0}" -eq 0 ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK025: UI completeness — all 10 categories pass"
    run_check
    return
  fi
  # Emit one warn line per sub-code violation
  local codes; codes=$(echo "$sub_codes" | grep -oE '"[A-Z]"' | tr -d '"' | tr '\n' ' ')
  if [ "$QUICK" = true ]; then
    echo -e "  ${YELLOW}⚠${NC} PSK025: UI completeness — ${violations} violation(s) in: $codes"
    run_check
  else
    issue "PSK025: UI completeness — ${violations} violation(s) in sub-codes: $codes" \
          "Run: bash agent/scripts/psk-ui-completeness.sh   # see per-sub-code details"
  fi
}

# --- CHECK PSK028: Cascade-as-user-update anti-pattern detection (v0.6.60+) ---
#
# The canonical user-project update path is `psk-orchestrate.sh build` (v0.6.62+
# — one command for new + existing; `--update` removed). The legacy "cascade kit into project" wording
# (and the install.sh-from-PKFL invocation it implied) is retired. PSK028
# grep-scans the kit's normative surfaces (portable-spec-kit.md, docs/work-flows/,
# reflex/lib/, reflex/prompts/, reflex/config.yml, agent/scripts/) for the
# anti-pattern. Detection patterns:
#
#   - "cascade(s|d|ing)?\s+(the\s+)?(updated\s+)?kit"     — wording leak
#   - "cascade(s|d|ing)?\s+.*\s+(into|to)\s+(the\s+)?(source\s+|triggering\s+)?project"
#   - "--auto-cascade" used outside deprecation marker
#   - kit-evolution.sh-style raw "install.sh --yes --from <kit> --target"
#     pattern when the script context is PKFL / kit-evolution (not install itself)
#
# Allowlist (legitimate occurrences that stay):
#   - psk-version-cascade.sh (kit-internal version-anchor sync — Step 6 of release)
#   - "cascade_check" / "cascade-check" (reflex Dev-Agent finding-auto-closure)
#   - "cascade(s)?" in historical/journal docs (docs/work-flows/17, /21 — past tense)
#   - "manual cascade pattern (retired ...)" — explicit deprecation copy in doc 23
#   - The deprecation lines in reflex/config.yml + reflex/lib/kit-evolution.sh
#     that retain --auto-cascade / auto_cascade as backward-compat aliases
#   - This check itself (which obviously mentions the anti-pattern words)
#
# Bypass: PSK_PSK028_DISABLED=1
#
check_cascade_anti_pattern() {
  if [ "${PSK_PSK028_DISABLED:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK028: skipped (PSK_PSK028_DISABLED=1)"
    run_check
    return
  fi

  # Only run in kit-mode (the rule is about the kit's own surface)
  if [ "$MODE" != "kit" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK028: skip (non-kit mode)"
    run_check
    return
  fi

  # Search surfaces — kit's normative files only. Excludes:
  #   - reflex/sandbox/ + reflex/history/  (transient + historical)
  #   - .session-archive/                  (transient)
  #   - examples/                          (downstream installed copies)
  #   - agent/RELEASES.md + agent/PLANS.md (historical journals)
  #   - agent/plans/ + agent/tasks/        (working plans + filed kit-tasks reference patterns by design)
  #   - tests/                             (test fixtures legitimately contain anti-pattern strings)
  #   - this script itself                 (obviously mentions the words)
  local violations=0
  local violation_files=""

  # Use a here-doc style file list to keep grep deterministic across machines.
  local files
  files=$(find "$PROJ_ROOT" \
    \( -path "$PROJ_ROOT/portable-spec-kit.md" \
    -o -path "$PROJ_ROOT/docs/work-flows/*.md" \
    -o -path "$PROJ_ROOT/reflex/lib/*.sh" \
    -o -path "$PROJ_ROOT/reflex/prompts/*.md" \
    -o -path "$PROJ_ROOT/reflex/config.yml" \
    -o -path "$PROJ_ROOT/reflex/run.sh" \
    -o -path "$PROJ_ROOT/agent/scripts/psk-orchestrate.sh" \
    -o -path "$PROJ_ROOT/agent/scripts/psk-release.sh" \
    \) -type f 2>/dev/null)

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    local base; base=$(basename "$f")

    # Allowlist scripts (legitimate cascade machinery)
    case "$base" in
      psk-version-cascade.sh) continue ;;
    esac

    # Scan for the two main anti-patterns. We grep then filter out
    # allowlisted contexts via inverse grep against legitimate markers.
    local hits
    hits=$(grep -nE \
      "cascade[sd]?[[:space:]]+(the[[:space:]]+)?(updated[[:space:]]+)?kit|cascade[sd]?[[:space:]]+.*[[:space:]]+(into|to)[[:space:]]+(the[[:space:]]+)?(source[[:space:]]+|triggering[[:space:]]+)?project|install\.sh[[:space:]]+--yes[[:space:]]+--from[[:space:]].*--target" \
      "$f" 2>/dev/null \
      | grep -viE "cascade_check|cascade-check|version-cascade|version cascade|version-drift cascade|field-anchored cascade|cascade scripts must|cascade ceremony|cascade Kit field|cascade auto-closure|cascade-script|cascade auto-closures|symptom .* cascade|DEPRECATED|backward-compat alias|manual cascade pattern|retired in v0\.6\.4[78]|retires the manual cascade|cascade auto-closes|cascade kit vX|hand-committing|--auto-cascade.*backward|auto_cascade.*backward|chapter|history|sandbox" \
      || true)

    if [ -n "$hits" ]; then
      violations=$((violations + 1))
      violation_files="${violation_files}
    $f"
      if [ "$QUICK" = false ]; then
        echo -e "  ${RED}✗${NC} PSK028 cascade-anti-pattern in $f:"
        echo "$hits" | sed 's/^/      /'
      fi
    fi
  done <<< "$files"

  if [ "$violations" -eq 0 ]; then
    emit_pass "PSK028: cascade-as-user-update anti-pattern — 0 violations"
  else
    if [ "$QUICK" = true ]; then
      echo -e "  ${YELLOW}⚠${NC} PSK028: cascade-as-user-update anti-pattern — $violations file(s)"
      run_check
    else
      emit_issue "PSK028" "cascade-anti-pattern" \
        "cascade-as-user-update wording detected in $violations kit file(s):$violation_files" \
        "Use 'psk-orchestrate.sh build' for user-project updates (v0.6.62+ — one command for new + existing; '--update' removed). Cascade wording is reserved for kit-internal version-anchor sync (psk-version-cascade.sh) and reflex Dev-Agent auto-closure (cascade-check). See HF0 in agent/plans/spawn-fidelity-hardening/ for migration guide."
    fi
  fi
}

# --- CHECK PSK029: Resume-on-session-start audit (v0.6.60+ HF4) ---
#
# Reads agent/.workflow-state/session-audit.log and verifies the most-recent
# `session-start-resume-check ran` marker is fresher than the most-recent
# commit that touched agent/ or src/. The rule only fires when there is
# in-progress workflow state — i.e., at least one *.state file in
# .workflow-state/ has `STARTED=<ts>` more recent than the last commit
# touching .workflow-state/ itself. This recursion-guard keeps normal
# kit-dev state from self-flagging while still catching gaps in genuine
# user projects.
#
# Severity: ADVISORY in --quick mode, ERROR in --full mode.
# Bypass: PSK_RESUME_BOOTSTRAP_DISABLED=1
check_resume_bootstrap() {
  if [ "${PSK_RESUME_BOOTSTRAP_DISABLED:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK029: skipped (PSK_RESUME_BOOTSTRAP_DISABLED=1)"
    run_check
    return
  fi

  local state_dir="$PROJ_ROOT/agent/.workflow-state"
  local audit_log="$state_dir/session-audit.log"

  # No state dir → nothing to audit (clean project, never used workflows)
  if [ ! -d "$state_dir" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK029: no workflow-state present — skip"
    run_check
    return
  fi

  # Recursion guard — only fire when there's *active* paused workflow state.
  # "Active" = at least one *.state file has STARTED= more recent than the
  # last commit touching .workflow-state/. Without this, the kit's OWN
  # in-progress workflow state (which is normal kit-dev) would self-flag.
  local has_state_files=0
  for sf in "$state_dir"/*.state; do
    [ -f "$sf" ] || continue
    has_state_files=1
    break
  done
  if [ "$has_state_files" -eq 0 ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK029: no .state files — skip"
    run_check
    return
  fi

  # Recursion guard: compare *.state STARTED timestamps to last commit
  # touching .workflow-state/. If no .state STARTED is newer than the
  # last commit, the in-progress state is already-committed history,
  # not a genuine "uncovered" pause. Skip.
  local last_wfstate_commit_ts=0
  if git -C "$PROJ_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    last_wfstate_commit_ts=$(git -C "$PROJ_ROOT" log -1 --format=%ct -- agent/.workflow-state/ 2>/dev/null || echo 0)
    [ -z "$last_wfstate_commit_ts" ] && last_wfstate_commit_ts=0
  fi

  local active_state=0
  for sf in "$state_dir"/*.state; do
    [ -f "$sf" ] || continue
    local started_iso started_epoch
    started_iso=$(grep '^STARTED=' "$sf" 2>/dev/null | head -1 | cut -d= -f2)
    [ -z "$started_iso" ] && continue
    # Parse ISO timestamp to epoch (portable across BSD / GNU date)
    started_epoch=$(python3 -c "
import sys, re, calendar
m = re.match(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$', '$started_iso'.strip())
if m:
    p = [int(x) for x in m.groups()]
    print(calendar.timegm((p[0],p[1],p[2],p[3],p[4],p[5],0,0,0)))
else:
    print(0)
" 2>/dev/null || echo 0)
    if [ "$started_epoch" -gt "$last_wfstate_commit_ts" ]; then
      active_state=1
      break
    fi
  done

  if [ "$active_state" -eq 0 ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK029: workflow state already committed — skip"
    run_check
    return
  fi

  # We have genuine active in-progress state. Check audit log freshness
  # against the last commit touching agent/ or src/.
  local last_commit_ts last_marker_ts
  if git -C "$PROJ_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    last_commit_ts=$(git -C "$PROJ_ROOT" log -1 --format=%ct -- agent/ src/ 2>/dev/null || echo 0)
    [ -z "$last_commit_ts" ] && last_commit_ts=0
  else
    last_commit_ts=0
  fi

  if [ ! -f "$audit_log" ]; then
    # Missing audit log + active state + commits exist → violation
    if [ "$last_commit_ts" -gt 0 ]; then
      if [ "$QUICK" = true ]; then
        echo -e "  ${YELLOW}⚠${NC} PSK029: session-audit.log missing despite active workflow state"
        run_check
      else
        emit_issue "PSK029" "resume-bootstrap-skipped" \
          "agent/.workflow-state/session-audit.log missing despite active in-progress workflow state" \
          "Run 'bash agent/scripts/psk-resume-bootstrap.sh' at the start of every session in this project. This drains the retry queue and surfaces paused phases before the agent responds to the user."
      fi
    else
      emit_pass "PSK029: no commits yet — skip"
    fi
    return
  fi

  # Parse the most-recent marker timestamp from the audit log
  last_marker_ts=$(tail -100 "$audit_log" 2>/dev/null \
    | grep 'session-start-resume-check ran' \
    | tail -1 \
    | awk '{print $1}' \
    | python3 -c "
import sys, re, calendar
s = sys.stdin.read().strip()
m = re.match(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$', s)
if m:
    p = [int(x) for x in m.groups()]
    print(calendar.timegm((p[0],p[1],p[2],p[3],p[4],p[5],0,0,0)))
else:
    print(0)
" 2>/dev/null || echo 0)
  [ -z "$last_marker_ts" ] && last_marker_ts=0

  # Grace window (QA-DIM-22-PSK029-RACE-01, v0.6.64; widened cycle-25-pass-001):
  # The marker exists to detect "agent forgot to run resume-bootstrap on session
  # start" — gross neglect, not sub-day timing drift. The original 300s default
  # treated any session lasting >5min between marker and commit as stale, but
  # real autoloop sessions routinely span hours (long convergence runs, plan-
  # execution phases, multi-iteration reflex cycles). 86400s (24h) captures the
  # gross-neglect signal cleanly while suppressing the false-positive carryover
  # bug (QA-PSK029-RESUME-BOOTSTRAP-STALE class-bug observed cycle-22→cycle-25).
  # Sub-day marker gaps are normal autoloop discipline, not a sync-check signal.
  # The AWAITING_HUMAN_ARBITRATION dual check below still triggers PSK029
  # regardless of grace-window — durable arbitration state is the real signal.
  local grace_window="${PSK029_GRACE_SECONDS:-86400}"
  local marker_age_vs_commit=$(( last_commit_ts - last_marker_ts ))
  local awaiting_arbitration=0
  local retry_queue="$PROJ_ROOT/agent/.workflow-state/retry-queue.yml"
  if [ -f "$retry_queue" ] && grep -qE 'AWAITING_HUMAN_ARBITRATION' "$retry_queue" 2>/dev/null; then
    awaiting_arbitration=1
  fi
  if [ "$last_marker_ts" -ge "$last_commit_ts" ]; then
    emit_pass "PSK029: resume-bootstrap audit log fresh (marker ≥ last commit)"
  elif [ "$marker_age_vs_commit" -le "$grace_window" ] && [ "$awaiting_arbitration" -eq 0 ]; then
    emit_pass "PSK029: marker within ${grace_window}s grace window of last commit and no AWAITING_HUMAN_ARBITRATION entries — healthy"
  else
    if [ "$QUICK" = true ]; then
      echo -e "  ${YELLOW}⚠${NC} PSK029: resume-bootstrap not run since last commit (active workflow state present)"
      run_check
    else
      # QA-D15-PSK029-MESSAGE-FALSE-POSITIVE fix (cycle-22-pass-002):
      # awaiting_arbitration is initialised to "0" (set + non-empty), so the
      # bash :+ operator ALWAYS expanded the suffix — including when zero
      # AWAITING_HUMAN_ARBITRATION entries exist in the queue. Replaced with
      # explicit -eq 1 test so the suffix only appears when truly applicable.
      local arbitration_suffix=""
      if [ "$awaiting_arbitration" -eq 1 ]; then
        arbitration_suffix=" AND retry queue has AWAITING_HUMAN_ARBITRATION entries"
      fi
      emit_issue "PSK029" "resume-bootstrap-stale" \
        "session-start-resume-check marker (epoch=$last_marker_ts) is older than the most-recent commit (epoch=$last_commit_ts) by ${marker_age_vs_commit}s, exceeding grace window of ${grace_window}s${arbitration_suffix}" \
        "Run 'bash agent/scripts/psk-resume-bootstrap.sh' before resuming work. The helper drains agent/.workflow-state/retry-queue.yml and lists paused phases so the agent picks them up before responding."
    fi
  fi
}

# --- CHECK PSK026: Critic-result.md synthesis-detection audit (v0.6.60+ HF6) ---
#
# Counterpart to HF5's check-audit-completeness.sh probe (for reflex
# findings.yaml) — applies the same three synthesis-signature checks to
# release-ceremony / feature-complete / init / reinit / new-setup /
# existing-setup workflow critic-result.md files at agent/.release-state/.
#
# Three signatures (all check critic-result.md as written by the sub-agent
# critic in response to critic-task.md):
#   (a) Has QUOTE evidence — at least one QUOTE: line paired with a CURRENT:
#       line (the file:line citation surface used by the dual-critic protocol)
#   (b) Reasonable timestamp diff — critic-result.md mtime must be ≥10sec
#       after the parent commit timestamp (genuine sub-agent runs take time;
#       impossibly fast diffs signal the result was canned in advance)
#   (c) Result references task files — at least one path mentioned in
#       critic-result.md overlaps with paths called out in critic-task.md
#
# Severity:
#   WARNING — missing QUOTE evidence (signature a)
#   ERROR   — impossibly-fast timestamp diff (signature b)
#   ERROR   — zero path overlap with critic-task.md (signature c)
#
# When fires: --full mode AND agent/.release-state/critic-result.md exists
# AND the parent path is NOT under tests/sections/ or /tmp/ (recursion
# guard for unit-tests that synthesize critic-result.md fixtures).
#
# Bypass: PSK_PSK026_DISABLED=1
check_psk026_critic_completeness() {
  if [ "${PSK_PSK026_DISABLED:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK026: skipped (PSK_PSK026_DISABLED=1)"
    run_check
    return
  fi

  # Only fires in --full mode (per spec).
  if [ "$QUICK" = true ]; then
    return
  fi

  local critic_result="$PROJ_ROOT/agent/.release-state/critic-result.md"
  local critic_task="$PROJ_ROOT/agent/.release-state/critic-task.md"

  # Recursion-guard: skip when project root looks like a test fixture path
  # (kit's own unit-tests synthesize critic-result.md under /tmp/ or
  # tests/sections/ — they would self-flag without this guard).
  case "$PROJ_ROOT" in
    */tests/sections/*|/tmp/*|/private/tmp/*|*/.tmp/*)
      [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK026: recursion guard (test fixture path) — skip"
      run_check
      return
      ;;
  esac

  if [ ! -f "$critic_result" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK026: no critic-result.md present — skip"
    run_check
    return
  fi

  local violations_warn=0
  local violations_err=0
  local violation_details=""

  # --- Signature (a): QUOTE evidence presence ---
  # Format used by critic-spawn templates is:
  #   CURRENT: <filename>
  #   QUOTE: <verbatim line>
  # Every CURRENT must have a paired QUOTE per the dual-critic contract.
  local current_count quote_count
  current_count=$(grep -cE '^CURRENT:' "$critic_result" 2>/dev/null)
  [ -z "$current_count" ] && current_count=0
  quote_count=$(grep -cE '^QUOTE:' "$critic_result" 2>/dev/null)
  [ -z "$quote_count" ] && quote_count=0

  if [ "$current_count" -gt 0 ] && [ "$quote_count" -eq 0 ]; then
    violations_warn=$((violations_warn + 1))
    violation_details="${violation_details}
    - WARNING: critic-result.md has $current_count CURRENT: entries but 0 QUOTE: lines (synthesis signature: no file evidence)"
  fi

  # --- Signature (b): mtime diff vs parent commit ---
  # Genuine sub-agent critic runs take ≥30sec wall-clock to read files and
  # produce the result. <10sec between the result write and the parent
  # commit signals a pre-canned response, not a real critic invocation.
  local result_mtime parent_commit_ts diff_sec
  result_mtime=$(get_mtime "$critic_result" 2>/dev/null || echo 0)
  [ -z "$result_mtime" ] && result_mtime=0
  parent_commit_ts=0
  if git -C "$PROJ_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    parent_commit_ts=$(git -C "$PROJ_ROOT" log -1 --format=%ct 2>/dev/null || echo 0)
    [ -z "$parent_commit_ts" ] && parent_commit_ts=0
  fi
  if [ "$result_mtime" -gt 0 ] && [ "$parent_commit_ts" -gt 0 ]; then
    # Take absolute value (mtime can come either before or after the parent
    # commit depending on whether the critic ran pre- or post-commit).
    if [ "$result_mtime" -ge "$parent_commit_ts" ]; then
      diff_sec=$(( result_mtime - parent_commit_ts ))
    else
      diff_sec=$(( parent_commit_ts - result_mtime ))
    fi
    if [ "$diff_sec" -lt 10 ]; then
      violations_err=$((violations_err + 1))
      violation_details="${violation_details}
    - ERROR: critic-result.md mtime within ${diff_sec}s of parent commit (<10s — synthesis signature: pre-canned response)"
    fi
  fi

  # --- Signature (c): path overlap with critic-task.md ---
  # critic-task.md enumerates files the sub-agent MUST read (e.g. "Read
  # these files: agent/AGENT_CONTEXT.md, agent/RELEASES.md, ..."). The
  # result MUST mention at least one of those paths. Zero overlap →
  # the critic never actually looked at the task.
  if [ -f "$critic_task" ]; then
    # Extract distinctive path tokens from critic-task.md. We look for
    # filenames with extension OR explicit dir paths under agent/ docs/
    # tests/ src/ ard/.
    local task_paths
    task_paths=$(grep -oE '(agent/[A-Za-z_./-]+|docs/[A-Za-z_./-]+|tests/[A-Za-z_./-]+|ard/[A-Za-z_./-]+|src/[A-Za-z_./-]+|[A-Za-z_-]+\.(md|sh|yml|yaml|html|js|ts|py|json))' "$critic_task" 2>/dev/null \
      | sort -u)
    if [ -n "$task_paths" ]; then
      local overlap=0
      local p
      while IFS= read -r p; do
        [ -z "$p" ] && continue
        # Trim trailing punctuation
        p="${p%[.,;:)]}"
        if grep -qF "$p" "$critic_result" 2>/dev/null; then
          overlap=1
          break
        fi
      done <<< "$task_paths"
      if [ "$overlap" -eq 0 ] && [ "$current_count" -gt 0 ]; then
        violations_err=$((violations_err + 1))
        violation_details="${violation_details}
    - ERROR: critic-result.md references no paths from critic-task.md (synthesis signature: result ignored the task)"
      fi
    fi
  fi

  if [ "$violations_err" -eq 0 ] && [ "$violations_warn" -eq 0 ]; then
    emit_pass "PSK026: critic-result.md synthesis-detection — clean ($current_count CURRENT entries, $quote_count QUOTE lines)"
  elif [ "$violations_err" -gt 0 ]; then
    emit_issue "PSK026" "critic-completeness" \
      "critic-result.md fails synthesis-detection (err=$violations_err warn=$violations_warn):$violation_details" \
      "Re-run the workflow critic phase. The sub-agent must read the files cited in critic-task.md and quote verbatim lines from each."
  else
    emit_warn "PSK026: critic-result.md has $violations_warn synthesis warning(s):$violation_details"
  fi
}

# --- CHECK PSK027: Bypass-Tamper Detection (v0.6.60+ HF9) ---
#
# Counts entries in agent/.bypass-log (JSONL format written by
# psk-bypass-log.sh). Bypasses remain available for genuine emergencies,
# but repeated use surfaces as a pattern — making "I'll just bypass it
# again" structurally visible.
#
# Severity (per the v0.6.60 spec):
#   0 in 24h          → no finding
#   1-2 in 24h        → WARNING
#   3+ in 24h         → ERROR  (repeated bypassing)
#   10+ in 7d         → ERROR  (structural bypass abuse)
#
# Recursion-guard: PSK027 itself does NOT call any bypass-respecting
# code (it shells out to the read-only `count` subcommand of
# psk-bypass-log.sh — that subcommand has no bypass branch). A missing
# .bypass-log is treated as 0 bypasses (clean projects).
#
# Bypass: PSK_PSK027_DISABLED=1 — emergency only.
check_psk027_bypass_audit() {
  if [ "${PSK_PSK027_DISABLED:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK027: skipped (PSK_PSK027_DISABLED=1)"
    run_check
    return
  fi

  local bypass_log_script="$SCRIPT_DIR/psk-bypass-log.sh"
  if [ ! -x "$bypass_log_script" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK027: psk-bypass-log.sh missing — skip"
    run_check
    return
  fi

  local count_24h count_7d
  count_24h=$(bash "$bypass_log_script" count --since-days 1 2>/dev/null || echo "0")
  count_7d=$(bash "$bypass_log_script" count --since-days 7 2>/dev/null || echo "0")
  [ -z "$count_24h" ] && count_24h=0
  [ -z "$count_7d" ] && count_7d=0

  # Sanitize — guard against any non-numeric output
  case "$count_24h" in (*[!0-9]*) count_24h=0 ;; esac
  case "$count_7d" in (*[!0-9]*) count_7d=0 ;; esac

  if [ "$count_24h" -eq 0 ] && [ "$count_7d" -lt 10 ]; then
    emit_pass "PSK027: bypass-tamper audit clean (0/24h, $count_7d/7d)"
    return
  fi

  # Build breakdown of unique env_vars (most-frequent first)
  local unique_summary
  unique_summary=$(bash "$bypass_log_script" unique-env-vars 1 2>/dev/null | head -5 \
    | awk 'NF>0 {printf "%s(x%s) ", $1, $2}')
  [ -z "$unique_summary" ] && unique_summary="(none)"

  # 10+ in 7 days → strong ERROR (structural abuse)
  if [ "$count_7d" -ge 10 ]; then
    emit_issue "PSK027" "bypass-abuse" \
      "structural bypass abuse — $count_7d bypasses in 7 days ($count_24h in last 24h); env vars: $unique_summary" \
      "Investigate why these guards are being routinely defeated. Audit agent/.bypass-log and address the root cause; do not silence with PSK_PSK027_DISABLED=1."
    return
  fi

  # 3+ in 24h → ERROR (repeated bypassing)
  if [ "$count_24h" -ge 3 ]; then
    emit_issue "PSK027" "bypass-repeated" \
      "repeated bypassing detected — $count_24h bypasses in last 24h; env vars: $unique_summary" \
      "Inspect with: bash agent/scripts/psk-bypass-log.sh list --since-days 1. Resolve the underlying blocker rather than bypassing again."
    return
  fi

  # 1-2 in 24h → WARNING
  if [ "$count_24h" -ge 1 ]; then
    emit_warn "PSK027: $count_24h gate bypass(es) in last 24h; env vars: $unique_summary (run: bash agent/scripts/psk-bypass-log.sh list)"
    return
  fi

  # Reach here only when count_24h==0 but count_7d>=10 was checked above;
  # fall-through is a normal pass.
  emit_pass "PSK027: bypass-tamper audit clean (0/24h, $count_7d/7d)"
}

# --- CHECK PSK030: Script class declaration audit (cycle-19 HF11 + Dim 28 Probe 4) ---
# Every kit script under agent/scripts/psk-*.sh MUST declare its class in the
# header (lines 1-5):
#   - `mechanical-script:` — no AI invocation, pure bash/awk logic
#   - `workflow-router:` — routes sub-agent spawns through psk-spawn.sh / psk-critic-spawn.sh
#   - `ai-invoker:` — directly invokes AI (rare, kit-internal only)
# Detection alternative: script contains `psk-spawn.sh request` (implicit
# workflow-router declaration).
#
# Why: §Spawn Fidelity's audit surface (Dim 28 Probe 4) walks every kit
# script and emits a finding for any psk-* that lacks a class declaration.
# Without this gate, future PRs can land undeclared psk-* scripts, breaking
# the discovery contract that probe relies on. PSK030 closes the loop by
# enforcing declaration at commit time (pre-commit) and at sync-check time.
#
# Bypass: PSK_PSK030_DISABLED=1 (genuine emergencies only).
check_psk030_script_declarations() {
  if [ "${PSK_PSK030_DISABLED:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK030: skipped (PSK_PSK030_DISABLED=1)"
    run_check
    return
  fi

  local scripts_dir="$PROJ_ROOT/agent/scripts"
  if [ ! -d "$scripts_dir" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK030: no agent/scripts/ — skip"
    run_check
    return
  fi

  local undeclared=()
  local f name has_decl has_spawn
  for f in "$scripts_dir"/psk-*.sh; do
    [ ! -f "$f" ] && continue
    name=$(basename "$f")
    # QA-PSK030-FALSE-NEGATIVE-GREP-C-QUOTING fix (cycle-25-pass-001):
    # `grep -c X "$f" 2>/dev/null || echo 0` is broken — when grep finds 0
    # matches it BOTH emits "0\n" AND exits status 1. The `|| echo 0` clause
    # then ALSO fires, yielding "0\n0" (length 3) not "0". The subsequent
    # string compare `[ "$has_spawn" = "0" ]` evaluates false → the file is
    # treated as having spawn references → silently exempted. This hid
    # every undeclared script (e.g. psk-kit-cmd.sh before its header fix).
    # Fix: drop `|| echo 0`, capture grep's stdout directly, default-via-
    # parameter-expansion. grep -c always emits a numeric line on stdout
    # (0 when no match), so the variable is "0" cleanly. The :- default
    # only fires if the pipeline produced no output at all (file missing
    # / unreadable — head -5 protects similarly above but for robustness).
    has_decl=$(head -5 "$f" 2>/dev/null | grep -cE "mechanical-script:|workflow-router:|ai-invoker:")
    has_decl=${has_decl:-0}
    has_spawn=$(grep -c "psk-spawn.sh request" "$f" 2>/dev/null)
    has_spawn=${has_spawn:-0}
    if [ "$has_decl" = "0" ] && [ "$has_spawn" = "0" ]; then
      undeclared+=("$name")
    fi
  done

  if [ "${#undeclared[@]}" -eq 0 ]; then
    local total
    total=$(ls "$scripts_dir"/psk-*.sh 2>/dev/null | wc -l | tr -d ' ')
    emit_pass "PSK030: all $total psk-* scripts declare class (mechanical-script / workflow-router / ai-invoker)"
    run_check
    return
  fi

  local list
  list=$(printf '%s ' "${undeclared[@]}" | sed 's/ $//')
  emit_issue "PSK030" "script-class-undeclared" \
    "${#undeclared[@]} psk-* script(s) missing class declaration: $list" \
    "Add a header comment matching /mechanical-script:|workflow-router:|ai-invoker:/ to each. See §Spawn Fidelity in portable-spec-kit.md for class semantics. Bypass with PSK_PSK030_DISABLED=1 for genuine emergencies."
  run_check
}

check_psk031_duplicate_findings() {
  # v0.6.61 P3 — detect cross-pass findings de-dup gaps.
  # Two patterns flagged:
  #   (a) two recent passes carry findings with identical fingerprints but
  #       different IDs (e.g. QA-D4-03 vs QA-D4-03-WIDENED-CYC20)
  #   (b) a finding's ID is a suffix-variant (-RESIDUAL-*, -WIDENED-*,
  #       -CYC<N>) of a registered canonical but not registered as alias
  # Severity: MAJOR. Bypass: PSK_PSK031_DISABLED=1.
  if [ "${PSK_PSK031_DISABLED:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK031: skipped (PSK_PSK031_DISABLED=1)"
    run_check
    return
  fi

  local registry_sh="$PROJ_ROOT/reflex/lib/findings-registry.sh"
  local registry_yaml="$PROJ_ROOT/reflex/history/findings-registry.yaml"
  if [ ! -x "$registry_sh" ] || [ ! -f "$registry_yaml" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK031: no findings-registry yet — skip"
    run_check
    return
  fi

  local history_dir="$PROJ_ROOT/reflex/history"
  if [ ! -d "$history_dir" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK031: no reflex/history/ — skip"
    run_check
    return
  fi

  # Collect the last 5 cycle-*/pass-*/findings.yaml files
  local yamls
  yamls=$(ls -1t "$history_dir"/cycle-*/pass-*/findings.yaml 2>/dev/null | head -5)
  if [ -z "$yamls" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK031: no recent findings.yaml — skip"
    run_check
    return
  fi

  # Build "id|fingerprint" pairs across recent yamls
  local pairs_tmp
  pairs_tmp=$(mktemp)
  local y id fp
  while IFS= read -r y; do
    [ -z "$y" ] && continue
    while IFS= read -r id; do
      [ -z "$id" ] && continue
      case "$id" in QA-*) ;; *) continue ;; esac
      fp=$(bash "$registry_sh" fingerprint "$y" "$id" 2>/dev/null)
      [ -n "$fp" ] && printf '%s|%s|%s\n' "$id" "$fp" "$(basename "$(dirname "$y")")" >> "$pairs_tmp"
    done < <(grep -E '^[[:space:]]*-[[:space:]]+id:[[:space:]]*' "$y" | awk '{sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/, ""); gsub(/[[:space:]"]+$/, ""); gsub(/^"|"$/, ""); print}')
  done <<< "$yamls"

  # Detect duplicate fingerprints with different IDs across DIFFERENT passes.
  # Same-pass duplicates (within one cycle's findings.yaml) are legitimate
  # (two dim-agents independently filed overlap; registered as internal
  # aliases by file-bugs.sh integration) — don't flag those.
  #
  # KIT-GAP-0012 fix (v0.6.68): consult the findings-registry to skip pairs
  # already linked as aliases of the same canonical. The alias-map lives in
  # an awk-readable temp file (passing a multi-line shell var via `-v`
  # caused parse-instability in earlier attempts).
  local alias_map_tmp
  alias_map_tmp=$(mktemp)
  awk '
    /^[[:space:]]*-[[:space:]]+canonical_id:/ {
      cid=$0; sub(/^[[:space:]]*-[[:space:]]+canonical_id:[[:space:]]*/, "", cid); gsub(/[[:space:]"]+$/, "", cid); gsub(/^"|"$/, "", cid)
      cur=cid; print cur"|"cid
      in_aliases=0; next
    }
    /^[[:space:]]+aliases:[[:space:]]*$/ { in_aliases=1; next }
    in_aliases && /^[[:space:]]+-[[:space:]]+/ {
      a=$0; sub(/^[[:space:]]+-[[:space:]]+/, "", a); gsub(/[[:space:]"]+$/, "", a); gsub(/^"|"$/, "", a)
      if (a != "" && cur != "") print a"|"cur
      next
    }
    /^[a-zA-Z]/ { in_aliases=0 }
  ' "$registry_yaml" 2>/dev/null > "$alias_map_tmp"
  local dup_lines
  dup_lines=$(awk -F'|' '{print $2"\t"$1"\t"$3}' "$pairs_tmp" | sort | awk -F'\t' \
    -v alias_file="$alias_map_tmp" '
    BEGIN {
      while ((getline line < alias_file) > 0) {
        split(line, kv, "|")
        if (kv[1] != "" && kv[2] != "") canon[kv[1]] = kv[2]
      }
      close(alias_file)
    }
    {
      if ($1 == prev_fp && $2 != prev_id && $3 != prev_pass) {
        c_prev = (prev_id in canon) ? canon[prev_id] : prev_id
        c_cur  = ($2 in canon) ? canon[$2] : $2
        if (c_prev != c_cur) print prev_id"\t"$2"\t"$1"\t"prev_pass"→"$3
      }
      prev_fp=$1; prev_id=$2; prev_pass=$3
    }
  ')
  rm -f "$alias_map_tmp"

  # Detect suffix-variant IDs not registered as aliases in the registry.
  #
  # KIT-GAP-0017 fix (v0.6.69 — root-cause refactor): the prior
  # implementation used a per-finding-id shell while-loop with two
  # `printf | sed` and `printf | grep` sub-shell pipes per iteration. For
  # passes with many findings across many cycles, this fanned out into
  # 20-800+ parallel sub-processes that took minutes to complete and
  # blocked every gates.sh invocation (which calls psk-sync-check --full
  # internally). The block now runs entirely in a single awk process:
  # known_ids set is loaded once into an awk hash; each id streams through
  # in-process suffix-stripping + hash lookup. Performance target met:
  # PSK031 completes in <100ms even on registries with 1000+ ids.
  local unreg_aliases=""
  local known_ids_tmp
  known_ids_tmp=$(mktemp)
  {
    grep -E '^[[:space:]]*-[[:space:]]+canonical_id:' "$registry_yaml" \
      | sed -E 's/^[[:space:]]*-[[:space:]]+canonical_id:[[:space:]]*//; s/[[:space:]"]+$//; s/^"|"$//'
    awk '
      /^[[:space:]]+aliases:[[:space:]]*$/ { f=1; next }
      f && /^[[:space:]]+-[[:space:]]+/ {
        a=$0; sub(/^[[:space:]]+-[[:space:]]+/, "", a);
        gsub(/[[:space:]"]+$/, "", a); gsub(/^"|"$/, "", a)
        if (a != "") print a; next
      }
      f && !/^[[:space:]]+-/ { f=0 }
    ' "$registry_yaml"
  } > "$known_ids_tmp"

  unreg_aliases=$(awk -F'|' '{print $1}' "$pairs_tmp" | sort -u | awk -v known_file="$known_ids_tmp" '
    BEGIN {
      while ((getline line < known_file) > 0) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        if (line != "") known[line] = 1
      }
      close(known_file)
      out = ""
    }
    {
      id = $0
      if (id == "") next
      stripped = id
      # KIT-GAP-0048 fix (v0.6.70): two-phase suffix strip. The prior
      # single regex `-[A-Z0-9]+(-CYC[0-9]+)?$` greedy-matched both the
      # CYC segment AND its preceding segment in one sub() call. For id
      # `QA-D5-CVE-PERSISTS-CYC22`, iter1 jumped directly to
      # `QA-D5-CVE`, skipping intermediate `QA-D5-CVE-PERSISTS`. If
      # that intermediate form is the registered canonical, PSK031
      # produced a false negative.
      # New approach: peel -CYC<N> first (one call), then peel -[A-Z0-9]+
      # iteratively. Each segment becomes its own check point so a
      # canonical at any intermediate level matches.
      sub(/-CYC[0-9]+$/, "", stripped)
      if (stripped in known && !(id in known)) {
        out = out " " id "->" stripped
        next
      }
      while (1) {
        prev = stripped
        sub(/-[A-Z0-9]+$/, "", stripped)
        if (stripped == prev) break
        if (stripped in known) {
          if (!(id in known)) {
            out = out " " id "->" stripped
          }
          break
        }
      }
    }
    END {
      if (out != "") {
        sub(/^[[:space:]]+/, "", out)
        print out
      }
    }
  ')

  rm -f "$pairs_tmp" "$known_ids_tmp"

  local dup_count
  dup_count=$(printf '%s\n' "$dup_lines" | grep -cE '.' || true)
  local unreg_count
  unreg_count=$(printf '%s' "$unreg_aliases" | wc -w | tr -d ' ')

  if [ "$dup_count" -eq 0 ] && [ "$unreg_count" -eq 0 ]; then
    emit_pass "PSK031: findings-registry de-dup integrity clean (no duplicate fingerprints, no orphan suffix-variants)"
  else
    local msg=""
    [ "$dup_count" -gt 0 ] && msg="$dup_count duplicate-fingerprint pair(s)"
    if [ "$unreg_count" -gt 0 ]; then
      [ -n "$msg" ] && msg="$msg + "
      msg="${msg}$unreg_count orphan suffix-variant ID(s)"
    fi
    emit_issue "PSK031" "findings-registry-dedup" \
      "$msg detected across recent passes" \
      "Run \`bash reflex/lib/findings-registry.sh bootstrap\` to refresh registry, or audit duplicate findings by fingerprint. Bypass: PSK_PSK031_DISABLED=1"
  fi
  run_check
}

check_psk032_cycle_misuse() {
  # v0.6.61 P1 — detect cycle-numbering misuse pattern.
  # Contract: 1 cycle = 1 autoloop run with multiple passes. If 3+ of the
  # last 5 cycle-NN dirs contain ONLY pass-001 (with verdict.md = not
  # in-flight), the kit's cycle-tracking was bypassed (find_next_pass_dir
  # / .active-cycle / compute_next_cycle_id).
  # Grandfather exemption (v0.6.62): cycles carrying a migration-note.md are
  # documented historical mis-numbering (v0.6.61 P1 "document, not rename")
  # and are skipped from both numerator and denominator — they are an
  # explained one-time artifact, not live cycle-tracking misuse.
  if [ "${PSK_PSK032_DISABLED:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK032: skipped (PSK_PSK032_DISABLED=1)"
    run_check
    return
  fi

  local history_dir="$PROJ_ROOT/reflex/history"
  if [ ! -d "$history_dir" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK032: no reflex/history/ — skip"
    run_check
    return
  fi

  # Collect cycle-NN dirs sorted by numeric N descending (latest first)
  local cycles=()
  local d
  for d in "$history_dir"/cycle-*/; do
    [ -d "$d" ] || continue
    local seg name num
    seg=$(basename "${d%/}")
    if [[ "$seg" =~ ^cycle-0*([0-9]+)$ ]]; then
      num="${BASH_REMATCH[1]}"
      cycles+=("$num:$d")
    fi
  done

  if [ "${#cycles[@]}" -eq 0 ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK032: no cycle-NN dirs — skip"
    run_check
    return
  fi

  # Sort numerically descending; keep top 5
  local sorted
  sorted=$(printf '%s\n' "${cycles[@]}" | sort -t: -k1,1 -n -r | head -5)

  local total_checked=0
  local single_pass_count=0
  local bad_cycles=()
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local cdir="${line#*:}"
    # Grandfather exemption A: a cycle carrying migration-note.md is a documented
    # historical mis-numbering (v0.6.61 P1 "document, not rename" migration).
    # It is not live misuse — skip it from both the numerator and denominator.
    if [ -f "${cdir}migration-note.md" ]; then
      continue
    fi
    total_checked=$((total_checked + 1))
    # Count pass dirs in this cycle
    local pass_count
    pass_count=$(ls -1d "$cdir"pass-*/ 2>/dev/null | wc -l | tr -d ' ')
    if [ "$pass_count" -eq 1 ]; then
      # Verify pass-001 is not in-flight (verdict.md present)
      local p001="${cdir}pass-001"
      if [ -f "$p001/verdict.md" ]; then
        # QA-PSK032-CYCLE-NUMBERING-MISUSE-CYCLE-25 fix:
        # Grandfather exemption B — converged-in-iter-1 cycles are healthy,
        # not misuse. When pass-001 ended GRANTED (verdict converged on first
        # iteration), the autoloop did not need a pass-002 — that is the
        # correct outcome, not a bypass of find_next_pass_dir(). Skip the
        # cycle from both numerator and denominator. PSK032 still fires on
        # cycles where pass-001 ended DENIED (genuine bypass — find_next_pass_dir
        # should have allocated pass-002) OR where the verdict marker is
        # ambiguous (count it as suspect → numerator).
        local verdict_text
        verdict_text=$(head -20 "$p001/verdict.md" 2>/dev/null)
        if echo "$verdict_text" | grep -qE 'GRANTED|verdict:[[:space:]]*GRANTED|## Verdict:[[:space:]]*GRANTED'; then
          # Healthy single-pass converged-in-iter-1 — skip from both
          total_checked=$((total_checked - 1))
          continue
        fi
        single_pass_count=$((single_pass_count + 1))
        bad_cycles+=("$(basename "${cdir%/}")")
      fi
    fi
  done <<< "$sorted"

  # Threshold: 3+ of last 5 cycles have only pass-001 (not in-flight)
  if [ "$single_pass_count" -ge 3 ]; then
    local cycle_list
    cycle_list=$(printf '%s ' "${bad_cycles[@]}" | sed 's/ $//')
    emit_issue "PSK032" "cycle-numbering-misuse" \
      "$single_pass_count of last $total_checked cycles ($cycle_list) have only pass-001 — kit cycle-tracking bypassed (1 cycle = 1 autoloop run; passes within = iterations)" \
      "See docs/work-flows/17-reflex.md §Cycle vs Pass semantics. Verify find_next_pass_dir() / .active-cycle / compute_next_cycle_id() — passes should increment pass-NNN within cycle. Bypass: PSK_PSK032_DISABLED=1"
  else
    emit_pass "PSK032: cycle-numbering pattern healthy ($single_pass_count single-pass of $total_checked recent cycles)"
  fi
  run_check
}

check_psk033_standalone_overuse() {
  # v0.6.61 P2 — detect standalone-pass overuse pattern.
  # Contract: reflex/history/standalone/ is for ad-hoc / one-shot audits,
  # not for convergence work. When the count of pass-* dirs under
  # standalone/ exceeds PSK033_STANDALONE_THRESHOLD (default 10), surface
  # ADVISORY suggesting the operator switch to autoloop. Never blocks.
  if [ "${PSK_PSK033_DISABLED:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK033: skipped (PSK_PSK033_DISABLED=1)"
    run_check
    return
  fi

  local standalone_dir="$PROJ_ROOT/reflex/history/standalone"
  if [ ! -d "$standalone_dir" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK033: no reflex/history/standalone/ — skip"
    run_check
    return
  fi

  local threshold="${PSK033_STANDALONE_THRESHOLD:-10}"
  local count
  count=$(ls -1d "$standalone_dir"/pass-* 2>/dev/null | wc -l | tr -d ' ')

  if [ "$count" -gt "$threshold" ]; then
    emit_issue "PSK033" "standalone-pass-overuse" \
      "$count standalone passes accumulated (threshold $threshold) — repeated 'reflex/run.sh single' invocations fragment audit trail across flat passes" \
      "Switch to autoloop (\`bash reflex/run.sh\` default mode) for convergence work. Standalone is for ad-hoc / one-shot audits only. See docs/work-flows/17-reflex.md §Standalone pass-dir layout. Bypass: PSK_PSK033_DISABLED=1 or raise threshold via PSK033_STANDALONE_THRESHOLD=N."
  else
    emit_pass "PSK033: standalone-pass count healthy ($count of threshold $threshold)"
  fi
  run_check
}

check_psk034_workflow_decl() {
  # v0.6.62 — §Workflow Declaration Schema enforcement (rule was documented in
  # portable-spec-kit.md but never implemented before now). Every script with a
  # `# workflow-router:` header MUST have a matching
  # .portable-spec-kit/workflows/<name>/phases.yml (where <name> derives from
  # psk-<name>.sh), UNLESS it carries `# workflow-decl-exempt:` (dispatcher,
  # plan-driver, session-helper, gate-helper). Bypass: PSK_PSK034_DISABLED=1.
  if [ "${PSK_PSK034_DISABLED:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK034: skipped (PSK_PSK034_DISABLED=1)"
    run_check
    return
  fi
  local scripts_dir="$PROJ_ROOT/agent/scripts"
  local wf_dir="$PROJ_ROOT/.portable-spec-kit/workflows"
  if [ ! -d "$scripts_dir" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK034: no agent/scripts/ — skip"
    run_check
    return
  fi
  local missing=()
  local f base name has_router has_exempt
  for f in "$scripts_dir"/psk-*.sh; do
    [ -f "$f" ] || continue
    has_router=$(head -6 "$f" | grep -cE '^# workflow-router:')
    [ "$has_router" = "0" ] && continue
    has_exempt=$(head -6 "$f" | grep -cE '^# workflow-decl-exempt:')
    [ "$has_exempt" != "0" ] && continue
    base=$(basename "$f" .sh)        # e.g. psk-release
    name="${base#psk-}"              # e.g. release
    if [ ! -f "$wf_dir/$name/phases.yml" ]; then
      missing+=("$base.sh→workflows/$name/phases.yml")
    fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    emit_pass "PSK034: every workflow-router script has a phases.yml declaration (or is decl-exempt)"
    run_check
    return
  fi
  local list
  list=$(printf '%s ' "${missing[@]}" | sed 's/ $//')
  emit_issue "PSK034" "workflow-decl-missing" \
    "${#missing[@]} workflow-router script(s) lack a phases.yml declaration: $list" \
    "Create .portable-spec-kit/workflows/<name>/phases.yml (see §Workflow Declaration Schema in portable-spec-kit.md) OR add a '# workflow-decl-exempt: <reason>' header line if the script is a dispatcher / plan-driver / helper. Bypass: PSK_PSK034_DISABLED=1."
  run_check
}

check_psk035_phases_schema() {
  # v0.6.62 — §Workflow Declaration Schema validation (rule documented but never
  # implemented before now). Every .portable-spec-kit/workflows/*/phases.yml MUST
  # carry the required top-level fields: schema_version, workflow, phases.
  # Bypass: PSK_PSK035_DISABLED=1.
  if [ "${PSK_PSK035_DISABLED:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK035: skipped (PSK_PSK035_DISABLED=1)"
    run_check
    return
  fi
  local wf_dir="$PROJ_ROOT/.portable-spec-kit/workflows"
  if [ ! -d "$wf_dir" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK035: no workflows/ — skip"
    run_check
    return
  fi
  local bad=()
  local y name
  for y in "$wf_dir"/*/phases.yml; do
    [ -f "$y" ] || continue
    name=$(basename "$(dirname "$y")")
    grep -qE '^schema_version:' "$y" || { bad+=("$name:no-schema_version"); continue; }
    grep -qE '^workflow:' "$y"       || { bad+=("$name:no-workflow"); continue; }
    grep -qE '^phases:' "$y"         || { bad+=("$name:no-phases"); continue; }
  done
  if [ "${#bad[@]}" -eq 0 ]; then
    local total
    total=$(ls -1 "$wf_dir"/*/phases.yml 2>/dev/null | wc -l | tr -d ' ')
    emit_pass "PSK035: all $total phases.yml carry required schema fields (schema_version / workflow / phases)"
    run_check
    return
  fi
  local list
  list=$(printf '%s ' "${bad[@]}" | sed 's/ $//')
  emit_issue "PSK035" "phases-schema-invalid" \
    "${#bad[@]} phases.yml fail schema validation: $list" \
    "Every .portable-spec-kit/workflows/<name>/phases.yml must declare schema_version:, workflow:, and phases: (see §Workflow Declaration Schema). Bypass: PSK_PSK035_DISABLED=1."
  run_check
}

# --- CHECK PSK040: §Kit Fidelity deviation-log coverage (v0.6.64+) ---
# Every commit since the §Kit Fidelity introduction whose subject matches a
# marker_commit_pattern from .portable-spec-kit/kit-commands.yml MUST have a
# matching entry in agent/.kit-deviation-log. Catches the case where the agent
# bypasses the psk-kit-cmd.sh wrapper but commits anyway.
# Severity: ADVISORY in --quick mode, ERROR in --full mode (pre-commit blocks).
# Bypass: PSK_PSK040_DISABLED=1.
check_psk040_kit_fidelity_coverage() {
  if [ "${PSK_PSK040_DISABLED:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK040: skipped (PSK_PSK040_DISABLED=1)"
    run_check
    return
  fi
  local inventory="$PROJ_ROOT/.portable-spec-kit/kit-commands.yml"
  local dev_log="$PROJ_ROOT/agent/.kit-deviation-log"
  if [ ! -f "$inventory" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK040: no kit-commands.yml — skip (kit pre-v0.6.64)"
    run_check
    return
  fi

  # Read marker_commit_patterns from inventory
  local patterns
  patterns=$(awk '
    /^marker_commit_patterns:/ { in_block=1; next }
    in_block && /^  - pattern:/ {
      sub(/^[[:space:]]+- pattern: */, "", $0)
      gsub(/^"|"$/, "", $0)
      print $0
    }
    in_block && /^[^[:space:]#]/ && !/^marker_commit_patterns:/ { in_block=0 }
  ' "$inventory")

  if [ -z "$patterns" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK040: no marker_commit_patterns defined — skip"
    run_check
    return
  fi

  # The §Kit Fidelity introduction commit is the first commit that added
  # portable-spec-kit.md text matching "## Kit Fidelity". Find it dynamically
  # so the check works across kit-version upgrades.
  local intro_sha
  intro_sha=$(git -C "$PROJ_ROOT" log --diff-filter=A --pickaxe-regex \
    -S '^## Kit Fidelity ' --pretty=format:%H -- portable-spec-kit.md 2>/dev/null \
    | tail -1)
  if [ -z "$intro_sha" ]; then
    # Fallback: scan all commits where portable-spec-kit.md gained "Kit Fidelity" section
    intro_sha=$(git -C "$PROJ_ROOT" log --pickaxe-regex \
      -S '^## Kit Fidelity ' --reverse --pretty=format:%H -- portable-spec-kit.md 2>/dev/null \
      | head -1)
  fi
  if [ -z "$intro_sha" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK040: §Kit Fidelity not yet committed — skip"
    run_check
    return
  fi

  # KIT-GAP-0049 fix #2 (v0.6.70): single-awk-pass replacement for the
  # per-commit-per-pattern grep loop. The prior implementation walked
  # ~291 commits × 2 patterns × 3 subshells/iter = ~1,750 potential
  # subshells per invocation, taking ~1.55s. New code: one `git log
  # --pretty="%H|%ad|%s" --date=short` invocation + one awk pass that
  # holds the patterns + whitelist + deviation-log-dates in arrays.
  #
  # Recursion-fix (v0.6.67) whitelist preserved: release-ceremony +
  # KIT-GAP closer commits sit OUTSIDE §Kit Fidelity workaround scope.
  local dev_log_dates_tmp
  dev_log_dates_tmp=$(mktemp)
  if [ -f "$dev_log" ]; then
    awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2}/ { print substr($0, 1, 10) }' "$dev_log" | sort -u > "$dev_log_dates_tmp"
  fi

  local violations_raw
  violations_raw=$(git -C "$PROJ_ROOT" log --pretty=format:'%H|%ad|%s' --date=short "$intro_sha..HEAD" 2>/dev/null \
    | awk -F'|' \
        -v patterns_raw="$patterns" \
        -v dev_log_dates_file="$dev_log_dates_tmp" '
    BEGIN {
      n = split(patterns_raw, parr, "\n")
      pcount = 0
      for (i = 1; i <= n; i++) {
        p = parr[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", p)
        if (p != "") {
          pcount++
          patterns[pcount] = p
        }
      }
      while ((getline line < dev_log_dates_file) > 0) {
        gsub(/[[:space:]]/, "", line)
        if (line != "") dev_dates[line] = 1
      }
      close(dev_log_dates_file)
    }
    {
      commit = $1; cdate = $2; subject = $3
      if (commit == "") next
      # Whitelist legitimate release/KIT-GAP commits (v0.6.67 recursion fix).
      if (subject ~ /^release: v[0-9]/)            next
      if (subject ~ /^fix\(KIT-GAP-[0-9]+\)/)      next
      if (subject ~ /^v[0-9]+\.[0-9]+\.[0-9]+:/)   next
      if (subject ~ /^chore\(release\)/)           next
      if (subject ~ /^docs\(release\)/)            next
      # Match each pattern; on first hit verify deviation-log has matching date.
      for (i = 1; i <= pcount; i++) {
        if (subject ~ patterns[i]) {
          if (!(cdate in dev_dates)) {
            printf "%s:%s\n", commit, subject
          }
          break
        }
      }
    }
  ')
  rm -f "$dev_log_dates_tmp"

  local violations=()
  if [ -n "$violations_raw" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && violations+=("$line")
    done <<< "$violations_raw"
  fi

  if [ "${#violations[@]}" -eq 0 ]; then
    emit_pass "PSK040: §Kit Fidelity deviation-log coverage clean (0 unaudited marker commits)"
    run_check
    return
  fi

  local list
  list=$(printf '  - %s\n' "${violations[@]}" | head -5)
  if [ "$QUICK" = true ]; then
    # Advisory in --quick (PostToolUse hook): warn but don't block
    echo -e "  ${YELLOW}⚠${NC} PSK040: ${#violations[@]} unaudited marker commit(s) since §Kit Fidelity intro"
    echo "$list" | head -3
    run_check
    return
  fi
  # Error in --full (pre-commit hook): block
  emit_issue "PSK040" "kit-fidelity-coverage" \
    "${#violations[@]} marker-shaped commit(s) since §Kit Fidelity intro have no matching agent/.kit-deviation-log entry: $(printf '%s; ' "${violations[@]}" | head -c 200)" \
    "Each non-canonical kit-command invocation must route through psk-kit-cmd.sh with --rationale, which appends to agent/.kit-deviation-log. Bypass: PSK_PSK040_DISABLED=1."
  run_check
}

# --- CHECK PSK041: KIT-GAP pending-disposition audit (v0.6.66 KIT-GAP-0008 fix) ---
# When an agent files a KIT-GAP via psk-kit-cmd.sh --log-gap, a pending-disposition
# marker is written to agent/.workflow-state/pending-kit-gap/<gap-id>.pending.
# Disposition must be set to "kit-fixed" (a commit message that references the
# KIT-GAP-NNNN) OR "escalated" (operator explicitly chose to defer).
# Pending markers older than 1 commit (since their filing time) indicate the
# "filed-then-workaround" anti-pattern §Kit Fidelity was supposed to prevent.
# Severity: ADVISORY in --quick mode, ERROR in --full mode.
# Bypass: PSK_PSK041_DISABLED=1.
check_psk041_kit_gap_disposition() {
  if [ "${PSK_PSK041_DISABLED:-0}" = "1" ]; then
    [ "$QUICK" = false ] && echo -e "  ${YELLOW}⚠${NC} PSK041: skipped (PSK_PSK041_DISABLED=1)"
    run_check
    return
  fi
  local pending_dir="$PROJ_ROOT/agent/.workflow-state/pending-kit-gap"
  if [ ! -d "$pending_dir" ]; then
    [ "$QUICK" = false ] && echo -e "  ${GREEN}✓${NC} PSK041: no pending-kit-gap dir — skip"
    run_check
    return
  fi

  # Find pending markers + check disposition against git log
  local pending_files
  pending_files=$(find "$pending_dir" -maxdepth 1 -name '*.pending' -type f 2>/dev/null)
  if [ -z "$pending_files" ]; then
    emit_pass "PSK041: KIT-GAP disposition — 0 pending markers"
    run_check
    return
  fi

  local violations=()
  local f gap_id ts_str ts_epoch now_epoch age_sec disposition
  now_epoch=$(date +%s)
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    gap_id=$(grep '^id=' "$f" 2>/dev/null | head -1 | cut -d= -f2)
    ts_str=$(grep '^ts=' "$f" 2>/dev/null | head -1 | cut -d= -f2)
    disposition=$(grep '^disposition=' "$f" 2>/dev/null | head -1 | cut -d= -f2)

    [ -z "$gap_id" ] && continue
    # Recursion-fix (v0.6.67): legitimate-exception taxonomy. Only "pending"
    # markers are checked. Operator-controlled non-pending states all skip:
    #   deferred     — postponed to a future version (via --defer flag)
    #   escalated    — operator-only decision required, routed elsewhere
    #   bypassed     — used canonical bypass flag (e.g. --skip-preconditions)
    #   kit-fixed    — fix landed in a commit referencing the gap_id
    #   outside-repo — fix lives outside tracked files (e.g. .git/hooks/)
    # Unknown values also skip — operator must use canonical names.
    case "$disposition" in
      pending) ;;
      *) continue ;;
    esac

    # Convert ts to epoch (macOS-compatible)
    ts_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$ts_str" +%s 2>/dev/null || echo "0")
    [ "$ts_epoch" = "0" ] && continue
    age_sec=$((now_epoch - ts_epoch))

    # Check if any commit since filing references the gap_id.
    # Use --all so commits on main (outside the current branch's first-parent
    # ancestry) are considered too. Collapse newlines so the result is a single
    # integer — earlier "|| echo 0" appended a second "0" line when grep
    # produced no output, breaking the [ "$matched" = "0" ] comparison.
    # KIT-GAP-0017 follow-up (v0.6.69 synthesis): replaced the
    # xargs-git-log-per-commit storm with git's native --grep filter.
    # Old code spawned ~one `git log -1` per commit since the marker's
    # timestamp; the new code searches the full commit-message corpus
    # in one git invocation. At ~35 commits/day × 11 pending markers
    # this drops 385 forks per --quick run to ~11.
    local matched
    matched=$(git -C "$PROJ_ROOT" log --all --since="@$ts_epoch" \
      --grep="$gap_id" --pretty=format:%H 2>/dev/null | wc -l | tr -d ' \n')
    [ -z "$matched" ] && matched=0

    if [ "$matched" -eq 0 ] && [ "$age_sec" -gt 60 ]; then
      # No commit references this gap and it's been >1min since filing
      violations+=("$gap_id (age=${age_sec}s, no commit references it)")
    fi
  done <<< "$pending_files"

  if [ "${#violations[@]}" -eq 0 ]; then
    emit_pass "PSK041: KIT-GAP disposition — 0 pending workarounds"
    run_check
    return
  fi

  local list
  list=$(printf '%s; ' "${violations[@]}" | head -c 200)
  if [ "$QUICK" = true ]; then
    echo -e "  ${YELLOW}⚠${NC} PSK041: ${#violations[@]} undispositioned KIT-GAP marker(s) — possible workaround anti-pattern"
    echo "    $list"
    run_check
    return
  fi
  emit_issue "PSK041" "kit-gap-disposition" \
    "${#violations[@]} pending KIT-GAP marker(s) without matching fix-commit: $list" \
    "Each pending marker means a KIT-GAP was filed but no commit since references it. Either commit the kit fix (with KIT-GAP-NNNN in commit message) OR set disposition=escalated in agent/.workflow-state/pending-kit-gap/<gap>.pending. Bypass: PSK_PSK041_DISABLED=1."
  run_check
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
    check_kit_version_drift
    check_reflex_protected_files
    check_plan_schema
    check_ui_completeness
    check_cascade_anti_pattern
    check_resume_bootstrap
    check_psk031_duplicate_findings
    check_psk032_cycle_misuse
    check_psk033_standalone_overuse
    check_psk034_workflow_decl
    check_psk035_phases_schema
    check_psk040_kit_fidelity_coverage
    check_psk041_kit_gap_disposition
  else
    # Full: all checks (expanded v0.5.9 with content validation, v0.5.13 with secrets)
    check_version
    check_test_count
    check_kit_version_drift
    check_flow_count
    check_feature_count
    check_specs_staleness
    check_rft_gate
    check_feature_criteria_blocks
    check_script_perms
    check_required_scripts
    check_required_dirs
    check_stub_paths
    check_current_version_docs
    check_ard_content
    check_agent_md_stack
    check_readme_content
    check_readme_install_list
    check_installer_manifest
    check_readme_agent_table
    check_readme_flow_table
    check_flow_docs_content
    check_flow_doc_template
    check_template_choice
    check_src_subdir_layout
    check_template_quality
    check_critic_prompts_comprehensive
    check_secrets
    check_reflex_protected_files
    check_reqs_coverage
    check_ui_requirements_coverage
    check_summary_csv_completeness
    check_plan_schema
    check_ui_completeness
    check_cascade_anti_pattern
    check_resume_bootstrap
    check_psk026_critic_completeness
    check_psk027_bypass_audit
    check_psk030_script_declarations
    check_psk031_duplicate_findings
    check_psk032_cycle_misuse
    check_psk033_standalone_overuse
    check_psk034_workflow_decl
    check_psk035_phases_schema
    check_psk040_kit_fidelity_coverage
    check_psk041_kit_gap_disposition
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
