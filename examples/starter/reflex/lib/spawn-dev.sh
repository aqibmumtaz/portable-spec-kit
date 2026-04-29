#!/bin/bash
# reflex/lib/spawn-dev.sh
#
# Writes dev-task.md and signals AWAITING_DEV. Same file-based protocol as
# spawn-qa.sh:
#   1. Write agent/.release-state/dev-task.md with the full prompt + context
#   2. Exit 2 — main Claude Code session must spawn a Task-tool sub-agent
#      with the prompt, write the sub-agent's response to dev-result.md
#   3. run.sh re-entered via --resume-dev picks up the result

set -uo pipefail

PROJ_ROOT="${REFLEX_PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PASS_DIR="${REFLEX_PASS_DIR:-$PROJ_ROOT/reflex/history/pass-$(date +%Y%m%d-%H%M%S)}"
STATE_DIR="$PROJ_ROOT/agent/.release-state"
TASK_FILE="$STATE_DIR/dev-task.md"
RESULT_FILE="$STATE_DIR/dev-result.md"
STAMP_FILE="$STATE_DIR/.dev-invoke-stamp"

PROMPT_FILE="$PROJ_ROOT/reflex/prompts/dev-agent.md"
CONFIG_FILE="$PROJ_ROOT/reflex/config.yml"

RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

mkdir -p "$PASS_DIR" "$STATE_DIR"

if [ ! -f "$PROMPT_FILE" ]; then
  echo -e "${RED}✗ dev-agent prompt not found at $PROMPT_FILE${NC}"
  exit 1
fi

date +%s > "$STAMP_FILE"

# Pull budget caps from config
budget_calls=$(grep -E '^\s*max_tool_calls_per_cycle:' "$CONFIG_FILE" 2>/dev/null | grep -oE '[0-9]+' | head -1)
budget_retries=$(grep -E '^\s*max_retries_per_task:' "$CONFIG_FILE" 2>/dev/null | grep -oE '[0-9]+' | head -1)
budget_calls="${budget_calls:-200}"
budget_retries="${budget_retries:-3}"

# Mechanical gates list (one per line, stripped of leading "- ")
gates=$(awk '/^mechanical_gates:/,0' "$CONFIG_FILE" | grep -E '^\s*-\s' | sed 's/^\s*-\s*//')

cat > "$TASK_FILE" <<EOF
---
role: Dev-Agent (reflex Actor)
cycle_dir: $PASS_DIR
project_root: $PROJ_ROOT
budget:
  max_tool_calls: $budget_calls
  max_retries_per_task: $budget_retries
---

$(cat "$PROMPT_FILE")

---

## Project context for this cycle

Project root: $PROJ_ROOT

## Mechanical gates (run these after every fix)

Each must pass green before committing the fix:

\`\`\`
$gates
\`\`\`

## Write your outputs here

- $PASS_DIR/dev-trace.md — per-task diagnosis + fix log
- $PASS_DIR/deferred-decisions.md — any [~] escalations (only if used)
- $RESULT_FILE — machine-parsed final summary (see schema in prompt)

## Task queue

Read $PROJ_ROOT/agent/TASKS.md. Find the current version's "QA Findings" subsection. Filter tasks tagged @reflex-dev. Skip any marked [x] or [~]. Process in severity order (CRITICAL, MAJOR, MINOR, NIT).

## Start

Begin Step 1 now.
EOF

echo -e "${YELLOW}⏳ AWAITING_DEV — reflex needs the main Claude Code session to spawn the Dev sub-agent${NC}"
echo ""
echo -e "  ${CYAN}Agent protocol:${NC}"
echo -e "    1. Read:  $TASK_FILE"
echo -e "    2. Spawn a Task-tool sub-agent (general-purpose) with the exact task content"
echo -e "    3. Sub-agent writes: $PASS_DIR/dev-trace.md + $RESULT_FILE"
echo -e "    4. Then re-run: ${CYAN}bash reflex/run.sh --resume-dev${NC}"

exit 2
