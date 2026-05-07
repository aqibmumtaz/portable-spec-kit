#!/bin/bash
# tests/sections/05-mandate-compliance.sh — regression for Dim 25 (Mandate-
# Compliance probe in QA-Agent) + 8th mechanical gate (mandate-compliance)
# in reflex/lib/gates.sh.
#
# Source: Loop-Iter-2 Phase F. Validates reflex/lib/mandate-audit.sh against
# three synthetic-fixture cases:
#   T1 — kit-conformant skeleton minus ard/ → MANDATE-DIR-ARD-MISSING (MAJOR)
#   T2 — SPECS.md F1 [x] + F2 [x] but only design/f1-*.md exists →
#        MANDATE-DESIGN-MD-MISSING-F2 (MINOR)
#   T3 — clean kit-conformant project → 0 findings
#
# Independently runnable: bash tests/sections/05-mandate-compliance.sh
#
# DEPRECATED-IN-FAVOR-OF: tests/features/fNN-*.sh
#
# Loop-4 v0.6.32: SPECS.md Tests column now points at tests/features/fNN-*.sh
# (per-feature audits, ~1 sec each). The exhaustive coverage in this file
# still runs when test-spec-kit.sh sources sections/. Future cleanup
# (v0.7.0+) will split this file's tests across features/ properly.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "Mandate-Compliance probe (Dim 25 + 8th gate)"

MANDATE_AUDIT="$PROJ/reflex/lib/mandate-audit.sh"

# --- Sanity: probe exists + executable ---
if [ -x "$MANDATE_AUDIT" ]; then
  pass "mandate-audit.sh exists and is executable"
else
  fail "mandate-audit.sh missing or not executable: $MANDATE_AUDIT"
  return 0 2>/dev/null || exit 1
fi

# Build a kit-conformant synthetic skeleton in $1 (target dir)
build_skeleton() {
  local d="$1"
  mkdir -p "$d/agent/design" "$d/agent/scripts" "$d/tests" \
           "$d/docs/work-flows" "$d/ard" "$d/.github/workflows" "$d/src"
  # Pipeline files (minimal but present)
  for f in REQS SPECS PLANS DESIGN TASKS RELEASES RESEARCH AGENT AGENT_CONTEXT; do
    echo "# $f" > "$d/agent/$f.md"
  done
  # Project files
  echo "# README" > "$d/README.md"
  echo "# CHANGELOG" > "$d/CHANGELOG.md"
  echo "FOO=paste-your-key-here" > "$d/.env.example"
  echo ".env" > "$d/.gitignore"
  # Stack manifest (Node) so layout check fires intentionally on src/
  echo '{"name":"synthetic","version":"0.0.1"}' > "$d/package.json"
  # Workflow content sanity: ≥3 entries, ci yml present
  for n in 01-foo.md 02-bar.md 03-baz.md; do echo "# $n" > "$d/docs/work-flows/$n"; done
  echo "name: ci" > "$d/.github/workflows/ci.yml"
  # ARD html so MANDATE-ARD-HTML-MISSING does not fire by default
  echo "<html></html>" > "$d/ard/Technical_Overview.html"
  # Version anchors (avoid drift finding)
  echo "**Version:** v0.1.0" > "$d/agent/AGENT_CONTEXT.md"
  echo "version-v0.1.0" >> "$d/README.md"
}

# --- T1: ard/ missing → MANDATE-DIR-ARD-MISSING (MAJOR) ---
T1_DIR=$(mktemp -d "/tmp/psk-mandate-t1-XXXXXX")
build_skeleton "$T1_DIR"
rm -rf "$T1_DIR/ard"
T1_OUT=$(bash "$MANDATE_AUDIT" --root "$T1_DIR" 2>/dev/null)
if echo "$T1_OUT" | grep -q "MANDATE-DIR-ARD-MISSING"; then
  pass "T1: ard/ missing flagged with MANDATE-DIR-ARD-MISSING"
else
  fail "T1: MANDATE-DIR-ARD-MISSING not reported when ard/ removed"
fi
# Verify severity = MAJOR for that finding
if echo "$T1_OUT" | grep -A1 "MANDATE-DIR-ARD-MISSING" | grep -q '"severity":"MAJOR"'; then
  pass "T1: severity = MAJOR (correct)"
else
  fail "T1: severity != MAJOR for MANDATE-DIR-ARD-MISSING"
fi
rm -rf "$T1_DIR"

# --- T2: SPECS has F1[x] + F2[x] but only design/f1-*.md exists → MANDATE-DESIGN-MD-MISSING-F2 (MINOR) ---
T2_DIR=$(mktemp -d "/tmp/psk-mandate-t2-XXXXXX")
build_skeleton "$T2_DIR"
cat > "$T2_DIR/agent/SPECS.md" <<'EOF'
# SPECS

## Features

| ID | Feature | Status | Tests |
|----|---------|--------|-------|
| F1 | Foo | [x] | tests/foo.sh |
| F2 | Bar | [x] | tests/bar.sh |
EOF
echo "# F1 plan" > "$T2_DIR/agent/design/f1-foo.md"
# Note: deliberately no f2-*.md
T2_OUT=$(bash "$MANDATE_AUDIT" --root "$T2_DIR" 2>/dev/null)
if echo "$T2_OUT" | grep -q "MANDATE-DESIGN-MD-MISSING-F2"; then
  pass "T2: missing design plan for F2 flagged"
else
  fail "T2: MANDATE-DESIGN-MD-MISSING-F2 not reported"
fi
if echo "$T2_OUT" | grep -A1 "MANDATE-DESIGN-MD-MISSING-F2" | grep -q '"severity":"MINOR"'; then
  pass "T2: severity = MINOR (correct)"
else
  fail "T2: severity != MINOR for MANDATE-DESIGN-MD-MISSING-F2"
fi
# F1 should NOT be flagged
if echo "$T2_OUT" | grep -q "MANDATE-DESIGN-MD-MISSING-F1"; then
  fail "T2: false positive — F1 has design plan but flagged"
else
  pass "T2: F1 correctly not flagged (design plan exists)"
fi
rm -rf "$T2_DIR"

# --- T3: clean kit-conformant project → 0 MAJOR/MINOR findings ---
# (ADVISORY-only findings like missing ard/*.pdf are allowed since the
# skeleton has no PDF generator wired up.)
T3_DIR=$(mktemp -d "/tmp/psk-mandate-t3-XXXXXX")
build_skeleton "$T3_DIR"
# Add a stub PDF so even ADVISORY total = 0
echo "%PDF-1.4 stub" > "$T3_DIR/ard/Technical_Overview.pdf"
T3_OUT=$(bash "$MANDATE_AUDIT" --root "$T3_DIR" 2>/dev/null)
T3_MAJOR=$(echo "$T3_OUT" | grep -oE '"MAJOR":[0-9]+' | head -1 | grep -oE '[0-9]+')
T3_MINOR=$(echo "$T3_OUT" | grep -oE '"MINOR":[0-9]+' | head -1 | grep -oE '[0-9]+')
if [ "${T3_MAJOR:-0}" -eq 0 ] && [ "${T3_MINOR:-0}" -eq 0 ]; then
  pass "T3: clean skeleton produces 0 MAJOR/MINOR findings"
else
  fail "T3: clean skeleton has MAJOR=$T3_MAJOR MINOR=$T3_MINOR (expected 0/0)"
  echo "$T3_OUT" | head -40 >&2
fi
rm -rf "$T3_DIR"

# --- Gate-8 wiring sanity: gates.sh references mandate-compliance ---
if grep -q "mandate-compliance\|mandate_compliance\|mandate-audit" "$PROJ/reflex/lib/gates.sh" 2>/dev/null; then
  pass "Gate-8: gates.sh references mandate-compliance probe"
else
  fail "Gate-8: gates.sh does not reference mandate-compliance"
fi

# --- QA-Agent prompt registers Dim 25 ---
if grep -q "Dim 25\|Dimension 25\|Mandate-Compliance" "$PROJ/reflex/prompts/qa-agent.md" 2>/dev/null; then
  pass "Dim 25: qa-agent.md registers Mandate-Compliance dimension"
else
  fail "Dim 25: qa-agent.md missing Mandate-Compliance registration"
fi

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  RESULTS (05-mandate-compliance): $PASS passed, $FAIL failed, $TOTAL total"
  echo "═══════════════════════════════════════════"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi
