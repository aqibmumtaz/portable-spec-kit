#!/bin/bash
# long-op: full test suite — self-wraps via psk-progress-selfwrap.sh (no-silent-wait / PSK047)
# ═══════════════════════════════════════════════════════════════
# Portable Spec Kit — Full Test Suite Orchestrator
#
# v0.6.11 — closes QA-TEST-COUPLING-01 (Option C, thematic split).
# This file is a THIN ORCHESTRATOR. Tests live in tests/sections/*.sh,
# each independently runnable. Shared helpers + globals in tests/lib.sh.
#
# Usage:
#   bash tests/test-spec-kit.sh                  # run all sections
#   bash tests/sections/01-infrastructure.sh     # run one section
#   bash tests/sections/04-reflex.sh             # ditto
#
# Why this design — the audit history:
#   QA-TEST-COUPLING-01 (v0.6.11 iter-1 finding) flagged that 69 of 70
#   features in SPECS.md all referenced this single test file. One flake
#   reported all 69 features as broken simultaneously. Option C splits
#   into thematic files preserving cohesion via tests/lib.sh while
#   restoring real per-section runtime independence.
#
# Aggregation pattern:
#   Each section file is sourced (not bash'd) by this orchestrator. They
#   share PASS/FAIL/TOTAL counters defined in tests/lib.sh, so totals
#   accumulate naturally across all sections without IPC. The orchestrator
#   prints the final aggregated summary.
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Save before sourcing sections — section files each redefine SCRIPT_DIR to
# point to tests/sections/, which would clobber the orchestrator's tests/ path.
ORCHESTRATOR_DIR="$SCRIPT_DIR"

# ── no-silent-wait self-wrap (default progress heartbeat) ───────────────────
# A direct `bash tests/test-spec-kit.sh` is a multi-minute silent wait — running
# slow looks identical to hung. Re-exec ourselves through psk-progress.sh so
# EVERY direct invocation emits an elapsed/✓✗-count heartbeat to stderr. Mechanism
# (precise): under the wrapper the suite's stdout+stderr are CAPTURED to the log and
# the last PSK_SELFWRAP_TAIL lines (incl. the `RESULTS:` line) are re-emitted to
# stderr; the EXIT CODE passes through verbatim. Every kit consumer either checks the
# exit code only, merges streams with `2>&1`, or reads the `--log` file — so the
# gate + test-release-check parsing is unaffected (heartbeats also go to stderr only).
#   PSK_PROGRESS_ACTIVE guard — prevents infinite re-exec AND double-wrap when a
#   reflex gate already routes us through psk-progress.sh (the wrapper exports
#   PSK_PROGRESS_ACTIVE=1 before running us, so we see it and skip).
#   PSK_PROGRESS_DISABLED=1 escape hatch — run with no wrap at all.
# Generic self-wrap — the ONE shared mechanism (agent/scripts/psk-progress-selfwrap.sh)
# every long-op script in the kit sources, so the monitor is wired consistently all over
# (no bespoke copy-paste). It re-execs us through psk-progress.sh on a fresh invocation;
# the PSK_PROGRESS_ACTIVE/PSK_PROGRESS_DISABLED guards live in the helper.
PSK_SELFWRAP_LABEL="test-spec-kit" PSK_SELFWRAP_METRIC='✓|✗' PSK_SELFWRAP_STAGE='═══' PSK_SELFWRAP_TAIL=12 \
  source "$ORCHESTRATOR_DIR/../agent/scripts/psk-progress-selfwrap.sh" "$@"

# Load shared helpers + globals (PASS/FAIL/TOTAL/PROJ/ROOT/kit_grep/...)
source "$SCRIPT_DIR/lib.sh"

# Section files in dependency order — infrastructure first (sets up TEMP +
# verifies framework files exist), then pipeline, then reliability, then
# reflex (largest, depends on rest of kit being intact).
SECTIONS=(
  "$SCRIPT_DIR/sections/01-infrastructure.sh"
  "$SCRIPT_DIR/sections/02-pipeline.sh"
  "$SCRIPT_DIR/sections/03-reliability.sh"
  "$SCRIPT_DIR/sections/04-reflex.sh"
  "$SCRIPT_DIR/sections/05-mandate-compliance.sh"
  "$SCRIPT_DIR/sections/06-cycle01-followup.sh"
  "$SCRIPT_DIR/sections/77-psk-session-monitor.sh"
  "$SCRIPT_DIR/sections/95-prompt-fidelity.sh"
  "$SCRIPT_DIR/sections/96-instruction-fidelity.sh"
  "$SCRIPT_DIR/sections/97-kit-fidelity.sh"
  "$SCRIPT_DIR/sections/98-script-coverage.sh"
)

# ── selection flags (Verification Fidelity — run a specific test THROUGH the harness) ──
# Uniform over the EXISTING structure: pick section file(s) and/or feature file(s), and/or
# narrow the reported tests via PSK_TEST_FILTER. No per-test relocation (that is Option 2,
# KIT-GAP-0106). A typo'd selector that matched nothing exits NON-ZERO — a verification
# runner must never false-green on a bad selector.
#   --section <NN|frag>  (repeatable)  source only matching tests/sections/*.sh
#   --feature <name>     (repeatable)  source only matching tests/features/f*.sh
#   --features-only                    skip sections, run only feature files
#   --filter <regex>                   export PSK_TEST_FILTER; report+count only matches
#   --list-sections                    print section + feature files, exit 0
#   (no args)                          all sections + all features (unchanged behavior)
_SECT_SEL=()        # --section fragments
_FEAT_SEL=()        # --feature fragments
_FEATURES_ONLY=0    # --features-only
_LIST_ONLY=0        # --list-sections
while [ $# -gt 0 ]; do
  case "$1" in
    --section|--feature|--filter)     # value-requiring — guard so a bare flag never hangs `shift 2`
      if [ $# -lt 2 ]; then echo "✗ $1 needs a value (try --help)" >&2; exit 2; fi
      case "$1" in
        --section) _SECT_SEL+=("$2") ;;
        --feature) _FEAT_SEL+=("$2") ;;
        --filter)  export PSK_TEST_FILTER="$2" ;;
      esac
      shift 2 ;;
    --section=*)     _SECT_SEL+=("${1#*=}"); shift ;;
    --feature=*)     _FEAT_SEL+=("${1#*=}"); shift ;;
    --filter=*)      export PSK_TEST_FILTER="${1#*=}"; shift ;;
    --features-only) _FEATURES_ONLY=1; shift ;;
    --list-sections) _LIST_ONLY=1; shift ;;
    -h|--help)
      echo "Usage: bash tests/test-spec-kit.sh [--section <NN|frag>]... [--feature <name>]... [--features-only] [--filter <regex>] [--list-sections]"
      exit 0 ;;
    *) echo "✗ unknown arg: $1 (try --help)" >&2; exit 2 ;;
  esac
done

# Validate --filter is a usable ERE once, here — one clear message instead of
# per-test grep stderr spam + a misleading "no tests matched filter" at the end.
# grep on empty input exits 1 for a valid no-match but >=2 for an invalid regex.
if [ -n "${PSK_TEST_FILTER:-}" ]; then
  grep -E "$PSK_TEST_FILTER" </dev/null >/dev/null 2>&1
  if [ "$?" -ge 2 ]; then
    echo "✗ --filter is not a valid ERE: $PSK_TEST_FILTER" >&2
    exit 2
  fi
fi

# Full feature-file list (used by --list-sections + --feature selection).
_ALL_FEATURES=()
if [ -d "$ORCHESTRATOR_DIR/features" ]; then
  for _ff in "$ORCHESTRATOR_DIR/features"/f*.sh; do
    [ -f "$_ff" ] && _ALL_FEATURES+=("$_ff")
  done
fi

# --list-sections: print available section + feature files, exit.
if [ "$_LIST_ONLY" -eq 1 ]; then
  echo "Sections (${#SECTIONS[@]}):"
  for s in "${SECTIONS[@]}"; do echo "  $(basename "$s")"; done
  echo "Features (${#_ALL_FEATURES[@]}):"
  for f in "${_ALL_FEATURES[@]}"; do echo "  $(basename "$f")"; done
  exit 0
fi

_has_sect=$([ "${#_SECT_SEL[@]}" -gt 0 ] && echo 1 || echo 0)
_has_feat=$([ "${#_FEAT_SEL[@]}" -gt 0 ] && echo 1 || echo 0)

# Effective sections (any-selector-narrows rule).
_EFFECTIVE_SECTIONS=()
if [ "$_FEATURES_ONLY" -eq 1 ]; then
  :                                   # --features-only → no sections
elif [ "$_has_sect" -eq 1 ]; then
  for s in "${SECTIONS[@]}"; do
    for frag in "${_SECT_SEL[@]}"; do
      if [[ "$(basename "$s")" == *"$frag"* ]]; then _EFFECTIVE_SECTIONS+=("$s"); break; fi
    done
  done
  if [ "${#_EFFECTIVE_SECTIONS[@]}" -eq 0 ]; then
    echo "✗ no sections matched: ${_SECT_SEL[*]}" >&2; exit 2
  fi
elif [ "$_has_feat" -eq 1 ]; then
  :                                   # --feature alone → no sections
else
  _EFFECTIVE_SECTIONS=("${SECTIONS[@]}")   # no selector → all sections
fi

# Effective features (any-selector-narrows rule).
_EFFECTIVE_FEATURES=()
if [ "$_has_feat" -eq 1 ]; then
  for f in "${_ALL_FEATURES[@]}"; do
    for frag in "${_FEAT_SEL[@]}"; do
      if [[ "$(basename "$f")" == *"$frag"* ]]; then _EFFECTIVE_FEATURES+=("$f"); break; fi
    done
  done
  if [ "${#_EFFECTIVE_FEATURES[@]}" -eq 0 ]; then
    echo "✗ no features matched: ${_FEAT_SEL[*]}" >&2; exit 2
  fi
elif [ "$_FEATURES_ONLY" -eq 1 ]; then
  _EFFECTIVE_FEATURES=("${_ALL_FEATURES[@]}")  # --features-only → all features
elif [ "$_has_sect" -eq 1 ]; then
  :                                   # --section alone → no features
else
  _EFFECTIVE_FEATURES=("${_ALL_FEATURES[@]}")  # no selector → all features
fi

if [ "${#_EFFECTIVE_SECTIONS[@]}" -gt 0 ]; then
  for s in "${_EFFECTIVE_SECTIONS[@]}"; do
    if [ ! -f "$s" ]; then
      echo "✗ section file missing: $s" >&2
      FAIL=$((FAIL + 1))
      TOTAL=$((TOTAL + 1))
      continue
    fi
    # shellcheck source=/dev/null
    source "$s"
  done
fi

# Phase T2 (Loop 4) — per-feature test discovery (Approach 3).
# Sources tests/features/f*.sh dynamically. Additive — runs alongside the
# legacy 5-section sourcing during the migration. Once all 70 features have
# been moved (Phase T5-T7), the section sourcing becomes redundant and
# sections/* will be converted to thin shims (Phase T9).
# Restore cwd: section edge-case tests (section 18) create+delete temp dirs,
# leaving the shell in a deleted directory. Feature file sourcing silently
# fails unless we return to a valid cwd first.
# Restore ORCHESTRATOR_DIR: section files redefine SCRIPT_DIR, clobbering it.
# Set selection: _EFFECTIVE_FEATURES (computed above per the any-selector-narrows rule).
cd "$PROJ" 2>/dev/null || cd / 2>/dev/null || true
if [ "${#_EFFECTIVE_FEATURES[@]}" -gt 0 ]; then
  echo ""
  echo "═══ Per-feature tests (tests/features/) ═══"
  for ff in "${_EFFECTIVE_FEATURES[@]}"; do
    [ -f "$ff" ] && source "$ff"
  done
fi

# Matched-nothing guard — a --filter that reported zero tests is a typo'd selector, not a
# pass. Exit NON-ZERO so a verification runner never false-greens on an empty selection.
if [ -n "${PSK_TEST_FILTER:-}" ] && [ "$TOTAL" -eq 0 ]; then
  echo "✗ no tests matched filter: $PSK_TEST_FILTER" >&2
  exit 2
fi

# Final aggregated summary
echo ""
echo "═══════════════════════════════════════════"
echo "  RESULTS: $PASS passed, $FAIL failed, $TOTAL total"
echo "═══════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo "  ✅ ALL TESTS PASSED"
  # KIT-GAP-0123: record a REAL exit-0 stamp for the unit this process actually ran, so a
  # chunked-drive of the suite can pre-verify the release test phase (psk-tests-gate.sh seal).
  # The proof is THIS process's true exit 0 — never an agent narrative. A --filter run is a
  # report-narrowed subset, so it does NOT stamp (fail-closed). Stamp is best-effort: it
  # never changes this script's exit code.
  _tg="$PROJ/agent/scripts/psk-tests-gate.sh"
  if [ -x "$_tg" ] && [ -z "${PSK_TEST_FILTER:-}" ]; then
    if [ "${_FEATURES_ONLY:-0}" = "1" ] && [ "${#_SECT_SEL[@]}" -eq 0 ] && [ "${#_FEAT_SEL[@]}" -eq 0 ]; then
      bash "$_tg" stamp features 2>/dev/null || true
    elif [ "${#_SECT_SEL[@]}" -eq 1 ] && [ "${_FEATURES_ONLY:-0}" != "1" ] && [ "${#_FEAT_SEL[@]}" -eq 0 ]; then
      bash "$_tg" stamp "section-${_SECT_SEL[0]}" 2>/dev/null || true
    elif [ "${#_SECT_SEL[@]}" -eq 0 ] && [ "${#_FEAT_SEL[@]}" -eq 0 ] && [ "${_FEATURES_ONLY:-0}" != "1" ]; then
      bash "$_tg" stamp full 2>/dev/null || true
    fi
  fi
  exit 0
else
  echo "  ❌ $FAIL TESTS FAILED"
  exit 1
fi
