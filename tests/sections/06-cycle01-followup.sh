#!/bin/bash
# tests/sections/06-cycle01-followup.sh — regression tests for the cycle-01
# follow-up fixes (post-GRANT dispositions). Four independent fixes:
#
#   QA-META-PHIL-03 — concurrent psk-spawn.sh race: shared spawn-state writes are
#                      now atomic (tmp+mv) and the multi-request batch is serialised
#                      under an mkdir-based lock. No orphan tmp files, no stuck lock.
#   QA-D6-P8        — eval removed from psk-conformance.sh: registry-sourced
#                      detect/fix command strings dispatch via `bash -c`, not `eval`.
#   QA-D17          — summary.csv wall_clock/tool_call columns: score.sh's
#                      extract_usage_field now falls back to the `totals:` /
#                      `aggregate:` block when the top-level key is absent
#                      (orchestrated multi-author QA usage schema).
#   QA-D31-001      — psk-install-hooks.sh: generated hook bodies anchor the repo
#                      root deterministically (baked $GIT_ROOT at install time, with
#                      runtime rev-parse as a guarded fallback only) instead of a
#                      bare CWD-dependent `git rev-parse --show-toplevel`.
#
# Independently runnable: bash tests/sections/06-cycle01-followup.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

SPAWN_SH="$PROJ/agent/scripts/psk-spawn.sh"
CONFORMANCE_SH="$PROJ/agent/scripts/psk-conformance.sh"
SCORE_SH="$PROJ/reflex/lib/score.sh"
INSTALL_HOOKS_SH="$PROJ/agent/scripts/psk-install-hooks.sh"

# ── QA-META-PHIL-03 — concurrent psk-spawn.sh race safety ────────────────────
section "N. Cycle-01 follow-up — QA-META-PHIL-03 spawn-state concurrency"

# Source-level: the concurrency primitives exist and are used.
grep -q '_atomic_write()' "$SPAWN_SH" \
  && pass "06.1: psk-spawn.sh defines _atomic_write (tmp+mv)" \
  || fail "06.1: psk-spawn.sh missing _atomic_write"

grep -q '_spawn_lock()' "$SPAWN_SH" && grep -q '_spawn_unlock()' "$SPAWN_SH" \
  && pass "06.2: psk-spawn.sh defines _spawn_lock/_spawn_unlock (mkdir mutex)" \
  || fail "06.2: psk-spawn.sh missing spawn lock helpers"

# request-multi must serialise the rm+write batch under the lock.
awk '/cmd_request_multi\(\)/{f=1} f&&/_spawn_lock/{print "L"} f&&/_spawn_unlock/{print "U"} /^}/{if(f)f=0}' "$SPAWN_SH" | grep -q 'L' \
  && pass "06.3: request-multi acquires the spawn-state lock" \
  || fail "06.3: request-multi does not acquire the spawn-state lock"

# The single-request writer uses atomic write (no bare `> "$req"` redirect).
grep -q '| _atomic_write "\$req"' "$SPAWN_SH" \
  && pass "06.4: cmd_request writes its request file atomically" \
  || fail "06.4: cmd_request still uses a non-atomic write"

# Bypass env var is documented.
grep -q 'PSK_SPAWN_LOCK_DISABLED' "$SPAWN_SH" \
  && pass "06.5: spawn lock has a documented emergency bypass" \
  || fail "06.5: spawn lock missing bypass env var"

# Behavioral: 6 parallel request-multi + 6 status on the same phase leaves
# exactly the manifest's request files, NO orphan tmp files, NO stuck lock.
SBX="$(mktemp -d)"
mkdir -p "$SBX/agent/scripts"
for s in psk-spawn.sh psk-workflow-state.sh psk-retry-queue.sh psk-bypass-log.sh psk-model-policy.sh psk-prompt-lint.sh; do
  cp "$PROJ/agent/scripts/$s" "$SBX/agent/scripts/" 2>/dev/null
done
cat > "$SBX/wave.yaml" <<'WAVEEOF'
schema_version: 1
workflow: cfwf
phase: cfphase
spawns:
  - id: sp-1
    prompt: P1
    artifact: A1
  - id: sp-2
    prompt: P2
    artifact: A2
WAVEEOF
touch "$SBX/P1" "$SBX/P2"
for _i in 1 2 3 4 5 6; do
  ( PROJ_ROOT="$SBX" PSK_PROMPT_FIDELITY_DISABLED=1 PSK_ENV_AUTO_DETECT=0 \
      bash "$SBX/agent/scripts/psk-spawn.sh" request-multi cfwf cfphase "$SBX/wave.yaml" >/dev/null 2>&1 ) &
  ( PROJ_ROOT="$SBX" PSK_PROMPT_FIDELITY_DISABLED=1 \
      bash "$SBX/agent/scripts/psk-spawn.sh" status cfwf cfphase >/dev/null 2>&1 ) &
done
wait

req_count=$(ls "$SBX/agent/.workflow-state/spawn/"cfwf.cfphase.*.request 2>/dev/null | wc -l | tr -d ' ')
[ "$req_count" = "2" ] \
  && pass "06.6: after 6 concurrent request-multi, exactly 2 request files remain" \
  || fail "06.6: concurrent request-multi left $req_count request files (expected 2)"

orphan_tmp=$(ls "$SBX/agent/.workflow-state/spawn/"*.tmp.* 2>/dev/null | wc -l | tr -d ' ')
[ "$orphan_tmp" = "0" ] \
  && pass "06.7: no orphan .tmp files leaked under concurrent spawn writes" \
  || fail "06.7: $orphan_tmp orphan .tmp files leaked (atomic-write race)"

[ ! -d "$SBX/agent/.workflow-state/spawn/.spawn-state.lock" ] \
  && pass "06.8: spawn-state lock released after concurrent batch (no deadlock)" \
  || fail "06.8: spawn-state lock left stuck after concurrent batch"

# Request files are well-formed (atomic write produced complete content, not a
# truncated fragment) — every file has all 6 expected keys.
wellformed=1
for rf in "$SBX/agent/.workflow-state/spawn/"cfwf.cfphase.*.request; do
  [ -f "$rf" ] || continue
  for key in WORKFLOW PHASE SPAWN_ID PROMPT_FILE RESULT_ARTIFACT REQUESTED; do
    grep -q "^${key}=" "$rf" || wellformed=0
  done
done
[ "$wellformed" = "1" ] \
  && pass "06.9: every request file is complete (atomic write, no truncation)" \
  || fail "06.9: a request file was truncated/incomplete"
rm -rf "$SBX"

# ── QA-D6-P8 — no eval in psk-conformance.sh ─────────────────────────────────
section "N. Cycle-01 follow-up — QA-D6-P8 eval-free conformance dispatch"

# Replicate psk-code-review.sh's bash-eval detector: unallowlisted `eval "$`/`eval $`.
ceval_hits=$(grep -nE '^[^#]*\beval[[:space:]]+["$]' "$CONFORMANCE_SH" 2>/dev/null || true)
[ -z "$ceval_hits" ] \
  && pass "06.10: psk-conformance.sh has no unallowlisted eval invocation" \
  || fail "06.10: psk-conformance.sh still calls eval: $ceval_hits"

# The detect/fix dispatch uses `bash -c`.
grep -cq 'bash -c "\$det_cmd"' "$CONFORMANCE_SH" 2>/dev/null && grep -q 'bash -c "\$fix_cmd"' "$CONFORMANCE_SH" \
  && pass "06.11: psk-conformance.sh dispatches detect/fix via bash -c" \
  || fail "06.11: psk-conformance.sh does not dispatch via bash -c"

# SCRIPT_DIR is exported so the child shell resolves built-in check commands.
grep -q '^export SCRIPT_DIR' "$CONFORMANCE_SH" \
  && pass "06.12: psk-conformance.sh exports SCRIPT_DIR for bash -c children" \
  || fail "06.12: psk-conformance.sh does not export SCRIPT_DIR"

# Behavioral: --list still resolves the check set, --check still runs (exit 0/1
# both acceptable — we only assert it executes detectors without an eval error).
if bash "$CONFORMANCE_SH" --list >/dev/null 2>&1; then
  pass "06.13: psk-conformance.sh --list runs cleanly (eval-free dispatch)"
else
  fail "06.13: psk-conformance.sh --list failed after eval removal"
fi

clist=$(bash "$CONFORMANCE_SH" --list 2>/dev/null | grep -c '^  - ')
[ "${clist:-0}" -ge 4 ] \
  && pass "06.14: --list resolves >=4 checks (built-ins intact after refactor)" \
  || fail "06.14: --list resolved only ${clist:-0} checks (built-ins broken)"

# ── QA-D17 — summary.csv usage columns sourced from totals/aggregate block ───
section "N. Cycle-01 follow-up — QA-D17 score.sh usage-field extraction"

# Source-level: extract_usage_field has the totals/aggregate fallback.
grep -q 'totals|aggregate' "$SCORE_SH" \
  && pass "06.15: score.sh extract_usage_field falls back to totals/aggregate block" \
  || fail "06.15: score.sh extract_usage_field has no aggregate-block fallback"

grep -q '_num_or_blank' "$SCORE_SH" \
  && pass "06.16: score.sh coerces numeric usage columns to digits-or-blank" \
  || fail "06.16: score.sh missing numeric coercion for usage columns"

# Behavioral: run score.sh against a synthetic pass whose qa-usage.yaml records
# tool_calls/wall_clock ONLY under a `totals:` block (the orchestrated schema).
# Assert the emitted CSV row carries the real values, not blank.
SBX2="$(mktemp -d)"
PD="$SBX2/reflex/history/cycle-09/pass-001"
mkdir -p "$PD" "$SBX2/agent/.release-state"
cat > "$PD/.cycle-meta" <<'METAEOF'
cycle=9
iteration=1
mode=test
started=2026-06-16T00:00:00Z
METAEOF
cat > "$PD/qa-usage.yaml" <<'QAEOF'
pass: cycle-09/pass-001
mode: orchestrated-multi-author
totals:
  tokens_used: 777000
  tool_calls: 333
  wall_clock_seconds: 4444
QAEOF
cat > "$PD/dev-usage.yaml" <<'DEVEOF'
tokens_used: 111000
tool_calls: 22
wall_clock_seconds: 900
DEVEOF
# Minimal findings.yaml so qa_findings parses without affecting usage columns.
cat > "$PD/findings.yaml" <<'FINDEOF'
findings:
  - id: QA-X-1
    severity: MINOR
FINDEOF

REFLEX_PROJ_ROOT="$SBX2" REFLEX_PASS_DIR="$PD" REFLEX_GATES_STATUS="pass" \
  bash "$SCORE_SH" >/dev/null 2>&1
score_rc=$?
row=$(grep '^9,1,' "$SBX2/reflex/history/summary.csv" 2>/dev/null | tail -1)
# columns: cycle,pass,date,qa_findings,dev_fixes,escalated,features_tested,
#          surprise_density,progress,gates_status,qa_tokens,dev_tokens,
#          qa_tool_calls,dev_tool_calls,wall_clock_seconds,pass_score,probe_coverage_pct
qa_tok=$(echo "$row"  | awk -F',' '{print $11}')
qa_tc=$(echo "$row"   | awk -F',' '{print $13}')
wall=$(echo "$row"    | awk -F',' '{print $15}')

[ "$score_rc" = "0" ] \
  && pass "06.17: score.sh runs against an orchestrated-schema pass" \
  || fail "06.17: score.sh failed on orchestrated-schema pass (rc=$score_rc)"

[ "$qa_tc" = "333" ] \
  && pass "06.18: qa_tool_calls sourced from totals: block (got 333)" \
  || fail "06.18: qa_tool_calls=[$qa_tc] not sourced from totals: block (expected 333)"

[ "$qa_tok" = "777000" ] \
  && pass "06.19: qa_tokens sourced from totals: block (got 777000)" \
  || fail "06.19: qa_tokens=[$qa_tok] not sourced from totals: block (expected 777000)"

# wall_clock = max(qa 4444, dev 900) = 4444
[ "$wall" = "4444" ] \
  && pass "06.20: wall_clock_seconds = max(qa,dev) from totals block (got 4444)" \
  || fail "06.20: wall_clock_seconds=[$wall] wrong (expected 4444)"

# A non-numeric placeholder under totals must coerce to blank, not pollute the CSV.
cat > "$PD/qa-usage.yaml" <<'QAEOF2'
pass: cycle-09/pass-001
mode: orchestrated-multi-author
totals:
  tool_calls: not-instrumented
  wall_clock_seconds: 4444
QAEOF2
REFLEX_PROJ_ROOT="$SBX2" REFLEX_PASS_DIR="$PD" REFLEX_GATES_STATUS="pass" \
  bash "$SCORE_SH" >/dev/null 2>&1
row2=$(grep '^9,1,' "$SBX2/reflex/history/summary.csv" 2>/dev/null | tail -1)
qa_tc2=$(echo "$row2" | awk -F',' '{print $13}')
[ -z "$qa_tc2" ] \
  && pass "06.21: non-numeric usage value coerced to blank (CSV stays numeric-clean)" \
  || fail "06.21: non-numeric usage value leaked into CSV: [$qa_tc2]"
rm -rf "$SBX2"

# ── QA-D31-001 — deterministic repo-root anchoring in generated hook bodies ──
section "N. Cycle-01 follow-up — QA-D31-001 hook root anchoring"

# Source-level: no fresh-install heredoc still emits a bare top-level
# `REPO_ROOT="$(git rev-parse ...)"` / `ROOT="$(git rev-parse ...)"` as the
# PRIMARY anchor. The only rev-parse left in a hook body must be the guarded
# fallback (preceded by `if [ ! -d ... ]`). Assert every rev-parse line inside
# the installer's heredocs is on an `if [ ! -d` fallback line.
unguarded=$(grep -nE 'rev-parse --show-toplevel' "$INSTALL_HOOKS_SH" \
  | grep -vE '^[0-9]+:[[:space:]]*#' \
  | grep -vE 'if \[ ! -d ' \
  | grep -vE 'git -C ' || true)
[ -z "$unguarded" ] \
  && pass "06.22: install-hooks has no unguarded/un-anchored rev-parse in hook bodies" \
  || fail "06.22: install-hooks still emits an unguarded rev-parse: $unguarded"

# The installer bakes the known root as the primary anchor.
grep -q 'PSK_REPO_ROOT="$GIT_ROOT"' "$INSTALL_HOOKS_SH" \
  && pass "06.23: install-hooks bakes PSK_REPO_ROOT=\$GIT_ROOT into hooks" \
  || fail "06.23: install-hooks does not bake the known root anchor"

# Behavioral: install into a throwaway repo, assert all 3 hooks (a) bake the
# literal repo root, (b) pass bash -n, (c) the post-commit hook resolves the
# root from a FOREIGN cwd (CWD-independence — the core of QA-D31-001).
HBX="$(mktemp -d)"
mkdir -p "$HBX/agent/scripts" "$HBX/agent/.workflow-state"
cp "$INSTALL_HOOKS_SH" "$HBX/agent/scripts/"
printf '#!/bin/bash\nexit 0\n' > "$HBX/agent/scripts/psk-sync-check.sh"
chmod +x "$HBX/agent/scripts/psk-sync-check.sh"
git -C "$HBX" init -q
git -C "$HBX" config user.email t@t.t; git -C "$HBX" config user.name t
( cd "$HBX" && bash agent/scripts/psk-install-hooks.sh >/dev/null 2>&1 )
HROOT=$(git -C "$HBX" rev-parse --show-toplevel)

baked_ok=1
for hook in pre-commit pre-push post-commit; do
  [ -f "$HBX/.git/hooks/$hook" ] || { baked_ok=0; continue; }
  grep -qF "\"$HROOT\"" "$HBX/.git/hooks/$hook" || baked_ok=0
  bash -n "$HBX/.git/hooks/$hook" 2>/dev/null || baked_ok=0
done
[ "$baked_ok" = "1" ] \
  && pass "06.24: all 3 generated hooks bake the literal repo root + pass bash -n" \
  || fail "06.24: a generated hook is missing the baked root or has a syntax error"

# CWD-independence: run post-commit from /tmp (NOT the worktree). A bare
# unanchored rev-parse here would resolve to /tmp's repo (or empty); the baked
# anchor resolves to the real root, writing the PSK029 marker.
( cd /tmp && bash "$HBX/.git/hooks/post-commit" >/dev/null 2>&1 )
[ -f "$HBX/agent/.workflow-state/session-audit.log" ] \
  && pass "06.25: post-commit hook resolves baked root from foreign cwd (CWD-independent)" \
  || fail "06.25: post-commit hook did not resolve root from foreign cwd"
rm -rf "$HBX"
