#!/bin/bash
# tests/sections/95-prompt-fidelity.sh — §Sub-Agent Prompt Fidelity (9th reliability layer)
# regression coverage (KIT-GAP-0055, v0.6.74).
#
# Independently runnable: bash tests/sections/95-prompt-fidelity.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "Section 95 — Sub-Agent Prompt Fidelity (9th reliability layer)"

_S95_RULES="$PROJ/.portable-spec-kit/kit-rules.yml"
_S95_RULE_SH="$PROJ/agent/scripts/psk-rule.sh"
_S95_LINT_SH="$PROJ/agent/scripts/psk-prompt-lint.sh"
_S95_SPAWN_SH="$PROJ/agent/scripts/psk-spawn.sh"
_S95_SYNC_SH="$PROJ/agent/scripts/psk-sync-check.sh"
_S95_FRAMEWORK="$PROJ/portable-spec-kit.md"
_S95_FLOW_DOC="$PROJ/docs/work-flows/31-sub-agent-prompt-fidelity.md"
_S95_TMP=$(mktemp -d)

# --- 95.1: artifacts exist ---
[ -f "$_S95_RULES" ] \
  && pass "95.1: .portable-spec-kit/kit-rules.yml manifest exists" \
  || fail "95.1: kit-rules.yml missing"

[ -x "$_S95_RULE_SH" ] \
  && pass "95.1: psk-rule.sh lookup helper exists + executable" \
  || fail "95.1: psk-rule.sh missing or not executable"

[ -x "$_S95_LINT_SH" ] \
  && pass "95.1: psk-prompt-lint.sh exists + executable" \
  || fail "95.1: psk-prompt-lint.sh missing"

# --- 95.2: kit-rules.yml schema validation ---
grep -qE '^schema_version: 1$' "$_S95_RULES" \
  && pass "95.2: kit-rules.yml carries schema_version: 1" \
  || fail "95.2: kit-rules.yml missing schema_version"

grep -qE '^rules:$' "$_S95_RULES" \
  && pass "95.2: kit-rules.yml has rules: array" \
  || fail "95.2: kit-rules.yml missing rules: array"

# --- 95.3: psk-rule.sh lookup happy path ---
_S95_LOOKUP=$(bash "$_S95_RULE_SH" lookup verdict-source-of-truth 2>&1)
if echo "$_S95_LOOKUP" | grep -q 'Verdicts come from gates.sh'; then
  pass "95.3: psk-rule.sh lookup returns verbatim rule text"
else
  fail "95.3: psk-rule.sh lookup output unexpected: $_S95_LOOKUP"
fi

# --- 95.4: psk-rule.sh list ---
_S95_LIST=$(bash "$_S95_RULE_SH" list 2>&1)
_S95_LIST_COUNT=$(echo "$_S95_LIST" | wc -l | tr -d ' ')
if [ "$_S95_LIST_COUNT" -ge "10" ]; then
  pass "95.4: psk-rule.sh list returns ${_S95_LIST_COUNT} rules (≥10)"
else
  fail "95.4: psk-rule.sh list returned only ${_S95_LIST_COUNT} rules"
fi

# --- 95.5: psk-rule.sh applies-to ---
_S95_APPLIES=$(bash "$_S95_RULE_SH" applies-to verdict 2>&1)
if echo "$_S95_APPLIES" | grep -q 'single-author-fallback-verdict'; then
  pass "95.5: psk-rule.sh applies-to filters by decision class"
else
  fail "95.5: applies-to verdict did not return expected rule"
fi

# --- 95.6: psk-prompt-lint.sh catches missing citations ---
cat > "$_S95_TMP/bad-prompt.md" <<'PROMPT_BAD'
# Test prompt that references kit rules
This prompt mentions verdict, GRANTED, and Bucket A but has no frontmatter citations.
PROMPT_BAD
_S95_BAD=$(bash "$_S95_LINT_SH" "$_S95_TMP/bad-prompt.md" --strict 2>&1)
_S95_BAD_RC=$?
if [ "$_S95_BAD_RC" -ne 0 ] && echo "$_S95_BAD" | grep -q 'missing kit_rule_citations'; then
  pass "95.6: prompt-lint --strict refuses prompt without kit_rule_citations"
else
  fail "95.6: prompt-lint should have refused bad prompt (rc=$_S95_BAD_RC)"
fi

# --- 95.7: psk-prompt-lint.sh accepts good prompt ---
cat > "$_S95_TMP/good-prompt.md" <<'PROMPT_GOOD'
---
kit_rule_citations:
  - verdict-source-of-truth
---

# Test prompt with proper citation

The kit rule:
Verdicts come from gates.sh + write_verdict() in run.sh, NOT from sub-agent
self-declaration. Sub-agents emit EVIDENCE (findings); kit emits DECISIONS
(verdict). Any verdict field a sub-agent writes in qa-result.md is ignored.

Mentions Bucket A and GRANTED for heuristic test.
PROMPT_GOOD
_S95_GOOD=$(bash "$_S95_LINT_SH" "$_S95_TMP/good-prompt.md" --strict 2>&1)
_S95_GOOD_RC=$?
if [ "$_S95_GOOD_RC" -eq 0 ]; then
  pass "95.7: prompt-lint --strict accepts prompt with verbatim citation"
else
  fail "95.7: prompt-lint refused good prompt (rc=$_S95_GOOD_RC): $_S95_GOOD"
fi

# --- 95.8: psk-prompt-lint.sh --all discovers prompts ---
_S95_ALL=$(bash "$_S95_LINT_SH" --all 2>&1)
if echo "$_S95_ALL" | grep -qE 'prompt\(s\)'; then
  pass "95.8: prompt-lint --all discovers + checks prompts"
else
  fail "95.8: prompt-lint --all did not produce expected output (got: $(echo "$_S95_ALL" | tail -1))"
fi

# --- 95.9: psk-spawn.sh request refuses bad prompt ---
echo "Test prompt mentions verdict and GRANTED" > "$_S95_TMP/spawn-bad.md"
_S95_SPAWN_BAD=$(bash "$_S95_SPAWN_SH" request test-pf-$$ test-phase "$_S95_TMP/spawn-bad.md" "$_S95_TMP/result.md" 2>&1)
_S95_SPAWN_RC=$?
if [ "$_S95_SPAWN_RC" -eq 4 ] && echo "$_S95_SPAWN_BAD" | grep -q 'SPAWN REFUSED'; then
  pass "95.9: psk-spawn.sh refuses bad prompt with exit 4"
else
  fail "95.9: psk-spawn.sh should have refused bad prompt (rc=$_S95_SPAWN_RC)"
fi

# --- 95.10: psk-spawn.sh request accepts good prompt ---
_S95_SPAWN_GOOD=$(bash "$_S95_SPAWN_SH" request test-pf-good-$$ test-phase "$_S95_TMP/good-prompt.md" "$_S95_TMP/result-good.md" 2>&1)
_S95_SPAWN_GOOD_RC=$?
if [ "$_S95_SPAWN_GOOD_RC" -eq 0 ] && echo "$_S95_SPAWN_GOOD" | grep -q 'AWAITING_SUBAGENT'; then
  pass "95.10: psk-spawn.sh accepts good prompt + signals AWAITING"
else
  fail "95.10: psk-spawn.sh should accept good prompt (rc=$_S95_SPAWN_GOOD_RC)"
fi

# --- 95.11: PSK042 sync-check rule registered ---
grep -q 'check_psk042_prompt_fidelity()' "$_S95_SYNC_SH" \
  && pass "95.11: PSK042 check function defined in psk-sync-check.sh" \
  || fail "95.11: PSK042 check function missing"

# QA-PERF-KIT-SYNCCHECK-QUICK-01 (cycle-29-pass-003): PSK042 prompt-fidelity
# linting (discovers + lints every sub-agent prompt) is too heavy for the
# per-edit --quick PostToolUse hook (<500ms budget). It now runs in --full only
# (pre-commit hook + release gate). Dispatch ref count is 2 (def + --full call).
psk042_refs=$(grep -c 'check_psk042_prompt_fidelity' "$_S95_SYNC_SH")
[ "$psk042_refs" -ge "2" ] \
  && pass "95.11: PSK042 registered in --full dispatch ($psk042_refs references)" \
  || fail "95.11: PSK042 dispatch registration incomplete ($psk042_refs refs, expected ≥2: def + --full call)"

# --- 95.12: §Sub-Agent Prompt Fidelity rule in framework ---
grep -q '^## Sub-Agent Prompt Fidelity' "$_S95_FRAMEWORK" \
  && pass "95.12: §Sub-Agent Prompt Fidelity section exists in portable-spec-kit.md" \
  || fail "95.12: framework section missing"

grep -q '9th reliability layer' "$_S95_FRAMEWORK" \
  && pass "95.12: framework identifies §Sub-Agent Prompt Fidelity as 9th layer" \
  || fail "95.12: framework missing 9th-layer claim"

# §Sub-Agent Prompt Fidelity stays the 9th layer; the overview total grows as new
# layers land (v0.6.78 ten, v0.6.79 eleven).
grep -qE '(nine|ten|eleven|twelve) enforcement layers' "$_S95_FRAMEWORK" \
  && pass "95.12: §Reliability Architecture overview declares current layer count (≥9)" \
  || fail "95.12: §Reliability Architecture overview not updated"

# --- 95.13: flow doc 31 exists with required sections ---
[ -f "$_S95_FLOW_DOC" ] \
  && pass "95.13: flow doc 31 exists" \
  || fail "95.13: flow doc 31 missing"

grep -q '^## Overview' "$_S95_FLOW_DOC" \
  && pass "95.13: flow doc 31 has ## Overview" \
  || fail "95.13: flow doc 31 missing ## Overview"

grep -q '^## Flow Diagram' "$_S95_FLOW_DOC" \
  && pass "95.13: flow doc 31 has ## Flow Diagram" \
  || fail "95.13: flow doc 31 missing ## Flow Diagram"

grep -q '^## Key Rules' "$_S95_FLOW_DOC" \
  && pass "95.13: flow doc 31 has ## Key Rules" \
  || fail "95.13: flow doc 31 missing ## Key Rules"

# --- 95.14: bypass env var honored ---
_S95_BYPASS=$(PSK_PROMPT_FIDELITY_DISABLED=1 bash "$_S95_SPAWN_SH" request test-pf-bypass-$$ test-phase "$_S95_TMP/spawn-bad.md" "$_S95_TMP/result-bypass.md" 2>&1)
_S95_BYPASS_RC=$?
if [ "$_S95_BYPASS_RC" -eq 0 ] && echo "$_S95_BYPASS" | grep -q 'AWAITING_SUBAGENT'; then
  pass "95.14: PSK_PROMPT_FIDELITY_DISABLED=1 bypasses the gate"
else
  fail "95.14: bypass env var not honored (rc=$_S95_BYPASS_RC)"
fi

# Cleanup
rm -f "$PROJ/agent/.workflow-state/spawn/test-pf-"*$$*.request 2>/dev/null
rm -rf "$_S95_TMP"

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  RESULTS (95-prompt-fidelity): $PASS passed, $FAIL failed, $TOTAL total"
  echo "═══════════════════════════════════════════"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi
