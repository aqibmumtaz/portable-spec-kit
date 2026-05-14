#!/usr/bin/env bash
# F73 — psk-plan-save.sh lifecycle: save → approve → start → done → list → show
#       + idempotency contract (re-save must preserve status + commits)
#
# Closes QA-C11P001-PLANSAVE-NO-TESTS-03 (cycle-11/pass-001 finding).
# Asserts the plan-save protocol from CLAUDE.md §Plan-Save Protocol works
# end-to-end and that re-save is idempotent across lifecycle transitions.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "F73 — psk-plan-save.sh lifecycle + idempotency"

SCRIPT="$PROJ/agent/scripts/psk-plan-save.sh"

if [ ! -x "$SCRIPT" ]; then
  fail "F73: psk-plan-save.sh missing or not executable"
  return 0 2>/dev/null || exit 1
fi
pass "F73: psk-plan-save.sh exists and is executable"

# Isolate the test in a sandbox PROJ_ROOT so we don't touch the real
# agent/plans/ directory in the kit repo.
SANDBOX=$(mktemp -d -t f73-plan-save.XXXXXX)
trap 'rm -rf "$SANDBOX"' RETURN
export PROJ_ROOT="$SANDBOX"
mkdir -p "$SANDBOX/agent/scripts"
cp "$SCRIPT" "$SANDBOX/agent/scripts/"

SLUG="f73-lifecycle-test"

# Step 1: save (creates draft)
echo "# Test plan body v1" | bash "$SANDBOX/agent/scripts/psk-plan-save.sh" save "$SLUG" - >/dev/null 2>&1
plan_file=$(ls "$SANDBOX/agent/plans/"*"$SLUG".md 2>/dev/null | head -1)
if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
  pass "F73: save creates plan file"
else
  fail "F73: save did not create plan file"
  unset PROJ_ROOT
  return 0 2>/dev/null || exit 1
fi

if grep -q '^status: draft$' "$plan_file"; then
  pass "F73: initial status is draft"
else
  fail "F73: initial status is not draft"
fi

# Step 2: approve (draft → approved)
bash "$SANDBOX/agent/scripts/psk-plan-save.sh" approve "$SLUG" >/dev/null 2>&1
if grep -q '^status: approved$' "$plan_file"; then
  pass "F73: approve transitions to approved"
else
  fail "F73: approve did not transition to approved"
fi

# Step 3: start (approved → executing)
bash "$SANDBOX/agent/scripts/psk-plan-save.sh" start "$SLUG" >/dev/null 2>&1
if grep -q '^status: executing$' "$plan_file"; then
  pass "F73: start transitions to executing"
else
  fail "F73: start did not transition to executing"
fi

# Step 4: done with sha-range (executing → done + commits field)
bash "$SANDBOX/agent/scripts/psk-plan-save.sh" done "$SLUG" "abc1234..def5678" >/dev/null 2>&1
if grep -q '^status: done$' "$plan_file"; then
  pass "F73: done transitions to done"
else
  fail "F73: done did not transition to done"
fi
if grep -q '^commits: abc1234..def5678$' "$plan_file"; then
  pass "F73: done records commits sha-range"
else
  fail "F73: done did not record commits sha-range"
fi

# Step 5: idempotency — re-save with new body must preserve status=done + commits.
# This is the QA-C11P001-PLANSAVE-IDEMPOTENCY-VIOLATION-02 regression check.
echo "# Test plan body v2 (revised)" | bash "$SANDBOX/agent/scripts/psk-plan-save.sh" save "$SLUG" - >/dev/null 2>&1
if grep -q '^status: done$' "$plan_file"; then
  pass "F73: re-save preserves status=done (idempotency)"
else
  fail "F73: re-save reset status — idempotency violated"
fi
if grep -q '^commits: abc1234..def5678$' "$plan_file"; then
  pass "F73: re-save preserves commits field (idempotency)"
else
  fail "F73: re-save erased commits field — idempotency violated"
fi
if grep -q '^# Test plan body v2 (revised)$' "$plan_file"; then
  pass "F73: re-save refreshes body content"
else
  fail "F73: re-save did not refresh body content"
fi

# Step 6: list (should show our plan with status)
list_out=$(bash "$SANDBOX/agent/scripts/psk-plan-save.sh" list 2>&1)
if echo "$list_out" | grep -q "$SLUG"; then
  pass "F73: list shows saved plan"
else
  fail "F73: list does not show saved plan"
fi
if echo "$list_out" | grep -q "done"; then
  pass "F73: list shows current status"
else
  fail "F73: list does not show current status"
fi

# Step 7: show (returns the file path)
show_out=$(bash "$SANDBOX/agent/scripts/psk-plan-save.sh" show "$SLUG" 2>&1)
if [ "$show_out" = "$plan_file" ]; then
  pass "F73: show returns plan file path"
else
  fail "F73: show did not return correct file path (got: $show_out)"
fi

# Step 8: abandon (any → abandoned, with reason)
bash "$SANDBOX/agent/scripts/psk-plan-save.sh" abandon "$SLUG" "test reason" >/dev/null 2>&1
if grep -q '^status: abandoned$' "$plan_file"; then
  pass "F73: abandon transitions to abandoned"
else
  fail "F73: abandon did not transition to abandoned"
fi

unset PROJ_ROOT
