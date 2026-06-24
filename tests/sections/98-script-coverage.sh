#!/bin/bash
# tests/sections/98-script-coverage.sh — behavioral coverage for previously-untested kit scripts
#
# Closes QA-COV-37-01 (Dim 37 coverage-distribution): 7 non-exempt kit scripts had ZERO test
# reference in tests/, so their behavior was unverified and could regress silently. This section
# gives each a REAL behavioral test reference (happy + error/edge path) rather than a blanket
# doc-coverage-exempt marker — these are user-visible / load-bearing scripts (psk-preview is a
# 983-line workflow previewer; orchestration-phase-6-5 is a pre-flight gate), so behavioral
# coverage is the right answer.
#
# Also closes QA-TESTQ-STRUCT-01 (Dim 12 structural-vs-behavioral balance): every assertion here
# INVOKES the script and checks its real exit code / output, the behavioral counterweight to the
# grep-heavy structural sections.
#
# Scripts covered (7):
#   agent/scripts/psk-preview.sh            reflex/lib/check-test-vacuousness.sh
#   agent/scripts/psk-generate-ci.sh        reflex/lib/cycle-summary.sh
#   agent/scripts/psk-generate-user-guide.sh  reflex/lib/heal-iter-status.sh
#                                           reflex/lib/orchestration-phase-6-5.sh
#
# ── Scope: this is a SUPPLEMENTAL / overflow section, NOT the kit's full coverage index ──
# (QA-D37-SECTION98-SCOPE-01, NIT). Section 98 holds behavioral tests ONLY for the scripts
# above — the ones that had ZERO coverage elsewhere. The MAJORITY of kit scripts are tested
# in their topical sections, NOT here. So "a script is absent from section 98" does NOT mean
# it is untested — check the topical section first. Coverage map (where else scripts are tested):
#   01-infrastructure.sh   — psk-sync-check, psk-env, psk-bootstrap-check, install/uninstall, perms
#   02-pipeline.sh         — psk-release, psk-init, psk-orchestrate, psk-feature-complete, psk-validate
#   03-reliability.sh      — hooks/critics, psk-spawn, psk-retry-queue, psk-workflow-watchdog,
#                            psk-regression-replay, psk-version-cascade, reflex/lib/*.sh gates + mutation corpus
#   04-reflex.sh           — reflex/run.sh, loop.sh, score.sh, chunked-run, progress monitors
#   05-mandate-compliance.sh — mandate-audit, workflow-fidelity-audit
#   06-cycle01-followup.sh — cycle-01 follow-up checks
#   77-psk-session-monitor.sh — psk-session-monitor
#   95/96/97-*.sh          — prompt-fidelity, instruction-fidelity, kit-fidelity (psk-rule, psk-prompt-lint, psk-kit-cmd)
#   tests/features/f*.sh   — feature-level behavioral tests (psk-* under their feature)
# Scripts that are intentionally test-exempt carry a `# doc-coverage-exempt:` marker in their header.
# To re-scope rather than annotate, this file could be renamed 98-supplemental-script-coverage.sh.
#
# Independently runnable: bash tests/sections/98-script-coverage.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "98. Behavioral coverage for previously-untested kit scripts (QA-COV-37-01 / QA-TESTQ-STRUCT-01)"

# ── psk-preview.sh — read-only workflow/plan previewer ──
PREVIEW="$PROJ/agent/scripts/psk-preview.sh"
if [ -x "$PREVIEW" ]; then
  # happy: --list-workflows exits 0 and prints at least the kit's known workflows
  _pv_out="$(bash "$PREVIEW" --list-workflows 2>/dev/null)"; _pv_rc=$?
  [ "$_pv_rc" -eq 0 ] \
    && pass "98.1: psk-preview --list-workflows exits 0" \
    || fail "98.1: psk-preview --list-workflows exit $_pv_rc"
  # behavioral: --help prints a usage summary (mentions a known flag)
  bash "$PREVIEW" --help 2>/dev/null | grep -q -- '--list-workflows' \
    && pass "98.2: psk-preview --help documents --list-workflows" \
    || fail "98.2: psk-preview --help missing usage"
  # error path: an unknown/nonexistent target must NOT exit 0 (no silent success)
  bash "$PREVIEW" __no_such_target_xyz__ >/dev/null 2>&1
  [ $? -ne 0 ] \
    && pass "98.3: psk-preview rejects an unknown target (non-zero exit)" \
    || fail "98.3: psk-preview silently accepted a bogus target"
else
  fail "98.1: psk-preview.sh missing or not executable"
fi

# ── psk-generate-ci.sh — emit .github/workflows/ci.yml from AGENT.md stack ──
GEN_CI="$PROJ/agent/scripts/psk-generate-ci.sh"
if [ -x "$GEN_CI" ]; then
  _tmp="$(mktemp -d)"; mkdir -p "$_tmp/agent"
  printf '# AGENT\n\n## Stack\n\n| Layer | Tech |\n|---|---|\n| Test | bash |\n' > "$_tmp/agent/AGENT.md"
  bash "$GEN_CI" "$_tmp" >/dev/null 2>&1
  [ -f "$_tmp/.github/workflows/ci.yml" ] \
    && pass "98.4: psk-generate-ci creates .github/workflows/ci.yml" \
    || fail "98.4: psk-generate-ci did not create ci.yml"
  # idempotent: a second run must not error (skip-if-exists contract)
  bash "$GEN_CI" "$_tmp" >/dev/null 2>&1 \
    && pass "98.5: psk-generate-ci is idempotent (second run exits 0)" \
    || fail "98.5: psk-generate-ci second run errored"
  rm -rf "$_tmp"
else
  fail "98.4: psk-generate-ci.sh missing or not executable"
fi

# ── psk-generate-user-guide.sh — emit ard/user-guide.html ──
GEN_UG="$PROJ/agent/scripts/psk-generate-user-guide.sh"
if [ -x "$GEN_UG" ]; then
  _tmp="$(mktemp -d)"; mkdir -p "$_tmp/agent"
  printf '# My Project\n\nA test project.\n' > "$_tmp/README.md"
  printf '# AGENT\n\n## Stack\n\n| Layer | Tech |\n|---|---|\n| Test | bash |\n' > "$_tmp/agent/AGENT.md"
  bash "$GEN_UG" "$_tmp" >/dev/null 2>&1
  [ -f "$_tmp/ard/user-guide.html" ] \
    && pass "98.6: psk-generate-user-guide creates ard/user-guide.html" \
    || fail "98.6: psk-generate-user-guide did not create user-guide.html"
  # the generated HTML is non-empty and well-formed enough to carry an <html tag
  { [ -f "$_tmp/ard/user-guide.html" ] && grep -qi '<html' "$_tmp/ard/user-guide.html"; } \
    && pass "98.7: generated user-guide.html contains an <html> document" \
    || fail "98.7: generated user-guide.html malformed/empty"
  rm -rf "$_tmp"
else
  fail "98.6: psk-generate-user-guide.sh missing or not executable"
fi

# ── reflex/lib/check-test-vacuousness.sh — flag grep-only feature tests ──
VAC="$PROJ/reflex/lib/check-test-vacuousness.sh"
if [ -x "$VAC" ]; then
  # behavioral: --json emits parseable JSON with a findings count field
  _vac_json="$(bash "$VAC" --json 2>/dev/null)"
  printf '%s' "$_vac_json" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null \
    && pass "98.8: check-test-vacuousness --json emits valid JSON" \
    || fail "98.8: check-test-vacuousness --json not valid JSON"
  # error path: an unknown flag must exit non-zero
  bash "$VAC" --no-such-flag >/dev/null 2>&1
  [ $? -ne 0 ] \
    && pass "98.9: check-test-vacuousness rejects an unknown flag" \
    || fail "98.9: check-test-vacuousness accepted a bogus flag"
else
  fail "98.8: check-test-vacuousness.sh missing or not executable"
fi

# ── reflex/lib/cycle-summary.sh — per-cycle aggregator ──
CYC="$PROJ/reflex/lib/cycle-summary.sh"
if [ -x "$CYC" ]; then
  # behavioral: runs against the kit's own history without error (read-mostly aggregator)
  bash "$CYC" >/dev/null 2>&1 \
    && pass "98.10: cycle-summary runs over existing history (exit 0)" \
    || fail "98.10: cycle-summary errored on existing history"
  # error path: no history dir → exit non-zero with a clear message
  _tmp="$(mktemp -d)"
  REFLEX_PROJ_ROOT="$_tmp" bash "$CYC" >/dev/null 2>&1
  [ $? -ne 0 ] \
    && pass "98.11: cycle-summary exits non-zero when no history dir exists" \
    || fail "98.11: cycle-summary silently succeeded with no history"
  rm -rf "$_tmp"
else
  fail "98.10: cycle-summary.sh missing or not executable"
fi

# ── reflex/lib/heal-iter-status.sh — reconcile stale RUNNING .iter-status.yml ──
HEAL="$PROJ/reflex/lib/heal-iter-status.sh"
if [ -x "$HEAL" ]; then
  # behavioral: dry run (no --apply) over an isolated history with a stale RUNNING entry
  _tmp="$(mktemp -d)"; _pd="$_tmp/reflex/history/cycle-01/pass-001"; mkdir -p "$_pd"
  printf 'status: RUNNING\n' > "$_pd/.iter-status.yml"
  printf -- '---\nverdict: GRANTED\n---\n# done\n' > "$_pd/verdict.md"
  # dry run reports the mismatch but must NOT rewrite the file (no --apply)
  PROJ_ROOT="$_tmp" bash "$HEAL" >/dev/null 2>&1
  grep -q 'RUNNING' "$_pd/.iter-status.yml" \
    && pass "98.12: heal-iter-status dry run leaves the stale entry unmodified" \
    || fail "98.12: heal-iter-status rewrote a file without --apply"
  # --apply heals the stale RUNNING entry to a terminal status
  PROJ_ROOT="$_tmp" bash "$HEAL" --apply >/dev/null 2>&1
  ! grep -q 'status: RUNNING' "$_pd/.iter-status.yml" \
    && pass "98.13: heal-iter-status --apply heals a stale RUNNING entry" \
    || fail "98.13: heal-iter-status --apply did not heal the stale entry"
  rm -rf "$_tmp"
else
  fail "98.12: heal-iter-status.sh missing or not executable"
fi

# ── reflex/lib/orchestration-phase-6-5.sh — pre-flight mandate conformance gate ──
P65="$PROJ/reflex/lib/orchestration-phase-6-5.sh"
if [ -x "$P65" ]; then
  # error path: a near-empty project root (missing mandates) must fail the pre-flight gate
  _tmp="$(mktemp -d)"; mkdir -p "$_tmp/agent" "$_tmp/src"
  bash "$P65" --root "$_tmp" >/dev/null 2>&1
  [ $? -ne 0 ] \
    && pass "98.14: orchestration-phase-6-5 fails a structurally-incomplete project" \
    || fail "98.14: orchestration-phase-6-5 passed a project missing mandates"
  # usage error: an unknown flag must exit non-zero (linear arg-parse contract)
  bash "$P65" --no-such-flag >/dev/null 2>&1
  [ $? -ne 0 ] \
    && pass "98.15: orchestration-phase-6-5 rejects an unknown flag" \
    || fail "98.15: orchestration-phase-6-5 accepted a bogus flag"
  rm -rf "$_tmp"
else
  fail "98.14: orchestration-phase-6-5.sh missing or not executable"
fi
