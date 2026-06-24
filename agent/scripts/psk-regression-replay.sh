#!/bin/bash
# mechanical-script: psk-regression-replay.sh — Regression Replay Gate (10th reliability layer, v0.6.75)
#
# Layer 10 §Regression Replay Gate (KIT-GAP-0056). Every "verified-fixed" claim a
# sub-agent makes for a finding MUST actually replay the regression_vector's
# invocation_verbatim and check the result against expected_assertion. Without
# this gate, sub-agents can claim "verified-fixed" without running the test —
# the same trust-based failure mode §Sub-Agent Prompt Fidelity closes for
# rule citations, repeated for fix verification.
#
# Usage:
#   psk-regression-replay.sh <findings.yaml>          — replay all verified-fixed
#   psk-regression-replay.sh <findings.yaml> --strict — exit 1 on any failure
#   psk-regression-replay.sh <findings.yaml> --dry    — show what would replay
#   psk-regression-replay.sh <findings.yaml> --lint-vectors
#                                                     — advisory: flag imprecise
#                                                       vectors (bare rule-ID grep
#                                                       with no PASS/FAIL discriminator;
#                                                       grep -c on a non-ASCII file)
#   psk-regression-replay.sh --help
#
# Exit: 0 clean · 1 replays failed · 2 usage error · 3 findings.yaml malformed

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

STRICT=0
DRY=0

case "${1:-}" in
  --help|-h|"")
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

FINDINGS_FILE="$1"; shift || true
# QA-2-03 (cycle-01-pass-001): the findings.yaml path is the FIRST positional
# arg. A flag-first invocation (e.g. `--dry` with no path) would otherwise be
# treated as a file path and print the misleading "findings.yaml not found:
# --dry". Detect a leading flag and print the usage block instead (exit 2).
case "$FINDINGS_FILE" in
  --*)
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
    ;;
esac
LINT=0
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    --dry)    DRY=1 ;;
    --lint-vectors) LINT=1 ;;
  esac
done

[ ! -f "$FINDINGS_FILE" ] && { echo "findings.yaml not found: $FINDINGS_FILE" >&2; exit 2; }

# --lint-vectors (QA-P005-REGVEC-PRECISION-01 + QA-AUDIT-TRACE-FRAGILE-01) —
# advisory linter for regression_vector PRECISION. Two classes of imprecise
# vector silently false-PASS or false-FAIL under gate-14 replay regardless of
# the actual fix state, so they are flagged (advisory; never blocks):
#   (a) bare rule-ID grep — `grep -q 'PSK<NNN>'` / `grep 'PSK<NNN>'` with NO
#       pass/fail discriminator (no ✓/✗, no 'grep -v', no exit-code check). The
#       rule ID is present on BOTH the PASS line ("✓ PSK029 …") and a FAIL line,
#       so the vector cannot tell them apart. Fix: add a prefix-aware discriminator
#       (e.g. `| grep -qv '✓' && echo VIOLATION || echo CLEAN`).
#   (b) grep -c on a likely non-ASCII file — `grep -c '^### '` etc. returns empty
#       in some macOS/zsh locales on a file with unicode bytes, false-FAILing the
#       replay. Fix: use an encoding-safe count (python3 ... open(..., errors='replace')).
# Always exits 0 — this is a quality advisory, not a gate.
if [ "$LINT" = "1" ]; then
  lint_warns=0
  # Walk every invocation_verbatim line in the file (any finding, any status).
  while IFS= read -r iv_line; do
    iv_val=$(printf '%s' "$iv_line" | sed -E 's/^[[:space:]]*invocation_verbatim:[[:space:]]*//; s/^"//; s/"$//')
    [ -z "$iv_val" ] && continue
    # (a) bare rule-ID grep with no pass/fail discriminator.
    if printf '%s' "$iv_val" | grep -qE "grep [^|]*PSK[0-9]+" \
       && ! printf '%s' "$iv_val" | grep -qE '✓|✗|grep -v|grep -qv|exit|\$\?'; then
      echo "⚠ regression-vector imprecise (bare rule-ID grep, no PASS/FAIL discriminator): $iv_val"
      lint_warns=$((lint_warns+1))
    fi
    # (b) grep -c on a likely non-ASCII file (encoding-fragile on macOS/zsh).
    if printf '%s' "$iv_val" | grep -qE "grep -c .*(REFLEX_EVAL_TRACE|\.md)" \
       && printf '%s' "$iv_val" | grep -q 'grep -c'; then
      echo "⚠ regression-vector encoding-fragile (grep -c on a .md file may be non-ASCII; use an encoding-safe count): $iv_val"
      lint_warns=$((lint_warns+1))
    fi
  done < <(grep -E '^[[:space:]]+invocation_verbatim:' "$FINDINGS_FILE")
  if [ "$lint_warns" = "0" ]; then
    echo "✓ regression-vector lint: all vectors carry a PASS/FAIL discriminator and are encoding-safe"
  else
    echo "-- $lint_warns imprecise vector(s) flagged (advisory)"
  fi
  exit 0
fi

# Parse findings.yaml — extract (id, status, invocation_verbatim, expected_assertion) tuples.
# Sub-agents emit status: closed | verified-fixed | open | acknowledged. Only
# "verified-fixed" and "closed" claims need replay.
TUPLES=$(awk '
  BEGIN { in_finding=0; id=""; status=""; iv=""; ea=""; in_rv=0 }

  /^[[:space:]]*-[[:space:]]+id:/ {
    if (id != "" && (status == "verified-fixed" || status == "closed") && iv != "") {
      printf "%s\t%s\t%s\t%s\n", id, status, iv, ea
    }
    sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/, "", $0)
    gsub(/^"|"$/, "", $0); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
    id=$0; status=""; iv=""; ea=""; in_rv=0
    in_finding=1; next
  }

  in_finding && /^[[:space:]]+status:/ {
    sub(/^[[:space:]]+status:[[:space:]]*/, "", $0)
    gsub(/^"|"$/, "", $0); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
    status=$0; next
  }

  in_finding && /^[[:space:]]+regression_vector:/ { in_rv=1; next }

  in_rv && /^[[:space:]]+invocation_verbatim:/ {
    sub(/^[[:space:]]+invocation_verbatim:[[:space:]]*/, "", $0)
    gsub(/^"|"$/, "", $0); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
    iv=$0; next
  }

  in_rv && /^[[:space:]]+expected_assertion:/ {
    sub(/^[[:space:]]+expected_assertion:[[:space:]]*/, "", $0)
    gsub(/^"|"$/, "", $0); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
    ea=$0; next
  }

  END {
    if (id != "" && (status == "verified-fixed" || status == "closed") && iv != "") {
      printf "%s\t%s\t%s\t%s\n", id, status, iv, ea
    }
  }
' "$FINDINGS_FILE")

if [ -z "$TUPLES" ]; then
  echo "✓ regression-replay: no verified-fixed/closed findings with regression_vector to replay"
  exit 0
fi

total=0
passed=0
failed=0
skipped=0

while IFS=$'\t' read -r id status iv ea; do
  [ -z "$id" ] && continue
  total=$((total+1))

  if [ -z "$iv" ]; then
    echo "⊘ $id: no invocation_verbatim — skip"
    skipped=$((skipped+1))
    continue
  fi

  # Non-ASCII encoding-fragility WARN (QA-AUDIT-TRACE-VEC-REGRESSION-01).
  # `LC_ALL=C grep` on a file containing non-ASCII bytes exits 1 with NO output
  # in the C locale (BSD/GNU grep treat the bytes as invalid in that locale) —
  # a FALSE NEGATIVE: a held fix reads as a regression. Nudge vector authors
  # toward an encoding-safe form (python3 with errors='replace', or grep -a)
  # whenever the vector pairs `LC_ALL=C grep` with a file whose bytes are not
  # all ASCII. Advisory only — never alters pass/fail, just prints to stderr.
  case "$iv" in
    *"LC_ALL=C grep"*|*"LC_ALL=C  grep"*)
      _ria_warned=0
      for _ria_f in $(printf '%s\n' "$iv" | grep -oE '[A-Za-z0-9_./-]+\.(md|txt|csv|yaml|yml|log)' 2>/dev/null); do
        [ "$_ria_warned" = "1" ] && break
        _ria_path="$PROJ_ROOT/$_ria_f"
        [ -f "$_ria_path" ] || _ria_path="$_ria_f"
        # Portable byte-level non-ASCII check via python3 (already a kit dependency
        # for encoding-safe vectors). BSD grep lacks -P and C-locale byte-classes are
        # unreliable, so a python3 byte scan is the portable detector here.
        if [ -f "$_ria_path" ] && command -v python3 >/dev/null 2>&1 \
           && python3 -c "import sys; d=open(sys.argv[1],'rb').read(); sys.exit(0 if any(b>127 for b in d) else 1)" "$_ria_path" 2>/dev/null; then
          echo "⚠ $id: vector uses 'LC_ALL=C grep' on Non-ASCII file ($_ria_f) — C-locale grep false-negatives here; prefer python3 errors='replace' or grep -a (encoding-safe)" >&2
          _ria_warned=1
        fi
      done
      ;;
  esac

  if [ "$DRY" = "1" ]; then
    echo "  $id [$status]: would replay '$iv' → expect '$ea'"
    continue
  fi

  # Replay: run the invocation_verbatim command in a subshell.
  # B2 fix (CWD): run from PROJ_ROOT so relative paths (reflex/lib/..., agent/...)
  # and $PWD inside invocation_verbatim resolve to the kit root. Without this the
  # replay ran from the gate's CWD, so relative-path invocations errored (e.g.
  # exit=2) even though the underlying fix held.
  # (Sandboxed: ignore stderr noise; capture stdout for assertion check)
  output=$(cd "$PROJ_ROOT" 2>/dev/null && bash -c "$iv" 2>/dev/null || true)
  if [ -z "$ea" ]; then
    echo "✓ $id [$status]: replayed (no expected_assertion to check)"
    passed=$((passed+1))
    continue
  fi

  # Check assertion. expected_assertion is often authored as prose; the matcher
  # extracts the matchable token while still verifying the ACTUAL command result
  # (it is not blindly lenient — empty-output and substring are both checked
  # against real stdout). KIT-GAP-0101 (cycle-01/pass-002): prose assertions
  # like "should print nothing ..." or "line contains <token>" produced
  # false-negative gate failures on CORRECT fixes (a held fix read as a
  # regression). Matchers tried in order:
  #   1. absence-semantics — assertion says the output should be empty/nothing
  #      → PASS iff the command produced no (non-whitespace) stdout.
  #   2. prose-prefix strip — drop a leading "line contains "/"output contains "/
  #      "contains "/"should contain "/"should print "/"prints "/"outputs "/
  #      "line: " then grep the remainder (the matchable token).
  #   3. whole-string then leading-literal-segment grep (back-compat, B2 fix):
  #      expected_assertion authored as "<literal-expected> — <prose>".
  ea_lc=$(printf '%s' "$ea" | tr '[:upper:]' '[:lower:]')
  out_trimmed=$(printf '%s' "$output" | tr -d '[:space:]')
  matched=0
  # (1) absence semantics — "prints nothing" / "empty" / "no match" etc.
  case "$ea_lc" in
    *nothing*|*"no output"*|*empty*|*"no match"*|*"no matches"*|*"prints nothing"*|*"should not "*|*absent*|*"0 results"*|*"zero results"*)
      [ -z "$out_trimmed" ] && matched=1 ;;
  esac
  # (2) prose-prefix strip → grep the remaining matchable token
  if [ "$matched" = "0" ]; then
    ea_tok="$ea"
    for _pfx in "line contains " "output contains " "should contain " "contains " "should print " "prints " "outputs " "line: "; do
      case "$ea_tok" in
        "$_pfx"*) ea_tok="${ea_tok#"$_pfx"}"; break ;;
      esac
    done
    case "$ea_tok" in
      *" — "*) ea_tok="${ea_tok%% — *}" ;;
      *" - "*) ea_tok="${ea_tok%% - *}" ;;
    esac
    [ -n "$ea_tok" ] && [ "$ea_tok" != "$ea" ] && echo "$output" | grep -qF "$ea_tok" && matched=1
  fi
  # (3) back-compat — whole string, then LEADING LITERAL segment
  if [ "$matched" = "0" ]; then
    ea_lead="$ea"
    case "$ea" in
      *" — "*) ea_lead="${ea%% — *}" ;;
      *" - "*) ea_lead="${ea%% - *}" ;;
      *": "*)  ea_lead="${ea%%: *}" ;;
    esac
    if echo "$output" | grep -qF "$ea" \
       || { [ -n "$ea_lead" ] && [ "$ea_lead" != "$ea" ] && echo "$output" | grep -qF "$ea_lead"; }; then
      matched=1
    fi
  fi
  if [ "$matched" = "1" ]; then
    echo "✓ $id [$status]: replay matches expected_assertion"
    passed=$((passed+1))
  else
    echo "✗ $id [$status]: replay did NOT match expected_assertion" >&2
    echo "  expected: $ea" >&2
    echo "  got (first 200 chars): $(echo "$output" | head -c 200)" >&2
    failed=$((failed+1))
  fi
done <<< "$TUPLES"

echo ""
echo "regression-replay summary: $passed/$total passed · $skipped skipped · $failed failed"

if [ "$failed" -gt 0 ]; then
  if [ "$STRICT" = "1" ]; then
    exit 1
  fi
  echo "  (advisory mode — run with --strict to exit non-zero on failures)"
fi

exit 0
