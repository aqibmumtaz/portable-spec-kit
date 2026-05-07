#!/usr/bin/env bash
# tests/shared/reliability-checks.sh — assertions for the kit's
# reliability infrastructure: psk-sync-check, psk-doc-sync, psk-critic-spawn,
# psk-validate, the dual-gate pattern, and PreCommit hook.
#
# Phase T4.4 (Loop 4) — extracted from sections/03-reliability.sh §59-§60k.
#
# Sourced by features that exercise reliability layer:
#   features/f50-agent-self-compliance.sh   (psk-sync-check + dual-gate)
#   features/f70-reflex-avacr.sh            (gates / critic spawn)
#
# Idempotent — safe to source multiple times.

[ -n "${SHARED_RELIABILITY_LOADED:-}" ] && return 0
SHARED_RELIABILITY_LOADED=1

# Canonical reliability scripts produced by the kit installer.
RELIABILITY_SCRIPTS=(
  "psk-sync-check.sh"
  "psk-doc-sync.sh"
  "psk-critic-spawn.sh"
  "psk-validate.sh"
)

# assert_reliability_script <name>
# Asserts $PROJ/agent/scripts/<name> exists AND is executable.
assert_reliability_script() {
  local name="$1"
  local path="$PROJ/agent/scripts/$name"
  if [ ! -f "$path" ]; then
    fail "agent/scripts/$name MISSING"
    return
  fi
  if [ ! -x "$path" ]; then
    fail "agent/scripts/$name not executable"
    return
  fi
  pass "agent/scripts/$name exists and is executable"
}

# assert_all_reliability_scripts
# Convenience — assert all 4 canonical reliability scripts present.
assert_all_reliability_scripts() {
  for s in "${RELIABILITY_SCRIPTS[@]}"; do
    assert_reliability_script "$s"
  done
}

# assert_dual_gate_documented
# Asserts framework explains the dual bash+sub-agent critic pattern.
assert_dual_gate_documented() {
  if kit_grep "Bash Critic" -q && kit_grep "Sub-Agent Critic" -q; then
    pass "framework documents dual-gate (Bash + Sub-Agent critic) pattern"
  else
    fail "framework missing dual-gate critic documentation"
  fi
}

# assert_awaiting_critic_protocol
# Asserts framework explains the AWAITING_CRITIC handoff convention.
assert_awaiting_critic_protocol() {
  if kit_grep "AWAITING_CRITIC" -q; then
    pass "framework documents AWAITING_CRITIC handoff protocol"
  else
    fail "framework missing AWAITING_CRITIC protocol"
  fi
}

# assert_critic_iteration_cap
# Asserts framework documents the critic iteration cap (5 attempts).
assert_critic_iteration_cap() {
  if kit_grep "Iteration cap: 5" -q || kit_grep "iteration cap.*5" -q; then
    pass "framework documents critic iteration cap (5)"
  else
    fail "framework missing critic iteration cap documentation"
  fi
}

# assert_pre_commit_hook_present
# Asserts $PROJ/.git/hooks/pre-commit exists and references psk-sync-check.
# Skips gracefully if .git/ absent (e.g. shallow worktree).
assert_pre_commit_hook_present() {
  local hook="$PROJ/.git/hooks/pre-commit"
  if [ ! -d "$PROJ/.git" ]; then
    pass "pre-commit hook check skipped (no .git/)"
    return
  fi
  if [ ! -f "$hook" ]; then
    fail "pre-commit hook MISSING at .git/hooks/pre-commit"
    return
  fi
  if grep -q "psk-sync-check" "$hook"; then
    pass "pre-commit hook references psk-sync-check"
  else
    fail "pre-commit hook present but does not reference psk-sync-check"
  fi
}

# assert_emergency_bypass_documented
# Asserts framework documents the 3 emergency bypass envs/flags.
assert_emergency_bypass_documented() {
  local ok=0
  kit_grep "PSK_SYNC_CHECK_DISABLED" -q && ok=$((ok+1))
  kit_grep "PSK_CRITIC_DISABLED" -q && ok=$((ok+1))
  kit_grep -- "--no-verify" -q && ok=$((ok+1))
  if [ "$ok" -ge 2 ]; then
    pass "framework documents emergency bypass mechanisms ($ok/3 found)"
  else
    fail "framework missing emergency bypass documentation ($ok/3 found)"
  fi
}
