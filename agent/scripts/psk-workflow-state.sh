#!/bin/bash
# mechanical-script: psk-workflow-state.sh — phase-state machine (no AI invocation)
# psk-workflow-state.sh — Shared resumable phase-state machine for every executable kit workflow
#
# Implements §Workflow Fidelity (portable-spec-kit.md): every executable workflow
# runs as a phase state machine. A phase cannot be marked done until its registered
# completion gate passes. On interruption (rate limit, context compact) the workflow
# pauses with state persisted; `resume` re-enters at the exact in-progress phase —
# never restarts, never skips.
#
# State file: agent/.workflow-state/<workflow>.state
#
# Usage:
#   psk-workflow-state.sh init <workflow> <phase1,phase2,...>   # create state machine
#   psk-workflow-state.sh get-phase <workflow>                  # print current actionable phase
#   psk-workflow-state.sh mark-in-progress <workflow> <phase>   # mark phase RUNNING
#   psk-workflow-state.sh mark-done <workflow> <phase>          # mark phase DONE (refuses without GATE_PASSED)
#   psk-workflow-state.sh mark-awaiting <workflow> <phase> <reason>  # pause: AWAITING:<reason>
#   psk-workflow-state.sh register-gate <workflow> <phase> <cmd>     # register completion gate
#   psk-workflow-state.sh verify-gate <workflow> <phase>        # execute gate; on exit 0 writes GATE_PASSED_<phase>
#   psk-workflow-state.sh resume <workflow>                     # print exact resume instruction
#   psk-workflow-state.sh status <workflow>                     # print full phase table
#   psk-workflow-state.sh complete? <workflow>                  # exit 0 if all phases done
#   psk-workflow-state.sh list-paused                           # list ALL phases in AWAITING:* status across all workflows
#   psk-workflow-state.sh abandon <workflow> <phase>            # mark a single paused phase ABANDONED (operator action)
#   psk-workflow-state.sh abandon-stale [--dry-run] [N|--days N]  # auto-abandon AWAITING:* phases whose state file is stale >N days (default 7)
#
# Phase-gate contract (§Workflow Fidelity — B2 v0.6.57):
#   1. Workflow registers gates via `register-gate` at init time.
#   2. Before marking a phase done, the caller MUST run `verify-gate`.
#   3. `verify-gate` runs the registered command; on exit 0 it writes
#      GATE_PASSED_<phase>=<unix-ts> into the state file.
#   4. `mark-done` refuses (exit 2) when a gate is registered but no
#      GATE_PASSED_<phase> marker exists. No registered gate → mark-done
#      is permitted (legacy / no-completion-check phases).
#
# Bypass: PSK_WORKFLOW_STATE_DISABLED=1 — emergency only, removes a structural guarantee.
#
# Exit codes: 0 ok · 1 gate failed / phase not found · 2 usage error / gate unverified

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STATE_DIR="$PROJ_ROOT/agent/.workflow-state"

_state_file() { echo "$STATE_DIR/$1.state"; }
_gate_file()  { echo "$STATE_DIR/$1.gates"; }

if [ "${PSK_WORKFLOW_STATE_DISABLED:-0}" = "1" ]; then
  # HF9 (v0.6.60): durable bypass-tamper audit trail.
  _bypass_log_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/psk-bypass-log.sh"
  if [ -x "$_bypass_log_script" ]; then
    bash "$_bypass_log_script" log \
      --env-var "PSK_WORKFLOW_STATE_DISABLED" \
      --command "psk-workflow-state.sh $*" \
      --justification "${PSK_BYPASS_REASON:-not provided}" 2>/dev/null || true
  fi
  # Emergency bypass — every command is a silent no-op success.
  case "${1:-}" in
    get-phase) echo "(state-disabled)" ;;
    "complete?") exit 0 ;;
    list-paused) : ;;   # silent — no paused phases when disabled
    *) : ;;
  esac
  exit 0
fi

cmd_init() {
  local wf="$1" phases="$2"
  [ -z "$wf" ] || [ -z "$phases" ] && { echo "usage: init <workflow> <phases-csv>" >&2; exit 2; }
  mkdir -p "$STATE_DIR"
  local sf; sf=$(_state_file "$wf")
  {
    echo "WORKFLOW=$wf"
    echo "RUN_ID=$(date +%s)"
    echo "STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local IFS=','
    for p in $phases; do
      echo "PHASE_${p}=pending"
    done
  } > "$sf"
  echo "initialized: $sf"
}

cmd_get_phase() {
  local wf="$1"; local sf; sf=$(_state_file "$wf")
  [ ! -f "$sf" ] && { echo "(no state — run init)"; exit 1; }
  # First non-done phase, in file order. AWAITING/in_progress reported as-is.
  local phase status
  while IFS='=' read -r key val; do
    case "$key" in
      PHASE_*)
        phase="${key#PHASE_}"; status="$val"
        case "$status" in
          done) continue ;;
          *) echo "$phase ($status)"; return 0 ;;
        esac
        ;;
    esac
  done < "$sf"
  echo "(all phases done)"
}

cmd_mark_in_progress() {
  local wf="$1" phase="$2"; local sf; sf=$(_state_file "$wf")
  [ ! -f "$sf" ] && { echo "no state for $wf" >&2; exit 1; }
  _set_phase "$sf" "$phase" "in_progress"
  echo "phase $phase → in_progress"
}

cmd_mark_awaiting() {
  local wf="$1" phase="$2" reason="${3:-unspecified}"; local sf; sf=$(_state_file "$wf")
  [ ! -f "$sf" ] && { echo "no state for $wf" >&2; exit 1; }
  _set_phase "$sf" "$phase" "AWAITING:$reason"
  echo "phase $phase → AWAITING ($reason) — workflow paused; run: psk-workflow-state.sh resume $wf"
}

cmd_register_gate() {
  local wf="$1" phase="$2"; shift 2; local gate_cmd="$*"
  mkdir -p "$STATE_DIR"
  local gf; gf=$(_gate_file "$wf")
  # Remove any existing gate for this phase, then append
  if [ -f "$gf" ]; then grep -v "^${phase}=" "$gf" > "$gf.tmp" 2>/dev/null || true; mv "$gf.tmp" "$gf"; fi
  echo "${phase}=${gate_cmd}" >> "$gf"
  echo "gate registered: $wf/$phase → $gate_cmd"
}

cmd_verify_gate() {
  local wf="$1" phase="$2"; local sf; sf=$(_state_file "$wf")
  [ ! -f "$sf" ] && { echo "no state for $wf" >&2; exit 1; }
  local gf; gf=$(_gate_file "$wf")
  if [ ! -f "$gf" ]; then
    echo "no gate registry for $wf — nothing to verify" >&2
    exit 1
  fi
  local gate_cmd
  gate_cmd=$(grep "^${phase}=" "$gf" | head -1 | cut -d= -f2-)
  if [ -z "$gate_cmd" ]; then
    echo "no gate registered for phase $phase in $wf — nothing to verify" >&2
    exit 1
  fi
  echo "running completion gate for $phase: $gate_cmd"
  # KIT-GAP-0005 fix (v0.6.66): two-stage quoting for paths with spaces.
  #
  # Stage A — pre-expanded path defensive re-substitution. Some callers
  # (notably reflex/run.sh) register gates with $PASS_DIR already shell-
  # expanded BEFORE register-gate is invoked. The stored gate string thus
  # contains literal absolute paths instead of $VAR refs. If the path has
  # spaces (e.g. "/Users/Jane Doe/..."), eval word-splits on those spaces
  # and the gate fails with "binary operator expected". Detect literal
  # path prefixes that match known env vars + replace them back with $VAR
  # syntax so Stage B can re-quote them defensively.
  local _gv _gq _val
  for _gv in REFLEX_PROJ_ROOT REFLEX_PASS_DIR PROJ_ROOT PASS_DIR; do
    _val="${!_gv:-}"
    [ -n "$_val" ] || continue
    gate_cmd="${gate_cmd//$_val/\$$_gv}"
  done
  # Stage B — quote $VAR substitutions via printf %q so eval doesn't
  # word-split on spaces inside the expanded path.
  for _gv in REFLEX_PROJ_ROOT REFLEX_PASS_DIR PROJ_ROOT PASS_DIR; do
    [ -n "${!_gv:-}" ] || continue
    _gq=$(printf '%q' "${!_gv}")
    gate_cmd="${gate_cmd//\$$_gv/$_gq}"
  done
  # eval-allowlist: phase completion gate from phase registry (kit-controlled, path-quoted via printf %q above)
  if ! ( cd "$PROJ_ROOT" && eval "$gate_cmd" ); then
    echo "✗ completion gate FAILED for phase $phase" >&2
    echo "  fix the gate failure, then re-run verify-gate" >&2
    exit 1
  fi
  # Write GATE_PASSED marker into state file. Replace any prior marker for
  # the same phase so re-verification refreshes the timestamp.
  local ts; ts=$(date +%s)
  local tmp; tmp=$(mktemp)
  grep -v "^GATE_PASSED_${phase}=" "$sf" > "$tmp" 2>/dev/null || true
  echo "GATE_PASSED_${phase}=${ts}" >> "$tmp"
  mv "$tmp" "$sf"
  echo "✓ gate passed — GATE_PASSED_${phase}=${ts}"
}

cmd_mark_done() {
  local wf="$1" phase="$2"; local sf; sf=$(_state_file "$wf")
  [ ! -f "$sf" ] && { echo "no state for $wf" >&2; exit 1; }
  # Refuse to mark done if a gate is registered but verify-gate has not
  # written the GATE_PASSED marker. This is the structural enforcement of
  # §Workflow Fidelity B2 — phases physically cannot advance without
  # a registered gate having been independently verified.
  local gf; gf=$(_gate_file "$wf")
  if [ -f "$gf" ]; then
    local gate_cmd
    gate_cmd=$(grep "^${phase}=" "$gf" | head -1 | cut -d= -f2-)
    if [ -n "$gate_cmd" ]; then
      if ! grep -q "^GATE_PASSED_${phase}=" "$sf"; then
        echo "phase $phase has registered gate ${gate_cmd} but no GATE_PASSED marker — run \`verify-gate $wf $phase\` first" >&2
        exit 2
      fi
    fi
  fi
  _set_phase "$sf" "$phase" "done"
  echo "phase $phase → done"
}

cmd_resume() {
  local wf="$1"; local sf; sf=$(_state_file "$wf")
  [ ! -f "$sf" ] && { echo "no state for $wf — nothing to resume" >&2; exit 1; }
  local cur; cur=$(cmd_get_phase "$wf")
  case "$cur" in
    "(all phases done)")
      echo "workflow $wf complete — nothing to resume"
      ;;
    *AWAITING:*)
      local reason="${cur#*AWAITING:}"; reason="${reason%)}"
      echo "RESUME $wf at phase: ${cur%% *}"
      echo "  paused reason: $reason"
      if [[ "$reason" == SUBAGENT_RETRY* ]]; then
        echo "  → retry the sub-agent spawn for this phase (psk-spawn.sh). NO inline fallback."
      else
        echo "  → re-enter this phase and complete it to its gate."
      fi
      ;;
    *)
      echo "RESUME $wf at phase: ${cur%% *}  (status: ${cur#* })"
      echo "  → continue this phase to its completion gate, then mark-done."
      ;;
  esac
}

cmd_status() {
  local wf="$1"; local sf; sf=$(_state_file "$wf")
  [ ! -f "$sf" ] && { echo "no state for $wf" >&2; exit 1; }
  echo "── workflow: $wf ──"
  grep -E '^(WORKFLOW|RUN_ID|STARTED)=' "$sf"
  echo "── phases ──"
  while IFS='=' read -r key val; do
    case "$key" in
      PHASE_*)
        local mark="·"
        case "$val" in
          done) mark="✓" ;;
          in_progress) mark="→" ;;
          AWAITING:*) mark="⏸" ;;
        esac
        printf '  %s %-28s %s\n' "$mark" "${key#PHASE_}" "$val"
        ;;
    esac
  done < "$sf"
}

cmd_complete() {
  local wf="$1"; local sf; sf=$(_state_file "$wf")
  [ ! -f "$sf" ] && exit 1
  if grep -qE '^PHASE_[^=]+=(pending|in_progress|AWAITING:)' "$sf"; then
    exit 1
  fi
  exit 0
}

# list-paused — scan every <workflow>.state file in STATE_DIR for phases
# whose status starts with "AWAITING". Emit one line per match:
#   <workflow>  <phase>  <status>
# Empty output when no paused phases exist (resume-bootstrap interprets
# zero lines as "clean"). Honored even when STATE_DIR is missing.
cmd_list_paused() {
  [ -d "$STATE_DIR" ] || { exit 0; }
  local f wf phase status
  for f in "$STATE_DIR"/*.state; do
    [ -f "$f" ] || continue
    wf=$(basename "$f" .state)
    while IFS='=' read -r key val; do
      case "$key" in
        PHASE_*)
          phase="${key#PHASE_}"; status="$val"
          case "$status" in
            AWAITING:*|AWAITING_SUBAGENT_RETRY:*)
              printf '%s\t%s\t%s\n' "$wf" "$phase" "$status"
              ;;
          esac
          ;;
      esac
    done < "$f"
  done
  exit 0
}

_set_phase() {
  local sf="$1" phase="$2" status="$3"
  local tmp; tmp=$(mktemp)
  local found=0
  while IFS= read -r line; do
    if [[ "$line" == "PHASE_${phase}="* ]]; then
      echo "PHASE_${phase}=${status}"
      found=1
    else
      echo "$line"
    fi
  done < "$sf" > "$tmp"
  if [ "$found" -eq 0 ]; then
    echo "phase '$phase' not found in state machine" >&2
    rm -f "$tmp"
    exit 1
  fi
  mv "$tmp" "$sf"
}

cmd_abandon() {
  # QA-D13 fix: explicit operator action to mark a paused phase ABANDONED.
  # ABANDONED phases stop appearing in list-paused so resume-bootstrap +
  # watchdog don't keep re-surfacing forgotten work.
  local workflow="$1"
  local phase="$2"
  if [[ -z "$workflow" || -z "$phase" ]]; then
    echo "usage: abandon <workflow> <phase>" >&2
    exit 2
  fi
  local sf="$STATE_DIR/${workflow}.state"
  if [[ ! -f "$sf" ]]; then
    echo "no state file for workflow '$workflow'" >&2
    exit 1
  fi
  _set_phase "$sf" "$phase" "ABANDONED"
  echo "abandoned: $workflow / $phase"
}

cmd_abandon_stale() {
  # QA-D13 auto-abandon policy: any phase in AWAITING:* status whose owning
  # state file hasn't been touched in N days gets auto-marked ABANDONED.
  # Default N = 7 days. Reads workflow_state_stale_days from reflex/config.yml
  # if available. Use `--dry-run` to preview without writing.
  local days=7
  local dry_run=0
  if [[ -f "$PROJ_ROOT/reflex/config.yml" ]]; then
    local cfg
    cfg=$(grep -E "^workflow_state_stale_days:" "$PROJ_ROOT/reflex/config.yml" 2>/dev/null | awk '{print $2}' | tr -d ' "')
    [[ -n "$cfg" && "$cfg" =~ ^[0-9]+$ ]] && days="$cfg"
  fi
  while [[ "${1:-}" == "--"* ]]; do
    case "$1" in
      --dry-run) dry_run=1; shift ;;
      --days) days="$2"; shift 2 ;;
      *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
  done
  [[ "${1:-}" =~ ^[0-9]+$ ]] && days="$1"

  [[ -d "$STATE_DIR" ]] || { echo "abandon-stale: no state dir (0 abandoned)"; exit 0; }

  local threshold_sec=$(( days * 86400 ))
  local now_sec; now_sec=$(date +%s)
  local abandoned=0
  local f wf started_str started_sec mtime age
  for f in "$STATE_DIR"/*.state; do
    [[ -f "$f" ]] || continue
    wf=$(basename "$f" .state)
    # Prefer the STARTED= field — measures actual workflow start, not mtime
    # which gate-passed updates churn. Fall back to mtime if STARTED missing.
    started_str=$(grep '^STARTED=' "$f" 2>/dev/null | head -1 | cut -d= -f2)
    if [[ -n "$started_str" ]]; then
      started_sec=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$started_str" +%s 2>/dev/null || echo 0)
    else
      started_sec=0
    fi
    if [[ "$started_sec" -eq 0 ]]; then
      mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
      age=$(( now_sec - mtime ))
    else
      age=$(( now_sec - started_sec ))
    fi
    [[ "$age" -lt "$threshold_sec" ]] && continue

    # Iterate over paused phases in this file
    while IFS='=' read -r key val; do
      case "$key" in
        PHASE_*)
          phase="${key#PHASE_}"
          case "$val" in
            AWAITING:*|AWAITING_SUBAGENT_RETRY:*)
              if [[ "$dry_run" -eq 1 ]]; then
                echo "would abandon: $wf / $phase (age=$((age/86400))d)"
              else
                _set_phase "$f" "$phase" "ABANDONED"
                echo "abandoned: $wf / $phase (age=$((age/86400))d)"
              fi
              abandoned=$(( abandoned + 1 ))
              ;;
          esac
          ;;
      esac
    done < "$f"
  done
  if [[ "$dry_run" -eq 1 ]]; then
    echo "abandon-stale: $abandoned phase(s) would be abandoned (threshold ${days}d)"
  else
    echo "abandon-stale: $abandoned phase(s) abandoned (threshold ${days}d)"
  fi
}

cmd_prune() {
  # QA-D13-03: prune old reflex-pass-cycle-* state files.
  # Keeps the N most-recent cycles (default 3). Reads workflow_state_keep
  # from reflex/config.yml if available; otherwise defaults to 3.
  local keep=3
  if [[ -f "$PROJ_ROOT/reflex/config.yml" ]]; then
    local cfg_keep
    cfg_keep=$(grep -E "^workflow_state_keep:" "$PROJ_ROOT/reflex/config.yml" 2>/dev/null | awk '{print $2}' | tr -d ' "')
    [[ -n "$cfg_keep" && "$cfg_keep" =~ ^[0-9]+$ ]] && keep="$cfg_keep"
  fi
  [[ "${1:-}" =~ ^[0-9]+$ ]] && keep="$1"

  local pruned=0
  # Group: reflex-pass-cycle-NN-pass-MMM.{state,gates}
  # Extract unique cycle numbers, sort desc, drop top keep
  local cycles
  cycles=$(ls "$STATE_DIR"/reflex-pass-cycle-*.state 2>/dev/null \
    | sed -E 's|.*/reflex-pass-cycle-([0-9]+)-pass-[0-9]+\.state|\1|' \
    | sort -un)
  if [[ -n "$cycles" ]]; then
    local cycles_desc
    cycles_desc=$(echo "$cycles" | sort -rn)
    local skip="$keep"
    local cycle_num
    while IFS= read -r cycle_num; do
      [[ -z "$cycle_num" ]] && continue
      if (( skip > 0 )); then
        skip=$((skip - 1))
        continue
      fi
      # Remove all files for this cycle
      local f
      for f in "$STATE_DIR"/reflex-pass-cycle-"$cycle_num"-pass-*.state "$STATE_DIR"/reflex-pass-cycle-"$cycle_num"-pass-*.gates; do
        if [[ -f "$f" ]]; then
          rm -f "$f"
          pruned=$((pruned + 1))
        fi
      done
    done <<< "$cycles_desc"
  fi

  echo "prune: removed $pruned reflex-pass-cycle-* state files (kept latest $keep cycles)"
}

case "${1:-}" in
  init)             shift; cmd_init "$@" ;;
  get-phase)        shift; cmd_get_phase "$@" ;;
  mark-in-progress) shift; cmd_mark_in_progress "$@" ;;
  mark-done)        shift; cmd_mark_done "$@" ;;
  mark-awaiting)    shift; cmd_mark_awaiting "$@" ;;
  register-gate)    shift; cmd_register_gate "$@" ;;
  verify-gate)      shift; cmd_verify_gate "$@" ;;
  resume)           shift; cmd_resume "$@" ;;
  status)           shift; cmd_status "$@" ;;
  "complete?")      shift; cmd_complete "$@" ;;
  list-paused)      shift; cmd_list_paused "$@" ;;
  abandon)          shift; cmd_abandon "$@" ;;
  abandon-stale)    shift; cmd_abandon_stale "$@" ;;
  prune)            shift; cmd_prune "$@" ;;
  -h|--help|"")     sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)                echo "unknown subcommand: $1" >&2; exit 2 ;;
esac
