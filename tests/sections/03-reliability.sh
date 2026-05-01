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

# Behavior 1: no critic-result, no stamp → exit 2 AWAITING_CRITIC
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


if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  RESULTS (03-reliability): $PASS passed, $FAIL failed, $TOTAL total"
  echo "═══════════════════════════════════════════"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi
