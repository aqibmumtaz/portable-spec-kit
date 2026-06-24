#!/bin/bash
# mechanical-script: deterministic, no AI prompts (Dim 28 allowlist — v0.6.60 HF7b)
# =============================================================
# psk-reflex.sh — Adversarial Verbal Actor-Critic Refinement (AVACR) Loop driver
#
# Formal name: Adversarial Verbal Actor-Critic Refinement Loop (AVACR)
#   - "Adversarial" — QA's goal = FAIL the release; Dev's goal = FOOLPROOF it. Asymmetric goals.
#   - "Verbal" — language-level feedback, no weight updates (Reflexion — Shinn et al. 2023)
#   - "Actor-Critic" — Dev-Agent (Actor) acts; QA-Agent (Critic) evaluates (Sutton & Barto)
#   - "Refinement" — iterative refinement via structured feedback (Self-Refine — Madaan et al. 2023)
#
# Pattern family: Reflexion-style verbal RL extended to multi-agent Automated Program Repair (APR)
# with adversarial goals. NOT classical Actor-Critic RL (no policy gradient),
# NOT GAN (inference-time fixed-point, not gradient-trained equilibrium).
# Convergence = fixed-point iteration (QA hunts hard and returns zero new findings).
#
# Deep-learning vocabulary mapping (user-facing):
#   pass              = one full QA→Dev iteration (adversarial hunt + fix round)
#   loss              = open QA findings count (target → 0)
#   convergence       = QA hunts hard across 14 dimensions and finds zero new blockers
#   early stopping    = P consecutive passes with no findings decrease (patience)
#   equilibrium       = same as convergence (inference-time fixed-point reached)
#
# Usage:
#   bash agent/scripts/psk-reflex.sh prepare              # run prepare/refresh release (thorough)
#   bash agent/scripts/psk-reflex.sh qa                   # QA-Agent only (file findings)
#   bash agent/scripts/psk-reflex.sh qa --resume          # resume after QA sub-agent
#   bash agent/scripts/psk-reflex.sh dev                  # Dev-Agent only (fix current findings)
#   bash agent/scripts/psk-reflex.sh dev --resume         # resume after Dev sub-agent
#   bash agent/scripts/psk-reflex.sh pass                # one full QA→Dev iteration
#   bash agent/scripts/psk-reflex.sh loop --passes N     # N passes with early stopping
#                                              [--patience P] (default 2)
#   bash agent/scripts/psk-reflex.sh status               # latest pass verdict + CSV trend
#   bash agent/scripts/psk-reflex.sh reset                # clear reflex state (safe)
#
# Research foundations:
#   - Shinn et al. 2023: Reflexion — verbal RL, language feedback, no gradient updates
#   - Madaan et al. 2023: Self-Refine — iterative refinement loop
#   - Goodfellow et al. 2014: GAN topology (Generator-Discriminator — not training dynamics)
#   - Sutton & Barto: Actor-Critic RL topology (inference-time only)
#   - Liu et al. 2023: Lost-in-the-middle — the failure mode AVACR counters
#   - Yang et al. 2024: SWE-agent — LLM-based software engineering agent framework
#
# Exit codes:
#   0 = command completed cleanly
#   1 = error / gate failure / agent action required
#   2 = AWAITING_AGENT — main Claude Code session must spawn a Task sub-agent
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
REFLEX_DIR="$PROJ_ROOT/reflex"
REFLEX_RUN="$REFLEX_DIR/run.sh"
REFLEX_LIB="$REFLEX_DIR/lib"
HISTORY="$REFLEX_DIR/history"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

usage() {
  cat <<EOF
psk-reflex.sh — Adversarial Verbal Actor-Critic Refinement (AVACR) Loop driver

Usage:
  bash agent/scripts/psk-reflex.sh prepare
      Run prepare release OR refresh release thoroughly (auto-detects which).
      Does NOT run refinement — use this first to put HEAD at a prep-release commit.

  bash agent/scripts/psk-reflex.sh qa [--resume]
      Spawn the QA-Agent (Critic) alone. Files bugs to TASKS.md.
      --resume continues after the QA sub-agent wrote qa-result.md.

  bash agent/scripts/psk-reflex.sh dev [--resume]
      Spawn the Dev-Agent (Actor) alone. Fixes current @reflex-dev tasks.
      --resume continues after the Dev sub-agent wrote dev-result.md.

  bash agent/scripts/psk-reflex.sh pass
      One full QA → Dev iteration (a "pass"). Equivalent to qa → dev.

  bash agent/scripts/psk-reflex.sh loop --passes N [--patience P]
      Run up to N passes with early stopping.
        --passes N     hard cap (default 5)
        --patience P   stop after P passes with no findings decrease (default 2)
      Stops early on convergence: zero new QA findings AND no regressions.

  bash agent/scripts/psk-reflex.sh status
      Show latest pass verdict + summary.csv trend.

  bash agent/scripts/psk-reflex.sh reset
      Clear reflex/history/cycle-* + standalone/ state (keeps summary.csv).

Exit codes:
  0 = success  |  1 = error  |  2 = AWAITING_AGENT (spawn sub-agent via Task tool)
EOF
}

require_reflex_dir() {
  if [ ! -x "$REFLEX_RUN" ]; then
    echo -e "${RED}✗ reflex/ not installed in this project${NC}"
    echo -e "  Run: ${CYAN}bash ~/portable-spec-kit/reflex/install-into-project.sh .${NC}"
    exit 1
  fi
}

# Detect if prepare vs refresh — prepare if there are changes since last release commit
# (HEAD is not a prep-release commit) OR working tree dirty; refresh otherwise.
cmd_prepare() {
  echo -e "${CYAN}═══ psk-reflex prepare — running release pipeline thoroughly ═══${NC}"

  # Sanity check — release script exists
  if [ ! -x "$SCRIPT_DIR/psk-release.sh" ]; then
    echo -e "${RED}✗ psk-release.sh not found at $SCRIPT_DIR${NC}"
    exit 1
  fi

  # Check HEAD commit message pattern — if already a prep-release AND tree clean, no need
  local head_msg
  head_msg="$(git log -1 --pretty=%s 2>/dev/null || echo "")"
  local tree_clean=true
  [ -n "$(git status --porcelain 2>/dev/null)" ] && tree_clean=false

  local is_prep=false
  if echo "$head_msg" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+:|prep release|refresh release'; then
    is_prep=true
  fi

  if [ "$is_prep" = true ] && [ "$tree_clean" = true ]; then
    echo -e "${GREEN}  HEAD is already a prep-release commit and tree is clean — skipping.${NC}"
    echo -e "  ${CYAN}You can run:${NC} bash agent/scripts/psk-reflex.sh pass"
    return 0
  fi

  # If HEAD is prep-release but tree has uncommitted work → run refresh (no version bump)
  # If HEAD is non-prep → run prepare (version bump)
  local release_mode="prepare"
  if [ "$is_prep" = true ] && [ "$tree_clean" = false ]; then
    release_mode="refresh"
    echo -e "${CYAN}  HEAD is prep-release but tree has changes → running refresh release (no bump)${NC}"
  else
    echo -e "${CYAN}  HEAD is not a prep-release or tree has changes → running prepare release${NC}"
  fi

  echo ""
  echo -e "${YELLOW}Starting $release_mode release pipeline.${NC}"
  bash "$SCRIPT_DIR/psk-release.sh" "$release_mode"

  # Walk through all steps
  while true; do
    local next
    next=$(bash "$SCRIPT_DIR/psk-release.sh" status 2>/dev/null | grep -oE 'Next: Step [0-9]+' | head -1)
    if [ -z "$next" ]; then
      break
    fi
    echo ""
    bash "$SCRIPT_DIR/psk-release.sh" next
    local rc=$?
    if [ $rc -ne 0 ]; then
      echo -e "${YELLOW}⚠ psk-release.sh next returned $rc — agent action required. See above.${NC}"
      echo -e "   After the required action, resume with:"
      echo -e "   ${CYAN}bash $SCRIPT_DIR/psk-release.sh next${NC}"
      echo -e "   Then re-run this command."
      return $rc
    fi
  done

  echo ""
  echo -e "${GREEN}✓ Prepare complete.${NC} HEAD is now at a prep-release commit."
  echo -e "  ${CYAN}You can now run:${NC} bash agent/scripts/psk-reflex.sh pass"
}

cmd_qa() {
  require_reflex_dir
  local resume="$1"

  if [ "$resume" = "--resume" ]; then
    echo -e "${CYAN}═══ psk-reflex qa --resume ═══${NC}"
    # Delegate to reflex/run.sh resume path — only files bugs, does NOT spawn dev
    # We need a QA-only resume: set QA_ONLY=true before calling run.sh --resume
    QA_ONLY_OVERRIDE=1 bash "$REFLEX_RUN" --resume
    return $?
  fi

  echo -e "${CYAN}═══ psk-reflex qa — spawning QA-Agent (Critic) alone ═══${NC}"
  # Start a new pass in QA-only mode so Dev-Agent is NOT auto-spawned on resume
  bash "$REFLEX_RUN" --qa-only
  # Exits 2 AWAITING_QA — main Claude Code session spawns sub-agent, then runs: psk-reflex.sh qa --resume
}

cmd_dev() {
  require_reflex_dir
  local resume="$1"

  if [ "$resume" = "--resume" ]; then
    echo -e "${CYAN}═══ psk-reflex dev --resume ═══${NC}"
    bash "$REFLEX_RUN" --resume-dev
    return $?
  fi

  echo -e "${CYAN}═══ psk-reflex dev — spawning Dev-Agent (Actor) alone ═══${NC}"
  # Requires existing QA findings in TASKS.md. Call spawn-dev directly so we don't re-run QA.
  local pass_dir
  pass_dir=$(ls -1dt "$HISTORY"/cycle-*/pass-* "$HISTORY"/standalone/pass-* 2>/dev/null | head -1)
  if [ -z "$pass_dir" ]; then
    echo -e "${RED}✗ no prior QA pass found; run:${NC} bash agent/scripts/psk-reflex.sh qa"
    exit 1
  fi
  export REFLEX_PASS_DIR="$pass_dir"
  export REFLEX_PROJ_ROOT="$PROJ_ROOT"
  bash "$REFLEX_LIB/spawn-dev.sh"
  # Exits 2 AWAITING_DEV — main session spawns sub-agent, then: psk-reflex.sh dev --resume
}

cmd_pass() {
  require_reflex_dir
  echo -e "${CYAN}═══ psk-reflex pass — one full QA→Dev iteration ═══${NC}"
  bash "$REFLEX_RUN"
  # Exits 2 AWAITING_QA — after resume-qa AND resume-dev, pass completes.
}

cmd_loop() {
  require_reflex_dir
  local passes=5
  local patience=2

  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --passes)   passes="$2"; shift 2 ;;
      --patience) patience="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  echo -e "${CYAN}═══ psk-reflex loop — up to $passes passes, patience=$patience ═══${NC}"
  echo -e "${YELLOW}Note: each pass requires 2 sub-agent spawns (QA + Dev).${NC}"
  echo -e "${YELLOW}Re-run this command after each resume step.${NC}"
  echo -e "${YELLOW}Convergence check runs at the end of every pass.${NC}"
  echo ""

  # Read last row from summary.csv as baseline
  local csv="$HISTORY/summary.csv"
  local prev_findings=999999 streak=0

  if [ -f "$csv" ]; then
    prev_findings=$(tail -n 1 "$csv" | awk -F',' '{print $3}')
    prev_findings="${prev_findings:-999999}"
  fi

  local n=1
  while [ $n -le $passes ]; do
    echo -e "${CYAN}──── Pass $n / $epochs ────${NC}"
    bash "$REFLEX_RUN"
    local rc=$?
    if [ $rc -eq 2 ]; then
      echo -e "${YELLOW}⚠ Pass $n awaiting sub-agent. Complete via:${NC}"
      echo -e "   1. Spawn QA sub-agent from agent/.release-state/qa-task.md"
      echo -e "   2. ${CYAN}bash $0 qa --resume${NC}"
      echo -e "   3. Spawn Dev sub-agent from agent/.release-state/dev-task.md"
      echo -e "   4. ${CYAN}bash $0 dev --resume${NC}"
      echo -e "   5. Re-run: ${CYAN}bash $0 loop --passes $((passes - n + 1)) --patience $patience${NC}"
      exit 2
    fi

    # Check convergence from summary.csv
    local last_row=$(tail -n 1 "$csv" 2>/dev/null)
    local cur_findings=$(echo "$last_row" | awk -F',' '{print $3}')
    cur_findings="${cur_findings:-0}"

    if [ "$cur_findings" -eq 0 ]; then
      echo -e "${GREEN}✓ Converged at pass $n (zero QA findings)${NC}"
      exit 0
    fi

    if [ "$cur_findings" -ge "$prev_findings" ]; then
      streak=$((streak + 1))
      echo -e "${YELLOW}  No loss decrease (streak=$streak / patience=$patience)${NC}"
      if [ $streak -ge $patience ]; then
        echo -e "${RED}⚠ Early stopping — $patience passes without improvement${NC}"
        exit 0
      fi
    else
      streak=0
      echo -e "${GREEN}  Loss decreased: $prev_findings → $cur_findings${NC}"
    fi

    prev_findings=$cur_findings
    n=$((n + 1))
  done

  echo -e "${YELLOW}Reached max passes ($epochs) without convergence.${NC}"
}

cmd_status() {
  require_reflex_dir
  bash "$REFLEX_RUN" status
  echo ""
  local csv="$HISTORY/summary.csv"
  if [ -f "$csv" ]; then
    echo -e "${CYAN}Trend (summary.csv):${NC}"
    cat "$csv"
  fi
}

cmd_reset() {
  require_reflex_dir
  echo -e "${YELLOW}Clearing reflex/history/cycle-* + standalone/ (keeping summary.csv)${NC}"
  rm -rf "$HISTORY"/cycle-* "$HISTORY"/standalone
  echo -e "${GREEN}✓ state cleared${NC}"
}

# --- Dispatch ---
cmd="${1:-}"
shift || true

case "$cmd" in
  prepare)  cmd_prepare ;;
  qa)       cmd_qa "${1:-}" ;;
  dev)      cmd_dev "${1:-}" ;;
  pass)    cmd_pass ;;
  loop)    cmd_loop "$@" ;;
  status)   cmd_status ;;
  reset)    cmd_reset ;;
  -h|--help|help|"") usage ;;
  *) echo -e "${RED}Unknown command: $cmd${NC}"; echo ""; usage; exit 1 ;;
esac
