#!/bin/bash
# reflex/lib/regression-diff.sh
#
# Compares the current cycle's QA findings against the prior pass's. Identifies:
#   - closed:    IDs that appeared in prior pass but not current (Dev-Agent fixed them)
#   - persisted: IDs present in both cycles (Dev-Agent couldn't fix or deferred)
#   - new:       IDs in current cycle only (newly surfaced)
#   - regressed: IDs previously marked [x] in TASKS.md that re-appear in current QA
#
# A "clean" regression-free cycle means:
#   closed > 0 AND regressed == 0
#
# Called from run.sh --resume-dev after gates pass, before writing the verdict.
# Output: regression-diff.md in the current pass dir + exit code:
#   0 = no regression detected
#   1 = regression detected (some previously-closed task reopened)

set -uo pipefail

PROJ_ROOT="${REFLEX_PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PASS_DIR="${REFLEX_PASS_DIR:-}"
HISTORY="$PROJ_ROOT/reflex/history"
TASKS_FILE="$PROJ_ROOT/agent/TASKS.md"
STATE_DIR="$PROJ_ROOT/agent/.release-state"

[ -z "$PASS_DIR" ] && { echo "regression-diff.sh: no REFLEX_PASS_DIR"; exit 1; }

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

OUT="$PASS_DIR/regression-diff.md"

# Current cycle QA IDs from qa-result.md
cur_result="$STATE_DIR/qa-result.md"
if [ ! -f "$cur_result" ]; then
  echo "No qa-result.md for current cycle — skipping regression diff"
  exit 0
fi
cur_ids=$(grep -oE 'QA-[A-Z0-9]+-[0-9]+(-[A-Z0-9]+)?' "$cur_result" | sort -u)

# Find prior pass — one before $PASS_DIR in alphabetical order
cur_pass_base=$(basename "$PASS_DIR")
prior_dir=$(ls -1d "$HISTORY"/pass-* 2>/dev/null | sort | awk -v cur="$cur_pass_base" '
  $0 ~ cur"$" { if (prev != "") print prev; exit }
  { prev = $0 }
')

if [ -z "$prior_dir" ]; then
  echo "# Regression diff — cycle-001 (first pass, no prior to compare)" > "$OUT"
  echo "  no-prior-pass"
  exit 0
fi

prior_base=$(basename "$prior_dir")

# Prior cycle's IDs — from its qa-summary.md (ids are in TASKS.md with fix annotations too,
# but parsing TASKS.md at fix-time is more reliable)
prior_ids=$(grep -oE 'QA-[A-Z0-9]+-[0-9]+(-[A-Z0-9]+)?' "$TASKS_FILE" 2>/dev/null | sort -u)

# In TASKS.md, find which IDs are [x] (fixed by Dev-Agent prior) vs [ ] (still open)
fixed_ids=$(awk '
  /^- \[x\] \*\*QA-/ { match($0, /QA-[A-Z0-9]+-[0-9]+(-[A-Z0-9]+)?/); if (RLENGTH > 0) print substr($0, RSTART, RLENGTH) }
' "$TASKS_FILE" | sort -u)

open_ids=$(awk '
  /^- \[ \] \*\*QA-/ { match($0, /QA-[A-Z0-9]+-[0-9]+(-[A-Z0-9]+)?/); if (RLENGTH > 0) print substr($0, RSTART, RLENGTH) }
' "$TASKS_FILE" | sort -u)

# Compute set operations
closed=$(comm -23 <(echo "$prior_ids") <(echo "$cur_ids") | grep -v '^$' || true)
persisted=$(comm -12 <(echo "$prior_ids") <(echo "$cur_ids") | grep -v '^$' || true)
new_ids=$(comm -13 <(echo "$prior_ids") <(echo "$cur_ids") | grep -v '^$' || true)

# Regressed = previously fixed [x] but re-appears in current pass
regressed=$(comm -12 <(echo "$fixed_ids") <(echo "$cur_ids") | grep -v '^$' || true)

# Exclude IDs just-closed in THIS pass's dev-result — they're not regressions,
# they're new findings filed and closed within the same pass.
# A real regression is an ID [x] in a PRIOR pass, re-filed this pass, with NO
# matching fix from this pass's Dev-Agent.
cur_dev_result="$STATE_DIR/dev-result.md"
if [ -f "$cur_dev_result" ] && [ -n "$regressed" ]; then
  just_closed=$(grep -oE 'QA-[A-Z0-9]+-[0-9]+(-[A-Z0-9]+)?' "$cur_dev_result" 2>/dev/null | sort -u)
  if [ -n "$just_closed" ]; then
    regressed=$(comm -23 <(echo "$regressed") <(echo "$just_closed") | grep -v '^$' || true)
  fi
fi

count_lines() {
  if [ -z "${1:-}" ]; then
    echo 0
  else
    local n
    n=$(echo -n "$1" | grep -c . 2>/dev/null || true)
    echo "${n:-0}"
  fi
}

n_closed=$(count_lines "$closed")
n_persisted=$(count_lines "$persisted")
n_new=$(count_lines "$new_ids")
n_regressed=$(count_lines "$regressed")

cat > "$OUT" <<EOF
# Regression diff

- prior_cycle: $prior_base
- current_cycle: $cur_pass_base
- closed_since_prior: $n_closed
- persisted: $n_persisted
- new: $n_new
- regressed_from_fixed: $n_regressed

## closed_since_prior (Dev-Agent fixed these)
${closed:-none}

## persisted (present in both cycles)
${persisted:-none}

## new (surfaced this pass)
${new_ids:-none}

## regressed (previously [x], re-appeared)
${regressed:-none}
EOF

echo -e "${CYAN}Regression diff:${NC} closed=$n_closed persisted=$n_persisted new=$n_new regressed=$n_regressed"

if [ "$n_regressed" -gt 0 ]; then
  echo -e "${RED}⚠ REGRESSION DETECTED — $n_regressed task(s) previously [x] are broken again${NC}"
  echo -e "$regressed" | head -10 | sed 's/^/    /'
  exit 1
fi

if [ "$n_closed" -gt 0 ]; then
  echo -e "${GREEN}✓ Net improvement: $n_closed task(s) closed, no regressions${NC}"
fi
exit 0
