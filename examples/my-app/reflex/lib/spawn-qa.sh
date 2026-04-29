#!/bin/bash
# reflex/lib/spawn-qa.sh
#
# Writes qa-task.md and signals AWAITING_QA. Mirrors the existing
# psk-critic-spawn.sh / psk-validate.sh file-based protocol:
#
#   1. This script writes agent/.release-state/qa-task.md with the prompt
#   2. Exits code 2 (AWAITING_QA) — the main Claude Code session picks up
#      the signal, spawns a Task-tool sub-agent with the exact prompt,
#      writes the sub-agent's response to qa-result.md
#   3. run.sh re-enters, sees qa-result.md is fresh, parses findings,
#      calls file-bugs.sh to append them to TASKS.md
#
# This keeps the protocol identical to the kit's existing critic machinery.

set -uo pipefail

PROJ_ROOT="${REFLEX_PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PASS_DIR="${REFLEX_PASS_DIR:-$PROJ_ROOT/reflex/history/pass-$(date +%Y%m%d-%H%M%S)}"
STATE_DIR="$PROJ_ROOT/agent/.release-state"
TASK_FILE="$STATE_DIR/qa-task.md"
RESULT_FILE="$STATE_DIR/qa-result.md"
STAMP_FILE="$STATE_DIR/.qa-invoke-stamp"

PROMPT_FILE="$PROJ_ROOT/reflex/prompts/qa-agent.md"

RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

mkdir -p "$PASS_DIR" "$STATE_DIR"

if [ ! -f "$PROMPT_FILE" ]; then
  echo -e "${RED}✗ qa-agent prompt not found at $PROMPT_FILE${NC}"
  exit 1
fi

# Fresh stamp — used later to verify qa-result.md mtime > stamp
date +%s > "$STAMP_FILE"

# Build the task file: prompt template + project-specific context pointer
cat > "$TASK_FILE" <<EOF
---
role: QA-Agent (reflex Critic)
cycle_dir: $PASS_DIR
project_root: $PROJ_ROOT
---

$(cat "$PROMPT_FILE")

---

## Project context pointers (read these first)

Read these files from $PROJ_ROOT:

- \`agent/REQS.md\` — business requirements
- \`agent/SPECS.md\` — feature contracts + acceptance criteria
- \`agent/PLANS.md\` — architecture and stack
- \`agent/DESIGN.md\` and \`agent/design/*.md\` — design decisions per feature
- \`agent/TASKS.md\` — current completed tasks, existing QA Findings
- \`agent/RELEASES.md\` — version history
- \`README.md\` — public contract

Do NOT read:
- \`src/*\`, \`lib/*\` — source code
- \`agent/scripts/*.sh\` — internal orchestration
- \`reflex/\` — reflex itself is out of scope for testing

## Write your outputs here

- $PASS_DIR/project-understanding.md — Phase 1 output (study summary)
- $PASS_DIR/test-plan.md — Phase 2 output (planned test cases per feature)
- $PASS_DIR/qa-summary.md — Phase 3+4 output (findings, one entry per bug)

## When done, write this single summary file to RESULT_FILE

$RESULT_FILE format (machine-parsed by file-bugs.sh):

\`\`\`
# QA-Agent cycle result

## Findings

- id: QA-F12-01
  feature: F12
  severity: CRITICAL
  assignee: reflex-dev
  title: Export-to-PDF returns empty buffer
  spec_ref: SPECS.md:42
  acceptance_ref: "ATS-compatible PDF"
  evidence: $PASS_DIR/qa-summary.md#F12-01

- id: QA-ARCH-01
  feature: ARCH
  severity: MAJOR
  assignee: human
  title: PLANS.md says Postgres, code uses Redis
  spec_ref: PLANS.md:88
  evidence: $PASS_DIR/qa-summary.md#ARCH-01

## Summary

- tests_planned: 47
- tests_executed: 47
- tests_passed: 39
- tests_failed: 8
- critical: 2
- major: 4
- minor: 2
- nit: 0
\`\`\`

If you find zero new issues, write a valid RESULT_FILE with \`## Findings\` empty and a populated \`## Summary\`.
EOF

echo -e "${YELLOW}⏳ AWAITING_QA — reflex needs the main Claude Code session to spawn the QA sub-agent${NC}"
echo ""
echo -e "  ${CYAN}Agent protocol:${NC}"
echo -e "    1. Read:  $TASK_FILE"
echo -e "    2. Spawn a Task-tool sub-agent (general-purpose) with the exact task content"
echo -e "    3. Have the sub-agent write outputs to $PASS_DIR and the result file to $RESULT_FILE"
echo -e "    4. Then re-run: ${CYAN}bash reflex/run.sh${NC}"

exit 2
