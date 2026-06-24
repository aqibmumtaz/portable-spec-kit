#!/usr/bin/env bash
# mechanical-script: psk-tests-gate.sh — pre-verify gate for the release test phase
# ─────────────────────────────────────────────────────────────────────────────
# WHY THIS EXISTS (KIT-GAP-0123 — structural in-chat progress for reflex/prepare):
#   The release ceremony's step-1-tests ran the full Test Execution Flow as ONE
#   opaque op (~25min). The chat is turn-based, so a single background op surfaces NO
#   per-section progress in the chat — the operator stares at silence. The fix DECOUPLES
#   the long suite from the opaque step-1: the agent drives the suite CHUNKED first
#   (`psk-chunked-run.sh --suite all-tests` → one message per section), which seals a
#   pre-verify marker; then `psk-release.sh prepare`'s step-1 routes through THIS gate,
#   sees the marker, and SKIPS the inline re-run (no double-run — cf. KIT-GAP-0121).
#
# SAFETY MODEL (fail-CLOSED — a test-skip gate must NEVER skip real/broken tests):
#   The skip is bound to PROOF, not trust. Two layers:
#     (1) PROOF = real exit-0 STAMPS. Only a test process that ACTUALLY exited 0 writes
#         its unit's stamp (sections + features + benchmarking + release-check). The
#         agent's free-text chunk "result" is cosmetic — it never seals anything. A
#         failing suite, a benignly-summarised failure, or zero recorded results all
#         leave a unit unstamped → seal refuses → tests run.
#     (2) TREE FINGERPRINT = HEAD + the FULL working tree (tracked diff + untracked
#         list), hashed. Every stamp and the marker record the fingerprint they were
#         made at. ANY change — a new commit, a staged/unstaged edit, an uncommitted
#         dirty tree at the same HEAD, a branch switch with different content — changes
#         the fingerprint, so stamps/marker no longer match and the suite runs. There is
#         no time window and no SHA-only path that could fail open.
#   Non-git project, detached/unborn HEAD, or any git failure → empty fingerprint →
#   seal refuses + check refuses → tests ALWAYS run (fail-closed). The marker + stamps
#   are gitignored so they never alter the fingerprint and never travel across clones.
#
# SUBCOMMANDS:
#   run             step-1-tests command — skip iff a marker proves the current tree, else run flow
#   check           exit 0 iff the marker's fingerprint == the current tree fingerprint, else 1
#   seal --suite N  write the marker IFF real exit-0 stamps cover every unit of suite N at the
#                   current fingerprint (N = test-spec-kit | all-tests). Refuses otherwise.
#   stamp <unit>    record a real exit-0 for <unit> at the current fingerprint (called by suites)
#   clear           remove the marker + all stamps
#   fingerprint     print the current tree fingerprint (debug)
#   path            print the marker path
#
# STRUCTURAL no-inline-fallback (KIT-GAP-0140):
#   When `run` finds NO pre-verify proof AND it is running in an agent-driven (non-
#   interactive) context, it does NOT run the suite inline (an opaque block surfaces zero
#   per-section progress in the turn-based chat). It refuses with exit 7 and prints the
#   chunk-drive recipe, forcing the agent down the chunked path (one in-chat message per
#   section). CI, a real TTY, and PSK_TESTS_GATE_ALLOW_INLINE=1 still run inline.
#
# ENV:
#   PSK_TESTS_GATE_DISABLED=1     `run` always executes the full flow inline (never skips)
#   PSK_TESTS_GATE_ALLOW_INLINE=1 `run` may execute inline even in an agent context (no chunk guard)
#   PSK_NONINTERACTIVE=1          force the agent-driven branch (refuse inline) regardless of TTY
# ─────────────────────────────────────────────────────────────────────────────
set -u

_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
PROJ_ROOT="${PSK_TESTS_GATE_PROJ_ROOT:-$(cd "$_SELF/../.." 2>/dev/null && pwd)}"
# STATE_DIR holds the marker + stamps. Override via PSK_TESTS_GATE_STATE_DIR so a test
# can isolate its gate state from the PRODUCTION agent/.release-state — critical because
# the kit's own section-109 tests exercise clear/stamp/seal, and the test suite runs as a
# chunk DURING a live chunked-drive; without isolation those tests would wipe the drive's
# real section stamps (the seal would then refuse — KIT-GAP-0124). PROJ_ROOT stays the real
# repo so the git tree fingerprint is still meaningful.
STATE_DIR="${PSK_TESTS_GATE_STATE_DIR:-$PROJ_ROOT/agent/.release-state}"
MARKER="$STATE_DIR/.tests-preverified"
STAMP_DIR="$STATE_DIR/.tests-stamps"

# Tree fingerprint — HEAD + the working tree (tracked diff + untracked list), hashed,
# EXCLUDING kit runtime-state paths. Empty on any git failure / non-git project (→
# fail-closed everywhere). Marker + stamps are gitignored so writing them never perturbs
# this fingerprint.
#
# WHY THE EXCLUDES: the fingerprint must change on a CODE/TEST edit (the safety property)
# but NOT on kit runtime churn. `psk-release.sh prepare` writes tracked state files
# (agent/.workflow-state/*, agent/.release-state/*) as it initialises — BEFORE step-1-tests
# runs. Without these excludes the fingerprint would differ between the chunked-suite seal
# and step-1's check, so the skip would never fire under reflex (the actual use case). The
# excluded paths are kit-created in EVERY project that installs the kit, so the exclude set
# is generic, not project-specific. A real source/test edit lives outside these paths and
# still flips the fingerprint → tests run.
_FP_EXCLUDES=(
  ":(exclude)agent/.workflow-state"
  ":(exclude)agent/.release-state"
  ":(exclude).portable-spec-kit/optimize-state.yml"
  ":(exclude)reflex/history"
  ":(exclude)reflex/sandbox"
  ":(exclude).session-stack.md"
  ":(exclude).session-archive"
)
_fingerprint() {
  git -C "$PROJ_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { printf ''; return; }
  local fp
  fp=$({ git -C "$PROJ_ROOT" rev-parse HEAD 2>/dev/null
         git -C "$PROJ_ROOT" status --porcelain=v1 --untracked-files=all -- . "${_FP_EXCLUDES[@]}" 2>/dev/null
         git -C "$PROJ_ROOT" diff HEAD -- . "${_FP_EXCLUDES[@]}" 2>/dev/null
       } | git -C "$PROJ_ROOT" hash-object --stdin 2>/dev/null)
  # A repo with an unborn HEAD (no commits) still yields a stable hash of empty-ish input;
  # only print when we actually got a 40-hex object id, else fail-closed (empty).
  case "$fp" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) printf '%s' "$fp" ;;
    *) printf '' ;;
  esac
}

# The full Test Execution Flow (mirrors release/phases.yml step-1-tests, pre-0123).
# Each suite self-stamps on its own exit 0, so a clean inline run also pre-verifies.
_run_full_flow() {
  cd "$PROJ_ROOT" || return 2
  bash tests/test-spec-kit.sh \
    && bash tests/test-spd-benchmarking.sh \
    && bash tests/test-release-check.sh agent/SPECS.md
}

# Sections the chunked plan enumerates — leading-number of each tests/sections/*.sh,
# the SAME scheme psk-chunked-run.sh::_tsk_chunks uses for `--section <NN>`.
_section_units() {
  cd "$PROJ_ROOT" 2>/dev/null || return 1
  PSK_PROGRESS_DISABLED=1 bash tests/test-spec-kit.sh --list-sections 2>/dev/null \
    | awk '/^Sections/{s=1;next} /^Features/{s=0} s&&/^  [0-9]/{gsub(/^  /,"");print}' \
    | while IFS= read -r _f; do [ -n "$_f" ] || continue; printf 'section-%s\n' "${_f%%-*}"; done
}

# True iff <unit>'s stamp exists AND records the given fingerprint.
_stamp_ok() {
  local unit="$1" fp="$2" sf="$STAMP_DIR/$1"
  [ -f "$sf" ] || return 1
  [ "$(grep -m1 '^fp=' "$sf" 2>/dev/null | cut -d= -f2-)" = "$fp" ]
}

# All units required for a suite. Echoes one unit per line. test-spec-kit is covered by a
# single `full` stamp OR (every section + features); all-tests adds benchmarking + release-check.
_missing_units() {
  local suite="$1" fp="$2" miss="" u
  local tsk_ok=0
  if _stamp_ok full "$fp"; then
    tsk_ok=1
  else
    tsk_ok=1
    while IFS= read -r u; do [ -n "$u" ] || continue; _stamp_ok "$u" "$fp" || { tsk_ok=0; miss="$miss $u"; }; done < <(_section_units)
    _stamp_ok features "$fp" || { tsk_ok=0; miss="$miss features"; }
  fi
  case "$suite" in
    all-tests|tests|test-execution-flow)
      _stamp_ok benchmarking "$fp"  || miss="$miss benchmarking"
      _stamp_ok release-check "$fp" || miss="$miss release-check" ;;
  esac
  printf '%s' "$miss"
}

cmd_fingerprint() { _fingerprint; echo; }

cmd_stamp() {
  local unit="$1"; [ -n "$unit" ] || { echo "psk-tests-gate: stamp needs <unit>" >&2; return 2; }
  local fp; fp=$(_fingerprint)
  [ -n "$fp" ] || return 0   # non-git → no stamp (seal will fail-closed). Never error a suite.
  mkdir -p "$STAMP_DIR" 2>/dev/null || true
  printf 'fp=%s\nts=%s\n' "$fp" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" \
    > "$STAMP_DIR/$unit.tmp" 2>/dev/null && mv "$STAMP_DIR/$unit.tmp" "$STAMP_DIR/$unit" 2>/dev/null || true
}

cmd_check() {
  [ -f "$MARKER" ] || return 1
  local fp mfp
  fp=$(_fingerprint); [ -n "$fp" ] || return 1            # non-git / git failure → fail-closed
  mfp=$(grep -m1 '^fp=' "$MARKER" 2>/dev/null | cut -d= -f2-)
  [ -n "$mfp" ] && [ "$mfp" = "$fp" ]                     # marker must prove THIS exact tree
}

cmd_seal() {
  local suite="${1:-test-spec-kit}" fp miss
  fp=$(_fingerprint)
  if [ -z "$fp" ]; then
    echo "psk-tests-gate: refusing to seal — not a git work tree (fail-closed)" >&2; return 1
  fi
  miss=$(_missing_units "$suite" "$fp")
  if [ -n "$miss" ]; then
    echo "psk-tests-gate: refusing to seal $suite — units without a real exit-0 stamp at the current tree:$miss" >&2
    return 1
  fi
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  {
    echo "# tests pre-verified — real exit-0 stamps cover every $suite unit at this exact tree (KIT-GAP-0123)"
    echo "fp=$fp"
    echo "suite=$suite"
    echo "ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
  } > "$MARKER.tmp" && mv "$MARKER.tmp" "$MARKER"
  echo "✓ sealed tests pre-verify marker ($suite) for tree $fp"
}

# Agent-driven (non-interactive) context where the CHUNKED drive is the REQUIRED progress
# surface (KIT-GAP-0140). Running the full suite inline here surfaces ZERO per-section
# progress in the chat — the chat is turn-based, so one opaque background block = no
# messages (KIT-GAP-0112/0113). True iff: NOT an explicit allow-inline opt-in, NOT CI,
# and either an explicit headless signal OR stdout is not a TTY (the shape of an agent
# subprocess). A real terminal (human) and CI both run inline as before — backward compat.
_agent_driven_context() {
  [ "${PSK_TESTS_GATE_ALLOW_INLINE:-0}" = "1" ] && return 1   # explicit inline opt-in — wins over all
  [ "${PSK_NONINTERACTIVE:-0}" = "1" ] && return 0            # explicit force-agent — wins over CI/TTY
  [ -n "${CI:-}" ] && return 1                                # CI runner — no agent to chunk
  [ -t 1 ] && return 1                                        # real terminal → human → inline
  return 0                                                    # no TTY, not CI → agent-driven
}

cmd_run() {
  if [ "${PSK_TESTS_GATE_DISABLED:-0}" = "1" ]; then
    echo "psk-tests-gate: PSK_TESTS_GATE_DISABLED=1 — running full flow inline" >&2
    _run_full_flow; return $?
  fi
  if cmd_check; then
    echo "✓ step-1-tests: pre-verified — real exit-0 stamps cover this exact tree, skipping inline re-run"
    echo "  (the suite already ran per-section with in-chat progress; cf. KIT-GAP-0123)"
    return 0
  fi
  # No pre-verify proof for the current tree. STRUCTURAL no-inline-fallback (KIT-GAP-0140):
  # in an agent-driven context the suite MUST be driven CHUNKED (one in-chat message per
  # section) — running it as one opaque block surfaces no chat progress. Refuse + emit the
  # chunk-drive recipe (exit 7 = AWAITING_CHUNKED_TESTS) instead of running inline. CI, a
  # real TTY, and the explicit allow-inline opt-in still run inline (backward compatible).
  if _agent_driven_context; then
    cat >&2 <<'EOF'
✗ step-1-tests: no pre-verify proof for the current tree, in an agent-driven (non-interactive)
  context. Running the full suite inline here surfaces NO per-section progress in the chat
  (the chat is turn-based — KIT-GAP-0112/0113). This is a STRUCTURAL guard, NOT a test failure.
  Drive the suite CHUNKED (one message per section), then re-run — step-1 will skip:

    bash agent/scripts/psk-chunked-run.sh plan --label reflex-tests --suite all-tests
    # per chunk: run `bash agent/scripts/psk-chunked-run.sh next --label reflex-tests` →
    #   run the printed command as a background task → relay
    #   `bash agent/scripts/psk-chunked-run.sh status --table --label reflex-tests` →
    #   `bash agent/scripts/psk-chunked-run.sh next --label reflex-tests --result "<result>"`
    # the test processes stamp real exit-0s; on DONE seal + re-run:
    bash agent/scripts/psk-tests-gate.sh seal --suite all-tests

  Bypass (genuine non-agent inline run): PSK_TESTS_GATE_ALLOW_INLINE=1  (or CI=1, or a TTY)
EOF
    return 7
  fi
  echo "step-1-tests: no proof for the current tree — running full Test Execution Flow inline"
  _run_full_flow
}

case "${1:-run}" in
  run)         cmd_run ;;
  check)       cmd_check ;;
  seal)        shift; case "${1:-}" in --suite) cmd_seal "${2:-}";; *) cmd_seal "${1:-test-spec-kit}";; esac ;;
  stamp)       shift; cmd_stamp "${1:-}" ;;
  clear)       rm -f "$MARKER"; rm -rf "$STAMP_DIR"; echo "✓ cleared marker + stamps" ;;
  fingerprint) cmd_fingerprint ;;
  path)        echo "$MARKER" ;;
  *) echo "usage: psk-tests-gate.sh {run|check|seal --suite <name>|stamp <unit>|clear|fingerprint|path}" >&2; exit 2 ;;
esac
