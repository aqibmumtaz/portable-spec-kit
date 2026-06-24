#!/bin/bash
# mechanical-script: psk-spawn.sh — §Spawn Fidelity central router
# psk-spawn.sh — Sub-agent spawn-fidelity protocol (§Workflow Fidelity, portable-spec-kit.md)
#
# Every executable workflow that needs a sub-agent goes through this wrapper.
# It does ONE thing: prepare a spawn request and record its lifecycle in the
# workflow state machine. It has NO inline-fallback branch — there is structurally
# no path where the agent does the sub-agent's work itself as a shortcut.
#
# Why no inline fallback: searchsocialtruth-v5 shipped a skeletal UI because, when
# a sub-agent rate-limited, the agent improvised the phase inline. A rule against
# that can be bypassed under pressure; removing the branch cannot.
#
# Lifecycle:
#   request  — workflow asks for a sub-agent → writes spawn-request.md, marks phase
#              AWAITING_SUBAGENT in the state machine, exits. The MAIN agent then
#              spawns the sub-agent via the Task tool with that exact prompt.
#   complete — main agent reports the sub-agent finished → verifies the result
#              artifact exists, clears AWAITING, returns control to the workflow.
#   retry    — sub-agent rate-limited / failed → stays AWAITING_SUBAGENT_RETRY,
#              prints the resume instruction. The ONLY forward path is another
#              spawn. There is no "do it inline" option.
#
# Usage:
#   psk-spawn.sh request        <workflow> <phase> <prompt-file> <result-artifact>
#   psk-spawn.sh request-multi  <workflow> <phase> <manifest-yaml>
#   psk-spawn.sh complete       <workflow> <phase> <result-artifact>
#   psk-spawn.sh complete-multi <workflow> <phase> <manifest-yaml>
#   psk-spawn.sh retry          <workflow> <phase>
#   psk-spawn.sh status         <workflow> <phase>
#
# request-multi: one phase, N parallel sub-agent spawns. Manifest YAML lists
# the N (id, prompt, artifact) tuples. Used by QA-Orchestrator wave dispatch
# (KIT-GAP-0052, v0.6.72) and by any workflow that fans out into N parallel
# units of work. Main session fan-out: one Task tool call per manifest entry,
# all in one response for parallelism.
#
# Manifest schema (YAML):
#   schema_version: 1
#   workflow: <name>
#   phase: <phase-name>
#   spawns:
#     - id: <unique-kebab>
#       prompt: <path>
#       artifact: <path>
#     - id: <unique-kebab>
#       prompt: <path>
#       artifact: <path>
#
# Bypass: PSK_SPAWN_FIDELITY_DISABLED=1 — emergency only. Even then, this script
# never does the work; it only stops blocking. The agent must still spawn.
# PSK_RETRY_FORCE=1 — bypass HF3 retry-queue backoff check for one retry.
#
# Exit codes: 0 ok · 1 missing artifact / not awaiting · 2 usage error · 4 prompt-lint refusal · 5 retry backoff not elapsed · 6 retry-queue durable-write failed (QA-D7-P8)

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STATE_SCRIPT="$PROJ_ROOT/agent/scripts/psk-workflow-state.sh"
RETRY_QUEUE_SCRIPT="$PROJ_ROOT/agent/scripts/psk-retry-queue.sh"
BYPASS_LOG_SCRIPT="$PROJ_ROOT/agent/scripts/psk-bypass-log.sh"
SPAWN_DIR="$PROJ_ROOT/agent/.workflow-state/spawn"

# QA-META-PHIL-03 (cycle-01 follow-up): concurrency safety for the shared
# spawn-directory state. When N parallel dim-agents (request-multi/complete-multi)
# and the retry-queue writer race on the same SPAWN_DIR, plain `>` writes can
# interleave — the symptom was orphaned *.qa-dims-redispatch.*.request files +
# inconsistent state. Two primitives close it WITHOUT changing the spawn protocol
# semantics or the no-inline-fallback contract:
#   1. _atomic_write — write to <file>.tmp.$$ then mv (POSIX rename is atomic),
#      so a reader never observes a half-written request file.
#   2. _spawn_lock / _spawn_unlock — mkdir-based mutex (same primitive as
#      psk-retry-queue.sh) serialising the multi-request batch's rm+write window,
#      with a portable timeout fallback. The retry-queue keeps its OWN lock, so
#      cross-script writes are each individually serialised on their own state.
# Bypass: PSK_SPAWN_LOCK_DISABLED=1 (genuine emergencies only).
SPAWN_LOCK_DIR="$SPAWN_DIR/.spawn-state.lock"

# Write stdin to a file atomically: stage to a unique tmp sibling, then rename.
# Rename within the same directory is atomic on POSIX filesystems, so concurrent
# readers/writers never see a partial file. Falls back to a direct write only if
# the tmp+mv cannot be staged (e.g. read-only parent — then there is no safe path
# anyway and the direct write surfaces the real error).
_atomic_write() {
  local dest="$1" tmp
  tmp="${dest}.tmp.$$.$RANDOM"
  if cat > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$dest" 2>/dev/null && return 0
    rm -f "$tmp" 2>/dev/null
  fi
  # Fallback: parent not writable for staging — direct write surfaces the error.
  cat > "$dest"
}

_spawn_lock() {
  [ "${PSK_SPAWN_LOCK_DISABLED:-0}" = "1" ] && return 0
  mkdir -p "$SPAWN_DIR" 2>/dev/null || true
  local tries=0
  while ! mkdir "$SPAWN_LOCK_DIR" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 100 ]; then
      # Stale-lock break: a crashed holder must not deadlock the queue forever.
      echo "psk-spawn: spawn-state lock held >10s — breaking presumed-stale lock $SPAWN_LOCK_DIR" >&2
      rmdir "$SPAWN_LOCK_DIR" 2>/dev/null || true
      mkdir "$SPAWN_LOCK_DIR" 2>/dev/null && break
      return 0   # never block the spawn protocol on lock acquisition
    fi
    sleep 0.1
  done
  return 0
}

_spawn_unlock() {
  [ "${PSK_SPAWN_LOCK_DISABLED:-0}" = "1" ] && return 0
  rmdir "$SPAWN_LOCK_DIR" 2>/dev/null || true
}

# HF9 (v0.6.60): shared helper — log a bypass invocation. Failure tolerant.
_log_bypass() {
  local env_var="$1" cmd_summary="$2"
  if [ -x "$BYPASS_LOG_SCRIPT" ]; then
    bash "$BYPASS_LOG_SCRIPT" log \
      --env-var "$env_var" \
      --command "$cmd_summary" \
      --justification "${PSK_BYPASS_REASON:-not provided}" 2>/dev/null || true
  fi
}

# HF3 integration: when a spawn fails, the failure is persisted to the
# retry queue (committed to git so it survives session ends). The in-state
# AWAITING_SUBAGENT_RETRY marker remains the fast-path check; the retry queue
# is the durable record + backoff source. Operator forces an early retry
# with PSK_RETRY_FORCE=1.

cmd_request() {
  # QA-D32-SPAWN-UNBOUND-VAR-01: ${N:-} so a missing positional yields the empty
  # string under `set -u` and the usage guard below fires with the helpful message,
  # instead of bash aborting with an opaque "$1: unbound variable" before the guard.
  local wf="${1:-}" phase="${2:-}" prompt_file="${3:-}" result_artifact="${4:-}"
  [ -z "$wf" ] || [ -z "$phase" ] || [ -z "$prompt_file" ] || [ -z "$result_artifact" ] && {
    echo "usage: psk-spawn.sh request <workflow> <phase> <prompt-file> <result-artifact>" >&2
    exit 2
  }
  [ ! -f "$prompt_file" ] && { echo "prompt file not found: $prompt_file" >&2; exit 1; }
  # HF4b idempotency outer safety net — phase-idempotency rule (portable-spec-kit.md).
  # If the gate has already passed for this phase, the phase is done; refuse
  # to re-spawn. Bypass: PSK_IDEMPOTENCY_DISABLED=1 (genuine emergencies only).
  if [ "${PSK_IDEMPOTENCY_DISABLED:-0}" != "1" ]; then
    local _state_file="$PROJ_ROOT/agent/.workflow-state/${wf}.state"
    if [ -f "$_state_file" ] && grep -q "^GATE_PASSED_${phase}=" "$_state_file" 2>/dev/null; then
      local _ts
      _ts=$(grep "^GATE_PASSED_${phase}=" "$_state_file" | head -1 | cut -d= -f2-)
      echo "Phase $phase already complete (gate passed at $_ts); refusing to re-spawn."
      echo "  Bypass with PSK_IDEMPOTENCY_DISABLED=1 to force re-spawn (rare)."
      exit 0
    fi
  else
    _log_bypass "PSK_IDEMPOTENCY_DISABLED" "psk-spawn.sh request $wf $phase"
  fi
  # KIT-GAP-0055 (v0.6.74): §Sub-Agent Prompt Fidelity prompt-validation gate.
  # Before any spawn, lint the prompt file. If it references kit rules but
  # lacks kit_rule_citations: frontmatter or verbatim rule text, REFUSE the
  # spawn. Same asymmetry as §Spawn Fidelity (no inline-fallback): the only
  # forward path is to fix the prompt. Recursive: applies regardless of spawn
  # depth (sub-agent spawning sub-sub-agent re-routes through this gate).
  # Bypass: PSK_PROMPT_FIDELITY_DISABLED=1 (genuine emergencies only).
  local lint_script="$PROJ_ROOT/agent/scripts/psk-prompt-lint.sh"
  if [ "${PSK_PROMPT_FIDELITY_DISABLED:-0}" != "1" ] && [ -x "$lint_script" ]; then
    local lint_out
    lint_out=$(bash "$lint_script" "$prompt_file" --strict 2>&1)
    local lint_rc=$?
    if [ "$lint_rc" -ne 0 ]; then
      echo "✗ SPAWN REFUSED — prompt fails §Sub-Agent Prompt Fidelity lint:" >&2
      echo "$lint_out" | sed 's/^/    /' >&2
      echo "" >&2
      echo "  Fix the prompt:" >&2
      echo "    - Add kit_rule_citations: frontmatter listing rule ids" >&2
      echo "    - Quote each cited rule's text verbatim (use: bash agent/scripts/psk-rule.sh lookup <id>)" >&2
      echo "    - Include the §Sub-Agent Prompt Fidelity preamble" >&2
      echo "  Bypass: PSK_PROMPT_FIDELITY_DISABLED=1 (emergencies only — logged to .bypass-log)" >&2
      exit 4
    fi
  elif [ "${PSK_PROMPT_FIDELITY_DISABLED:-0}" = "1" ]; then
    _log_bypass "PSK_PROMPT_FIDELITY_DISABLED" "psk-spawn.sh request $wf $phase"
  fi
  # Model-policy resolution (kit-wide cost/perf model selection). The model is
  # DATA in .portable-spec-kit/model-policy.yml, resolved here by phase→role→model,
  # injected into the request AND surfaced loudly in the protocol block below. It is
  # re-printed at EVERY spawn (coupled to the unskippable protocol) so model choice
  # is mechanical, not memory-driven — the fix for long-session attention decay.
  # PSK045 sync-check verifies this wiring stays intact.
  local model_policy="$PROJ_ROOT/agent/scripts/psk-model-policy.sh"
  local spawn_model="inherit"
  if [ -x "$model_policy" ]; then
    spawn_model=$(bash "$model_policy" lookup "$phase" "$wf" 2>/dev/null || echo inherit)
    [ -z "$spawn_model" ] && spawn_model="inherit"
  fi
  mkdir -p "$SPAWN_DIR"
  local req="$SPAWN_DIR/${wf}.${phase}.request"
  # QA-META-PHIL-03: atomic write — a concurrent reader (status/complete) never
  # observes a half-written request file.
  {
    echo "WORKFLOW=$wf"
    echo "PHASE=$phase"
    echo "PROMPT_FILE=$prompt_file"
    echo "RESULT_ARTIFACT=$result_artifact"
    echo "MODEL=$spawn_model"
    echo "REQUESTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } | _atomic_write "$req"
  bash "$STATE_SCRIPT" mark-awaiting "$wf" "$phase" "SUBAGENT_SPAWN" >/dev/null 2>&1 || true
  echo "⏸ AWAITING_SUBAGENT — workflow '$wf' paused at phase '$phase'"
  echo ""
  echo "  MAIN AGENT PROTOCOL (mandatory — no inline alternative exists):"
  echo "  1. Read the prompt: $prompt_file"
  if [ "$spawn_model" = "inherit" ]; then
    echo "  2. Spawn a Task-tool sub-agent with that exact prompt (MODEL: inherit — use current session model)"
  else
    echo "  2. Spawn a Task-tool sub-agent with that exact prompt — and set its MODEL:"
    echo "       ┌──────────────────────────────────────────────────────────────┐"
    echo "       │  MODEL = $spawn_model"
    echo "       │  Pass model=$spawn_model to the Task/Agent tool for this spawn."
    echo "       │  Kit model-policy (cost/perf). Do NOT default to the session"
    echo "       │  model for this spawn — the policy chose $spawn_model on purpose."
    echo "       └──────────────────────────────────────────────────────────────┘"
  fi
  echo "  3. Sub-agent writes its output to: $result_artifact"
  echo "  4. On success → psk-spawn.sh complete $wf $phase $result_artifact"
  echo "  5. On rate-limit / failure → psk-spawn.sh retry $wf $phase  (then spawn again)"
  echo ""
  echo "  There is NO step that does this phase's work inline. Spawn or retry-spawn only."
  # KIT-GAP-0133: structurally PRE-PLAN the reflex Dev progress tracker so the
  # status --table surface is ALWAYS set up by the kit — not dependent on the
  # driving agent remembering to plan it. The agent renders the table (chat is
  # agent-side), but the tracker is created here and the relay is mandated below.
  if printf '%s' "$wf" | grep -q '^reflex-pass-' && [ "$phase" = "dev" ]; then
    _ccr="$PROJ_ROOT/agent/scripts/psk-chunked-run.sh"
    if [ -x "$_ccr" ]; then
      ( cd "$PROJ_ROOT" && bash "$_ccr" plan --label reflex-dev --suite reflex-dev >/dev/null 2>&1 ) || true
      echo ""
      echo "  ── Progress surface (MANDATORY — structural, KIT-GAP-0133): the reflex-dev"
      echo "     per-finding tracker is PRE-PLANNED. Relay this VERBATIM each turn so the Dev"
      echo "     phase shows the canonical psk-chunked-run.sh status --table (the ONE template — same surface as the test suites):"
      echo "       bash agent/scripts/psk-chunked-run.sh status --table --label reflex-dev"
    fi
  fi
}

cmd_complete() {
  # QA-D32-SPAWN-UNBOUND-VAR-01: ${N:-} guards against opaque set -u abort (see cmd_request).
  local wf="${1:-}" phase="${2:-}" result_artifact="${3:-}"
  [ -z "$wf" ] || [ -z "$phase" ] || [ -z "$result_artifact" ] && {
    echo "usage: psk-spawn.sh complete <workflow> <phase> <result-artifact>" >&2
    exit 2
  }
  if [ ! -f "$result_artifact" ]; then
    echo "✗ result artifact missing: $result_artifact" >&2
    echo "  the sub-agent did not finish — do NOT mark complete." >&2
    echo "  → psk-spawn.sh retry $wf $phase  then spawn again" >&2
    exit 1
  fi
  local req="$SPAWN_DIR/${wf}.${phase}.request"
  [ -f "$req" ] && mv "$req" "${req}.done"
  bash "$STATE_SCRIPT" mark-in-progress "$wf" "$phase" >/dev/null 2>&1 || true
  echo "✓ sub-agent complete for $wf/$phase — result verified at $result_artifact"
  echo "  workflow may now run the phase completion gate and mark-done."
}

cmd_retry() {
  # QA-D32-SPAWN-UNBOUND-VAR-01: ${N:-} guards against opaque set -u abort (see cmd_request).
  local wf="${1:-}" phase="${2:-}"
  local err_msg="${3:-spawn retry requested}"
  [ -z "$wf" ] || [ -z "$phase" ] && { echo "usage: psk-spawn.sh retry <workflow> <phase> [\"<error>\"]" >&2; exit 2; }

  # HF3 backoff check — if a retry-queue entry already exists for this
  # (workflow, phase, target) and its next_attempt_at is still in the future,
  # refuse the retry unless PSK_RETRY_FORCE=1. The retry queue is the
  # durable source of truth for "may I attempt this spawn now?".
  local req="$SPAWN_DIR/${wf}.${phase}.request"
  local prompt_file="" artifact_file=""
  if [ -f "$req" ]; then
    prompt_file=$(grep '^PROMPT_FILE=' "$req" | cut -d= -f2-)
    artifact_file=$(grep '^RESULT_ARTIFACT=' "$req" | cut -d= -f2-)
  fi

  if [ "${PSK_RETRY_FORCE:-0}" = "1" ]; then
    _log_bypass "PSK_RETRY_FORCE" "psk-spawn.sh retry $wf $phase"
  fi
  if [ -x "$RETRY_QUEUE_SCRIPT" ] && [ "${PSK_RETRY_FORCE:-0}" != "1" ]; then
    # Look up the existing entry's next_attempt_at via psk-retry-queue.sh list.
    local nxt_iso
    nxt_iso=$(bash "$RETRY_QUEUE_SCRIPT" list 2>/dev/null \
      | awk -v wf="$wf" -v ph="$phase" \
            'BEGIN{FS="  +"} $2==wf && $3==ph {print $5; exit}')
    if [ -n "$nxt_iso" ] && [ "$nxt_iso" != "NEXT_ATTEMPT_AT" ]; then
      local nxt_epoch
      nxt_epoch=$(python3 -c "
import re, calendar
m = re.match(r'^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})Z\$', '$nxt_iso'.strip())
if m:
    p = [int(x) for x in m.groups()]
    print(calendar.timegm((p[0],p[1],p[2],p[3],p[4],p[5],0,0,0)))
else:
    print(0)
" 2>/dev/null || echo 0)
      local now_epoch
      now_epoch=$(date -u +%s)
      if [ "$nxt_epoch" -gt "$now_epoch" ]; then
        local secs_left=$(( nxt_epoch - now_epoch ))
        local mins_left=$(( (secs_left + 59) / 60 ))
        echo "⚠ retry backoff not elapsed for $wf/$phase" >&2
        echo "  next_attempt_at: $nxt_iso (~${mins_left} min from now)" >&2
        echo "  override: PSK_RETRY_FORCE=1 bash agent/scripts/psk-spawn.sh retry $wf $phase" >&2
        exit 5
      fi
    fi
  fi

  bash "$STATE_SCRIPT" mark-awaiting "$wf" "$phase" "SUBAGENT_RETRY" >/dev/null 2>&1 || true

  # HF3: persist this retry intent to the durable queue. spawn_target is the
  # caller-provided phase context — best-effort classification: critic-/qa-/
  # dev-/orchestrate-/feature- prefixes inform the target field, defaulting
  # to "subagent" for unmatched workflows.
  # QA-D7-P8 (cycle-01-pass-008): the retry-queue write is the durable record
  # of a paused spawn — if it fails silently the spawn intent is LOST (no
  # session-start auto-resume, no watchdog re-enqueue). Capture the result and
  # surface a stderr warning + non-zero internal status on failure instead of
  # swallowing it. The no-inline-fallback contract is untouched: the only
  # forward path is still retry-spawn; the warning just makes a lost durable
  # record visible so the operator re-spawns manually rather than assuming the
  # queue has it.
  local _rq_write_ok=1
  if [ -x "$RETRY_QUEUE_SCRIPT" ]; then
    local target="subagent"
    case "$wf" in
      *critic*)      target="critic-agent" ;;
      reflex|*reflex*)
        case "$phase" in
          qa*|*qa*) target="qa-agent" ;;
          dev*|*dev*) target="dev-agent" ;;
          *) target="subagent" ;;
        esac
        ;;
      *orchestrate*) target="orchestrate-phase" ;;
      run-plan-*)    target="plan-phase-agent" ;;
      *feature*)     target="feature-spawn" ;;
    esac
    local _rq_out
    if ! _rq_out=$(bash "$RETRY_QUEUE_SCRIPT" add "$wf" "$phase" "$target" \
      "${prompt_file:-unknown}" "${artifact_file:-unknown}" "$err_msg" 2>&1); then
      _rq_write_ok=0
      echo "⚠ psk-spawn: retry-queue write FAILED for $wf/$phase — durable record NOT persisted." >&2
      echo "  The session-start auto-resume + watchdog cannot pick this up. Re-spawn manually." >&2
      [ -n "$_rq_out" ] && echo "  retry-queue.sh said: $_rq_out" >&2
    fi
  fi

  echo "⏸ AWAITING_SUBAGENT_RETRY — workflow '$wf' phase '$phase'"
  echo ""
  if [ -f "$req" ]; then
    echo "  Re-spawn with the SAME prompt: $prompt_file"
    echo "  Sub-agent writes to: $artifact_file"
  fi
  echo ""
  echo "  The sub-agent rate-limited or failed. The forward path is to spawn it again."
  echo "  Waiting for the rate limit to clear is acceptable. Doing the work inline is NOT."
  if [ "$_rq_write_ok" = "1" ]; then
    echo "  Retry queued in agent/.workflow-state/retry-queue.yml (HF3)."
  else
    echo "  ⚠ Retry NOT durably queued (retry-queue write failed above) — re-spawn manually this session."
  fi
  if [ "${PSK_SPAWN_FIDELITY_DISABLED:-0}" = "1" ]; then
    _log_bypass "PSK_SPAWN_FIDELITY_DISABLED" "psk-spawn.sh retry $wf $phase"
    echo ""
    echo "  ⚠ PSK_SPAWN_FIDELITY_DISABLED=1 — fidelity guard bypassed. Even so, this"
    echo "    script does not do the work. The agent must still spawn or explicitly"
    echo "    accept a documented scope reduction."
  fi
  # QA-D7-P8: propagate the durable-write failure as a non-zero exit (code 6)
  # so callers/CI can detect a lost retry record. Exit 0 only when the queue
  # write succeeded (or the queue script was absent, which is its own no-op case
  # where _rq_write_ok stays 1).
  [ "$_rq_write_ok" = "1" ] || return 6
}

cmd_status() {
  local wf="$1" phase="$2"
  local req="$SPAWN_DIR/${wf}.${phase}.request"
  if [ -f "$req" ]; then
    echo "AWAITING — request pending:"
    cat "$req"
  elif [ -f "${req}.done" ]; then
    echo "COMPLETE — request fulfilled:"
    cat "${req}.done"
  else
    # Multi-spawn case: look for sibling per-id request files.
    local multi_count
    multi_count=$(ls "$SPAWN_DIR/${wf}.${phase}."*.request 2>/dev/null | wc -l | tr -d ' ')
    if [ "$multi_count" -gt 0 ]; then
      echo "AWAITING_MULTI — $multi_count parallel spawns pending:"
      ls "$SPAWN_DIR/${wf}.${phase}."*.request 2>/dev/null | sed 's|.*/||;s|\.request$||'
    else
      echo "no spawn request on record for $wf/$phase"
    fi
  fi
}

# KIT-GAP-0052 (v0.6.72): multi-spawn request. One phase, N parallel sub-agents.
# Reads manifest YAML, creates per-spawn request files, marks ONE workflow
# state entry as AWAITING:MULTI_SUBAGENT_SPAWN, prints fan-out protocol.
cmd_request_multi() {
  # QA-D32-SPAWN-UNBOUND-VAR-01: ${N:-} guards against opaque set -u abort (see cmd_request).
  local wf="${1:-}" phase="${2:-}" manifest="${3:-}"
  [ -z "$wf" ] || [ -z "$phase" ] || [ -z "$manifest" ] && {
    echo "usage: psk-spawn.sh request-multi <workflow> <phase> <manifest-yaml>" >&2
    exit 2
  }
  [ ! -f "$manifest" ] && { echo "manifest file not found: $manifest" >&2; exit 1; }

  # Idempotency guard — if the phase gate already passed, refuse.
  if [ "${PSK_IDEMPOTENCY_DISABLED:-0}" != "1" ]; then
    local _state_file="$PROJ_ROOT/agent/.workflow-state/${wf}.state"
    if [ -f "$_state_file" ] && grep -q "^GATE_PASSED_${phase}=" "$_state_file" 2>/dev/null; then
      local _ts
      _ts=$(grep "^GATE_PASSED_${phase}=" "$_state_file" | head -1 | cut -d= -f2-)
      echo "Phase $phase already complete (gate passed at $_ts); refusing to re-spawn."
      exit 0
    fi
  else
    _log_bypass "PSK_IDEMPOTENCY_DISABLED" "psk-spawn.sh request-multi $wf $phase"
  fi

  # Parse manifest with awk: extract id/prompt/artifact triples.
  # Validation requires schema_version=1 and at least 1 spawn entry.
  local sv
  sv=$(awk -F: '/^schema_version:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$manifest")
  [ "$sv" != "1" ] && { echo "manifest schema_version must be 1 (got: '$sv')" >&2; exit 1; }

  mkdir -p "$SPAWN_DIR"
  # QA-META-PHIL-03: serialise the whole rm-stale + write-N-files batch under the
  # spawn-state lock so a concurrent request-multi / complete-multi / status for
  # the same phase can't observe a partially-rewritten request set. Each per-spawn
  # file is itself written atomically (awk → .tmp, then mv) so even within the lock
  # window a crash leaves no half-file. The lock is released in all exit paths.
  _spawn_lock
  # Strip any stale request files for this phase before writing new ones.
  rm -f "$SPAWN_DIR/${wf}.${phase}."*.request 2>/dev/null

  local now_iso
  now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  # awk PARSES the manifest and emits one TAB-separated (id, prompt, artifact)
  # row per spawn. Bash then writes each request file via _atomic_write — the
  # rename happens in bash (quoted) so a SPAWN_DIR under a path with spaces
  # (e.g. the kit dev-workspace "/…/Aqib Mumtaz/…") renames correctly. Doing the
  # mv inside awk's system() would word-split the unquoted space (QA-META-PHIL-03
  # regression of the kit's own space-safe-paths rule).
  local _triples
  _triples=$(awk '
    BEGIN { in_spawns=0; in_entry=0; id=""; prompt=""; artifact="" }
    /^spawns:/ { in_spawns=1; next }
    in_spawns && /^[[:space:]]*-[[:space:]]*id:/ {
      if (id != "" && prompt != "" && artifact != "") print id "\t" prompt "\t" artifact
      in_entry=1; id=""; prompt=""; artifact=""
      sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", $0)
      gsub(/"/, "", $0); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      id=$0; next
    }
    in_spawns && in_entry && /^[[:space:]]*prompt:/ {
      sub(/^[[:space:]]*prompt:[[:space:]]*/, "", $0)
      gsub(/"/, "", $0); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      prompt=$0; next
    }
    in_spawns && in_entry && /^[[:space:]]*artifact:/ {
      sub(/^[[:space:]]*artifact:[[:space:]]*/, "", $0)
      gsub(/"/, "", $0); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      artifact=$0; next
    }
    END { if (id != "" && prompt != "" && artifact != "") print id "\t" prompt "\t" artifact }
  ' "$manifest")

  local spawn_count=0 _sid _sprompt _sartifact _reqfile
  while IFS=$'\t' read -r _sid _sprompt _sartifact; do
    [ -z "$_sid" ] && continue
    _reqfile="$SPAWN_DIR/${wf}.${phase}.${_sid}.request"
    {
      echo "WORKFLOW=$wf"
      echo "PHASE=$phase"
      echo "SPAWN_ID=$_sid"
      echo "PROMPT_FILE=$_sprompt"
      echo "RESULT_ARTIFACT=$_sartifact"
      echo "REQUESTED=$now_iso"
    } | _atomic_write "$_reqfile"
    spawn_count=$((spawn_count + 1))
  done <<< "$_triples"

  [ "$spawn_count" -lt 1 ] && { _spawn_unlock; echo "manifest has no valid spawn entries" >&2; exit 1; }
  _spawn_unlock

  # Model-policy resolution — PARITY with cmd_request (KIT-GAP / cycle-01/pass-002).
  # All N spawns in a request-multi share one phase, so they share one model. Without
  # this, the multi-author dim-agent fan-out — the kit's biggest cost lever, meant to
  # run on `sonnet` per .portable-spec-kit/model-policy.yml — silently inherited the
  # driver's (opus) model because the protocol block never surfaced the policy. Resolve
  # once and surface it in the fan-out instruction so every parallel spawn is pinned.
  local model_policy="$PROJ_ROOT/agent/scripts/psk-model-policy.sh"
  local spawn_model="inherit"
  if [ -f "$model_policy" ]; then
    spawn_model=$(bash "$model_policy" lookup "$phase" "$wf" 2>/dev/null || echo inherit)
    [ -z "$spawn_model" ] && spawn_model="inherit"
  fi

  bash "$STATE_SCRIPT" mark-awaiting "$wf" "$phase" "MULTI_SUBAGENT_SPAWN" >/dev/null 2>&1 || true

  echo "⏸ AWAITING_MULTI_SUBAGENT — workflow '$wf' phase '$phase' ($spawn_count parallel spawns)"
  echo "MODEL=$spawn_model"
  echo ""
  echo "  MAIN AGENT PROTOCOL (mandatory — fan out via Task tool):"
  echo "  1. For each request file in $SPAWN_DIR/$wf.$phase.*.request:"
  echo "     - Read its PROMPT_FILE field → that's the sub-agent prompt"
  if [ "$spawn_model" = "inherit" ]; then
    echo "     - Spawn a Task-tool sub-agent with that exact prompt (MODEL: inherit — current session model)"
  else
    echo "     - Spawn a Task-tool sub-agent with that exact prompt — set model=$spawn_model on the Task/Agent tool"
    echo "       (kit model-policy, cost/perf; do NOT default to the session model — the policy chose $spawn_model on purpose)"
  fi
  echo "     - Sub-agent writes its output to the RESULT_ARTIFACT path"
  echo "  2. Issue ALL $spawn_count Task tool calls in ONE response for parallelism (all with model=$spawn_model)."
  echo "  3. After all sub-agents return → bash psk-spawn.sh complete-multi $wf $phase <manifest>"
  echo ""
  echo "  Pending request files:"
  ls "$SPAWN_DIR/${wf}.${phase}."*.request 2>/dev/null | sed 's|.*/||;s|^|    |'
  echo ""
  echo "  There is NO step that does this phase's work inline. Spawn or retry-spawn only."
  # KIT-GAP-0133: structurally PRE-PLAN the reflex QA dim-agent progress tracker so the
  # status --table surface is ALWAYS set up by the kit. Each dim-agent spawn-completion
  # is a tracker row, rendered via the canonical psk-chunked-run.sh status --table for QA.
  if printf '%s' "$wf" | grep -q '^reflex-pass-' && printf '%s' "$phase" | grep -q 'qa-dims'; then
    _ccr="$PROJ_ROOT/agent/scripts/psk-chunked-run.sh"
    if [ -x "$_ccr" ]; then
      ( cd "$PROJ_ROOT" && bash "$_ccr" plan --label reflex-qa --suite reflex-qa-dims >/dev/null 2>&1 ) || true
      echo ""
      echo "  ── Progress surface (MANDATORY — structural, KIT-GAP-0133): the reflex-qa"
      echo "     per-dim-agent tracker is PRE-PLANNED. Relay this VERBATIM each turn so the QA"
      echo "     dim-agents show the canonical psk-chunked-run.sh status --table (separate from the Dev table):"
      echo "       bash agent/scripts/psk-chunked-run.sh status --table --label reflex-qa"
    fi
  fi
}

# Verify all per-spawn artifacts exist, then mark the phase IN_PROGRESS.
cmd_complete_multi() {
  # QA-D32-SPAWN-UNBOUND-VAR-01: ${N:-} guards against opaque set -u abort (see cmd_request).
  local wf="${1:-}" phase="${2:-}" manifest="${3:-}"
  [ -z "$wf" ] || [ -z "$phase" ] || [ -z "$manifest" ] && {
    echo "usage: psk-spawn.sh complete-multi <workflow> <phase> <manifest-yaml>" >&2
    exit 2
  }
  [ ! -f "$manifest" ] && { echo "manifest file not found: $manifest" >&2; exit 1; }

  # Walk manifest, verify each artifact exists.
  local missing=0 verified=0
  while IFS=$'\t' read -r aid apath; do
    [ -z "$aid" ] && continue
    if [ -f "$apath" ]; then
      verified=$((verified+1))
    else
      missing=$((missing+1))
      echo "✗ missing artifact for spawn '$aid': $apath" >&2
    fi
  done < <(awk '
    BEGIN { in_spawns=0; id=""; artifact="" }
    /^spawns:/ { in_spawns=1; next }
    in_spawns && /^[[:space:]]*-[[:space:]]*id:/ {
      if (id != "" && artifact != "") { print id "\t" artifact }
      sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", $0)
      gsub(/"/, "", $0); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      id=$0; artifact=""
    }
    in_spawns && /^[[:space:]]*artifact:/ {
      sub(/^[[:space:]]*artifact:[[:space:]]*/, "", $0)
      gsub(/"/, "", $0); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      artifact=$0
    }
    END { if (id != "" && artifact != "") print id "\t" artifact }
  ' "$manifest")

  if [ "$missing" -gt 0 ]; then
    echo "" >&2
    echo "✗ $missing of $((verified+missing)) sub-agent artifacts missing — phase NOT complete." >&2
    echo "  Re-spawn the missing sub-agents and re-run complete-multi." >&2
    exit 1
  fi

  # Move all per-spawn request files to .done — under the spawn-state lock so a
  # concurrent request-multi rewrite of the same phase doesn't race the rename
  # batch (QA-META-PHIL-03).
  _spawn_lock
  for req in "$SPAWN_DIR/${wf}.${phase}."*.request; do
    [ -f "$req" ] && mv -f "$req" "${req}.done"
  done
  _spawn_unlock

  bash "$STATE_SCRIPT" mark-in-progress "$wf" "$phase" >/dev/null 2>&1 || true
  echo "✓ all $verified sub-agents complete for $wf/$phase"
  echo "  workflow may now run the phase completion gate and mark-done."
}

case "${1:-}" in
  request)        shift; cmd_request "$@" ;;
  request-multi)  shift; cmd_request_multi "$@" ;;
  complete)       shift; cmd_complete "$@" ;;
  complete-multi) shift; cmd_complete_multi "$@" ;;
  retry)          shift; cmd_retry "$@" ;;
  status)         shift; cmd_status "$@" ;;
  -h|--help|"") sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "unknown subcommand: $1" >&2; exit 2 ;;
esac
