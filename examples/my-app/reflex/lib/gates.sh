#!/bin/bash
# reflex/lib/gates.sh
#
# Runs the mechanical gates configured in reflex/config.yml. Called by
# run.sh after the Dev-Agent finishes, to verify the Dev-Agent's commits
# didn't break anything globally.
#
# Dev-Agent runs gates PER COMMIT on its own during its cycle. This
# script re-runs them across the whole branch state to catch cross-commit
# issues.
#
# Exit 0 → all gates green; exit 1 → at least one gate failed.

set -uo pipefail

PROJ_ROOT="${REFLEX_PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONFIG_FILE="$PROJ_ROOT/reflex/config.yml"
PASS_DIR="${REFLEX_PASS_DIR:-}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

cd "$PROJ_ROOT"

gates=$(awk '/^mechanical_gates:/,0' "$CONFIG_FILE" 2>/dev/null | sed -n 's/^[[:space:]]*-[[:space:]]\{1,\}//p')

if [ -z "$gates" ]; then
  echo -e "${YELLOW}⚠ no mechanical gates configured in reflex/config.yml — skipping${NC}"
  exit 0
fi

echo -e "${CYAN}═══ Running mechanical gates ═══${NC}"

fails=0
results=""

while IFS= read -r gate; do
  [ -z "$gate" ] && continue
  echo -e "  → ${gate}"
  if bash -c "$gate" >/dev/null 2>&1; then
    echo -e "    ${GREEN}✓ pass${NC}"
    results="${results}PASS  ${gate}\n"
  else
    echo -e "    ${RED}✗ fail${NC}"
    results="${results}FAIL  ${gate}\n"
    fails=$((fails + 1))
  fi
done <<< "$gates"

# Record results for the verdict
if [ -n "$PASS_DIR" ] && [ -d "$PASS_DIR" ]; then
  {
    echo "# Mechanical gates — reflex pass"
    echo
    printf "%b" "$results"
    echo
    echo "Failed: $fails"
  } > "$PASS_DIR/gates-result.md"
fi

if [ "$fails" -eq 0 ]; then
  echo -e "${GREEN}✓ all gates passed${NC}"
  exit 0
else
  echo -e "${RED}✗ $fails gate(s) failed${NC}"
  exit 1
fi
