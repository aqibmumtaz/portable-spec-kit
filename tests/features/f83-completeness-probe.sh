#!/usr/bin/env bash
# f83-completeness-probe.sh — Adversarial assertions for F83 (HF5 synthesis-detection probe).
#
# cycle-17/pass-001 rewrite (closes QA-CRIT-FIDELITY-F83-01 + QA-D12-01 instance):
# previous stub was an 8-line delegate that passed unconditionally. This rewrite
# asserts the F83 implicit acceptance criteria directly:
#   AC1. reflex/lib/check-audit-completeness.sh exists + executable
#   AC2. probe emits a verdict field with one of {real, suspect, synthesis-confirmed}
#   AC3. probe accepts --json flag
#   AC4. probe enforces ≥6 red-flag signatures (script self-documents)
#   AC5. Section 75 in tests/sections/03-reliability.sh exists (sibling-section probe)
#   AC6. The 13th gate (audit-completeness) is wired in reflex/lib/gates.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "f83-completeness-probe — HF5 synthesis-detection probe + 13th gate"

PROBE="$PROJ/reflex/lib/check-audit-completeness.sh"
GATES="$PROJ/reflex/lib/gates.sh"
SEC03="$PROJ/tests/sections/03-reliability.sh"

# AC1 — probe exists + executable
if [ -x "$PROBE" ]; then
  pass "f83 AC1: check-audit-completeness.sh exists and is executable"
else
  fail "f83 AC1: check-audit-completeness.sh missing or non-executable"
fi

# AC2 — probe emits verdict on a pass dir; assert one of the canonical values.
# Self-contained fixture: a clean reflex reset (`--purge-history`) legitimately
# wipes ALL pass dirs, so the test must NOT depend on real history existing.
# Prefer a real committed pass dir when present (richer signal); otherwise build a
# minimal synthetic pass dir so the assertion always runs.
SAMPLE_PASS=$(ls -dt "$PROJ"/reflex/history/cycle-*/pass-* 2>/dev/null | head -1)
if [ -z "$SAMPLE_PASS" ] || [ ! -d "$SAMPLE_PASS" ]; then
  SAMPLE_PASS=$(mktemp -d)
  printf 'findings:\n  - id: SYNTH-1\n    status: open\n    citable_quote: "reflex/lib/foo.sh:7 — synthetic fixture finding"\n' > "$SAMPLE_PASS/findings.yaml"
  printf -- '- verdict: DENIED\n- qa_findings: 1\n' > "$SAMPLE_PASS/verdict.md"
  printf 'qa_usage:\n  mode: orchestrated-single-author\n' > "$SAMPLE_PASS/qa-usage.yaml"
fi
if [ -x "$PROBE" ] && [ -d "$SAMPLE_PASS" ]; then
  PROBE_OUT=$(bash "$PROBE" "$SAMPLE_PASS" --json 2>/dev/null || true)
  if echo "$PROBE_OUT" | grep -qE '"verdict":\s*"(real|suspect|synthesis-confirmed)"'; then
    pass "f83 AC2: verdict emitted in canonical set {real, suspect, synthesis-confirmed}"
  else
    fail "f83 AC2: verdict field missing or non-canonical value in JSON output"
  fi
else
  fail "f83 AC2: cannot run probe — script or sample pass dir missing"
fi

# AC3 — --json flag accepted (probe must accept the flag; output already verified in AC2)
if [ -x "$PROBE" ] && bash "$PROBE" --help 2>&1 | grep -qE '\-\-json|json' \
   || bash "$PROBE" "$SAMPLE_PASS" --json 2>&1 | head -c1 | grep -qE '\{'; then
  pass "f83 AC3: --json flag accepted by check-audit-completeness.sh"
else
  fail "f83 AC3: --json flag not recognized"
fi

# AC4 — probe self-documents ≥6 red-flag signatures (regex-match in source)
if [ -f "$PROBE" ]; then
  FLAG_COUNT=$(grep -cE 'red.flag|RED.FLAG|red_flag|signature' "$PROBE" || true)
  if [ "$FLAG_COUNT" -ge 6 ]; then
    pass "f83 AC4: probe references ≥6 signature/red-flag tokens ($FLAG_COUNT found)"
  else
    fail "f83 AC4: probe references only $FLAG_COUNT signature/red-flag tokens (expected ≥6)"
  fi
else
  fail "f83 AC4: probe source file missing"
fi

# AC5 — Section 75 exists in tests/sections/03-reliability.sh
if [ -f "$SEC03" ] && grep -qE '^# Section 75' "$SEC03"; then
  pass "f83 AC5: Section 75 (HF5 synthesis-detection) registered in 03-reliability.sh"
else
  fail "f83 AC5: Section 75 marker missing from tests/sections/03-reliability.sh"
fi

# AC6 — 13th gate audit-completeness wired in reflex/lib/gates.sh
if [ -f "$GATES" ] && grep -qE 'audit.completeness|audit_completeness' "$GATES"; then
  pass "f83 AC6: 13th gate 'audit-completeness' wired in reflex/lib/gates.sh"
else
  fail "f83 AC6: 13th gate not wired in reflex/lib/gates.sh"
fi
