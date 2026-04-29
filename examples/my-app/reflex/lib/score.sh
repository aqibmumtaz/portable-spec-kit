#!/bin/bash
# reflex/lib/score.sh
#
# Computes one summary row per cycle and appends to reflex/history/summary.csv.
#
# Metric:
#   surprise_density = qa_findings / features_tested
#
# Lower is better. When density trends toward zero over cycles, the project is
# maturing. Regression is when density INCREASES compared to the previous cycle.
#
# summary.csv columns:
#   cycle, date, qa_findings, dev_fixes, escalated, features_tested,
#   surprise_density, progress, gates_status

set -uo pipefail

PROJ_ROOT="${REFLEX_PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HISTORY="$PROJ_ROOT/reflex/history"
CSV="$HISTORY/summary.csv"
PASS_DIR="${REFLEX_PASS_DIR:-}"
STATE_DIR="$PROJ_ROOT/agent/.release-state"

[ -z "$PASS_DIR" ] && { echo "score.sh: no REFLEX_PASS_DIR set"; exit 1; }

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# Ensure CSV exists with header
if [ ! -f "$CSV" ]; then
  echo "cycle,date,qa_findings,dev_fixes,escalated,features_tested,surprise_density,progress,gates_status" > "$CSV"
fi

# Cycle number from directory name (cycle-NNN)
cycle_num=$(basename "$PASS_DIR" | sed 's/pass-//;s/^0*//')
cycle_num="${cycle_num:-0}"
date_stamp=$(date -u +%Y-%m-%d)

# Findings count from qa-result.md
qa_result="$STATE_DIR/qa-result.md"
qa_findings=0
[ -f "$qa_result" ] && qa_findings=$(grep -c '^- id:' "$qa_result" 2>/dev/null | tr -d '\n')
qa_findings="${qa_findings:-0}"

# Features tested from qa-result.md summary (tests_planned)
features_tested=0
[ -f "$qa_result" ] && features_tested=$(grep -E '^\s*-\s*tests_planned:' "$qa_result" 2>/dev/null | grep -oE '[0-9]+' | head -1)
features_tested="${features_tested:-0}"

# Dev fixes + escalations from dev-result.md
dev_result="$STATE_DIR/dev-result.md"
dev_fixes=0
escalated=0
if [ -f "$dev_result" ]; then
  dev_fixes=$(awk '
    /^## Fixes/    { section = "fixes"; next }
    /^## /         { section = "other" }
    section == "fixes" && /^- id:/ { count++ }
    END { print count+0 }
  ' "$dev_result")
  escalated=$(awk '
    /^## Escalated/ { section = "esc"; next }
    /^## /          { section = "other" }
    section == "esc" && /^- id:/ { count++ }
    END { print count+0 }
  ' "$dev_result")
fi
dev_fixes="${dev_fixes:-0}"
escalated="${escalated:-0}"

# Surprise density (findings per features tested) — 2 decimal places
if [ "$features_tested" -gt 0 ]; then
  density=$(awk -v f="$qa_findings" -v t="$features_tested" 'BEGIN { printf "%.3f", f / t }')
else
  density="0.000"
fi

# Progress: compared to previous row's findings, did net findings decrease?
# progress = (prev_findings - prev_fixes) - (current_findings - current_fixes)
# Positive = project is improving (unfixed backlog shrank)
# Zero = no change. Negative = regression.
progress="n/a"
if [ -f "$CSV" ] && [ "$(wc -l < "$CSV")" -gt 1 ]; then
  prev_row=$(tail -n 1 "$CSV")
  prev_findings=$(echo "$prev_row" | awk -F',' '{print $3}')
  prev_fixes=$(echo "$prev_row" | awk -F',' '{print $4}')
  if [[ "$prev_findings" =~ ^[0-9]+$ ]] && [[ "$prev_fixes" =~ ^[0-9]+$ ]]; then
    prev_backlog=$((prev_findings - prev_fixes))
    cur_backlog=$((qa_findings - dev_fixes))
    progress=$((prev_backlog - cur_backlog))
  fi
fi

gates_status="${REFLEX_GATES_STATUS:-unknown}"

row="${cycle_num},${date_stamp},${qa_findings},${dev_fixes},${escalated},${features_tested},${density},${progress},${gates_status}"
echo "$row" >> "$CSV"

echo -e "${CYAN}Score row appended:${NC} $row"
echo -e "  surprise_density: ${density} (lower is better)"
echo -e "  progress: ${progress} ($([ "$progress" = "n/a" ] && echo "first cycle" || (test "$progress" -gt 0 && echo "improvement ✓" || (test "$progress" -eq 0 && echo "no change ·" || echo "REGRESSION ✗"))))"
