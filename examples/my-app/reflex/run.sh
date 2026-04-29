#!/bin/bash
# reflex/run.sh — Actor-Critic Remediation Loop orchestrator
#
# Usage:
#   bash reflex/run.sh                    # run one cycle (QA → Dev → gates → verdict)
#   bash reflex/run.sh status             # show latest cycle summary
#   bash reflex/run.sh --qa-only          # only run QA, skip Dev-Agent (Phase 1 mode)
#   bash reflex/run.sh --resume           # re-enter after QA-Agent wrote qa-result.md
#   bash reflex/run.sh --resume-dev       # re-enter after Dev-Agent wrote dev-result.md
#   bash reflex/run.sh --skip-preconditions   (dev/testing only — bypasses prep-release gate)
#
# Flow (Phase 2+):
#   1. Preconditions (HEAD must be prep-release commit, tree clean)
#   2. Spawn QA-Agent (exits 2 AWAITING_QA)
#   3. User invokes Task-tool sub-agent → qa-result.md written
#   4. --resume → file bugs to TASKS.md, spawn Dev-Agent (exits 2 AWAITING_DEV)
#   5. User invokes Task-tool sub-agent → dev-result.md + commits written
#   6. --resume-dev → run global mechanical gates, write verdict, update summary

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REFLEX_PROJ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$SCRIPT_DIR/lib"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

SKIP_PRECONDITIONS=false
MODE=""
QA_ONLY=false

# Parse args — flags anywhere, mode is first non-flag
for arg in "$@"; do
  case "$arg" in
    --skip-preconditions) SKIP_PRECONDITIONS=true ;;
    --qa-only)            QA_ONLY=true; MODE="${MODE:-run}" ;;
    --resume)             MODE="resume-qa" ;;
    --resume-dev)         MODE="resume-dev" ;;
    status)               MODE="status" ;;
    run)                  MODE="run" ;;
    *) ;;
  esac
done
MODE="${MODE:-run}"

cd "$REFLEX_PROJ_ROOT"

HISTORY="$REFLEX_PROJ_ROOT/reflex/history"
STATE_DIR="$REFLEX_PROJ_ROOT/agent/.release-state"
mkdir -p "$HISTORY"

find_next_cycle_dir() {
  local n=1
  while [ -d "$HISTORY/cycle-$(printf '%03d' $n)" ]; do
    n=$((n + 1))
  done
  echo "$HISTORY/cycle-$(printf '%03d' $n)"
}

latest_cycle_dir() {
  ls -1dt "$HISTORY"/cycle-* 2>/dev/null | head -1
}

show_latest() {
  if [ -f "$HISTORY/latest.md" ]; then
    cat "$HISTORY/latest.md"
  else
    echo "No reflex passs have run yet."
  fi
}

write_verdict() {
  local cycle_dir="$1" findings="$2" fixes="$3" gates_ok="$4"
  local mode_str="Phase 2 (QA + Dev)"
  [ "$QA_ONLY" = true ] && mode_str="Phase 1 (QA-only)"

  cat > "$cycle_dir/verdict.md" <<EOF
# reflex pass verdict

- mode: $mode_str
- cycle_dir: $cycle_dir
- qa_findings: $findings
- dev_fixes: $fixes
- mechanical_gates: $gates_ok
- timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)

See TASKS.md for remaining tasks and \`qa-summary.md\` / \`dev-trace.md\` for detail.
EOF

  cp "$cycle_dir/verdict.md" "$HISTORY/latest.md"
}

case "$MODE" in
  status)
    show_latest
    exit 0
    ;;

  # =============================================================
  # RESUME QA path — after QA sub-agent wrote qa-result.md
  # =============================================================
  resume-qa)
    echo -e "${CYAN}═══ refine resume-qa — processing qa-result.md ═══${NC}"
    RESULT_FILE="$STATE_DIR/qa-result.md"
    if [ ! -f "$RESULT_FILE" ]; then
      echo -e "${RED}✗ no qa-result.md found at $RESULT_FILE${NC}"
      exit 1
    fi

    CYCLE_DIR="$(latest_cycle_dir)"
    [ -z "$CYCLE_DIR" ] && { echo -e "${RED}✗ no cycle directory; start a new run first${NC}"; exit 1; }
    export REFLEX_PASS_DIR="$CYCLE_DIR"

    bash "$LIB/file-bugs.sh"

    findings=$(grep -c '^- id:' "$RESULT_FILE" 2>/dev/null | tr -d '\n')
    findings="${findings:-0}"

    # Phase 1 ends here; Phase 2+ continues into Dev-Agent spawn
    if [ "$QA_ONLY" = true ] || [ "$findings" -eq 0 ]; then
      write_verdict "$CYCLE_DIR" "$findings" "0" "n/a"
      echo -e "${GREEN}✓ reflex pass complete${NC} — $findings finding(s) filed"
      echo -e "  Verdict: $CYCLE_DIR/verdict.md"
      exit 0
    fi

    echo -e "${CYAN}═══ spawning Dev-Agent for $findings refine-dev tasks ═══${NC}"
    bash "$LIB/spawn-dev.sh"
    # spawn-dev.sh exits 2 AWAITING_DEV
    exit $?
    ;;

  # =============================================================
  # RESUME DEV path — after Dev sub-agent wrote dev-result.md + commits
  # =============================================================
  resume-dev)
    echo -e "${CYAN}═══ refine resume-dev — verifying Dev-Agent output ═══${NC}"
    DEV_RESULT="$STATE_DIR/dev-result.md"
    if [ ! -f "$DEV_RESULT" ]; then
      echo -e "${RED}✗ no dev-result.md found at $DEV_RESULT${NC}"
      exit 1
    fi

    CYCLE_DIR="$(latest_cycle_dir)"
    [ -z "$CYCLE_DIR" ] && { echo -e "${RED}✗ no cycle directory${NC}"; exit 1; }
    export REFLEX_PASS_DIR="$CYCLE_DIR"

    # Run global mechanical gates on the post-Dev-Agent state
    gates_status="pass"
    if ! bash "$LIB/gates.sh"; then
      gates_status="FAIL"
    fi
    export REFLEX_GATES_STATUS="$gates_status"

    fixes=$(grep -c '^- id:' "$DEV_RESULT" 2>/dev/null | tr -d '\n')
    fixes="${fixes:-0}"

    # QA findings count from matching qa-result
    QA_RESULT="$STATE_DIR/qa-result.md"
    findings=0
    if [ -f "$QA_RESULT" ]; then
      findings=$(grep -c '^- id:' "$QA_RESULT" 2>/dev/null | tr -d '\n')
      findings="${findings:-0}"
    fi

    # Phase 3 — regression detection across cycles
    regression_status="clean"
    if ! bash "$LIB/regression-diff.sh"; then
      regression_status="REGRESSION"
    fi

    # Phase 3 — append a row to summary.csv with score + trend
    bash "$LIB/score.sh" || true

    write_verdict "$CYCLE_DIR" "$findings" "$fixes" "$gates_status"

    if [ "$gates_status" = "FAIL" ]; then
      echo -e "${RED}⚠ reflex pass completed but mechanical gates failed.${NC}"
      echo -e "   Review $CYCLE_DIR/gates-result.md and $CYCLE_DIR/dev-trace.md."
      echo -e "   Dev-Agent's commits are on HEAD. Consider: git reset --hard to before cycle."
      exit 1
    fi

    if [ "$regression_status" = "REGRESSION" ]; then
      echo -e "${RED}⚠ Regression detected — see $CYCLE_DIR/regression-diff.md${NC}"
      echo -e "   Cycle is not clean; consider reviewing Dev-Agent's fixes before trusting them."
      # Don't auto-revert — leave the decision to the user. Exit 2 to flag.
      exit 2
    fi

    echo -e "${GREEN}✓ reflex pass complete${NC} — $fixes fix(es) landed from $findings finding(s), gates green, no regressions"
    echo -e "  Verdict: $CYCLE_DIR/verdict.md"
    echo -e "  Trend:   $HISTORY/summary.csv"
    exit 0
    ;;

  # =============================================================
  # NEW-CYCLE path
  # =============================================================
  run)
    local_mode_str="Phase 2 (QA + Dev)"
    [ "$QA_ONLY" = true ] && local_mode_str="Phase 1 (QA-only)"
    echo -e "${CYAN}═══ refine — Actor-Critic Remediation Loop ($local_mode_str) ═══${NC}"
    echo ""

    # 1. Preconditions
    if [ "$SKIP_PRECONDITIONS" = true ]; then
      echo -e "${YELLOW}⚠ skipping preconditions (--skip-preconditions flag — for dev/testing only)${NC}"
    else
      if ! bash "$LIB/preconditions.sh"; then
        exit 1
      fi
    fi

    # 2. Create cycle dir
    CYCLE_DIR="$(find_next_cycle_dir)"
    mkdir -p "$CYCLE_DIR"
    export REFLEX_PASS_DIR="$CYCLE_DIR"
    echo -e "${CYAN}Cycle directory:${NC} $CYCLE_DIR"
    echo ""

    # 3. Spawn QA-Agent (exits 2 AWAITING_QA)
    bash "$LIB/spawn-qa.sh"
    # When sub-agent is done → user runs `bash reflex/run.sh --resume`
    exit $?
    ;;

  *)
    echo "Usage: bash reflex/run.sh [run | status | --qa-only | --resume | --resume-dev] [--skip-preconditions]"
    exit 1
    ;;
esac
