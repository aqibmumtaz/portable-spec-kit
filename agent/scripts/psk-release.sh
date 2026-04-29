#!/bin/bash
# =============================================================
# psk-release.sh — Release Process Executor (v3)
#
# 10-step release pipeline. Dual gate at Step 9.
# Workflow doc: docs/work-flows/13-release-workflow.md
#
# Automated (script runs directly): 1,2,3,5,6,7,10
# Agent-required (pause, agent works, verify): 4,8
# Dual final gate (bash sync-check + sub-agent critic): 9
#
# Reliability model — "dual at end of workflow":
#   Steps 1-8: bash critic runs at each automated step; agent
#   steps 4+8 verified by mtime check. These keep the release
#   moving and catch mechanical drift.
#   Step 9: THE GATE. Both bash critic (deterministic) and
#   sub-agent critic (semantic) must pass. Either failure
#   blocks the release.
#
# Step 6 (Version Bump) is FULLY AUTOMATED — computes next
# patch and seds all files. No agent action needed.
#
# Usage:
#   bash agent/scripts/psk-release.sh prepare     # full release
#   bash agent/scripts/psk-release.sh refresh      # no version bump
#   bash agent/scripts/psk-release.sh next         # run next step
#   bash agent/scripts/psk-release.sh done         # mark agent step done
#   bash agent/scripts/psk-release.sh status       # show progress
#   bash agent/scripts/psk-release.sh reset        # clear state
#
# Exit codes:
#   0 = step completed (or all done)
#   1 = step failed / agent action needed
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
STATE_DIR="$SCRIPT_DIR/../.release-state"
STATE_FILE="$STATE_DIR/state"
CRITIC_DIR="$STATE_DIR"
CONFIG_FILE="$PROJ_ROOT/.portable-spec-kit/config.md"
SYNC_CHECK="$SCRIPT_DIR/psk-sync-check.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

MODE="${1:-status}"

ALL_STEPS="STEP_1_TESTS STEP_2_CODE_REVIEW STEP_3_SCOPE_CHECK STEP_4_FLOW_DOCS STEP_5_COUNTS STEP_6_VERSION STEP_7_PDFS STEP_8_RELEASES STEP_9_VALIDATION STEP_10_SUMMARY"

# --- State management ---
init_state() {
  mkdir -p "$STATE_DIR"
  # Clear prior critic artifacts so stale CURRENT reports can't satisfy this run's gate
  rm -f "$STATE_DIR/critic-task.md" "$STATE_DIR/critic-result.md" "$STATE_DIR/critic-iterations" "$STATE_DIR/.validate-stamp"
  local start_ver
  start_ver=$(grep -E '^\- \*\*Version:\*\*' "$PROJ_ROOT/agent/AGENT_CONTEXT.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  cat > "$STATE_FILE" <<EOF
RELEASE_MODE=$MODE
STEP_1_TESTS=pending
STEP_2_CODE_REVIEW=pending
STEP_3_SCOPE_CHECK=pending
STEP_4_FLOW_DOCS=pending
STEP_5_COUNTS=pending
STEP_6_VERSION=pending
STEP_7_PDFS=pending
STEP_8_RELEASES=pending
STEP_9_VALIDATION=pending
STEP_10_SUMMARY=pending
RUN_ID=$(date +%s)
STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
START_VERSION=${start_ver:-unknown}
EOF
  echo -e "${GREEN}Release process started: $MODE (base: ${start_ver:-unknown})${NC}"
}

# Freshness check: refuses to resume a state file that's stale in TIME or VERSION.
# Caught by: v0.5.20 release — stale state from v0.5.19 attempt silently
# carried "done" markers across to today's v0.5.20 work.
state_is_stale() {
  [ -f "$STATE_FILE" ] || return 1

  local run_id cur_ts age_sec start_ver cur_ver
  run_id=$(get_run_id)
  cur_ts=$(date +%s)
  [ -z "$run_id" ] && return 0   # no RUN_ID = treat as stale
  age_sec=$((cur_ts - run_id))
  if [ "$age_sec" -gt 86400 ]; then
    echo -e "${YELLOW}State file is $((age_sec / 3600))h old (RUN_ID $run_id).${NC}" >&2
    return 0
  fi

  start_ver=$(grep "^START_VERSION=" "$STATE_FILE" 2>/dev/null | cut -d= -f2)
  cur_ver=$(grep -E '^\- \*\*Version:\*\*' "$PROJ_ROOT/agent/AGENT_CONTEXT.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  # STEP_6 bumps version intentionally — only flag version mismatch if STEP_6 is still pending
  # (i.e., version drift occurred outside the release flow, which is what we want to catch).
  if [ -n "$start_ver" ] && [ -n "$cur_ver" ] && [ "$start_ver" != "$cur_ver" ]; then
    if [ "$(get_state STEP_6_VERSION)" = "pending" ]; then
      echo -e "${YELLOW}AGENT_CONTEXT version is $cur_ver but state was started at $start_ver (Step 6 not yet run).${NC}" >&2
      return 0
    fi
  fi

  return 1
}

mark_done() {
  local step="$1"
  sed -i '' "s/^${step}=pending/${step}=done/" "$STATE_FILE" 2>/dev/null || \
  sed -i "s/^${step}=pending/${step}=done/" "$STATE_FILE" 2>/dev/null
}

get_state() {
  local step="$1"
  grep "^${step}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2
}

get_release_mode() {
  grep "^RELEASE_MODE=" "$STATE_FILE" 2>/dev/null | cut -d= -f2
}

get_run_id() {
  grep "^RUN_ID=" "$STATE_FILE" 2>/dev/null | cut -d= -f2
}

get_next_step() {
  for step in $ALL_STEPS; do
    if [ "$(get_state "$step")" = "pending" ]; then
      echo "$step"
      return
    fi
  done
  echo "ALL_DONE"
}

config_enabled() {
  local key="$1"
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "false"
    return
  fi
  local val
  val=$(grep -i "$key" "$CONFIG_FILE" 2>/dev/null | grep -oi 'true\|false' | tail -1)
  echo "${val:-false}"
}

show_status() {
  if [ ! -f "$STATE_FILE" ]; then
    echo "No release in progress. Run: bash agent/scripts/psk-release.sh prepare"
    return
  fi

  echo ""
  echo "══════════════════════════════════════════════"
  echo "  RELEASE PROGRESS — $(get_release_mode)"
  echo "══════════════════════════════════════════════"

  if state_is_stale; then
    echo -e "  ${YELLOW}⚠ State is stale — 'next' will refuse. Run: psk-release.sh prepare${NC}"
    echo "──────────────────────────────────────────────"
  fi

  local labels=("Tests" "Code Review" "Scope Check" "Flow Docs" "Counts" "Version" "PDFs" "RELEASES" "Validation" "Summary")
  local i=0

  for step in $ALL_STEPS; do
    local state
    state=$(get_state "$step")
    local label="${labels[$i]}"
    if [ "$state" = "done" ]; then
      printf "  %2d. %-14s ${GREEN}✅ done${NC}\n" $((i+1)) "$label"
    else
      printf "  %2d. %-14s ${YELLOW}⏳ pending${NC}\n" $((i+1)) "$label"
    fi
    i=$((i+1))
  done

  local next
  next=$(get_next_step)
  echo ""
  if [ "$next" = "ALL_DONE" ]; then
    echo -e "  ${GREEN}All steps completed. Ready to commit + push.${NC}"
  else
    local step_num
    step_num=$(echo "$next" | grep -o '[0-9]*' | head -1)
    echo -e "  ${YELLOW}Next: Step $step_num${NC}"
  fi
  echo "══════════════════════════════════════════════"
}

# === AUTOMATED STEPS ===

run_step_1_tests() {
  echo -e "${CYAN}═══ Step 1: Running all test suites ═══${NC}"
  local fail=0

  echo -e "\n${CYAN}--- test-spec-kit.sh ---${NC}"
  if bash "$PROJ_ROOT/tests/test-spec-kit.sh"; then
    echo -e "${GREEN}  Framework tests: PASSED${NC}"
  else
    echo -e "${RED}  Framework tests: FAILED${NC}"
    fail=1
  fi

  echo -e "\n${CYAN}--- test-spd-benchmarking.sh ---${NC}"
  if bash "$PROJ_ROOT/tests/test-spd-benchmarking.sh"; then
    echo -e "${GREEN}  Benchmarking tests: PASSED${NC}"
  else
    echo -e "${RED}  Benchmarking tests: FAILED${NC}"
    fail=1
  fi

  echo -e "\n${CYAN}--- test-release-check.sh ---${NC}"
  if bash "$PROJ_ROOT/tests/test-release-check.sh" "$PROJ_ROOT/agent/SPECS.md"; then
    echo -e "${GREEN}  Release check: PASSED${NC}"
  else
    echo -e "${RED}  Release check: FAILED${NC}"
    fail=1
  fi

  if [ "$fail" -eq 1 ]; then
    echo -e "\n${RED}Step 1 FAILED — fix test failures, then: psk-release.sh next${NC}"
    return 1
  fi

  echo -e "\n${GREEN}Step 1 PASSED — all suites green${NC}"
  mark_done "STEP_1_TESTS"
  return 0
}

run_step_2_code_review() {
  echo -e "${CYAN}═══ Step 2: Code Review ═══${NC}"
  local enabled
  enabled=$(config_enabled "In release pipeline")

  if [ "$enabled" != "true" ]; then
    echo -e "${YELLOW}  Code review disabled in config — skipping${NC}"
    mark_done "STEP_2_CODE_REVIEW"
    return 0
  fi

  if [ -f "$PROJ_ROOT/agent/scripts/psk-code-review.sh" ]; then
    bash "$PROJ_ROOT/agent/scripts/psk-code-review.sh"
    echo -e "${GREEN}  Code review complete (advisory)${NC}"
  else
    echo -e "${YELLOW}  psk-code-review.sh not found — skipping${NC}"
  fi

  mark_done "STEP_2_CODE_REVIEW"
  return 0
}

run_step_3_scope_check() {
  echo -e "${CYAN}═══ Step 3: Scope Drift Check ═══${NC}"
  local enabled
  enabled=$(config_enabled "In release pipeline")

  if [ "$enabled" != "true" ]; then
    echo -e "${YELLOW}  Scope check disabled in config — skipping${NC}"
    mark_done "STEP_3_SCOPE_CHECK"
    return 0
  fi

  if [ -f "$PROJ_ROOT/agent/scripts/psk-scope-check.sh" ]; then
    bash "$PROJ_ROOT/agent/scripts/psk-scope-check.sh"
    echo -e "${GREEN}  Scope check complete (advisory)${NC}"
  else
    echo -e "${YELLOW}  psk-scope-check.sh not found — skipping${NC}"
  fi

  mark_done "STEP_3_SCOPE_CHECK"
  return 0
}

run_step_5_counts() {
  echo -e "${CYAN}═══ Step 5: Consistency Sweep (psk-sync-check.sh + manifest validation) ═══${NC}"

  if [ ! -x "$SYNC_CHECK" ]; then
    echo -e "${YELLOW}  psk-sync-check.sh not found — skipping automated check${NC}"
    echo -e "${YELLOW}  Agent: verify counts manually, then call done${NC}"
    return 1
  fi

  if ! bash "$SYNC_CHECK" --full; then
    echo -e "\n${RED}Step 5 FAILED — fix mismatches reported above, then: psk-release.sh next${NC}"
    return 1
  fi

  # v0.6.14 — Manifest validation (advisory, non-blocking).
  # For any stack detected by psk-env.sh, verify the appropriate manifest
  # exists and is non-empty. Per §Environment Selection: detected stack
  # without a manifest = the project can't be installed by other contributors.
  # The kit itself has no detected stack (pure markdown + bash) so this
  # gracefully no-ops; user projects with package.json / requirements.txt
  # / Gemfile / go.mod / Cargo.toml get validated.
  local env_sh="$SCRIPT_DIR/psk-env.sh"
  if [ -x "$env_sh" ]; then
    echo ""
    echo -e "${CYAN}  Manifest check (advisory):${NC}"
    local detected_stacks
    detected_stacks=$(bash "$env_sh" detect 2>/dev/null)
    local missing_manifests=0
    if [ -z "$detected_stacks" ]; then
      echo -e "${GREEN}    ✓ No runtime stack detected (kit-only / docs-only project)${NC}"
    else
      local stack
      while IFS= read -r stack; do
        [ -z "$stack" ] && continue
        case "$stack" in
          python)
            if [ -f "$PROJ_ROOT/requirements.txt" ] || [ -f "$PROJ_ROOT/pyproject.toml" ] || [ -f "$PROJ_ROOT/setup.py" ] || [ -f "$PROJ_ROOT/Pipfile" ]; then
              echo -e "${GREEN}    ✓ python: manifest present${NC}"
            else
              echo -e "${YELLOW}    ⚠ python: detected but no manifest (requirements.txt / pyproject.toml / setup.py / Pipfile)${NC}"
              missing_manifests=$((missing_manifests + 1))
            fi ;;
          node)
            if [ -f "$PROJ_ROOT/package.json" ]; then
              echo -e "${GREEN}    ✓ node: package.json present${NC}"
            else
              echo -e "${YELLOW}    ⚠ node: detected but no package.json${NC}"
              missing_manifests=$((missing_manifests + 1))
            fi ;;
          ruby)   [ -f "$PROJ_ROOT/Gemfile" ]    && echo -e "${GREEN}    ✓ ruby: Gemfile present${NC}"    || { echo -e "${YELLOW}    ⚠ ruby: no Gemfile${NC}";    missing_manifests=$((missing_manifests + 1)); } ;;
          go)     [ -f "$PROJ_ROOT/go.mod" ]     && echo -e "${GREEN}    ✓ go: go.mod present${NC}"     || { echo -e "${YELLOW}    ⚠ go: no go.mod${NC}";     missing_manifests=$((missing_manifests + 1)); } ;;
          rust)   [ -f "$PROJ_ROOT/Cargo.toml" ] && echo -e "${GREEN}    ✓ rust: Cargo.toml present${NC}" || { echo -e "${YELLOW}    ⚠ rust: no Cargo.toml${NC}"; missing_manifests=$((missing_manifests + 1)); } ;;
        esac
      done <<< "$detected_stacks"
    fi
    # Kit-author-only: REQUIREMENTS.md system-prereqs doc check
    if [ -f "$PROJ_ROOT/portable-spec-kit.md" ] && [ ! -L "$PROJ_ROOT/portable-spec-kit.md" ]; then
      # We're in the kit repo (regular file, not symlink). Verify REQUIREMENTS.md exists.
      if [ -f "$PROJ_ROOT/REQUIREMENTS.md" ]; then
        echo -e "${GREEN}    ✓ kit: REQUIREMENTS.md present (system prereqs)${NC}"
      else
        echo -e "${YELLOW}    ⚠ kit: REQUIREMENTS.md missing — system-prereqs doc absent${NC}"
        missing_manifests=$((missing_manifests + 1))
      fi
    fi
    if [ "$missing_manifests" -gt 0 ]; then
      echo -e "${YELLOW}    Total missing manifests: $missing_manifests (advisory; non-blocking)${NC}"
    fi

    # v0.6.14 — Lock-file freshness check + auto-regenerate per stack.
    # When a manifest (package.json, requirements.txt, Gemfile, go.mod, Cargo.toml)
    # is newer than its lock file, the lock is stale — regenerate to keep the
    # project reproducible. Manifests are NEVER auto-modified (human judgment
    # for version bumps); only lock files (deterministic from manifest).
    # Each per-stack regenerate runs inside the project's saved env via
    # psk-env.sh activate-cmd <stack>. Failures are advisory, non-blocking.
    if [ -n "$detected_stacks" ]; then
      echo ""
      echo -e "${CYAN}  Lock-file freshness (auto-regenerate when stale):${NC}"
      local stale_count=0 regenerated=0
      while IFS= read -r stack; do
        [ -z "$stack" ] && continue
        local prefix
        prefix=$(bash "$env_sh" activate-cmd "$stack" 2>/dev/null)
        case "$stack" in
          node)
            local manifest="$PROJ_ROOT/package.json"
            local lock="$PROJ_ROOT/package-lock.json"
            if [ -f "$manifest" ] && [ -f "$lock" ] && [ "$lock" -ot "$manifest" ]; then
              echo -e "${YELLOW}    ⚠ node: package-lock.json is older than package.json — regenerating...${NC}"
              if (cd "$PROJ_ROOT" && bash -c "$prefix npm install --package-lock-only --legacy-peer-deps" >/dev/null 2>&1); then
                echo -e "${GREEN}    ✓ node: package-lock.json regenerated${NC}"
                regenerated=$((regenerated + 1))
              else
                echo -e "${YELLOW}      regenerate failed — run 'npm install' manually${NC}"
              fi
              stale_count=$((stale_count + 1))
            elif [ -f "$lock" ]; then
              echo -e "${GREEN}    ✓ node: package-lock.json fresh${NC}"
            elif [ -f "$manifest" ]; then
              echo -e "${YELLOW}    ⚠ node: package.json present but no package-lock.json — run 'npm install' to generate${NC}"
            fi ;;
          python)
            # Python lock-file conventions vary by manager — only auto-update
            # when the manager is known. Otherwise just report staleness.
            if [ -f "$PROJ_ROOT/poetry.lock" ] && [ -f "$PROJ_ROOT/pyproject.toml" ] && [ "$PROJ_ROOT/poetry.lock" -ot "$PROJ_ROOT/pyproject.toml" ]; then
              echo -e "${YELLOW}    ⚠ python: poetry.lock stale — regenerating...${NC}"
              if (cd "$PROJ_ROOT" && bash -c "$prefix poetry lock --no-update" >/dev/null 2>&1); then
                echo -e "${GREEN}    ✓ python: poetry.lock regenerated${NC}"
                regenerated=$((regenerated + 1))
              else
                echo -e "${YELLOW}      regenerate failed — run 'poetry lock' manually${NC}"
              fi
              stale_count=$((stale_count + 1))
            elif [ -f "$PROJ_ROOT/uv.lock" ] && [ -f "$PROJ_ROOT/pyproject.toml" ] && [ "$PROJ_ROOT/uv.lock" -ot "$PROJ_ROOT/pyproject.toml" ]; then
              echo -e "${YELLOW}    ⚠ python: uv.lock stale — regenerating...${NC}"
              if (cd "$PROJ_ROOT" && bash -c "$prefix uv lock" >/dev/null 2>&1); then
                echo -e "${GREEN}    ✓ python: uv.lock regenerated${NC}"
                regenerated=$((regenerated + 1))
              else
                echo -e "${YELLOW}      regenerate failed — run 'uv lock' manually${NC}"
              fi
              stale_count=$((stale_count + 1))
            elif [ -f "$PROJ_ROOT/Pipfile.lock" ] && [ -f "$PROJ_ROOT/Pipfile" ] && [ "$PROJ_ROOT/Pipfile.lock" -ot "$PROJ_ROOT/Pipfile" ]; then
              echo -e "${YELLOW}    ⚠ python: Pipfile.lock stale — run 'pipenv lock'${NC}"
              stale_count=$((stale_count + 1))
            elif [ -f "$PROJ_ROOT/requirements.txt" ]; then
              echo -e "${GREEN}    ✓ python: requirements.txt present (no lock-file convention for plain pip)${NC}"
            else
              echo -e "${GREEN}    ✓ python: no lock-file staleness detected${NC}"
            fi ;;
          ruby)
            if [ -f "$PROJ_ROOT/Gemfile.lock" ] && [ -f "$PROJ_ROOT/Gemfile" ] && [ "$PROJ_ROOT/Gemfile.lock" -ot "$PROJ_ROOT/Gemfile" ]; then
              echo -e "${YELLOW}    ⚠ ruby: Gemfile.lock stale — regenerating...${NC}"
              if (cd "$PROJ_ROOT" && bash -c "$prefix bundle install --quiet" >/dev/null 2>&1); then
                echo -e "${GREEN}    ✓ ruby: Gemfile.lock regenerated${NC}"
                regenerated=$((regenerated + 1))
              else
                echo -e "${YELLOW}      regenerate failed — run 'bundle install' manually${NC}"
              fi
              stale_count=$((stale_count + 1))
            elif [ -f "$PROJ_ROOT/Gemfile" ]; then
              echo -e "${GREEN}    ✓ ruby: Gemfile.lock fresh (or absent — first install)${NC}"
            fi ;;
          go)
            if [ -f "$PROJ_ROOT/go.mod" ]; then
              # go.sum is the lock; `go mod tidy` regenerates it
              if [ -f "$PROJ_ROOT/go.sum" ] && [ "$PROJ_ROOT/go.sum" -ot "$PROJ_ROOT/go.mod" ]; then
                echo -e "${YELLOW}    ⚠ go: go.sum stale — running 'go mod tidy'...${NC}"
                if (cd "$PROJ_ROOT" && bash -c "$prefix go mod tidy" >/dev/null 2>&1); then
                  echo -e "${GREEN}    ✓ go: go.sum regenerated${NC}"
                  regenerated=$((regenerated + 1))
                else
                  echo -e "${YELLOW}      regenerate failed — run 'go mod tidy' manually${NC}"
                fi
                stale_count=$((stale_count + 1))
              else
                echo -e "${GREEN}    ✓ go: go.sum fresh${NC}"
              fi
            fi ;;
          rust)
            if [ -f "$PROJ_ROOT/Cargo.lock" ] && [ -f "$PROJ_ROOT/Cargo.toml" ] && [ "$PROJ_ROOT/Cargo.lock" -ot "$PROJ_ROOT/Cargo.toml" ]; then
              echo -e "${YELLOW}    ⚠ rust: Cargo.lock stale — running 'cargo update --workspace'...${NC}"
              if (cd "$PROJ_ROOT" && bash -c "$prefix cargo update --workspace" >/dev/null 2>&1); then
                echo -e "${GREEN}    ✓ rust: Cargo.lock regenerated${NC}"
                regenerated=$((regenerated + 1))
              else
                echo -e "${YELLOW}      regenerate failed — run 'cargo update' manually${NC}"
              fi
              stale_count=$((stale_count + 1))
            elif [ -f "$PROJ_ROOT/Cargo.toml" ]; then
              echo -e "${GREEN}    ✓ rust: Cargo.lock fresh${NC}"
            fi ;;
        esac
      done <<< "$detected_stacks"
      if [ "$stale_count" -gt 0 ]; then
        echo -e "${CYAN}    Stale lock files: $stale_count detected, $regenerated auto-regenerated${NC}"
        if [ "$regenerated" -gt 0 ]; then
          echo -e "${YELLOW}    → review the regenerated lock file diff + commit before push${NC}"
        fi
      fi
    fi
  fi

  echo -e "\n${GREEN}Step 5 PASSED — all counts consistent${NC}"
  mark_done "STEP_5_COUNTS"
  return 0
}

run_step_6_version() {
  local release_mode
  release_mode=$(get_release_mode)

  if [ "$release_mode" = "refresh" ]; then
    echo -e "${CYAN}═══ Step 6: Version Bump — SKIPPED (refresh mode) ═══${NC}"
    mark_done "STEP_6_VERSION"
    return 0
  fi

  echo -e "${CYAN}═══ Step 6: Version Bump (automated) ═══${NC}"

  # Read current version
  local cur_ver
  cur_ver=$(grep '^\- \*\*Version:\*\*' "$PROJ_ROOT/agent/AGENT_CONTEXT.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)

  if [ -z "$cur_ver" ]; then
    echo -e "${RED}  Cannot read current version from AGENT_CONTEXT.md${NC}"
    echo -e "${RED}  Agent: bump version manually, then call done${NC}"
    return 1
  fi

  # Compute next patch
  local major minor patch next_ver
  major=$(echo "$cur_ver" | cut -d. -f1 | tr -d 'v')
  minor=$(echo "$cur_ver" | cut -d. -f2)
  patch=$(echo "$cur_ver" | cut -d. -f3)
  patch=$((patch + 1))
  next_ver="v${major}.${minor}.${patch}"

  echo -e "  Current: ${YELLOW}$cur_ver${NC}"
  echo -e "  Next:    ${GREEN}$next_ver${NC}"

  # Files to update (portable-spec-kit.md handles examples via sync later)
  local files_to_bump="$PROJ_ROOT/portable-spec-kit.md $PROJ_ROOT/README.md $PROJ_ROOT/agent/AGENT_CONTEXT.md"

  # Update portable-spec-kit.md (Framework Version comment + header)
  if [ -f "$PROJ_ROOT/portable-spec-kit.md" ]; then
    sed -i '' "s/<!-- Framework Version: $cur_ver -->/<!-- Framework Version: $next_ver -->/" "$PROJ_ROOT/portable-spec-kit.md" 2>/dev/null || \
    sed -i "s/<!-- Framework Version: $cur_ver -->/<!-- Framework Version: $next_ver -->/" "$PROJ_ROOT/portable-spec-kit.md" 2>/dev/null
    sed -i '' "s/\*\*Version:\*\* $cur_ver/\*\*Version:\*\* $next_ver/" "$PROJ_ROOT/portable-spec-kit.md" 2>/dev/null || \
    sed -i "s/\*\*Version:\*\* $cur_ver/\*\*Version:\*\* $next_ver/" "$PROJ_ROOT/portable-spec-kit.md" 2>/dev/null
    echo -e "  ${GREEN}✓${NC} portable-spec-kit.md"
  fi

  # Update README badge
  if [ -f "$PROJ_ROOT/README.md" ]; then
    sed -i '' "s/version-$cur_ver/version-$next_ver/" "$PROJ_ROOT/README.md" 2>/dev/null || \
    sed -i "s/version-$cur_ver/version-$next_ver/" "$PROJ_ROOT/README.md" 2>/dev/null
    echo -e "  ${GREEN}✓${NC} README.md badge"
  fi

  # Update AGENT_CONTEXT.md (Version + Kit)
  if [ -f "$PROJ_ROOT/agent/AGENT_CONTEXT.md" ]; then
    sed -i '' "s/\*\*Version:\*\* $cur_ver/\*\*Version:\*\* $next_ver/" "$PROJ_ROOT/agent/AGENT_CONTEXT.md" 2>/dev/null || \
    sed -i "s/\*\*Version:\*\* $cur_ver/\*\*Version:\*\* $next_ver/" "$PROJ_ROOT/agent/AGENT_CONTEXT.md" 2>/dev/null
    sed -i '' "s/\*\*Kit:\*\* $cur_ver/\*\*Kit:\*\* $next_ver/" "$PROJ_ROOT/agent/AGENT_CONTEXT.md" 2>/dev/null || \
    sed -i "s/\*\*Kit:\*\* $cur_ver/\*\*Kit:\*\* $next_ver/" "$PROJ_ROOT/agent/AGENT_CONTEXT.md" 2>/dev/null
    echo -e "  ${GREEN}✓${NC} AGENT_CONTEXT.md"
  fi

  # Update CHANGELOG built-over range end
  if [ -f "$PROJ_ROOT/CHANGELOG.md" ]; then
    sed -i '' "s/— $cur_ver/— $next_ver/" "$PROJ_ROOT/CHANGELOG.md" 2>/dev/null || \
    sed -i "s/— $cur_ver/— $next_ver/" "$PROJ_ROOT/CHANGELOG.md" 2>/dev/null
    echo -e "  ${GREEN}✓${NC} CHANGELOG.md range"
  fi

  # Update RELEASES kit range end
  if [ -f "$PROJ_ROOT/agent/RELEASES.md" ]; then
    sed -i '' "s/— $cur_ver/— $next_ver/" "$PROJ_ROOT/agent/RELEASES.md" 2>/dev/null || \
    sed -i "s/— $cur_ver/— $next_ver/" "$PROJ_ROOT/agent/RELEASES.md" 2>/dev/null
    echo -e "  ${GREEN}✓${NC} RELEASES.md range"
  fi

  # Update ARD HTML files
  for f in "$PROJ_ROOT"/ard/*.html; do
    [ -f "$f" ] || continue
    sed -i '' "s/$cur_ver/$next_ver/g" "$f" 2>/dev/null || \
    sed -i "s/$cur_ver/$next_ver/g" "$f" 2>/dev/null
    echo -e "  ${GREEN}✓${NC} $(basename "$f")"
  done

  # Sync to examples
  if [ -f "$PROJ_ROOT/examples/starter/portable-spec-kit.md" ]; then
    cp "$PROJ_ROOT/portable-spec-kit.md" "$PROJ_ROOT/examples/starter/portable-spec-kit.md"
    cp "$PROJ_ROOT/portable-spec-kit.md" "$PROJ_ROOT/examples/my-app/portable-spec-kit.md"
    echo -e "  ${GREEN}✓${NC} examples synced"
  fi

  # Verify version consistency
  if [ -x "$SYNC_CHECK" ]; then
    if bash "$SYNC_CHECK" --quick 2>/dev/null; then
      echo -e "\n${GREEN}Step 6 PASSED — $cur_ver → $next_ver, all files consistent${NC}"
    else
      echo -e "\n${YELLOW}Step 6 WARNING — version bumped but sync-check found issues${NC}"
      echo -e "${YELLOW}  Agent: fix remaining mismatches, then call next${NC}"
      return 1
    fi
  fi

  mark_done "STEP_6_VERSION"
  return 0
}

run_step_7_pdfs() {
  echo -e "${CYAN}═══ Step 7: Regenerate PDFs ═══${NC}"

  if ! command -v weasyprint &>/dev/null; then
    echo -e "${RED}  weasyprint not found — install it: pip install weasyprint${NC}"
    return 1
  fi

  local html_count=0
  local pdf_ok=0
  local pdf_fail=0

  for f in "$PROJ_ROOT"/ard/*.html; do
    [ -f "$f" ] || continue
    html_count=$((html_count + 1))
    local pdf="${f%.html}.pdf"
    echo -e "  Generating: $(basename "$pdf")"
    if weasyprint "$f" "$pdf" 2>/dev/null; then
      if [ -s "$pdf" ]; then
        pdf_ok=$((pdf_ok + 1))
        echo -e "    ${GREEN}✅ $(wc -c < "$pdf" | tr -d ' ') bytes${NC}"
      else
        pdf_fail=$((pdf_fail + 1))
        echo -e "    ${RED}✗ zero-size output${NC}"
      fi
    else
      pdf_fail=$((pdf_fail + 1))
      echo -e "    ${RED}✗ weasyprint failed${NC}"
    fi
  done

  if [ "$html_count" -eq 0 ]; then
    echo -e "${YELLOW}  No ard/*.html files found — skipping${NC}"
    mark_done "STEP_7_PDFS"
    return 0
  fi

  if [ "$pdf_fail" -gt 0 ]; then
    echo -e "\n${RED}Step 7 FAILED — $pdf_fail PDF(s) failed${NC}"
    return 1
  fi

  echo -e "\n${GREEN}Step 7 PASSED — $pdf_ok/$html_count PDFs regenerated${NC}"
  mark_done "STEP_7_PDFS"
  return 0
}

run_step_9_validation() {
  echo -e "${CYAN}═══ Step 9: Final Validation — DUAL GATE ═══${NC}"

  local validate_script="$SCRIPT_DIR/psk-validate.sh"

  if [ ! -x "$validate_script" ]; then
    echo -e "${RED}  psk-validate.sh not found or not executable.${NC}"
    echo -e "${RED}  Cannot run dual gate. Fix: chmod +x $validate_script${NC}"
    return 1
  fi

  # Delegate to generic dual-gate helper
  bash "$validate_script" release
  local rc=$?

  case $rc in
    0)
      mark_done "STEP_9_VALIDATION"
      return 0
      ;;
    2)
      # AWAITING_CRITIC — script printed agent instructions; workflow re-run will pick up
      return 1
      ;;
    *)
      # 1 = bash critic failed; 3 = critic stale; other = error
      echo -e "\n${RED}Step 9 FAILED (psk-validate exit $rc) — fix above, then: psk-release.sh next${NC}"
      return 1
      ;;
  esac
}

run_step_10_summary() {
  echo -e "${CYAN}═══ Step 10: Release Summary ═══${NC}"
  mark_done "STEP_10_SUMMARY"
  show_status
  echo ""
  echo -e "${GREEN}All release steps completed. Ready to commit + push.${NC}"
  echo -e "${YELLOW}  Refine will recognize the next commit as a prep-release commit${NC}"
  echo -e "${YELLOW}  if its message starts with: 'v0.N.N:' or contains 'prep release' or 'refresh release'.${NC}"

  # v0.6.14 — advisory token-optimization scan (non-blocking).
  # Surfaces accumulated bloat (duplicate version entries, stale badges,
  # superseded-ADR rationale, oversized framework sections, reflex prompt
  # bloat, register growth) at the natural release cadence. The scan is
  # READ-ONLY by default — it never modifies files, never blocks the
  # release. To apply cuts, the user invokes the /optimize skill.
  #
  # Bypass: PSK_OPTIMIZE_SCAN_DISABLED=1 (e.g. for offline / fast releases).
  local optimize_sh="$SCRIPT_DIR/psk-optimize.sh"
  if [ -x "$optimize_sh" ] && [ "${PSK_OPTIMIZE_SCAN_DISABLED:-0}" != "1" ]; then
    echo ""
    echo -e "${CYAN}═══ Token-optimization scan (advisory — non-blocking) ═══${NC}"
    # Run with cache-only mode to avoid re-spawning test suites
    local opt_out
    opt_out=$(PSK_OPTIMIZE_SKIP_TESTRUN=1 bash "$optimize_sh" --scan 2>&1 || true)
    # Count flagged candidates (lines containing flag markers)
    local flag_count
    flag_count=$(echo "$opt_out" | grep -cE 'STALE_REF|UNUSED_ENV|OVERSIZED|REFLEX_PROMPT_BLOAT|REFLEX_HISTORY_BLOAT|REFLEX_REGISTER_BLOAT|BLOAT|appears [0-9]+ times|STALE:' || echo 0)
    if [ "$flag_count" -gt 0 ]; then
      echo -e "${YELLOW}  ⚠ $flag_count token-bloat candidate(s) detected.${NC}"
      echo -e "${YELLOW}    Review with: bash agent/scripts/psk-optimize.sh --scan${NC}"
      echo -e "${YELLOW}    Apply cuts:  invoke /optimize skill (per-cut gate-verified, never auto-applies)${NC}"
      echo -e "${YELLOW}    Disable scan: PSK_OPTIMIZE_SCAN_DISABLED=1 bash agent/scripts/psk-release.sh prepare${NC}"
    else
      echo -e "${GREEN}  ✓ No token-bloat candidates detected — release files are optimized.${NC}"
    fi
  fi

  return 0
}

# === AGENT-REQUIRED STEPS (with artifact verification) ===

pause_for_agent() {
  local step_num="$1"
  local step_name="$2"
  local instructions="$3"

  echo -e "${CYAN}═══ Step $step_num: $step_name (AGENT ACTION REQUIRED) ═══${NC}"
  echo -e "${YELLOW}$instructions${NC}"
  echo ""
  echo -e "  When done: ${CYAN}bash agent/scripts/psk-release.sh done${NC}"
  return 1
}

# Verify agent step: check files were modified since RUN_ID
verify_agent_step() {
  local step="$1"
  local run_id
  run_id=$(get_run_id)

  case "$step" in
    STEP_4_FLOW_DOCS)
      # Per-flow-doc critic verdict (replaces mtime-only check which could be
      # satisfied by editing any single flow doc). Require critic to name
      # every flow doc file and report CURRENT for each.
      local result_file="$CRITIC_DIR/critic-result.md"
      local critic_script="$SCRIPT_DIR/psk-critic-spawn.sh"

      # Allow bypass via PSK_CRITIC_DISABLED (logged separately)
      if [ "${PSK_CRITIC_DISABLED:-0}" = "1" ]; then
        echo -e "${YELLOW}  Step 4 critic BYPASSED (PSK_CRITIC_DISABLED=1)${NC}"
        echo -e "${YELLOW}  mtime fallback: requiring at least one flow doc touched.${NC}"
        for f in "$PROJ_ROOT"/docs/work-flows/*.md; do
          [ -f "$f" ] || continue
          local m
          m=$(stat -f "%m" "$f" 2>/dev/null || stat -c "%Y" "$f" 2>/dev/null)
          [ -n "$m" ] && [ "$m" -ge "$run_id" ] && return 0
        done
        echo -e "${RED}  No flow doc touched in this run and critic bypassed — refusing to advance.${NC}"
        return 1
      fi

      # Check critic result exists and is fresh (mtime >= run_id)
      local result_fresh=false
      if [ -f "$result_file" ] && [ -n "$run_id" ]; then
        local rm
        rm=$(stat -f "%m" "$result_file" 2>/dev/null || stat -c "%Y" "$result_file" 2>/dev/null)
        [ -n "$rm" ] && [ "$rm" -ge "$run_id" ] && result_fresh=true
      fi

      if [ "$result_fresh" = false ]; then
        # Spawn step-4 critic
        if [ -x "$critic_script" ]; then
          bash "$critic_script" write STEP_4_FLOW_DOCS >/dev/null 2>&1
          echo -e "${YELLOW}  ⏳ AWAITING_CRITIC — spawn sub-agent for flow docs verdict${NC}"
          echo -e "     Read: ${CYAN}$CRITIC_DIR/critic-task.md${NC}"
          echo -e "     Write: ${CYAN}$result_file${NC}"
          echo -e "     Retry: ${CYAN}bash agent/scripts/psk-release.sh done${NC}"
        else
          echo -e "${RED}  psk-critic-spawn.sh missing — cannot verify flow docs${NC}"
        fi
        return 1
      fi

      # Verify every flow doc has a CURRENT verdict (not just "no STALE")
      local missing=""
      for f in "$PROJ_ROOT"/docs/work-flows/*.md; do
        [ -f "$f" ] || continue
        local fname
        fname=$(basename "$f")
        grep -qE "^CURRENT:.*$fname|^STALE:.*$fname" "$result_file" 2>/dev/null || missing="$missing $fname"
      done

      if [ -n "$missing" ]; then
        echo -e "${RED}  Critic did not cover these flow docs:${NC}$missing"
        echo -e "${RED}  Every flow doc needs a CURRENT or STALE verdict.${NC}"
        echo -e "${YELLOW}  Re-spawn critic with the full file list.${NC}"
        return 1
      fi

      if grep -q "^STALE:" "$result_file" 2>/dev/null; then
        echo -e "${RED}  Critic flagged stale flow doc(s):${NC}"
        grep "^STALE:" "$result_file" | while read -r line; do echo -e "    ${RED}$line${NC}"; done
        echo -e "${YELLOW}  Fix flagged items, clear result, re-run.${NC}"
        return 1
      fi

      local current_count
      current_count=$(grep -c "^CURRENT:" "$result_file" 2>/dev/null)
      echo -e "${GREEN}  ✓ Step 4 critic: $current_count flow doc(s) verified CURRENT${NC}"
      return 0
      ;;
    STEP_8_RELEASES)
      # RELEASES.md and CHANGELOG.md must be modified
      local cur_ver
      cur_ver=$(grep '^\- \*\*Version:\*\*' "$PROJ_ROOT/agent/AGENT_CONTEXT.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
      local minor_ver
      minor_ver=$(echo "$cur_ver" | grep -oE 'v[0-9]+\.[0-9]+')

      if [ -n "$minor_ver" ]; then
        if ! grep -q "$minor_ver" "$PROJ_ROOT/agent/RELEASES.md" 2>/dev/null; then
          echo -e "${RED}  RELEASES.md missing entry for $minor_ver${NC}"
          return 1
        fi
        if ! grep -q "$minor_ver" "$PROJ_ROOT/CHANGELOG.md" 2>/dev/null; then
          echo -e "${RED}  CHANGELOG.md missing entry for $minor_ver${NC}"
          return 1
        fi
      fi
      ;;
  esac

  return 0
}

# === MAIN DISPATCH ===

run_next() {
  if [ ! -f "$STATE_FILE" ]; then
    echo -e "${RED}No release in progress. Run: bash agent/scripts/psk-release.sh prepare${NC}"
    exit 1
  fi

  if state_is_stale; then
    echo -e "${RED}Refusing to resume stale release state.${NC}"
    echo -e "${YELLOW}  Reason: state file is >24h old OR base version drifted outside the release flow.${NC}"
    echo -e "${YELLOW}  This guards against done-markers from a prior version carrying over silently.${NC}"
    echo -e "${CYAN}  Start fresh: bash agent/scripts/psk-release.sh prepare${NC}"
    exit 1
  fi

  local next
  next=$(get_next_step)

  if [ "$next" = "ALL_DONE" ]; then
    echo -e "${GREEN}All steps already completed. Ready to commit + push.${NC}"
    show_status
    return 0
  fi

  case "$next" in
    STEP_1_TESTS)       run_step_1_tests ;;
    STEP_2_CODE_REVIEW) run_step_2_code_review ;;
    STEP_3_SCOPE_CHECK) run_step_3_scope_check ;;
    STEP_4_FLOW_DOCS)
      pause_for_agent 4 "Update Flow Docs" \
        "  READ every flow doc in docs/work-flows/.
  Update any that describe changed processes.
  Create new docs for new processes.
  Verify numeric order, box-style format, 63-char lines."
      ;;
    STEP_5_COUNTS)      run_step_5_counts ;;
    STEP_6_VERSION)     run_step_6_version ;;
    STEP_7_PDFS)        run_step_7_pdfs ;;
    STEP_8_RELEASES)
      pause_for_agent 8 "Update RELEASES.md + CHANGELOG.md" \
        "  Add or update entry for this version in RELEASES.md.
  Update CHANGELOG.md — grouped entry per minor release.
  Include test counts, section counts, feature counts."
      ;;
    STEP_9_VALIDATION)  run_step_9_validation ;;
    STEP_10_SUMMARY)    run_step_10_summary ;;
  esac
}

mark_current_done() {
  if [ ! -f "$STATE_FILE" ]; then
    echo -e "${RED}No release in progress.${NC}"
    exit 1
  fi

  local next
  next=$(get_next_step)

  if [ "$next" = "ALL_DONE" ]; then
    echo -e "${GREEN}All steps already completed.${NC}"
    return 0
  fi

  # Only allow marking agent-required steps
  case "$next" in
    STEP_4_FLOW_DOCS|STEP_8_RELEASES)
      echo -e "${CYAN}Verifying $next...${NC}"
      if verify_agent_step "$next"; then
        mark_done "$next"
        echo -e "${GREEN}✅ $next verified and marked done.${NC}"
        show_status
        echo ""
        echo -e "Run next step: ${CYAN}bash agent/scripts/psk-release.sh next${NC}"
      else
        echo -e "\n${RED}Verification FAILED — step NOT marked done.${NC}"
        exit 1
      fi
      ;;
    *)
      echo -e "${RED}Step $next is automated — run 'next' instead of 'done'.${NC}"
      exit 1
      ;;
  esac
}

# === BOOTSTRAP GATE (pre-Step-0) ===
# Runs before init_state on prepare/refresh. Ensures the kit was actually
# installed in this project — catches the "Copilot/plain-agent created agent/
# files manually and never ran install.sh" failure mode. Without this, a
# partially-bootstrapped project can run prep-release + reflex end-to-end and
# ship a v0.N.N commit without any kit infrastructure ever being in place.
#
# Bypass: PSK_BOOTSTRAP_CHECK_DISABLED=1 (genuine emergencies only).
run_bootstrap_gate() {
  local bootstrap_check="$SCRIPT_DIR/psk-bootstrap-check.sh"
  if [ ! -x "$bootstrap_check" ]; then
    # Script is missing — skip silently. The gate itself is newly-added and
    # older projects may not have it yet. Install.sh will land it on next run.
    return 0
  fi
  if [ "${PSK_BOOTSTRAP_CHECK_DISABLED:-0}" = "1" ]; then
    echo -e "${YELLOW}⚠ psk-bootstrap-check bypassed (PSK_BOOTSTRAP_CHECK_DISABLED=1)${NC}"
    return 0
  fi
  if ! bash "$bootstrap_check" --quiet; then
    echo ""
    echo -e "${RED}✗ Cannot start release — kit is not fully installed in this project.${NC}"
    echo ""
    bash "$bootstrap_check" | sed 's/^/  /'
    echo ""
    echo -e "${CYAN}→ Fix by running the kit installer from its source checkout, then retry.${NC}"
    exit 1
  fi
}

# === COMMANDS ===
case "$MODE" in
  prepare|refresh)
    run_bootstrap_gate
    init_state
    show_status
    echo ""
    echo -e "Run steps: ${CYAN}bash agent/scripts/psk-release.sh next${NC}  (repeat until all done)"
    echo "Automated steps run directly. Agent steps (4, 8) pause for action."
    ;;
  next)
    run_next
    ;;
  done)
    shift
    mark_current_done "$@"
    ;;
  status)
    show_status
    ;;
  reset)
    rm -rf "$STATE_DIR"
    echo "Release state cleared."
    ;;
  *)
    echo "Usage: bash agent/scripts/psk-release.sh [prepare|refresh|next|done|status|reset]"
    exit 1
    ;;
esac
