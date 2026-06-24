#!/bin/bash
# mechanical-script: deterministic, no AI prompts (Dim 28 allowlist — v0.6.60 HF7b)
# ════════════════════════════════════════════════════════════════
# psk-close-finding.sh — Mark a reflex finding as closed
#
# Closes the kit's structural gap: when a finding is fixed by a commit
# OUTSIDE of a reflex pass (manual fix, cross-cycle work, etc.), the
# finding's pass dir findings.yaml stays in `status: pending` state.
# count_findings_yaml then keeps the cycle "open" forever, blocking
# new cycles from advancing.
#
# This script lets you mark a finding closed with one command, so
# reflex's per-cycle continuation logic correctly advances when all
# findings are resolved.
#
# Usage:
#   bash agent/scripts/psk-close-finding.sh <finding-id> <closure-rationale>
#   bash agent/scripts/psk-close-finding.sh QA-KIT-VERSION-02 "fixed in commit abc123 — version cascade bumped"
#   bash agent/scripts/psk-close-finding.sh --pass cycle-NN/pass-MMM <id> <rationale>  # explicit pass
#
# What it does:
#   1. Finds the latest pass dir containing this finding (or uses --pass)
#   2. Adds `status: closed` + `closed_at: YYYY-MM-DD` + `closure_rationale: <text>`
#      after the finding's `id:` line
#   3. Reports the change so user can verify
#
# Exit:
#   0 — finding closed successfully
#   1 — finding not found OR closure failed
#   2 — invalid args
# ════════════════════════════════════════════════════════════════

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
HISTORY="$PROJ_ROOT/reflex/history"
PASS_OVERRIDE=""

# Parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --pass) PASS_OVERRIDE="$2"; shift 2 ;;
    --help|-h)
      sed -n '/^# Usage:/,/^# ====/p' "$0" | head -15
      exit 0
      ;;
    *) break ;;
  esac
done

FINDING_ID="${1:-}"
RATIONALE="${2:-}"

if [ -z "$FINDING_ID" ] || [ -z "$RATIONALE" ]; then
  echo "Usage: $0 <finding-id> <closure-rationale>" >&2
  echo "Example: $0 QA-KIT-VERSION-02 \"fixed in commit abc123\"" >&2
  exit 2
fi

# Find the pass dir containing this finding
TARGET_PASS=""
if [ -n "$PASS_OVERRIDE" ]; then
  TARGET_PASS="$HISTORY/$PASS_OVERRIDE"
  if [ ! -f "$TARGET_PASS/findings.yaml" ]; then
    echo "✗ Pass dir not found: $TARGET_PASS" >&2
    exit 1
  fi
else
  # Search latest-first across cycle-NN/pass-NNN + standalone/pass-NNN.
  # Use find with null-separation to handle paths containing spaces correctly.
  while IFS= read -r -d '' d; do
    d="${d%/}"
    if grep -qE "^[[:space:]]*-[[:space:]]*id:[[:space:]]*\"?${FINDING_ID}\"?[[:space:]]*$" "$d/findings.yaml" 2>/dev/null; then
      TARGET_PASS="$d"
      break
    fi
  done < <(find "$HISTORY" -mindepth 2 -maxdepth 3 -type d -name "pass-*" -print0 2>/dev/null | xargs -0 -I {} stat -f "%m {}" 2>/dev/null | sort -rn | cut -d' ' -f2- | tr '\n' '\0')
fi

if [ -z "$TARGET_PASS" ]; then
  echo "✗ Finding $FINDING_ID not found in any pass dir" >&2
  echo "  Try: --pass cycle-NN/pass-NNN to specify explicitly" >&2
  exit 1
fi

FINDINGS="$TARGET_PASS/findings.yaml"

# Check if already closed
if awk -v fid="$FINDING_ID" '
  $0 ~ "^[[:space:]]*-[[:space:]]*id:[[:space:]]*\"?"fid"\"?[[:space:]]*$" { in_finding=1; next }
  in_finding && /^[[:space:]]*-[[:space:]]*id:/ { in_finding=0 }
  in_finding && /^[[:space:]]*status:[[:space:]]*(closed|closed-by-doc|fixed)/ { found=1; exit }
  END { exit (found ? 0 : 1) }
' "$FINDINGS"; then
  echo "ℹ Finding $FINDING_ID already marked closed in $(basename "$TARGET_PASS")"
  exit 0
fi

# Insert status: closed + closed_at + closure_rationale after the finding's `id:` line.
# We add the fields immediately after the id line so they're inside the finding entry.
TODAY=$(date -u +%Y-%m-%d)
TMP=$(mktemp)
awk -v fid="$FINDING_ID" -v today="$TODAY" -v rationale="$RATIONALE" '
  {
    print
    if ($0 ~ "^[[:space:]]*-[[:space:]]*id:[[:space:]]*\"?"fid"\"?[[:space:]]*$") {
      # Determine indentation from the next line, fallback to 4 spaces
      indent = "    "
      print indent "status: closed"
      print indent "closed_at: " today
      print indent "closure_rationale: |"
      n = split(rationale, lines, "\n")
      for (i = 1; i <= n; i++) print indent "  " lines[i]
    }
  }
' "$FINDINGS" > "$TMP" && mv "$TMP" "$FINDINGS"

echo "✓ Closed $FINDING_ID in $(basename "$(dirname "$TARGET_PASS")")/$(basename "$TARGET_PASS")"
echo "  Rationale: $RATIONALE"

# Closes QA-AUDIT-CSV-01 (v0.6.28): when this close-finding action results
# in zero unclosed findings for the pass AND a signoff exists, the cycle is
# about to advance — auto-invoke score.sh so summary.csv has a row for the
# closing pass before the next cycle starts. Previously the closing-cycle
# pass could remain unscored (cycle-03/pass-001 was missing from
# summary.csv until manual score.sh invocation).
PROJ_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCORE_SH="$PROJ_ROOT/reflex/lib/score.sh"
if [ -x "$SCORE_SH" ]; then
  unclosed=$(awk '
    /^  - id:/ { in_finding=1; closed=0; next }
    in_finding && /^[[:space:]]*status:[[:space:]]*(closed|closed-by-doc|fixed)/ { closed=1 }
    in_finding && /^  - id:/ { if (!closed) total++; in_finding=1; closed=0; next }
    END { if (in_finding && !closed) total++; print total+0 }
  ' "$FINDINGS")
  has_signoff=0
  [ -f "$TARGET_PASS/signoff.md" ] && has_signoff=1
  has_csv_row=0
  cycle_num=$(basename "$(dirname "$TARGET_PASS")" | sed -nE 's/^cycle-0*([0-9]+)$/\1/p')
  pass_num=$(basename "$TARGET_PASS" | sed -nE 's/^pass-0*([0-9]+)$/\1/p')
  CSV="$PROJ_ROOT/reflex/history/summary.csv"
  if [ -f "$CSV" ] && [ -n "$cycle_num" ] && [ -n "$pass_num" ]; then
    grep -qE "^${cycle_num},${pass_num}," "$CSV" 2>/dev/null && has_csv_row=1
  fi
  if [ "$unclosed" = "0" ] && [ "$has_signoff" = "1" ] && [ "$has_csv_row" = "0" ]; then
    echo ""
    echo "All findings closed → invoking score.sh to record summary.csv row"
    REFLEX_PASS_DIR="$TARGET_PASS" bash "$SCORE_SH" 2>&1 | sed 's/^/  /'
  fi
fi

echo ""
echo "Verify:"
echo "  bash reflex/run.sh status   # should now show advanced cycle when all findings closed"
exit 0
