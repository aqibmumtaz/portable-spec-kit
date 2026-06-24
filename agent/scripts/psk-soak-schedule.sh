#!/bin/bash
# mechanical-script: deterministic, no AI prompts (Dim 28 allowlist — v0.6.60 HF7b)
# ════════════════════════════════════════════════════════════════
# psk-soak-schedule.sh — Post-merge 48h soak gauntlet (P01, v0.6.25+, ADR-035)
#
# Re-runs psk-evolution-gauntlet.sh against any proposal that landed
# on main between 9 days ago and 2 days ago (the "soak window"). On
# any gate failure during the soak run, files an automatic
# revert-Pxx-name task in agent/TASKS.md under the active backlog.
#
# Companion to docs/work-flows/19-kit-evolution-gauntlet.md §Post-merge
# soak. Invoked by .github/workflows/postmerge-gauntlet-soak.yml on a
# daily cron OR manually for ad-hoc soak.
#
# Implements P6 — Structural Enforcement Over Trust (PHILOSOPHY.md).
#
# Usage:
#   bash agent/scripts/psk-soak-schedule.sh [--since=9days] [--until=2days] [--dry-run]
#   bash agent/scripts/psk-soak-schedule.sh --proposal Pxx-name  # single-proposal mode
#
# Env:
#   PSK_SOAK_DISABLED=1     skip entirely (CI emergency only)
#   PSK_SOAK_DRY_RUN=1      same as --dry-run (no TASKS.md modifications)
# ════════════════════════════════════════════════════════════════

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
GAUNTLET="$PROJ_ROOT/agent/scripts/psk-evolution-gauntlet.sh"
TASKS="$PROJ_ROOT/agent/TASKS.md"

# --- Args ---
SINCE="9 days ago"
UNTIL="2 days ago"
DRY_RUN="${PSK_SOAK_DRY_RUN:-0}"
SINGLE_PROPOSAL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --since=*)    SINCE="${1#*=}"; shift ;;
    --until=*)    UNTIL="${1#*=}"; shift ;;
    --dry-run)    DRY_RUN=1; shift ;;
    --proposal)   SINGLE_PROPOSAL="$2"; shift 2 ;;
    --help|-h)
      sed -n '/^# Usage:/,/^# ====/p' "$0" | head -20
      exit 0
      ;;
    *)            echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# --- Bypass ---
if [ "${PSK_SOAK_DISABLED:-0}" = "1" ]; then
  echo "[psk-soak] disabled via PSK_SOAK_DISABLED=1"
  exit 0
fi

# --- Sanity ---
if [ ! -x "$GAUNTLET" ]; then
  echo "[psk-soak] gauntlet not executable: $GAUNTLET" >&2
  exit 1
fi
# Accept either a direct .git or being inside a git worktree (nested-repo layout)
if [ ! -d "$PROJ_ROOT/.git" ]; then
  if ! git -C "$PROJ_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "[psk-soak] not a git repo (no .git dir, not inside worktree)" >&2
    exit 1
  fi
fi

# --- Find proposals to soak ---
PROPOSALS=()

if [ -n "$SINGLE_PROPOSAL" ]; then
  PROPOSALS+=("$SINGLE_PROPOSAL")
else
  # Scan git log for proposal-bearing commits in the soak window
  COMMITS=$(git -C "$PROJ_ROOT" log --since="$SINCE" --until="$UNTIL" --grep='\[proposal: [PG][0-9]\+' --pretty=format:"%H %s" 2>/dev/null)
  if [ -z "$COMMITS" ]; then
    echo "[psk-soak] no proposal commits in soak window ($SINCE to $UNTIL)"
    exit 0
  fi
  while read -r line; do
    pid=$(echo "$line" | grep -oE '\[proposal: [PG][0-9]+-[a-z0-9-]+' | sed 's/\[proposal: //' | head -1)
    [ -n "$pid" ] && PROPOSALS+=("$pid")
  done <<< "$COMMITS"
fi

if [ "${#PROPOSALS[@]}" -eq 0 ]; then
  echo "[psk-soak] no proposals to soak"
  exit 0
fi

# Dedup (bash-3.2-safe: macOS ships /bin/bash 3.2 where `mapfile`/`readarray`
# is absent — a `mapfile` call there fails silently, leaving duplicates. Use a
# portable while-read rebuild instead. Mirrors the bash-3.2-compat mandate in
# psk-ui-completeness.sh / findings-registry.sh / doc-code-diff.sh.)
_dedup_tmp=()
while IFS= read -r _p; do
  [ -n "$_p" ] && _dedup_tmp+=("$_p")
done < <(printf '%s\n' "${PROPOSALS[@]}" | sort -u)
PROPOSALS=("${_dedup_tmp[@]}")
unset _dedup_tmp _p

echo "[psk-soak] soaking ${#PROPOSALS[@]} proposal(s): ${PROPOSALS[*]}"

# --- Run gauntlet on each proposal ---
FAILURES=()
for pid in "${PROPOSALS[@]}"; do
  # Look in proposed/, then rejected/, then archived locations
  local_file=""
  for dir in "agent/tasks/proposed" "agent/tasks/rejected" "agent/tasks"; do
    candidate="$PROJ_ROOT/$dir/$pid.md"
    if [ -f "$candidate" ]; then
      local_file="$candidate"
      break
    fi
  done

  if [ -z "$local_file" ]; then
    echo "  [psk-soak] $pid: proposal file not found, skipping"
    continue
  fi

  echo "  [psk-soak] $pid: re-running gauntlet on $local_file"

  # Run in quick mode to skip Gate D fixture-reflex (still expensive in soak)
  # Gate F is auto-deferred in non-interactive mode.
  if PSK_GAUNTLET_QUICK=1 bash "$GAUNTLET" "$local_file" >/tmp/psk-soak-$$.log 2>&1; then
    echo "    ✓ $pid: gauntlet still green"
  else
    rc=$?
    failure_summary=$(tail -5 /tmp/psk-soak-$$.log | grep -iE "fail|error" | head -3 | tr '\n' ' ')
    [ -z "$failure_summary" ] && failure_summary="exit=$rc (see CI log)"
    echo "    ✗ $pid: SOAK REGRESSION — $failure_summary"
    FAILURES+=("$pid|$failure_summary")
  fi
  rm -f /tmp/psk-soak-$$.log
done

# --- File auto-revert tasks for failures ---
if [ "${#FAILURES[@]}" -eq 0 ]; then
  echo "[psk-soak] all proposals soak-clean. ${#PROPOSALS[@]}/${#PROPOSALS[@]} green."
  exit 0
fi

echo "[psk-soak] ${#FAILURES[@]} of ${#PROPOSALS[@]} proposals regressed during soak"

if [ "$DRY_RUN" = "1" ]; then
  echo "[psk-soak] DRY-RUN — would file these revert tasks:"
  for f in "${FAILURES[@]}"; do
    pid="${f%|*}"
    summary="${f#*|}"
    echo "  - revert-$pid (soak-fail $(date +%Y-%m-%d): $summary)"
  done
  exit 0
fi

# Append to TASKS.md under the active backlog. Find the first
# `### v0.x` heading under `## Backlog` and insert revert tasks there.
if [ ! -f "$TASKS" ]; then
  echo "[psk-soak] $TASKS missing — cannot file revert tasks" >&2
  exit 1
fi

backlog_header=$(grep -nE "^## Backlog" "$TASKS" | head -1 | cut -d: -f1)
if [ -z "$backlog_header" ]; then
  echo "[psk-soak] no '## Backlog' section in TASKS.md — appending to end" >&2
  insert_line=$(wc -l < "$TASKS" | tr -d ' ')
else
  # Insert after the first `### v0.x` heading under backlog
  insert_line=$(awk -v start="$backlog_header" 'NR > start && /^### v[0-9]/ { print NR; exit }' "$TASKS")
  [ -z "$insert_line" ] && insert_line=$((backlog_header + 2))
fi

today=$(date +%Y-%m-%d)
revert_block="\n### Soak-regression auto-revert tasks (filed $today)\n\n"
for f in "${FAILURES[@]}"; do
  pid="${f%|*}"
  summary="${f#*|}"
  revert_block+="- [ ] **revert-$pid** @kit-maintainer: post-merge soak (48h re-run via psk-soak-schedule.sh) detected regression — $summary. Investigate; either fix the regression or revert the proposal commit.\n"
done

# Insert via temp file (cross-platform — sed -i is GNU-only)
tmpfile=$(mktemp)
awk -v line="$insert_line" -v block="$revert_block" 'NR == line { printf "%s", block } { print }' "$TASKS" > "$tmpfile"
mv "$tmpfile" "$TASKS"

echo "[psk-soak] filed ${#FAILURES[@]} revert task(s) in $TASKS at line $insert_line"
echo "[psk-soak] kit maintainer: review TASKS.md and decide fix-or-revert per task"
exit 1  # Non-zero to flag CI workflow as failed
