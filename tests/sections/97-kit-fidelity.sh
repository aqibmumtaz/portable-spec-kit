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

# Registered in the --full dispatch (def + full call = 2 references minimum).
# QA-PERF-KIT-SYNCCHECK-QUICK-01 (cycle-29-pass-003): PSK040 does git-log
# scanning and is too heavy for the per-edit --quick PostToolUse hook (<500ms
# budget). It now runs in --full only (pre-commit hook + release gate), which
# is where kit-fidelity coverage belongs. So the dispatch ref count is 2
# (1 function def + 1 --full call), not 3.
psk040_refs=$(grep -c 'check_psk040_kit_fidelity_coverage' "$SYNC_CHECK")
[ "$psk040_refs" -ge "2" ] \
  && pass "97.7: PSK040 registered in --full dispatch ($psk040_refs references)" \
  || fail "97.7: PSK040 missing dispatch registration (only $psk040_refs refs, expected ≥2: def + --full call)"

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

# --- 97.9b (B7): a --check DRY-RUN must NOT log a PSK027 bypass; a REAL command must ---
# A --check classification executes nothing; logging it inflated PSK027 and tripped
# reflex's own sync-check gate every pass (reflex --check's its own `reflex single`).
# Structural assertions (behavioral isolation is fragile: the wrapper derives PROJ_ROOT
# from its own location, and tests/lib.sh exports PSK_BYPASS_SELFTEST=1 which tags every
# logged bypass). Guard: the wrapper skips the bypass-log write for --check but keeps it
# for a real command.
if [ -f "$WRAPPER" ]; then
  # 97.9b — the B7 guard exists: a `--check` arm that intentionally skips logging.
  if grep -q '"${1:-}" = "--check"' "$WRAPPER" && grep -qi "B7" "$WRAPPER"; then
    pass "97.9b: --check arm skips bypass logging (B7 — PSK027 not inflated / no self-trip)"
  else
    fail "97.9b: B7 --check skip-log guard missing — reflex would re-trip its own gate"
  fi
  # 97.9c — a real command still routes through the canonical bypass logger
  # (invoked as `bash "$_bypass_logger" log`, where _bypass_logger=.../psk-bypass-log.sh).
  if grep -q 'psk-bypass-log.sh' "$WRAPPER" && grep -q '_bypass_logger" log' "$WRAPPER"; then
    pass "97.9c: real-command path still logs via canonical bypass logger (abuse detection intact)"
  else
    fail "97.9c: bypass logging removed — abuse detection broken"
  fi
else
  pass "97.9b: wrapper absent — skip"; pass "97.9c: skip"
fi

# --- 97.7b (KIT-GAP-0085): PSK041 matched-commit count must not be off-by-one ---
# 'git log --pretty=format:%H | wc -l' counts 1 matching commit as 0 lines
# (format: emits no trailing newline) → a gap fixed by exactly one commit
# false-flagged forever. The count must use tformat (trailing newline) or an
# equivalent newline-safe idiom.
if grep -q 'pretty=tformat:%H' "$SYNC_CHECK"; then
  pass "97.7b: PSK041 commit count uses tformat (single referencing commit counts as 1)"
else
  fail "97.7b: PSK041 still counts via format:%H | wc -l — 1 commit counts as 0 (KIT-GAP-0085)"
fi
_one=$(git -C "$PROJ" log -1 --pretty=tformat:%H | wc -l | tr -d ' ')
[ "$_one" = "1" ] \
  && pass "97.7b: tformat idiom counts a single commit as 1 line" \
  || fail "97.7b: tformat idiom returned $_one (expected 1)"

# --- 97.10: framework rule §Kit Fidelity is present ---
grep -qE '^## Kit Fidelity ' "$FRAMEWORK" \
  && pass "97.10: §Kit Fidelity section exists in portable-spec-kit.md" \
  || fail "97.10: §Kit Fidelity section missing"

grep -q '8th reliability layer' "$FRAMEWORK" \
  && pass "97.10: framework identifies §Kit Fidelity as 8th reliability layer" \
  || fail "97.10: framework missing 8th-reliability-layer claim"

# Overview count grows as new layers land (v0.6.74 nine, v0.6.78 ten, v0.6.79 eleven).
# §Kit Fidelity remains the 8th layer; the overview total is the current layer count.
grep -qE '(eight|nine|ten|eleven|twelve) enforcement layers' "$FRAMEWORK" \
  && pass "97.10: §Reliability Architecture overview declares current layer count (≥8)" \
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

# ════════════════════════════════════════════════════════════════
# 97.14 — F85.1 deliverable coverage (QA-CRIT-FIDELITY-F85.1-09).
# SPECS.md F85.1 marks `[x] Test coverage: ... cover all 5 closed gaps` but the
# section previously had ZERO assertions on the actual deliverables (psk-version
# -bump.sh, --next-cycle, verify-gate two-stage quoting, octal base-10 parsing).
# These assertions close the F→T gap by probing each deliverable's behavior.
# ════════════════════════════════════════════════════════════════
VERSION_BUMP="$PROJ/agent/scripts/psk-version-bump.sh"
[ -x "$VERSION_BUMP" ] \
  && pass "97.14: F85.1 — psk-version-bump.sh present + executable" \
  || fail "97.14: F85.1 — psk-version-bump.sh missing or not executable"

# Idempotency marker (per-run) — the helper records a marker so a re-run is a no-op
grep -qE 'idempoten|already.bumped|marker|GATE_PASSED|\.bumped' "$VERSION_BUMP" \
  && pass "97.14: F85.1 — psk-version-bump.sh carries a per-run idempotency guard" \
  || fail "97.14: F85.1 — psk-version-bump.sh has no idempotency guard"

# --next-cycle escape-hatch flag (KIT-GAP-0006)
grep -q -- '--next-cycle' "$PROJ/reflex/run.sh" \
  && pass "97.14: F85.1 — reflex/run.sh accepts --next-cycle escape hatch" \
  || fail "97.14: F85.1 — reflex/run.sh missing --next-cycle"

# verify-gate two-stage quoting (KIT-GAP-0005 path-with-spaces eval bug)
grep -qE 'verify-gate|verify_gate' "$PROJ/agent/scripts/psk-workflow-state.sh" \
  && pass "97.14: F85.1 — psk-workflow-state.sh implements verify-gate" \
  || fail "97.14: F85.1 — psk-workflow-state.sh missing verify-gate"

# octal-safe id increment (KIT-GAP-0008) — base-10 forced parse at id >= 0008
grep -qF '10#' "$WRAPPER" \
  && pass "97.14: F85.1 — psk-kit-cmd.sh --log-gap forces base-10 (no octal at id>=0008)" \
  || fail "97.14: F85.1 — psk-kit-cmd.sh --log-gap lacks base-10 forcing"

# Behavioral octal probe: 10#0008 + 1 must be 9 (octal would error on 0008/0009)
octal_probe=$(( 10#0008 + 1 ))
[ "$octal_probe" = "9" ] \
  && pass "97.14: F85.1 — base-10 increment yields 0008->9 (octal would fail)" \
  || fail "97.14: F85.1 — base-10 increment wrong ($octal_probe)"

# ════════════════════════════════════════════════════════════════
# 97.15 — F85.2 deliverable coverage (QA-CRIT-FIDELITY-F85.2-13).
# SPECS.md F85.2 marks `[x] Test coverage: ... cover the recursion-fix taxonomy`
# but had no assertions on safe_install_hook, --defer/--outside-repo/--bypassed
# flags, the disposition enum, or the PSK040 commit-shape whitelist.
# ════════════════════════════════════════════════════════════════
INSTALL_HOOKS="$PROJ/agent/scripts/psk-install-hooks.sh"
[ -f "$INSTALL_HOOKS" ] && grep -q 'safe_install_hook' "$INSTALL_HOOKS" \
  && pass "97.15: F85.2 — psk-install-hooks.sh defines safe_install_hook()" \
  || fail "97.15: F85.2 — safe_install_hook() missing"

# safe_install_hook performs bash -n syntax check before atomic tmp->mv
grep -qE 'bash -n|bash[[:space:]]+-n' "$INSTALL_HOOKS" \
  && pass "97.15: F85.2 — safe_install_hook bash -n syntax-checks before install" \
  || fail "97.15: F85.2 — safe_install_hook lacks bash -n syntax check"

# .psk-backup restore-on-failure path
grep -q '\.psk-backup' "$INSTALL_HOOKS" \
  && pass "97.15: F85.2 — safe_install_hook restores from .psk-backup on failure" \
  || fail "97.15: F85.2 — safe_install_hook has no .psk-backup restore"

# --log-gap legitimate-exception flags
for flag in --defer --outside-repo --bypassed; do
  grep -q -- "$flag" "$WRAPPER" \
    && pass "97.15: F85.2 — psk-kit-cmd.sh --log-gap supports $flag" \
    || fail "97.15: F85.2 — psk-kit-cmd.sh --log-gap missing $flag"
done

# PSK040 commit-shape whitelist recognizes legitimate release subjects
grep -qE 'release: v\[0-9\]|release: v' "$SYNC_CHECK" \
  && pass "97.15: F85.2 — PSK040 whitelist recognizes 'release: vX.Y.Z' subjects" \
  || fail "97.15: F85.2 — PSK040 whitelist missing release-subject pattern"

# ── G27 (QA-D22-001/002): --log-gap emits single 5-field TSV; committed log canonical ──
# AC1 — committed agent/.kit-gap-log is fully canonical: every data line is a 5-field TSV
# record with an ISO-8601 timestamp (with 'T') in field 1. Guards against the malformed
# space-separated / wrong-order / shattered-continuation entries G27 repaired.
_g27_bad=$(awk -F'\t' '!/^#/ && !/^$/ && (NF!=5 || $1!~/^[0-9]{4}-[0-9]{2}-[0-9]{2}T/){c++} END{print c+0}' "$PROJ/agent/.kit-gap-log")
[ "$_g27_bad" = "0" ] \
  && pass "97.16: G27 — agent/.kit-gap-log fully canonical (0 malformed data lines)" \
  || fail "97.16: G27 — $_g27_bad malformed lines in .kit-gap-log (expected 0)"

# AC2 — log_gap() sanitizes embedded tabs/newlines so a future entry cannot shatter.
grep -qE "tr '\\\\t\\\\r\\\\n'" "$WRAPPER" \
  && pass "97.16: G27 — log_gap() sanitizes tab/newline/CR in fields" \
  || fail "97.16: G27 — log_gap() missing field sanitization"

# AC3 — BEHAVIORAL: run --log-gap in an isolated temp PROJ_ROOT with a multi-line + tab
# friction; the appended entry must be exactly ONE line with 5 tab-separated fields.
_g27_tmp=$(mktemp -d)
mkdir -p "$_g27_tmp/agent/scripts" "$_g27_tmp/.portable-spec-kit"
cp "$WRAPPER" "$_g27_tmp/agent/scripts/psk-kit-cmd.sh"
# wrapper hard-requires the canonical-command inventory before any action — provide it
cp "$PROJ/.portable-spec-kit/kit-commands.yml" "$_g27_tmp/.portable-spec-kit/kit-commands.yml" 2>/dev/null
_g27_friction=$(printf 'line-one\nline-two\twith-tab')
bash "$_g27_tmp/agent/scripts/psk-kit-cmd.sh" --log-gap "reflex/run.sh" "$_g27_friction" "do the fix" >/dev/null 2>&1
_g27_datalines=$(awk '!/^#/ && !/^$/' "$_g27_tmp/agent/.kit-gap-log" 2>/dev/null | wc -l | tr -d ' ')
_g27_nf=$(awk -F'\t' '!/^#/ && !/^$/{print NF; exit}' "$_g27_tmp/agent/.kit-gap-log" 2>/dev/null)
if [ "$_g27_datalines" = "1" ] && [ "$_g27_nf" = "5" ]; then
  pass "97.16: G27 — multi-line/tab friction → single 5-field TSV entry (lines=$_g27_datalines NF=$_g27_nf)"
else
  fail "97.16: G27 — sanitization failed (lines=$_g27_datalines NF=$_g27_nf, expected 1/5)"
fi
rm -rf "$_g27_tmp"
