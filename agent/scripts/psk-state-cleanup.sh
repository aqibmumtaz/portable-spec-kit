#!/usr/bin/env bash
# mechanical-script: psk-state-cleanup.sh — prune dead workflow-state triplets (no AI invocation)
# doc-coverage-exempt: internal mechanical helper — no user-facing R->F->T claim
#
# Resets agent/.workflow-state/ to a clean slate, KEEPING only workflows that are
# genuinely resumable RIGHT NOW — per the kit's own resume authority, NOT a guess
# from stale CURRENT_PHASE markers (which can falsely flag old parked runs).
#
# A workflow triplet (<wf>.state/.gates/.run/.dispatch.run/.env/.gates.bak) is
# classified ACTIVE → KEPT iff ANY of:
#   1. its id appears in retry-queue.yml          (paused spawn awaiting retry/arbitration)
#   2. it is reported by `psk-workflow-state.sh list-paused`  (AWAITING phase)
#   3. it is the currently-running workflow        (--running <id>)
# Everything else — done plans, completed workflows, old parked-but-stale triplets —
# is DEAD → pruned via `git rm` (recoverable from git history).
#
# Fail-safe: any triplet that cannot be classified cleanly is KEPT, never pruned.
#
# NOT touched here: reflex-pass-cycle-* state (kept by psk-workflow-state.sh prune's
# own latest-N-cycles retention), retry-queue.yml, *.log, task-tool-available, spawn/.
#
# Usage:
#   bash agent/scripts/psk-state-cleanup.sh                 # dry run — list, remove nothing
#   bash agent/scripts/psk-state-cleanup.sh --apply         # git-rm the dead triplets
#   bash agent/scripts/psk-state-cleanup.sh --running <wf>  # protect a live workflow id
#
# Exit codes:
#   0  ran cleanly (dry-run or apply)
#   1  usage / environment error

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STATE_DIR="${PSK_STATE_DIR:-$PROJ_ROOT/agent/.workflow-state}"
QUEUE_FILE="${PSK_RETRY_QUEUE_FILE:-$STATE_DIR/retry-queue.yml}"
STATE_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/psk-workflow-state.sh"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'

APPLY=false
RUNNING_WF=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)   APPLY=true; shift ;;
    --running) RUNNING_WF="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -d "$STATE_DIR" ] || { echo "no workflow-state dir — nothing to clean"; exit 0; }

# ── Build the ACTIVE set (newline-delimited workflow ids) ────────────────────
active_ids=""

# (1) retry-queue.yml — every `workflow:` value is a paused/arbitration entry.
if [ -f "$QUEUE_FILE" ]; then
  q_ids=$(grep -E '^[[:space:]]*-?[[:space:]]*workflow:' "$QUEUE_FILE" 2>/dev/null \
    | sed -E 's/.*workflow:[[:space:]]*//; s/"//g; s/[[:space:]]+$//' \
    | grep -v '^$' || true)
  [ -n "$q_ids" ] && active_ids="$active_ids$q_ids"$'\n'
fi

# (2) list-paused — tab-separated <wf>\t<phase>\t<status>; column 1 is the workflow.
if [ -x "$STATE_SCRIPT" ]; then
  p_ids=$(bash "$STATE_SCRIPT" list-paused 2>/dev/null | cut -f1 | grep -v '^$' | sort -u || true)
  [ -n "$p_ids" ] && active_ids="$active_ids$p_ids"$'\n'
fi

# (3) currently-running workflow.
[ -n "$RUNNING_WF" ] && active_ids="$active_ids$RUNNING_WF"$'\n'

active_ids=$(printf '%s' "$active_ids" | grep -v '^$' | sort -u || true)

_is_active() {
  local wf="$1"
  [ -z "$active_ids" ] && return 1
  printf '%s\n' "$active_ids" | grep -qxF "$wf"
}

# ── Enumerate triplet base names ─────────────────────────────────────────────
# A "base" is any <name> that owns a .state/.gates/.run/.dispatch.run/.env file in
# STATE_DIR, EXCLUDING reflex-pass-cycle-* (own retention) and non-triplet files.
strip_ext() {
  local n="$1"
  n="${n%.dispatch.run}"; n="${n%.gates.bak}"
  n="${n%.state}"; n="${n%.gates}"; n="${n%.run}"; n="${n%.env}"
  printf '%s' "$n"
}

bases=$(
  for f in "$STATE_DIR"/*.state "$STATE_DIR"/*.run "$STATE_DIR"/*.dispatch.run \
           "$STATE_DIR"/*.gates "$STATE_DIR"/*.env; do
    [ -e "$f" ] || continue
    b=$(basename "$f"); b=$(strip_ext "$b")
    case "$b" in
      (reflex-pass-cycle-*) continue ;;     # own retention via psk-workflow-state.sh prune
      (retry-queue|session-audit|watchdog|task-tool-available) continue ;;
    esac
    printf '%s\n' "$b"
  done | sort -u
)

# ── Classify + act ───────────────────────────────────────────────────────────
kept=0; pruned=0; stale_flags=0
kept_list=""; prune_files=""

is_all_done() {  # all PHASE_* lines are =done AND ≥1 phase present
  local sf="$1"
  [ -f "$sf" ] || return 1
  grep -qE '^PHASE_' "$sf" || return 1
  ! grep -qE '^PHASE_[^=]+=(pending|in_progress|AWAITING)' "$sf"
}

echo -e "${CYAN}═══ psk-state-cleanup ($([ "$APPLY" = true ] && echo APPLY || echo DRY-RUN)) ═══${NC}"
echo "state dir: $STATE_DIR"
[ -n "$active_ids" ] && echo -e "active (kept) ids: $(printf '%s' "$active_ids" | tr '\n' ' ')" || echo "active ids: (none — full reset)"
echo ""

while IFS= read -r base; do
  [ -z "$base" ] && continue
  if _is_active "$base"; then
    kept=$((kept + 1))
    # Stale-entry cross-check: active only via retry-queue but state is all-done.
    if is_all_done "$STATE_DIR/$base.state" \
       && ! bash "$STATE_SCRIPT" list-paused 2>/dev/null | cut -f1 | grep -qxF "$base"; then
      echo -e "  ${YELLOW}⚠ kept (retry-queue) but .state is all-done — possible STALE queue entry:${NC} $base"
      echo -e "    ${YELLOW}→ if abandoned, clear it: psk-retry-queue.sh clear <id>${NC}"
      stale_flags=$((stale_flags + 1))
    else
      echo -e "  ${GREEN}✓ keep (active):${NC} $base"
    fi
    continue
  fi
  # Fail-safe: prune ONLY a triplet we can CONFIRM is complete (≥1 PHASE, all done).
  # Anything incomplete (pending/in_progress/AWAITING) OR unparseable (no PHASE lines)
  # is kept — we never delete a workflow whose completion we can't prove. This is the
  # guarantee that interrupted/parked work is never lost; only provably-finished work
  # is pruned. (A stale CURRENT_PHASE in .run does NOT block pruning — .state is the
  # authority for completion, so the strict-grant "done-but-CURRENT_PHASE-set" case
  # still prunes.)
  if ! is_all_done "$STATE_DIR/$base.state"; then
    kept=$((kept + 1))
    echo -e "  ${GREEN}✓ keep (incomplete/unparseable — completion not provable):${NC} $base"
    continue
  fi
  # DEAD — confirmed-complete + not active. Collect every sibling that exists.
  pruned=$((pruned + 1))
  echo -e "  ${RED}✗ prune (done):${NC} $base"
  for ext in state gates run dispatch.run env gates.bak; do
    [ -e "$STATE_DIR/$base.$ext" ] && prune_files="$prune_files$STATE_DIR/$base.$ext"$'\n'
  done
done <<< "$bases"

echo ""
echo -e "summary: ${GREEN}$kept kept${NC} · ${RED}$pruned dead${NC}$([ "$stale_flags" -gt 0 ] && echo " · ${YELLOW}$stale_flags stale-queue flag(s)${NC}")"

if [ "$pruned" -eq 0 ]; then
  echo "nothing to prune."
  exit 0
fi

if [ "$APPLY" != true ]; then
  echo -e "${YELLOW}(dry run — re-run with --apply to git-rm the $pruned dead triplet(s))${NC}"
  exit 0
fi

# Apply: git-rm tracked files, plain rm for untracked. Recoverable from git history.
removed=0
while IFS= read -r pf; do
  [ -z "$pf" ] && continue
  if git -C "$PROJ_ROOT" ls-files --error-unmatch "$pf" >/dev/null 2>&1; then
    git -C "$PROJ_ROOT" rm -qf "$pf" >/dev/null 2>&1 && removed=$((removed + 1))
  else
    rm -f "$pf" && removed=$((removed + 1))
  fi
done <<< "$prune_files"

echo -e "${GREEN}✓ pruned $removed file(s) across $pruned dead triplet(s).${NC}"
echo "  Recover any via: git checkout <commit>~1 -- <path>"
exit 0
