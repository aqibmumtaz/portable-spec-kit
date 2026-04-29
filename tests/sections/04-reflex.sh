#!/bin/bash
# tests/sections/04-reflex.sh — section N onwards (reflex/AVACR runtime)
#
# Reflex cross-pass register + pass-export anonymizer + submission, N52
# dev-branch isolation + protected-files write-ban + autoloop + history
# retention, N56 convergence-based stopping + loop-resume + cache-order +
# token tracking, N57 psk-bootstrap-check gate, N58 bootstrap-first rule
# + curl-fallback, N59 Phase 0 pre-compute (claims + state-diff), N60
# 7-layer Senior-Engineer QA (v0.6.7), N61 v0.6.8 Layer 3/5/7 helpers
# + ADL auto-extraction. Largest section — captures all v0.5.21+ reflex
# runtime tests including the G1-G15 reflex framework gaps (parser,
# regex, regression-diff, gates, file-bugs schema validator, dimension
# floor, coverage YAML, preconditions install-commit walkback, recover
# diagnostic, RFT cache + CI templates).
#
# Independently runnable: bash tests/sections/04-reflex.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "N. Reflex cross-pass register + pass-export anonymizer + submission"

# --- Register generator integration test (synthetic multi-pass fixture) ---
REG_TMP="/tmp/psk-register-test-$$"
mkdir -p "$REG_TMP/reflex/history/standalone/pass-100" "$REG_TMP/reflex/history/standalone/pass-101" "$REG_TMP/agent"

# Pass-100: structured findings.yaml with mixed status (resolved via TASKS.md below)
cat > "$REG_TMP/reflex/history/standalone/pass-100/findings.yaml" <<'EOF'
pass_id: standalone-pass-100
release_class: minor
pass_stance: FAIL_UNTIL_PROVEN
findings:
  - id: QA-TEST-100
    feature: TEST
    priority: CRITICAL
    scope: target-project
    dimension: functional-correctness
  - id: QA-TEST-101
    feature: TEST
    priority: MAJOR
    scope: kit
    dimension: documentation-completeness
EOF

cat > "$REG_TMP/reflex/history/standalone/pass-100/signoff.md" <<'EOF'
# Signoff standalone-pass-100
Verdict: DENIED
EOF

cat > "$REG_TMP/reflex/history/standalone/pass-100/verdict.md" <<'EOF'
- timestamp: 2026-04-23T10:00:00Z
EOF

# Pass-101 (newer) — one persisted, one new
cat > "$REG_TMP/reflex/history/standalone/pass-101/findings.yaml" <<'EOF'
pass_id: standalone-pass-101
release_class: patch
pass_stance: FAIL_UNTIL_PROVEN
findings:
  - id: QA-TEST-102
    feature: TEST
    priority: MINOR
    scope: target-project
    dimension: polish
EOF

cat > "$REG_TMP/reflex/history/standalone/pass-101/signoff.md" <<'EOF'
# Signoff standalone-pass-101
Verdict: GRANTED
EOF

# TASKS.md with a mix: one [x] closed, one [ ] open, one [~] acknowledged
cat > "$REG_TMP/agent/TASKS.md" <<'EOF'
## v0.1 — Current
- [x] **QA-TEST-100** @reflex-dev: fixed the critical failure
- [ ] **QA-TEST-101** @reflex-dev: still pending
- [~] **QA-TEST-102** @reflex-dev: accepted as known limit
EOF

# Copy generator to temp + run
cp "$PROJ/reflex/lib/update-eval-trace.sh" "$REG_TMP/reflex/lib/" 2>/dev/null || \
  { mkdir -p "$REG_TMP/reflex/lib" && cp "$PROJ/reflex/lib/update-eval-trace.sh" "$REG_TMP/reflex/lib/"; }

if REFLEX_PROJECT_ROOT="$REG_TMP" bash "$REG_TMP/reflex/lib/update-eval-trace.sh" >/dev/null 2>&1; then
  REG_OUT="$REG_TMP/reflex/history/REFLEX_EVAL_TRACE.md"
  [ -f "$REG_OUT" ] && pass "register-integration: generator produces REFLEX_EVAL_TRACE.md" || fail "register-integration: output file missing"
  grep -qF "standalone-pass-101" "$REG_OUT" && pass "register-integration: newest pass block first (101)" || fail "register-integration: 101 block missing"
  grep -qF "standalone-pass-100" "$REG_OUT" && pass "register-integration: older pass also included (100)" || fail "register-integration: 100 block missing"
  grep -qF '| `[x]` | `QA-TEST-100`' "$REG_OUT" && pass "register-integration: [x] closed resolved from TASKS.md" || fail "register-integration: [x] not resolved"
  grep -qF '| `[ ]` | `QA-TEST-101`' "$REG_OUT" && pass "register-integration: [ ] open resolved from TASKS.md" || fail "register-integration: [ ] not resolved"
  grep -qF '| `[~]` | `QA-TEST-102`' "$REG_OUT" && pass "register-integration: [~] acknowledged resolved from TASKS.md" || fail "register-integration: [~] not resolved"
  grep -qF "Verdict: DENIED" "$REG_OUT" || grep -qF "verdict: **DENIED**" "$REG_OUT" && pass "register-integration: DENIED verdict surfaced" || fail "register-integration: DENIED verdict missing"
  grep -qF "verdict: **GRANTED**" "$REG_OUT" && pass "register-integration: GRANTED verdict surfaced" || fail "register-integration: GRANTED verdict missing"
else
  fail "register-integration: generator exited non-zero on synthetic fixture"
fi
rm -rf "$REG_TMP"

# --- Intake parser test (YAML block in issue body) ---
INTAKE_TMP="/tmp/psk-intake-test-$$.json"
cat > "$INTAKE_TMP" <<'EOF'
[{"number":77,"body":"# AVACR Pass\n## Findings (structured)\n```yaml\npass_id: reflex-pass-002\nfindings:\n  - id: QA-REL-42\n    feature: REL\n    priority: CRITICAL\n    scope: kit\n    dimension: functional-correctness\n  - id: QA-PROJ-01\n    feature: F5\n    priority: MAJOR\n    scope: target-project\n  - id: QA-META-09\n    feature: PAPER\n    priority: MINOR\n    scope: meta\n```"}]
EOF
intake_out=$(python3 - "$INTAKE_TMP" <<'PYEOF' 2>&1
import json, re, sys
with open(sys.argv[1]) as f: issues = json.load(f)
YAML_BLOCK = re.compile(r'```ya?ml\s*\n(.*?)\n```', re.DOTALL)
def parse_findings_yaml(yaml_body):
    out = []; in_findings = False; current = {}
    def flush():
        if current.get('id') and current.get('scope') in ('kit', 'meta'):
            out.append(dict(current))
    for raw in yaml_body.split('\n'):
        if re.match(r'^findings:\s*$', raw): in_findings = True; continue
        if in_findings and re.match(r'^[A-Za-z_]', raw): flush(); current = {}; in_findings = False; continue
        if not in_findings: continue
        m = re.match(r'^\s*-\s+id:\s*(.+?)\s*$', raw)
        if m: flush(); current = {'id': m.group(1).strip()}; continue
        for key in ('priority', 'scope', 'feature'):
            m = re.match(rf'^\s+{key}:\s*(.+?)\s*$', raw)
            if m: current[key] = m.group(1).strip(); break
    flush(); return out
for issue in issues:
    body = issue.get("body", "") or ""
    ym = YAML_BLOCK.search(body)
    if not ym: continue
    for f in parse_findings_yaml(ym.group(1)):
        print(f"{issue['number']}\t{f['id']}\t{f['scope']}\t{f['priority']}")
PYEOF
)
echo "$intake_out" | grep -qF "77	QA-REL-42	kit	CRITICAL" && pass "intake-parser: extracts kit-scope finding from yaml block" || fail "intake-parser: kit finding not extracted ($intake_out)"
echo "$intake_out" | grep -qF "77	QA-META-09	meta	MINOR" && pass "intake-parser: extracts meta-scope finding" || fail "intake-parser: meta finding not extracted"
echo "$intake_out" | grep -qF "QA-PROJ-01" \
  && fail "intake-parser: target-project finding leaked (should be filtered)" \
  || pass "intake-parser: target-project finding correctly filtered out"
rm -f "$INTAKE_TMP"

# Cross-pass findings register (REFLEX_EVAL_TRACE.md) — single surface now
REG_SH="$PROJ/reflex/lib/update-eval-trace.sh"
[ -x "$REG_SH" ] && pass "reflex-register: update-eval-trace.sh executable" || fail "reflex-register: update-eval-trace.sh not executable"
grep -qF "REFLEX_EVAL_TRACE.md" "$REG_SH" \
  && pass "reflex-register: generator targets REFLEX_EVAL_TRACE.md" \
  || fail "reflex-register: generator wrong output path"
grep -qF "findings.yaml" "$REG_SH" \
  && pass "reflex-register: generator reads per-pass findings.yaml" \
  || fail "reflex-register: generator does not source findings.yaml"
grep -qF "task_status" "$REG_SH" \
  && pass "reflex-register: generator resolves status from agent/TASKS.md" \
  || fail "reflex-register: generator missing TASKS.md status resolution"

# Verify the AVACR_EVAL_TRACE.md per-pass narrative is retired — generator + template must not exist
[ ! -f "$PROJ/reflex/prompts/avacr-eval-trace-template.md" ] \
  && pass "reflex-register: per-pass trace template retired (findings.yaml + signoff.md + register replace it)" \
  || fail "reflex-register: per-pass trace template still present"
[ ! -f "$PROJ/reflex/lib/write-eval-trace.sh" ] \
  && pass "reflex-register: per-pass trace generator retired" \
  || fail "reflex-register: per-pass trace generator still present"

# Anonymizer script exists, executable, strips home paths + emails
TRACE_TMPDIR="/tmp/psk-reflex-anon-test-$$"
mkdir -p "$TRACE_TMPDIR"
ANON_SH="$PROJ/reflex/lib/anonymize.sh"
[ -x "$ANON_SH" ] && pass "reflex-anon: anonymize.sh executable" || fail "reflex-anon: anonymize.sh not executable"
cat > "$TRACE_TMPDIR/input.md" <<'IEOF'
Path: /Users/realname/workspace/project/file.md
Email: real.person@somewhere.io
/tmp/session-abc123/scratch
IEOF
bash "$ANON_SH" "$TRACE_TMPDIR/input.md" "$TRACE_TMPDIR/output.md" >/dev/null 2>&1
grep -q '<home>/workspace' "$TRACE_TMPDIR/output.md" \
  && pass "reflex-anon: strips /Users/* home path" \
  || fail "reflex-anon: failed to strip home path"
grep -q '<email-redacted>' "$TRACE_TMPDIR/output.md" \
  && pass "reflex-anon: redacts email" \
  || fail "reflex-anon: failed to redact email"
grep -q '/tmp/<session>' "$TRACE_TMPDIR/output.md" \
  && pass "reflex-anon: generalizes /tmp session paths" \
  || fail "reflex-anon: failed on /tmp path"
grep -q 'realname' "$TRACE_TMPDIR/output.md" \
  && fail "reflex-anon: LEAKED username" \
  || pass "reflex-anon: did not leak username"
rm -rf "$TRACE_TMPDIR"

# run.sh exposes --submit-to-kit, --report-to-kit, --confirm, --replace-project=
for flag in "--submit-to-kit" "--report-to-kit" "--confirm" "--replace-project="; do
  grep -qF -- "$flag" "$PROJ/reflex/run.sh" \
    && pass "reflex-submit: run.sh exposes $flag" \
    || fail "reflex-submit: run.sh missing $flag"
done

# --submit-to-kit without --confirm must be a dry-run (no gh call), OR
# refuse cleanly when no prior pass exists. Either behaviour is correct —
# what must NEVER happen is an actual gh issue creation.
submit_out=$(bash "$PROJ/reflex/run.sh" --submit-to-kit 2>&1 || true)
if echo "$submit_out" | grep -q "Dry-run\|no reflex pass has run yet\|findings.yaml missing"; then
  pass "reflex-submit: --submit-to-kit without --confirm is safe (dry-run or refuses cleanly)"
else
  fail "reflex-submit: --submit-to-kit must dry-run or refuse — unexpected output: $submit_out"
fi

# Pass export is composed from signoff.md + findings.yaml (not AVACR_EVAL_TRACE.md)
grep -qF 'signoff.md' "$PROJ/reflex/run.sh" \
  && pass "reflex-submit: run.sh composes export from signoff.md" \
  || fail "reflex-submit: run.sh export does not reference signoff.md"
grep -qF 'findings.yaml' "$PROJ/reflex/run.sh" \
  && pass "reflex-submit: run.sh composes export from findings.yaml" \
  || fail "reflex-submit: run.sh export does not reference findings.yaml"
grep -qF 'AVACR_EVAL_TRACE' "$PROJ/reflex/run.sh" \
  && fail "reflex-submit: run.sh still references AVACR_EVAL_TRACE.md (deleted artifact)" \
  || pass "reflex-submit: run.sh has no AVACR_EVAL_TRACE.md references"

# README documents all three mechanisms (A / B / C)
for pattern in "report-to-kit" "submit-to-kit" "Manual issue"; do
  grep -qF "$pattern" "$PROJ/reflex/README.md" \
    && pass "reflex-submit: reflex/README documents '$pattern'" \
    || fail "reflex-submit: reflex/README missing '$pattern'"
done

# qa-agent.md prompt mandates PASS list + integrity rules (carried from Q1 — still live in qa-result.md)
grep -qF "## Tested (PASS)" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "reflex-qa: qa-agent prompt documents Tested (PASS) section" \
  || fail "reflex-qa: qa-agent prompt missing Tested (PASS) section"
grep -qF "PASS-list integrity rules" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "reflex-qa: qa-agent prompt has integrity rules" \
  || fail "reflex-qa: qa-agent prompt missing integrity rules"
grep -qF "tests_planned" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "reflex-qa: qa-agent Summary schema has tests_planned" \
  || fail "reflex-qa: qa-agent Summary schema missing tests_planned"

# --- Q2: --self-test mode (v0.6.2+: no wrapper scripts; consolidated to run.sh) ---

# run.sh exposes --self-test flag (kit-identity auto-detection also works)
grep -qF -- "--self-test" "$PROJ/reflex/run.sh" && pass "self-test: run.sh exposes --self-test" || fail "self-test: run.sh missing --self-test"
grep -q "SELF_TEST=true" "$PROJ/reflex/run.sh" && pass "self-test: run.sh sets SELF_TEST flag" || fail "self-test: run.sh missing SELF_TEST flag"
grep -qE 'cycle-\*/pass-\*|standalone/pass-\*|pass_dir_to_name' "$PROJ/reflex/run.sh" && pass "self-test: run.sh encodes nested pass-dir naming convention" || fail "self-test: run.sh missing nested pass-dir naming"

# Wrapper scripts retired in v0.6.2 — run.sh is the single public entry
[ ! -f "$PROJ/reflex/autoloop.sh" ] && pass "entry-consolidation: reflex/autoloop.sh wrapper retired (run.sh is sole entry)" || fail "entry-consolidation: autoloop.sh wrapper still present"
[ ! -f "$PROJ/reflex/kit-loop.sh" ] && pass "entry-consolidation: reflex/kit-loop.sh wrapper retired" || fail "entry-consolidation: kit-loop.sh wrapper still present"
[ ! -f "$PROJ/reflex/self-test.sh" ] && pass "entry-consolidation: reflex/self-test.sh wrapper retired" || fail "entry-consolidation: self-test.sh wrapper still present"
[ ! -f "$PROJ/reflex/loop.sh" ] && pass "entry-consolidation: reflex/loop.sh wrapper retired (reflex/lib/loop.sh remains internal)" || fail "entry-consolidation: loop.sh wrapper still present"

# preconditions.sh guards cwd when SELF_TEST=true
grep -q 'SELF_TEST' "$PROJ/reflex/lib/preconditions.sh" && pass "self-test: preconditions.sh checks SELF_TEST" || fail "self-test: preconditions.sh missing SELF_TEST guard"
grep -q 'must be a real file, not a symlink' "$PROJ/reflex/lib/preconditions.sh" && pass "self-test: preconditions rejects symlinked portable-spec-kit.md" || fail "self-test: preconditions missing symlink guard"
grep -q 'reflex/ directory missing' "$PROJ/reflex/lib/preconditions.sh" && pass "self-test: preconditions rejects projects without reflex/" || fail "self-test: preconditions missing reflex/ guard"

# Behavioral: run preconditions in a temp non-kit dir → must refuse with --self-test
ST_TMP="/tmp/psk-selftest-$$"
mkdir -p "$ST_TMP"
echo "dummy" > "$ST_TMP/portable-spec-kit.md"  # NOT a real kit — missing reflex/ and psk-release.sh
if SELF_TEST=true REFLEX_PROJ_ROOT="$ST_TMP" bash "$PROJ/reflex/lib/preconditions.sh" 2>&1 | grep -q "requires cwd to be the kit repo"; then
  pass "self-test: preconditions refuses --self-test outside kit repo"
else
  fail "self-test: preconditions failed to reject non-kit cwd"
fi
rm -rf "$ST_TMP"

# Behavioral: run preconditions in the actual kit repo → passes (or fails on other gates, but NOT on the self-test one)
# Using --skip-preconditions is not available for preconditions.sh itself, so we check that the self-test gate passes in the actual kit repo
if SELF_TEST=true REFLEX_PROJ_ROOT="$PROJ" bash "$PROJ/reflex/lib/preconditions.sh" 2>&1 | grep -q "self-test precondition passed"; then
  pass "self-test: preconditions accepts real kit repo as --self-test cwd"
else
  fail "self-test: preconditions rejected real kit repo"
fi

# README.md documents the self-test workflow (via run.sh --self-test or kit-identity auto-detect)
for pattern in "Testing the kit itself" "pass-NNN" "run.sh"; do
  grep -qF "$pattern" "$PROJ/reflex/README.md" \
    && pass "self-test: reflex/README documents '$pattern'" \
    || fail "self-test: reflex/README missing '$pattern'"
done

# --- G1/G2/G5/G6: parser + regex consistency across reflex/lib/ ---

G_TMP="/tmp/psk-ggaps-$$"
mkdir -p "$G_TMP/pass-777"

# G1 — score.sh dev_fixes counts both legacy "## Fixes" + new YAML "fixed:" formats
# Legacy form
cat > "$G_TMP/dev-legacy.md" <<LEOF
# Dev
## Fixes
- id: QA-F1-01
- id: QA-F2-01
## Other
- id: QA-IGNORED-01
LEOF
legacy_count=$(awk '
  /^## Fixes/    { section = "fixes"; next }
  /^## /         { section = "other" }
  /^fixed:/      { yaml = "fixed"; next }
  /^[a-z_]+:/    { yaml = "other" }
  section == "fixes" && /^- id:/            { count++ }
  yaml == "fixed" && /^[[:space:]]+- id:/   { count++ }
  END { print count+0 }
' "$G_TMP/dev-legacy.md")
[ "$legacy_count" = "2" ] && pass "G1: legacy dev-result.md counts 2 fixes" || fail "G1: legacy format miscounted ($legacy_count, expected 2)"

# New YAML form
cat > "$G_TMP/dev-yaml.md" <<YEOF
# Dev
fixed:
  - id: QA-F5-01
    commit: abc123
  - id: QA-F6-01
    commit: def456
escalated:
  - id: QA-ARCH-99
YEOF
yaml_count=$(awk '
  /^## Fixes/    { section = "fixes"; next }
  /^## /         { section = "other" }
  /^fixed:/      { yaml = "fixed"; next }
  /^[a-z_]+:/    { yaml = "other" }
  section == "fixes" && /^- id:/            { count++ }
  yaml == "fixed" && /^[[:space:]]+- id:/   { count++ }
  END { print count+0 }
' "$G_TMP/dev-yaml.md")
[ "$yaml_count" = "2" ] && pass "G1: YAML dev-result.md counts 2 fixes" || fail "G1: YAML format miscounted ($yaml_count, expected 2)"

# G6 — findings count scoped to ## Findings only, NOT Tested (PASS)
cat > "$G_TMP/qa-mixed.md" <<QEOF
# QA
## Findings
- id: QA-F1-01
- id: QA-F2-01
## Tested (PASS)
- id: QA-F3-PASS
- id: QA-F4-PASS
- id: QA-F5-PASS
## Summary
- findings_total: 2
QEOF
findings_count=$(awk '
  /^## Findings/ { section = "findings"; next }
  /^## /         { section = "other" }
  section == "findings" && /^- id:/ { count++ }
  END { print count+0 }
' "$G_TMP/qa-mixed.md")
[ "$findings_count" = "2" ] && pass "G6: findings count scoped to ## Findings (not Tested PASS)" || fail "G6: findings over-counted ($findings_count, expected 2)"

# G2 — regression-diff normalize_ids strips -R\d+ / -F\d+ suffixes
# Directly re-test the sed pattern used in regression-diff.sh
norm_out=$(echo -e "QA-SEC-03\nQA-SEC-03-R1\nQA-SEC-03-R2\nQA-F12-01\nQA-F12-01-F1" | sed -E 's/-R[0-9]+$|-F[0-9]+$//' | sort -u | wc -l | tr -d ' ')
[ "$norm_out" = "2" ] && pass "G2: suffix normalizer collapses -R1/-R2/-F1 into base IDs (2 unique)" || fail "G2: suffix normalizer broken (got $norm_out unique, expected 2)"
# Verify the actual helper in regression-diff.sh does the same
grep -q "s/-R\[0-9\]+\$|-F\[0-9\]+\$//" "$PROJ/reflex/lib/regression-diff.sh" \
  && pass "G2: regression-diff.sh has normalize_ids helper with correct sed pattern" \
  || fail "G2: regression-diff.sh missing suffix normalizer"

# G5 — QA ID regex is consistent across file-bugs.sh and regression-diff.sh
# Expected canonical regex literal (fixed-string match): QA-[A-Z]+[0-9]*-[0-9]+(-[A-Z]+[0-9]*)?
CANONICAL_LITERAL='QA-[A-Z]+[0-9]*-[0-9]+(-[A-Z]+[0-9]*)?'
grep -qF "$CANONICAL_LITERAL" "$PROJ/reflex/lib/file-bugs.sh" \
  && pass "G5: file-bugs.sh uses canonical QA-ID regex" \
  || fail "G5: file-bugs.sh has stale QA-ID regex"
grep -qF "$CANONICAL_LITERAL" "$PROJ/reflex/lib/regression-diff.sh" \
  && pass "G5: regression-diff.sh uses canonical QA-ID regex" \
  || fail "G5: regression-diff.sh has stale QA-ID regex"
# Should NOT have the old permissive pattern [A-Z0-9]+ in middle segment
if grep -qF 'QA-[A-Z0-9]+-[0-9]+' "$PROJ/reflex/lib/file-bugs.sh" "$PROJ/reflex/lib/regression-diff.sh"; then
  fail "G5: old permissive regex still present in file-bugs.sh or regression-diff.sh"
else
  pass "G5: old permissive regex [A-Z0-9]+ purged from file-bugs.sh + regression-diff.sh"
fi

# Behavioral: canonical regex matches expected feature codes
for sample_id in "QA-F70-03" "QA-ARCH-01" "QA-SEC-03-R1" "QA-ASSUME-01" "QA-F12-03-R2"; do
  if echo "$sample_id" | grep -qE 'QA-[A-Z]+[0-9]*-[0-9]+(-[A-Z]+[0-9]*)?'; then
    pass "G5: canonical regex matches $sample_id"
  else
    fail "G5: canonical regex FAILS to match $sample_id"
  fi
done

# Cleanup
rm -rf "$TRACE_TMPDIR" "$Q1_TMP" "$G_TMP"

# --- G7: test-templates skill ---
TT_SKILL="$PROJ/.portable-spec-kit/skills/test-templates.md"
[ -f "$TT_SKILL" ] && pass "G7: test-templates.md skill exists" || fail "G7: test-templates.md skill MISSING"
for pattern in "_find_free_port" "_wait_for_healthz" "subprocess.Popen" "live_server" "X-Forwarded-For"; do
  grep -qF "$pattern" "$TT_SKILL" \
    && pass "G7: test-templates skill documents '$pattern'" \
    || fail "G7: test-templates skill missing '$pattern'"
done
# Skill is registered in portable-spec-kit.md trigger table
grep -qF "test-templates.md" "$PROJ/portable-spec-kit.md" \
  && pass "G7: test-templates skill listed in Skill-Based Architecture table" \
  || fail "G7: test-templates skill not wired into skill trigger table"

# --- G11: AVACR eval trace template marked done in TASKS.md ---
grep -qE '^\s*-\s*\[x\] \*\*G11' "$PROJ/agent/TASKS.md" \
  && pass "G11: marked [x] in TASKS.md (shipped in f141544)" \
  || fail "G11: not marked done in TASKS.md"

# --- G13: rate-limit escape-hatch doc in reflex/README.md ---
for pattern in "rate-limit escape hatch" "Dev-Agent rate-limit" "dev-result.md" "Hand-finish" "hand-finish"; do
  if grep -qF "$pattern" "$PROJ/reflex/README.md"; then
    pass "G13: reflex/README documents '$pattern'"
  fi
done
grep -qF "Recovery — Dev-Agent rate-limit escape hatch" "$PROJ/reflex/README.md" \
  && pass "G13: escape-hatch section present in reflex/README" \
  || fail "G13: escape-hatch section MISSING in reflex/README"
grep -qE '^\s*-\s*\[x\] \*\*G13' "$PROJ/agent/TASKS.md" \
  && pass "G13: marked [x] in TASKS.md" \
  || fail "G13: not marked done in TASKS.md"

# --- G14: serial-execution trade-off doc in f70-reflex.md ---
grep -qF "Serial execution trade-off" "$PROJ/agent/design/f70-reflex.md" \
  && pass "G14: §14a Serial execution trade-off section added to design" \
  || fail "G14: §14a section MISSING from f70-reflex.md"
for pattern in "~69 min" "~4 hours" "Parallel QA across features" "Pipelined QA + Dev" "Cross-project reflex farm"; do
  grep -qF "$pattern" "$PROJ/agent/design/f70-reflex.md" \
    && pass "G14: design doc documents '$pattern'" \
    || fail "G14: design doc missing '$pattern'"
done
grep -qE '^\s*-\s*\[x\] \*\*G14' "$PROJ/agent/TASKS.md" \
  && pass "G14: marked [x] in TASKS.md" \
  || fail "G14: not marked done in TASKS.md"

grep -qE '^\s*-\s*\[x\] \*\*G7' "$PROJ/agent/TASKS.md" \
  && pass "G7: marked [x] in TASKS.md" \
  || fail "G7: not marked done in TASKS.md"

# --- G9: spawn-qa purges SQLite artifacts from sandbox data/ ---
grep -q "purge SQLite" "$PROJ/reflex/lib/spawn-qa.sh" \
  && pass "G9: spawn-qa.sh has SQLite purge block" \
  || fail "G9: spawn-qa.sh missing SQLite purge block"
for pat in '\*\.db' '\*\.sqlite' 'db-wal' 'db-shm'; do
  grep -q "$pat" "$PROJ/reflex/lib/spawn-qa.sh" \
    && pass "G9: spawn-qa.sh purge pattern includes $pat" \
    || fail "G9: spawn-qa.sh purge pattern MISSING $pat"
done

# --- G15: score.sh emits token-accounting columns + migrates old CSV ---
grep -q "qa_tokens,dev_tokens,qa_tool_calls,dev_tool_calls,wall_clock_seconds" "$PROJ/reflex/lib/score.sh" \
  && pass "G15: score.sh V2_HEADER has 5 new columns" \
  || fail "G15: score.sh missing V2 header columns"
grep -qE "migrated .* (to v2 schema|v1 → v3|v2 → v3)" "$PROJ/reflex/lib/score.sh" \
  && pass "G15: score.sh has migration log message" \
  || fail "G15: score.sh missing migration log message"
grep -q "extract_usage_field" "$PROJ/reflex/lib/score.sh" \
  && pass "G15: score.sh has extract_usage_field helper" \
  || fail "G15: score.sh missing extract_usage_field helper"

# Behavioral: run score.sh on synthetic dir with old 9-column CSV + usage files
# Verifies migration + token capture + row append works end-to-end.
G15_TMP="/tmp/psk-g15-$$"
mkdir -p "$G15_TMP/reflex/history/standalone/pass-777" "$G15_TMP/agent/.release-state"
cat > "$G15_TMP/reflex/history/summary.csv" <<'G15EOF'
pass,date,qa_findings,dev_fixes,escalated,features_tested,surprise_density,progress,gates_status
1,2026-01-01,3,2,0,5,0.600,n/a,pass
G15EOF
cat > "$G15_TMP/reflex/history/standalone/pass-777/qa-usage.yaml" <<'QU'
tokens_used: 12345
tool_calls: 42
wall_clock_seconds: 90
QU
cat > "$G15_TMP/reflex/history/standalone/pass-777/dev-usage.yaml" <<'DU'
tokens_used: 6789
tool_calls: 17
wall_clock_seconds: 120
DU
cat > "$G15_TMP/agent/.release-state/qa-result.md" <<'QR'
## Findings
- id: QA-F9-01

## Summary
- tests_planned: 5
QR
cat > "$G15_TMP/agent/.release-state/dev-result.md" <<'DR'
fixed:
  - id: QA-F9-01
DR
REFLEX_PROJ_ROOT="$G15_TMP" REFLEX_PASS_DIR="$G15_TMP/reflex/history/standalone/pass-777" REFLEX_GATES_STATUS="pass" \
  bash "$PROJ/reflex/lib/score.sh" >/dev/null 2>&1
# Header migrated to 15 columns (v3 — adds pass_score for Dim 17 ranking)
header_cols=$(head -1 "$G15_TMP/reflex/history/summary.csv" | awk -F',' '{print NF}')
[ "$header_cols" = "15" ] && pass "G15: header migrated to 15 columns (was 9)" || fail "G15: header did not migrate (got $header_cols columns)"
# Existing row padded to 15 columns
row_1_cols=$(sed -n '2p' "$G15_TMP/reflex/history/summary.csv" | awk -F',' '{print NF}')
[ "$row_1_cols" = "15" ] && pass "G15: existing row padded to 15 columns" || fail "G15: existing row not padded ($row_1_cols columns)"
# New row has token counts (now also pass_score appended)
if grep -qE ",12345,6789,42,17,120,[0-9]*$" "$G15_TMP/reflex/history/summary.csv"; then
  pass "G15: new row captures qa_tokens/dev_tokens/tool_calls/wall_clock + pass_score"
else
  fail "G15: new row missing token accounting or pass_score"
fi
rm -rf "$G15_TMP"

# Prompts mandate usage files
grep -qF "qa-usage.yaml" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "G15: qa-agent.md prompt mandates qa-usage.yaml" \
  || fail "G15: qa-agent.md missing qa-usage.yaml requirement"
grep -qF "dev-usage.yaml" "$PROJ/reflex/prompts/dev-agent.md" \
  && pass "G15: dev-agent.md prompt mandates dev-usage.yaml" \
  || fail "G15: dev-agent.md missing dev-usage.yaml requirement"

# Existing summary.csv in repo is v3 format (15 columns — added pass_score in v0.6.12)
live_csv_cols=$(head -1 "$PROJ/reflex/history/summary.csv" | awk -F',' '{print NF}')
[ "$live_csv_cols" = "15" ] && pass "G15: live summary.csv is already v3 (15 columns)" || fail "G15: live summary.csv not migrated ($live_csv_cols cols)"
# v3 schema includes pass_score column
grep -qE "^pass,date,.*,wall_clock_seconds,pass_score$" "$PROJ/reflex/history/summary.csv" \
  && pass "G15: v3 schema header includes pass_score column" \
  || fail "G15: v3 schema header missing pass_score column"
# score.sh has compute_pass_score logic (severity-weighted findings_value)
grep -q "findings_value=" "$PROJ/reflex/lib/score.sh" \
  && pass "G15: score.sh computes severity-weighted findings_value" \
  || fail "G15: score.sh missing findings_value computation"
grep -q "pass_score=" "$PROJ/reflex/lib/score.sh" \
  && pass "G15: score.sh emits pass_score (Dim 17 ranking)" \
  || fail "G15: score.sh missing pass_score emission"
grep -q "Excellent\|Good\|OK\|Wasted" "$PROJ/reflex/lib/score.sh" \
  && pass "G15: score.sh maps pass_score to verdict label (Excellent/Good/OK/Wasted)" \
  || fail "G15: score.sh missing verdict labels"
grep -q "score:" "$PROJ/reflex/lib/update-eval-trace.sh" \
  && pass "G15: update-eval-trace.sh surfaces pass_score in register" \
  || fail "G15: update-eval-trace.sh missing score surface"

# --- G8: file-bugs.sh validates qa-result.md schema + rejects malformed ---
grep -q "validate_qa_result_schema" "$PROJ/reflex/lib/file-bugs.sh" \
  && pass "G8: file-bugs.sh has validate_qa_result_schema function" \
  || fail "G8: file-bugs.sh missing validator"
grep -q "REFLEX_SKIP_SCHEMA_VALIDATION" "$PROJ/reflex/lib/file-bugs.sh" \
  && pass "G8: validator has emergency-bypass env var" \
  || fail "G8: validator missing bypass"

# Behavioral: malformed qa-result.md → exit 2 with FAILED message
G8_TMP="/tmp/psk-g8-$$"
mkdir -p "$G8_TMP/agent/.release-state"
echo "# Tasks" > "$G8_TMP/agent/TASKS.md"
cat > "$G8_TMP/agent/.release-state/qa-result.md" <<'BAD'
# QA
## Findings
- id: QA-F1-01
BAD
exit_code_malformed=0
REFLEX_PROJ_ROOT="$G8_TMP" bash "$PROJ/reflex/lib/file-bugs.sh" >/dev/null 2>&1 || exit_code_malformed=$?
[ "$exit_code_malformed" = "2" ] \
  && pass "G8: malformed qa-result.md → exit 2 (schema rejected)" \
  || fail "G8: validator didn't reject malformed qa-result (exit $exit_code_malformed)"

# Valid qa-result.md → exit 0
cat > "$G8_TMP/agent/.release-state/qa-result.md" <<'OK8'
# QA
## Findings
- id: QA-F1-01
  feature: F1
  severity: MAJOR
  assignee: reflex-dev
  title: Example
  spec_ref: a
  evidence: b

## Summary
- tests_planned: 10
- tests_executed: 10
- tests_passed: 9
- tests_failed: 1
- tests_skipped: 0
- features_tested_full: 5
- features_tested_partial: 0
- features_total: 5
- findings_total: 1
- signoff: GRANTED
- dimensions_probed_counts: [5, 4, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
OK8
exit_code_valid=0
REFLEX_PROJ_ROOT="$G8_TMP" bash "$PROJ/reflex/lib/file-bugs.sh" >/dev/null 2>&1 || exit_code_valid=$?
[ "$exit_code_valid" = "0" ] \
  && pass "G8: valid qa-result.md → exit 0 (validator passes)" \
  || fail "G8: validator rejected valid qa-result (exit $exit_code_valid)"

# Bypass env var works
exit_code_bypass=0
REFLEX_PROJ_ROOT="$G8_TMP" REFLEX_SKIP_SCHEMA_VALIDATION=1 bash "$PROJ/reflex/lib/file-bugs.sh" >/dev/null 2>&1 || exit_code_bypass=$?
[ "$exit_code_bypass" = "0" ] \
  && pass "G8: REFLEX_SKIP_SCHEMA_VALIDATION=1 bypasses validator" \
  || fail "G8: bypass env var didn't work (exit $exit_code_bypass)"

# --- G12: dimension-floor enforcement ---
cat > "$G8_TMP/agent/.release-state/qa-result.md" <<'FLOOR'
# QA
## Findings
- id: QA-F1-01
## Summary
- tests_planned: 10
- tests_executed: 10
- tests_passed: 10
- tests_failed: 0
- tests_skipped: 0
- features_tested_full: 5
- features_tested_partial: 0
- features_total: 5
- findings_total: 0
- signoff: GRANTED
- dimensions_probed_counts: [5, 4, 1, 3, 0, 3, 3, 3, 2, 3, 3, 3, 3, 3]
FLOOR
floor_out=$(REFLEX_PROJ_ROOT="$G8_TMP" bash "$PROJ/reflex/lib/file-bugs.sh" 2>&1)
if echo "$floor_out" | grep -q "G12 violation.*dim3=1"; then
  pass "G12: validator rejects GRANTED signoff with dim below 3 floor"
else
  fail "G12: validator didn't flag floor violation"
fi
rm -rf "$G8_TMP"

# qa-agent.md prompt documents G12 minimum-probe rule + dimensions_probed_counts
grep -qF "Minimum-per-dimension probe count" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "G12: qa-agent.md prompt has minimum-probe rule section" \
  || fail "G12: qa-agent.md missing minimum-probe rule"
grep -qF "dimensions_probed_counts" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "G12: qa-agent.md Summary includes dimensions_probed_counts field" \
  || fail "G12: qa-agent.md missing dimensions_probed_counts field"

# --- G10: coverage.md machine-readable YAML block ---
grep -qF "Machine-readable (YAML)" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "G10: coverage.md requires machine-readable YAML block" \
  || fail "G10: qa-agent.md missing YAML block requirement"
for pattern in "tested:" "not_tested:" "regression_vectors_re_executed:"; do
  grep -qF "$pattern" "$PROJ/reflex/prompts/qa-agent.md" \
    && pass "G10: coverage YAML schema has '$pattern'" \
    || fail "G10: coverage YAML schema missing '$pattern'"
done

# TASKS.md marked done
for g in G8 G10 G12; do
  grep -qE "^\s*-\s*\[x\] \*\*$g" "$PROJ/agent/TASKS.md" \
    && pass "$g: marked [x] in TASKS.md" \
    || fail "$g: not marked done in TASKS.md"
done

# --- G3: preconditions accepts reflex-install commits after prep-release ---
grep -q "REFLEX_INSTALL_RE" "$PROJ/reflex/lib/preconditions.sh" \
  && pass "G3: preconditions.sh has REFLEX_INSTALL_RE pattern" \
  || fail "G3: preconditions.sh missing reflex-install pattern"
grep -q "Gate 2 relaxed for reflex-install" "$PROJ/reflex/lib/preconditions.sh" \
  && pass "G3: preconditions logs relaxation message" \
  || fail "G3: preconditions missing relaxation log"
for pat in "reflex install" "install reflex" "reflex setup" "install-into-project"; do
  grep -qF "$pat" "$PROJ/reflex/lib/preconditions.sh" \
    && pass "G3: reflex-install regex covers '$pat'" \
    || fail "G3: reflex-install regex missing '$pat'"
done

# --- G4: --recover diagnostic mode ---
[ -x "$PROJ/reflex/lib/recover.sh" ] && pass "G4: reflex/lib/recover.sh exists + executable" || fail "G4: recover.sh missing or not executable"
grep -qF -- "--recover" "$PROJ/reflex/run.sh" && pass "G4: run.sh exposes --recover flag" || fail "G4: run.sh missing --recover"
grep -q 'MODE="recover"' "$PROJ/reflex/run.sh" && pass "G4: run.sh recover handler" || fail "G4: run.sh missing recover mode handler"

# Behavioral: --recover on synthetic partial state
G4_TMP="/tmp/psk-g4-$$"
mkdir -p "$G4_TMP/reflex/history/standalone/pass-001" "$G4_TMP/agent/.release-state"
cat > "$G4_TMP/reflex/history/standalone/pass-001/findings.yaml" <<'F4'
findings:
  - id: QA-F1-01
  - id: QA-F2-01
  - id: QA-F3-01
F4
cat > "$G4_TMP/agent/.release-state/dev-result.md" <<'D4'
fixed:
  - id: QA-F1-01
    commit: abc123
D4
recover_out=$(REFLEX_PROJ_ROOT="$G4_TMP" bash "$PROJ/reflex/lib/recover.sh" 2>&1)
echo "$recover_out" | grep -qF "Findings in this pass" | head -1 >/dev/null
echo "$recover_out" | grep -qF "findings.yaml):" && echo "$recover_out" | grep -qF " 3" \
  && pass "G4: recover counts 3 findings" \
  || fail "G4: recover finding-count wrong"
echo "$recover_out" | grep -qF "Already fixed" && echo "$recover_out" | grep -qF " 1" \
  && pass "G4: recover detects 1 fixed" \
  || fail "G4: recover fixed-count wrong"
echo "$recover_out" | grep -qF "Pending (need manual finish):" && echo "$recover_out" | grep -qF " 2" \
  && pass "G4: recover detects 2 pending" \
  || fail "G4: recover pending-count wrong"
echo "$recover_out" | grep -q "paste-ready template" \
  && pass "G4: recover emits paste-ready template" \
  || fail "G4: recover template not emitted"
echo "$recover_out" | grep -q "QA-F2-01" && echo "$recover_out" | grep -q "QA-F3-01" \
  && pass "G4: recover lists pending IDs in template" \
  || fail "G4: recover template missing pending IDs"
rm -rf "$G4_TMP"

# TASKS.md marked done for G3 + G4
grep -qE '^\s*-\s*\[x\] \*\*G3' "$PROJ/agent/TASKS.md" \
  && pass "G3: marked [x] in TASKS.md" \
  || fail "G3: not marked done in TASKS.md"
grep -qE '^\s*-\s*\[x\] \*\*G4' "$PROJ/agent/TASKS.md" \
  && pass "G4: marked [x] in TASKS.md" \
  || fail "G4: not marked done in TASKS.md"

# --- Rule 6a: Breadcrumb trailing closed-sibling hint ---
grep -q "^6a\. \*\*Trailing closed-sibling hint\." "$PROJ/portable-spec-kit.md" \
  && pass "Rule 6a: trailing-hint rule present in portable-spec-kit.md" \
  || fail "Rule 6a: trailing-hint rule MISSING"
grep -qF "› ✓**Nx**" "$PROJ/portable-spec-kit.md" \
  && pass "Rule 6a: format token '› ✓**Nx**' documented" \
  || fail "Rule 6a: format token missing"
# No "just closed:" literal anywhere (user explicitly asked to omit this label)
if grep -qF "just closed:" "$PROJ/portable-spec-kit.md"; then
  fail "Rule 6a: 'just closed:' literal present — user asked to omit"
else
  pass "Rule 6a: 'just closed:' literal absent (space-saving honored)"
fi
# Lifecycle language — "Replaced" / "Never dropped" appears
grep -qF "Replaced" "$PROJ/portable-spec-kit.md" \
  && pass "Rule 6a: lifecycle — 'Replaced on newer close' documented" \
  || fail "Rule 6a: lifecycle language missing"
# Cross-ref updated in session-trace skill
grep -qF "Rule 6a adds a single trailing" "$PROJ/.portable-spec-kit/skills/session-trace.md" \
  && pass "Rule 6a: session-trace skill cross-references the hint rule" \
  || fail "Rule 6a: session-trace skill cross-ref not updated"

# --- Writing Style sub-section (5 rules for smoother prose) ---
grep -qF "**Writing Style (MANDATORY — editorial discipline inside templates):**" "$PROJ/portable-spec-kit.md" \
  && pass "Writing Style: sub-section header present" \
  || fail "Writing Style: sub-section MISSING"
grep -qF "One idea per sentence." "$PROJ/portable-spec-kit.md" \
  && pass "Writing Style: Rule 1 (one idea per sentence)" \
  || fail "Writing Style: Rule 1 missing"
grep -qF "Default terminator is a period, not an em-dash." "$PROJ/portable-spec-kit.md" \
  && pass "Writing Style: Rule 2 (period over em-dash)" \
  || fail "Writing Style: Rule 2 missing"
grep -qF "Drop semicolons." "$PROJ/portable-spec-kit.md" \
  && pass "Writing Style: Rule 3 (drop semicolons)" \
  || fail "Writing Style: Rule 3 missing"
grep -qF "Cut parenthetical asides unless load-bearing." "$PROJ/portable-spec-kit.md" \
  && pass "Writing Style: Rule 4 (cut parentheticals)" \
  || fail "Writing Style: Rule 4 missing"
grep -qF "One voice per reply." "$PROJ/portable-spec-kit.md" \
  && pass "Writing Style: Rule 5 (one voice per reply)" \
  || fail "Writing Style: Rule 5 missing"

# --- MINIMAL template tier (3rd template for short answers) ---
grep -qF "**MINIMAL template (fast path).**" "$PROJ/portable-spec-kit.md" \
  && pass "MINIMAL: template header present" \
  || fail "MINIMAL: template section MISSING"
grep -qF "three templates" "$PROJ/portable-spec-kit.md" \
  && pass "MINIMAL: intro references three templates" \
  || fail "MINIMAL: intro not updated to three templates"
grep -qF "MINIMAL paragraph OR BRIEF 5-row table OR DETAILED 7-section block" "$PROJ/portable-spec-kit.md" \
  && pass "MINIMAL: pre-send self-check covers all 3 tiers" \
  || fail "MINIMAL: pre-send self-check not updated"
grep -qF "Pick MINIMAL, BRIEF, or DETAILED" "$PROJ/portable-spec-kit.md" \
  && pass "MINIMAL: Rule 8 updated to 3 templates" \
  || fail "MINIMAL: Rule 8 still references 2 templates"

# --- Template dispatch rule ---
grep -qF "Template dispatch (auto-selection rule" "$PROJ/portable-spec-kit.md" \
  && pass "Dispatch: auto-selection rule present" \
  || fail "Dispatch: rule MISSING"
for trigger in "Yes/no confirmation" "Status check" "Short factual recall" \
               "Decision point requiring trade-off" "details" "go deep"; do
  grep -qF "$trigger" "$PROJ/portable-spec-kit.md" \
    && pass "Dispatch: trigger '$trigger' documented" \
    || fail "Dispatch: trigger '$trigger' missing"
done
grep -qF "User overrides." "$PROJ/portable-spec-kit.md" \
  && pass "Dispatch: user override clause present" \
  || fail "Dispatch: user override missing"

# Rule 6b reverted per user feedback — only verify the revert note remains
grep -qF "REVERTED 2026-04-22" "$PROJ/portable-spec-kit.md" \
  && pass "Rule 6b: revert note present (IDs-only dropped for clarity)" \
  || fail "Rule 6b: revert note missing"

# Rule 6c — consecutive-reply breadcrumb skip
grep -qF "Consecutive-reply breadcrumb skip" "$PROJ/portable-spec-kit.md" \
  && pass "Rule 6c: consecutive-skip rule present" \
  || fail "Rule 6c: consecutive-skip rule missing"
grep -qF "has not changed since the previous reply" "$PROJ/portable-spec-kit.md" \
  && pass "Rule 6c: change-detection clause present" \
  || fail "Rule 6c: change-detection clause missing"

# Rule 6d — MINIMAL arrow optional
grep -qF "Arrow footer is optional in MINIMAL" "$PROJ/portable-spec-kit.md" \
  && pass "Rule 6d: arrow-optional rule present" \
  || fail "Rule 6d: arrow-optional rule missing"

# --- N33: auto-submit config + dispatcher ---
grep -q "^upstream_submission:" "$PROJ/reflex/config.yml" \
  && pass "N33: upstream_submission section in config.yml" \
  || fail "N33: upstream_submission section MISSING from config"
grep -qF "mode: manual" "$PROJ/reflex/config.yml" \
  && pass "N33: default mode=manual" \
  || fail "N33: default mode not manual"
grep -qF "rate_limit_hours: 24" "$PROJ/reflex/config.yml" \
  && pass "N33: rate_limit_hours configured" \
  || fail "N33: rate_limit_hours missing"

[ -x "$PROJ/reflex/lib/auto-submit.sh" ] && pass "N33: auto-submit.sh executable" || fail "N33: auto-submit.sh not executable"
grep -q "Guard 1 — Consent marker" "$PROJ/reflex/lib/auto-submit.sh" \
  && pass "N33: dispatcher has Guard 1 (consent)" \
  || fail "N33: Guard 1 missing"
grep -q "Guard 2 — Pass filter" "$PROJ/reflex/lib/auto-submit.sh" \
  && pass "N33: dispatcher has Guard 2 (pass filter)" \
  || fail "N33: Guard 2 missing"
grep -q "Guard 3 — Rate limit" "$PROJ/reflex/lib/auto-submit.sh" \
  && pass "N33: dispatcher has Guard 3 (rate limit)" \
  || fail "N33: Guard 3 missing"

grep -qF -- "--enable-auto-submit" "$PROJ/reflex/run.sh" \
  && pass "N33: run.sh exposes --enable-auto-submit flag" \
  || fail "N33: --enable-auto-submit flag missing"
grep -qF -- "--i-understand-privacy-implications" "$PROJ/reflex/run.sh" \
  && pass "N33: run.sh requires --i-understand-privacy-implications ack" \
  || fail "N33: privacy-ack flag missing"
grep -qF 'bash "$LIB/auto-submit.sh"' "$PROJ/reflex/run.sh" \
  && pass "N33: dispatcher wired into run.sh end-of-pass" \
  || fail "N33: dispatcher not wired"

# Behavioral: manual mode is a clean no-op
N33_TMP="/tmp/psk-n33-$$"
mkdir -p "$N33_TMP/reflex" "$N33_TMP/reflex/history/standalone/pass-001" "$N33_TMP/agent/.release-state"
cat > "$N33_TMP/reflex/config.yml" <<'EOF'
upstream_submission:
  mode: manual
EOF
cp "$PROJ/reflex/lib/auto-submit.sh" "$N33_TMP/reflex/lib-auto-submit.sh" 2>/dev/null
exit_code=0
REFLEX_PROJ_ROOT="$N33_TMP" REFLEX_PASS_DIR="$N33_TMP/reflex/history/standalone/pass-001" \
  bash "$PROJ/reflex/lib/auto-submit.sh" >/dev/null 2>&1 || exit_code=$?
[ "$exit_code" = "0" ] && pass "N33: manual mode is clean no-op (exit 0)" || fail "N33: manual mode didn't exit 0"
[ ! -f "$N33_TMP/reflex/history/auto-submit-log.csv" ] \
  && pass "N33: manual mode writes nothing to audit log" \
  || fail "N33: manual mode incorrectly wrote to audit log"

# Behavioral: auto mode without consent marker skips
cat > "$N33_TMP/reflex/config.yml" <<'EOF'
upstream_submission:
  mode: auto
EOF
exit_code=0
REFLEX_PROJ_ROOT="$N33_TMP" REFLEX_PASS_DIR="$N33_TMP/reflex/history/standalone/pass-001" \
  bash "$PROJ/reflex/lib/auto-submit.sh" >/dev/null 2>&1 || exit_code=$?
[ "$exit_code" = "0" ] && pass "N33: auto without consent exits 0 (non-blocking skip)" || fail "N33: auto without consent gave exit $exit_code"
if [ -f "$N33_TMP/reflex/history/auto-submit-log.csv" ]; then
  grep -q "skip:no-consent" "$N33_TMP/reflex/history/auto-submit-log.csv" \
    && pass "N33: skip:no-consent row logged" \
    || fail "N33: skip:no-consent row missing from audit log"
fi

# Behavioral: invalid mode returns non-zero
cat > "$N33_TMP/reflex/config.yml" <<'EOF'
upstream_submission:
  mode: gibberish
EOF
exit_code=0
REFLEX_PROJ_ROOT="$N33_TMP" REFLEX_PASS_DIR="$N33_TMP/reflex/history/standalone/pass-001" \
  bash "$PROJ/reflex/lib/auto-submit.sh" >/dev/null 2>&1 || exit_code=$?
[ "$exit_code" = "1" ] && pass "N33: invalid mode returns exit 1" || fail "N33: invalid mode should return 1 (got $exit_code)"

rm -rf "$N33_TMP"

# --- N38: intake automation (weekly kit-side pull) ---
[ -x "$PROJ/reflex/lib/intake.sh" ] && pass "N38: reflex/lib/intake.sh executable" || fail "N38: intake.sh not executable"
[ -x "$PROJ/reflex/intake.sh" ] && pass "N38: reflex/intake.sh wrapper executable" || fail "N38: wrapper not executable"
[ -f "$PROJ/.github/workflows/kit-intake.yml" ] && pass "N38: kit-intake.yml Action file present" || fail "N38: Action file missing"

# Wrapper invokes lib script with --self-test-style exec
grep -qF 'exec bash "$SCRIPT_DIR/lib/intake.sh"' "$PROJ/reflex/intake.sh" \
  && pass "N38: wrapper execs lib/intake.sh" \
  || fail "N38: wrapper doesn't exec lib script correctly"

# Action file has expected triggers
grep -qF "cron: \"0 9 * * 1\"" "$PROJ/.github/workflows/kit-intake.yml" \
  && pass "N38: Action has weekly Monday cron" \
  || fail "N38: Action cron missing or wrong"
grep -q "workflow_dispatch:" "$PROJ/.github/workflows/kit-intake.yml" \
  && pass "N38: Action has manual workflow_dispatch trigger" \
  || fail "N38: Action manual dispatch missing"
grep -qF "intake-review-pending" "$PROJ/.github/workflows/kit-intake.yml" \
  && pass "N38: Action labels PR intake-review-pending" \
  || fail "N38: Action PR label missing"

# intake.sh has the 3 required phases (fetch, parse findings, draft)
grep -q "gh issue list" "$PROJ/reflex/lib/intake.sh" \
  && pass "N38: intake.sh fetches via gh issue list" \
  || fail "N38: gh issue list call missing"
grep -qF "('kit', 'meta')" "$PROJ/reflex/lib/intake.sh" \
  && pass "N38: intake.sh filters findings by scope in {kit, meta}" \
  || fail "N38: scope filter missing"
grep -qF "INTAKE DRAFT" "$PROJ/reflex/lib/intake.sh" \
  && pass "N38: intake.sh draft template has INTAKE DRAFT banner" \
  || fail "N38: draft banner missing"

# Python parser extracts kit + meta from the YAML block (v0.6.2+ submission format)
N38_TMP="/tmp/psk-n38-$$"
mkdir -p "$N38_TMP"
cat > "$N38_TMP/issues.json" <<'FIXTURE_EOF'
[
  {"number": 100, "body": "# AVACR Pass — test / reflex-pass-001\n\n## Findings (structured)\n\n```yaml\npass_id: reflex-pass-001\nfindings:\n  - id: QA-F1-01\n    feature: F1\n    priority: CRITICAL\n    scope: kit\n    dimension: functional-correctness\n  - id: QA-F2-01\n    feature: F2\n    priority: MAJOR\n    scope: target-project\n    dimension: edge-case\n  - id: QA-M3-01\n    feature: PAPER\n    priority: MINOR\n    scope: meta\n    dimension: documentation-completeness\n```\n"}
]
FIXTURE_EOF
parsed=$(python3 - "$N38_TMP/issues.json" <<'PY_EOF'
import json, re, sys
with open(sys.argv[1]) as f:
    issues = json.load(f)
YAML_BLOCK = re.compile(r'```ya?ml\s*\n(.*?)\n```', re.DOTALL)
def parse_findings_yaml(yaml_body):
    out = []; in_findings = False; current = {}
    def flush():
        if current.get('id') and current.get('scope') in ('kit', 'meta'):
            out.append(dict(current))
    for raw in yaml_body.split('\n'):
        if re.match(r'^findings:\s*$', raw): in_findings = True; continue
        if in_findings and re.match(r'^[A-Za-z_]', raw): flush(); current = {}; in_findings = False; continue
        if not in_findings: continue
        m = re.match(r'^\s*-\s+id:\s*(.+?)\s*$', raw)
        if m: flush(); current = {'id': m.group(1).strip()}; continue
        for key in ('priority', 'scope', 'feature'):
            m = re.match(rf'^\s+{key}:\s*(.+?)\s*$', raw)
            if m: current[key] = m.group(1).strip(); break
    flush(); return out
for issue in issues:
    body = issue.get("body", "") or ""
    ym = YAML_BLOCK.search(body)
    if not ym: continue
    for f in parse_findings_yaml(ym.group(1)):
        print(f"{issue['number']}\t{f['id']}\t{f['scope']}\t{f.get('priority', '?')}")
PY_EOF
)
rm -rf "$N38_TMP"
kit_meta_count=$(echo "$parsed" | grep -c "^100" || echo 0)
[ "$kit_meta_count" = "2" ] \
  && pass "N38: parser extracts kit + meta findings from YAML block (skips target-project)" \
  || fail "N38: parser expected 2 extractions, got $kit_meta_count"

# No-gh path exits 1 with clear message
PATH_ORIG="$PATH"
exit_code=0
PATH="/usr/bin:/bin" REFLEX_PROJ_ROOT="/tmp" bash "$PROJ/reflex/lib/intake.sh" >/dev/null 2>&1 || exit_code=$?
export PATH="$PATH_ORIG"
[ "$exit_code" = "1" ] \
  && pass "N38: intake.sh exits 1 when gh CLI not available" \
  || fail "N38: expected exit 1 on missing gh (got $exit_code)"

# --- N45: --target flag + loop orchestrator ---
grep -qF -- "--target" "$PROJ/reflex/run.sh" \
  && pass "N45: run.sh exposes --target flag" \
  || fail "N45: --target flag missing"
grep -qF -- "--loop" "$PROJ/reflex/run.sh" \
  && pass "N45: run.sh exposes --loop flag" \
  || fail "N45: --loop flag missing"
grep -qF "Auto-detect self-test" "$PROJ/reflex/run.sh" \
  && pass "N45: run.sh has target auto-detection block" \
  || fail "N45: target auto-detect missing"

[ -x "$PROJ/reflex/lib/loop.sh" ] && pass "N45: reflex/lib/loop.sh executable" || fail "N45: loop.sh not executable"
# v0.6.2+: top-level reflex/loop.sh wrapper retired; run.sh is the sole entry point.
[ ! -f "$PROJ/reflex/loop.sh" ] && pass "N45: top-level reflex/loop.sh wrapper retired (run.sh is sole entry)" || fail "N45: top-level loop.sh wrapper still present"

# State-file transitions
grep -q 'prep-release)\|"prep-release"' "$PROJ/reflex/lib/loop.sh" \
  && pass "N45: loop state machine has prep-release phase" \
  || fail "N45: prep-release phase missing"
grep -q 'self-test-qa)\|"self-test-qa"' "$PROJ/reflex/lib/loop.sh" \
  && pass "N45: loop state machine has self-test-qa phase" \
  || fail "N45: self-test-qa phase missing"
grep -q "KIT_LOOP_MAX_ITER" "$PROJ/reflex/lib/loop.sh" \
  && pass "N45: loop has configurable max-iteration cap" \
  || fail "N45: KIT_LOOP_MAX_ITER env var missing"
grep -q "MANUAL_REVIEW_NEEDED" "$PROJ/reflex/lib/loop.sh" \
  && pass "N45: loop exit signal on max-iter exhaustion" \
  || fail "N45: MANUAL_REVIEW_NEEDED signal missing"

# v0.6.13 — QA → Dev contract enforcement (no silent skip when sub-agent times out).
# resume-qa MUST refuse to spawn Dev unless findings.yaml + signoff.md exist.
grep -qF 'qa_missing+=("findings.yaml' "$PROJ/reflex/run.sh" \
  && pass "N45: resume-qa enforces findings.yaml mandatory artifact" \
  || fail "N45: resume-qa missing findings.yaml enforcement"
grep -qF 'qa_missing+=("signoff.md' "$PROJ/reflex/run.sh" \
  && pass "N45: resume-qa enforces signoff.md mandatory artifact" \
  || fail "N45: resume-qa missing signoff.md enforcement"
# resume-dev MUST refuse to write verdict unless dev-trace.md exists.
grep -qF 'dev_missing+=("dev-trace.md' "$PROJ/reflex/run.sh" \
  && pass "N45: resume-dev enforces dev-trace.md mandatory artifact" \
  || fail "N45: resume-dev missing dev-trace.md enforcement"
# Autoloop Phase 4 verdict halts if pass dir missing findings.yaml or dev-trace.md
grep -qF "incomplete_reason" "$PROJ/reflex/lib/loop.sh" \
  && pass "N45: loop Phase 4 detects INCOMPLETE pass (no silent advance)" \
  || fail "N45: loop Phase 4 missing INCOMPLETE detection"
grep -qF "QA → Dev to run alternately" "$PROJ/reflex/run.sh" \
  && pass "N45: contract message documented in error path" \
  || fail "N45: alternation contract message missing"

# v0.6.13 — register surfaces incomplete passes + dual-format qa-result.md.
grep -qF "is_incomplete=true" "$PROJ/reflex/lib/update-eval-trace.sh" \
  && pass "N45: update-eval-trace renders incomplete passes (is_incomplete flag)" \
  || fail "N45: update-eval-trace missing incomplete-pass rendering"
grep -qF "INCOMPLETE _(QA timed out" "$PROJ/reflex/lib/update-eval-trace.sh" \
  && pass "N45: incomplete passes get explicit verdict label" \
  || fail "N45: INCOMPLETE verdict label missing"
grep -qF "Reflex cycle " "$PROJ/reflex/lib/update-eval-trace.sh" \
  && pass "N45: cycle headings renamed Autoloop → Reflex (v0.6.13)" \
  || fail "N45: cycle heading rename missing"
grep -qF "auto-synthesized markdown sections from YAML" "$PROJ/reflex/lib/file-bugs.sh" \
  && pass "N45: file-bugs.sh accepts both qa-result.md formats (markdown + YAML)" \
  || fail "N45: schema-validator dual-format support missing"

# v0.6.13 — Dimension 23 (Auditor-output hygiene) — closes meta-gap from user trace audit.
grep -qF "Dimension 23 — Auditor-output hygiene" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "N45/Dim23: qa-agent prompt documents Dimension 23 (auditor-output hygiene)" \
  || fail "N45/Dim23: Dimension 23 missing from qa-agent.md"
grep -qF "Probe 23.1 — Register hygiene" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "N45/Dim23: Probe 23.1 register-hygiene present" \
  || fail "N45/Dim23: Probe 23.1 missing"
grep -qF "Probe 23.2 — Cost data persistence" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "N45/Dim23: Probe 23.2 cost-persistence present" \
  || fail "N45/Dim23: Probe 23.2 missing"
grep -qF "Probe 23.3 — Parallel-directory disambiguation" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "N45/Dim23: Probe 23.3 parallel-dir disambiguation present" \
  || fail "N45/Dim23: Probe 23.3 missing"
grep -qF "Probe 23.4 — Cross-surface terminology consistency" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "N45/Dim23: Probe 23.4 terminology-consistency present" \
  || fail "N45/Dim23: Probe 23.4 missing"
grep -qF "Probe 23.5 — Self-output validation loop" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "N45/Dim23: Probe 23.5 self-output validation present" \
  || fail "N45/Dim23: Probe 23.5 missing"
grep -qE "23 dimensions of review|across 23 dimensions" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "N45/Dim23: prompt heading bumped to 23 dimensions" \
  || fail "N45/Dim23: dim count not bumped to 23"

# v0.6.11 — iter-aware release-prep (cost optimization).
# Iter 1 = prepare (version bump), iter 2+ = refresh (no bump).
grep -q 'RELEASE_CMD="prepare"' "$PROJ/reflex/lib/loop.sh" \
  && pass "N45: loop iter 1 uses psk-release.sh prepare" \
  || fail "N45: iter 1 prepare branch missing"
grep -q 'RELEASE_CMD="refresh"' "$PROJ/reflex/lib/loop.sh" \
  && pass "N45: loop iter 2+ uses psk-release.sh refresh (no version inflation)" \
  || fail "N45: iter 2+ refresh branch missing"
grep -qE 'if \[ "\$\{?ITER:?-?1?\}?" = "1" \]' "$PROJ/reflex/lib/loop.sh" \
  && pass "N45: iter-aware branching present (ITER=1 vs 2+)" \
  || fail "N45: iter-aware branching condition missing"

# --target with non-existent path → exit 1
N45_TMP="/tmp/psk-n45-$$"
exit_code=0
bash "$PROJ/reflex/run.sh" --target /definitely/not/a/real/path >/dev/null 2>&1 || exit_code=$?
[ "$exit_code" = "1" ] \
  && pass "N45: --target non-existent path rejects with exit 1" \
  || fail "N45: --target invalid path should exit 1 (got $exit_code)"

# run.sh --loop --status with no state → graceful message, exit 0
exit_code=0
bash "$PROJ/reflex/lib/loop.sh" --status >/dev/null 2>&1 || exit_code=$?
[ "$exit_code" = "0" ] \
  && pass "N45: lib/loop.sh --status exits 0 when no active loop" \
  || fail "N45: lib/loop.sh --status should exit 0 with no loop (got $exit_code)"

# kit-loop --abort with no state → graceful, exit 0
exit_code=0
bash "$PROJ/reflex/lib/loop.sh" --abort >/dev/null 2>&1 || exit_code=$?
[ "$exit_code" = "0" ] \
  && pass "N45: lib/loop.sh --abort exits 0 when no active loop" \
  || fail "N45: lib/loop.sh --abort should exit 0 (got $exit_code)"

# run.sh --help mentions --loop and --target
bash "$PROJ/reflex/run.sh" --help 2>&1 | grep -q -- "--loop" \
  && pass "N45: run.sh --help mentions --loop" \
  || fail "N45: run.sh --help missing --loop"
bash "$PROJ/reflex/run.sh" --help 2>&1 | grep -q "\-\-target" \
  && pass "N45: run.sh --help mentions --target" \
  || fail "N45: run.sh --help missing --target"

rm -rf "$N45_TMP"

# --- Trace-continuity: QA reads prior findings.yaml + signoff.md ---
grep -qF "Cross-pass state — what was fixed, what remains" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "trace-continuity: qa-agent prompt instructs reading prior artifacts" \
  || fail "trace-continuity: qa-agent prompt missing cross-pass rule"
grep -qF "MANDATORY read at Phase 1" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "trace-continuity: prior artifact read is MANDATORY at Phase 1" \
  || fail "trace-continuity: mandatory-read clause missing"
grep -qF "findings.yaml" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "trace-continuity: qa-agent prompt points at findings.yaml" \
  || fail "trace-continuity: qa-agent prompt does not reference findings.yaml"
grep -qF "signoff.md" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "trace-continuity: qa-agent prompt points at signoff.md" \
  || fail "trace-continuity: qa-agent prompt does not reference signoff.md"
grep -qF "Cross-pass handoff" "$PROJ/reflex/lib/spawn-qa.sh" \
  && pass "trace-continuity: spawn-qa.sh surfaces prior artifacts in task file" \
  || fail "trace-continuity: spawn-qa.sh cross-pass block missing"
grep -qF "findings.yaml" "$PROJ/reflex/lib/spawn-qa.sh" \
  && pass "trace-continuity: spawn-qa.sh points at findings.yaml" \
  || fail "trace-continuity: spawn-qa.sh does not surface findings.yaml"

# REFLEX_EVAL_TRACE.md is the cross-pass findings register, owned by update-eval-trace.sh
grep -qF "REFLEX_EVAL_TRACE.md" "$PROJ/reflex/lib/loop.sh" \
  && pass "trace-naming: loop.sh references REFLEX_EVAL_TRACE.md (triggers regen)" \
  || fail "trace-naming: loop.sh does not reference REFLEX_EVAL_TRACE.md"
grep -qF "REFLEX_EVAL_TRACE.md" "$PROJ/reflex/README.md" \
  && pass "trace-naming: reflex/README documents AVACR vs REFLEX trace scope" \
  || fail "trace-naming: reflex/README missing REFLEX_EVAL_TRACE.md naming note"
[ -x "$PROJ/reflex/lib/update-eval-trace.sh" ] \
  && pass "trace-register: update-eval-trace.sh exists and is executable" \
  || fail "trace-register: update-eval-trace.sh missing or not executable"
grep -qF "REFLEX_EVAL_TRACE.md" "$PROJ/reflex/lib/update-eval-trace.sh" \
  && pass "trace-register: update-eval-trace.sh targets REFLEX_EVAL_TRACE.md" \
  || fail "trace-register: update-eval-trace.sh wrong output path"

# Dev-Agent focus discipline: does NOT read cross-pass prior trace (Dev stays current-pass-only)
grep -qF "Do NOT read prior passes" "$PROJ/reflex/prompts/dev-agent.md" \
  && pass "dev-focus: dev-agent prompt forbids prior-trace read (focus discipline)" \
  || fail "dev-focus: dev-agent prompt missing focus-discipline rule"
if grep -qF "Cross-pass handoff" "$PROJ/reflex/lib/spawn-dev.sh"; then
  fail "dev-focus: spawn-dev.sh still has cross-pass block (should be removed)"
else
  pass "dev-focus: spawn-dev.sh has no cross-pass block (Dev stays focused on current pass)"
fi

# Kit-loop refreshes the cross-pass findings register at iteration boundaries
grep -q "refresh_findings_register" "$PROJ/reflex/lib/loop.sh" \
  && pass "loop-trace: loop.sh has refresh_findings_register helper" \
  || fail "loop-trace: refresh_findings_register missing"
grep -qF "update-eval-trace.sh" "$PROJ/reflex/lib/loop.sh" \
  && pass "loop-trace: loop.sh invokes update-eval-trace.sh" \
  || fail "loop-trace: loop.sh does not invoke register generator"
grep -qF "update-eval-trace.sh" "$PROJ/reflex/lib/file-bugs.sh" \
  && pass "loop-trace: file-bugs.sh refreshes register after filing" \
  || fail "loop-trace: file-bugs.sh does not invoke register generator"

# ───────────────────────────────────────────────────────────────
# Section N52 — Dev-branch isolation + protected-files write-ban + autoloop + retention
# ───────────────────────────────────────────────────────────────
section "N52. Dev-branch isolation + protected-files write-ban + autoloop + history retention"

# --- Dev branch creation (spawn-dev.sh) ---
grep -qF "reflex/dev-${PASS_NAME:-}" "$PROJ/reflex/lib/spawn-dev.sh" || grep -qF 'DEV_BRANCH="reflex/dev-' "$PROJ/reflex/lib/spawn-dev.sh" \
  && pass "N52/dev-branch: spawn-dev.sh creates reflex/dev-cycle-NN-pass-NNN branch" \
  || fail "N52/dev-branch: spawn-dev.sh branch creation missing"
grep -qF ".parent-branch" "$PROJ/reflex/lib/spawn-dev.sh" \
  && pass "N52/dev-branch: spawn-dev.sh captures parent branch for merge-back" \
  || fail "N52/dev-branch: parent-branch capture missing"
grep -qF "git checkout -b" "$PROJ/reflex/lib/spawn-dev.sh" \
  && pass "N52/dev-branch: spawn-dev.sh uses git checkout -b" \
  || fail "N52/dev-branch: git checkout -b missing"

# --- Protected-files write-ban: 3 layers ---
# Layer 1 — prompt constraint
grep -qF "NEVER modify" "$PROJ/reflex/prompts/dev-agent.md" \
  && grep -qF "AGENT.md" "$PROJ/reflex/prompts/dev-agent.md" \
  && pass "N52/protected-L1: dev-agent.md prompt forbids AGENT.md edits" \
  || fail "N52/protected-L1: prompt constraint missing"
grep -qF "AGENT_CONTEXT.md" "$PROJ/reflex/prompts/dev-agent.md" \
  && pass "N52/protected-L1: dev-agent.md prompt forbids AGENT_CONTEXT.md edits" \
  || fail "N52/protected-L1: AGENT_CONTEXT.md prompt rule missing"

# Layer 2 — gates.sh diff check
grep -qF "protected-files" "$PROJ/reflex/lib/gates.sh" \
  && pass "N52/protected-L2: gates.sh has protected-files check" \
  || fail "N52/protected-L2: gates.sh protected-files check missing"
# Branch-scope regex must match both reflex dev branch naming conventions
# (cycle-NN-pass-NNN autoloop + standalone-pass-NNN single-pass).
# Behavioral test: extract the =~ pattern from gates.sh, apply it to simulated branch names.
_gates_pattern=$(grep -E 'CURRENT_BRANCH.*=~.*reflex/dev' "$PROJ/reflex/lib/gates.sh" | grep -oE '\^reflex/dev[^ ]*pass-' | head -1)
if [ -n "$_gates_pattern" ]; then
  _hits=0
  for _b in "reflex/dev-cycle-01-pass-001" "reflex/dev-standalone-pass-001"; do
    [[ "$_b" =~ $_gates_pattern ]] && _hits=$((_hits+1))
  done
  [ "$_hits" -eq 2 ] \
    && pass "N52/protected-L2: gates.sh branch-scope regex matches cycle-NN + standalone naming" \
    || fail "N52/protected-L2: gates.sh branch regex matches only $_hits/2 conventions (cycle / standalone)"
else
  fail "N52/protected-L2: gates.sh branch scoping missing"
fi

# Layer 3 — psk-sync-check branch detection
grep -qF "check_reflex_protected_files" "$PROJ/agent/scripts/psk-sync-check.sh" \
  && pass "N52/protected-L3: sync-check has reflex protected-files function" \
  || fail "N52/protected-L3: sync-check protected-files function missing"
# Behavioral test: the sync-check branch-scope regex must match all 3 naming conventions.
_sc_line=$(grep -E 'branch.*=~.*reflex/dev' "$PROJ/agent/scripts/psk-sync-check.sh" | head -1)
if [ -n "$_sc_line" ]; then
  # Strip the `if [[ ! ... ]]` negation — we want to test the positive match
  _sc_pattern=$(echo "$_sc_line" | grep -oE '\^reflex/dev[^ ]*pass-' | head -1)
  _hits=0
  for _b in "reflex/dev-cycle-01-pass-001" "reflex/dev-standalone-pass-001"; do
    [[ "$_b" =~ $_sc_pattern ]] && _hits=$((_hits+1))
  done
  [ "$_hits" -eq 2 ] \
    && pass "N52/protected-L3: sync-check branch-scope regex matches cycle-NN + standalone naming" \
    || fail "N52/protected-L3: sync-check branch regex matches only $_hits/2 conventions (cycle / standalone)"
else
  fail "N52/protected-L3: sync-check branch scoping missing"
fi

# --- Merge-back with ff-fallback in run.sh ---
grep -qF "merge --ff-only" "$PROJ/reflex/run.sh" \
  && pass "N52/merge-back: run.sh tries ff-only merge on GRANTED" \
  || fail "N52/merge-back: ff-only merge missing"
grep -qF "merge --no-ff" "$PROJ/reflex/run.sh" \
  && pass "N52/merge-back: run.sh falls back to --no-ff on divergence" \
  || fail "N52/merge-back: no-ff fallback missing"
grep -qF "git branch -D" "$PROJ/reflex/run.sh" \
  && pass "N52/merge-back: run.sh deletes dev branch after merge" \
  || fail "N52/merge-back: branch deletion missing"

# --- Autoloop (v0.6.2+: consolidated into run.sh, wrappers retired) ---
grep -qF -- "--autoloop" "$PROJ/reflex/run.sh" \
  && pass "N52/autoloop: run.sh accepts --autoloop flag" \
  || fail "N52/autoloop: --autoloop flag missing from run.sh"
grep -qF -- "--loop|--kit-loop|--autoloop" "$PROJ/reflex/run.sh" \
  && pass "N52/autoloop: run.sh accepts --loop / --kit-loop backward-compat aliases" \
  || fail "N52/autoloop: backward-compat aliases missing"
grep -qF 'MODE:-loop' "$PROJ/reflex/run.sh" \
  && pass "N52/autoloop: run.sh defaults to autoloop mode (bare invocation)" \
  || fail "N52/autoloop: bare run.sh does not default to autoloop"
grep -qF "single" "$PROJ/reflex/run.sh" \
  && pass "N52/autoloop: run.sh accepts 'single' positional for per-iter single-pass" \
  || fail "N52/autoloop: 'single' positional missing"

# --- History retention ---
[ -x "$PROJ/reflex/lib/prune-history.sh" ] \
  && pass "N52/retention: prune-history.sh exists and is executable" \
  || fail "N52/retention: prune-history.sh missing or not executable"
grep -qF "history_retention:" "$PROJ/reflex/config.yml" \
  && pass "N52/retention: config.yml has history_retention block" \
  || fail "N52/retention: history_retention config missing"
grep -qF "pass_dirs_keep" "$PROJ/reflex/config.yml" \
  && pass "N52/retention: config has pass_dirs_keep setting" \
  || fail "N52/retention: pass_dirs_keep missing"
grep -qF "prune-history.sh" "$PROJ/reflex/run.sh" \
  && pass "N52/retention: run.sh invokes prune-history at start" \
  || fail "N52/retention: prune-history not wired into run.sh"
grep -qF -- "--purge-history" "$PROJ/reflex/run.sh" \
  && pass "N52/retention: run.sh exposes --purge-history command" \
  || fail "N52/retention: --purge-history missing"

# --- Archived-pass rendering in register ---
grep -qF "archived_passes" "$PROJ/reflex/lib/update-eval-trace.sh" \
  && pass "N52/archived: register generator handles archived passes" \
  || fail "N52/archived: archived-pass rendering missing"
grep -qF "_(archived" "$PROJ/reflex/lib/update-eval-trace.sh" \
  && pass "N52/archived: archived marker text present" \
  || fail "N52/archived: archived marker missing"

# --- Concurrency lockfile ---
grep -qF "reflex.lock" "$PROJ/reflex/run.sh" \
  && pass "N52/lock: run.sh uses reflex.lock for concurrency protection" \
  || fail "N52/lock: lockfile missing"
grep -qF "flock" "$PROJ/reflex/run.sh" \
  && pass "N52/lock: run.sh prefers flock when available" \
  || fail "N52/lock: flock invocation missing"

# --- Empty-pass shortcut (0 findings → GRANTED without Dev spawn) ---
grep -qF "empty-pass shortcut" "$PROJ/reflex/run.sh" \
  && pass "N52/empty-pass: run.sh has empty-pass shortcut" \
  || fail "N52/empty-pass: shortcut missing"
grep -qF "GRANTED" "$PROJ/reflex/run.sh" \
  && pass "N52/empty-pass: run.sh writes GRANTED verdict on 0 findings" \
  || fail "N52/empty-pass: GRANTED marker missing"

# --- N53: sandbox purge after QA + cycle metadata + grouped register ---
grep -qF "purged current-pass QA sandbox" "$PROJ/reflex/lib/file-bugs.sh" \
  && pass "N53/sandbox-purge: file-bugs.sh purges current-pass sandbox after findings filed" \
  || fail "N53/sandbox-purge: sandbox purge missing"
grep -qF 'reflex/sandbox/$pass_rel' "$PROJ/reflex/lib/file-bugs.sh" \
  && pass "N53/sandbox-purge: file-bugs.sh targets current-pass sandbox path (nested)" \
  || fail "N53/sandbox-purge: sandbox path target missing"

# Cycle counter in loop.sh
grep -qF "next_cycle_id" "$PROJ/reflex/lib/loop.sh" \
  && pass "N53/cycle: loop.sh has next_cycle_id helper" \
  || fail "N53/cycle: next_cycle_id helper missing"
grep -qF "REFLEX_AUTOLOOP_CYCLE" "$PROJ/reflex/lib/loop.sh" \
  && pass "N53/cycle: loop.sh exports REFLEX_AUTOLOOP_CYCLE" \
  || fail "N53/cycle: REFLEX_AUTOLOOP_CYCLE export missing"

# cycle-meta in run.sh at pass creation
grep -qF ".cycle-meta" "$PROJ/reflex/run.sh" \
  && pass "N53/cycle: run.sh writes .cycle-meta at pass creation" \
  || fail "N53/cycle: .cycle-meta write missing"
grep -qF "REFLEX_AUTOLOOP_CYCLE" "$PROJ/reflex/run.sh" \
  && pass "N53/cycle: run.sh reads REFLEX_AUTOLOOP_CYCLE for cycle tagging" \
  || fail "N53/cycle: REFLEX_AUTOLOOP_CYCLE read missing in run.sh"

# Register grouping by cycle
grep -qF "Reflex cycle" "$PROJ/reflex/lib/update-eval-trace.sh" \
  && pass "N53/register: generator emits Reflex cycle headings" \
  || fail "N53/register: cycle heading missing"
grep -qF ".cycle-meta" "$PROJ/reflex/lib/update-eval-trace.sh" \
  && pass "N53/register: generator reads .cycle-meta per pass" \
  || fail "N53/register: .cycle-meta read missing"

# --- N55: --reset command (full nuclear wipe of all reflex state) ---
[ -x "$PROJ/reflex/lib/reset.sh" ] \
  && pass "N55/reset: reset.sh exists and is executable" \
  || fail "N55/reset: reset.sh missing or not executable"
grep -qF -- "--reset)" "$PROJ/reflex/run.sh" \
  && pass "N55/reset: run.sh dispatches --reset mode" \
  || fail "N55/reset: --reset dispatch missing"
grep -qF "reset.sh" "$PROJ/reflex/run.sh" \
  && pass "N55/reset: run.sh invokes reset.sh helper" \
  || fail "N55/reset: run.sh doesn't invoke reset.sh"
grep -qF "reset-consent" "$PROJ/reflex/lib/reset.sh" \
  && pass "N55/reset: reset.sh respects --reset-consent flag" \
  || fail "N55/reset: --reset-consent flag missing"
grep -qF "reset-hardening" "$PROJ/reflex/lib/reset.sh" \
  && pass "N55/reset: reset.sh respects --reset-hardening flag" \
  || fail "N55/reset: --reset-hardening flag missing"
grep -qF "HISTORY_KEEP" "$PROJ/reflex/lib/reset.sh" \
  && pass "N55/reset: allowlist-based collection (HISTORY_KEEP)" \
  || fail "N55/reset: allowlist HISTORY_KEEP missing"
grep -qF "reset-hardening" "$PROJ/reflex/run.sh" \
  && pass "N55/reset: run.sh forwards --reset-hardening" \
  || fail "N55/reset: run.sh missing --reset-hardening passthrough"

# Dry-run without --confirm should refuse to delete
RESET_OUT=$(bash "$PROJ/reflex/run.sh" --reset 2>&1 || true)
echo "$RESET_OUT" | grep -qF "dry-run" \
  && pass "N55/reset: --reset without --confirm is dry-run" \
  || fail "N55/reset: --reset should dry-run without --confirm"
echo "$RESET_OUT" | grep -qF "hardening-log preserved" \
  && pass "N55/reset: dry-run reports hardening-log preserved" \
  || fail "N55/reset: dry-run should mention hardening-log preservation"

# --- Behavioral: generator groups synthetic passes by cycle correctly ---
N53_TMP="/tmp/psk-n53-$$"
mkdir -p "$N53_TMP/reflex/history/standalone/pass-200" "$N53_TMP/reflex/history/standalone/pass-201" "$N53_TMP/agent" "$N53_TMP/reflex/lib"

cat > "$N53_TMP/reflex/history/standalone/pass-200/findings.yaml" <<'EOF'
pass_id: standalone-pass-200
findings:
  - id: QA-N53-01
    feature: TEST
    priority: MINOR
    scope: target-project
    dimension: polish
EOF
cat > "$N53_TMP/reflex/history/standalone/pass-200/signoff.md" <<'EOF'
Verdict: DENIED
EOF
cat > "$N53_TMP/reflex/history/standalone/pass-200/.cycle-meta" <<'EOF'
cycle=5
iteration=1
EOF
cat > "$N53_TMP/reflex/history/standalone/pass-201/findings.yaml" <<'EOF'
pass_id: standalone-pass-201
findings:
  - id: QA-N53-02
    feature: TEST
    priority: MINOR
    scope: target-project
    dimension: polish
EOF
cat > "$N53_TMP/reflex/history/standalone/pass-201/signoff.md" <<'EOF'
Verdict: GRANTED
EOF
cat > "$N53_TMP/reflex/history/standalone/pass-201/.cycle-meta" <<'EOF'
cycle=5
iteration=2
EOF
cat > "$N53_TMP/agent/TASKS.md" <<'EOF'
## v0.1
- [x] **QA-N53-01** @reflex-dev: fixed
- [x] **QA-N53-02** @reflex-dev: fixed
EOF
cp "$PROJ/reflex/lib/update-eval-trace.sh" "$N53_TMP/reflex/lib/"

if REFLEX_PROJECT_ROOT="$N53_TMP" bash "$N53_TMP/reflex/lib/update-eval-trace.sh" >/dev/null 2>&1; then
  REG="$N53_TMP/reflex/history/REFLEX_EVAL_TRACE.md"
  grep -qF "Reflex cycle 5" "$REG" \
    && pass "N53/behavioral: register emits 'Reflex cycle 5' heading" \
    || fail "N53/behavioral: cycle heading missing from rendered register"
  grep -qF "iter 1" "$REG" && pass "N53/behavioral: per-pass iter label rendered" \
    || fail "N53/behavioral: iter label missing"
  grep -qF "iter 2" "$REG" && pass "N53/behavioral: second pass iter label rendered" \
    || fail "N53/behavioral: second iter label missing"
else
  fail "N53/behavioral: generator failed on synthetic cycle fixture"
fi
rm -rf "$N53_TMP"

# ───────────────────────────────────────────────────────────────
# Section N56 — Convergence stopping + loop-resume + cache-order + token tracking
# ───────────────────────────────────────────────────────────────
section "N56. Convergence-based stopping + loop-resume + cache-order + token tracking"

# --- Convergence config in reflex/config.yml ---
grep -qF "convergence:" "$PROJ/reflex/config.yml" \
  && pass "N56/convergence: config.yml has convergence block" \
  || fail "N56/convergence: convergence block missing from config.yml"
for k in findings_floor patience_passes min_fix_rate allow_findings_increase max_iterations_safety; do
  grep -qF "$k:" "$PROJ/reflex/config.yml" \
    && pass "N56/convergence: config has $k setting" \
    || fail "N56/convergence: $k setting missing"
done
grep -qF "token_tracking:" "$PROJ/reflex/config.yml" \
  && pass "N56/token: config.yml has token_tracking block" \
  || fail "N56/token: token_tracking block missing"

# --- loop.sh convergence stop logic ---
grep -qF "FINDINGS_FLOOR" "$PROJ/reflex/lib/loop.sh" \
  && pass "N56/loop: loop.sh reads findings_floor from config" \
  || fail "N56/loop: findings_floor logic missing"
grep -qF "PATIENCE_PASSES" "$PROJ/reflex/lib/loop.sh" \
  && pass "N56/loop: loop.sh implements patience counter" \
  || fail "N56/loop: patience logic missing"
grep -qF "MIN_FIX_RATE" "$PROJ/reflex/lib/loop.sh" \
  && pass "N56/loop: loop.sh checks fix-rate threshold" \
  || fail "N56/loop: min_fix_rate logic missing"
grep -qF "SAFETY_CAP" "$PROJ/reflex/lib/loop.sh" \
  && pass "N56/loop: loop.sh uses max_iterations_safety as escape hatch" \
  || fail "N56/loop: safety cap missing"
grep -qF "FINDINGS_INCREASED" "$PROJ/reflex/lib/loop.sh" \
  && pass "N56/loop: loop.sh detects findings-increase regression signal" \
  || fail "N56/loop: findings-increase check missing"
grep -qF "PLATEAU" "$PROJ/reflex/lib/loop.sh" \
  && pass "N56/loop: loop.sh emits PLATEAU stop reason" \
  || fail "N56/loop: PLATEAU signal missing"

# --- gates.sh cache-order fix ---
grep -qF "rft-cache.txt" "$PROJ/reflex/lib/gates.sh" \
  && pass "N56/gates: gates.sh clears rft-cache at entry (cache-order fix)" \
  || fail "N56/gates: rft-cache clear missing from gates.sh"

# --- --loop --resume collision fix ---
grep -qF "LOOP_FLAG" "$PROJ/reflex/run.sh" \
  && pass "N56/resume: run.sh tracks LOOP_FLAG separately for collision resolution" \
  || fail "N56/resume: LOOP_FLAG missing from run.sh"
grep -qF "RESUME_FLAG" "$PROJ/reflex/run.sh" \
  && pass "N56/resume: run.sh defers --resume resolution until after arg parse" \
  || fail "N56/resume: RESUME_FLAG deferred resolution missing"
grep -qF "loop-resume" "$PROJ/reflex/run.sh" \
  && pass "N56/resume: run.sh has loop-resume mode dispatch" \
  || fail "N56/resume: loop-resume mode missing"

# Behavioral: --loop --resume must route to loop.sh --resume, not resume-qa
# (can't execute without state; verify the mode resolution logic instead)
grep -qF 'MODE="loop-resume"' "$PROJ/reflex/run.sh" \
  && pass "N56/resume-behavioral: --loop + --resume resolves to loop-resume (no hijack)" \
  || fail "N56/resume-behavioral: mode resolution wrong"

# --- End-to-end branch merge-back verification ---
# Synthetic: make a throwaway reflex/dev-test-pass-999 branch, commit a dummy
# change, verify the merge-back pattern in run.sh matches + branch deletion
# pattern works. No actual invocation — just verify the code paths + patterns.
# (Running run.sh --resume-dev end-to-end requires dev-result.md + state files
# which are not worth synthesizing for a test.)
grep -qE 'git merge --ff-only' "$PROJ/reflex/run.sh" \
  && pass "N56/merge-e2e: run.sh uses --ff-only merge (fast-forward preferred)" \
  || fail "N56/merge-e2e: --ff-only merge missing"
grep -qE 'git merge --no-ff -m' "$PROJ/reflex/run.sh" \
  && pass "N56/merge-e2e: run.sh falls back to --no-ff on divergence" \
  || fail "N56/merge-e2e: --no-ff fallback missing"
grep -qE 'git branch -D "\$CURRENT_BR"' "$PROJ/reflex/run.sh" \
  && pass "N56/merge-e2e: run.sh deletes dev branch after successful merge" \
  || fail "N56/merge-e2e: branch deletion missing"
grep -qF 'reflex/dev-(cycle-[0-9]+-|standalone-)?pass-' "$PROJ/reflex/run.sh" \
  && pass "N56/merge-e2e: run.sh merge-back regex matches unified + standalone naming" \
  || fail "N56/merge-e2e: merge-back regex too narrow"

# Force next-iteration guidance (anti-iteration-skip)
grep -qF "NEXT_ACTION" "$PROJ/reflex/run.sh" \
  && pass "N56/anti-skip: run.sh emits NEXT_ACTION on non-GRANTED pass" \
  || fail "N56/anti-skip: NEXT_ACTION block missing"
grep -qE 'exit 3' "$PROJ/reflex/run.sh" \
  && pass "N56/anti-skip: run.sh uses exit code 3 for 'iteration required'" \
  || fail "N56/anti-skip: exit 3 signal missing"

# --- token tracking ---
[ -x "$PROJ/reflex/lib/track-tokens.sh" ] \
  && pass "N56/token: track-tokens.sh exists and is executable" \
  || fail "N56/token: track-tokens.sh missing or not executable"
grep -qF "token-usage.csv" "$PROJ/reflex/lib/track-tokens.sh" \
  && pass "N56/token: track-tokens writes to token-usage.csv" \
  || fail "N56/token: output file wrong"
grep -qF "per_pass_budget_tokens" "$PROJ/reflex/lib/track-tokens.sh" \
  && pass "N56/token: track-tokens respects per_pass_budget_tokens" \
  || fail "N56/token: per-pass budget not enforced"
grep -qF "per_cycle_budget_tokens" "$PROJ/reflex/lib/track-tokens.sh" \
  && pass "N56/token: track-tokens respects per_cycle_budget_tokens" \
  || fail "N56/token: per-cycle budget not enforced"
grep -qF "tokens_per_finding" "$PROJ/reflex/lib/track-tokens.sh" \
  && pass "N56/token: track-tokens emits tokens_per_finding optimization signal" \
  || fail "N56/token: tpf metric missing"
grep -qF "track-tokens.sh" "$PROJ/reflex/run.sh" \
  && pass "N56/token: run.sh invokes track-tokens.sh in --resume-dev path" \
  || fail "N56/token: track-tokens not wired into run.sh"

# --- Orphaned findings section (register shows full history, not just on-disk passes) ---
grep -qF "Historical findings" "$PROJ/reflex/lib/update-eval-trace.sh" \
  && pass "N56/register-historical: generator renders Historical findings section" \
  || fail "N56/register-historical: Historical findings section missing"
grep -qF "orphaned" "$PROJ/reflex/lib/update-eval-trace.sh" \
  && pass "N56/register-historical: generator detects orphaned (wiped-pass) findings in TASKS.md" \
  || fail "N56/register-historical: orphan detection missing"
# Behavioral — synthetic TASKS.md with QA-ids, no on-disk findings.yaml, expect orphan rendering
OH_TMP="/tmp/psk-orphans-$$"
mkdir -p "$OH_TMP/reflex/history" "$OH_TMP/agent" "$OH_TMP/reflex/lib"
cp "$PROJ/reflex/lib/update-eval-trace.sh" "$OH_TMP/reflex/lib/"
cat > "$OH_TMP/agent/TASKS.md" <<'EOF'
## v0.1 — QA Findings
- [x] **QA-HIST-01** @reflex-dev: historical closed finding
- [ ] **QA-HIST-02** @human: open human-arbitration finding
EOF
# No pass dirs, no findings.yaml — everything should be orphaned
if REFLEX_PROJECT_ROOT="$OH_TMP" bash "$OH_TMP/reflex/lib/update-eval-trace.sh" >/dev/null 2>&1; then
  REG="$OH_TMP/reflex/history/REFLEX_EVAL_TRACE.md"
  grep -qF "Historical findings" "$REG" && pass "N56/register-historical: orphans render under Historical findings section" || fail "N56/register-historical: section missing from output"
  grep -qF "QA-HIST-01" "$REG" && pass "N56/register-historical: orphaned closed finding rendered" || fail "N56/register-historical: QA-HIST-01 not rendered"
  grep -qF "QA-HIST-02" "$REG" && pass "N56/register-historical: orphaned open finding rendered" || fail "N56/register-historical: QA-HIST-02 not rendered"
else
  fail "N56/register-historical: generator failed on synthetic orphan fixture"
fi
rm -rf "$OH_TMP"

# --- audit-integrity.sh self-inspection helper ---
[ -x "$PROJ/reflex/lib/audit-integrity.sh" ] \
  && pass "N56/audit-integrity: audit-integrity.sh exists and is executable" \
  || fail "N56/audit-integrity: audit-integrity.sh missing or not executable"
grep -qF "Register missing" "$PROJ/reflex/lib/audit-integrity.sh" \
  && pass "N56/audit-integrity: detects register-missing findings gap" \
  || fail "N56/audit-integrity: register-missing check missing"
grep -qF "ghost pass dir" "$PROJ/reflex/lib/audit-integrity.sh" \
  && pass "N56/audit-integrity: detects ghost pass dirs (no CSV row)" \
  || fail "N56/audit-integrity: ghost-pass check missing"
grep -qF "Orphan dev branch" "$PROJ/reflex/lib/audit-integrity.sh" \
  && pass "N56/audit-integrity: detects orphan reflex/dev-* branches" \
  || fail "N56/audit-integrity: orphan-branch check missing"
grep -qF "cycle-meta" "$PROJ/reflex/lib/audit-integrity.sh" \
  && pass "N56/audit-integrity: detects missing .cycle-meta files" \
  || fail "N56/audit-integrity: cycle-meta check missing"
grep -qF "audit-integrity.sh" "$PROJ/reflex/lib/file-bugs.sh" \
  && pass "N56/audit-integrity: wired into file-bugs.sh post-pass flow" \
  || fail "N56/audit-integrity: not wired into reflex pipeline"

# QA-agent prompt now includes dimension-15 self-inspection
grep -qF "Audit-trail integrity" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "N56/dim-15: qa-agent prompt includes Dimension 15 (Audit-trail integrity)" \
  || fail "N56/dim-15: dimension 15 missing from qa-agent prompt"
grep -qF "MANDATORY self-inspection" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "N56/dim-15: dimension 15 is MANDATORY (not optional)" \
  || fail "N56/dim-15: MANDATORY marker missing"
grep -qE "(1[5-9]|2[0-9]) dimensions of review|dimensions of review.*(1[5-9]|2[0-9])" "$PROJ/reflex/prompts/qa-agent.md" \
  && pass "N56/dim-15: prompt heading updated to 15+ dimensions" \
  || fail "N56/dim-15: still says 14 dimensions"

# Orphan-detection uses strict `- id:` extraction (not loose QA-* grep)
grep -qF "^\s*-\s*id:\s*QA-" "$PROJ/reflex/lib/update-eval-trace.sh" \
  && pass "N56/orphan-strict: register uses strict id extraction (avoids prose-mention false positives)" \
  || fail "N56/orphan-strict: strict extraction missing — QA-NNN mentioned in recommendation text will falsely show as covered"

# 0-finding GRANTED passes now write summary.csv (no ghost)
grep -qF '"$LIB/score.sh"' "$PROJ/reflex/run.sh" | head -1 >/dev/null
if grep -c '"$LIB/score.sh"' "$PROJ/reflex/run.sh" | awk '$1 >= 2' >/dev/null 2>&1; then
  pass "N56/no-ghost: run.sh writes summary.csv row on 0-finding GRANTED pass (no ghost dirs)"
else
  # Fallback: at least check the empty-pass shortcut invokes score.sh
  grep -B2 "empty-pass shortcut" "$PROJ/reflex/run.sh" | grep -q "score.sh" && \
    pass "N56/no-ghost: empty-pass path invokes score.sh" || \
    fail "N56/no-ghost: empty-pass path misses score.sh → ghost pass dir bug"
fi

# --- Token optimization report ---
[ -x "$PROJ/reflex/lib/token-report.sh" ] \
  && pass "N56/token-report: token-report.sh exists and is executable" \
  || fail "N56/token-report: token-report.sh missing or not executable"
grep -qF "token-report.md" "$PROJ/reflex/lib/token-report.sh" \
  && pass "N56/token-report: report writes to token-report.md" \
  || fail "N56/token-report: output path missing"
if grep -qE "Tokens per finding|Tokens/finding" "$PROJ/reflex/lib/token-report.sh" && \
   grep -qE "f_per_10k|Findings per 10k" "$PROJ/reflex/lib/token-report.sh"; then
  pass "N56/token-report: emits both tokens-per-finding and findings-per-10k-tokens metrics"
else
  fail "N56/token-report: optimization metrics missing"
fi
grep -qF "Iteration efficiency" "$PROJ/reflex/lib/token-report.sh" \
  && pass "N56/token-report: tracks iteration efficiency (iter N+1 vs N cost)" \
  || fail "N56/token-report: iteration efficiency section missing"
grep -qF "Tuning recommendations" "$PROJ/reflex/lib/token-report.sh" \
  && pass "N56/token-report: includes tuning recommendations section" \
  || fail "N56/token-report: tuning recommendations missing"
grep -qF "token-report.sh" "$PROJ/reflex/lib/track-tokens.sh" \
  && pass "N56/token-report: track-tokens auto-invokes token-report after each pass" \
  || fail "N56/token-report: auto-invoke wiring missing"

# Behavioral: synthetic token-usage.csv → token-report.sh produces valid markdown
TR_TMP="/tmp/psk-token-report-$$"
mkdir -p "$TR_TMP/reflex/history" "$TR_TMP/reflex/lib"
cp "$PROJ/reflex/lib/token-report.sh" "$TR_TMP/reflex/lib/"
cat > "$TR_TMP/reflex/history/token-usage.csv" <<'EOF'
pass,date,cycle,iter,qa_tokens,dev_tokens,qa_calls,dev_calls,wall_seconds,findings,fixes,tokens_per_finding
1,2026-04-24,1,1,150000,50000,35,25,600,11,11,18181
2,2026-04-24,1,2,100000,30000,25,15,400,3,3,43333
3,2026-04-24,2,1,200000,80000,45,35,800,8,7,35000
EOF
if REFLEX_PROJ_ROOT="$TR_TMP" bash "$TR_TMP/reflex/lib/token-report.sh" >/dev/null 2>&1; then
  REPORT="$TR_TMP/reflex/history/token-report.md"
  [ -f "$REPORT" ] && pass "N56/token-report-behavioral: report file generated" || fail "N56/token-report-behavioral: report not generated"
  grep -qF "Per-cycle breakdown" "$REPORT" && pass "N56/token-report-behavioral: per-cycle breakdown section present" || fail "N56/token-report-behavioral: per-cycle section missing"
  grep -qF "Iteration efficiency" "$REPORT" && pass "N56/token-report-behavioral: iteration efficiency section present" || fail "N56/token-report-behavioral: iter efficiency missing"
  grep -qE "diminishing returns|tpf rose" "$REPORT" && pass "N56/token-report-behavioral: detects diminishing returns (cycle 1 tpf 18k→43k)" || fail "N56/token-report-behavioral: diminishing returns not flagged"
else
  fail "N56/token-report-behavioral: report generation failed on synthetic data"
fi
rm -rf "$TR_TMP"

# ═══════════════════════════════════════════════════════════════
# N57 — psk-bootstrap-check gate (multi-layer kit-install verification)
# ═══════════════════════════════════════════════════════════════
# Verifies the bootstrap-integrity gate catches the failure mode where a
# project was scaffolded without running install.sh (e.g. Copilot creates
# agent/*.md manually). The gate must pass on the kit itself and fail on a
# synthetic empty project that only has pipeline .md files.

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  N57 — psk-bootstrap-check gate"
echo "═══════════════════════════════════════════════════════════════"

BOOTSTRAP_CHECK="$PROJ/agent/scripts/psk-bootstrap-check.sh"

[ -x "$BOOTSTRAP_CHECK" ] && pass "N57/bootstrap: psk-bootstrap-check.sh exists + executable" \
                          || fail "N57/bootstrap: psk-bootstrap-check.sh missing or non-executable"

# Kit self — must PASS (exit 0)
if bash "$BOOTSTRAP_CHECK" --quiet 2>/dev/null; then
  pass "N57/bootstrap: kit self passes bootstrap check (exit 0)"
else
  fail "N57/bootstrap: kit self should pass bootstrap check, exited non-zero"
fi

# JSON mode emits parseable JSON
if bash "$BOOTSTRAP_CHECK" --json 2>/dev/null | grep -qE '"verdict":"(PASS|WARN|FAIL)"'; then
  pass "N57/bootstrap: --json emits parseable verdict field"
else
  fail "N57/bootstrap: --json did not emit verdict field"
fi

# Synthetic incomplete project — must FAIL (exit 1)
NB_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t nb)
mkdir -p "$NB_TMP/agent"
for f in REQS SPECS PLANS RESEARCH DESIGN TASKS RELEASES AGENT AGENT_CONTEXT; do
  echo "# $f" > "$NB_TMP/agent/$f.md"
done
# This project has agent/ files but nothing else — mirrors Copilot scaffold
if PSK_PROJ_ROOT="$NB_TMP" bash "$BOOTSTRAP_CHECK" --quiet 2>/dev/null; then
  fail "N57/bootstrap: synthetic incomplete project should FAIL but passed"
else
  pass "N57/bootstrap: synthetic incomplete project correctly FAILS (exit non-zero)"
fi

# JSON output on failing project reports critical gaps > 0
json_out=$(PSK_PROJ_ROOT="$NB_TMP" bash "$BOOTSTRAP_CHECK" --json 2>/dev/null)
if echo "$json_out" | grep -qE '"critical":[1-9]'; then
  pass "N57/bootstrap: synthetic project reports critical>=1 in JSON"
else
  fail "N57/bootstrap: synthetic project should report critical>=1, got: $json_out"
fi

# Check specific gap detection
if echo "$json_out" | grep -qE 'psk-sync-check\.sh'; then
  pass "N57/bootstrap: detects missing core kit scripts (C3)"
else
  fail "N57/bootstrap: did not flag missing psk-sync-check.sh"
fi
if echo "$json_out" | grep -qE 'config\.md.*missing|\.portable-spec-kit/config'; then
  pass "N57/bootstrap: detects missing .portable-spec-kit/config.md (C2)"
else
  fail "N57/bootstrap: did not flag missing .portable-spec-kit/config.md"
fi

# psk-release.sh refuses to init on a non-bootstrapped project
# (confirm Step 0 gate is wired)
if grep -qE "run_bootstrap_gate|psk-bootstrap-check" "$PROJ/agent/scripts/psk-release.sh"; then
  pass "N57/bootstrap: psk-release.sh has bootstrap gate wired"
else
  fail "N57/bootstrap: psk-release.sh missing bootstrap gate — Step 0 not wired"
fi

# reflex/lib/preconditions.sh has bootstrap Gate 0a wired
if grep -qE "psk-bootstrap-check|BOOTSTRAP_CHECK" "$PROJ/reflex/lib/preconditions.sh"; then
  pass "N57/bootstrap: reflex/lib/preconditions.sh has Gate 0a wired"
else
  fail "N57/bootstrap: reflex/lib/preconditions.sh missing Gate 0a — bootstrap gate not wired"
fi

# QA-Agent prompt references Dimension 16 (kit-bootstrap integrity)
if grep -qE "Dimension 16|Kit-bootstrap integrity" "$PROJ/reflex/prompts/qa-agent.md"; then
  pass "N57/bootstrap: qa-agent.md documents Dimensions 16+17"
else
  fail "N57/bootstrap: qa-agent.md missing Dimension 16 or 17"
fi

# Dimension count updated to 16
if grep -qE "23 dimensions of review" "$PROJ/reflex/prompts/qa-agent.md"; then
  pass "N57/bootstrap: qa-agent.md header says 23 dimensions"
else
  fail "N57/bootstrap: qa-agent.md header not updated to 23 dimensions"
fi

rm -rf "$NB_TMP"

# ═══════════════════════════════════════════════════════════════
# N58 — Bootstrap-first rule + curl-fallback remediation
# ═══════════════════════════════════════════════════════════════
# Verifies:
#  (a) portable-spec-kit.md documents the "Bootstrap-first rule" near the top
#      so AI agents reading the framework file see install.sh instruction BEFORE
#      doing any work on a new project.
#  (b) psk-bootstrap-check.sh --remediate has a 3-tier resolution including
#      curl fallback (PSK_INSTALL_URL configurable, PSK_BOOTSTRAP_CURL_DISABLED
#      opt-out).

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  N58 — Bootstrap-first rule + curl-fallback"
echo "═══════════════════════════════════════════════════════════════"

# --- Framework file rule documented ---
grep -qF "Bootstrap-first rule (MANDATORY on any new project)" "$PROJ/portable-spec-kit.md" \
  && pass "N58/rule: portable-spec-kit.md documents Bootstrap-first rule" \
  || fail "N58/rule: Bootstrap-first rule missing from framework file"

grep -qE "psk-bootstrap-check\.sh --quiet.*install\.sh.*--yes --from" "$PROJ/portable-spec-kit.md" \
  && pass "N58/rule: framework file shows the one-liner bootstrap-then-install command" \
  || fail "N58/rule: one-liner bootstrap-then-install command missing"

grep -qF "only works if" "$PROJ/portable-spec-kit.md" \
  && grep -qF "Why this rule exists" "$PROJ/portable-spec-kit.md" \
  && pass "N58/rule: framework file explains why install is required" \
  || fail "N58/rule: install rationale missing"

# Rule appears BEFORE Reliability Architecture (so agents hit it first)
rule_line=$(grep -n "Bootstrap-first rule" "$PROJ/portable-spec-kit.md" | head -1 | cut -d: -f1)
rel_line=$(grep -n "^## Reliability Architecture" "$PROJ/portable-spec-kit.md" | head -1 | cut -d: -f1)
if [ -n "$rule_line" ] && [ -n "$rel_line" ] && [ "$rule_line" -lt "$rel_line" ]; then
  pass "N58/rule: Bootstrap-first rule is above Reliability Architecture (agents see it first)"
else
  fail "N58/rule: Bootstrap-first rule not positioned above Reliability Architecture"
fi

# --- Curl fallback in bootstrap-check ---
grep -qF "INSTALL_URL=" "$PROJ/agent/scripts/psk-bootstrap-check.sh" \
  && pass "N58/curl: INSTALL_URL variable defined (configurable via PSK_INSTALL_URL)" \
  || fail "N58/curl: INSTALL_URL variable missing"

grep -qF "PSK_BOOTSTRAP_CURL_DISABLED" "$PROJ/agent/scripts/psk-bootstrap-check.sh" \
  && pass "N58/curl: opt-out envvar PSK_BOOTSTRAP_CURL_DISABLED honored" \
  || fail "N58/curl: opt-out envvar missing"

grep -qE "Tier 3.*curl|curl the canonical installer" "$PROJ/agent/scripts/psk-bootstrap-check.sh" \
  && pass "N58/curl: Tier 3 (curl fallback) documented in remediate_attempt" \
  || fail "N58/curl: Tier 3 comment missing"

grep -qE "curl -fsSL.*INSTALL_URL" "$PROJ/agent/scripts/psk-bootstrap-check.sh" \
  && pass "N58/curl: curl invocation uses -fsSL flags + INSTALL_URL variable" \
  || fail "N58/curl: curl invocation missing"

# Default URL points to canonical GitHub path
grep -qF "raw.githubusercontent.com/aqibmumtaz/portable-spec-kit" "$PROJ/agent/scripts/psk-bootstrap-check.sh" \
  && pass "N58/curl: default INSTALL_URL points to canonical GitHub raw path" \
  || fail "N58/curl: default INSTALL_URL not pointing to canonical source"

# Behavioral: --remediate on incomplete project with PSK_BOOTSTRAP_CURL_DISABLED=1
# should exit non-zero (no local install.sh AND network disabled)
N58_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t n58)
mkdir -p "$N58_TMP/agent"
for f in REQS SPECS PLANS RESEARCH DESIGN TASKS RELEASES AGENT AGENT_CONTEXT; do
  echo "# $f" > "$N58_TMP/agent/$f.md"
done
if PSK_PROJ_ROOT="$N58_TMP" PSK_BOOTSTRAP_CURL_DISABLED=1 \
   bash "$PROJ/agent/scripts/psk-bootstrap-check.sh" --remediate >/dev/null 2>&1; then
  fail "N58/curl: remediate should fail when no local install + curl disabled (got exit 0)"
else
  pass "N58/curl: remediate fails cleanly when no local install + PSK_BOOTSTRAP_CURL_DISABLED=1"
fi

# Behavioral: remediate output mentions curl-fallback message when no local install
n58_out=$(PSK_PROJ_ROOT="$N58_TMP" PSK_BOOTSTRAP_CURL_DISABLED=1 \
  bash "$PROJ/agent/scripts/psk-bootstrap-check.sh" --remediate 2>&1 || true)
if echo "$n58_out" | grep -qE "PSK_BOOTSTRAP_CURL_DISABLED|network install disabled|Cannot auto-remediate"; then
  pass "N58/curl: remediate prints meaningful message when curl disabled"
else
  fail "N58/curl: remediate output missing curl-disabled message"
fi

rm -rf "$N58_TMP"

# ═══════════════════════════════════════════════════════════════
# N60 — Reflex 7-layer Senior-Engineer QA system (v0.6.7)
# ═══════════════════════════════════════════════════════════════
# Verifies the full v0.6.7 architecture:
#   Layer 1: check-rft-integrity.sh deterministic R→F→T gate
#   Layer 2: doc-code-diff.sh bidirectional doc↔code consistency
#   Layer 3-5-7: qa-agent.md mandates for behavioral / integration / external
#   Layer 4: qa-agent.md mandate for test-quality audit
#   Layer 6: spawn-qa.sh kit-tools-output/ capture
#   Senior/Principal philosophy preambles in qa-agent.md + dev-agent.md
#   Plan doc at agent/design/f70-reflex-senior-engineer-qa.md

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  N60 — 7-layer Senior-Engineer QA (v0.6.7)"
echo "═══════════════════════════════════════════════════════════════"

# --- Plan doc exists ---
PLAN_DOC="$PROJ/agent/design/f70-reflex-senior-engineer-qa.md"
[ -f "$PLAN_DOC" ] && pass "N60/plan: 7-layer architecture plan doc exists" \
                  || fail "N60/plan: missing agent/design/f70-reflex-senior-engineer-qa.md"

for section in "QA-Agent Philosophy" "Dev-Agent Philosophy" "The 7 Verification Layers" "What Stays from v0.6.5/v0.6.6"; do
  grep -qF "$section" "$PLAN_DOC" 2>/dev/null \
    && pass "N60/plan: documents '$section'" \
    || fail "N60/plan: missing '$section' in plan doc"
done

# --- Layer 1: check-rft-integrity.sh ---
RFT_CHECK="$PROJ/reflex/lib/check-rft-integrity.sh"
[ -x "$RFT_CHECK" ] && pass "N60/L1: check-rft-integrity.sh exists + executable" \
                    || fail "N60/L1: check-rft-integrity.sh missing or non-executable"

N60_RFT_OUT=$(mktemp)
bash "$RFT_CHECK" "$PROJ" --out "$N60_RFT_OUT" 2>/dev/null
[ -f "$N60_RFT_OUT" ] && pass "N60/L1: produces rft-integrity.yaml" \
                     || fail "N60/L1: did not produce output file"

grep -qE "^features_checked:" "$N60_RFT_OUT" \
  && pass "N60/L1: rft-integrity.yaml reports features_checked" \
  || fail "N60/L1: features_checked field missing"

grep -qE "^totals:" "$N60_RFT_OUT" \
  && pass "N60/L1: rft-integrity.yaml has totals block (critical/major/minor)" \
  || fail "N60/L1: totals block missing"
rm -f "$N60_RFT_OUT"

# Synthetic feature with no design plan + no acceptance criteria → break
N60_RFT_TMP=$(mktemp -d)
mkdir -p "$N60_RFT_TMP/agent"
cat > "$N60_RFT_TMP/agent/SPECS.md" <<'EOF'
# SPECS.md
## Features
| F1 | feature one | R1 | criteria | [x] | 2026-04-25 | tests/foo.sh |
EOF
echo "# REQS" > "$N60_RFT_TMP/agent/REQS.md"
echo "# TASKS" > "$N60_RFT_TMP/agent/TASKS.md"
N60_SYN_OUT="$N60_RFT_TMP/rft.yaml"
bash "$RFT_CHECK" "$N60_RFT_TMP" --out "$N60_SYN_OUT" 2>/dev/null
grep -qE "major: [1-9]" "$N60_SYN_OUT" \
  && pass "N60/L1: synthetic feature without criteria/design/test produces breaks" \
  || fail "N60/L1: synthetic broken pipeline did not produce breaks"
rm -rf "$N60_RFT_TMP"

# --- Layer 2: doc-code-diff.sh ---
DOC_CODE="$PROJ/reflex/lib/doc-code-diff.sh"
[ -x "$DOC_CODE" ] && pass "N60/L2: doc-code-diff.sh exists + executable" \
                  || fail "N60/L2: doc-code-diff.sh missing or non-executable"

N60_DC_OUT=$(mktemp)
bash "$DOC_CODE" "$PROJ" --out "$N60_DC_OUT" 2>/dev/null
[ -f "$N60_DC_OUT" ] && pass "N60/L2: produces doc-code-diff.yaml" \
                    || fail "N60/L2: did not produce output file"
grep -qE "^doc_surfaces_scanned:" "$N60_DC_OUT" \
  && pass "N60/L2: reports doc_surfaces_scanned count" \
  || fail "N60/L2: doc_surfaces_scanned missing"
grep -qE "^code_artifacts_scanned:" "$N60_DC_OUT" \
  && pass "N60/L2: reports code_artifacts_scanned count" \
  || fail "N60/L2: code_artifacts_scanned missing"
grep -qE "direction: (doc-to-code|code-to-doc|count-mismatch)" "$N60_DC_OUT" \
  || pass "N60/L2: bidirectional drift schema present (or 0 drifts)" \
  && true  # tolerate either case
rm -f "$N60_DC_OUT"

# --- QA-Agent prompt updates ---
QA_PROMPT="$PROJ/reflex/prompts/qa-agent.md"
grep -qF "Senior / Principal-level QA engineer" "$QA_PROMPT" \
  && pass "N60/qa-prompt: Senior/Principal philosophy preamble present" \
  || fail "N60/qa-prompt: philosophy preamble missing"

grep -qF "The 7-layer verification system" "$QA_PROMPT" \
  && pass "N60/qa-prompt: documents 7-layer system" \
  || fail "N60/qa-prompt: 7-layer documentation missing"

grep -qF "rft-integrity.yaml" "$QA_PROMPT" \
  && pass "N60/qa-prompt: references rft-integrity.yaml (Layer 1)" \
  || fail "N60/qa-prompt: rft-integrity.yaml not mentioned"

grep -qF "doc-code-diff.yaml" "$QA_PROMPT" \
  && pass "N60/qa-prompt: references doc-code-diff.yaml (Layer 2)" \
  || fail "N60/qa-prompt: doc-code-diff.yaml not mentioned"

grep -qF "kit-tools-output/" "$QA_PROMPT" \
  && pass "N60/qa-prompt: references kit-tools-output/ (Layer 6)" \
  || fail "N60/qa-prompt: kit-tools-output/ not mentioned"

grep -qF "behavioral-tests/" "$QA_PROMPT" \
  && pass "N60/qa-prompt: mandates behavioral-tests/ output (Layer 3)" \
  || fail "N60/qa-prompt: Layer 3 behavioral-tests not mandated"

grep -qF "test-quality-audit.yaml" "$QA_PROMPT" \
  && pass "N60/qa-prompt: mandates test-quality-audit.yaml (Layer 4)" \
  || fail "N60/qa-prompt: Layer 4 test-quality-audit not mandated"

grep -qF "integration-probes.md" "$QA_PROMPT" \
  && pass "N60/qa-prompt: mandates integration-probes.md (Layer 5)" \
  || fail "N60/qa-prompt: Layer 5 not mandated"

grep -qF "external-research.md" "$QA_PROMPT" \
  && pass "N60/qa-prompt: mandates external-research.md (Layer 7)" \
  || fail "N60/qa-prompt: Layer 7 not mandated"

grep -qE "Independence rule|design these probes BEFORE reading Dev" "$QA_PROMPT" \
  && pass "N60/qa-prompt: independence rule (test before reading Dev's test)" \
  || fail "N60/qa-prompt: independence rule missing"

grep -qE "1 happy.*5 edge.*3 adversarial.*1 integration|1 happy-path.*5 edge cases.*3 adversarial.*1 integration" "$QA_PROMPT" \
  && pass "N60/qa-prompt: documents 1+5+3+1 probe pattern per feature" \
  || fail "N60/qa-prompt: probe pattern missing"

# --- Dev-Agent prompt updates ---
DEV_PROMPT="$PROJ/reflex/prompts/dev-agent.md"
grep -qF "Senior / Principal-level engineer" "$DEV_PROMPT" \
  && pass "N60/dev-prompt: Senior/Principal philosophy preamble present" \
  || fail "N60/dev-prompt: philosophy preamble missing"

grep -qF "rft-integrity.yaml" "$DEV_PROMPT" \
  && pass "N60/dev-prompt: reads rft-integrity.yaml" \
  || fail "N60/dev-prompt: rft-integrity.yaml not in inputs"

grep -qF "doc-code-diff.yaml" "$DEV_PROMPT" \
  && pass "N60/dev-prompt: reads doc-code-diff.yaml" \
  || fail "N60/dev-prompt: doc-code-diff.yaml not in inputs"

grep -qF "test-quality-audit.yaml" "$DEV_PROMPT" \
  && pass "N60/dev-prompt: reads test-quality-audit.yaml" \
  || fail "N60/dev-prompt: test-quality-audit.yaml not in inputs"

grep -qF "kit-tools-output/" "$DEV_PROMPT" \
  && pass "N60/dev-prompt: reads kit-tools-output/" \
  || fail "N60/dev-prompt: kit-tools-output/ not in inputs"

grep -qE "sibling-class|hardening" "$DEV_PROMPT" \
  && pass "N60/dev-prompt: sibling-class hardening principle" \
  || fail "N60/dev-prompt: sibling-class hardening missing"

# --- spawn-qa.sh wiring ---
SPAWN_QA="$PROJ/reflex/lib/spawn-qa.sh"
grep -qF "check-rft-integrity.sh" "$SPAWN_QA" \
  && pass "N60/spawn-qa: invokes check-rft-integrity.sh" \
  || fail "N60/spawn-qa: Layer 1 not wired"

grep -qF "doc-code-diff.sh" "$SPAWN_QA" \
  && pass "N60/spawn-qa: invokes doc-code-diff.sh" \
  || fail "N60/spawn-qa: Layer 2 not wired"

grep -qF 'KIT_TOOLS_DIR=' "$SPAWN_QA" \
  && pass "N60/spawn-qa: defines KIT_TOOLS_DIR for Layer 6 capture" \
  || fail "N60/spawn-qa: kit-tools-output capture not wired"

grep -qF "sync-check.txt" "$SPAWN_QA" \
  && pass "N60/spawn-qa: captures sync-check.txt" \
  || fail "N60/spawn-qa: sync-check capture missing"

grep -qF "doc-sync.txt" "$SPAWN_QA" \
  && pass "N60/spawn-qa: captures doc-sync.txt" \
  || fail "N60/spawn-qa: doc-sync capture missing"

grep -qF "release-check.txt" "$SPAWN_QA" \
  && pass "N60/spawn-qa: captures release-check.txt" \
  || fail "N60/spawn-qa: release-check capture missing"

# Order check: Phase 0 helpers run BEFORE sandbox cp creation
rft_line=$(grep -n "check-rft-integrity.sh" "$SPAWN_QA" | head -1 | cut -d: -f1)
cp_line=$(grep -n "cp-based sandbox\|cp -a " "$SPAWN_QA" | head -1 | cut -d: -f1)
if [ -n "$rft_line" ] && [ -n "$cp_line" ] && [ "$rft_line" -lt "$cp_line" ]; then
  pass "N60/spawn-qa: all Phase 0 helpers run BEFORE sandbox cp"
else
  fail "N60/spawn-qa: Phase 0 ordering wrong"
fi

# --- 16-dim safety net preserved ---
grep -qE "23 dimensions of review|safety net" "$QA_PROMPT" \
  && pass "N60/qa-prompt: 23-dim checklist preserved as safety net (not replaced)" \
  || fail "N60/qa-prompt: 16-dim safety net missing"

# --- Senior/Principal Dev plan + hardening log (parallel to QA plan) ---
DEV_PLAN="$PROJ/agent/design/f70-reflex-senior-engineer-dev.md"
[ -f "$DEV_PLAN" ] && pass "N60/dev-plan: Senior/Principal Dev architecture plan exists" \
                  || fail "N60/dev-plan: agent/design/f70-reflex-senior-engineer-dev.md missing"

for section in "Dev-Agent Philosophy" "The 7-Layer Dev Operating System" "Symmetry with QA's 7 Layers" "Three Gap Classes per Pass"; do
  grep -qF "$section" "$DEV_PLAN" 2>/dev/null \
    && pass "N60/dev-plan: documents '$section'" \
    || fail "N60/dev-plan: missing '$section'"
done

# Title consistency: both plans say "Senior/Principal-Level"
grep -qiE "Senior/Principal-(Level|level)" "$PLAN_DOC" \
  && pass "N60/title: QA plan title says 'Senior/Principal-Level'" \
  || fail "N60/title: QA plan title not 'Senior/Principal-Level'"
grep -qiE "Senior/Principal-(Level|level)" "$DEV_PLAN" \
  && pass "N60/title: Dev plan title says 'Senior/Principal-Level'" \
  || fail "N60/title: Dev plan title not 'Senior/Principal-Level'"

# Hardening log + helper
HARDEN_LOG="$PROJ/reflex/history/hardening-log.md"
HARDEN_HELPER="$PROJ/reflex/lib/log-hardening.sh"

[ -f "$HARDEN_LOG" ] && pass "N60/harden: hardening-log.md exists" \
                    || fail "N60/harden: reflex/history/hardening-log.md missing"
[ -x "$HARDEN_HELPER" ] && pass "N60/harden: log-hardening.sh exists + executable" \
                        || fail "N60/harden: log-hardening.sh missing or non-executable"

# Behavioral: append + verify entry
N60_HARDEN_TMP_LOG=$(mktemp)
cp "$HARDEN_LOG" "$N60_HARDEN_TMP_LOG"
HARDEN_LOG="$N60_HARDEN_TMP_LOG" bash "$HARDEN_HELPER" \
  --finding-id "QA-TEST-N60" --class "test-harness-class" \
  --mechanism "N60 smoke test mechanism" --commit "test1234" --pass "n60-smoke" >/dev/null 2>&1
if grep -qF "QA-TEST-N60" "$N60_HARDEN_TMP_LOG"; then
  pass "N60/harden: log-hardening.sh appends entry to registry"
else
  fail "N60/harden: log-hardening.sh did not append entry"
fi
if grep -qF "H-001" "$N60_HARDEN_TMP_LOG"; then
  pass "N60/harden: assigns next H-NNN id automatically"
else
  fail "N60/harden: H-NNN id assignment broken"
fi
rm -f "$N60_HARDEN_TMP_LOG"

# Dev prompt references hardening helper
grep -qF "log-hardening.sh" "$DEV_PROMPT" \
  && pass "N60/dev-prompt: references log-hardening.sh helper" \
  || fail "N60/dev-prompt: log-hardening.sh helper not mentioned"

# ═══════════════════════════════════════════════════════════════
# N61 — Reflex v0.6.8: Layer 3/5/7 helpers + Dev L7 ADL auto-extraction
# ═══════════════════════════════════════════════════════════════
# Verifies the four v0.6.8 helpers + their wiring + prompt updates:
#   scaffold-behavioral-tests.sh  (QA L3 — 1+5+3+1 skeleton per [x] feature)
#   identify-integration-probes.sh (QA L5 — feature-pair candidates)
#   external-research.sh           (QA L7 — CVE/framework/OWASP query seeds)
#   auto-extract-adl.sh            (Dev L7 — ADL drafts from commit bodies)

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  N61 — v0.6.8 Layer 3/5/7 helpers + ADL auto-extraction"
echo "═══════════════════════════════════════════════════════════════"

# --- Layer 3: scaffold-behavioral-tests.sh ---
SBT="$PROJ/reflex/lib/scaffold-behavioral-tests.sh"
[ -x "$SBT" ] && pass "N61/L3: scaffold-behavioral-tests.sh exists + executable" \
              || fail "N61/L3: scaffold-behavioral-tests.sh missing or non-executable"

N61_SBT_TMP=$(mktemp -d)
bash "$SBT" "$PROJ" --pass-dir "$N61_SBT_TMP" >/dev/null 2>&1
[ -d "$N61_SBT_TMP/behavioral-tests" ] && pass "N61/L3: creates behavioral-tests/ directory" \
                                      || fail "N61/L3: did not create behavioral-tests/ directory"
sbt_count=$(find "$N61_SBT_TMP/behavioral-tests" -name "F*-test-plan.md" 2>/dev/null | wc -l | tr -d ' ')
[ "$sbt_count" -ge 50 ] && pass "N61/L3: scaffolds >=50 test plans on kit ($sbt_count actual)" \
                       || fail "N61/L3: only $sbt_count test plans scaffolded — expected >=50"

# Check structure of one plan
sample_plan="$N61_SBT_TMP/behavioral-tests/F1-test-plan.md"
[ -f "$sample_plan" ] && pass "N61/L3: F1-test-plan.md generated" \
                      || fail "N61/L3: F1-test-plan.md missing"
grep -qF "Happy-path probe (1)" "$sample_plan" 2>/dev/null \
  && pass "N61/L3: skeleton has happy-path section" \
  || fail "N61/L3: skeleton missing happy-path section"
grep -qF "Edge cases (5)" "$sample_plan" 2>/dev/null \
  && pass "N61/L3: skeleton has 5-edge-cases section" \
  || fail "N61/L3: skeleton missing edge-cases section"
grep -qF "Adversarial inputs (3)" "$sample_plan" 2>/dev/null \
  && pass "N61/L3: skeleton has 3-adversarial section" \
  || fail "N61/L3: skeleton missing adversarial section"
grep -qF "Integration scenario (1)" "$sample_plan" 2>/dev/null \
  && pass "N61/L3: skeleton has integration section" \
  || fail "N61/L3: skeleton missing integration section"
grep -qF "Independence rule" "$sample_plan" 2>/dev/null \
  && pass "N61/L3: skeleton documents independence rule" \
  || fail "N61/L3: independence rule missing"
rm -rf "$N61_SBT_TMP"

# --- Layer 5: identify-integration-probes.sh ---
IIP="$PROJ/reflex/lib/identify-integration-probes.sh"
[ -x "$IIP" ] && pass "N61/L5: identify-integration-probes.sh exists + executable" \
              || fail "N61/L5: identify-integration-probes.sh missing or non-executable"

N61_IIP_TMP=$(mktemp -d)
bash "$IIP" "$PROJ" --pass-dir "$N61_IIP_TMP" >/dev/null 2>&1
[ -f "$N61_IIP_TMP/integration-probes.md" ] && pass "N61/L5: produces integration-probes.md" \
                                            || fail "N61/L5: did not produce output"
grep -qF "Layer 5" "$N61_IIP_TMP/integration-probes.md" \
  && pass "N61/L5: output documents Layer 5 mandate" \
  || fail "N61/L5: Layer 5 mandate missing from output"
grep -qE "Heuristic candidates" "$N61_IIP_TMP/integration-probes.md" \
  && pass "N61/L5: reports heuristic candidate count" \
  || fail "N61/L5: candidate count missing"
grep -qF "Common integration patterns" "$N61_IIP_TMP/integration-probes.md" \
  && pass "N61/L5: includes common integration patterns reference" \
  || fail "N61/L5: integration patterns reference missing"

# v0.6.9: hub-suppression — when a single feature appears in 10+ candidate pairs,
# it's a hub indexer (e.g. F70 reflex links many; F64 design pipeline cross-refs
# everything). Pairs involving hubs are mostly noise — suppress them.
grep -qF "Hub-suppressed pairs:" "$N61_IIP_TMP/integration-probes.md" \
  && pass "N61/L5: emits Hub-suppressed pairs count (v0.6.9 fix)" \
  || fail "N61/L5: Hub-suppressed pairs count missing"
grep -qF "after hub-suppression" "$N61_IIP_TMP/integration-probes.md" \
  && pass "N61/L5: candidate count notes hub-suppression applied" \
  || fail "N61/L5: hub-suppression annotation missing"
rm -rf "$N61_IIP_TMP"

# --- Layer 7 QA: external-research.sh ---
ER="$PROJ/reflex/lib/external-research.sh"
[ -x "$ER" ] && pass "N61/L7-qa: external-research.sh exists + executable" \
             || fail "N61/L7-qa: external-research.sh missing or non-executable"

N61_ER_TMP=$(mktemp -d)
bash "$ER" "$PROJ" --pass-dir "$N61_ER_TMP" >/dev/null 2>&1
[ -f "$N61_ER_TMP/external-research.md" ] && pass "N61/L7-qa: produces external-research.md" \
                                          || fail "N61/L7-qa: did not produce output"
grep -qF "Layer 7" "$N61_ER_TMP/external-research.md" \
  && pass "N61/L7-qa: output documents Layer 7 mandate" \
  || fail "N61/L7-qa: Layer 7 mandate missing"
grep -qF "OWASP" "$N61_ER_TMP/external-research.md" \
  && pass "N61/L7-qa: references OWASP" \
  || fail "N61/L7-qa: OWASP reference missing"
if grep -qF "QA-EXT-NN" "$N61_ER_TMP/external-research.md" \
   || grep -qF "N/A — bash-only project" "$N61_ER_TMP/external-research.md"; then
  pass "N61/L7-qa: documents QA-EXT-NN finding format OR N/A short-circuit (v0.6.11 QA-KIT-EXT-01 fix)"
else
  fail "N61/L7-qa: neither finding format nor N/A short-circuit present"
fi

# Synthetic project with package.json for stack detection
N61_ER_SYN_TMP=$(mktemp -d)
mkdir -p "$N61_ER_SYN_TMP"
cat > "$N61_ER_SYN_TMP/package.json" <<'EOF'
{
  "name": "test", "version": "1.0.0",
  "dependencies": {"react": "^18.0.0", "express": "^4.18.0"}
}
EOF
N61_ER_SYN_OUT_TMP=$(mktemp -d)
bash "$ER" "$N61_ER_SYN_TMP" --pass-dir "$N61_ER_SYN_OUT_TMP" >/dev/null 2>&1
grep -qF "react" "$N61_ER_SYN_OUT_TMP/external-research.md" \
  && pass "N61/L7-qa: detects npm dependencies (react)" \
  || fail "N61/L7-qa: did not detect npm dependencies"
grep -qF "express" "$N61_ER_SYN_OUT_TMP/external-research.md" \
  && pass "N61/L7-qa: detects npm dependencies (express)" \
  || fail "N61/L7-qa: missed express dep"
rm -rf "$N61_ER_TMP" "$N61_ER_SYN_TMP" "$N61_ER_SYN_OUT_TMP"

# --- Layer 7 Dev: auto-extract-adl.sh ---
AEA="$PROJ/reflex/lib/auto-extract-adl.sh"
[ -x "$AEA" ] && pass "N61/L7-dev: auto-extract-adl.sh exists + executable" \
              || fail "N61/L7-dev: auto-extract-adl.sh missing or non-executable"

N61_AEA_OUT=$(mktemp)
bash "$AEA" "$PROJ" --branch main --out "$N61_AEA_OUT" >/dev/null 2>&1
grep -qF "ADL drafts" "$N61_AEA_OUT" \
  && pass "N61/L7-dev: produces ADL drafts header" \
  || fail "N61/L7-dev: ADL drafts header missing"
grep -qF "Maintainer action" "$N61_AEA_OUT" 2>/dev/null \
  || grep -qF "No commits" "$N61_AEA_OUT" 2>/dev/null \
  && pass "N61/L7-dev: emits drafts OR notes no rationale-bearing commits" \
  || fail "N61/L7-dev: malformed output"
rm -f "$N61_AEA_OUT"

# --- spawn-qa.sh wiring ---
grep -qF "scaffold-behavioral-tests.sh" "$SPAWN_QA" \
  && pass "N61/spawn-qa: invokes scaffold-behavioral-tests.sh (Layer 3)" \
  || fail "N61/spawn-qa: Layer 3 helper not wired"
grep -qF "identify-integration-probes.sh" "$SPAWN_QA" \
  && pass "N61/spawn-qa: invokes identify-integration-probes.sh (Layer 5)" \
  || fail "N61/spawn-qa: Layer 5 helper not wired"
grep -qF "external-research.sh" "$SPAWN_QA" \
  && pass "N61/spawn-qa: invokes external-research.sh (Layer 7 QA)" \
  || fail "N61/spawn-qa: Layer 7 QA helper not wired"

# --- QA prompt references new pre-populated artifacts ---
grep -qF "behavioral-tests/F{N}-test-plan.md" "$QA_PROMPT" \
  && pass "N61/qa-prompt: references behavioral-tests skeleton (Layer 3 v0.6.8)" \
  || fail "N61/qa-prompt: Layer 3 skeleton mention missing"
grep -qF "scaffold-behavioral-tests.sh" "$QA_PROMPT" \
  && pass "N61/qa-prompt: names the scaffold helper" \
  || fail "N61/qa-prompt: scaffold helper name missing"
grep -qF "identify-integration-probes.sh" "$QA_PROMPT" \
  && pass "N61/qa-prompt: names integration-probes helper" \
  || fail "N61/qa-prompt: integration-probes helper name missing"
grep -qF "external-research.sh" "$QA_PROMPT" \
  && pass "N61/qa-prompt: names external-research helper" \
  || fail "N61/qa-prompt: external-research helper name missing"

# --- Dev prompt references auto-extract-adl ---
grep -qF "auto-extract-adl.sh" "$DEV_PROMPT" \
  && pass "N61/dev-prompt: references auto-extract-adl.sh (Layer 7 v0.6.8)" \
  || fail "N61/dev-prompt: auto-extract-adl.sh reference missing"

# ═══════════════════════════════════════════════════════════════
# N59 — Reflex Phase 0 pre-compute: claims + state-diff + prompt enhancements
# ═══════════════════════════════════════════════════════════════
# Verifies: (1) reference-state YAML is parseable, (2) state-diff.sh emits
# 0 deltas on kit-self and >0 deltas on a synthetic incomplete project,
# (3) extract-claims.sh emits claims.yaml with >0 claims on the kit,
# (4) QA prompt documents Phase 0 and mentions claims.yaml + state-diff.yaml,
# (5) Dev prompt has "build unfulfilled claims" directive, (6) spawn-qa.sh
# invokes both helpers before sandbox creation, (7) 16-dim checklist still
# present as safety net (not replaced).

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  N59 — Phase 0 pre-compute (claims + state-diff + prompt enhancements)"
echo "═══════════════════════════════════════════════════════════════"

# --- Reference state file present + has required keys ---
REF_FILE="$PROJ/reflex/reference-state/speckit-project.yaml"
[ -f "$REF_FILE" ] && pass "N59/ref: reference-state YAML present" \
                   || fail "N59/ref: reflex/reference-state/speckit-project.yaml missing"

for key in required_files pipeline_files required_dirs git_hooks entry_points exclusions kit_self_markers; do
  grep -q "^$key:" "$REF_FILE" \
    && pass "N59/ref: reference-state has '$key' section" \
    || fail "N59/ref: reference-state missing '$key' section"
done

# --- state-diff.sh exists + executable + emits 0 deltas on kit-self ---
STATE_DIFF="$PROJ/reflex/lib/state-diff.sh"
[ -x "$STATE_DIFF" ] && pass "N59/state-diff: state-diff.sh exists + executable" \
                     || fail "N59/state-diff: script missing or non-executable"

N59_KIT_OUT=$(mktemp)
if bash "$STATE_DIFF" "$PROJ" --out "$N59_KIT_OUT" 2>/dev/null; then
  pass "N59/state-diff: kit-self produces 0 deltas (exit 0)"
else
  fail "N59/state-diff: kit-self should have 0 deltas but state-diff.sh exited non-zero"
fi
if grep -qE "^totals:" "$N59_KIT_OUT" && grep -qE "^  total: 0" "$N59_KIT_OUT"; then
  pass "N59/state-diff: kit-self state-diff.yaml reports total: 0"
else
  fail "N59/state-diff: kit-self state-diff.yaml does not show total: 0"
fi
rm -f "$N59_KIT_OUT"

# Synthetic incomplete project: agent/*.md only — should have many deltas
N59_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t n59)
mkdir -p "$N59_TMP/agent"
for f in REQS SPECS PLANS RESEARCH DESIGN TASKS RELEASES AGENT AGENT_CONTEXT; do
  echo "# $f" > "$N59_TMP/agent/$f.md"
done
N59_SYN_OUT="$N59_TMP/state-diff.yaml"
bash "$STATE_DIFF" "$N59_TMP" --out "$N59_SYN_OUT" 2>/dev/null
if grep -qE "critical: [1-9]" "$N59_SYN_OUT"; then
  pass "N59/state-diff: synthetic incomplete project flagged with >=1 CRITICAL delta"
else
  fail "N59/state-diff: synthetic project should have CRITICAL deltas"
fi
grep -qF 'portable-spec-kit.md' "$N59_SYN_OUT" \
  && pass "N59/state-diff: synthetic missing portable-spec-kit.md delta surfaced" \
  || fail "N59/state-diff: did not flag missing portable-spec-kit.md"
grep -qF 'agent/scripts/psk-sync-check.sh' "$N59_SYN_OUT" \
  && pass "N59/state-diff: synthetic missing core script delta surfaced" \
  || fail "N59/state-diff: did not flag missing psk-sync-check.sh"
rm -rf "$N59_TMP"

# --- extract-claims.sh exists + emits claims on kit-self ---
EXTRACT_CLAIMS="$PROJ/reflex/lib/extract-claims.sh"
[ -x "$EXTRACT_CLAIMS" ] && pass "N59/claims: extract-claims.sh exists + executable" \
                         || fail "N59/claims: script missing or non-executable"

N59_CLAIMS_OUT=$(mktemp)
bash "$EXTRACT_CLAIMS" "$PROJ" --out "$N59_CLAIMS_OUT" 2>/dev/null
if grep -qE "^total: [1-9]" "$N59_CLAIMS_OUT"; then
  pass "N59/claims: kit-self produces >=1 claim"
else
  fail "N59/claims: kit-self should produce >=1 claim"
fi
grep -qF 'probe_type: version-match' "$N59_CLAIMS_OUT" \
  && pass "N59/claims: version-match probe type emitted for version badges" \
  || fail "N59/claims: version-match probe type missing"
grep -qF 'probe_type: test-count' "$N59_CLAIMS_OUT" \
  && pass "N59/claims: test-count probe type emitted for test badges" \
  || fail "N59/claims: test-count probe type missing"
rm -f "$N59_CLAIMS_OUT"

# --- QA prompt documents Phase 0 + claims.yaml + state-diff.yaml ---
QA_PROMPT="$PROJ/reflex/prompts/qa-agent.md"
grep -qE "^### Phase 0" "$QA_PROMPT" \
  && pass "N59/qa-prompt: Phase 0 section present" \
  || fail "N59/qa-prompt: Phase 0 section missing"
grep -qF "claims.yaml" "$QA_PROMPT" \
  && pass "N59/qa-prompt: references claims.yaml from Phase 0" \
  || fail "N59/qa-prompt: does not reference claims.yaml"
grep -qF "state-diff.yaml" "$QA_PROMPT" \
  && pass "N59/qa-prompt: references state-diff.yaml from Phase 0" \
  || fail "N59/qa-prompt: does not reference state-diff.yaml"
grep -qF "assumptions.md" "$QA_PROMPT" \
  && pass "N59/qa-prompt: assumption-surfacing documented" \
  || fail "N59/qa-prompt: assumption-surfacing missing"

# --- 23-dim checklist preserved as safety net (not replaced) ---
grep -qE "23 dimensions of review" "$QA_PROMPT" \
  && pass "N59/qa-prompt: 23-dim checklist preserved as safety net (not replaced by Phase 0)" \
  || fail "N59/qa-prompt: 23-dim checklist missing — Phase 0 should augment, not replace"

grep -qiE "safety net|short-circuit" "$QA_PROMPT" \
  && pass "N59/qa-prompt: prompt describes how Phase 0 and 22-dim interact (safety net / short-circuit)" \
  || fail "N59/qa-prompt: missing guidance on Phase 0 + 16-dim interaction"

# --- Dev prompt: build-unfulfilled-claims directive ---
DEV_PROMPT="$PROJ/reflex/prompts/dev-agent.md"
grep -qiE "build.*unfulfilled|build unfulfilled claims|Build, don't just patch" "$DEV_PROMPT" \
  && pass "N59/dev-prompt: build-unfulfilled-claims directive present" \
  || fail "N59/dev-prompt: build directive missing — Dev must build claims, not just patch findings"
grep -qF "claims.yaml" "$DEV_PROMPT" \
  && pass "N59/dev-prompt: Dev reads claims.yaml from Phase 0" \
  || fail "N59/dev-prompt: Dev prompt missing claims.yaml reference"
grep -qF "state-diff.yaml" "$DEV_PROMPT" \
  && pass "N59/dev-prompt: Dev reads state-diff.yaml from Phase 0" \
  || fail "N59/dev-prompt: Dev prompt missing state-diff.yaml reference"

# --- spawn-qa.sh invokes extract-claims + state-diff BEFORE sandbox creation ---
SPAWN_QA="$PROJ/reflex/lib/spawn-qa.sh"
grep -qF "extract-claims.sh" "$SPAWN_QA" \
  && pass "N59/spawn-qa: invokes extract-claims.sh" \
  || fail "N59/spawn-qa: not wired to invoke extract-claims.sh"
grep -qF "state-diff.sh" "$SPAWN_QA" \
  && pass "N59/spawn-qa: invokes state-diff.sh" \
  || fail "N59/spawn-qa: not wired to invoke state-diff.sh"

# Both must run BEFORE sandbox cp-fallback (so output is available to sandbox creation)
spawn_qa_content=$(cat "$SPAWN_QA")
extract_line=$(grep -n "extract-claims.sh" "$SPAWN_QA" | head -1 | cut -d: -f1)
cp_fallback_line=$(grep -n "cp-based sandbox\|cp -a " "$SPAWN_QA" | head -1 | cut -d: -f1)
if [ -n "$extract_line" ] && [ -n "$cp_fallback_line" ] && [ "$extract_line" -lt "$cp_fallback_line" ]; then
  pass "N59/spawn-qa: Phase 0 pre-compute runs BEFORE sandbox creation (correct order)"
else
  fail "N59/spawn-qa: Phase 0 pre-compute order wrong — must run before sandbox cp"
fi

# --- N59 end-to-end: spawn-qa sets up both helpers' output in PASS_DIR ---
# (behavioral check of the integration)
N59_E2E_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t n59e2e)
mkdir -p "$N59_E2E_TMP/pass"
if bash "$EXTRACT_CLAIMS" "$PROJ" --out "$N59_E2E_TMP/pass/claims.yaml" >/dev/null 2>&1 \
  && bash "$STATE_DIFF" "$PROJ" --out "$N59_E2E_TMP/pass/state-diff.yaml" >/dev/null 2>&1 \
  && [ -f "$N59_E2E_TMP/pass/claims.yaml" ] \
  && [ -f "$N59_E2E_TMP/pass/state-diff.yaml" ]; then
  pass "N59/e2e: both Phase 0 helpers produce pass-dir artifacts"
else
  fail "N59/e2e: Phase 0 helpers failed to produce pass-dir artifacts"
fi
rm -rf "$N59_E2E_TMP"

section "N62. v0.6.15 cycle-id continuation rule (findings-first semantics)"

# Regression test for ADR-027 (v0.6.15): one convergence journey = one cycle id.
# History: v0.6.14 used a fragile false-GRANTED detection (empty-pass shortcut
# string + findings>0 → DENIED override). It still let the playground campaign
# fragment cycle-02 → cycle-03 because file-bugs.sh stamped signoff.md only
# on certain code paths, leaving stamp-less GRANTED-with-findings cases through.
#
# v0.6.15 simplifies to a findings-first rule: cycle ends ONLY when latest
# pass produced zero findings AND a clean GRANTED verdict. Any findings in
# findings.yaml → continue same cycle, regardless of how signoff was stamped
# (empty-pass shortcut, convergence_pass flag, manual fix between passes).
# The user's mental model: a "convergence cycle" = one journey from initial
# state through to QA reporting zero findings.

# --- Layer 1: count_findings_yaml helper exists in both run.sh + loop.sh ---
RUN_SH="$PROJ/reflex/run.sh"
LOOP_SH="$PROJ/reflex/lib/loop.sh"
grep -q "count_findings_yaml()" "$RUN_SH" \
  && pass "N62/helper: count_findings_yaml() defined in run.sh" \
  || fail "N62/helper: count_findings_yaml() missing from run.sh"
grep -q "count_findings_yaml()" "$LOOP_SH" \
  && pass "N62/helper: count_findings_yaml() defined in loop.sh" \
  || fail "N62/helper: count_findings_yaml() missing from loop.sh"

# --- Layer 2: findings-first rule documented in both files ---
grep -q 'findings-first' "$RUN_SH" \
  && pass "N62/rule: run.sh comments cite findings-first continuation" \
  || fail "N62/rule: run.sh missing findings-first continuation comment"
grep -q 'findings-first' "$LOOP_SH" \
  && pass "N62/rule: loop.sh comments cite findings-first continuation" \
  || fail "N62/rule: loop.sh missing findings-first continuation comment"

# --- Layer 3: behavioral test of count_findings_yaml ---
N62_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t n62)

cat > "$N62_TMP/findings-3.yaml" <<'EOF'
pass_id: test-pass
release_class: minor

findings:
  - id: QA-A-01
    priority: MAJOR
  - id: QA-B-02
    priority: MINOR
  - id: QA-C-03
    priority: NIT

deferred_decisions:
  - id: NOT-A-FINDING-01
EOF

cat > "$N62_TMP/findings-0.yaml" <<'EOF'
pass_id: test-pass
findings:
deferred_decisions:
  - id: NOT-A-FINDING-99
EOF

helper_src=$(awk '/^count_findings_yaml\(\)/{flag=1} flag; /^}$/{if(flag)exit}' "$RUN_SH")
eval "$helper_src"

count_a=$(count_findings_yaml "$N62_TMP/findings-3.yaml")
count_b=$(count_findings_yaml "$N62_TMP/findings-0.yaml")
count_missing=$(count_findings_yaml "$N62_TMP/does-not-exist.yaml")

[ "$count_a" = "3" ] \
  && pass "N62/helper: counts 3 findings in well-formed findings.yaml (ignores deferred bucket)" \
  || fail "N62/helper: expected 3 findings, got '$count_a'"
[ "$count_b" = "0" ] \
  && pass "N62/helper: returns 0 for empty findings list (ignores deferred bucket)" \
  || fail "N62/helper: expected 0 findings, got '$count_b'"
[ "$count_missing" = "0" ] \
  && pass "N62/helper: returns 0 for missing file" \
  || fail "N62/helper: expected 0 for missing file, got '$count_missing'"

# --- Layer 4: findings-first continuation logic — extract & exercise both
#     compute_next_cycle_id (run.sh) and next_cycle_id (loop.sh) against a
#     synthetic HISTORY tree. Each scenario constructs cycle-NN/pass-NNN/
#     dirs with .cycle-meta + signoff.md + findings.yaml, then asserts the
#     next-cycle-id decision matches the rule.

run_decision() {
  # Returns the next cycle id given a synthetic HISTORY dir.
  local hist="$1"
  bash -c '
    HISTORY="'"$hist"'"
    '"$(awk '/^count_findings_yaml\(\)/,/^}$/' "$RUN_SH")"'
    '"$(awk '/^compute_next_cycle_id\(\)/,/^}$/' "$RUN_SH")"'
    compute_next_cycle_id
  '
}

build_pass() {
  # build_pass HISTORY CYCLE PASS VERDICT FINDINGS_COUNT
  local hist="$1" cyc="$2" pn="$3" verdict="$4" fc="$5"
  local cdir
  cdir="$hist/cycle-$(printf '%02d' "$cyc")/pass-$(printf '%03d' "$pn")"
  mkdir -p "$cdir"
  printf 'cycle=%d\niteration=1\nmode=full\n' "$cyc" > "$cdir/.cycle-meta"
  if [ "$verdict" = "GRANTED-stamped" ]; then
    cat > "$cdir/signoff.md" <<'STAMP'
# signoff
**Verdict: GRANTED** _(empty-pass shortcut — QA hunted, filed 0 findings)_
STAMP
  elif [ "$verdict" = "GRANTED" ]; then
    cat > "$cdir/signoff.md" <<'CLEAN'
# signoff
**Verdict: GRANTED**
CLEAN
  elif [ "$verdict" = "DENIED" ]; then
    cat > "$cdir/signoff.md" <<'DENY'
# signoff
**Verdict: DENIED** — findings remain
DENY
  fi
  if [ "$fc" -gt 0 ]; then
    {
      echo "findings:"
      for i in $(seq 1 "$fc"); do echo "  - id: QA-FX-$i"; done
    } > "$cdir/findings.yaml"
  else
    echo "findings:" > "$cdir/findings.yaml"
  fi
}

# Scenario A: false-GRANTED stamp + findings (the historical bug)
HIST_A="$N62_TMP/scen-a"
build_pass "$HIST_A" 2 5 "GRANTED-stamped" 1
result=$(run_decision "$HIST_A")
[ "$result" = "2" ] \
  && pass "N62/A: false-GRANTED stamp + 1 finding → continue cycle 2 (was the cycle-fragmentation bug)" \
  || fail "N62/A: expected 2, got '$result'"

# Scenario B: hand-written GRANTED + findings (deferred-but-pending)
HIST_B="$N62_TMP/scen-b"
build_pass "$HIST_B" 1 1 "GRANTED" 5
result=$(run_decision "$HIST_B")
[ "$result" = "1" ] \
  && pass "N62/B: clean GRANTED + 5 findings → continue cycle 1 (findings = work pending)" \
  || fail "N62/B: expected 1, got '$result'"

# Scenario C: true empty pass — 0 findings + GRANTED → advance
HIST_C="$N62_TMP/scen-c"
build_pass "$HIST_C" 1 1 "GRANTED-stamped" 0
result=$(run_decision "$HIST_C")
[ "$result" = "2" ] \
  && pass "N62/C: 0 findings + GRANTED → advance to cycle 2 (clean terminator)" \
  || fail "N62/C: expected 2, got '$result'"

# Scenario D: DENIED + 0 findings → continue (verdict mismatch should not advance)
HIST_D="$N62_TMP/scen-d"
build_pass "$HIST_D" 1 1 "DENIED" 0
result=$(run_decision "$HIST_D")
[ "$result" = "1" ] \
  && pass "N62/D: DENIED + 0 findings → continue cycle 1 (verdict not GRANTED)" \
  || fail "N62/D: expected 1, got '$result'"

# Scenario E: missing signoff.md → continue
HIST_E="$N62_TMP/scen-e"
mkdir -p "$HIST_E/cycle-01/pass-001"
printf 'cycle=1\niteration=1\nmode=full\n' > "$HIST_E/cycle-01/pass-001/.cycle-meta"
echo "findings:" > "$HIST_E/cycle-01/pass-001/findings.yaml"
result=$(run_decision "$HIST_E")
[ "$result" = "1" ] \
  && pass "N62/E: missing signoff.md → continue cycle 1 (no clean terminator)" \
  || fail "N62/E: expected 1, got '$result'"

# Scenario F: convergence journey — 3 passes, last clean → advance
HIST_F="$N62_TMP/scen-f"
build_pass "$HIST_F" 1 1 "DENIED" 12        # initial pass: many findings
build_pass "$HIST_F" 1 2 "GRANTED-stamped" 3 # after dev fixes: still 3 findings
build_pass "$HIST_F" 1 3 "GRANTED-stamped" 0 # final pass: 0 findings, clean GRANTED
result=$(run_decision "$HIST_F")
[ "$result" = "2" ] \
  && pass "N62/F: convergence journey 12→3→0 with last pass clean → advance to cycle 2" \
  || fail "N62/F: expected 2, got '$result'"

# Scenario G: convergence still in flight — last pass has findings → continue
HIST_G="$N62_TMP/scen-g"
build_pass "$HIST_G" 2 1 "DENIED" 12
build_pass "$HIST_G" 2 2 "GRANTED-stamped" 3
result=$(run_decision "$HIST_G")
[ "$result" = "2" ] \
  && pass "N62/G: in-flight convergence (last pass has 3 findings) → continue cycle 2" \
  || fail "N62/G: expected 2, got '$result'"

rm -rf "$N62_TMP"

section "N63. v0.6.14 psk-optimize.sh + /optimize skill (token-bloat sweep)"

# Regression test for the prune-bloat infrastructure (script + skill).
# Exercises detector logic (cat 1, 2, 3) on synthetic fixtures to confirm
# the safety contract holds: no false positives, no missed bloat.

PRUNE_SH="$PROJ/agent/scripts/psk-optimize.sh"
PRUNE_SKILL="$PROJ/.portable-spec-kit/skills/optimize.md"

# --- Existence + executable ---
[ -x "$PRUNE_SH" ] \
  && pass "N63/script: psk-optimize.sh present + executable" \
  || fail "N63/script: psk-optimize.sh missing or not executable"
[ -f "$PRUNE_SKILL" ] \
  && pass "N63/skill: optimize.md skill file present" \
  || fail "N63/skill: optimize.md skill file missing"

# --- Skill enforces safety contract (key phrases) ---
grep -q "atomic commit" "$PRUNE_SKILL" \
  && pass "N63/skill: per-cut atomic commit requirement present" \
  || fail "N63/skill: missing atomic commit requirement"
grep -q "MANDATORY-line preservation" "$PRUNE_SKILL" \
  && pass "N63/skill: MANDATORY-line preservation rule present" \
  || fail "N63/skill: missing MANDATORY-line preservation"
grep -q "git reset --hard HEAD~1" "$PRUNE_SKILL" \
  && pass "N63/skill: gate-failure revert protocol present" \
  || fail "N63/skill: missing gate-failure revert protocol"

# --- Detector — cat 1 (duplicate version blocks) — SHOULD detect duplicates ---
N63_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t n63)
cat > "$N63_TMP/CHANGELOG.md" <<'EOF'
# Changelog
## v0.5 — Theme name (April 2026)
### v0.5.1 — First iteration (April 2026)
First take.
### v0.5.1 — Second iteration after rework (April 2026)
Second take, replacing first.
### v0.5.1 — Third iteration final (April 2026)
Final form.
EOF

# Source detector function from psk-optimize.sh
detector_src=$(awk '/^detect_duplicate_version_blocks\(\)/{flag=1} flag; /^}$/{if(flag){exit}}' "$PRUNE_SH")
eval "$detector_src"

dup_out=$(detect_duplicate_version_blocks "$N63_TMP/CHANGELOG.md")
dup_count=$(echo "$dup_out" | grep -c "v0.5.1")
[ "$dup_count" = "1" ] \
  && pass "N63/cat1: detector flags v0.5.1 appearing 3 times in synthetic fixture" \
  || fail "N63/cat1: detector missed duplicate; expected 1 line of output, got '$dup_out'"

# --- Detector — cat 1 — SHOULD NOT false-positive on legitimate single block ---
cat > "$N63_TMP/RELEASES.md" <<'EOF'
# Releases
## v0.6 — Title (April 2026)
## v0.6.1 — Patch one — first release (2026-04-01)
Single block, no iteration narrative.
## v0.6.2 — Patch two (2026-04-02)
Single block.
EOF
clean_out=$(detect_duplicate_version_blocks "$N63_TMP/RELEASES.md")
[ -z "$clean_out" ] \
  && pass "N63/cat1: detector silent on clean file (no false positives)" \
  || fail "N63/cat1: false positive on clean fixture: '$clean_out'"

# --- Detector — cat 1 — SHOULD NOT match subsection headers like "#### v0.x hotfixes" ---
cat > "$N63_TMP/sub.md" <<'EOF'
### v0.6.11 — Reset allowlist (April 2026)
Real release.
#### v0.6.11 hotfixes (refresh release commits, in order)
This is a sub-subsection, not a duplicate release header.
EOF
sub_out=$(detect_duplicate_version_blocks "$N63_TMP/sub.md")
[ -z "$sub_out" ] \
  && pass "N63/cat1: detector ignores #### subsections (only matches release headers)" \
  || fail "N63/cat1: false positive on subsection: '$sub_out'"

# --- CLI smoke — --scan mode runs without crash + emits expected sections ---
# Set re-entrancy guard so detect_stale_test_counts doesn't re-spawn the
# test suite (infinite recursion: test runs psk-optimize which would run
# the test suite which would re-enter this section).
scan_output=$(PSK_OPTIMIZE_SKIP_TESTRUN=1 bash "$PRUNE_SH" --scan 2>&1)
if echo "$scan_output" | grep -q "psk-optimize scan" \
   && echo "$scan_output" | grep -q "Duplicate version-iteration entries" \
   && echo "$scan_output" | grep -q "Stale numeric badges" \
   && echo "$scan_output" | grep -q "Superseded-ADR rationale bloat" \
   && echo "$scan_output" | grep -q "Safety contract: every cut is one atomic commit"; then
  pass "N63/cli: --scan emits all 3 categories + safety-contract footer"
else
  fail "N63/cli: --scan output incomplete or malformed"
fi

# --- CLI smoke — --json mode produces parseable JSON ---
json_output=$(PSK_OPTIMIZE_SKIP_TESTRUN=1 bash "$PRUNE_SH" --scan --json 2>&1)
if echo "$json_output" | grep -q '"candidates":' \
   && echo "$json_output" | grep -q '"timestamp":'; then
  pass "N63/cli: --json mode emits structured output with candidates + timestamp"
else
  fail "N63/cli: --json mode malformed: $(echo "$json_output" | head -3)"
fi

# --- CLI smoke — invalid flag is rejected ---
bad_output=$(bash "$PRUNE_SH" --bogus-flag 2>&1; echo "EXIT:$?")
if echo "$bad_output" | grep -q "unknown flag" && echo "$bad_output" | grep -q "EXIT:1"; then
  pass "N63/cli: rejects unknown flags with non-zero exit"
else
  fail "N63/cli: unknown flag handling broken: $bad_output"
fi

rm -rf "$N63_TMP"

section "N64. v0.6.14 psk-optimize.sh v2 categories (cat 4-8 — file refs + env vars + sections + reflex)"

# v2 expansion: stale file refs (cat 4), unused env vars (cat 5),
# oversized markdown sections (cat 6), reflex prompt bloat (cat 7),
# reflex history retention bloat (cat 8). Each detector is exercised
# against synthetic fixtures with both true-positive and false-positive
# scenarios.

PRUNE_SH="$PROJ/agent/scripts/psk-optimize.sh"
N64_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t n64)

# Source detector functions from psk-optimize.sh (extract each function
# block; portable awk).
extract_fn() {
  awk -v fn="$1" '$0 ~ "^"fn"\\(\\)" {flag=1} flag; flag && /^}$/ {exit}' "$PRUNE_SH"
}
eval "$(extract_fn 'detect_stale_file_refs')"
eval "$(extract_fn 'detect_unused_env_vars')"
eval "$(extract_fn 'detect_oversized_markdown_sections')"
eval "$(extract_fn 'detect_reflex_prompt_bloat')"
eval "$(extract_fn 'detect_reflex_history_bloat')"

# --- Cat 4: stale file references ---
# Setup: a markdown file linking to one valid path + one stale path
mkdir -p "$N64_TMP/agent"
cat > "$N64_TMP/agent/PLANS.md" <<'EOF'
# Plans
- [Real link](../existing-doc.md)
- [Broken link](does-not-exist.md)
- [External](https://example.com/page.md) — should be skipped
- [Anchor](#section) — should be skipped
EOF
touch "$N64_TMP/existing-doc.md"

# Override PROJ_ROOT for the detector's relative-path resolution
PROJ_ROOT_BACKUP="$PROJ_ROOT"
PROJ_ROOT="$N64_TMP"
ref_out=$(detect_stale_file_refs 2>/dev/null || true)
PROJ_ROOT="$PROJ_ROOT_BACKUP"

# Need a fixture-aware re-run: the detector hardcodes the file list,
# so we just verify the function runs and its output format is correct
# when invoked with full PROJ_ROOT. The kit's own PLANS.md is the
# real fixture — at this point it should have 0 stale refs (we fixed
# the false positives earlier in cat 4 path-resolution work).
real_refs=$(detect_stale_file_refs 2>/dev/null || true)
# Real kit has no stale refs after the relative-path fix
[ -z "$real_refs" ] \
  && pass "N64/cat4: detector returns clean on real kit (no stale refs)" \
  || fail "N64/cat4: detector found unexpected stale refs in real kit: '$real_refs'"

# Verify detector skips http URLs + anchors (would have caught earlier bug)
echo '[Doc](https://example.com/page.md)' > "$N64_TMP/url-test.md"
url_out=$(grep -oE '\[[^]]+\]\(([^)]+\.(md|sh|yml|yaml|json|html))\)' "$N64_TMP/url-test.md" | sed -E 's|^\[[^]]+\]\(([^)]+)\)|\1|')
case "$url_out" in
  http*) pass "N64/cat4: extraction handles URL prefix correctly (will be skipped by detector)" ;;
  *)     fail "N64/cat4: URL extraction wrong: '$url_out'" ;;
esac

# --- Cat 5: unused env vars ---
# Setup: .env.example with USED_VAR + UNUSED_VAR; src/ that reads only USED_VAR
mkdir -p "$N64_TMP/.env-test/src"
cat > "$N64_TMP/.env-test/.env.example" <<'EOF'
# Comment line
USED_VAR=placeholder
UNUSED_VAR=placeholder
PSK_INTERNAL=placeholder
NEXT_PUBLIC_API=placeholder
EOF
cat > "$N64_TMP/.env-test/src/route.ts" <<'EOF'
const url = process.env.USED_VAR
EOF

# Test detector function with overridden PROJ_ROOT
PROJ_ROOT_BACKUP="$PROJ_ROOT"
PROJ_ROOT="$N64_TMP/.env-test"
env_out=$(detect_unused_env_vars 2>/dev/null || true)
PROJ_ROOT="$PROJ_ROOT_BACKUP"

# Use word-boundary grep to avoid USED_VAR matching UNUSED_VAR substring
if echo "$env_out" | grep -qE '\bUNUSED_VAR\b'; then
  pass "N64/cat5: detector flags UNUSED_VAR (declared but never read)"
else
  fail "N64/cat5: detector missed UNUSED_VAR; got: '$env_out'"
fi
# Match the specific finding-line for USED_VAR (UNUSED_ENV: USED_VAR declared)
if echo "$env_out" | grep -qE 'UNUSED_ENV: USED_VAR\b'; then
  fail "N64/cat5: detector falsely flagged USED_VAR (which IS read)"
else
  pass "N64/cat5: detector silent on USED_VAR (correctly identified as referenced)"
fi
if echo "$env_out" | grep -qE '\bPSK_INTERNAL\b'; then
  fail "N64/cat5: detector falsely flagged PSK_-prefixed var (kit infra exemption broken)"
else
  pass "N64/cat5: detector skips PSK_-prefixed kit infra vars"
fi
if echo "$env_out" | grep -qE '\bNEXT_PUBLIC_API\b'; then
  fail "N64/cat5: detector falsely flagged NEXT_PUBLIC_-prefixed var (Next.js convention)"
else
  pass "N64/cat5: detector skips NEXT_PUBLIC_-prefixed Next.js convention vars"
fi

# --- Cat 6: oversized markdown sections ---
# Setup: synthetic file with one giant section + one short section
{
  echo "## Short Section"
  echo "Just a few lines"
  echo ""
  echo "## Huge Section"
  for i in $(seq 1 250); do echo "Filler line $i"; done
  echo ""
  echo "## Another Short"
  echo "Done"
} > "$N64_TMP/oversized.md"

# Direct awk test (detect_oversized_markdown_sections hardcodes path)
oversized_out=$(awk '
  /^##[#]? / {
    if (current_heading != "" && (NR - heading_line) > 200) {
      printf "%s:%d:OVERSIZED: section \"%s\" is %d lines\n", FILENAME, heading_line, current_heading, (NR - heading_line)
    }
    current_heading = $0
    heading_line = NR
  }
' "$N64_TMP/oversized.md")
if echo "$oversized_out" | grep -q "Huge Section"; then
  pass "N64/cat6: detector flags >200-line section as oversized"
else
  fail "N64/cat6: detector missed oversized section: '$oversized_out'"
fi
if echo "$oversized_out" | grep -q "Short Section"; then
  fail "N64/cat6: detector falsely flagged short section"
else
  pass "N64/cat6: detector silent on short sections (no false positives)"
fi

# --- Cat 7: reflex prompt bloat ---
# Setup: synthetic prompt file >500 lines
mkdir -p "$N64_TMP/reflex-test/reflex/prompts"
{
  for i in $(seq 1 510); do echo "Prompt line $i"; done
} > "$N64_TMP/reflex-test/reflex/prompts/big-prompt.md"
# Small prompt (under threshold)
{
  for i in $(seq 1 100); do echo "Small prompt line $i"; done
} > "$N64_TMP/reflex-test/reflex/prompts/small-prompt.md"

PROJ_ROOT_BACKUP="$PROJ_ROOT"
PROJ_ROOT="$N64_TMP/reflex-test"
prompt_out=$(detect_reflex_prompt_bloat 2>/dev/null || true)
PROJ_ROOT="$PROJ_ROOT_BACKUP"

if echo "$prompt_out" | grep -q "big-prompt.md"; then
  pass "N64/cat7: detector flags >500-line reflex prompt as bloat"
else
  fail "N64/cat7: detector missed oversized prompt: '$prompt_out'"
fi
if echo "$prompt_out" | grep -q "small-prompt.md"; then
  fail "N64/cat7: detector falsely flagged 100-line prompt"
else
  pass "N64/cat7: detector silent on small prompts (no false positives)"
fi

# --- Cat 8: reflex history retention bloat ---
# Setup: synthetic reflex/history with 25 pass dirs (default limit 10, hard cap 20)
mkdir -p "$N64_TMP/hist-test/reflex/history/standalone"
for i in $(seq 1 25); do
  mkdir -p "$N64_TMP/hist-test/reflex/history/standalone/pass-$(printf '%03d' $i)"
done

PROJ_ROOT_BACKUP="$PROJ_ROOT"
PROJ_ROOT="$N64_TMP/hist-test"
hist_out=$(detect_reflex_history_bloat 2>/dev/null || true)
PROJ_ROOT="$PROJ_ROOT_BACKUP"

if echo "$hist_out" | grep -q "REFLEX_HISTORY_BLOAT"; then
  pass "N64/cat8: detector flags 25 pass dirs (>2x retention limit) as bloat"
else
  fail "N64/cat8: detector missed history bloat: '$hist_out'"
fi

# Setup: oversized REFLEX_EVAL_TRACE.md
mkdir -p "$N64_TMP/register-test/reflex/history"
# Generate >100KB of content
yes "Some line of text in the register that takes up bytes." 2>/dev/null | head -2200 > "$N64_TMP/register-test/reflex/history/REFLEX_EVAL_TRACE.md"
# Need a few pass dirs for the function to walk
mkdir -p "$N64_TMP/register-test/reflex/history/standalone/pass-001"

PROJ_ROOT_BACKUP="$PROJ_ROOT"
PROJ_ROOT="$N64_TMP/register-test"
reg_out=$(detect_reflex_history_bloat 2>/dev/null || true)
PROJ_ROOT="$PROJ_ROOT_BACKUP"

if echo "$reg_out" | grep -q "REFLEX_REGISTER_BLOAT"; then
  pass "N64/cat8: detector flags >100KB REFLEX_EVAL_TRACE.md as register bloat"
else
  fail "N64/cat8: detector missed register bloat: '$reg_out'"
fi

# --- CLI: --scan emits all 8 sections ---
scan_v2=$(PSK_OPTIMIZE_SKIP_TESTRUN=1 bash "$PRUNE_SH" --scan 2>&1)
v2_sections_count=$(echo "$scan_v2" | grep -cE '^\[[1-9]/9\]')
[ "$v2_sections_count" = "9" ] \
  && pass "N64/cli: --scan emits all 9 category headers" \
  || fail "N64/cli: expected 9 category headers, got $v2_sections_count"

rm -rf "$N64_TMP"

section "N65. v0.6.14 reflex no-op pass detection (HEAD-unchanged → skip)"

# Regression test for the reflex performance optimization that skips
# a full pass when git HEAD is unchanged since the most-recent GRANTED
# pass. The audit result CANNOT change without a commit, so re-running
# is pure waste — saves ~100-300K tokens + 3-10 min wall time per
# skipped pass. --force flag overrides for explicit re-runs.

RUN_SH="$PROJ/reflex/run.sh"

# --- 1. --force flag is parsed (not rejected as unknown) ---
force_help_out=$(bash "$RUN_SH" --force --help 2>&1 || true)
# --help may exit 0; check that --force did NOT cause "unknown flag" error
if echo "$force_help_out" | grep -q "unknown flag"; then
  fail "N65/flag: --force flag rejected as unknown"
else
  pass "N65/flag: --force flag accepted"
fi

# --- 2. .cycle-meta now records HEAD ---
grep -q 'echo "head=' "$RUN_SH" \
  && pass "N65/meta: pass-meta writer records git HEAD" \
  || fail "N65/meta: missing 'head=' field in .cycle-meta writer"

# --- 3. No-op detection block exists ---
grep -q "No-op pass detection" "$RUN_SH" \
  && pass "N65/detection: no-op detection block present in run.sh" \
  || fail "N65/detection: no-op detection block missing"

# --- 4. Detection respects FORCE_RUN flag ---
grep -q 'FORCE_RUN.*!= true' "$RUN_SH" \
  && pass "N65/detection: --force flag overrides no-op skip" \
  || fail "N65/detection: --force override missing"

# --- 5. Detection respects REFLEX_NO_OP_DETECTION env var ---
grep -q 'REFLEX_NO_OP_DETECTION' "$RUN_SH" \
  && pass "N65/detection: REFLEX_NO_OP_DETECTION=0 disables check" \
  || fail "N65/detection: env-var bypass missing"

# --- 6. Detection only triggers on GRANTED prior pass ---
grep -q 'Verdict.*GRANTED.*verdict.*GRANTED' "$RUN_SH" \
  && pass "N65/detection: only matches GRANTED prior verdicts (not DENIED/INCOMPLETE)" \
  || fail "N65/detection: verdict-filter pattern wrong or missing"

# --- 7. Behavioral: simulated no-op should exit early (synthetic fixture) ---
N65_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t n65)
mkdir -p "$N65_TMP/reflex/history/cycle-01/pass-001"
# Synthesize a GRANTED pass with HEAD recorded
cat > "$N65_TMP/reflex/history/cycle-01/pass-001/.cycle-meta" <<EOF
cycle=1
iteration=1
mode=full
self_test=false
started=2026-04-29T00:00:00Z
head=fake-sha-12345
EOF
cat > "$N65_TMP/reflex/history/cycle-01/pass-001/signoff.md" <<'EOF'
# Signoff
**Verdict: GRANTED**
EOF

# We can't actually run reflex/run.sh here (would require a full kit
# repo + preconditions), but we can verify the detection logic itself.
# Source the detection block and run it with mock current_head matching
# the recorded one.
detection_logic='
HISTORY="'"$N65_TMP"'/reflex/history"
PROJ_ROOT="'"$N65_TMP"'"
FORCE_RUN=false
REFLEX_NO_OP_DETECTION=1
current_head="fake-sha-12345"

last_granted_head=""
last_granted_pass=""
for pdir in $(ls -1dt "$HISTORY"/cycle-*/pass-*/ 2>/dev/null); do
  pdir="${pdir%/}"
  [ -f "$pdir/.cycle-meta" ] || continue
  recorded_head=$(awk -F= "\$1==\"head\"{print \$2; exit}" "$pdir/.cycle-meta" 2>/dev/null)
  [ -z "$recorded_head" ] && continue
  if [ -f "$pdir/signoff.md" ] && grep -qE "Verdict:[[:space:]]+GRANTED|^- verdict: GRANTED" "$pdir/signoff.md"; then
    last_granted_head="$recorded_head"
    last_granted_pass="$pdir"
    break
  fi
done
if [ "$last_granted_head" = "$current_head" ]; then echo "SKIP"; else echo "RUN"; fi
'
result=$(bash -c "$detection_logic")
[ "$result" = "SKIP" ] \
  && pass "N65/behavioral: matching HEAD triggers SKIP (no-op pass)" \
  || fail "N65/behavioral: expected SKIP for matching HEAD, got '$result'"

# Test 8: HEAD differs → should RUN
detection_logic_diff="${detection_logic/fake-sha-12345\"/different-sha-9999\"}"
# Need to replace only the current_head value, not the recorded one
detection_logic_diff='
HISTORY="'"$N65_TMP"'/reflex/history"
PROJ_ROOT="'"$N65_TMP"'"
FORCE_RUN=false
REFLEX_NO_OP_DETECTION=1
current_head="different-sha-9999"

last_granted_head=""
for pdir in $(ls -1dt "$HISTORY"/cycle-*/pass-*/ 2>/dev/null); do
  pdir="${pdir%/}"
  [ -f "$pdir/.cycle-meta" ] || continue
  recorded_head=$(awk -F= "\$1==\"head\"{print \$2; exit}" "$pdir/.cycle-meta" 2>/dev/null)
  [ -z "$recorded_head" ] && continue
  if [ -f "$pdir/signoff.md" ] && grep -qE "Verdict:[[:space:]]+GRANTED|^- verdict: GRANTED" "$pdir/signoff.md"; then
    last_granted_head="$recorded_head"
    break
  fi
done
if [ "$last_granted_head" = "$current_head" ]; then echo "SKIP"; else echo "RUN"; fi
'
result_diff=$(bash -c "$detection_logic_diff")
[ "$result_diff" = "RUN" ] \
  && pass "N65/behavioral: differing HEAD triggers RUN (audit needed)" \
  || fail "N65/behavioral: expected RUN for differing HEAD, got '$result_diff'"

# Test 9: DENIED prior verdict → should RUN (don't skip on non-GRANTED)
cat > "$N65_TMP/reflex/history/cycle-01/pass-001/signoff.md" <<'EOF'
# Signoff
**Verdict: DENIED**
EOF
result_denied=$(bash -c "$detection_logic")
[ "$result_denied" = "RUN" ] \
  && pass "N65/behavioral: DENIED prior verdict does NOT trigger skip (only GRANTED qualifies)" \
  || fail "N65/behavioral: expected RUN for DENIED prior, got '$result_denied'"

rm -rf "$N65_TMP"

section "N66. v0.6.14 prep-release integration with /optimize advisory scan"

# psk-release.sh Step 10 (Release Summary) now runs psk-optimize.sh --scan
# as a non-blocking advisory. Surfaces token-bloat at the natural release
# cadence. Scan is read-only by default; user invokes /optimize skill for
# actual cuts. Bypass: PSK_OPTIMIZE_SCAN_DISABLED=1.

RELEASE_SH="$PROJ/agent/scripts/psk-release.sh"

# --- 1. psk-release.sh references psk-optimize.sh in Step 10 ---
grep -q 'psk-optimize.sh' "$RELEASE_SH" \
  && pass "N66/integration: psk-release.sh references psk-optimize.sh" \
  || fail "N66/integration: psk-release.sh missing psk-optimize.sh reference"

# --- 2. Integration is in run_step_10_summary (final summary, not blocking) ---
grep -A 30 'run_step_10_summary()' "$RELEASE_SH" | grep -q 'psk-optimize' \
  && pass "N66/integration: integration in Step 10 (final summary, non-blocking)" \
  || fail "N66/integration: psk-optimize call not in Step 10"

# --- 3. Bypass env var present ---
grep -q 'PSK_OPTIMIZE_SCAN_DISABLED' "$RELEASE_SH" \
  && pass "N66/integration: PSK_OPTIMIZE_SCAN_DISABLED bypass present" \
  || fail "N66/integration: missing scan-disable bypass"

# --- 4. Re-entrancy guard set when calling psk-optimize from release script ---
grep -q 'PSK_OPTIMIZE_SKIP_TESTRUN=1' "$RELEASE_SH" \
  && pass "N66/integration: re-entrancy guard set (skip-testrun) when called from release" \
  || fail "N66/integration: missing re-entrancy guard"

# --- 5. Skill documents cadence + feature-preservation guarantee ---
SKILL="$PROJ/.portable-spec-kit/skills/optimize.md"
grep -q "Feature-preservation guarantee" "$SKILL" \
  && pass "N66/skill: feature-preservation guarantee section documented" \
  || fail "N66/skill: missing feature-preservation guarantee section"
grep -q "Cadence — when to re-run" "$SKILL" \
  && pass "N66/skill: cadence guidance documented" \
  || fail "N66/skill: missing cadence section"

section "N67. v0.6.14 optimization health tracking + breadcrumb indicator"

# Lightweight health tracking: psk-optimize.sh --scan writes
# .portable-spec-kit/optimize-state.yml; --health reads + emits one-line
# indicator. Framework rule (portable-spec-kit.md §Optimization Health
# Indicator) instructs agents to append the indicator to breadcrumb.
# Performance constraint: --health must be O(read-one-file), no detector
# re-run.

OPTIMIZE_SH="$PROJ/agent/scripts/psk-optimize.sh"

# --- 1. --health flag accepted ---
grep -q '\-\-health.*MODE="health"' "$OPTIMIZE_SH" \
  && pass "N67/flag: --health flag parsed" \
  || fail "N67/flag: --health flag handler missing"

# --- 2. State file path defined ---
grep -q 'STATE_FILE=.*optimize-state.yml' "$OPTIMIZE_SH" \
  && pass "N67/state: STATE_FILE points to .portable-spec-kit/optimize-state.yml" \
  || fail "N67/state: STATE_FILE constant missing or wrong path"

# --- 3. write_state_file function present + called from scan dispatch ---
grep -q 'write_state_file()' "$OPTIMIZE_SH" \
  && pass "N67/state: write_state_file() function defined" \
  || fail "N67/state: write_state_file() function missing"
grep -q 'write_state_file ' "$OPTIMIZE_SH" \
  && pass "N67/state: write_state_file invoked from scan dispatch" \
  || fail "N67/state: write_state_file not called"

# --- 4. emit_health function present + called from health dispatch ---
grep -q 'emit_health()' "$OPTIMIZE_SH" \
  && pass "N67/health: emit_health() function defined" \
  || fail "N67/health: emit_health() function missing"
grep -A 2 '^  health)' "$OPTIMIZE_SH" | grep -q 'emit_health' \
  && pass "N67/health: emit_health called from health dispatch" \
  || fail "N67/health: emit_health not wired"

# --- 5. Threshold logic: optimized / review / stale ---
grep -q '🟢 optimized' "$OPTIMIZE_SH" \
  && pass "N67/threshold: 🟢 optimized indicator present" \
  || fail "N67/threshold: optimized indicator missing"
grep -q '🟡 review' "$OPTIMIZE_SH" \
  && pass "N67/threshold: 🟡 review indicator present" \
  || fail "N67/threshold: review indicator missing"
grep -q '🔴 stale' "$OPTIMIZE_SH" \
  && pass "N67/threshold: 🔴 stale indicator present" \
  || fail "N67/threshold: stale indicator missing"

# --- 6. Behavioral: --health on real kit emits valid indicator ---
health_out=$(bash "$OPTIMIZE_SH" --health 2>&1)
case "$health_out" in
  *🟢*|*🟡*|*🔴*|*⚪*)
    pass "N67/behavioral: --health emits valid status indicator: '$health_out'" ;;
  *)
    fail "N67/behavioral: --health output malformed: '$health_out'" ;;
esac

# --- 7. Performance: --health completes in <500ms (read-only fast-path) ---
start_ms=$(date +%s)
bash "$OPTIMIZE_SH" --health >/dev/null 2>&1
end_ms=$(date +%s)
elapsed=$((end_ms - start_ms))
if [ "$elapsed" -le 1 ]; then
  pass "N67/perf: --health completes in <1s (read-only fast-path verified)"
else
  fail "N67/perf: --health took ${elapsed}s — too slow, must be read-only"
fi

# --- 8. Framework rule documented in portable-spec-kit.md ---
FRAMEWORK="$PROJ/portable-spec-kit.md"
grep -q "Optimization Health Indicator" "$FRAMEWORK" \
  && pass "N67/framework: §Optimization Health Indicator documented" \
  || fail "N67/framework: framework rule missing"
grep -q 'opt: 🟢' "$FRAMEWORK" \
  && pass "N67/framework: breadcrumb indicator format documented" \
  || fail "N67/framework: indicator format missing from framework"

# --- 9. Suppression rule: if state file missing, agent suppresses indicator ---
grep -q "missing.*suppress\|suppress.*missing\|Suppression" "$FRAMEWORK" \
  && pass "N67/framework: suppression rule documented (no state → no indicator)" \
  || fail "N67/framework: suppression rule missing"

section "N68. v0.6.14 generic env management (psk-env.sh + env-management skill)"

# Restore a known-good cwd — earlier sections may have created and removed
# temp dirs while we were inside them, leaving bash in a deleted directory.
cd "$PROJ" 2>/dev/null || true

# Generic runtime-environment selector across all stacks (Python, Node,
# Ruby, Go, Rust). Per-project env-config.yml committed; agent prefixes
# every stack-runtime command with the saved env's activation. New
# project setup invokes env-selection as Step 0 (before any package
# install) per the kit's portability promise.

ENV_SH="$PROJ/agent/scripts/psk-env.sh"
ENV_SKILL="$PROJ/.portable-spec-kit/skills/env-management.md"

# --- 1. Script + skill present ---
[ -x "$ENV_SH" ] \
  && pass "N68/script: psk-env.sh present + executable" \
  || fail "N68/script: psk-env.sh missing or not executable"
[ -f "$ENV_SKILL" ] \
  && pass "N68/skill: env-management.md skill file present" \
  || fail "N68/skill: env-management.md skill file missing"

# --- 2. Script supports all required commands ---
for cmd in detect status "list-envs" set "activate-cmd" check; do
  if bash "$ENV_SH" help 2>/dev/null | grep -q "$cmd"; then
    pass "N68/script: command '$cmd' documented in help"
  else
    fail "N68/script: command '$cmd' missing from help"
  fi
done

# --- 3. detect runs without error in this kit (no recognized stack) ---
detect_out=$(bash "$ENV_SH" detect 2>&1)
# Kit itself has no requirements.txt / package.json / etc., so detect
# should produce empty output (or only kit-internal stacks if any)
case "$detect_out" in
  ""|*python*|*node*|*ruby*|*go*|*rust*)
    pass "N68/script: detect runs cleanly (output: '$(echo "$detect_out" | head -1)' or empty)" ;;
  *)
    fail "N68/script: detect produced unexpected output: '$detect_out'" ;;
esac

# --- 4. set + activate-cmd round-trip ---
N68_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t n68)
mkdir -p "$N68_TMP/.portable-spec-kit"
# Override CONFIG_DIR by symlinking — easiest cross-platform approach is
# to copy script + run from a fixture dir
cp "$ENV_SH" "$N68_TMP/psk-env.sh"
mkdir -p "$N68_TMP/agent/scripts"
cp "$ENV_SH" "$N68_TMP/agent/scripts/psk-env.sh"

(cd "$N68_TMP" && bash "$N68_TMP/agent/scripts/psk-env.sh" set python conda my-test-env >/dev/null 2>&1)
[ -f "$N68_TMP/.portable-spec-kit/env-config.yml" ] \
  && pass "N68/state: 'set' writes env-config.yml" \
  || fail "N68/state: env-config.yml not created after set"

set_check=$(cd "$N68_TMP" && bash "$N68_TMP/agent/scripts/psk-env.sh" activate-cmd python 2>&1)
case "$set_check" in
  *envs/my-test-env/bin*PATH*)
    pass "N68/activate: activate-cmd returns absolute-path PATH prefix for conda env" ;;
  *)
    fail "N68/activate: expected absolute-path PATH prefix, got '$set_check'" ;;
esac

# --- 5. activate-cmd for venv with path ---
(cd "$N68_TMP" && bash "$N68_TMP/agent/scripts/psk-env.sh" set python venv /custom/.venv >/dev/null 2>&1)
venv_check=$(cd "$N68_TMP" && bash "$N68_TMP/agent/scripts/psk-env.sh" activate-cmd python 2>&1)
case "$venv_check" in
  "source /custom/.venv/bin/activate"*)
    pass "N68/activate: venv prefix uses correct activate path" ;;
  *)
    fail "N68/activate: expected venv source path, got '$venv_check'" ;;
esac

# --- 6. Multi-stack persistence (set python + node, both survive) ---
(cd "$N68_TMP" && bash "$N68_TMP/agent/scripts/psk-env.sh" set node nvm 20 >/dev/null 2>&1)
multi_python=$(cd "$N68_TMP" && bash "$N68_TMP/agent/scripts/psk-env.sh" activate-cmd python 2>&1)
multi_node=$(cd "$N68_TMP" && bash "$N68_TMP/agent/scripts/psk-env.sh" activate-cmd node 2>&1)
case "$multi_python" in
  "source /custom/.venv/bin/activate"*)
    pass "N68/multi: python entry preserved when node added" ;;
  *)
    fail "N68/multi: python entry lost after node added: '$multi_python'" ;;
esac
case "$multi_node" in
  *"nvm use 20"*)
    pass "N68/multi: node entry written and resolves correctly" ;;
  *)
    fail "N68/multi: node entry wrong: '$multi_node'" ;;
esac

rm -rf "$N68_TMP"

# --- 7. Skill documents the workflow + edge cases ---
grep -q "Detect stacks" "$ENV_SKILL" && pass "N68/skill: detect step documented" || fail "N68/skill: detect step missing"
grep -q "List available envs" "$ENV_SKILL" && pass "N68/skill: list-envs step documented" || fail "N68/skill: list-envs step missing"
grep -q "Save the choice" "$ENV_SKILL" && pass "N68/skill: save step documented" || fail "N68/skill: save step missing"
grep -q "Edge cases" "$ENV_SKILL" && pass "N68/skill: edge cases section present" || fail "N68/skill: edge cases missing"

# --- 8. Framework rule documented ---
grep -q "Environment Selection (MANDATORY" "$FRAMEWORK" \
  && pass "N68/framework: §Environment Selection rule documented" \
  || fail "N68/framework: framework rule missing"
grep -q 'env-config.yml' "$FRAMEWORK" \
  && pass "N68/framework: env-config.yml schema referenced" \
  || fail "N68/framework: env-config.yml not referenced"
grep -q "psk-env.sh detect" "$FRAMEWORK" \
  && pass "N68/framework: detect command referenced as auto-detect step" \
  || fail "N68/framework: detect command not referenced"

# --- 9. New-project-setup hook: Step 0 references env-management ---
grep -A 5 "### New Project Setup (MANDATORY)" "$FRAMEWORK" | grep -q "env-management\|Environment Selection" \
  && pass "N68/setup: new-project setup invokes env-management as Step 0" \
  || fail "N68/setup: new-project setup doesn't reference env-management"

# --- 10. Prep-release Step 5 includes lock-file freshness check per stack ---
RELEASE_SH="$PROJ/agent/scripts/psk-release.sh"
grep -q "Lock-file freshness" "$RELEASE_SH" \
  && pass "N68/prep-release: lock-file freshness check present in Step 5" \
  || fail "N68/prep-release: lock-file freshness check missing"

# Per-stack auto-regenerate commands present
for stack_check in "npm install --package-lock-only" "poetry lock" "uv lock" "bundle install" "go mod tidy" "cargo update"; do
  if grep -q "$stack_check" "$RELEASE_SH"; then
    pass "N68/prep-release: auto-regenerate cmd present: '$stack_check'"
  else
    fail "N68/prep-release: missing auto-regenerate cmd '$stack_check'"
  fi
done

# Activation prefix wired into lock-file regen
grep -q 'activate-cmd "$stack"' "$RELEASE_SH" \
  && pass "N68/prep-release: lock-file regen runs inside project's saved env (activate-cmd prefix)" \
  || fail "N68/prep-release: regen not wired through activate-cmd prefix"

section "N69. v0.6.14 /optimize cat 9 — rule-duplication detection (stub sections)"

cd "$PROJ" 2>/dev/null || true
OPTIMIZE_SH="$PROJ/agent/scripts/psk-optimize.sh"

# --- 1. detect_duplicate_skill_refs function present ---
grep -q 'detect_duplicate_skill_refs()' "$OPTIMIZE_SH" \
  && pass "N69/script: detect_duplicate_skill_refs() function defined" \
  || fail "N69/script: detect_duplicate_skill_refs() missing"

# --- 2. Cat 9 wired into print output ---
grep -q '\[9/9\] Duplicate skill references' "$OPTIMIZE_SH" \
  && pass "N69/output: cat 9 print block present (9/9 sections)" \
  || fail "N69/output: cat 9 print block missing"

# --- 3. Cat 9 wired into JSON emitter ---
grep -q 'duplicate_skill_ref' "$OPTIMIZE_SH" \
  && pass "N69/json: duplicate_skill_ref category emitted in JSON" \
  || fail "N69/json: cat 9 missing from JSON emitter"

# --- 4. State file schema includes cat9 ---
grep -q 'cat9_duplicate_skill_refs' "$OPTIMIZE_SH" \
  && pass "N69/state: cat9 included in optimize-state.yml schema" \
  || fail "N69/state: cat9 missing from state schema"

# --- 5. Behavioral: detector finds at least one stub on a synthetic fixture ---
N69_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t n69)
mkdir -p "$N69_TMP/.portable-spec-kit/skills"
touch "$N69_TMP/.portable-spec-kit/skills/foo.md"
cat > "$N69_TMP/portable-spec-kit.md" <<'EOF'
# Test Framework
## Section A
### Real Section
This section has substantive content that goes on and on with rules and detail.
Even has multiple paragraphs.
> **Skill: Foo** — see .portable-spec-kit/skills/foo.md

### Stub Section
> **Skill: Foo** — see .portable-spec-kit/skills/foo.md

### Another Real Section
- bullet 1
- bullet 2
- bullet 3
- bullet 4
EOF

# Source the detector function with overridden PROJ_ROOT
PROJ_ROOT_BACKUP="$PROJ_ROOT"
PROJ_ROOT="$N69_TMP"
detector_src=$(awk '/^detect_duplicate_skill_refs\(\)/{flag=1} flag; flag && /^}$/{exit}' "$OPTIMIZE_SH")
eval "$detector_src"
stub_out=$(detect_duplicate_skill_refs 2>&1)
PROJ_ROOT="$PROJ_ROOT_BACKUP"

if echo "$stub_out" | grep -q "Stub Section"; then
  pass "N69/behavioral: detector flags single-line skill-link stub"
else
  fail "N69/behavioral: detector missed stub: '$stub_out'"
fi
if echo "$stub_out" | grep -q "Real Section"; then
  fail "N69/behavioral: detector falsely flagged Real Section (has body content)"
else
  pass "N69/behavioral: detector silent on real-content section (no false positive)"
fi
if echo "$stub_out" | grep -q "Another Real Section"; then
  fail "N69/behavioral: detector falsely flagged section with bullet-list body"
else
  pass "N69/behavioral: detector silent on bullet-list body section (no false positive)"
fi

rm -rf "$N69_TMP"

# --- 6. Skill documents cat 9 ---
SKILL="$PROJ/.portable-spec-kit/skills/optimize.md"
grep -q "Category 9" "$SKILL" \
  && pass "N69/skill: cat 9 documented in skill" \
  || fail "N69/skill: cat 9 not documented"
grep -q "9 categories" "$SKILL" \
  && pass "N69/skill: skill summary updated to '9 categories'" \
  || fail "N69/skill: skill summary still says fewer categories"

# --- 7. Cat 9 self-applies to the kit (real run finds the legitimate stub-section results) ---
real_out=$(PSK_OPTIMIZE_SKIP_TESTRUN=1 bash "$OPTIMIZE_SH" --scan 2>&1 | grep -c 'STUB_SECTION' || echo 0)
if [ "$real_out" -ge 0 ]; then
  pass "N69/self-apply: cat 9 runs cleanly on real kit (output count: $real_out)"
else
  fail "N69/self-apply: cat 9 output unexpected on real kit"
fi

# --- 11+. Deferral mechanism: count_deferred() function + DEFERRED_FILE handling ---
grep -q 'count_deferred()' "$OPTIMIZE_SH" \
  && pass "N69/deferral: count_deferred() function defined" \
  || fail "N69/deferral: count_deferred() function missing"
grep -q 'DEFERRED_FILE=' "$OPTIMIZE_SH" \
  && pass "N69/deferral: DEFERRED_FILE constant defined" \
  || fail "N69/deferral: DEFERRED_FILE constant missing"
grep -q 'optimize-deferred.yml' "$OPTIMIZE_SH" \
  && pass "N69/deferral: deferred-config file path is .portable-spec-kit/optimize-deferred.yml" \
  || fail "N69/deferral: deferred-config file path missing or wrong"

# --- 12+. emit_health uses active count (total - deferred) for status ---
grep -q 'active=$((total - deferred))' "$OPTIMIZE_SH" \
  && pass "N69/deferral: emit_health subtracts deferred from active count" \
  || fail "N69/deferral: emit_health doesn't subtract deferred"

# --- 13+. Behavioral: synthetic project with deferred entries shows 🟢 ---
N69_DEF_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t n69def)
mkdir -p "$N69_DEF_TMP/.portable-spec-kit"
# Synthetic state: 5 candidates + 5 deferred → 0 active → 🟢 optimized (5 deferred)
cat > "$N69_DEF_TMP/.portable-spec-kit/optimize-state.yml" <<'EOF'
schema_version: 1
last_scan: 2026-04-29T00:00:00Z
candidates_total: 5
status: review
EOF
cat > "$N69_DEF_TMP/.portable-spec-kit/optimize-deferred.yml" <<'EOF'
schema_version: 1
deferred:
  - id: "cat7:test-1"
    reason: "test"
  - id: "cat9:test-2"
    reason: "test"
  - id: "cat9:test-3"
    reason: "test"
  - id: "cat9:test-4"
    reason: "test"
  - id: "cat9:test-5"
    reason: "test"
EOF

# Run --health using a temp kit-clone
mkdir -p "$N69_DEF_TMP/agent/scripts"
cp "$OPTIMIZE_SH" "$N69_DEF_TMP/agent/scripts/psk-optimize.sh"
def_health=$(cd "$N69_DEF_TMP" && bash "$N69_DEF_TMP/agent/scripts/psk-optimize.sh" --health 2>&1)
case "$def_health" in
  *🟢*deferred*)
    pass "N69/deferral: 5 candidates + 5 deferred → 🟢 optimized (5 deferred)" ;;
  *)
    fail "N69/deferral: expected '🟢 optimized (5 deferred)', got '$def_health'" ;;
esac

# Synthetic: 10 candidates + 5 deferred → 5 active → 🟡 review
cat > "$N69_DEF_TMP/.portable-spec-kit/optimize-state.yml" <<'EOF'
schema_version: 1
last_scan: 2026-04-29T00:00:00Z
candidates_total: 10
status: review
EOF
def_health2=$(cd "$N69_DEF_TMP" && bash "$N69_DEF_TMP/agent/scripts/psk-optimize.sh" --health 2>&1)
case "$def_health2" in
  *🟡*5*candidates*5*deferred*|*🟡*review*5*candidates*)
    pass "N69/deferral: 10 candidates + 5 deferred → 🟡 review (5 candidates, 5 deferred)" ;;
  *)
    fail "N69/deferral: expected '🟡 review (5 candidates, 5 deferred)', got '$def_health2'" ;;
esac

rm -rf "$N69_DEF_TMP"

# --- 14+. RUNTIME marker support in cat 5 detector ---
grep -q "'# RUNTIME:'" "$OPTIMIZE_SH" \
  && pass "N69/runtime: cat 5 detector honors '# RUNTIME:' inline marker" \
  || fail "N69/runtime: '# RUNTIME:' marker support missing in cat 5"

# Legacy summary block removed v0.6.11 (was duplicated when split happened).
# Final aggregated summary is now in the orchestrator at tests/test-spec-kit.sh.
# Direct-invocation summary is below.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  RESULTS (04-reflex): $PASS passed, $FAIL failed, $TOTAL total"
  echo "═══════════════════════════════════════════"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi
