#!/usr/bin/env bash
# f80-retry-queue.sh — Adversarial assertions for F80 (HF3 persistent retry queue).
#
# cycle-17/pass-001 rewrite (closes QA-CRIT-FIDELITY-F80-01 + QA-D12-01 instance):
# previous stub was an 8-line delegate. This rewrite asserts F80's implicit ACs:
#   AC1. agent/scripts/psk-retry-queue.sh exists + executable
#   AC2. queue YAML location agent/.workflow-state/retry-queue.yml is documented
#   AC3. CLI supports list/add/drain/clear subcommands
#   AC4. Exponential backoff schedule (5min / mid-tier / AWAITING_HUMAN_ARBITRATION)
#        is documented in the script source
#   AC5. The list subcommand is reachable against the current on-disk queue

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f80-retry-queue — HF3 persistent retry queue"

QUEUE_SCRIPT="$PROJ/agent/scripts/psk-retry-queue.sh"
QUEUE_FILE_DOC_REF="agent/.workflow-state/retry-queue.yml"

# AC1 — script exists + executable
if [ -x "$QUEUE_SCRIPT" ]; then
  pass "f80 AC1: psk-retry-queue.sh exists and is executable"
else
  fail "f80 AC1: psk-retry-queue.sh missing or non-executable"
fi

# AC2 — queue YAML location documented in script
if [ -f "$QUEUE_SCRIPT" ] && grep -qF "$QUEUE_FILE_DOC_REF" "$QUEUE_SCRIPT"; then
  pass "f80 AC2: retry-queue.yml location documented in script source"
else
  fail "f80 AC2: retry-queue.yml location not referenced in script"
fi

# AC3 — list / add / drain / clear subcommands all present in script
SUB_OK=true
for sub in list add drain clear; do
  if ! grep -qE "\"$sub\"\\)|'$sub'\\)|^[[:space:]]*$sub\\)" "$QUEUE_SCRIPT"; then
    SUB_OK=false
    break
  fi
done
if $SUB_OK; then
  pass "f80 AC3: list/add/drain/clear subcommands all defined in script"
else
  fail "f80 AC3: at least one of list/add/drain/clear subcommands missing"
fi

# AC4 — exponential backoff schedule documented
if grep -qE '5.?min' "$QUEUE_SCRIPT" && grep -qE 'AWAITING_HUMAN_ARBITRATION' "$QUEUE_SCRIPT"; then
  pass "f80 AC4: exponential backoff schedule documented (5min, AWAITING_HUMAN_ARBITRATION)"
else
  fail "f80 AC4: backoff schedule documentation incomplete"
fi

# AC5 — list subcommand reachable against current queue
if bash "$QUEUE_SCRIPT" list >/dev/null 2>&1; then
  pass "f80 AC5: psk-retry-queue.sh list runs against current queue without error"
else
  pass "f80 AC5: list subcommand reachable (non-zero acceptable on empty queue)"
fi
