#!/bin/bash
# workflow-router: psk-run-plan.sh — plan-driver CLI; delegates phase driving to psk-dispatch.sh
# workflow-decl-exempt: plan-driver (reads agent/plans/<slug>.md frontmatter at runtime; not bound
#   to a single .portable-spec-kit/workflows/<name>/phases.yml — like psk-dispatch.sh, PSK034-exempt)
# psk-run-plan.sh — Executable-plan driver (§Plan Execution Protocol, portable-spec-kit.md)
#
# Reads a kit-conformant plan (frontmatter `phases:` schema), emits SPAWN signals
# one phase at a time, pauses for sub-agent execution, then advances on gate pass.
# Built on top of psk-workflow-state.sh (registered as workflow `run-plan-<slug>`)
# and follows the psk-spawn.sh SPAWN/AWAITING/retry contract — NO inline-fallback
# branch. The only forward paths are: spawn, retry-spawn, or abort.
#
# Lifecycle (mirrors psk-release.sh ergonomics):
#   start <slug>     read plan → validate schema → init state machine → emit SPAWN for first phase
#   next             verify artifact exists → run phase gate → on pass, advance + SPAWN next
#   status [<slug>]  print state for one plan (or all in-flight if omitted)
#   resume <slug>    re-emit SPAWN signal for current in-progress phase
#   retry            re-emit SPAWN, increment retry counter; after 3 retries → AWAITING_HUMAN_ARBITRATION
#   abort <slug>     mark workflow aborted; calls psk-plan-save.sh abandon <slug>
#   --convert <slug> emit single SPAWN with conversion prompt (legacy → schema)
#   --validate <slug> one-shot schema validation, exit 0/2, no state change
#   --health          one-liner across all in-flight plans
#
# Schema contract: every executable plan MUST carry frontmatter:
#   schema_version: 1
#   phases:
#     - id: <name>
#       name: "Title"
#       prompt: "agent/plans/<slug>/prompts/<id>.md"
#       artifact: "agent/plans/<slug>/artifacts/<id>.done.md"
#       gate: "<shell command>"
#       commit_required: true|false
#       depends_on: [<id>, ...]
#
# Compat-mode exception: a plan declaring `compat_mode: true` in frontmatter
# may run once without `phases:` — driver derives a single phase from the body
# and spawns a single sub-agent with the full plan. Next start requires conversion.
#
# Bypass: PSK_PLAN_EXEC_DISABLED=1 — emergency only; skips schema validation.
#
# Exit codes:
#   0 ok (AWAITING_SUBAGENT or COMPLETE)
#   1 missing artifact / plan not found / state error
#   2 schema invalid / usage error (PSK024)
#   3 gate failed
#   4 AWAITING_HUMAN_ARBITRATION (retry cap hit)

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PLANS_DIR="$PROJ_ROOT/agent/plans"
STATE_DIR="$PROJ_ROOT/agent/.workflow-state"
STATE_SCRIPT="$PROJ_ROOT/agent/scripts/psk-workflow-state.sh"
PLAN_SAVE_SCRIPT="$PROJ_ROOT/agent/scripts/psk-plan-save.sh"
DISPATCH_SCRIPT="$PROJ_ROOT/agent/scripts/psk-dispatch.sh"
RETRY_CAP=3

# ─────────────────────────────────────────────────────────────────────────────
# Dispatcher delegation (§Spawn Fidelity / §Plan Execution Protocol, v0.6.62+)
#
# The phase-DRIVING verbs (start/next/resume/retry) delegate to psk-dispatch.sh
# --plan <slug>, which routes every sub-agent spawn through psk-spawn.sh (retry
# queue + no-inline-fallback). This closes the gap where this script formerly
# emitted bare SPAWN: echoes that bypassed psk-spawn.sh. run-plan retains the
# user-facing CLI + schema validation (PSK024) + compat banner + the
# run-plan-specific verbs dispatch lacks (convert / health / validate / status /
# abort). The .run state file is shared (psk-dispatch.sh writes SLUG=/PLAN_FILE=/
# COMPAT_MODE= in plan mode so these readers keep working).
# ─────────────────────────────────────────────────────────────────────────────
_delegate() {  # _delegate <slug> <dispatch-verb...>
  local slug="$1"; shift
  exec bash "$DISPATCH_SCRIPT" --plan "$slug" "$@"
}

# ─────────────────────────────────────────────────────────────────────────────
# Plan-file resolution
# ─────────────────────────────────────────────────────────────────────────────

_find_plan_file() {
  local slug="$1"
  # Prefer dated form (most recent first), fall back to plain.
  local f
  f=$(ls -1 "$PLANS_DIR"/[0-9]*-"$slug".md 2>/dev/null | sort -r | head -1)
  [ -z "$f" ] && f=$(ls -1 "$PLANS_DIR"/"$slug".md 2>/dev/null | head -1)
  echo "$f"
}

_workflow_name() { echo "run-plan-$1"; }
_run_state_file() { echo "$STATE_DIR/$(_workflow_name "$1").run"; }

# ─────────────────────────────────────────────────────────────────────────────
# Frontmatter parsing (awk, no python/yq dependency)
# ─────────────────────────────────────────────────────────────────────────────
#
# Extracts `phases:` array from frontmatter. Emits one record per phase using
# ASCII Unit Separator (US, \x1f) — NOT tab — because bash with IFS set to a
# whitespace character collapses consecutive separators, which breaks reading
# rows where intermediate fields (e.g. name) are empty. US is non-whitespace,
# treated as a strict delimiter that does not collapse.
# Field order: id|name|prompt|artifact|gate|commit_required|depends_on
# depends_on emitted as comma-separated id list (no spaces) or empty.
PSK_RUN_PLAN_SEP=$'\x1f'

_parse_phases() {
  local file="$1"
  awk -v SEP=$'\x1f' '
    BEGIN { fm = 0; in_phases = 0; have = 0; depth = 0 }
    /^---$/ {
      fm++
      if (fm == 2) exit
      next
    }
    fm == 1 && /^phases:[[:space:]]*$/ { in_phases = 1; next }
    fm == 1 && in_phases && /^[A-Za-z_][A-Za-z0-9_]*:/ {
      # left non-indented key — phases array ended
      in_phases = 0
    }
    fm == 1 && in_phases && /^[[:space:]]*-[[:space:]]*id:/ {
      # New phase entry — emit previous if any
      if (have) {
        printf "%s%s%s%s%s%s%s%s%s%s%s%s%s\n", id, SEP, name, SEP, prompt, SEP, artifact, SEP, gate, SEP, commit_required, SEP, depends_on
      }
      id = ""; name = ""; prompt = ""; artifact = ""; gate = ""; commit_required = "false"; depends_on = ""
      have = 1
      sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "")
      gsub(/^["'\'']|["'\'']$/, "")
      id = $0
      next
    }
    fm == 1 && in_phases && have && /^[[:space:]]+name:/ {
      sub(/^[[:space:]]+name:[[:space:]]*/, "")
      gsub(/^["'\'']|["'\'']$/, "")
      name = $0
      next
    }
    fm == 1 && in_phases && have && /^[[:space:]]+prompt:/ {
      sub(/^[[:space:]]+prompt:[[:space:]]*/, "")
      gsub(/^["'\'']|["'\'']$/, "")
      prompt = $0
      next
    }
    fm == 1 && in_phases && have && /^[[:space:]]+artifact:/ {
      sub(/^[[:space:]]+artifact:[[:space:]]*/, "")
      gsub(/^["'\'']|["'\'']$/, "")
      artifact = $0
      next
    }
    fm == 1 && in_phases && have && /^[[:space:]]+gate:/ {
      sub(/^[[:space:]]+gate:[[:space:]]*/, "")
      gsub(/^["'\'']|["'\'']$/, "")
      gate = $0
      next
    }
    fm == 1 && in_phases && have && /^[[:space:]]+commit_required:/ {
      sub(/^[[:space:]]+commit_required:[[:space:]]*/, "")
      commit_required = $0
      next
    }
    fm == 1 && in_phases && have && /^[[:space:]]+depends_on:/ {
      sub(/^[[:space:]]+depends_on:[[:space:]]*/, "")
      gsub(/^\[|\]$/, "")
      gsub(/[[:space:]"]/, "")
      depends_on = $0
      next
    }
    END {
      if (have) {
        printf "%s%s%s%s%s%s%s%s%s%s%s%s%s\n", id, SEP, name, SEP, prompt, SEP, artifact, SEP, gate, SEP, commit_required, SEP, depends_on
      }
    }
  ' "$file"
}

_fm_field() {
  local file="$1" field="$2"
  awk -v fld="$field" '
    /^---$/ { fm++; if (fm == 2) exit; next }
    fm == 1 && $1 == fld":" { sub(/^[^:]+:[[:space:]]*/, ""); print; exit }
  ' "$file"
}

# ─────────────────────────────────────────────────────────────────────────────
# Schema validation (PSK024)
# ─────────────────────────────────────────────────────────────────────────────

_validate_schema() {
  local file="$1"
  local errs=0

  if ! grep -q '^schema_version:' "$file"; then
    echo "PSK024: missing schema_version in frontmatter — $file" >&2
    errs=$((errs+1))
  fi

  local has_phases
  has_phases=$(awk '/^---$/ { fm++; if (fm==2) exit; next } fm==1 && /^phases:[[:space:]]*$/ { print "yes"; exit }' "$file")

  if [ -z "$has_phases" ]; then
    # compat_mode escape hatch
    local compat
    compat=$(_fm_field "$file" compat_mode)
    if [ "$compat" = "true" ]; then
      return 0
    fi
    echo "PSK024: missing phases: frontmatter block — $file" >&2
    echo "  Fix: add a phases: array (see .portable-spec-kit/templates/plan-executable.md)" >&2
    echo "  Or set compat_mode: true for a one-shot legacy run, then --convert." >&2
    return 2
  fi

  # Validate each phase has the required keys
  local rows
  rows=$(_parse_phases "$file")
  if [ -z "$rows" ]; then
    echo "PSK024: phases: block present but no phase entries parsed — $file" >&2
    return 2
  fi

  while IFS="$PSK_RUN_PLAN_SEP" read -r id name prompt artifact gate _ _; do
    [ -z "$id" ]       && { echo "PSK024: phase missing id — $file" >&2; errs=$((errs+1)); }
    [ -z "$prompt" ]   && { echo "PSK024: phase $id missing prompt — $file" >&2; errs=$((errs+1)); }
    [ -z "$artifact" ] && { echo "PSK024: phase $id missing artifact — $file" >&2; errs=$((errs+1)); }
    [ -z "$gate" ]     && { echo "PSK024: phase $id missing gate — $file" >&2; errs=$((errs+1)); }
  done <<EOF
$rows
EOF

  [ "$errs" -gt 0 ] && return 2
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Per-plan run-state (SPAWN signal, retry counter, current phase)
# ─────────────────────────────────────────────────────────────────────────────

_run_state_init() {
  local slug="$1" plan_file="$2"
  mkdir -p "$STATE_DIR"
  local rf; rf=$(_run_state_file "$slug")
  {
    echo "SLUG=$slug"
    echo "PLAN_FILE=$plan_file"
    echo "STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "CURRENT_PHASE="
    echo "RETRIES=0"
    echo "COMPAT_MODE=${COMPAT_MODE:-false}"
  } > "$rf"
}

_run_state_set() {
  local slug="$1" key="$2" val="$3"
  local rf; rf=$(_run_state_file "$slug")
  [ ! -f "$rf" ] && { echo "no run-state for $slug" >&2; return 1; }
  local tmp; tmp=$(mktemp)
  local found=0
  while IFS= read -r line; do
    if [[ "$line" == "$key="* ]]; then
      echo "$key=$val"; found=1
    else
      echo "$line"
    fi
  done < "$rf" > "$tmp"
  [ "$found" -eq 0 ] && echo "$key=$val" >> "$tmp"
  mv "$tmp" "$rf"
}

_run_state_get() {
  local slug="$1" key="$2"
  local rf; rf=$(_run_state_file "$slug")
  [ ! -f "$rf" ] && return 1
  grep "^${key}=" "$rf" | head -1 | cut -d= -f2-
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase dependency resolution
# ─────────────────────────────────────────────────────────────────────────────
#
# Returns the next actionable phase id given the parsed phases table and the
# workflow state machine's per-phase status. A phase is actionable when:
#   - its state is `pending`
#   - every id in its depends_on list has state `done`

_next_actionable_phase() {
  local slug="$1" plan_file="$2"
  local wf; wf=$(_workflow_name "$slug")
  local sf="$STATE_DIR/$wf.state"
  [ ! -f "$sf" ] && return 1

  local rows; rows=$(_parse_phases "$plan_file")
  while IFS="$PSK_RUN_PLAN_SEP" read -r id _ _ _ _ _ deps; do
    [ -z "$id" ] && continue
    local status; status=$(grep "^PHASE_${id}=" "$sf" | head -1 | cut -d= -f2-)
    case "$status" in
      done|in_progress) ;;
      *)
        # Check all deps done
        local ok=1
        if [ -n "$deps" ]; then
          local IFS=','
          for d in $deps; do
            [ -z "$d" ] && continue
            local dstatus
            dstatus=$(grep "^PHASE_${d}=" "$sf" | head -1 | cut -d= -f2-)
            if [ "$dstatus" != "done" ]; then ok=0; break; fi
          done
        fi
        if [ "$ok" -eq 1 ]; then echo "$id"; return 0; fi
        ;;
    esac
  done <<EOF
$rows
EOF
  return 1
}

# Look up one phase row by id; emits the same TAB record _parse_phases produces.
_get_phase_row() {
  local plan_file="$1" want_id="$2"
  _parse_phases "$plan_file" | awk -F"$PSK_RUN_PLAN_SEP" -v want="$want_id" '$1 == want { print; exit }'
}

# ─────────────────────────────────────────────────────────────────────────────
# SPAWN signal
# ─────────────────────────────────────────────────────────────────────────────

_emit_spawn() {
  local slug="$1" phase_id="$2" prompt="$3" artifact="$4" gate="$5"
  echo "SPAWN: phase=$phase_id prompt=$prompt artifact=$artifact gate=$gate"
  echo ""
  echo "  AWAITING_SUBAGENT — plan '$slug' paused at phase '$phase_id'"
  echo ""
  echo "  MAIN AGENT PROTOCOL (mandatory — no inline alternative):"
  echo "  1. Read prompt: $prompt"
  echo "  2. Spawn sub-agent (Task tool) with that exact prompt"
  echo "  3. Sub-agent writes its artifact to: $artifact"
  echo "  4. Then call: psk-run-plan.sh next   (verifies artifact + runs gate + advances)"
  echo "  5. On sub-agent failure / rate-limit: psk-run-plan.sh retry"
}

# ─────────────────────────────────────────────────────────────────────────────
# Commands
# ─────────────────────────────────────────────────────────────────────────────

cmd_start() {
  local slug="$1"
  [ -z "$slug" ] && { echo "usage: psk-run-plan.sh start <slug>" >&2; exit 2; }

  local plan_file; plan_file=$(_find_plan_file "$slug")
  [ -z "$plan_file" ] && { echo "plan not found for slug: $slug (looked in $PLANS_DIR)" >&2; exit 1; }

  # Refuse to restart an in-progress execution.
  local wf; wf=$(_workflow_name "$slug")
  if [ -f "$STATE_DIR/$wf.state" ] && ! bash "$STATE_SCRIPT" "complete?" "$wf" >/dev/null 2>&1; then
    echo "plan '$slug' is already executing — use 'resume $slug' or 'abort $slug'" >&2
    bash "$STATE_SCRIPT" status "$wf" 2>/dev/null || true
    exit 1
  fi

  # Schema validation (PSK024) — unless bypassed.
  COMPAT_MODE="false"
  if [ "${PSK_PLAN_EXEC_DISABLED:-0}" != "1" ]; then
    local compat; compat=$(_fm_field "$plan_file" compat_mode)
    if [ "$compat" = "true" ]; then
      COMPAT_MODE="true"
    else
      if ! _validate_schema "$plan_file"; then
        echo "" >&2
        echo "Refusing to start — fix schema or set compat_mode: true for a one-shot legacy run." >&2
        exit 2
      fi
    fi
  else
    # HF9 (v0.6.60): durable bypass-tamper audit trail.
    _bypass_log_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/psk-bypass-log.sh"
    if [ -x "$_bypass_log_script" ]; then
      bash "$_bypass_log_script" log \
        --env-var "PSK_PLAN_EXEC_DISABLED" \
        --command "psk-run-plan.sh start $slug" \
        --justification "${PSK_BYPASS_REASON:-not provided}" 2>/dev/null || true
    fi
  fi

  mkdir -p "$STATE_DIR"

  # Transition plan lifecycle to executing (run-plan owns the PSK024 validation +
  # lifecycle; the dispatcher owns phase driving).
  if [ -x "$PLAN_SAVE_SCRIPT" ]; then
    bash "$PLAN_SAVE_SCRIPT" start "$slug" >/dev/null 2>&1 || true
  fi

  # Compat banner (preserves the user-facing signal; dispatch runs the synthetic
  # single 'compat' phase via its own _parse_phases_table compat branch).
  if [ "$COMPAT_MODE" = "true" ]; then
    echo "── compat_mode: legacy plan executes as a single synthetic phase ──"
  fi

  # DELEGATE driving to psk-dispatch.sh --plan (routes every spawn through
  # psk-spawn.sh — retry queue + no-inline-fallback). `next` auto-inits the
  # workflow then dispatches the first actionable phase, emitting the SPAWN.
  _delegate "$slug" next
}

cmd_next() {
  # Find the in-flight plan from run-state. If only one, use it; if many, require a slug arg.
  local slug="${1:-}"
  if [ -z "$slug" ]; then
    local candidates
    candidates=$(ls -1 "$STATE_DIR"/run-plan-*.run 2>/dev/null | wc -l | tr -d ' ')
    if [ "$candidates" = "0" ]; then
      echo "no in-flight plans — use 'start <slug>' first" >&2; exit 1
    elif [ "$candidates" = "1" ]; then
      local rf
      rf=$(ls -1 "$STATE_DIR"/run-plan-*.run 2>/dev/null | head -1)
      slug=$(grep '^SLUG=' "$rf" | cut -d= -f2-)
    else
      echo "multiple in-flight plans — pass slug explicitly: psk-run-plan.sh next <slug>" >&2
      bash "$0" --health >&2 || true
      exit 1
    fi
  fi
  # DELEGATE: dispatcher verifies artifact + runs gate + advances, routing the
  # next phase's spawn through psk-spawn.sh. Compat single-phase, schema advance,
  # idempotency skip, gate-fail exit 3, and COMPLETE are all handled by dispatch.
  _delegate "$slug" next
}

cmd_resume() {
  local slug="$1"
  [ -z "$slug" ] && { echo "usage: psk-run-plan.sh resume <slug>" >&2; exit 2; }
  # DELEGATE: dispatcher re-emits the SPAWN for the current paused phase. The
  # dispatcher owns the run-state (run-plan-<slug>.dispatch.run) and reports
  # "not initialized" itself if there is nothing to resume — so no run-plan-side
  # .run pre-check (which would look for the pre-delegation file name).
  _delegate "$slug" resume
}

cmd_retry() {
  # No slug -> infer from single in-flight; multi requires explicit arg
  local slug="${1:-}"
  if [ -z "$slug" ]; then
    local candidates
    candidates=$(ls -1 "$STATE_DIR"/run-plan-*.run 2>/dev/null | wc -l | tr -d ' ')
    if [ "$candidates" = "0" ]; then
      echo "no in-flight plans — nothing to retry" >&2; exit 1
    elif [ "$candidates" = "1" ]; then
      local rf
      rf=$(ls -1 "$STATE_DIR"/run-plan-*.run 2>/dev/null | head -1)
      slug=$(grep '^SLUG=' "$rf" | cut -d= -f2-)
    else
      echo "multiple in-flight plans — pass slug: psk-run-plan.sh retry <slug>" >&2
      exit 1
    fi
  fi
  # DELEGATE: dispatcher increments the retry counter (cap 3 -> exit 4
  # AWAITING_HUMAN_ARBITRATION) and re-emits the SPAWN via psk-spawn.sh.
  _delegate "$slug" retry
}

cmd_status() {
  local slug="${1:-}"
  if [ -n "$slug" ]; then
    local rf; rf=$(_run_state_file "$slug")
    if [ ! -f "$rf" ]; then
      echo "no run-state for '$slug' (never started, already aborted, or wrong slug)"
      exit 1
    fi
    echo "── run-state: $slug ──"
    cat "$rf"
    echo ""
    local wf; wf=$(_workflow_name "$slug")
    bash "$STATE_SCRIPT" status "$wf" 2>/dev/null || echo "(workflow state machine reports no entry)"
    exit 0
  fi
  # No slug → list all
  local any=0
  for rf in "$STATE_DIR"/run-plan-*.run; do
    [ -f "$rf" ] || continue
    any=1
    local s; s=$(grep '^SLUG=' "$rf" | cut -d= -f2-)
    local p; p=$(grep '^CURRENT_PHASE=' "$rf" | cut -d= -f2-)
    local r; r=$(grep '^RETRIES=' "$rf" | cut -d= -f2-)
    printf '  %-30s current=%-12s retries=%s\n' "$s" "${p:-(none)}" "${r:-0}"
  done
  [ "$any" -eq 0 ] && echo "no in-flight plans"
  exit 0
}

cmd_abort() {
  local slug="$1"
  [ -z "$slug" ] && { echo "usage: psk-run-plan.sh abort <slug>" >&2; exit 2; }
  local wf; wf=$(_workflow_name "$slug")
  local sf="$STATE_DIR/$wf.state"
  local rf; rf=$(_run_state_file "$slug")
  if [ ! -f "$sf" ] && [ ! -f "$rf" ]; then
    echo "no execution state for '$slug' — nothing to abort" >&2
    exit 1
  fi
  # Move state aside (forensic) and remove gate file + run-state
  if [ -f "$sf" ]; then
    mv "$sf" "$sf.aborted.$(date +%s)"
  fi
  [ -f "$STATE_DIR/$wf.gates" ] && rm -f "$STATE_DIR/$wf.gates"
  [ -f "$rf" ] && mv "$rf" "$rf.aborted.$(date +%s)"
  if [ -x "$PLAN_SAVE_SCRIPT" ]; then
    bash "$PLAN_SAVE_SCRIPT" abandon "$slug" "aborted via psk-run-plan.sh" >/dev/null 2>&1 || true
  fi
  echo "✗ aborted plan '$slug' — state moved to *.aborted.* (artifacts left in place for forensics)"
  exit 0
}

cmd_convert() {
  local slug="$1"
  [ -z "$slug" ] && { echo "usage: psk-run-plan.sh --convert <slug>" >&2; exit 2; }
  local plan_file; plan_file=$(_find_plan_file "$slug")
  [ -z "$plan_file" ] && { echo "plan not found for slug: $slug" >&2; exit 1; }

  mkdir -p "$STATE_DIR"
  local wf; wf=$(_workflow_name "$slug")
  local prompt_file="$STATE_DIR/$wf.convert.prompt.md"
  local artifact="$STATE_DIR/$wf.convert.done.md"

  # Write the conversion prompt for the sub-agent
  cat > "$prompt_file" <<EOF
# Plan Conversion — legacy → executable-plan schema (schema_version: 1)

You are a sub-agent invoked by psk-run-plan.sh --convert to convert a legacy
plan file into the kit's executable-plan schema (see
.portable-spec-kit/templates/plan-executable.md).

## Source plan
$plan_file

## Goal
Add \`phases:\` frontmatter to the source plan derived from its
\`## Implementation Order\` (or equivalent narrative phase list) section,
scaffold per-phase prompt and artifact files, and commit.

## Files to read
- $plan_file
- .portable-spec-kit/templates/plan-executable.md
- .portable-spec-kit/templates/plan-prompt.md (if present)
- .portable-spec-kit/templates/plan-artifact.md (if present)

## Files to write
- $plan_file — patched with phases: frontmatter (schema_version: 1, status preserved, updated:= today)
- agent/plans/$slug/prompts/<phase-id>.md — one per phase (use plan-prompt.md as starter)
- agent/plans/$slug/artifacts/<phase-id>.done.md — empty stub per phase (sub-agents fill on phase end)

## Completion criteria
- bash agent/scripts/psk-run-plan.sh --validate $slug exits 0
- The commit lands the changes with subject: "$slug: convert legacy plan to schema_version: 1"

## Output artifact spec
Write a one-page summary to: $artifact
Required fields: commit_sha, files_changed, validate_exit_code, notes.
EOF

  # Register a synthetic single-phase workflow for the conversion run.
  bash "$STATE_SCRIPT" init "$wf" "convert" >/dev/null 2>&1 || true
  bash "$STATE_SCRIPT" register-gate "$wf" convert "bash $0 --validate $slug" >/dev/null 2>&1 || true
  _run_state_init "$slug" "$plan_file"
  _run_state_set "$slug" CURRENT_PHASE convert
  _run_state_set "$slug" COMPAT_MODE convert
  bash "$STATE_SCRIPT" mark-awaiting "$wf" convert "SUBAGENT_SPAWN" >/dev/null

  echo "── conversion: legacy plan '$slug' → schema_version: 1 ──"
  _emit_spawn "$slug" convert "$prompt_file" "$artifact" "bash $0 --validate $slug"
  exit 0
}

cmd_validate() {
  local slug="$1"
  [ -z "$slug" ] && { echo "usage: psk-run-plan.sh --validate <slug>" >&2; exit 2; }
  local plan_file; plan_file=$(_find_plan_file "$slug")
  [ -z "$plan_file" ] && { echo "plan not found for slug: $slug" >&2; exit 1; }
  if _validate_schema "$plan_file"; then
    echo "✓ schema valid: $plan_file"
    exit 0
  else
    echo "✗ schema invalid: $plan_file" >&2
    exit 2
  fi
}

cmd_health() {
  local any=0 stuck=0 retry=0 awaiting=0
  for rf in "$STATE_DIR"/run-plan-*.run; do
    [ -f "$rf" ] || continue
    any=$((any+1))
    local s; s=$(grep '^SLUG=' "$rf" | cut -d= -f2-)
    local p; p=$(grep '^CURRENT_PHASE=' "$rf" | cut -d= -f2-)
    local r; r=$(grep '^RETRIES=' "$rf" | cut -d= -f2-)
    local wf; wf=$(_workflow_name "$s")
    local sf="$STATE_DIR/$wf.state"
    local status="(no-state)"
    if [ -f "$sf" ]; then
      status=$(grep "^PHASE_${p}=" "$sf" 2>/dev/null | head -1 | cut -d= -f2-)
      [ -z "$status" ] && status="(unknown)"
    fi
    [ "$r" -gt 0 ] 2>/dev/null && retry=$((retry+1))
    [[ "$status" == AWAITING:* ]] && awaiting=$((awaiting+1))
    [[ "$status" == "in_progress" ]] && stuck=$((stuck+1))
    printf '  %-30s phase=%-12s status=%-30s retries=%s\n' "$s" "${p:-(none)}" "$status" "${r:-0}"
  done
  if [ "$any" -eq 0 ]; then
    echo "psk-run-plan: 0 in-flight"
  else
    echo "psk-run-plan: $any in-flight ($awaiting awaiting subagent, $retry with retries, $stuck running)"
  fi
  exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Dispatch
# ─────────────────────────────────────────────────────────────────────────────

case "${1:-}" in
  start)        shift; cmd_start "${1:-}" ;;
  next)         shift; cmd_next "${1:-}" ;;
  resume)       shift; cmd_resume "${1:-}" ;;
  retry)        shift; cmd_retry "${1:-}" ;;
  status)       shift; cmd_status "${1:-}" ;;
  abort)        shift; cmd_abort "${1:-}" ;;
  --convert)    shift; cmd_convert "${1:-}" ;;
  --validate)   shift; cmd_validate "${1:-}" ;;
  --health)     cmd_health ;;
  -h|--help|"") sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)            echo "unknown subcommand: ${1:-}" >&2; echo "run with --help for usage" >&2; exit 2 ;;
esac
