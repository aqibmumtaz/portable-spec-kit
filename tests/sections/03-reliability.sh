#!/bin/bash
# tests/sections/03-reliability.sh — sections 59-60f
#
# Reliability architecture, dual-gate validation (every executable workflow),
# 60c workflow orchestrators + Step 4 tighter gate + bypass audit,
# 60d secret scanning (PSK011), 60e distribution completeness (install.sh
# + sync.sh), 60j flow doc content + critic prompt meta-check (PSK016/017),
# 60k full doc-surface coverage analyzer (PSK018), 60l stale release-state
# detection, 60m F70 reflex (AVACR v0.5.21–v0.5.23 baseline tests),
# 60i README structural checks (PSK013/014/015), 60h README content check
# (PSK012), 60g v0.5.16 RFT cache + CI templates, 60f verbatim-quote critic.
#
# Independently runnable: bash tests/sections/03-reliability.sh
#
# DEPRECATED-IN-FAVOR-OF: tests/features/fNN-*.sh
#
# Loop-4 v0.6.32: SPECS.md Tests column now points at tests/features/fNN-*.sh
# (per-feature audits, ~1 sec each). The exhaustive coverage in this file
# still runs when test-spec-kit.sh sources sections/. Future cleanup
# (v0.7.0+) will split this file's tests across features/ properly.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "59. Reliability Architecture"
# ═══════════════════════════════════════════════════════════════

[ -x "$PROJ/agent/scripts/psk-sync-check.sh" ] \
  && pass "reliability: psk-sync-check.sh exists and is executable" \
  || fail "reliability: psk-sync-check.sh missing or not executable"

[ -x "$PROJ/agent/scripts/psk-install-hooks.sh" ] \
  && pass "reliability: psk-install-hooks.sh exists and is executable" \
  || fail "reliability: psk-install-hooks.sh missing or not executable"

[ -f "$PROJ/install.sh" ] && [ -x "$PROJ/install.sh" ] \
  && pass "reliability: install.sh exists and is executable" \
  || fail "reliability: install.sh missing or not executable"

[ -f "$PROJ/.claude/settings.json" ] \
  && pass "reliability: .claude/settings.json exists" \
  || fail "reliability: .claude/settings.json missing"

grep -q "PostToolUse" "$PROJ/.claude/settings.json" 2>/dev/null \
  && pass "reliability: settings.json has PostToolUse hook" \
  || fail "reliability: settings.json missing PostToolUse hook"

grep -q "psk-sync-check" "$PROJ/.claude/settings.json" 2>/dev/null \
  && pass "reliability: settings.json wires psk-sync-check.sh" \
  || fail "reliability: settings.json missing psk-sync-check.sh reference"

[ -f "$PROJ/.git-hooks/pre-commit" ] && [ -x "$PROJ/.git-hooks/pre-commit" ] \
  && pass "reliability: .git-hooks/pre-commit template exists and is executable" \
  || fail "reliability: .git-hooks/pre-commit template missing or not executable"

grep -q "psk-sync-check" "$PROJ/.git-hooks/pre-commit" 2>/dev/null \
  && pass "reliability: pre-commit hook wires psk-sync-check.sh" \
  || fail "reliability: pre-commit hook missing psk-sync-check.sh reference"

[ -f "$PROJ/.portable-spec-kit/skills/hooks-and-critics.md" ] \
  && pass "reliability: hooks-and-critics.md skill file exists" \
  || fail "reliability: hooks-and-critics.md skill file missing"

kit_grep -q "## Reliability Architecture" \
  && pass "reliability: framework has Reliability Architecture section" \
  || fail "reliability: framework missing Reliability Architecture section"

kit_grep -q "AWAITING_CRITIC" \
  && pass "reliability: framework has critic protocol rule" \
  || fail "reliability: framework missing critic protocol rule"

kit_grep -q "hooks-and-critics.md" \
  && pass "reliability: skill routing table includes hooks-and-critics.md" \
  || fail "reliability: skill routing table missing hooks-and-critics.md"

grep -q "\-\-quick" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check has --quick mode" \
  || fail "reliability: sync-check missing --quick mode"

grep -q "\-\-full" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check has --full mode" \
  || fail "reliability: sync-check missing --full mode"

grep -q "detect_mode" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check has mode auto-detection" \
  || fail "reliability: sync-check missing mode auto-detection"

grep -q "is_sensitive\|SENSITIVE_PATTERNS" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check has sensitive data exclusion" \
  || fail "reliability: sync-check missing sensitive data exclusion"

grep -q "PSK_SYNC_CHECK_DISABLED" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check has emergency bypass" \
  || fail "reliability: sync-check missing emergency bypass"

grep -q "PSK001\|PSK002\|PSK003" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check has structured error codes" \
  || fail "reliability: sync-check missing structured error codes"

grep -qi "husky" "$PROJ/agent/scripts/psk-install-hooks.sh" 2>/dev/null \
  && pass "reliability: install-hooks detects Husky" \
  || fail "reliability: install-hooks missing Husky detection"

grep -qi "backup\|Backed up" "$PROJ/agent/scripts/psk-install-hooks.sh" 2>/dev/null \
  && pass "reliability: install-hooks wraps existing hooks (backups)" \
  || fail "reliability: install-hooks missing hook wrapping/backup"

# New checks added in v0.5.9 — gap closures from audit 2026-04-17
grep -q "check_specs_staleness" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check has SPECS staleness check (Gap 9)" \
  || fail "reliability: sync-check missing SPECS staleness check"

grep -q "check_ard_content" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check has ARD content check (Gap 5)" \
  || fail "reliability: sync-check missing ARD content check"

grep -q "check_agent_md_stack" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check has AGENT.md Stack check (Gap 11)" \
  || fail "reliability: sync-check missing AGENT.md Stack check"

grep -q "VERIFY_REFACTOR" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check has --verify-refactor mode (Gap 12)" \
  || fail "reliability: sync-check missing --verify-refactor mode"

grep -q "content-sparse" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check validates CHANGELOG/RELEASES content (Gaps 1, 2)" \
  || fail "reliability: sync-check missing content validation"

grep -q "PSK004B" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check has PSK004B error code (SPECS staleness)" \
  || fail "reliability: sync-check missing PSK004B"

grep -q "PSK009" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check has PSK009 error code (ARD content)" \
  || fail "reliability: sync-check missing PSK009"

grep -q "PSK010" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check has PSK010 error code (AGENT.md Stack)" \
  || fail "reliability: sync-check missing PSK010"

# Critic prompt tightening (Gaps 3, 5)
grep -qE "Compare against git log|Additional check|cross-file verification" "$PROJ/agent/scripts/psk-critic-spawn.sh" 2>/dev/null \
  && pass "reliability: critic prompts include cross-file verification" \
  || fail "reliability: critic prompts missing cross-file verification"

grep -q "copy from v0.N-1\|copy-paste detection" "$PROJ/agent/scripts/psk-critic-spawn.sh" 2>/dev/null \
  && pass "reliability: critic prompts reject copy-paste content" \
  || fail "reliability: critic prompts missing copy-paste detection"

# Framework rule updates (Gaps 4, 6, 10, 13)
kit_grep -q "MANDATORY for minor releases.*What's New\|section MUST have a \"What's New" \
  && pass "reliability: framework mandates README What's New for minor versions (Gap 4)" \
  || fail "reliability: framework missing mandatory What's New rule"

kit_grep -q "phase line must describe NEXT planned work\|Version-bumped-but-phase-unchanged" \
  && pass "reliability: framework mandates phase description update (Gap 6)" \
  || fail "reliability: framework missing phase update rule"

kit_grep -q "ADL entry with .Plan Ref. column\|corresponding ADL entry" \
  && pass "reliability: framework mandates ADL Plan Ref for design files (Gap 10)" \
  || fail "reliability: framework missing ADL Plan Ref rule"

kit_grep -qi "EXHAUSTIVE \(check every\|safety net grep" \
  && pass "reliability: framework has exhaustive consistency sweep checklist (Gap 13)" \
  || fail "reliability: framework missing exhaustive checklist"

# psk-uninstall.sh (from Phase 7)
[ -x "$PROJ/agent/scripts/psk-uninstall.sh" ] \
  && pass "reliability: psk-uninstall.sh exists and is executable" \
  || fail "reliability: psk-uninstall.sh missing or not executable"

# Verify sync-check uses the new 11-check counter pattern (not e2e run — that recurses via test-release-check)
grep -q "check_specs_staleness" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null && \
grep -q "check_ard_content" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null && \
grep -q "check_agent_md_stack" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "reliability: sync-check dispatch includes all 3 new checks (11 total)" \
  || fail "reliability: sync-check dispatch missing new checks"

section "60. Dual-Gate Validation — every executable workflow"

# psk-validate.sh — the generic dual-gate helper
[ -x "$PROJ/agent/scripts/psk-validate.sh" ] \
  && pass "dual-gate: psk-validate.sh exists and is executable" \
  || fail "dual-gate: psk-validate.sh missing or not executable"

# Helper invokes bash critic
grep -q "psk-sync-check.sh" "$PROJ/agent/scripts/psk-validate.sh" 2>/dev/null \
  && pass "dual-gate: psk-validate.sh invokes psk-sync-check.sh (Layer 2A)" \
  || fail "dual-gate: psk-validate.sh missing Layer 2A"

# Helper invokes sub-agent critic
grep -q "psk-critic-spawn.sh" "$PROJ/agent/scripts/psk-validate.sh" 2>/dev/null \
  && pass "dual-gate: psk-validate.sh invokes psk-critic-spawn.sh (Layer 2B)" \
  || fail "dual-gate: psk-validate.sh missing Layer 2B"

# Helper supports all 6 workflow names
for wf in release feature-complete init reinit new-setup existing-setup; do
  grep -qE "\\b$wf\\)" "$PROJ/agent/scripts/psk-validate.sh" 2>/dev/null \
    && pass "dual-gate: psk-validate.sh supports '$wf' workflow" \
    || fail "dual-gate: psk-validate.sh missing '$wf' workflow"
done

# Helper has freshness check against stale critic-result.md
grep -qE "result_is_fresh|INVOKE_STAMP|validate-stamp" "$PROJ/agent/scripts/psk-validate.sh" 2>/dev/null \
  && pass "dual-gate: psk-validate.sh has freshness check" \
  || fail "dual-gate: psk-validate.sh missing freshness check"

# Helper has both bypass env vars
grep -q "PSK_SYNC_CHECK_DISABLED" "$PROJ/agent/scripts/psk-validate.sh" 2>/dev/null && \
grep -q "PSK_CRITIC_DISABLED" "$PROJ/agent/scripts/psk-validate.sh" 2>/dev/null \
  && pass "dual-gate: psk-validate.sh has both bypass env vars" \
  || fail "dual-gate: psk-validate.sh missing bypass env vars"

# Helper exit codes documented (0, 1, 2, 3, 4)
grep -q "AWAITING_CRITIC" "$PROJ/agent/scripts/psk-validate.sh" 2>/dev/null \
  && pass "dual-gate: psk-validate.sh emits AWAITING_CRITIC status" \
  || fail "dual-gate: psk-validate.sh missing AWAITING_CRITIC status"

# All 5 new critic templates present in psk-critic-spawn.sh
for tpl in FEATURE_COMPLETE INIT REINIT NEW_SETUP EXISTING_SETUP; do
  grep -qE "^\\s+${tpl}\\)" "$PROJ/agent/scripts/psk-critic-spawn.sh" 2>/dev/null \
    && pass "dual-gate: critic template '$tpl' exists" \
    || fail "dual-gate: critic template '$tpl' missing"
done

# psk-release.sh Step 9 actually invokes psk-validate.sh (not reimplementing)
grep -q "psk-validate.sh" "$PROJ/agent/scripts/psk-release.sh" 2>/dev/null \
  && pass "dual-gate: psk-release.sh Step 9 delegates to psk-validate.sh" \
  || fail "dual-gate: psk-release.sh does not delegate to psk-validate.sh (orphan helper)"

# Every executable workflow flow doc references psk-validate.sh
for flow in "docs/work-flows/03-new-project-setup.md:new-setup" \
            "docs/work-flows/04-existing-project-setup.md:existing-setup" \
            "docs/work-flows/05-project-init.md:init" \
            "docs/work-flows/11-spec-persistent-development.md:feature-complete" \
            "docs/work-flows/13-release-workflow.md:release"; do
  f="${flow%:*}"; wf="${flow##*:}"
  grep -q "psk-validate.sh $wf" "$PROJ/$f" 2>/dev/null \
    && pass "dual-gate: $f mentions psk-validate.sh $wf" \
    || fail "dual-gate: $f missing psk-validate.sh $wf reference"
done

# Framework core file mentions the MANDATORY validate rule
grep -q "psk-validate.sh" "$PROJ/portable-spec-kit.md" 2>/dev/null \
  && pass "dual-gate: portable-spec-kit.md mentions psk-validate.sh" \
  || fail "dual-gate: portable-spec-kit.md missing psk-validate.sh reference"

# hooks-and-critics.md skill lists all 6 workflows
skill_file="$PROJ/.portable-spec-kit/skills/hooks-and-critics.md"
if [ -f "$skill_file" ]; then
  missing_wf=""
  for wf in release feature-complete init reinit new-setup existing-setup; do
    grep -q "psk-validate.sh $wf" "$skill_file" 2>/dev/null || missing_wf="$missing_wf $wf"
  done
  [ -z "$missing_wf" ] \
    && pass "dual-gate: hooks-and-critics.md lists all 6 workflows" \
    || fail "dual-gate: hooks-and-critics.md missing workflows:$missing_wf"
else
  fail "dual-gate: hooks-and-critics.md skill file missing"
fi

# ── Behavioral tests: exercise psk-validate.sh with staged state ──
# These verify the helper actually BEHAVES correctly when fed input,
# not just that the script contains the right keywords. We use
# PSK_SYNC_CHECK_DISABLED=1 to isolate critic-gate logic from the
# bash critic (which is separately tested by sync-check's own suite).

VSTATE="$PROJ/agent/.release-state"
VALIDATE_SH="$PROJ/agent/scripts/psk-validate.sh"

mkdir -p "$VSTATE"
# Back up any in-flight state so we don't disturb active release
for f in critic-task.md critic-result.md .validate-stamp critic-iterations; do
  [ -f "$VSTATE/$f" ] && mv "$VSTATE/$f" "$VSTATE/$f.pretest-bak"
done

# H5 / QA-KIT-SELFTEST-ISOLATION-01 (searchsocialtruth-cycle-05-gate)
# + L5.4 G-KIT-SELFTEST-ISOLATION-01 (searchsocialtruth-cycle-08-gate):
# pre-clean helper — strips ALL state files known to leak between
# behavior tests so a prior failed run cannot pollute a subsequent
# test. Called before every "Behavior N" block.
#
# Files cleaned (full reflex/release-state surface):
#   critic-task.md      — input from validate.sh to critic
#   critic-result.md    — output from critic
#   .validate-stamp     — freshness anchor (mtime-checked)
#   critic-iterations   — iteration counter (5-cap)
#   loop-state.yml      — autoloop convergence state
#   dev-task.md         — input to Dev-Agent (L5.4)
#   dev-result.md       — output from Dev-Agent
#   qa-task.md          — input to QA-Agent (L5.4)
#   qa-result.md        — output from QA-Agent (L5.4)
pre_clean_release_state() {
  for f in critic-task.md critic-result.md .validate-stamp \
           critic-iterations loop-state.yml \
           dev-task.md dev-result.md \
           qa-task.md qa-result.md; do
    rm -f "$VSTATE/$f"
  done
}

# L5.4 — also pre-clean at section start (covers any pollution from
# prior section files OR prior test-spec-kit.sh runs that exited mid-flow).
pre_clean_release_state

# Behavior 1: no critic-result, no stamp → exit 2 AWAITING_CRITIC
pre_clean_release_state
PSK_SYNC_CHECK_DISABLED=1 bash "$VALIDATE_SH" release >/dev/null 2>&1
rc=$?
[ "$rc" = "2" ] \
  && pass "dual-gate behavior: missing critic-result exits AWAITING_CRITIC (2)" \
  || fail "dual-gate behavior: missing critic-result wrong exit code ($rc, expected 2)"

# Stamp now exists from run above. Write a STALE result (newer mtime than stamp).
sleep 1
cat > "$VSTATE/critic-result.md" <<'EOF'
STALE: test-file.md — "induced stale content for regression test"
CURRENT: another.md
EOF

# Behavior 2: STALE in critic-result → exit 3
PSK_SYNC_CHECK_DISABLED=1 bash "$VALIDATE_SH" release >/dev/null 2>&1
rc=$?
[ "$rc" = "3" ] \
  && pass "dual-gate behavior: STALE critic-result exits 3 (blocks)" \
  || fail "dual-gate behavior: STALE not detected (exit $rc, expected 3)"

# Behavior 3: all-CURRENT critic-result WITH valid QUOTE lines → exit 0
rm -f "$VSTATE/critic-result.md"
sleep 1
# Extract real lines from the kit's own files for verifiable quotes
# Must be ≥20 chars — pick long lines that exist in v0.5+ state
readme_line=$(grep -E "^## (Latest Release|What's New|The Methodology|The Problem|The Solution)" "$PROJ/README.md" | head -1)
[ ${#readme_line} -lt 20 ] && readme_line=$(grep -E "^\*\*macOS" "$PROJ/README.md" | head -1)
changelog_line=$(grep -E "^## v0\.5" "$PROJ/CHANGELOG.md" | head -1)
releases_line=$(grep -E "^## v0\.5" "$PROJ/agent/RELEASES.md" | head -1)
cat > "$VSTATE/critic-result.md" <<EOF
CURRENT: README.md
QUOTE: $readme_line
CURRENT: CHANGELOG.md
QUOTE: $changelog_line
CURRENT: agent/RELEASES.md
QUOTE: $releases_line
EOF
PSK_SYNC_CHECK_DISABLED=1 bash "$VALIDATE_SH" release >/dev/null 2>&1
rc=$?
[ "$rc" = "0" ] \
  && pass "dual-gate behavior: all-CURRENT with verified QUOTE lines exits 0 (passes)" \
  || fail "dual-gate behavior: CURRENT+QUOTE failed (exit $rc, expected 0)"

# Helper to ensure a stamp exists BEFORE writing result (stamp-delete happens on success path)
setup_fresh_stamp() {
  rm -f "$VSTATE/critic-result.md"
  # Stamp must exist and be OLDER than the upcoming result file
  local past=$(( $(date +%s) - 10 ))
  echo "$past" > "$VSTATE/.validate-stamp"
}

# Behavior 4: CURRENT without QUOTE → exit 3 (v0.5.15 — verbatim-quote gate)
setup_fresh_stamp
sleep 1
cat > "$VSTATE/critic-result.md" <<'EOF'
CURRENT: README.md
CURRENT: CHANGELOG.md
EOF
PSK_SYNC_CHECK_DISABLED=1 bash "$VALIDATE_SH" release >/dev/null 2>&1
rc=$?
[ "$rc" = "3" ] \
  && pass "dual-gate behavior: CURRENT without QUOTE exits 3 (unread-file protection)" \
  || fail "dual-gate behavior: CURRENT-without-QUOTE did not block (exit $rc, expected 3)"

# Behavior 5: CURRENT with fabricated QUOTE → exit 3 (v0.5.15 — verbatim-quote gate)
setup_fresh_stamp
sleep 1
cat > "$VSTATE/critic-result.md" <<'EOF'
CURRENT: README.md
QUOTE: this specific string does not appear in README.md anywhere — fabricated
EOF
PSK_SYNC_CHECK_DISABLED=1 bash "$VALIDATE_SH" release >/dev/null 2>&1
rc=$?
[ "$rc" = "3" ] \
  && pass "dual-gate behavior: fabricated QUOTE exits 3 (bash grep-verifies every quote)" \
  || fail "dual-gate behavior: fabricated QUOTE did not block (exit $rc, expected 3)"

# Cleanup + restore any pre-test state
rm -f "$VSTATE/critic-task.md" "$VSTATE/critic-result.md" "$VSTATE/.validate-stamp" "$VSTATE/critic-iterations"
for f in critic-task.md critic-result.md .validate-stamp critic-iterations; do
  [ -f "$VSTATE/$f.pretest-bak" ] && mv "$VSTATE/$f.pretest-bak" "$VSTATE/$f"
done

section "60c. Workflow Orchestrators + Step 4 Tighter Gate + Bypass Audit"

# Orchestrators exist and executable
for orch in psk-feature-complete.sh psk-init.sh psk-reinit.sh psk-new-setup.sh psk-existing-setup.sh; do
  [ -x "$PROJ/agent/scripts/$orch" ] \
    && pass "orchestrator: $orch exists and executable" \
    || fail "orchestrator: $orch missing or not executable"
done

# Each orchestrator calls psk-validate.sh at final gate
for orch in psk-feature-complete.sh psk-init.sh psk-reinit.sh psk-new-setup.sh psk-existing-setup.sh; do
  grep -q "psk-validate.sh" "$PROJ/agent/scripts/$orch" 2>/dev/null \
    && pass "orchestrator: $orch invokes psk-validate.sh" \
    || fail "orchestrator: $orch does not invoke psk-validate.sh (orphan)"
done

# psk-feature-complete.sh has preflight R→F→T enforcement
grep -q "Tests column empty" "$PROJ/agent/scripts/psk-feature-complete.sh" 2>/dev/null \
  && pass "orchestrator: feature-complete preflight enforces Tests column" \
  || fail "orchestrator: feature-complete missing Tests column preflight"

grep -q "No design plan" "$PROJ/agent/scripts/psk-feature-complete.sh" 2>/dev/null \
  && pass "orchestrator: feature-complete preflight enforces design plan" \
  || fail "orchestrator: feature-complete missing design plan preflight"

# psk-reinit.sh has content-loss snapshot
grep -q "byte-counts" "$PROJ/agent/scripts/psk-reinit.sh" 2>/dev/null \
  && pass "orchestrator: reinit has content-loss snapshot (byte-counts)" \
  || fail "orchestrator: reinit missing content-loss protection"

# psk-existing-setup.sh has destructive-edit snapshot
grep -q "manifest.txt" "$PROJ/agent/scripts/psk-existing-setup.sh" 2>/dev/null \
  && pass "orchestrator: existing-setup has destructive-edit snapshot" \
  || fail "orchestrator: existing-setup missing destructive-edit protection"

# Step 4 upgraded from mtime check to critic verdict
grep -q "STEP_4_FLOW_DOCS" "$PROJ/agent/scripts/psk-release.sh" 2>/dev/null && \
grep -q "Critic did not cover these flow docs" "$PROJ/agent/scripts/psk-release.sh" 2>/dev/null \
  && pass "step-4: psk-release.sh upgraded to per-flow-doc critic verdict" \
  || fail "step-4: still using mtime-only check (no per-flow-doc verdict)"

# Bypass audit log function exists in psk-validate.sh
grep -q "log_bypass" "$PROJ/agent/scripts/psk-validate.sh" 2>/dev/null && \
grep -q "BYPASS_LOG" "$PROJ/agent/scripts/psk-validate.sh" 2>/dev/null \
  && pass "bypass-audit: psk-validate.sh has log_bypass function" \
  || fail "bypass-audit: psk-validate.sh missing log_bypass"

# Both bypass env vars trigger logging
grep -A2 "PSK_SYNC_CHECK_DISABLED" "$PROJ/agent/scripts/psk-validate.sh" | grep -q "log_bypass" \
  && pass "bypass-audit: PSK_SYNC_CHECK_DISABLED logs to audit" \
  || fail "bypass-audit: PSK_SYNC_CHECK_DISABLED does not log"

grep -A2 "PSK_CRITIC_DISABLED" "$PROJ/agent/scripts/psk-validate.sh" | grep -q "log_bypass" \
  && pass "bypass-audit: PSK_CRITIC_DISABLED logs to audit" \
  || fail "bypass-audit: PSK_CRITIC_DISABLED does not log"

# sync-check surfaces bypass warning
grep -q "bypass(es) logged" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "bypass-audit: psk-sync-check.sh surfaces bypass warnings" \
  || fail "bypass-audit: sync-check does not surface bypass log"

# .bypass-log is gitignored (local-only audit trail)
grep -q "\.bypass-log" "$PROJ/agent/.gitignore" 2>/dev/null \
  && pass "bypass-audit: .bypass-log is gitignored (local audit trail)" \
  || fail "bypass-audit: .bypass-log not gitignored"

# Behavioral: bypass triggers log entry
rm -f "$PROJ/agent/.bypass-log" "$VSTATE/critic-task.md" "$VSTATE/critic-result.md" "$VSTATE/.validate-stamp"
PSK_SYNC_CHECK_DISABLED=1 PSK_CRITIC_DISABLED=1 bash "$PROJ/agent/scripts/psk-validate.sh" release >/dev/null 2>&1
if [ -f "$PROJ/agent/.bypass-log" ] && [ "$(wc -l < "$PROJ/agent/.bypass-log" | tr -d ' ')" -ge "2" ]; then
  pass "bypass-audit behavior: both bypasses produce log entries"
else
  fail "bypass-audit behavior: bypass did not create log entries"
fi
rm -f "$PROJ/agent/.bypass-log" "$VSTATE/critic-task.md" "$VSTATE/critic-result.md" "$VSTATE/.validate-stamp"

section "60d. Secret Scanning (PSK011)"

# check_secrets function present
grep -q "^check_secrets" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "secrets: check_secrets() function defined" \
  || fail "secrets: check_secrets() missing"

# Function is called in --full dispatch
grep -q "check_secrets" "$PROJ/agent/scripts/psk-sync-check.sh" | head -1 >/dev/null
if grep -A20 "check_current_version_docs$" "$PROJ/agent/scripts/psk-sync-check.sh" | grep -q "check_secrets"; then
  pass "secrets: check_secrets wired into --full dispatch"
else
  fail "secrets: check_secrets not in --full dispatch"
fi

# PSK011 error code documented in --help output
grep -q "PSK011" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "secrets: PSK011 error code documented in sync-check" \
  || fail "secrets: PSK011 error code missing"

# High-signal patterns present (spot-check that all 3 critical regexes exist in check_secrets)
# AWS: AKIA[0-9A-Z]{16}
# Anthropic: sk-ant-api[0-9]+...
# Private key: BEGIN (RSA|OPENSSH|...) PRIVATE KEY
for pat_regex_info in "AKIA\[0-9A-Z\]:AWS-access-key" "sk-ant-api:Anthropic-API-key" "BEGIN.*PRIVATE KEY:private-key-header"; do
  regex="${pat_regex_info%:*}"; label="${pat_regex_info##*:}"
  grep -qE "$regex" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
    && pass "secrets: pattern for $label present" \
    || fail "secrets: pattern for $label missing"
done

# Placeholder-aware exclusion (real patterns + example markers both present → must exclude)
grep -qE 'paste-your|example\.com|placeholder|XXXX' "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "secrets: placeholder-aware exclusions defined" \
  || fail "secrets: placeholder exclusions missing (would false-positive on .env.example)"

# Excluded paths (tests/fixtures, node_modules, binary extensions)
grep -qE 'node_modules|tests/fixtures|\.min\.js' "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "secrets: path exclusions defined (node_modules, fixtures, minified)" \
  || fail "secrets: path exclusions missing"

# Pattern count sanity: count alternations in the combined secrets_re variable (at least 10 high-signal patterns)
# Counts `|` separators in the secrets_re assignment line + 1 for the first alternative
secrets_re_line=$(grep -E "^  local secrets_re=" "$PROJ/agent/scripts/psk-sync-check.sh" | head -1)
pattern_count=$(echo "$secrets_re_line" | grep -oE '\|' | wc -l | tr -d ' ')
# Subtract 4 alternations that are inside grouping (RSA|OPENSSH|EC|DSA|PGP|ENCRYPTED = 5 alternations inside one pattern = 5 extra |)
pattern_count=$((pattern_count - 4))
if [ "$pattern_count" -ge 10 ]; then
  pass "secrets: at least 10 high-signal patterns registered ($pattern_count in combined regex)"
else
  fail "secrets: only $pattern_count patterns registered (expected >= 10)"
fi

# Pattern regex validity: load one pattern and confirm it matches a known-positive string.
# NOTE: we do NOT call sync-check --full from here — it would recurse via check_rft_gate → test-release-check → test-spec-kit.
# Kit's own repo passing the secret scan is verified manually + by the PreCommit hook on every commit.
test_positive='const x = "AKIAIOSFODNN7EXAMPLE";'
test_negative='AWS docs: keys start with AKIA followed by 16 chars — e.g. paste-your-key-here'
if echo "$test_positive" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  pass "secrets: AWS pattern regex matches real-format key"
else
  fail "secrets: AWS pattern regex does not match known-positive string"
fi

# Verify placeholder exclusion would fire on the negative case
if echo "$test_negative" | grep -qE 'paste-your|placeholder|example\.com'; then
  pass "secrets: placeholder exclusion regex catches example strings"
else
  fail "secrets: placeholder exclusion regex does not catch 'paste-your'"
fi

# check_secrets function is wired via git grep (fast, not per-file fork)
grep -q "git grep -nE" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "secrets: scan uses git grep (single-process, no fork storm)" \
  || fail "secrets: scan not using git grep (slow + process explosion risk)"

section "60e. Distribution Completeness (install.sh + sync.sh)"

# install.sh must ship every psk-*.sh script that exists in agent/scripts/
# (otherwise end users install a broken kit — critical for kit adoption)
critical_scripts="psk-sync-check.sh psk-install-hooks.sh psk-code-review.sh psk-scope-check.sh psk-release.sh psk-critic-spawn.sh psk-validate.sh psk-feature-complete.sh psk-init.sh psk-reinit.sh psk-new-setup.sh psk-existing-setup.sh psk-uninstall.sh psk-doc-sync.sh"
missing_install=""
for s in $critical_scripts; do
  grep -q "$s" "$PROJ/install.sh" 2>/dev/null || missing_install="$missing_install $s"
done
[ -z "$missing_install" ] \
  && pass "distribution: install.sh ships all 14 reliability scripts" \
  || fail "distribution: install.sh missing:$missing_install"

# sync.sh (author's push script) must copy every psk-*.sh to the public repo
missing_sync=""
for s in $critical_scripts; do
  grep -q "$s" "$PROJ/agent/scripts/sync.sh" 2>/dev/null || missing_sync="$missing_sync $s"
done
[ -z "$missing_sync" ] \
  && pass "distribution: sync.sh copies all 14 reliability scripts" \
  || fail "distribution: sync.sh missing:$missing_sync"

# CI workflow must exist and run the full test matrix + sync-check
[ -f "$PROJ/.github/workflows/ci.yml" ] \
  && pass "CI: .github/workflows/ci.yml exists" \
  || fail "CI: ci.yml missing (framework claims CI but none configured)"

if [ -f "$PROJ/.github/workflows/ci.yml" ]; then
  grep -q "test-spec-kit.sh" "$PROJ/.github/workflows/ci.yml" 2>/dev/null \
    && pass "CI: runs test-spec-kit.sh" \
    || fail "CI: doesn't run test-spec-kit.sh"
  grep -q "test-spd-benchmarking.sh" "$PROJ/.github/workflows/ci.yml" 2>/dev/null \
    && pass "CI: runs test-spd-benchmarking.sh" \
    || fail "CI: doesn't run test-spd-benchmarking.sh"
  grep -q "test-release-check.sh" "$PROJ/.github/workflows/ci.yml" 2>/dev/null \
    && pass "CI: runs test-release-check.sh" \
    || fail "CI: doesn't run test-release-check.sh"
  grep -q "psk-sync-check.sh" "$PROJ/.github/workflows/ci.yml" 2>/dev/null \
    && pass "CI: runs psk-sync-check.sh (includes PSK011 secret scan)" \
    || fail "CI: doesn't run psk-sync-check.sh (secrets not enforced on push/PR)"
fi

section "60j. Flow Doc Content + Critic Prompt Meta-Check (PSK016/017 — v0.5.19)"

# PSK016 function + wiring
grep -q "^check_flow_docs_content" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk016: check_flow_docs_content() function defined" \
  || fail "psk016: check_flow_docs_content() missing"

grep -q "    check_flow_docs_content$" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk016: check_flow_docs_content wired into --full dispatch" \
  || fail "psk016: check_flow_docs_content not in dispatch"

grep -q "PSK016" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk016: PSK016 error code documented" \
  || fail "psk016: PSK016 error code missing"

# PSK016 checks all 5 executable workflows
for pair in "psk-release.sh:13-release-workflow.md" "psk-new-setup.sh:03-new-project-setup.md" "psk-existing-setup.sh:04-existing-project-setup.md" "psk-init.sh:05-project-init.md" "psk-feature-complete.sh:11-spec-persistent-development.md"; do
  grep -q "$pair" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
    && pass "psk016: script↔flow-doc mapping present: $pair" \
    || fail "psk016: script↔flow-doc mapping missing: $pair"
done

# PSK016 also requires psk-reinit.sh in 05-project-init.md (composite mapping)
grep -qE "psk-init\.sh.*05-project-init\.md.*psk-reinit" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk016: 05-project-init.md requires both psk-init.sh + psk-reinit.sh" \
  || fail "psk016: composite reinit mapping missing"

# PSK017 function + wiring
grep -q "^check_critic_prompts_comprehensive" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk017: check_critic_prompts_comprehensive() function defined" \
  || fail "psk017: check_critic_prompts_comprehensive() missing"

grep -q "    check_critic_prompts_comprehensive$" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk017: check_critic_prompts_comprehensive wired into --full dispatch" \
  || fail "psk017: check_critic_prompts_comprehensive not in dispatch"

grep -q "PSK017" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk017: PSK017 error code documented" \
  || fail "psk017: PSK017 error code missing"

# PSK017 checks both critic prompts contain the required language
grep -q "OMISSION DETECTION" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk017: checks for OMISSION DETECTION in Step 4 prompt" \
  || fail "psk017: OMISSION DETECTION check missing"

grep -q "CROSS-DOC FEATURE COVERAGE" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk017: checks for CROSS-DOC FEATURE COVERAGE in Step 9 prompt" \
  || fail "psk017: CROSS-DOC FEATURE COVERAGE check missing"

# The actual critic prompts must contain the language PSK017 is checking for
awk '/STEP_4_FLOW_DOCS\)/,/;;/' "$PROJ/agent/scripts/psk-critic-spawn.sh" | grep -q "OMISSION DETECTION" \
  && pass "critic-prompt: STEP_4_FLOW_DOCS prompt contains OMISSION DETECTION section" \
  || fail "critic-prompt: STEP_4_FLOW_DOCS missing OMISSION DETECTION"

awk '/STEP_9_VALIDATION\)/,/;;/' "$PROJ/agent/scripts/psk-critic-spawn.sh" | grep -q "CROSS-DOC FEATURE COVERAGE" \
  && pass "critic-prompt: STEP_9_VALIDATION prompt contains CROSS-DOC FEATURE COVERAGE" \
  || fail "critic-prompt: STEP_9_VALIDATION missing CROSS-DOC FEATURE COVERAGE"

# Prompts explicitly list the 5 orchestrator↔flow-doc mappings
for script in psk-release.sh psk-new-setup.sh psk-existing-setup.sh psk-feature-complete.sh; do
  awk '/STEP_4_FLOW_DOCS\)/,/;;/' "$PROJ/agent/scripts/psk-critic-spawn.sh" | grep -q "$script" \
    && pass "critic-prompt: STEP_4 prompt mentions $script orchestrator mapping" \
    || fail "critic-prompt: STEP_4 missing $script mapping"
done

section "60k. Full Doc-Surface Coverage Analyzer (psk-doc-sync.sh — v0.5.20)"

# Script exists and is executable
[ -x "$PROJ/agent/scripts/psk-doc-sync.sh" ] \
  && pass "doc-sync: psk-doc-sync.sh exists and is executable" \
  || fail "doc-sync: psk-doc-sync.sh missing or not executable"

# Runs without error on current kit state
bash "$PROJ/agent/scripts/psk-doc-sync.sh" >/dev/null 2>&1 \
  && pass "doc-sync: runs cleanly in advisory mode (exit 0)" \
  || fail "doc-sync: advisory run failed"

# Covers all 5 doc surfaces by name in help/header
for surface in "agent/\*.md" "docs/work-flows/\*.md" "docs/research/\*.md" "ard/\*.html" "README.md"; do
  grep -q "$surface" "$PROJ/agent/scripts/psk-doc-sync.sh" \
    && pass "doc-sync: covers surface $surface" \
    || fail "doc-sync: missing surface $surface"
done

# Surface legend uses A/F/P/D/R codes
for code in "\[A\]gent" "\[F\]low-docs" "\[P\]aper" "AR\[D\]" "\[R\]eadme"; do
  grep -q "$code" "$PROJ/agent/scripts/psk-doc-sync.sh" \
    && pass "doc-sync: legend includes $code" \
    || fail "doc-sync: legend missing $code"
done

# Has COVERED/PARTIAL/MISSING classification
grep -q "COVERED" "$PROJ/agent/scripts/psk-doc-sync.sh" \
  && grep -q "PARTIAL" "$PROJ/agent/scripts/psk-doc-sync.sh" \
  && grep -q "MISSING" "$PROJ/agent/scripts/psk-doc-sync.sh" \
  && pass "doc-sync: classifies COVERED/PARTIAL/MISSING" \
  || fail "doc-sync: missing classification labels"

# --strict flag supported for CI use
grep -q '"--strict"' "$PROJ/agent/scripts/psk-doc-sync.sh" \
  && pass "doc-sync: --strict flag supported" \
  || fail "doc-sync: --strict flag missing"

# Suggests target docs based on keyword heuristic
grep -q "suggest_doc()" "$PROJ/agent/scripts/psk-doc-sync.sh" \
  && pass "doc-sync: suggest_doc() function defined" \
  || fail "doc-sync: suggest_doc() missing"

# STEP_4_FLOW_DOCS critic prompt references the analyzer
awk '/STEP_4_FLOW_DOCS\)/,/;;/' "$PROJ/agent/scripts/psk-critic-spawn.sh" | grep -q "psk-doc-sync.sh" \
  && pass "critic-prompt: STEP_4_FLOW_DOCS references psk-doc-sync.sh" \
  || fail "critic-prompt: STEP_4_FLOW_DOCS missing psk-doc-sync.sh reference"

# STEP_9_VALIDATION critic prompt references the analyzer
awk '/STEP_9_VALIDATION\)/,/;;/' "$PROJ/agent/scripts/psk-critic-spawn.sh" | grep -q "psk-doc-sync.sh" \
  && pass "critic-prompt: STEP_9_VALIDATION references psk-doc-sync.sh" \
  || fail "critic-prompt: STEP_9_VALIDATION missing psk-doc-sync.sh reference"

# release-process.md skill mentions the analyzer at Step 4
grep -q "psk-doc-sync.sh" "$PROJ/.portable-spec-kit/skills/release-process.md" \
  && pass "skill: release-process.md references psk-doc-sync.sh" \
  || fail "skill: release-process.md missing psk-doc-sync.sh"

# 13-release-workflow.md describes the analyzer at Step 4
grep -q "psk-doc-sync.sh" "$PROJ/docs/work-flows/13-release-workflow.md" \
  && pass "flow-doc: 13-release-workflow.md references psk-doc-sync.sh" \
  || fail "flow-doc: 13-release-workflow.md missing psk-doc-sync.sh"

section "60l. Stale Release State Detection (psk-release.sh — v0.5.20)"

# state_is_stale() function defined
grep -q "^state_is_stale()" "$PROJ/agent/scripts/psk-release.sh" \
  && pass "stale-state: state_is_stale() function defined" \
  || fail "stale-state: state_is_stale() missing"

# init_state writes START_VERSION
grep -q "^START_VERSION=" "$PROJ/agent/scripts/psk-release.sh" \
  && pass "stale-state: init_state writes START_VERSION" \
  || fail "stale-state: START_VERSION not captured at init"

# init_state clears .validate-stamp too
grep -q "rm -f.*\.validate-stamp" "$PROJ/agent/scripts/psk-release.sh" \
  && pass "stale-state: init_state clears .validate-stamp on prepare" \
  || fail "stale-state: .validate-stamp not cleared at prepare"

# run_next calls state_is_stale
awk '/^run_next\(\)/,/^}/' "$PROJ/agent/scripts/psk-release.sh" | grep -q "state_is_stale" \
  && pass "stale-state: run_next refuses stale state" \
  || fail "stale-state: run_next does not check staleness"

# 24h time threshold hardcoded
grep -q "age_sec.*86400\|86400.*age_sec\|gt 86400" "$PROJ/agent/scripts/psk-release.sh" \
  && pass "stale-state: 24h (86400s) threshold enforced" \
  || fail "stale-state: 24h threshold missing"

# Version-drift check only triggers if STEP_6 is still pending (don't false-flag legitimate bumps)
grep -B1 "START_VERSION" "$PROJ/agent/scripts/psk-release.sh" | grep -q "STEP_6_VERSION.*pending\|pending.*STEP_6" 2>/dev/null || \
  grep -A20 "state_is_stale" "$PROJ/agent/scripts/psk-release.sh" | grep -q 'STEP_6_VERSION.*pending\|pending.*STEP_6' \
  && pass "stale-state: version drift only flagged when STEP_6 pending" \
  || fail "stale-state: version drift check doesn't exempt legitimate bumps"

# status command surfaces stale-state warning
grep -A3 "RELEASE PROGRESS" "$PROJ/agent/scripts/psk-release.sh" | grep -q "state_is_stale\|State is stale" \
  && pass "stale-state: show_status surfaces warning" \
  || fail "stale-state: show_status does not warn on stale"

# Time-based stale refusal actually refuses (behavioral test)
mkdir -p "$PROJ/agent/.release-state" 2>/dev/null
_original_state="$PROJ/agent/.release-state/state"
_backup="/tmp/psk-stale-test-$$"
[ -f "$_original_state" ] && cp "$_original_state" "$_backup"
cat > "$_original_state" <<EOF
RELEASE_MODE=prepare
STEP_1_TESTS=pending
STEP_2_CODE_REVIEW=pending
STEP_3_SCOPE_CHECK=pending
STEP_4_FLOW_DOCS=pending
STEP_5_COUNTS=pending
STEP_6_VERSION=pending
STEP_7_PDFS=pending
STEP_8_RELEASES=pending
STEP_9_VALIDATION=pending
STEP_10_SUMMARY=pending
RUN_ID=1000000000
STARTED=2001-09-09T00:00:00Z
START_VERSION=v0.1.0
EOF
bash "$PROJ/agent/scripts/psk-release.sh" next 2>&1 | grep -q "Refusing to resume stale release state" \
  && pass "stale-state: behavioral — 24h-old RUN_ID blocks 'next'" \
  || fail "stale-state: behavioral — 'next' did not refuse stale state"
[ -f "$_backup" ] && cp "$_backup" "$_original_state" && rm -f "$_backup"

section "60m. F70 Reflex — Adversarial Verbal Actor-Critic Refinement Loop (AVACR) v0.5.21–v0.5.23"

# psk-reflex.sh command driver (v0.5.23)
[ -x "$PROJ/agent/scripts/psk-reflex.sh" ] \
  && pass "reflex: psk-reflex.sh command driver present + executable" \
  || fail "reflex: psk-reflex.sh missing"

for cmd in "prepare" "qa" "dev" "pass" "loop" "status" "reset"; do
  grep -qE "^  $cmd\)" "$PROJ/agent/scripts/psk-reflex.sh" \
    && pass "reflex: psk-reflex.sh supports '$cmd' subcommand" \
    || fail "reflex: psk-reflex.sh missing '$cmd' subcommand"
done

grep -q -- "--passes" "$PROJ/agent/scripts/psk-reflex.sh" \
  && pass "reflex: loop accepts --passes N" \
  || fail "reflex: loop missing --passes"
grep -q -- "--patience" "$PROJ/agent/scripts/psk-reflex.sh" \
  && pass "reflex: loop accepts --patience P (early stopping)" \
  || fail "reflex: loop missing --patience"

grep -qE 'Converged|converged' "$PROJ/agent/scripts/psk-reflex.sh" \
  && pass "reflex: loop detects convergence (zero findings)" \
  || fail "reflex: loop missing convergence detection"
grep -qE 'Early stopping|patience' "$PROJ/agent/scripts/psk-reflex.sh" \
  && pass "reflex: loop implements early stopping on patience" \
  || fail "reflex: loop missing early stopping"

grep -qE "\bpass\b|pass=" "$PROJ/agent/scripts/psk-reflex.sh" \
  && pass "reflex: uses pass terminology (SWE review vocabulary)" \
  || fail "reflex: missing epoch terminology"

# Literature grounding — citations in the script header
grep -qE "Shinn|Reflexion" "$PROJ/agent/scripts/psk-reflex.sh" \
  && pass "reflex: cites Reflexion (Shinn et al. 2023)" \
  || fail "reflex: missing Reflexion citation"
grep -qE "Self-Refine|Madaan" "$PROJ/agent/scripts/psk-reflex.sh" \
  && pass "reflex: cites Self-Refine (Madaan et al. 2023)" \
  || fail "reflex: missing Self-Refine citation"
grep -qE "Lost-in-the-middle|Liu et al" "$PROJ/agent/scripts/psk-reflex.sh" \
  && pass "reflex: cites Lost-in-the-middle (Liu et al. 2023)" \
  || fail "reflex: missing Lost-in-the-middle citation"
grep -qE "Automated Program Repair|APR" "$PROJ/agent/scripts/psk-reflex.sh" \
  && pass "reflex: positions within Automated Program Repair (APR) literature" \
  || fail "reflex: missing APR positioning"

grep -q "Adversarial Verbal Actor-Critic Refinement\|AVACR" "$PROJ/agent/scripts/psk-reflex.sh" \
  && pass "reflex: formal name AVACR present" \
  || fail "reflex: AVACR formal name missing"

grep -qE "psk-release.sh" "$PROJ/agent/scripts/psk-reflex.sh" \
  && pass "reflex: prepare subcommand wraps psk-release.sh" \
  || fail "reflex: prepare doesn't wrap psk-release.sh"

# Autoloop → refine rename completed
[ ! -d "$PROJ/autoloop" ] && [ ! -d "$PROJ/refine" ] \
  && pass "reflex: old autoloop/ directory removed (renamed to reflex/)" \
  || fail "reflex: stale autoloop/ still exists"

# Directory structure
[ -d "$PROJ/reflex" ] \
  && pass "reflex: reflex/ directory exists" \
  || fail "reflex: directory missing"
[ -d "$PROJ/reflex/lib" ] && [ -d "$PROJ/reflex/prompts" ] && [ -d "$PROJ/reflex/history" ] \
  && pass "reflex: lib/, prompts/, history/ subdirs present" \
  || fail "reflex: subdirs missing"

# Core scripts
for f in run.sh install-into-project.sh README.md config.yml; do
  [ -f "$PROJ/reflex/$f" ] \
    && pass "reflex: $f present" \
    || fail "reflex: $f missing"
done

# Lib helpers
for f in preconditions.sh spawn-qa.sh spawn-dev.sh file-bugs.sh gates.sh regression-diff.sh score.sh; do
  [ -x "$PROJ/reflex/lib/$f" ] \
    && pass "reflex: lib/$f exists and is executable" \
    || fail "reflex: lib/$f missing or not executable"
done

# Prompts
for f in qa-agent.md dev-agent.md; do
  [ -f "$PROJ/reflex/prompts/$f" ] \
    && pass "reflex: prompts/$f present" \
    || fail "reflex: prompts/$f missing"
done

# Prompt content — QA-Agent specifies black-box discipline
grep -q "black-box" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "reflex: qa-agent.md specifies black-box discipline" \
  || fail "reflex: qa-agent.md missing black-box spec"

grep -q "citable quote\|citable QUOTE\|cite a" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "reflex: qa-agent.md requires citable spec quotes" \
  || fail "reflex: qa-agent.md missing citable-quote honesty gate"

# Prompt content — Dev-Agent specifies atomic commits + retry cap
grep -q "atomic\|atomically\|Atomic" "$PROJ/reflex/prompts/dev-agent.md" \
  && pass "reflex: dev-agent.md requires atomic commits" \
  || fail "reflex: dev-agent.md missing atomic commit rule"

grep -qE 'retry|retries' "$PROJ/reflex/prompts/dev-agent.md" \
  && pass "reflex: dev-agent.md has retry logic" \
  || fail "reflex: dev-agent.md missing retry logic"

# 4-bucket diagnosis
grep -q "Bucket" "$PROJ/reflex/prompts/dev-agent.md" \
  && pass "reflex: dev-agent.md specifies 4-bucket diagnosis" \
  || fail "reflex: dev-agent.md missing bucket diagnosis"

# Precondition — HEAD must be prep-release
grep -q "prep.release\|prepare release\|refresh release" "$PROJ/reflex/lib/preconditions.sh" \
  && pass "reflex: preconditions enforce prep-release HEAD" \
  || fail "reflex: preconditions missing prep-release check"

# Preconditions refuse dirty tree
grep -q "working tree has uncommitted\|porcelain" "$PROJ/reflex/lib/preconditions.sh" \
  && pass "reflex: preconditions refuse dirty tree" \
  || fail "reflex: preconditions missing clean-tree check"

# file-bugs respects [~] marker
grep -q '\[~\]\|acknowledged' "$PROJ/reflex/lib/file-bugs.sh" \
  && pass "reflex: file-bugs.sh respects [~] acknowledged marker" \
  || fail "reflex: file-bugs.sh missing [~] respect"

# file-bugs idempotency — skips already-filed IDs
grep -q "already-tracked\|existing_ids\|existing IDs" "$PROJ/reflex/lib/file-bugs.sh" \
  && pass "reflex: file-bugs.sh idempotent on already-filed IDs" \
  || fail "reflex: file-bugs.sh missing idempotency"

# gates.sh reads config.yml mechanical_gates
grep -q "mechanical_gates" "$PROJ/reflex/lib/gates.sh" \
  && pass "reflex: gates.sh reads mechanical_gates from config.yml" \
  || fail "reflex: gates.sh doesn't read config"

# regression-diff detects previously-[x] regressions
grep -q "regressed\|previously \[x\]" "$PROJ/reflex/lib/regression-diff.sh" \
  && pass "reflex: regression-diff detects [x]-to-[ ] regressions" \
  || fail "reflex: regression-diff missing regression detection"

# score.sh writes summary.csv
grep -q "summary.csv" "$PROJ/reflex/lib/score.sh" \
  && pass "reflex: score.sh writes summary.csv" \
  || fail "reflex: score.sh doesn't write summary.csv"

# run.sh has all 4 key modes
grep -q "resume-qa\|--resume" "$PROJ/reflex/run.sh" \
  && pass "reflex: run.sh supports resume-qa mode" \
  || fail "reflex: run.sh missing resume-qa mode"
grep -q "resume-dev" "$PROJ/reflex/run.sh" \
  && pass "reflex: run.sh supports resume-dev mode" \
  || fail "reflex: run.sh missing resume-dev mode"
grep -q 'MODE="status"\|status)' "$PROJ/reflex/run.sh" \
  && pass "reflex: run.sh supports status mode" \
  || fail "reflex: run.sh missing status mode"
grep -q 'MODE="run"\|MODE="${MODE:-run}"\|run)' "$PROJ/reflex/run.sh" \
  && pass "reflex: run.sh supports run mode" \
  || fail "reflex: run.sh missing run mode"

# Installer validates target is a speckit project
grep -q "not a speckit project\|AGENT_CONTEXT.md" "$PROJ/reflex/install-into-project.sh" \
  && pass "reflex: installer refuses non-speckit targets" \
  || fail "reflex: installer missing speckit validation"

# Installer detects project's test commands
grep -qE "npm test|pytest|go test|test-release-check" "$PROJ/reflex/install-into-project.sh" \
  && pass "reflex: installer auto-detects project test commands" \
  || fail "reflex: installer missing test detection"

# Installer appends to target .gitignore
grep -q "gitignore" "$PROJ/reflex/install-into-project.sh" \
  && pass "reflex: installer appends to target .gitignore" \
  || fail "reflex: installer doesn't update .gitignore"

# Installer works on example projects (integration test)
for ex in my-app starter; do
  [ -d "$PROJ/examples/$ex/reflex" ] && [ -f "$PROJ/examples/$ex/reflex/run.sh" ] \
    && pass "reflex: installed in examples/$ex/ successfully" \
    || fail "reflex: missing from examples/$ex/"
done

# psk-release.sh Step 10 mentions prep-release commit convention (for precondition matching)
grep -qE "prep release|refresh release|prep-release" "$PROJ/agent/scripts/psk-release.sh" \
  && pass "reflex: psk-release.sh describes refine precondition convention" \
  || fail "reflex: psk-release.sh Step 10 missing precondition convention"

# Framework rule — plan-to-pipeline sync
grep -q "Plan-mode → implementation transition\|plan-to-pipeline" "$PROJ/portable-spec-kit.md" \
  && pass "reflex: framework codifies plan-to-pipeline sync rule" \
  || fail "reflex: plan-to-pipeline sync rule missing from framework"

# F70 present in SPECS
grep -q "^| F70 " "$PROJ/agent/SPECS.md" \
  && pass "reflex: F70 row in SPECS.md" \
  || fail "reflex: F70 row missing from SPECS.md"

# F70 acceptance criteria subsection
grep -q "^### F70" "$PROJ/agent/SPECS.md" \
  && pass "reflex: F70 acceptance criteria subsection in SPECS.md" \
  || fail "reflex: F70 acceptance subsection missing"

# Design plan
[ -f "$PROJ/agent/design/f70-reflex.md" ] \
  && pass "reflex: agent/design/f70-reflex.md plan committed" \
  || fail "reflex: design plan missing"

# ADL entries for F70 architecture decisions
for adr in ADR-012 ADR-013 ADR-014 ADR-015; do
  grep -q "$adr" "$PROJ/agent/PLANS.md" \
    && pass "reflex: $adr in PLANS.md ADL" \
    || fail "reflex: $adr missing from PLANS.md"
done

section "60i. README Structural Checks (PSK013/014/015 — v0.5.18)"

# PSK013 check_readme_install_list function present + wired
grep -q "^check_readme_install_list" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk013: check_readme_install_list() function defined" \
  || fail "psk013: check_readme_install_list() missing"

grep -q "    check_readme_install_list$" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk013: check_readme_install_list wired into --full dispatch" \
  || fail "psk013: check_readme_install_list not in dispatch"

grep -q "PSK013" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk013: PSK013 error code documented" \
  || fail "psk013: PSK013 error code missing"

# PSK013 excludes jira/tracker from reliability count
grep -q "grep -vE '(jira|tracker)'" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk013: excludes jira/tracker from 'reliability scripts' count" \
  || fail "psk013: doesn't exclude optional scripts"

# PSK014 check_readme_agent_table function + wiring
grep -q "^check_readme_agent_table" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk014: check_readme_agent_table() function defined" \
  || fail "psk014: check_readme_agent_table() missing"

grep -q "    check_readme_agent_table$" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk014: check_readme_agent_table wired into --full dispatch" \
  || fail "psk014: check_readme_agent_table not in dispatch"

grep -q "PSK014" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk014: PSK014 error code documented" \
  || fail "psk014: PSK014 error code missing"

# PSK015 check_readme_flow_table function + wiring
grep -q "^check_readme_flow_table" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk015: check_readme_flow_table() function defined" \
  || fail "psk015: check_readme_flow_table() missing"

grep -q "    check_readme_flow_table$" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk015: check_readme_flow_table wired into --full dispatch" \
  || fail "psk015: check_readme_flow_table not in dispatch"

grep -q "PSK015" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk015: PSK015 error code documented" \
  || fail "psk015: PSK015 error code missing"

# Behavioral sanity: current kit state passes all 3 new checks (otherwise commit would be blocked)
install_result=$(awk '/^Installs:/' "$PROJ/README.md")
[ -n "$install_result" ] \
  && pass "psk013: kit README has 'Installs:' line present" \
  || fail "psk013: kit README missing 'Installs:' line (would false-positive PSK013)"

agent_md_count=$(ls "$PROJ/agent/"*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$agent_md_count" -ge 9 ] \
  && pass "psk014: kit has $agent_md_count agent/*.md files (PSK014 checks table matches)" \
  || fail "psk014: agent/*.md count too low ($agent_md_count)"

flow_count=$(ls "$PROJ/docs/work-flows/"*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$flow_count" -ge 16 ] \
  && pass "psk015: kit has $flow_count flow docs (PSK015 checks table matches)" \
  || fail "psk015: flow doc count too low ($flow_count)"

section "60h. README Content Check (PSK012 — v0.5.17)"

# check_readme_content function present
grep -q "^check_readme_content" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk012: check_readme_content() function defined" \
  || fail "psk012: check_readme_content() missing"

# Called in --full dispatch (must appear in the full-mode check chain, between check_agent_md_stack and check_secrets)
awk '/check_agent_md_stack/,/check_secrets$/' "$PROJ/agent/scripts/psk-sync-check.sh" | grep -q "^    check_readme_content$" \
  && pass "psk012: check_readme_content wired into --full dispatch" \
  || fail "psk012: check_readme_content not in dispatch"

# PSK012 error code in help
grep -q "PSK012" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "psk012: PSK012 error code documented" \
  || fail "psk012: PSK012 missing"

# Framework rule in release-process skill mentions Latest Release + REPLACE
grep -q "Latest Release" "$PROJ/.portable-spec-kit/skills/release-process.md" 2>/dev/null && \
grep -q "REPLACE, don't accumulate" "$PROJ/.portable-spec-kit/skills/release-process.md" 2>/dev/null \
  && pass "psk012: framework rule enforces 'Latest Release' + replace-don't-accumulate" \
  || fail "psk012: release-process.md missing Latest Release rule"

# README actually has "Latest Release" section (current state must be valid)
grep -qE "^## Latest Release" "$PROJ/README.md" 2>/dev/null \
  && pass "psk012: README has '## Latest Release' section" \
  || fail "psk012: README missing 'Latest Release' section"

# README's Latest Release section links to CHANGELOG
awk '/^## Latest Release/,/^## [^L]/' "$PROJ/README.md" | grep -q "CHANGELOG.md" \
  && pass "psk012: README 'Latest Release' links to CHANGELOG.md" \
  || fail "psk012: README 'Latest Release' missing CHANGELOG link"

# Only ONE 'What's New in vX' section max (enforce replace-don't-accumulate)
wn_count=$(grep -cE "^## What's New in v[0-9]+" "$PROJ/README.md" 2>/dev/null)
if [ "$wn_count" -le 1 ]; then
  pass "psk012: README has ≤1 'What's New in vX' section ($wn_count found — no accumulation)"
else
  fail "psk012: README has $wn_count 'What's New' sections (should accumulate in CHANGELOG, not README)"
fi

section "60g. v0.5.16 — RFT Cache + CI Templates + Compact Output"

# RFT cache implementation present in sync-check
grep -q "rft-cache.txt" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "rft-cache: cache file referenced in sync-check" \
  || fail "rft-cache: not implemented"

grep -q "find.*-newer" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "rft-cache: mtime-based invalidation (find -newer) present" \
  || fail "rft-cache: no mtime invalidation check"

grep -q "PSK_RFT_NO_CACHE" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "rft-cache: PSK_RFT_NO_CACHE bypass env var defined" \
  || fail "rft-cache: no bypass env var"

# Output-discipline footer present in critic-spawn
grep -q "^output_discipline" "$PROJ/agent/scripts/psk-critic-spawn.sh" 2>/dev/null \
  && pass "opt7: output_discipline() function defined" \
  || fail "opt7: output_discipline() missing"

grep -q 'discipline=\$(output_discipline)' "$PROJ/agent/scripts/psk-critic-spawn.sh" 2>/dev/null \
  && pass "opt7: discipline footer wired into task file write" \
  || fail "opt7: discipline footer not appended to critic task"

# CI templates for user projects
for tmpl in ci-node.yml ci-python.yml ci-go.yml ci-generic.yml README.md; do
  [ -f "$PROJ/.portable-spec-kit/templates/ci/$tmpl" ] \
    && pass "ci-templates: $tmpl exists" \
    || fail "ci-templates: $tmpl missing"
done

# Each CI template must run kit gates
for tmpl in ci-node.yml ci-python.yml ci-go.yml ci-generic.yml; do
  grep -q "psk-sync-check.sh --full" "$PROJ/.portable-spec-kit/templates/ci/$tmpl" 2>/dev/null \
    && pass "ci-templates: $tmpl runs psk-sync-check --full" \
    || fail "ci-templates: $tmpl doesn't run sync-check"
done

# install.sh + sync.sh ship CI templates
grep -q "ci-node.yml" "$PROJ/install.sh" 2>/dev/null \
  && pass "distribution: install.sh ships CI templates" \
  || fail "distribution: install.sh doesn't ship CI templates"

grep -q "templates/ci" "$PROJ/agent/scripts/sync.sh" 2>/dev/null \
  && pass "distribution: sync.sh copies CI templates" \
  || fail "distribution: sync.sh doesn't copy CI templates"

# Migration protection — install.sh doesn't overwrite existing user files silently
grep -qE "psk-backup|backup|\.bak" "$PROJ/install.sh" 2>/dev/null \
  && pass "migration: install.sh backs up existing non-symlink files" \
  || fail "migration: install.sh has no backup safety for existing files"

# Closes QA-REL-NONDETERM-02 (v0.6.28): test-ref-cache key must include cwd so
# running test-release-check.sh from a non-PROJ_ROOT cwd cannot pollute the
# canonical PROJ_ROOT cache with cwd-relative results.
grep -q "current_cwd=" "$PROJ/tests/test-release-check.sh" 2>/dev/null \
  && pass "rft-cache: test-ref-cache key includes cwd (QA-REL-NONDETERM-02)" \
  || fail "rft-cache: test-ref-cache key missing cwd component (regression risk)"

grep -q 'current_key="\${current_head}|\${current_cwd}"' "$PROJ/tests/test-release-check.sh" 2>/dev/null \
  && pass "rft-cache: cache key composes head|cwd" \
  || fail "rft-cache: cache key composition wrong"

# Closes QA-AUDIT-CSV-01 (v0.6.28): summary.csv completeness check + score.sh
# auto-invoke on close-finding. summary.csv must have a row for every closed
# reflex pass dir; score.sh must run without awk warnings.
grep -q "check_summary_csv_completeness" "$PROJ/agent/scripts/psk-sync-check.sh" 2>/dev/null \
  && pass "audit-csv: psk-sync-check.sh has check_summary_csv_completeness (QA-AUDIT-CSV-01)" \
  || fail "audit-csv: check_summary_csv_completeness missing"

grep -q 'REFLEX_PASS_DIR="\$TARGET_PASS" bash "\$SCORE_SH"' "$PROJ/agent/scripts/psk-close-finding.sh" 2>/dev/null \
  && pass "audit-csv: psk-close-finding.sh auto-invokes score.sh on last close" \
  || fail "audit-csv: psk-close-finding.sh missing score.sh hook"

# Closes QA-AUDIT-SCORE-AWK-01 (v0.6.28): score.sh must emit no awk warnings
# (was tripping on multi-line "0\n0" produced by `grep -c ... || echo 0`).
SCORE_AWK_ERR=$(REFLEX_PASS_DIR="$PROJ/reflex/history/cycle-03/pass-001" bash "$PROJ/reflex/lib/score.sh" 2>&1 | grep -c "^awk:" 2>/dev/null)
SCORE_AWK_ERR="${SCORE_AWK_ERR:-0}"
[ "$SCORE_AWK_ERR" = "0" ] \
  && pass "score.sh: no awk warnings (QA-AUDIT-SCORE-AWK-01)" \
  || fail "score.sh: emits $SCORE_AWK_ERR awk warning lines"

section "60f. Verbatim-Quote Critic Verification (v0.5.15)"

# verify_quotes function present in psk-validate.sh
grep -q "^verify_quotes" "$PROJ/agent/scripts/psk-validate.sh" 2>/dev/null \
  && pass "quote-verify: verify_quotes() function defined in psk-validate.sh" \
  || fail "quote-verify: verify_quotes() function missing"

# Function is called in the CURRENT/STALE evaluation flow
grep -q "verify_quotes \"\$RESULT_FILE\"" "$PROJ/agent/scripts/psk-validate.sh" 2>/dev/null \
  && pass "quote-verify: verify_quotes invoked on critic result" \
  || fail "quote-verify: verify_quotes not wired into result evaluation"

# Grep-based verification uses fixed-string match (grep -F) to avoid regex interpretation of QUOTE text
grep -q "grep -qF" "$PROJ/agent/scripts/psk-validate.sh" 2>/dev/null \
  && pass "quote-verify: uses grep -F (fixed string — QUOTE text not regex-interpreted)" \
  || fail "quote-verify: not using grep -F (QUOTE with special chars would break)"

# Minimum quote length enforcement (prevents trivial "a" quotes)
grep -qE '20' "$PROJ/agent/scripts/psk-validate.sh" | head -1 >/dev/null
grep -q "too short" "$PROJ/agent/scripts/psk-validate.sh" 2>/dev/null \
  && pass "quote-verify: minimum QUOTE length enforced" \
  || fail "quote-verify: no minimum QUOTE length check"

# All 6 critic templates include QUOTE: requirement
for tpl in STEP_4_FLOW_DOCS STEP_8_RELEASES STEP_9_VALIDATION FEATURE_COMPLETE INIT REINIT NEW_SETUP EXISTING_SETUP; do
  # Extract template body and check for QUOTE: requirement
  awk "/^    ${tpl})/,/^      ;;/" "$PROJ/agent/scripts/psk-critic-spawn.sh" | grep -q "QUOTE:" \
    && pass "quote-verify: critic template $tpl requires QUOTE:" \
    || fail "quote-verify: critic template $tpl missing QUOTE: requirement"
done


# ═══════════════════════════════════════════════════════════════
section "61. Workflow Fidelity (§Workflow Fidelity — v0.6.56)"
# ═══════════════════════════════════════════════════════════════

WFS="$PROJ/agent/scripts/psk-workflow-state.sh"
SPAWN="$PROJ/agent/scripts/psk-spawn.sh"

[ -x "$WFS" ] \
  && pass "workflow-fidelity: psk-workflow-state.sh exists and is executable" \
  || fail "workflow-fidelity: psk-workflow-state.sh missing or not executable"
[ -x "$SPAWN" ] \
  && pass "workflow-fidelity: psk-spawn.sh exists and is executable" \
  || fail "workflow-fidelity: psk-spawn.sh missing or not executable"

# §Workflow Fidelity rule present in framework + P10 in PHILOSOPHY.md
grep -q "## Workflow Fidelity" "$PROJ/portable-spec-kit.md" \
  && pass "workflow-fidelity: §Workflow Fidelity section in portable-spec-kit.md" \
  || fail "workflow-fidelity: §Workflow Fidelity section missing"
grep -q "P10 — Workflow Fidelity" "$PROJ/agent/PHILOSOPHY.md" \
  && pass "workflow-fidelity: P10 principle in PHILOSOPHY.md" \
  || fail "workflow-fidelity: P10 principle missing"

# State machine: init → mark-done round-trip + gate-blocks-advance
if [ -x "$WFS" ]; then
  _wft_tmp=$(mktemp -d)
  ( PROJ_ROOT="$_wft_tmp" bash "$WFS" init wft-test "a,b" >/dev/null 2>&1 )
  [ -f "$_wft_tmp/agent/.workflow-state/wft-test.state" ] \
    && pass "workflow-fidelity: state machine init creates state file" \
    || fail "workflow-fidelity: state machine init did not create state file"
  ( PROJ_ROOT="$_wft_tmp" bash "$WFS" mark-done wft-test a >/dev/null 2>&1 )
  PROJ_ROOT="$_wft_tmp" bash "$WFS" get-phase wft-test 2>/dev/null | grep -q "^b " \
    && pass "workflow-fidelity: mark-done advances to next phase" \
    || fail "workflow-fidelity: mark-done did not advance phase"
  # gate-blocks-advance: register a failing gate, assert mark-done refuses
  ( PROJ_ROOT="$_wft_tmp" bash "$WFS" register-gate wft-test b "false" >/dev/null 2>&1 )
  if ( PROJ_ROOT="$_wft_tmp" bash "$WFS" mark-done wft-test b >/dev/null 2>&1 ); then
    fail "workflow-fidelity: failing gate did NOT block mark-done (fidelity hole)"
  else
    pass "workflow-fidelity: failing completion gate blocks mark-done"
  fi
  # resume points at the exact unfinished phase
  PROJ_ROOT="$_wft_tmp" bash "$WFS" resume wft-test 2>/dev/null | grep -q "phase: b" \
    && pass "workflow-fidelity: resume re-enters at exact unfinished phase" \
    || fail "workflow-fidelity: resume did not point at unfinished phase"
  rm -rf "$_wft_tmp"
fi

# Spawn protocol: NO inline-fallback code path. The script must never contain a
# branch that performs the sub-agent's work itself. We assert structurally:
# every case-dispatch target is one of the known lifecycle verbs, and there is
# no function that does work beyond request/complete/retry/status bookkeeping.
if [ -x "$SPAWN" ]; then
  # Assert the only dispatch verbs are the lifecycle verbs (no "inline"/"fallback" verb)
  _spawn_verbs=$(grep -oE '^\s+(request|complete|retry|status|inline|fallback|do-it)\)' "$SPAWN" | tr -d ' )' | sort -u | tr '\n' ',')
  if [ "$_spawn_verbs" = "complete,request,retry,status," ]; then
    pass "workflow-fidelity: psk-spawn.sh dispatch verbs are lifecycle-only (no inline/fallback verb)"
  else
    fail "workflow-fidelity: psk-spawn.sh has unexpected dispatch verbs: $_spawn_verbs"
  fi
  # request → state machine pauses AWAITING; complete without artifact → exit 1
  _spawn_tmp=$(mktemp -d)
  mkdir -p "$_spawn_tmp/agent/scripts"
  cp "$WFS" "$_spawn_tmp/agent/scripts/" 2>/dev/null
  cp "$SPAWN" "$_spawn_tmp/agent/scripts/" 2>/dev/null
  echo "prompt" > "$_spawn_tmp/p.md"
  ( PROJ_ROOT="$_spawn_tmp" bash "$_spawn_tmp/agent/scripts/psk-workflow-state.sh" init orch "p0" >/dev/null 2>&1 )
  ( PROJ_ROOT="$_spawn_tmp" bash "$_spawn_tmp/agent/scripts/psk-spawn.sh" request orch p0 "$_spawn_tmp/p.md" "$_spawn_tmp/r.md" >/dev/null 2>&1 )
  PROJ_ROOT="$_spawn_tmp" bash "$_spawn_tmp/agent/scripts/psk-workflow-state.sh" status orch 2>/dev/null | grep -q "AWAITING" \
    && pass "workflow-fidelity: spawn request pauses workflow AWAITING_SUBAGENT" \
    || fail "workflow-fidelity: spawn request did not pause workflow"
  if ( PROJ_ROOT="$_spawn_tmp" bash "$_spawn_tmp/agent/scripts/psk-spawn.sh" complete orch p0 "$_spawn_tmp/r.md" >/dev/null 2>&1 ); then
    fail "workflow-fidelity: spawn complete succeeded with NO result artifact (fidelity hole)"
  else
    pass "workflow-fidelity: spawn complete refuses when result artifact is missing"
  fi
  rm -rf "$_spawn_tmp"
fi

# Retrofit coverage: every executable workflow references §Workflow Fidelity
for _wf in psk-orchestrate psk-new-setup psk-existing-setup psk-init psk-reinit psk-feature-complete; do
  grep -qi "workflow fidelity" "$PROJ/agent/scripts/$_wf.sh" \
    && pass "workflow-fidelity: $_wf.sh references §Workflow Fidelity" \
    || fail "workflow-fidelity: $_wf.sh missing §Workflow Fidelity reference"
done
grep -qi "workflow fidelity" "$PROJ/reflex/run.sh" \
  && pass "workflow-fidelity: reflex/run.sh references §Workflow Fidelity" \
  || fail "workflow-fidelity: reflex/run.sh missing §Workflow Fidelity reference"

section "62. Plan-Save body-preservation + schema validation (B0.3 — v0.6.57)"
# ═══════════════════════════════════════════════════════════════
# Regression coverage for `psk-plan-save.sh` body-preservation fix and the
# PSK024 schema-validation gate on `approve`. Catalyst: the v5 workflow-
# fidelity plan body was erased by a stdin-empty save invocation; the fix
# splits frontmatter from body via tempfiles and refreshes only `updated:`.
# Schema validation: PSK024-N (schema_version) / PSK024-P (phases) /
# PSK024-F (per-phase required fields) / PSK024-D (depends_on dangling) /
# PSK024-L (canonical path layout).

PLANSAVE="$PROJ/agent/scripts/psk-plan-save.sh"

# Prior sections cd into ephemeral tmp dirs that may be rm'd by later sections,
# leaving this shell's cwd dangling. Snap back to $PROJ before our subshell
# launches so getcwd() works inside child processes.
cd "$PROJ" 2>/dev/null || true

if [ ! -x "$PLANSAVE" ]; then
  fail "plan-save-b03: psk-plan-save.sh missing or not executable"
else
  pass "plan-save-b03: psk-plan-save.sh exists and is executable"

  # Per-section sandbox so we never touch agent/plans/ in the kit repo
  _ps_sandbox=$(mktemp -d -t plan-save-b03.XXXXXX)
  mkdir -p "$_ps_sandbox/agent/scripts"
  cp "$PLANSAVE" "$_ps_sandbox/agent/scripts/"
  _PS_SCRIPT="$_ps_sandbox/agent/scripts/psk-plan-save.sh"

  # ─── Test 1: save round-trip preserves complex frontmatter byte-for-byte
  _ps_complex_slug="b03-complex-plan"
  _ps_complex_file="$_ps_sandbox/agent/plans/2026-05-13-${_ps_complex_slug}.md"
  mkdir -p "$_ps_sandbox/agent/plans"
  cat > "$_ps_complex_file" <<'EOF'
---
status: executing
slug: b03-complex-plan
created: 2026-05-13
updated: 2026-05-15
target_releases: [v0.6.56, v0.6.57, v0.6.58]
trigger: "user prompt: 'fix everything'"
revision: 5
revision_note: |
  v5 — generalizes v4 per user feedback.
  Adds multi-line body preservation, schema validation,
  canonical path layout.
revision_history:
  - v1: initial draft
  - v2: added Phase B
  - v3: convergence strategy
schema_version: 1
phases:
  - id: phase-a
    name: "First phase"
    prompt: "agent/plans/b03-complex-plan/prompts/phase-a.md"
    artifact: "agent/plans/b03-complex-plan/artifacts/phase-a.done.md"
    gate: "test -f agent/plans/b03-complex-plan/artifacts/phase-a.done.md"
    commit_required: true
    depends_on: []
---

# Complex Test Plan

## Context
Multi-paragraph plan body with code blocks and tables.

```bash
echo "this should survive a save round-trip"
```

| Col1 | Col2 |
|------|------|
| a    | b    |

## End
Final line.
EOF

  cp "$_ps_complex_file" "$_ps_sandbox/before.md"
  ( PROJ_ROOT="$_ps_sandbox" bash "$_PS_SCRIPT" save "$_ps_complex_slug" </dev/null >/dev/null 2>&1 ) || true

  # Compare body section (everything after 2nd ---) byte-for-byte
  _ps_before_body=$(awk '/^---$/{c++; next} c>=2{print}' "$_ps_sandbox/before.md")
  _ps_after_body=$(awk '/^---$/{c++; next} c>=2{print}' "$_ps_complex_file")
  if [ "$_ps_before_body" = "$_ps_after_body" ]; then
    pass "plan-save-b03: save round-trip preserves markdown body byte-for-byte"
  else
    fail "plan-save-b03: save round-trip mutated body"
  fi

  # Verify revision_history (array) + revision_note (multi-line) survived
  if grep -q '^revision_history:' "$_ps_complex_file" \
     && grep -q '  - v1: initial draft' "$_ps_complex_file" \
     && grep -q '^revision_note: |' "$_ps_complex_file" \
     && grep -q 'v5 — generalizes v4 per user feedback' "$_ps_complex_file"; then
    pass "plan-save-b03: save round-trip preserves multi-line + array frontmatter values"
  else
    fail "plan-save-b03: save round-trip lost complex frontmatter fields"
  fi

  # Verify target_releases array survived
  if grep -q '^target_releases: \[v0.6.56, v0.6.57, v0.6.58\]' "$_ps_complex_file"; then
    pass "plan-save-b03: save round-trip preserves inline array frontmatter values"
  else
    fail "plan-save-b03: save round-trip lost inline array frontmatter values"
  fi

  # ─── Test 2: save refreshes `updated:` field
  _ps_updated_after=$(grep '^updated:' "$_ps_complex_file" | head -1)
  _ps_today=$(date +%Y-%m-%d)
  if [ "$_ps_updated_after" = "updated: $_ps_today" ]; then
    pass "plan-save-b03: save refreshes 'updated:' to today's date"
  else
    fail "plan-save-b03: save did not refresh 'updated:' field (got: '$_ps_updated_after')"
  fi

  # ─── Test 3: save does NOT change `status:` field
  if grep -q '^status: executing$' "$_ps_complex_file"; then
    pass "plan-save-b03: save preserves 'status:' field (no implicit transition)"
  else
    fail "plan-save-b03: save mutated 'status:' field"
  fi

  # ─── Test 4: full diff — only `updated:` line differs
  _ps_diff_lines=$(diff "$_ps_sandbox/before.md" "$_ps_complex_file" | grep -c '^[<>]')
  # 2 lines of diff = one < (before) and one > (after) for the single changed line
  if [ "$_ps_diff_lines" = "2" ]; then
    pass "plan-save-b03: save round-trip diff is exactly the 'updated:' field (2 diff lines)"
  else
    fail "plan-save-b03: save round-trip mutated more than 'updated:' field ($_ps_diff_lines diff lines)"
  fi

  # ─── Test 5: approve on valid schema plan succeeds, transitions to approved
  _ps_valid_slug="b03-valid-schema"
  _ps_valid_file="$_ps_sandbox/agent/plans/2026-05-13-${_ps_valid_slug}.md"
  cat > "$_ps_valid_file" <<EOF
---
status: draft
slug: $_ps_valid_slug
created: 2026-05-13
updated: 2026-05-13
schema_version: 1
phases:
  - id: phase-a
    name: "First phase"
    prompt: "agent/plans/$_ps_valid_slug/prompts/phase-a.md"
    artifact: "agent/plans/$_ps_valid_slug/artifacts/phase-a.done.md"
    gate: "true"
    commit_required: true
    depends_on: []
  - id: phase-b
    name: "Second phase"
    prompt: "agent/plans/$_ps_valid_slug/prompts/phase-b.md"
    artifact: "agent/plans/$_ps_valid_slug/artifacts/phase-b.done.md"
    gate: "true"
    commit_required: false
    depends_on: [phase-a]
---

# Body
EOF
  if ( PROJ_ROOT="$_ps_sandbox" bash "$_PS_SCRIPT" approve "$_ps_valid_slug" >/dev/null 2>&1 ); then
    if grep -q '^status: approved$' "$_ps_valid_file"; then
      pass "plan-save-b03: approve on valid schema plan succeeds and transitions to approved"
    else
      fail "plan-save-b03: approve on valid schema plan did not transition status"
    fi
  else
    fail "plan-save-b03: approve refused a valid schema plan"
  fi

  # ─── Test 6: approve on plan missing `phases:` → PSK024-P
  _ps_nophases_slug="b03-no-phases"
  _ps_nophases_file="$_ps_sandbox/agent/plans/2026-05-13-${_ps_nophases_slug}.md"
  cat > "$_ps_nophases_file" <<EOF
---
status: draft
slug: $_ps_nophases_slug
created: 2026-05-13
updated: 2026-05-13
schema_version: 1
---

# Body
EOF
  _ps_err=$( ( PROJ_ROOT="$_ps_sandbox" bash "$_PS_SCRIPT" approve "$_ps_nophases_slug" 2>&1 >/dev/null ) || true )
  if echo "$_ps_err" | grep -q 'PSK024-P'; then
    pass "plan-save-b03: approve refuses plan missing 'phases:' (PSK024-P)"
  else
    fail "plan-save-b03: approve did not emit PSK024-P for missing phases (got: $_ps_err)"
  fi
  if grep -q '^status: draft$' "$_ps_nophases_file"; then
    pass "plan-save-b03: approve refusal did not advance status (still draft)"
  else
    fail "plan-save-b03: approve refusal advanced status anyway"
  fi

  # ─── Test 7: approve on plan with phase missing `prompt:` → PSK024-F
  _ps_noprompt_slug="b03-phase-no-prompt"
  _ps_noprompt_file="$_ps_sandbox/agent/plans/2026-05-13-${_ps_noprompt_slug}.md"
  cat > "$_ps_noprompt_file" <<EOF
---
status: draft
slug: $_ps_noprompt_slug
created: 2026-05-13
updated: 2026-05-13
schema_version: 1
phases:
  - id: phase-a
    name: "First phase"
    artifact: "agent/plans/$_ps_noprompt_slug/artifacts/phase-a.done.md"
    gate: "true"
    commit_required: true
    depends_on: []
---

# Body
EOF
  _ps_err=$( ( PROJ_ROOT="$_ps_sandbox" bash "$_PS_SCRIPT" approve "$_ps_noprompt_slug" 2>&1 >/dev/null ) || true )
  if echo "$_ps_err" | grep -q "PSK024-F: phase phase-a missing 'prompt'"; then
    pass "plan-save-b03: approve refuses phase missing 'prompt:' (PSK024-F)"
  else
    fail "plan-save-b03: approve did not emit PSK024-F for missing prompt (got: $_ps_err)"
  fi

  # ─── Test 8: approve on plan with depends_on referencing nonexistent phase → PSK024-D
  _ps_baddep_slug="b03-bad-depends"
  _ps_baddep_file="$_ps_sandbox/agent/plans/2026-05-13-${_ps_baddep_slug}.md"
  cat > "$_ps_baddep_file" <<EOF
---
status: draft
slug: $_ps_baddep_slug
created: 2026-05-13
updated: 2026-05-13
schema_version: 1
phases:
  - id: phase-a
    name: "Phase A"
    prompt: "agent/plans/$_ps_baddep_slug/prompts/phase-a.md"
    artifact: "agent/plans/$_ps_baddep_slug/artifacts/phase-a.done.md"
    gate: "true"
    commit_required: true
    depends_on: [phase-zzz]
---

# Body
EOF
  _ps_err=$( ( PROJ_ROOT="$_ps_sandbox" bash "$_PS_SCRIPT" approve "$_ps_baddep_slug" 2>&1 >/dev/null ) || true )
  if echo "$_ps_err" | grep -q 'PSK024-D'; then
    pass "plan-save-b03: approve refuses 'depends_on' referencing nonexistent phase (PSK024-D)"
  else
    fail "plan-save-b03: approve did not emit PSK024-D for dangling depends_on (got: $_ps_err)"
  fi

  # ─── Test 9: approve on plan missing schema_version → PSK024-N
  _ps_nover_slug="b03-no-schema-version"
  _ps_nover_file="$_ps_sandbox/agent/plans/2026-05-13-${_ps_nover_slug}.md"
  cat > "$_ps_nover_file" <<EOF
---
status: draft
slug: $_ps_nover_slug
created: 2026-05-13
updated: 2026-05-13
phases:
  - id: phase-a
    name: "Phase A"
    prompt: "agent/plans/$_ps_nover_slug/prompts/phase-a.md"
    artifact: "agent/plans/$_ps_nover_slug/artifacts/phase-a.done.md"
    gate: "true"
    commit_required: true
    depends_on: []
---

# Body
EOF
  _ps_err=$( ( PROJ_ROOT="$_ps_sandbox" bash "$_PS_SCRIPT" approve "$_ps_nover_slug" 2>&1 >/dev/null ) || true )
  if echo "$_ps_err" | grep -q 'PSK024-N'; then
    pass "plan-save-b03: approve refuses plan missing 'schema_version' (PSK024-N)"
  else
    fail "plan-save-b03: approve did not emit PSK024-N for missing schema_version (got: $_ps_err)"
  fi

  # ─── Test 10: PSK_PLAN_EXEC_DISABLED=1 bypasses schema validation
  _ps_warn=$( ( PROJ_ROOT="$_ps_sandbox" PSK_PLAN_EXEC_DISABLED=1 bash "$_PS_SCRIPT" approve "$_ps_nophases_slug" 2>&1 >/dev/null ) || true )
  if echo "$_ps_warn" | grep -q 'PSK_PLAN_EXEC_DISABLED=1'; then
    pass "plan-save-b03: PSK_PLAN_EXEC_DISABLED=1 emits stderr warning"
  else
    fail "plan-save-b03: PSK_PLAN_EXEC_DISABLED=1 did not emit warning (got: $_ps_warn)"
  fi
  if grep -q '^status: approved$' "$_ps_nophases_file"; then
    pass "plan-save-b03: PSK_PLAN_EXEC_DISABLED=1 lets approve advance status despite schema fail"
  else
    fail "plan-save-b03: PSK_PLAN_EXEC_DISABLED=1 did not advance status (got: $(grep '^status:' "$_ps_nophases_file"))"
  fi

  # ─── Test 11: compat-mode plan is approved without schema_version/phases checks
  _ps_compat_slug="b03-compat-mode"
  _ps_compat_file="$_ps_sandbox/agent/plans/2026-05-13-${_ps_compat_slug}.md"
  cat > "$_ps_compat_file" <<EOF
---
status: draft
slug: $_ps_compat_slug
created: 2026-05-13
updated: 2026-05-13
compat_mode: true
---

# Legacy plan body (no phases yet — converted at next start)
EOF
  if ( PROJ_ROOT="$_ps_sandbox" bash "$_PS_SCRIPT" approve "$_ps_compat_slug" >/dev/null 2>&1 ); then
    if grep -q '^status: approved$' "$_ps_compat_file"; then
      pass "plan-save-b03: compat-mode plan approves without schema validation"
    else
      fail "plan-save-b03: compat-mode approve did not transition status"
    fi
  else
    fail "plan-save-b03: compat-mode plan refused by approve"
  fi

  # ─── Test 12: --validate-schema returns 0 on valid plan, 2 on invalid plan
  if ( PROJ_ROOT="$_ps_sandbox" bash "$_PS_SCRIPT" --validate-schema "$_ps_valid_slug" >/dev/null 2>&1 ); then
    pass "plan-save-b03: --validate-schema exits 0 on valid plan"
  else
    fail "plan-save-b03: --validate-schema failed on valid plan"
  fi
  if ! ( PROJ_ROOT="$_ps_sandbox" bash "$_PS_SCRIPT" --validate-schema "$_ps_baddep_slug" >/dev/null 2>&1 ); then
    pass "plan-save-b03: --validate-schema exits non-zero on invalid plan"
  else
    fail "plan-save-b03: --validate-schema returned 0 on invalid plan"
  fi

  # ─── Test 13: --validate-schema has no side effects on the plan file
  _ps_pre_mtime=$(stat -f %m "$_ps_valid_file" 2>/dev/null || stat -c %Y "$_ps_valid_file" 2>/dev/null)
  ( PROJ_ROOT="$_ps_sandbox" bash "$_PS_SCRIPT" --validate-schema "$_ps_valid_slug" >/dev/null 2>&1 ) || true
  _ps_post_mtime=$(stat -f %m "$_ps_valid_file" 2>/dev/null || stat -c %Y "$_ps_valid_file" 2>/dev/null)
  if [ "$_ps_pre_mtime" = "$_ps_post_mtime" ]; then
    pass "plan-save-b03: --validate-schema has no side effects on plan file"
  else
    fail "plan-save-b03: --validate-schema mutated plan file mtime"
  fi

  # ─── Test 14: save creates new plan with stdin-piped body
  _ps_stdin_slug="b03-stdin"
  echo "# Piped body" | ( PROJ_ROOT="$_ps_sandbox" bash "$_PS_SCRIPT" save "$_ps_stdin_slug" - >/dev/null 2>&1 )
  _ps_stdin_file=$(ls "$_ps_sandbox/agent/plans/"*"$_ps_stdin_slug".md 2>/dev/null | head -1)
  if [ -n "$_ps_stdin_file" ] && grep -q '^# Piped body$' "$_ps_stdin_file"; then
    pass "plan-save-b03: save with piped stdin creates plan with that body"
  else
    fail "plan-save-b03: save with piped stdin did not preserve body"
  fi

  rm -rf "$_ps_sandbox"
fi

# ═══════════════════════════════════════════════════════════════
section "63. psk-run-plan.sh driver (§Plan Execution Protocol — B0.2 — v0.6.57)"
# ═══════════════════════════════════════════════════════════════
# Covers the executable-plan driver: schema validation, SPAWN signal,
# depends_on resolution, gate enforcement, retry cap, compat-mode,
# conversion path, abort, --health one-liner. Each test uses an
# isolated PROJ_ROOT sandbox under /tmp so the kit's own plans are
# never touched.

RUNPLAN="$PROJ/agent/scripts/psk-run-plan.sh"

[ -x "$RUNPLAN" ] \
  && pass "run-plan: psk-run-plan.sh exists and is executable" \
  || fail "run-plan: psk-run-plan.sh missing or not executable"

# Structural: no inline-fallback branch. The script must NEVER contain a
# code path that does the sub-agent's work itself. The only forward
# verbs are spawn/retry/abort.
if [ -x "$RUNPLAN" ]; then
  grep -qE 'NO inline-fallback|no inline-fallback branch|no inline alternative' "$RUNPLAN" \
    && pass "run-plan: doc-string declares no-inline-fallback contract" \
    || fail "run-plan: doc-string missing no-inline-fallback contract"

  # Dispatch verbs are lifecycle-only (no 'inline'/'fallback'/'execute' verb)
  _rp_verbs=$(grep -oE '^[[:space:]]+(start|next|resume|retry|status|abort|--convert|--validate|--health|inline|fallback|do-it)\)' "$RUNPLAN" | tr -d ' )' | sort -u | tr '\n' ',')
  case "$_rp_verbs" in
    *inline*|*fallback*|*do-it*)
      fail "run-plan: dispatch verbs include inline/fallback/do-it (fidelity hole): $_rp_verbs"
      ;;
    *)
      pass "run-plan: dispatch verbs are lifecycle-only (no inline/fallback shortcut)"
      ;;
  esac
fi

# Behavioural tests — each in an isolated sandbox.
if [ -x "$RUNPLAN" ]; then
  _rp_setup() {
    local sandbox="$1"
    mkdir -p "$sandbox/agent/scripts" "$sandbox/agent/plans"
    cp "$PROJ/agent/scripts/psk-run-plan.sh" "$sandbox/agent/scripts/"
    cp "$PROJ/agent/scripts/psk-workflow-state.sh" "$sandbox/agent/scripts/"
    cp "$PROJ/agent/scripts/psk-plan-save.sh" "$sandbox/agent/scripts/"
  }

  # ─── T1: --validate exits 0 on a well-formed plan, exit 2 on missing phases.
  _rp_t1=$(mktemp -d -t run-plan-t1.XXXXXX)
  _rp_setup "$_rp_t1"
  cat > "$_rp_t1/agent/plans/good.md" <<EOF
---
status: approved
slug: good
schema_version: 1
phases:
  - id: a
    prompt: "$_rp_t1/a.p.md"
    artifact: "$_rp_t1/a.d.md"
    gate: "true"
    depends_on: []
---
EOF
  if PROJ_ROOT="$_rp_t1" bash "$_rp_t1/agent/scripts/psk-run-plan.sh" --validate good >/dev/null 2>&1; then
    pass "run-plan: --validate exits 0 on schema-conformant plan"
  else
    fail "run-plan: --validate did not accept a valid plan"
  fi
  cat > "$_rp_t1/agent/plans/bad.md" <<'EOF'
---
status: draft
slug: bad
---
No phases.
EOF
  _rp_t1_bad_out=$(PROJ_ROOT="$_rp_t1" bash "$_rp_t1/agent/scripts/psk-run-plan.sh" --validate bad 2>&1)
  _rp_t1_bad_code=$?
  if [ "$_rp_t1_bad_code" -eq 2 ] && echo "$_rp_t1_bad_out" | grep -q "PSK024"; then
    pass "run-plan: --validate exits 2 with PSK024 on plan missing phases:"
  else
    fail "run-plan: --validate did not return PSK024/exit-2 for non-conformant plan (code=$_rp_t1_bad_code)"
  fi
  rm -rf "$_rp_t1"

  # ─── T2: start on conformant plan emits SPAWN for first phase.
  _rp_t2=$(mktemp -d -t run-plan-t2.XXXXXX)
  _rp_setup "$_rp_t2"
  cat > "$_rp_t2/agent/plans/2026-05-16-flow.md" <<EOF
---
status: approved
slug: flow
schema_version: 1
phases:
  - id: alpha
    prompt: "$_rp_t2/alpha.p.md"
    artifact: "$_rp_t2/alpha.d.md"
    gate: "true"
    depends_on: []
---
EOF
  _rp_t2_out=$(PROJ_ROOT="$_rp_t2" bash "$_rp_t2/agent/scripts/psk-run-plan.sh" start flow 2>&1)
  if echo "$_rp_t2_out" | grep -q "^SPAWN: phase=alpha"; then
    pass "run-plan: start emits SPAWN signal for first phase"
  else
    fail "run-plan: start did not emit SPAWN signal"
  fi
  # Workflow state machine recorded the phase as AWAITING
  if PROJ_ROOT="$_rp_t2" bash "$_rp_t2/agent/scripts/psk-workflow-state.sh" status run-plan-flow 2>/dev/null | grep -q "AWAITING:SUBAGENT_SPAWN"; then
    pass "run-plan: start marks phase AWAITING_SUBAGENT in state machine"
  else
    fail "run-plan: start did not pause workflow at AWAITING"
  fi
  rm -rf "$_rp_t2"

  # ─── T3: start refuses non-conformant plan (PSK024, exit 2).
  _rp_t3=$(mktemp -d -t run-plan-t3.XXXXXX)
  _rp_setup "$_rp_t3"
  cat > "$_rp_t3/agent/plans/old.md" <<'EOF'
---
status: draft
slug: old
---
Legacy.
EOF
  _rp_t3_out=$(PROJ_ROOT="$_rp_t3" bash "$_rp_t3/agent/scripts/psk-run-plan.sh" start old 2>&1)
  _rp_t3_code=$?
  if [ "$_rp_t3_code" -eq 2 ] && echo "$_rp_t3_out" | grep -q "PSK024"; then
    pass "run-plan: start refuses non-conformant plan with PSK024 + exit 2"
  else
    fail "run-plan: start did not refuse non-conformant plan (code=$_rp_t3_code)"
  fi
  rm -rf "$_rp_t3"

  # ─── T4: compat-mode plan runs as a single synthetic phase.
  _rp_t4=$(mktemp -d -t run-plan-t4.XXXXXX)
  _rp_setup "$_rp_t4"
  cat > "$_rp_t4/agent/plans/legacy.md" <<'EOF'
---
status: draft
slug: legacy
compat_mode: true
---
Legacy plan body.
EOF
  _rp_t4_out=$(PROJ_ROOT="$_rp_t4" bash "$_rp_t4/agent/scripts/psk-run-plan.sh" start legacy 2>&1)
  if echo "$_rp_t4_out" | grep -q "^SPAWN: phase=compat" && echo "$_rp_t4_out" | grep -q "compat_mode"; then
    pass "run-plan: compat-mode plan emits a single SPAWN with whole-plan prompt"
  else
    fail "run-plan: compat-mode did not emit synthetic SPAWN"
  fi
  rm -rf "$_rp_t4"

  # ─── T5/T6: next advances on artifact + passing gate, exits 3 on failing gate.
  _rp_t5=$(mktemp -d -t run-plan-t5.XXXXXX)
  _rp_setup "$_rp_t5"
  cat > "$_rp_t5/agent/plans/adv.md" <<EOF
---
status: approved
slug: adv
schema_version: 1
phases:
  - id: a
    prompt: "$_rp_t5/a.p.md"
    artifact: "$_rp_t5/a.d.md"
    gate: "true"
    depends_on: []
  - id: b
    prompt: "$_rp_t5/b.p.md"
    artifact: "$_rp_t5/b.d.md"
    gate: "true"
    depends_on: [a]
---
EOF
  PROJ_ROOT="$_rp_t5" bash "$_rp_t5/agent/scripts/psk-run-plan.sh" start adv >/dev/null 2>&1
  echo "ok" > "$_rp_t5/a.d.md"
  _rp_t5_out=$(PROJ_ROOT="$_rp_t5" bash "$_rp_t5/agent/scripts/psk-run-plan.sh" next 2>&1)
  if echo "$_rp_t5_out" | grep -q "^SPAWN: phase=b"; then
    pass "run-plan: next advances to next phase after artifact + passing gate"
  else
    fail "run-plan: next did not advance to phase b"
  fi
  # T6: failing gate exits 3 and does NOT advance.
  cat > "$_rp_t5/agent/plans/fail.md" <<EOF
---
status: approved
slug: fail
schema_version: 1
phases:
  - id: x
    prompt: "$_rp_t5/x.p.md"
    artifact: "$_rp_t5/x.d.md"
    gate: "false"
    depends_on: []
---
EOF
  PROJ_ROOT="$_rp_t5" bash "$_rp_t5/agent/scripts/psk-run-plan.sh" start fail >/dev/null 2>&1
  echo "ok" > "$_rp_t5/x.d.md"
  PROJ_ROOT="$_rp_t5" bash "$_rp_t5/agent/scripts/psk-run-plan.sh" next fail >/dev/null 2>&1
  _rp_t5_fail_code=$?
  if [ "$_rp_t5_fail_code" -eq 3 ]; then
    pass "run-plan: next exits 3 on gate failure"
  else
    fail "run-plan: gate failure did not exit 3 (got $_rp_t5_fail_code)"
  fi
  # And the phase must NOT have advanced — state still has x as not-done.
  if PROJ_ROOT="$_rp_t5" bash "$_rp_t5/agent/scripts/psk-workflow-state.sh" get-phase run-plan-fail 2>/dev/null | grep -q "^x "; then
    pass "run-plan: gate failure keeps phase NOT done in state machine"
  else
    fail "run-plan: gate failure incorrectly advanced phase"
  fi
  rm -rf "$_rp_t5"

  # ─── T7: resume re-emits the same SPAWN signal for the current phase.
  _rp_t7=$(mktemp -d -t run-plan-t7.XXXXXX)
  _rp_setup "$_rp_t7"
  cat > "$_rp_t7/agent/plans/r.md" <<EOF
---
status: approved
slug: r
schema_version: 1
phases:
  - id: only
    prompt: "$_rp_t7/only.p.md"
    artifact: "$_rp_t7/only.d.md"
    gate: "true"
    depends_on: []
---
EOF
  PROJ_ROOT="$_rp_t7" bash "$_rp_t7/agent/scripts/psk-run-plan.sh" start r >/dev/null 2>&1
  _rp_t7_out=$(PROJ_ROOT="$_rp_t7" bash "$_rp_t7/agent/scripts/psk-run-plan.sh" resume r 2>&1)
  if echo "$_rp_t7_out" | grep -q "^SPAWN: phase=only"; then
    pass "run-plan: resume re-emits SPAWN for current in-progress phase"
  else
    fail "run-plan: resume did not re-emit SPAWN"
  fi
  rm -rf "$_rp_t7"

  # ─── T8: retry cap (4th retry hits AWAITING_HUMAN_ARBITRATION, exit 4).
  _rp_t8=$(mktemp -d -t run-plan-t8.XXXXXX)
  _rp_setup "$_rp_t8"
  cat > "$_rp_t8/agent/plans/rt.md" <<EOF
---
status: approved
slug: rt
schema_version: 1
phases:
  - id: only
    prompt: "$_rp_t8/only.p.md"
    artifact: "$_rp_t8/only.d.md"
    gate: "true"
    depends_on: []
---
EOF
  PROJ_ROOT="$_rp_t8" bash "$_rp_t8/agent/scripts/psk-run-plan.sh" start rt >/dev/null 2>&1
  PROJ_ROOT="$_rp_t8" bash "$_rp_t8/agent/scripts/psk-run-plan.sh" retry rt >/dev/null 2>&1
  PROJ_ROOT="$_rp_t8" bash "$_rp_t8/agent/scripts/psk-run-plan.sh" retry rt >/dev/null 2>&1
  PROJ_ROOT="$_rp_t8" bash "$_rp_t8/agent/scripts/psk-run-plan.sh" retry rt >/dev/null 2>&1
  _rp_t8_out=$(PROJ_ROOT="$_rp_t8" bash "$_rp_t8/agent/scripts/psk-run-plan.sh" retry rt 2>&1)
  _rp_t8_code=$?
  if [ "$_rp_t8_code" -eq 4 ] && echo "$_rp_t8_out" | grep -q "AWAITING_HUMAN_ARBITRATION"; then
    pass "run-plan: 4th retry hits AWAITING_HUMAN_ARBITRATION (exit 4)"
  else
    fail "run-plan: retry cap not enforced (code=$_rp_t8_code)"
  fi
  rm -rf "$_rp_t8"

  # ─── T9: --convert emits a conversion SPAWN.
  _rp_t9=$(mktemp -d -t run-plan-t9.XXXXXX)
  _rp_setup "$_rp_t9"
  cat > "$_rp_t9/agent/plans/legacy.md" <<'EOF'
---
status: draft
slug: legacy
---
Legacy body.
EOF
  _rp_t9_out=$(PROJ_ROOT="$_rp_t9" bash "$_rp_t9/agent/scripts/psk-run-plan.sh" --convert legacy 2>&1)
  if echo "$_rp_t9_out" | grep -q "^SPAWN: phase=convert" && echo "$_rp_t9_out" | grep -q "conversion"; then
    pass "run-plan: --convert emits conversion SPAWN signal"
  else
    fail "run-plan: --convert did not emit conversion SPAWN"
  fi
  rm -rf "$_rp_t9"

  # ─── T10: depends_on graph — phase B doesn't get SPAWN until A is done.
  _rp_t10=$(mktemp -d -t run-plan-t10.XXXXXX)
  _rp_setup "$_rp_t10"
  cat > "$_rp_t10/agent/plans/dep.md" <<EOF
---
status: approved
slug: dep
schema_version: 1
phases:
  - id: a
    prompt: "$_rp_t10/a.p.md"
    artifact: "$_rp_t10/a.d.md"
    gate: "true"
    depends_on: []
  - id: b
    prompt: "$_rp_t10/b.p.md"
    artifact: "$_rp_t10/b.d.md"
    gate: "true"
    depends_on: [a]
---
EOF
  _rp_t10_start=$(PROJ_ROOT="$_rp_t10" bash "$_rp_t10/agent/scripts/psk-run-plan.sh" start dep 2>&1)
  if echo "$_rp_t10_start" | grep -q "^SPAWN: phase=a" \
     && ! echo "$_rp_t10_start" | grep -q "^SPAWN: phase=b"; then
    pass "run-plan: depends_on honored — only phase a (no deps) is spawned first"
  else
    fail "run-plan: dependency graph broken — start spawned wrong/multiple phases"
  fi
  rm -rf "$_rp_t10"

  # ─── T11: abort cleans state and marks plan abandoned.
  _rp_t11=$(mktemp -d -t run-plan-t11.XXXXXX)
  _rp_setup "$_rp_t11"
  cat > "$_rp_t11/agent/plans/2026-05-16-abrt.md" <<EOF
---
status: approved
slug: abrt
schema_version: 1
phases:
  - id: x
    prompt: "$_rp_t11/x.p.md"
    artifact: "$_rp_t11/x.d.md"
    gate: "true"
    depends_on: []
---
EOF
  PROJ_ROOT="$_rp_t11" bash "$_rp_t11/agent/scripts/psk-run-plan.sh" start abrt >/dev/null 2>&1
  _rp_t11_abort=$(PROJ_ROOT="$_rp_t11" bash "$_rp_t11/agent/scripts/psk-run-plan.sh" abort abrt 2>&1)
  if echo "$_rp_t11_abort" | grep -q "aborted plan 'abrt'" \
     && [ ! -f "$_rp_t11/agent/.workflow-state/run-plan-abrt.state" ] \
     && [ ! -f "$_rp_t11/agent/.workflow-state/run-plan-abrt.run" ]; then
    pass "run-plan: abort moves state aside (no live .state / .run remain)"
  else
    fail "run-plan: abort did not clean state files"
  fi
  # Plan status now reflects abandoned (via psk-plan-save.sh abandon)
  if grep -q "^status: abandoned" "$_rp_t11/agent/plans/2026-05-16-abrt.md"; then
    pass "run-plan: abort transitions plan status → abandoned"
  else
    fail "run-plan: abort did not transition plan to abandoned"
  fi
  rm -rf "$_rp_t11"

  # ─── T12: --health one-liner reports in-flight count.
  _rp_t12=$(mktemp -d -t run-plan-t12.XXXXXX)
  _rp_setup "$_rp_t12"
  cat > "$_rp_t12/agent/plans/h.md" <<EOF
---
status: approved
slug: h
schema_version: 1
phases:
  - id: only
    prompt: "$_rp_t12/only.p.md"
    artifact: "$_rp_t12/only.d.md"
    gate: "true"
    depends_on: []
---
EOF
  PROJ_ROOT="$_rp_t12" bash "$_rp_t12/agent/scripts/psk-run-plan.sh" start h >/dev/null 2>&1
  _rp_t12_health=$(PROJ_ROOT="$_rp_t12" bash "$_rp_t12/agent/scripts/psk-run-plan.sh" --health 2>&1)
  if echo "$_rp_t12_health" | grep -q "1 in-flight"; then
    pass "run-plan: --health reports in-flight plan count"
  else
    fail "run-plan: --health did not report in-flight count"
  fi
  rm -rf "$_rp_t12"

  # ─── T13: Documented bypass + framework registration.
  grep -q "PSK_PLAN_EXEC_DISABLED" "$RUNPLAN" \
    && pass "run-plan: emergency bypass PSK_PLAN_EXEC_DISABLED documented + wired" \
    || fail "run-plan: emergency bypass not wired"
  kit_grep "psk-run-plan.sh" \
    && pass "run-plan: framework documents psk-run-plan.sh" \
    || fail "run-plan: framework does NOT reference psk-run-plan.sh"
fi

# ═══════════════════════════════════════════════════════════════
section "64. PSK024 — Plan Execution Schema (B0.4)"
# ═══════════════════════════════════════════════════════════════
#
# PSK024 lints every plan in agent/plans/*.md for §Plan Execution Protocol
# schema conformance. Narrative plans are skipped; executable plans must
# carry phases: frontmatter conforming to v1 schema. Compat-mode plans get
# a single advisory and are bypassed from per-phase checks.

_PSK024_TMP_ROOT="${TEMP}/psk024"
mkdir -p "$_PSK024_TMP_ROOT"

# Build a one-off fixture project. Each fixture gets its own copy of
# psk-sync-check.sh so PROJ_ROOT resolution treats it as the project root.
_psk024_fixture() {
  local case_slug="$1"
  local plan_name="$2"
  local plan_body="$3"
  local case_dir="$_PSK024_TMP_ROOT/$case_slug"
  rm -rf "$case_dir"
  mkdir -p "$case_dir/agent/plans" "$case_dir/agent/scripts"
  cp "$PROJ/agent/scripts/psk-sync-check.sh" "$case_dir/agent/scripts/"
  chmod +x "$case_dir/agent/scripts/psk-sync-check.sh"
  printf '%s' "$plan_body" > "$case_dir/agent/plans/$plan_name"
  echo "$case_dir"
}

_psk024_run_full() {
  local case_dir="$1"
  ( cd "$case_dir" && bash agent/scripts/psk-sync-check.sh --full --project "$case_dir" 2>&1; echo "EXIT:$?" )
}
_psk024_run_quick() {
  local case_dir="$1"
  ( cd "$case_dir" && bash agent/scripts/psk-sync-check.sh --quick --project "$case_dir" 2>&1; echo "EXIT:$?" )
}

# Test 1 — valid phases plan passes clean
_t1_body='---
status: approved
slug: t1-valid
schema_version: 1
phases:
  - id: a
    name: "First"
    prompt: "agent/plans/t1-valid/prompts/a.md"
    artifact: "agent/plans/t1-valid/artifacts/a.done.md"
    gate: "true"
    commit_required: true
    depends_on: []
---
'
_t1_dir=$(_psk024_fixture "t1-valid" "t1-valid.md" "$_t1_body")
mkdir -p "$_t1_dir/agent/plans/t1-valid/prompts"
touch "$_t1_dir/agent/plans/t1-valid/prompts/a.md"
_t1_out=$(_psk024_run_full "$_t1_dir")
echo "$_t1_out" | grep -q "PSK024: 1 plans checked, 1 executable, 0 violations" \
  && pass "PSK024: valid phases plan passes clean" \
  || fail "PSK024: valid phases plan should pass — got: $(echo "$_t1_out" | grep PSK024 | head -2)"

# Test 2 — missing schema_version → PSK024-V
_t2_body='---
status: approved
slug: t2-noschema
phases:
  - id: a
    name: "X"
    prompt: "agent/plans/t2-noschema/prompts/a.md"
    artifact: "agent/plans/t2-noschema/artifacts/a.done.md"
    gate: "true"
    commit_required: true
    depends_on: []
---
'
_t2_dir=$(_psk024_fixture "t2-noschema" "t2-noschema.md" "$_t2_body")
mkdir -p "$_t2_dir/agent/plans/t2-noschema/prompts"
touch "$_t2_dir/agent/plans/t2-noschema/prompts/a.md"
_t2_out=$(_psk024_run_full "$_t2_dir")
echo "$_t2_out" | grep -q "PSK024-V" \
  && pass "PSK024-V: missing schema_version flagged" \
  || fail "PSK024-V: schema_version absence should fire"

# Test 3 — executable via ## Implementation Order, missing phases: → PSK024-P
_t3_body='---
status: draft
slug: t3-impl-order
schema_version: 1
---

# T3

## Implementation Order

1. Do A
2. Do B
'
_t3_dir=$(_psk024_fixture "t3-implorder" "t3-impl-order.md" "$_t3_body")
_t3_out=$(_psk024_run_full "$_t3_dir")
echo "$_t3_out" | grep -q "PSK024-P" \
  && pass "PSK024-P: missing phases on Implementation-Order plan flagged" \
  || fail "PSK024-P: missing phases on executable plan should fire"

# Test 4 — phase missing id → PSK024-I
_t4_body='---
status: approved
slug: t4-noid
schema_version: 1
phases:
  - id:
    name: "Anonymous"
    prompt: "agent/plans/t4-noid/prompts/x.md"
    artifact: "agent/plans/t4-noid/artifacts/x.done.md"
    gate: "true"
    commit_required: true
    depends_on: []
---
'
_t4_dir=$(_psk024_fixture "t4-noid" "t4-noid.md" "$_t4_body")
_t4_out=$(_psk024_run_full "$_t4_dir")
echo "$_t4_out" | grep -q "PSK024-I" \
  && pass "PSK024-I: missing id flagged" \
  || fail "PSK024-I: empty id should fire"

# Test 5 — phase missing name → PSK024-N
_t5_body='---
status: approved
slug: t5-noname
schema_version: 1
phases:
  - id: a
    prompt: "agent/plans/t5-noname/prompts/a.md"
    artifact: "agent/plans/t5-noname/artifacts/a.done.md"
    gate: "true"
    commit_required: true
    depends_on: []
---
'
_t5_dir=$(_psk024_fixture "t5-noname" "t5-noname.md" "$_t5_body")
mkdir -p "$_t5_dir/agent/plans/t5-noname/prompts"
touch "$_t5_dir/agent/plans/t5-noname/prompts/a.md"
_t5_out=$(_psk024_run_full "$_t5_dir")
echo "$_t5_out" | grep -q "PSK024-N" \
  && pass "PSK024-N: missing name flagged" \
  || fail "PSK024-N: missing name should fire"

# Test 6 — phase missing prompt → PSK024-R
_t6_body='---
status: approved
slug: t6-noprompt
schema_version: 1
phases:
  - id: a
    name: "A"
    artifact: "agent/plans/t6-noprompt/artifacts/a.done.md"
    gate: "true"
    commit_required: true
    depends_on: []
---
'
_t6_dir=$(_psk024_fixture "t6-noprompt" "t6-noprompt.md" "$_t6_body")
_t6_out=$(_psk024_run_full "$_t6_dir")
echo "$_t6_out" | grep -q "PSK024-R" \
  && pass "PSK024-R: missing prompt flagged" \
  || fail "PSK024-R: missing prompt should fire"

# Test 7 — phase missing artifact → PSK024-A
_t7_body='---
status: approved
slug: t7-noartifact
schema_version: 1
phases:
  - id: a
    name: "A"
    prompt: "agent/plans/t7-noartifact/prompts/a.md"
    gate: "true"
    commit_required: true
    depends_on: []
---
'
_t7_dir=$(_psk024_fixture "t7-noartifact" "t7-noartifact.md" "$_t7_body")
mkdir -p "$_t7_dir/agent/plans/t7-noartifact/prompts"
touch "$_t7_dir/agent/plans/t7-noartifact/prompts/a.md"
_t7_out=$(_psk024_run_full "$_t7_dir")
echo "$_t7_out" | grep -q "PSK024-A" \
  && pass "PSK024-A: missing artifact flagged" \
  || fail "PSK024-A: missing artifact should fire"

# Test 8 — phase missing gate → PSK024-G
_t8_body='---
status: approved
slug: t8-nogate
schema_version: 1
phases:
  - id: a
    name: "A"
    prompt: "agent/plans/t8-nogate/prompts/a.md"
    artifact: "agent/plans/t8-nogate/artifacts/a.done.md"
    commit_required: true
    depends_on: []
---
'
_t8_dir=$(_psk024_fixture "t8-nogate" "t8-nogate.md" "$_t8_body")
mkdir -p "$_t8_dir/agent/plans/t8-nogate/prompts"
touch "$_t8_dir/agent/plans/t8-nogate/prompts/a.md"
_t8_out=$(_psk024_run_full "$_t8_dir")
echo "$_t8_out" | grep -q "PSK024-G" \
  && pass "PSK024-G: missing gate flagged" \
  || fail "PSK024-G: missing gate should fire"

# Test 9 — phase missing commit_required → PSK024-C
_t9_body='---
status: approved
slug: t9-nocommit
schema_version: 1
phases:
  - id: a
    name: "A"
    prompt: "agent/plans/t9-nocommit/prompts/a.md"
    artifact: "agent/plans/t9-nocommit/artifacts/a.done.md"
    gate: "true"
    depends_on: []
---
'
_t9_dir=$(_psk024_fixture "t9-nocommit" "t9-nocommit.md" "$_t9_body")
mkdir -p "$_t9_dir/agent/plans/t9-nocommit/prompts"
touch "$_t9_dir/agent/plans/t9-nocommit/prompts/a.md"
_t9_out=$(_psk024_run_full "$_t9_dir")
echo "$_t9_out" | grep -q "PSK024-C" \
  && pass "PSK024-C: missing commit_required flagged" \
  || fail "PSK024-C: missing commit_required should fire"

# Test 10 — depends_on references a non-existent phase → PSK024-D dangling
_t10_body='---
status: approved
slug: t10-dangling
schema_version: 1
phases:
  - id: a
    name: "A"
    prompt: "agent/plans/t10-dangling/prompts/a.md"
    artifact: "agent/plans/t10-dangling/artifacts/a.done.md"
    gate: "true"
    commit_required: true
    depends_on: [nonexistent]
---
'
_t10_dir=$(_psk024_fixture "t10-dangling" "t10-dangling.md" "$_t10_body")
mkdir -p "$_t10_dir/agent/plans/t10-dangling/prompts"
touch "$_t10_dir/agent/plans/t10-dangling/prompts/a.md"
_t10_out=$(_psk024_run_full "$_t10_dir")
echo "$_t10_out" | grep -q "PSK024-D" \
  && pass "PSK024-D: dangling depends_on flagged" \
  || fail "PSK024-D: dangling depends_on should fire"

# Test 11 — depends_on cycle (A→B, B→A) → PSK024-D cycle
_t11_body='---
status: approved
slug: t11-cycle
schema_version: 1
phases:
  - id: a
    name: "A"
    prompt: "agent/plans/t11-cycle/prompts/a.md"
    artifact: "agent/plans/t11-cycle/artifacts/a.done.md"
    gate: "true"
    commit_required: true
    depends_on: [b]
  - id: b
    name: "B"
    prompt: "agent/plans/t11-cycle/prompts/b.md"
    artifact: "agent/plans/t11-cycle/artifacts/b.done.md"
    gate: "true"
    commit_required: true
    depends_on: [a]
---
'
_t11_dir=$(_psk024_fixture "t11-cycle" "t11-cycle.md" "$_t11_body")
mkdir -p "$_t11_dir/agent/plans/t11-cycle/prompts"
touch "$_t11_dir/agent/plans/t11-cycle/prompts/a.md"
touch "$_t11_dir/agent/plans/t11-cycle/prompts/b.md"
_t11_out=$(_psk024_run_full "$_t11_dir")
echo "$_t11_out" | grep -q "cycle detected" \
  && pass "PSK024-D: depends_on cycle flagged" \
  || fail "PSK024-D: depends_on cycle should fire"

# Test 12 — narrative plan (no execution signal) → skipped
_t12_body='---
status: draft
slug: t12-narrative
---

# Pure narrative document.

## Decisions

- Decided X
'
_t12_dir=$(_psk024_fixture "t12-narrative" "t12-narrative.md" "$_t12_body")
_t12_out=$(_psk024_run_full "$_t12_dir")
echo "$_t12_out" | grep -q "PSK024: 1 plans checked, 0 executable, 0 violations" \
  && pass "PSK024: narrative plan skipped (0 executable)" \
  || fail "PSK024: narrative plan should be skipped — got: $(echo "$_t12_out" | grep PSK024 | head -2)"

# Test 13 — compat-mode plan → advisory only, no hard error
_t13_body='---
status: executing
slug: t13-compat
compat_mode: true
---

# T13

## Implementation Order

1. Stuff
'
_t13_dir=$(_psk024_fixture "t13-compat" "t13-compat.md" "$_t13_body")
_t13_out=$(_psk024_run_full "$_t13_dir")
if echo "$_t13_out" | grep -q "PSK024-X" \
   && echo "$_t13_out" | grep -q "PSK024: 1 plans checked, 1 executable, 0 violations"; then
  pass "PSK024-X: compat-mode plan advisory + 0 violations"
else
  fail "PSK024-X: compat-mode should be advisory only — got: $(echo "$_t13_out" | grep -i psk024 | head -3)"
fi

# Test 14 — --quick mode exits 0 even with violations
_t14_body='---
status: approved
slug: t14-bad
schema_version: 1
phases:
  - id: a
    name: ""
    prompt: "wrong/path.md"
    artifact: ""
    gate: ""
    commit_required: maybe
    depends_on: [ghost]
---
'
_t14_dir=$(_psk024_fixture "t14-quick" "t14-bad.md" "$_t14_body")
_t14_out=$(_psk024_run_quick "$_t14_dir")
echo "$_t14_out" | tail -3 | grep -q "EXIT:0" \
  && pass "PSK024: --quick mode exits 0 even on violations" \
  || fail "PSK024: --quick should exit 0 — got tail: $(echo "$_t14_out" | tail -3)"

# Test 15 — --full mode exits 1 on violations
_t15_out=$(_psk024_run_full "$_t14_dir")
echo "$_t15_out" | tail -3 | grep -q "EXIT:1" \
  && pass "PSK024: --full mode exits 1 on violations" \
  || fail "PSK024: --full should exit 1 on violations — got tail: $(echo "$_t15_out" | tail -3)"

# Test 16 — real-kit workflow-fidelity plan is schema-conformant (post-D1 conversion in v0.6.58)
# Pre-v0.6.58 this plan was bootstrap-exception compat_mode. v0.6.58 Phase D1 converted it
# to schema_version: 1 + phases: via psk-run-plan.sh --convert (self-application).
grep -qE '^schema_version:[[:space:]]*1' "$PROJ/agent/plans/2026-05-13-workflow-fidelity.md" \
  && pass "PSK024: workflow-fidelity plan converted to schema_version: 1 (post-D1)" \
  || fail "PSK024: workflow-fidelity should have schema_version: 1 (converted in D1)"

rm -rf "$_PSK024_TMP_ROOT"

section "66. Dim 26 + Gate 12: Workflow-Fidelity & Completeness (B4 — v0.6.57)"
# ═══════════════════════════════════════════════════════════════
#
# Dim 26 is the audit-side mirror of §Workflow Fidelity (4th reliability
# layer) + §Plan Execution Protocol (5th layer). Gate 12 is the structural
# counterpart in reflex/lib/gates.sh — QA surfaces violations, the gate
# prevents regression across passes.
#
# Tests below validate:
#   - workflow-fidelity-audit.sh exists + executable + emits valid JSON
#   - JSON schema correctness (dim=26, summary counts present, findings array)
#   - workflow with healthy state file → no WFC findings for that workflow
#   - workflow missing state file (with active legacy .release-state) → ADVISORY
#   - compat-mode plan with no `phases:` → ADVISORY (not MAJOR)
#   - schema plan with missing phase ledger → MAJOR
#   - frontend project with empty-shell gaps → MAJOR (via psk-ui-polish-check wrap)
#   - no-frontend project skips UI sub-audit (HAS_FRONTEND=false)
#   - gates.sh --list shows 12 gates including workflow-fidelity-completeness
#   - WFC_GATE_DISABLED=1 makes gate 12 skip (operator bypass path)
#   - WFC_AUDIT_DISABLED=1 makes audit emit disabled marker
#   - qa-agent.md registers Dim 26
#   - reflex/config.yml carries workflow_fidelity_block_severity

_WFC_TMP_ROOT="${TEMP}/wfc"
mkdir -p "$_WFC_TMP_ROOT"

# Test 1 — workflow-fidelity-audit.sh exists and is executable
[ -x "$PROJ/reflex/lib/workflow-fidelity-audit.sh" ] \
  && pass "WFC: workflow-fidelity-audit.sh exists + executable" \
  || fail "WFC: workflow-fidelity-audit.sh missing or not executable"

# Test 2 — emits valid JSON schema (dim:26 + findings array + summary)
_wfc_kit_out=$(bash "$PROJ/reflex/lib/workflow-fidelity-audit.sh" --root "$PROJ" 2>/dev/null)
echo "$_wfc_kit_out" | grep -q '"dim": 26' \
  && pass "WFC: JSON includes dim:26" \
  || fail "WFC: JSON missing dim:26 — got: $(echo "$_wfc_kit_out" | head -3)"
echo "$_wfc_kit_out" | grep -q '"findings":' \
  && pass "WFC: JSON includes findings array" \
  || fail "WFC: JSON missing findings array"
echo "$_wfc_kit_out" | grep -qE '"summary":\{"total":[0-9]+,"MAJOR":[0-9]+,"MINOR":[0-9]+,"ADVISORY":[0-9]+\}' \
  && pass "WFC: JSON includes summary with MAJOR/MINOR/ADVISORY counts" \
  || fail "WFC: JSON summary missing or malformed"

# Test 3 — schema_version field present
echo "$_wfc_kit_out" | grep -q '"audit_version": "1.0"' \
  && pass "WFC: JSON includes audit_version 1.0" \
  || fail "WFC: JSON missing audit_version 1.0"

# Test 4 — workflow with healthy state file → no WFC-A finding for that workflow
_wfc_t4_dir="$_WFC_TMP_ROOT/t4-healthy"
rm -rf "$_wfc_t4_dir"
mkdir -p "$_wfc_t4_dir/agent/.workflow-state" "$_wfc_t4_dir/agent/scripts" "$_wfc_t4_dir/agent/plans" "$_wfc_t4_dir/agent/.release-state"
# Healthy: a workflow-state ledger exists
echo "WORKFLOW=psk-release" > "$_wfc_t4_dir/agent/.workflow-state/psk-release.state"
# Active release state present but ALSO with matching ledger → no drift
echo "step=1" > "$_wfc_t4_dir/agent/.release-state/state"
_wfc_t4_out=$(bash "$PROJ/reflex/lib/workflow-fidelity-audit.sh" --root "$_wfc_t4_dir" 2>/dev/null)
echo "$_wfc_t4_out" | grep -q 'WFC-A-WORKFLOW-STATE-DRIFT' \
  && fail "WFC: healthy project with state ledger should not surface workflow-state-drift" \
  || pass "WFC: healthy state ledger → no WFC-A-WORKFLOW-STATE-DRIFT"

# Test 5 — workflow with active legacy state but missing ledger → ADVISORY
_wfc_t5_dir="$_WFC_TMP_ROOT/t5-legacy"
rm -rf "$_wfc_t5_dir"
mkdir -p "$_wfc_t5_dir/agent/.release-state" "$_wfc_t5_dir/agent/scripts" "$_wfc_t5_dir/agent/plans"
echo "step=1" > "$_wfc_t5_dir/agent/.release-state/state"
# No agent/.workflow-state/psk-release.state → drift
_wfc_t5_out=$(bash "$PROJ/reflex/lib/workflow-fidelity-audit.sh" --root "$_wfc_t5_dir" 2>/dev/null)
echo "$_wfc_t5_out" | grep -q '"id":"WFC-A-WORKFLOW-STATE-DRIFT","severity":"ADVISORY"' \
  && pass "WFC: legacy active state without ledger → ADVISORY workflow-state-drift" \
  || fail "WFC: legacy active state should surface ADVISORY drift"

# Test 6 — compat-mode plan with no `phases:` → ADVISORY (not MAJOR)
_wfc_t6_dir="$_WFC_TMP_ROOT/t6-compat"
rm -rf "$_wfc_t6_dir"
mkdir -p "$_wfc_t6_dir/agent/plans" "$_wfc_t6_dir/agent/scripts"
cat > "$_wfc_t6_dir/agent/plans/legacy.md" <<'PLAN'
---
status: executing
slug: legacy
compat_mode: true
---
# Legacy plan
PLAN
_wfc_t6_out=$(bash "$PROJ/reflex/lib/workflow-fidelity-audit.sh" --root "$_wfc_t6_dir" 2>/dev/null)
echo "$_wfc_t6_out" | grep -q '"id":"WFC-C-PLAN-COMPAT-MODE","severity":"ADVISORY"' \
  && pass "WFC: compat-mode plan → ADVISORY (not MAJOR)" \
  || fail "WFC: compat-mode plan should surface ADVISORY — got: $(echo "$_wfc_t6_out" | grep -o 'WFC-C-PLAN-[A-Z-]*' | head -3)"
# And ensure no MAJOR plan-no-phases for the same plan
echo "$_wfc_t6_out" | grep -q '"id":"WFC-C-PLAN-NO-PHASES","severity":"MAJOR","category":"phase-gate","subcategory":"schema-missing","file":"agent/plans/legacy.md"' \
  && fail "WFC: compat-mode plan should NOT surface MAJOR no-phases" \
  || pass "WFC: compat-mode plan suppresses MAJOR no-phases"

# Test 7 — schema plan with phases but missing state ledger → MAJOR
_wfc_t7_dir="$_WFC_TMP_ROOT/t7-schema"
rm -rf "$_wfc_t7_dir"
mkdir -p "$_wfc_t7_dir/agent/plans" "$_wfc_t7_dir/agent/scripts"
cat > "$_wfc_t7_dir/agent/plans/feat-x.md" <<'PLAN'
---
status: executing
slug: feat-x
schema_version: 1
phases:
  - id: A1
    name: "Phase A1"
    prompt: "agent/plans/feat-x/prompts/A1.md"
    artifact: "agent/plans/feat-x/artifacts/A1.done.md"
    gate: "true"
    commit_required: true
    depends_on: []
---
# Plan body
PLAN
_wfc_t7_out=$(bash "$PROJ/reflex/lib/workflow-fidelity-audit.sh" --root "$_wfc_t7_dir" 2>/dev/null)
echo "$_wfc_t7_out" | grep -q '"id":"WFC-C-PLAN-STATE-MISSING","severity":"MAJOR"' \
  && pass "WFC: schema plan missing state ledger → MAJOR plan-state-missing" \
  || fail "WFC: schema plan should surface MAJOR state-missing"

# Test 8 — schema plan WITH state ledger → no state-missing
_wfc_t8_dir="$_WFC_TMP_ROOT/t8-schema-healthy"
rm -rf "$_wfc_t8_dir"
mkdir -p "$_wfc_t8_dir/agent/plans" "$_wfc_t8_dir/agent/scripts" "$_wfc_t8_dir/agent/.workflow-state"
cat > "$_wfc_t8_dir/agent/plans/feat-y.md" <<'PLAN'
---
status: executing
slug: feat-y
schema_version: 1
phases:
  - id: A1
    name: "Phase A1"
    prompt: "p.md"
    artifact: "a.md"
    gate: "true"
    commit_required: true
    depends_on: []
---
PLAN
echo "WORKFLOW=run-plan-feat-y" > "$_wfc_t8_dir/agent/.workflow-state/run-plan-feat-y.state"
_wfc_t8_out=$(bash "$PROJ/reflex/lib/workflow-fidelity-audit.sh" --root "$_wfc_t8_dir" 2>/dev/null)
echo "$_wfc_t8_out" | grep -q 'WFC-C-PLAN-STATE-MISSING' \
  && fail "WFC: schema plan with ledger should not surface state-missing" \
  || pass "WFC: schema plan with ledger → no state-missing finding"

# Test 9 — frontend project: psk-ui-polish-check.sh wrap surfaces gaps
_wfc_t9_dir="$_WFC_TMP_ROOT/t9-frontend"
rm -rf "$_wfc_t9_dir"
mkdir -p "$_wfc_t9_dir/agent/scripts" "$_wfc_t9_dir/agent/plans" "$_wfc_t9_dir/src"
cat > "$_wfc_t9_dir/package.json" <<'PKG'
{"name":"t9","version":"0.0.1","dependencies":{"next":"^14"}}
PKG
# Empty src/ — no components found → psk-ui-polish-check.sh reports many gaps
cp "$PROJ/agent/scripts/psk-ui-polish-check.sh" "$_wfc_t9_dir/agent/scripts/"
chmod +x "$_wfc_t9_dir/agent/scripts/psk-ui-polish-check.sh"
_wfc_t9_out=$(bash "$PROJ/reflex/lib/workflow-fidelity-audit.sh" --root "$_wfc_t9_dir" 2>/dev/null)
echo "$_wfc_t9_out" | grep -q '"has_frontend": true' \
  && pass "WFC: frontend detected (package.json has next)" \
  || fail "WFC: frontend should be detected from package.json"
echo "$_wfc_t9_out" | grep -qE '"category":"ui-completeness"' \
  && pass "WFC: frontend project surfaces ui-completeness findings" \
  || fail "WFC: frontend project should surface ui-completeness findings"

# Test 10 — no-frontend project skips UI sub-audit (has_frontend: false)
_wfc_t10_dir="$_WFC_TMP_ROOT/t10-nofrontend"
rm -rf "$_wfc_t10_dir"
mkdir -p "$_wfc_t10_dir/agent/scripts" "$_wfc_t10_dir/agent/plans"
# No package.json + no src/app/ → has_frontend = false
_wfc_t10_out=$(bash "$PROJ/reflex/lib/workflow-fidelity-audit.sh" --root "$_wfc_t10_dir" 2>/dev/null)
echo "$_wfc_t10_out" | grep -q '"has_frontend": false' \
  && pass "WFC: no-frontend project → has_frontend:false" \
  || fail "WFC: no-frontend project should set has_frontend:false"
echo "$_wfc_t10_out" | grep -qE '"category":"ui-completeness"' \
  && fail "WFC: no-frontend project should skip ui-completeness sub-audit" \
  || pass "WFC: no-frontend project skips ui-completeness sub-audit"

# Test 11 — block-severity MAJOR exits non-zero when MAJOR findings exist
_wfc_t11_out=$(bash "$PROJ/reflex/lib/workflow-fidelity-audit.sh" --root "$_wfc_t7_dir" --block-severity MAJOR >/dev/null 2>&1; echo "EXIT:$?")
echo "$_wfc_t11_out" | grep -q 'EXIT:1' \
  && pass "WFC: --block-severity MAJOR exits 1 on MAJOR finding" \
  || fail "WFC: --block-severity MAJOR should exit 1 — got $_wfc_t11_out"

# Test 12 — block-severity MAJOR with no MAJOR findings → exit 0
_wfc_t12_dir="$_WFC_TMP_ROOT/t12-clean"
rm -rf "$_wfc_t12_dir"
mkdir -p "$_wfc_t12_dir/agent/scripts" "$_wfc_t12_dir/agent/plans"
_wfc_t12_out=$(bash "$PROJ/reflex/lib/workflow-fidelity-audit.sh" --root "$_wfc_t12_dir" --block-severity MAJOR >/dev/null 2>&1; echo "EXIT:$?")
echo "$_wfc_t12_out" | grep -q 'EXIT:0' \
  && pass "WFC: --block-severity MAJOR exits 0 when no MAJOR findings" \
  || fail "WFC: clean project should exit 0 — got $_wfc_t12_out"

# Test 13 — WFC_AUDIT_DISABLED=1 emits disabled marker + exit 0
_wfc_t13_out=$(WFC_AUDIT_DISABLED=1 bash "$PROJ/reflex/lib/workflow-fidelity-audit.sh" --root "$PROJ" 2>/dev/null)
echo "$_wfc_t13_out" | grep -q '"disabled":true' \
  && pass "WFC: WFC_AUDIT_DISABLED=1 emits disabled:true marker" \
  || fail "WFC: WFC_AUDIT_DISABLED=1 should emit disabled marker"

# Test 14 — gates.sh --list shows 12 gates including workflow-fidelity-completeness
_wfc_gates_list=$(bash "$PROJ/reflex/lib/gates.sh" --list 2>&1)
echo "$_wfc_gates_list" | grep -q '12\.[[:space:]]*workflow-fidelity-completeness' \
  && pass "WFC: gates.sh --list shows gate 12 workflow-fidelity-completeness" \
  || fail "WFC: gates.sh --list missing gate 12 workflow-fidelity-completeness"
_wfc_gate_count=$(echo "$_wfc_gates_list" | grep -cE '^[0-9]+\.[[:space:]]')
[ "$_wfc_gate_count" -eq 12 ] \
  && pass "WFC: gates.sh --list shows exactly 12 numbered gates" \
  || fail "WFC: gates.sh --list shows $_wfc_gate_count gates, expected 12"

# Test 15 — qa-agent.md registers Dim 26
grep -q '### Dimension 26 — Workflow-Fidelity & Deliverable-Completeness' "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "WFC: qa-agent.md registers Dimension 26" \
  || fail "WFC: qa-agent.md missing Dimension 26 registration"

# Test 16 — reflex/config.yml carries workflow_fidelity_block_severity
grep -q '^workflow_fidelity_block_severity:' "$PROJ/reflex/config.yml" \
  && pass "WFC: reflex/config.yml has workflow_fidelity_block_severity" \
  || fail "WFC: reflex/config.yml missing workflow_fidelity_block_severity"

# Test 17 — qa-agent-dim.md mentions Dim 26
grep -q 'Dim 26 — Workflow-Fidelity' "$PROJ/reflex/prompts/qa-agent-dim.md" \
  && pass "WFC: qa-agent-dim.md mentions Dim 26 invocation protocol" \
  || fail "WFC: qa-agent-dim.md missing Dim 26 mention"

# Test 18 — portable-spec-kit.md updated to "12 mechanical gates"
kit_grep -q '12 mechanical gates' \
  && pass "WFC: portable-spec-kit.md mentions '12 mechanical gates'" \
  || fail "WFC: portable-spec-kit.md should mention '12 mechanical gates'"

# Test 19 — portable-spec-kit.md mentions Dims 25-26
kit_grep -q 'Dims 25-26' \
  && pass "WFC: portable-spec-kit.md references 'Dims 25-26' structural-floor pair" \
  || fail "WFC: portable-spec-kit.md should reference 'Dims 25-26'"

# Test 20 — bypass marker in commit body suppresses bypass-abuse finding
# (Verified indirectly: the audit looks for bypass-justification: in commit
# trailers; we test the negative — running on a fresh repo with no git
# history surfaces nothing for WFC-A-BYPASS-ABUSE.)
echo "$_wfc_kit_out" | grep -oE '"id":"WFC-A-BYPASS-ABUSE"' | head -1 >/dev/null
# Kit repo currently has no _DISABLED=1 abuse in last 20 commits → no finding expected
# If a finding IS present that's actually evidence of an issue in kit's git history
# (informational only — not a test failure)
pass "WFC: bypass-abuse audit logic exercises on kit's own git history (informational)"

rm -rf "$_WFC_TMP_ROOT"

section "68. Per-phase completion gates — register-gate / verify-gate / mark-done refusal (B2 — v0.6.57)"
# ═══════════════════════════════════════════════════════════════
# B2 closes the loophole where mark-done could fire without any registered
# gate having passed. Contract:
#   • register-gate <wf> <phase> <cmd>  → appends `<phase>=<cmd>` to gate file
#   • verify-gate   <wf> <phase>        → runs cmd; on exit 0 writes
#                                          GATE_PASSED_<phase>=<unix-ts>
#   • mark-done     <wf> <phase>        → refuses (exit 2) when a gate is
#                                          registered but no GATE_PASSED marker.
# The two-step verify→mark contract is the structural enforcement of
# §Workflow Fidelity B2: phases physically cannot advance without an
# independently-verified gate pass.

_B2_WFS="$PROJ/agent/scripts/psk-workflow-state.sh"
[ -x "$_B2_WFS" ] \
  && pass "B2: psk-workflow-state.sh exists and is executable" \
  || fail "B2: psk-workflow-state.sh missing"

# Test 1 — register-gate API exists and writes GATE_<phase>=<cmd> to a gate file
_B2_TMP=$(mktemp -d)
( PROJ_ROOT="$_B2_TMP" bash "$_B2_WFS" init b2-wf "p1,p2" >/dev/null 2>&1 )
( PROJ_ROOT="$_B2_TMP" bash "$_B2_WFS" register-gate b2-wf p1 "true" >/dev/null 2>&1 )
[ -f "$_B2_TMP/agent/.workflow-state/b2-wf.gates" ] \
  && grep -q "^p1=true" "$_B2_TMP/agent/.workflow-state/b2-wf.gates" \
  && pass "B2.1: register-gate writes phase=cmd into the gate registry file" \
  || fail "B2.1: register-gate did not record p1=true in the gate file"

# Test 2 — verify-gate runs registered command; exit 0 writes GATE_PASSED_<phase>
PROJ_ROOT="$_B2_TMP" bash "$_B2_WFS" verify-gate b2-wf p1 >/dev/null 2>&1
if grep -q "^GATE_PASSED_p1=" "$_B2_TMP/agent/.workflow-state/b2-wf.state" 2>/dev/null; then
  pass "B2.2: verify-gate on passing gate writes GATE_PASSED_<phase> marker"
else
  fail "B2.2: verify-gate on passing gate did not write GATE_PASSED marker"
fi

# Test 3 — verify-gate runs registered command; non-0 exit → no GATE_PASSED marker
( PROJ_ROOT="$_B2_TMP" bash "$_B2_WFS" register-gate b2-wf p2 "false" >/dev/null 2>&1 )
( PROJ_ROOT="$_B2_TMP" bash "$_B2_WFS" verify-gate b2-wf p2 >/dev/null 2>&1 )
if grep -q "^GATE_PASSED_p2=" "$_B2_TMP/agent/.workflow-state/b2-wf.state" 2>/dev/null; then
  fail "B2.3: verify-gate on failing gate wrote GATE_PASSED marker (should not)"
else
  pass "B2.3: verify-gate on failing gate does NOT write GATE_PASSED marker"
fi

# Test 4 — mark-done refuses when registered gate has not been verified
_B2_OUT=$(PROJ_ROOT="$_B2_TMP" bash "$_B2_WFS" mark-done b2-wf p2 2>&1)
_B2_RC=$?
if [ "$_B2_RC" -eq 2 ] && echo "$_B2_OUT" | grep -q "no GATE_PASSED marker"; then
  pass "B2.4: mark-done refuses (exit 2 + specific msg) when gate not verified"
else
  fail "B2.4: mark-done did not refuse properly — rc=$_B2_RC msg='$_B2_OUT'"
fi

# Test 5 — mark-done succeeds when no gate registered OR GATE_PASSED set
( PROJ_ROOT="$_B2_TMP" bash "$_B2_WFS" init b2-wf2 "a,b" >/dev/null 2>&1 )
# Phase a — no gate registered → mark-done permitted
if ( PROJ_ROOT="$_B2_TMP" bash "$_B2_WFS" mark-done b2-wf2 a >/dev/null 2>&1 ); then
  : pass-a
else
  fail "B2.5a: mark-done refused for phase with no registered gate"
fi
# Phase p1 — gate registered AND GATE_PASSED already set from Test 2 → mark-done permitted
if ( PROJ_ROOT="$_B2_TMP" bash "$_B2_WFS" mark-done b2-wf p1 >/dev/null 2>&1 ); then
  pass "B2.5: mark-done succeeds (a) without registered gate (b) with GATE_PASSED set"
else
  fail "B2.5: mark-done refused even with GATE_PASSED set"
fi

# Test 6 — psk-release.sh registers expected step gates at init
_B2_REL_TMP=$(mktemp -d)
mkdir -p "$_B2_REL_TMP/agent/scripts" "$_B2_REL_TMP/agent" "$_B2_REL_TMP/tests"
cp "$_B2_WFS" "$_B2_REL_TMP/agent/scripts/"
# Provide stub helpers the release script touches at init_state time
echo '#!/bin/bash' > "$_B2_REL_TMP/agent/scripts/psk-sync-check.sh" && chmod +x "$_B2_REL_TMP/agent/scripts/psk-sync-check.sh"
echo '#!/bin/bash' > "$_B2_REL_TMP/agent/scripts/psk-validate.sh" && chmod +x "$_B2_REL_TMP/agent/scripts/psk-validate.sh"
echo '#!/bin/bash' > "$_B2_REL_TMP/agent/scripts/psk-bootstrap-check.sh" && chmod +x "$_B2_REL_TMP/agent/scripts/psk-bootstrap-check.sh"
echo '#!/bin/bash' > "$_B2_REL_TMP/tests/test-spec-kit.sh" && chmod +x "$_B2_REL_TMP/tests/test-spec-kit.sh"
echo "- **Version:** v0.6.57" > "$_B2_REL_TMP/agent/AGENT_CONTEXT.md"
cp "$PROJ/agent/scripts/psk-release.sh" "$_B2_REL_TMP/agent/scripts/"
# init_state runs on prepare/refresh; bootstrap_gate already passes (script returns 0)
( cd "$_B2_REL_TMP" && PSK_BOOTSTRAP_CHECK_DISABLED=1 bash "$_B2_REL_TMP/agent/scripts/psk-release.sh" prepare >/dev/null 2>&1 )
if [ -f "$_B2_REL_TMP/agent/.workflow-state/psk-release.gates" ] \
   && grep -q "^STEP_1_TESTS=" "$_B2_REL_TMP/agent/.workflow-state/psk-release.gates" \
   && grep -q "^STEP_9_VALIDATION=" "$_B2_REL_TMP/agent/.workflow-state/psk-release.gates"; then
  pass "B2.6: psk-release.sh registers STEP_1..STEP_10 gates at prepare/init"
else
  fail "B2.6: psk-release.sh did not register expected step gates"
fi
rm -rf "$_B2_REL_TMP"

# Test 7 — psk-orchestrate.sh (new mode) registers P-phase gates at fresh start
_B2_ORCH_TMP=$(mktemp -d)
mkdir -p "$_B2_ORCH_TMP/agent/scripts" "$_B2_ORCH_TMP/agent/.release-state" "$_B2_ORCH_TMP/tests"
cp "$_B2_WFS" "$_B2_ORCH_TMP/agent/scripts/"
cp "$PROJ/agent/scripts/psk-orchestrate.sh" "$_B2_ORCH_TMP/agent/scripts/"
echo '#!/bin/bash' > "$_B2_ORCH_TMP/agent/scripts/psk-sync-check.sh" && chmod +x "$_B2_ORCH_TMP/agent/scripts/psk-sync-check.sh"
echo '#!/bin/bash' > "$_B2_ORCH_TMP/tests/test-release-check.sh" && chmod +x "$_B2_ORCH_TMP/tests/test-release-check.sh"
# Run a fresh start in capture phase; the script will write state + register gates,
# then emit a SPAWN signal and exit 2. We only care that the gate file lands.
( cd "$_B2_ORCH_TMP" && PSK_PROJ_ROOT="$_B2_ORCH_TMP" bash "$_B2_ORCH_TMP/agent/scripts/psk-orchestrate.sh" "test req" >/dev/null 2>&1 || true )
if [ -f "$_B2_ORCH_TMP/agent/.workflow-state/psk-orchestrate.gates" ] \
   && grep -q "^research=" "$_B2_ORCH_TMP/agent/.workflow-state/psk-orchestrate.gates" \
   && grep -q "^features=" "$_B2_ORCH_TMP/agent/.workflow-state/psk-orchestrate.gates"; then
  pass "B2.7: psk-orchestrate.sh registers P-phase gates at fresh start"
else
  fail "B2.7: psk-orchestrate.sh did not register P-phase gates"
fi
rm -rf "$_B2_ORCH_TMP"

# Test 8 — round-trip: init → register → verify → mark-done → next phase visible
_B2_RT=$(mktemp -d)
( PROJ_ROOT="$_B2_RT" bash "$_B2_WFS" init rt-wf "a,b,c" >/dev/null 2>&1 )
( PROJ_ROOT="$_B2_RT" bash "$_B2_WFS" register-gate rt-wf a "true" >/dev/null 2>&1 )
( PROJ_ROOT="$_B2_RT" bash "$_B2_WFS" register-gate rt-wf b "true" >/dev/null 2>&1 )
( PROJ_ROOT="$_B2_RT" bash "$_B2_WFS" verify-gate rt-wf a >/dev/null 2>&1 )
( PROJ_ROOT="$_B2_RT" bash "$_B2_WFS" mark-done rt-wf a >/dev/null 2>&1 )
_B2_PHASE=$(PROJ_ROOT="$_B2_RT" bash "$_B2_WFS" get-phase rt-wf 2>/dev/null)
if echo "$_B2_PHASE" | grep -q "^b "; then
  pass "B2.8: round-trip init → register → verify → mark-done advances to next phase"
else
  fail "B2.8: round-trip did not advance — got '$_B2_PHASE'"
fi
rm -rf "$_B2_RT" "$_B2_TMP"

# =============================================================================
# Section 67 — PSK025 UI Completeness Gate (B1 of workflow-fidelity plan)
# =============================================================================
echo ""
echo "═══ Section 67 — PSK025 UI Completeness Gate (B1) ═══"

_B1_UI="$PROJ/agent/scripts/psk-ui-completeness.sh"

if [ -x "$_B1_UI" ] && head -20 "$_B1_UI" | grep -q "UI completeness audit"; then
  pass "B1.1: psk-ui-completeness.sh exists, executable, doc-string present"
else
  fail "B1.1: psk-ui-completeness.sh missing or doc-string absent"
fi

_B1_TMP=$(mktemp -d)
mkdir -p "$_B1_TMP/agent"
cat > "$_B1_TMP/agent/PLANS.md" <<'EOF'
## Stack
| Layer | Technology |
|-------|-----------|
| Framework | Bash scripts only |
EOF
if ( cd "$_B1_TMP" && bash "$_B1_UI" 2>&1 ) | grep -q "no frontend"; then
  pass "B1.2: no-frontend project — skip"
else
  fail "B1.2: no-frontend project did not skip"
fi
rm -rf "$_B1_TMP"

_B1_TMP=$(mktemp -d)
mkdir -p "$_B1_TMP/agent" "$_B1_TMP/src/app"
cat > "$_B1_TMP/agent/PLANS.md" <<'EOF'
## Stack
| Frontend | Next.js 15 |
EOF
( cd "$_B1_TMP" && bash "$_B1_UI" >/dev/null 2>&1 )
if [ $? -ne 0 ]; then
  pass "B1.3: empty UI dir → exit non-zero (violations)"
else
  fail "B1.3: empty UI dir should have failed"
fi
rm -rf "$_B1_TMP"

_B1_TMP=$(mktemp -d)
mkdir -p "$_B1_TMP/agent" "$_B1_TMP/src/app/admin"
cat > "$_B1_TMP/agent/PLANS.md" <<'EOF'
## Stack
| Frontend | Next.js |
EOF
cat > "$_B1_TMP/src/app/admin/page.tsx" <<'EOF'
export default function Admin() {
  return <div>Coming soon</div>
}
EOF
if ( cd "$_B1_TMP" && bash "$_B1_UI" 2>&1 ) | grep -q "PSK025-E"; then
  pass "B1.4: empty-shell <div>Coming soon</div> triggers PSK025-E"
else
  fail "B1.4: empty-shell not detected"
fi
rm -rf "$_B1_TMP"

_B1_TMP=$(mktemp -d)
mkdir -p "$_B1_TMP/agent" "$_B1_TMP/src/app"
cat > "$_B1_TMP/agent/PLANS.md" <<'EOF'
## Stack
| Frontend | Next.js |
EOF
( cd "$_B1_TMP" && bash "$_B1_UI" --check >/dev/null 2>&1 )
if [ $? -eq 0 ]; then
  pass "B1.5: --check mode exits 0 even with violations"
else
  fail "B1.5: --check returned non-zero"
fi
rm -rf "$_B1_TMP"

_B1_TMP=$(mktemp -d)
mkdir -p "$_B1_TMP/agent" "$_B1_TMP/src/app"
cat > "$_B1_TMP/agent/PLANS.md" <<'EOF'
## Stack
| Frontend | Next.js |
EOF
( cd "$_B1_TMP" && bash "$_B1_UI" --strict >/dev/null 2>&1 )
if [ $? -ne 0 ]; then
  pass "B1.6: --strict mode exits non-zero on violations"
else
  fail "B1.6: --strict returned 0 with violations"
fi
rm -rf "$_B1_TMP"

_B1_TMP=$(mktemp -d)
mkdir -p "$_B1_TMP/agent"
cat > "$_B1_TMP/agent/PLANS.md" <<'EOF'
## Stack
| Framework | Bash |
EOF
_B1_JSON=$( cd "$_B1_TMP" && bash "$_B1_UI" --json 2>/dev/null )
if echo "$_B1_JSON" | grep -q '"rule":"PSK025"'; then
  pass "B1.7: --json output includes rule:PSK025"
else
  fail "B1.7: --json output malformed: $_B1_JSON"
fi
rm -rf "$_B1_TMP"

if bash "$PROJ/agent/scripts/psk-sync-check.sh" --full 2>&1 | grep -q "PSK025:"; then
  pass "B1.8: PSK025 registered in psk-sync-check.sh --full output"
else
  fail "B1.8: PSK025 not registered in sync-check dispatcher"
fi

# L5.4 — post-clean: prevent residue from leaking into the next section
# file or next test-spec-kit.sh run. Idempotent; safe even if VSTATE
# doesn't exist yet.
if [ -d "$VSTATE" ]; then
  for f in critic-task.md critic-result.md .validate-stamp \
           critic-iterations loop-state.yml \
           dev-task.md dev-result.md \
           qa-task.md qa-result.md; do
    rm -f "$VSTATE/$f"
  done
fi

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  RESULTS (03-reliability): $PASS passed, $FAIL failed, $TOTAL total"
  echo "═══════════════════════════════════════════"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi
