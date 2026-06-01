#!/bin/bash
# tests/sections/97-kit-fidelity.sh — §Kit Fidelity (8th reliability layer)
# regression coverage. Validates the wrapper script, canonical-command
# inventory, deviation/gap log files, PSK040 sync-check rule, framework rule
# placement, flow doc, and skill file all exist + work correctly.
#
# Independently runnable: bash tests/sections/97-kit-fidelity.sh
#
# Source: 2026-05-31 — Phase F of plan kit-fidelity-8th-layer.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "Kit Fidelity (8th reliability layer)"

WRAPPER="$PROJ/agent/scripts/psk-kit-cmd.sh"
INVENTORY="$PROJ/.portable-spec-kit/kit-commands.yml"
DEV_LOG="$PROJ/agent/.kit-deviation-log"
GAP_LOG="$PROJ/agent/.kit-gap-log"
SYNC_CHECK="$PROJ/agent/scripts/psk-sync-check.sh"
FRAMEWORK="$PROJ/portable-spec-kit.md"
FLOW_DOC="$PROJ/docs/work-flows/30-kit-fidelity.md"
SKILL_FILE="$PROJ/.portable-spec-kit/skills/kit-fidelity.md"

# --- 97.1: required files exist ---
[ -x "$WRAPPER" ] \
  && pass "97.1: psk-kit-cmd.sh exists and is executable" \
  || fail "97.1: psk-kit-cmd.sh missing or not executable"

[ -f "$INVENTORY" ] \
  && pass "97.1: kit-commands.yml inventory exists" \
  || fail "97.1: kit-commands.yml missing"

[ -f "$DEV_LOG" ] \
  && pass "97.1: .kit-deviation-log exists (committed)" \
  || fail "97.1: .kit-deviation-log missing"

[ -f "$GAP_LOG" ] \
  && pass "97.1: .kit-gap-log exists (committed)" \
  || fail "97.1: .kit-gap-log missing"

# --- 97.2: inventory schema sanity ---
grep -qE '^schema_version: 1$' "$INVENTORY" \
  && pass "97.2: inventory carries schema_version: 1" \
  || fail "97.2: inventory missing schema_version: 1"

grep -qE '^commands:$' "$INVENTORY" \
  && pass "97.2: inventory has commands: section" \
  || fail "97.2: inventory missing commands: section"

grep -qE '^marker_commit_patterns:$' "$INVENTORY" \
  && pass "97.2: inventory has marker_commit_patterns: section" \
  || fail "97.2: inventory missing marker_commit_patterns: section"

# --- 97.3: wrapper --help works + mentions rationale ---
help_out=$(bash "$WRAPPER" --help 2>&1)
echo "$help_out" | grep -q 'psk-kit-cmd.sh' \
  && pass "97.3: --help works and identifies the wrapper" \
  || fail "97.3: --help output missing wrapper name"

echo "$help_out" | grep -qE 'AWAITING_RATIONALE|--rationale' \
  && pass "97.3: --help mentions rationale mechanism" \
  || fail "97.3: --help missing rationale mechanism mention"

# --- 97.4: wrapper --list shows core inventory commands ---
list_out=$(bash "$WRAPPER" --list 2>&1)
for cmd in reflex prepare-release init orchestrate; do
  echo "$list_out" | grep -qE "^  $cmd$" \
    && pass "97.4: --list shows $cmd command" \
    || fail "97.4: --list missing $cmd command"
done

# --- 97.5: --check detects canonical vs non-canonical ---
check_can=$(bash "$WRAPPER" --check reflex 2>&1)
echo "$check_can" | grep -qi 'canonical' \
  && pass "97.5: --check reflex (no args) → canonical" \
  || fail "97.5: --check reflex should report canonical"

check_noncan=$(bash "$WRAPPER" --check reflex single 2>&1)
echo "$check_noncan" | grep -qi 'non-canonical' \
  && pass "97.5: --check reflex single → non-canonical" \
  || fail "97.5: --check reflex single should report non-canonical"

# Exit codes
bash "$WRAPPER" --check reflex >/dev/null 2>&1
rc=$?
[ "$rc" = "0" ] \
  && pass "97.5: --check canonical exits 0" \
  || fail "97.5: --check canonical exit code = $rc (expected 0)"

bash "$WRAPPER" --check reflex single >/dev/null 2>&1
rc=$?
[ "$rc" = "2" ] \
  && pass "97.5: --check non-canonical exits 2" \
  || fail "97.5: --check non-canonical exit code = $rc (expected 2)"

# --- 97.6: --log-gap writes to kit-gap-log + auto-increments id ---
GAP_BACKUP=$(mktemp)
cp "$GAP_LOG" "$GAP_BACKUP"

out1=$(bash "$WRAPPER" --log-gap "cmd-A-$$" "friction-A-$$" "fix-A-$$" 2>&1)
out2=$(bash "$WRAPPER" --log-gap "cmd-B-$$" "friction-B-$$" "fix-B-$$" 2>&1)

id1=$(echo "$out1" | grep -oE 'KIT-GAP-[0-9]+' | head -1 | sed 's/KIT-GAP-//')
id2=$(echo "$out2" | grep -oE 'KIT-GAP-[0-9]+' | head -1 | sed 's/KIT-GAP-//')

if [ -n "$id1" ] && [ -n "$id2" ] && [ "$((10#$id2))" = "$((10#$id1 + 1))" ]; then
  pass "97.6: --log-gap KIT-GAP id auto-increments ($id1 → $id2)"
else
  fail "97.6: --log-gap id did not auto-increment (got $id1 → $id2)"
fi

grep -q "friction-A-$$" "$GAP_LOG" \
  && pass "97.6: --log-gap appends to .kit-gap-log" \
  || fail "97.6: .kit-gap-log not updated after --log-gap"

# Restore log to keep tests idempotent
mv "$GAP_BACKUP" "$GAP_LOG"

# Clean up the .pending markers log_gap wrote for the test gaps so the test
# stays idempotent and does not leak markers into the working tree.
[ -n "$id1" ] && rm -f "$PROJ/agent/.workflow-state/pending-kit-gap/KIT-GAP-$(printf '%04d' "$((10#$id1))").pending"
[ -n "$id2" ] && rm -f "$PROJ/agent/.workflow-state/pending-kit-gap/KIT-GAP-$(printf '%04d' "$((10#$id2))").pending"

# --- 97.7: PSK040 sync-check function exists + registered ---
grep -q 'check_psk040_kit_fidelity_coverage()' "$SYNC_CHECK" \
  && pass "97.7: PSK040 check function defined in psk-sync-check.sh" \
  || fail "97.7: PSK040 check function missing"

# Should be registered in both quick and full mode (2 references — function def + 2 calls = 3 total)
psk040_refs=$(grep -c 'check_psk040_kit_fidelity_coverage' "$SYNC_CHECK")
[ "$psk040_refs" -ge "3" ] \
  && pass "97.7: PSK040 registered in dispatch ($psk040_refs references)" \
  || fail "97.7: PSK040 missing dispatch registration (only $psk040_refs refs, expected ≥3)"

# --- 97.8: PSK040 runs and reports clean OR skip on current tree ---
psk040_out=$(bash "$SYNC_CHECK" --full 2>&1 | grep PSK040 | head -2)
echo "$psk040_out" | grep -qE 'PSK040.*(clean|skip)' \
  && pass "97.8: PSK040 reports clean OR skip on current tree" \
  || fail "97.8: PSK040 unexpected output: $psk040_out"

# --- 97.9: emergency bypass env var is honored ---
bypass_out=$(PSK_KIT_FIDELITY_DISABLED=1 bash "$WRAPPER" --check reflex single 2>&1)
echo "$bypass_out" | grep -qi 'bypassed' \
  && pass "97.9: PSK_KIT_FIDELITY_DISABLED=1 produces bypass warning" \
  || fail "97.9: bypass env var not honored"

# --- 97.10: framework rule §Kit Fidelity is present ---
grep -qE '^## Kit Fidelity ' "$FRAMEWORK" \
  && pass "97.10: §Kit Fidelity section exists in portable-spec-kit.md" \
  || fail "97.10: §Kit Fidelity section missing"

grep -q '8th reliability layer' "$FRAMEWORK" \
  && pass "97.10: framework identifies §Kit Fidelity as 8th reliability layer" \
  || fail "97.10: framework missing 8th-reliability-layer claim"

grep -q 'eight enforcement layers' "$FRAMEWORK" \
  && pass "97.10: §Reliability Architecture overview updated to eight layers" \
  || fail "97.10: §Reliability Architecture overview not updated"

# --- 97.11: flow doc 30 + skill file exist ---
[ -f "$FLOW_DOC" ] \
  && pass "97.11: flow doc 30-kit-fidelity.md exists" \
  || fail "97.11: flow doc 30-kit-fidelity.md missing"

[ -f "$SKILL_FILE" ] \
  && pass "97.11: skill file kit-fidelity.md exists" \
  || fail "97.11: skill file missing"

# --- 97.12: flow doc has required sections ---
grep -q '^## Overview' "$FLOW_DOC" \
  && pass "97.12: flow doc has ## Overview" \
  || fail "97.12: flow doc missing ## Overview"

grep -q '^## Flow Diagram' "$FLOW_DOC" \
  && pass "97.12: flow doc has ## Flow Diagram" \
  || fail "97.12: flow doc missing ## Flow Diagram"

grep -q '^## Key Rules' "$FLOW_DOC" \
  && pass "97.12: flow doc has ## Key Rules" \
  || fail "97.12: flow doc missing ## Key Rules"

# --- 97.13: ADR-089 recorded in PLANS.md ---
grep -q 'ADR-089' "$PROJ/agent/PLANS.md" \
  && pass "97.13: ADR-089 (§Kit Fidelity 8th layer) recorded in PLANS.md" \
  || fail "97.13: ADR-089 missing from PLANS.md"
