#!/usr/bin/env bash
# F3 — 6 agent file templates (AGENT, AGENT_CONTEXT, SPECS, PLANS, TASKS, RELEASES)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/agent-files.sh"

section "F3 — 6 agent file templates"

assert_agent_file "AGENT.md"
assert_agent_file "AGENT_CONTEXT.md"
assert_agent_file "SPECS.md"
assert_agent_file "PLANS.md"
assert_agent_file "TASKS.md"
assert_agent_file "RELEASES.md"

# Pipeline files referenced in framework
for f in REQS SPECS PLANS TASKS RELEASES AGENT_CONTEXT; do
  if kit_grep "$f.md" -q; then
    pass "F3: framework references $f.md template"
  else
    fail "F3: framework missing $f.md reference"
  fi
done
