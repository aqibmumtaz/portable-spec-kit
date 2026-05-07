#!/usr/bin/env bash
# F50 — Agent files self-compliance
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
source "$SCRIPT_DIR/../shared/agent-files.sh"
source "$SCRIPT_DIR/../shared/reliability-checks.sh"

section "F50 — Agent files self-compliance"

# Kit's own agent/ files
for f in PLANS.md AGENT.md RELEASES.md SPECS.md TASKS.md AGENT_CONTEXT.md REQS.md; do
  assert_agent_file "$f"
done

# Sync-check infrastructure verifies them
assert_reliability_script "psk-sync-check.sh"
assert_reliability_script "psk-doc-sync.sh"

# Each agent file is non-trivial
for f in SPECS.md PLANS.md TASKS.md RELEASES.md; do
  if [ -f "$PROJ/agent/$f" ] && [ $(wc -l < "$PROJ/agent/$f") -gt 10 ]; then
    pass "F50: agent/$f non-trivial"
  else
    fail "F50: agent/$f too short or missing"
  fi
done
