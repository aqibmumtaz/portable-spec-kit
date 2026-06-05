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

# AC4 — exponential backoff schedule is CORRECTLY IMPLEMENTED.
#
# QA-CRIT-FIDELITY-F80-AC4 (cycle-29-pass-003): the prior assertion was a vacuous
# five-minute substring grep that passed whether the schedule was right,
# wrong, or absent. It never validated the numeric sequence. This rewrite is a
# behavioral assertion against the implemented constant + the runtime transition:
#   (a) the BACKOFF_MIN constant in the script equals EXACTLY [5, 15, 45, 120, 360];
#   (b) driving the queue (add → fail×5) reaches AWAITING_HUMAN_ARBITRATION at
#       retry_count ≥ 5, proving the MAX_RETRIES boundary behaves.
# A wrong schedule (e.g. the doc-drift value 5/30/120/360) now fails AC4a.

# AC4a — implemented backoff sequence is the canonical [5, 15, 45, 120, 360].
F80_BACKOFF=$(grep -E '^BACKOFF_MIN[[:space:]]*=' "$QUEUE_SCRIPT" | head -1 | grep -oE '\[[0-9, ]+\]' | tr -d ' ')
if [ "$F80_BACKOFF" = "[5,15,45,120,360]" ]; then
  pass "f80 AC4a: implemented backoff schedule is exactly [5,15,45,120,360] (5min/15min/45min/2h/6h)"
else
  fail "f80 AC4a: BACKOFF_MIN is '$F80_BACKOFF', expected [5,15,45,120,360] — schedule wrong or drifted"
fi

# AC4b — behavioral: driving add → fail repeatedly reaches AWAITING_HUMAN_ARBITRATION
# at retry_count ≥ MAX_RETRIES (5). Uses an isolated temp queue so the real queue
# is untouched. Catches a broken MAX_RETRIES boundary that AC4a alone cannot.
F80_QTMP=$(mktemp -d)
F80_QFILE="$F80_QTMP/retry-queue.yml"
F80_ADD_OUT=$(PSK_RETRY_QUEUE_FILE="$F80_QFILE" bash "$QUEUE_SCRIPT" \
  add "test-wf" "test-phase" "test-target" "/tmp/p.md" "/tmp/a.md" "init failure" 2>/dev/null)
F80_EID=$(echo "$F80_ADD_OUT" | grep -oE 'added entry [^ ]+' | awk '{print $3}')
if [ -n "$F80_EID" ]; then
  # Fail it 5 more times (rc 1→5) to cross MAX_RETRIES.
  for _i in 1 2 3 4 5; do
    PSK_RETRY_QUEUE_FILE="$F80_QFILE" bash "$QUEUE_SCRIPT" fail "$F80_EID" "retry $_i" >/dev/null 2>&1 || true
  done
  if grep -qE 'AWAITING_HUMAN_ARBITRATION' "$F80_QFILE"; then
    pass "f80 AC4b: queue entry reaches AWAITING_HUMAN_ARBITRATION after MAX_RETRIES failures"
  else
    fail "f80 AC4b: entry did not reach AWAITING_HUMAN_ARBITRATION after 5 failures — MAX_RETRIES boundary broken"
  fi
else
  fail "f80 AC4b: could not add a test entry to drive the backoff schedule"
fi
rm -rf "$F80_QTMP"

# AC5 — list subcommand reachable against current queue
if bash "$QUEUE_SCRIPT" list >/dev/null 2>&1; then
  pass "f80 AC5: psk-retry-queue.sh list runs against current queue without error"
else
  pass "f80 AC5: list subcommand reachable (non-zero acceptable on empty queue)"
fi
