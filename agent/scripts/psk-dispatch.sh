#!/bin/bash
# workflow-router: psk-dispatch.sh — shared phase-dispatch driver
# workflow-decl-exempt: class-A-canonical (unified dispatch driver — reads any workflow's phases.yml
#   or plan frontmatter at runtime; not bound to a single phases.yml declaration)
# psk-dispatch.sh — Unified phase-dispatch driver (§Spawn Fidelity / §Plan Execution Protocol)
#
# Single shared dispatcher for every kit workflow and every executable plan.
# Reads phase declarations from:
#   - .portable-spec-kit/workflows/<wf>/phases.yml  (workflow mode)
#   - agent/plans/<dated>-<slug>.md frontmatter      (plan mode)
#   - arbitrary phases.yml-shaped file               (file mode — for tests)
#
# Registers with psk-workflow-state.sh, routes sub-agent phases through
# psk-spawn.sh, and runs mechanical phases directly. D1 delivers sequential
# dispatch only — D2 adds parallel, D3 adds mechanical-skip.
#
# 100% guarantee preserved: every existing contract (phase idempotency,
# gate isolation, durable execution, sub-agent context cleanliness, behavior
# parity) is structurally inherited. psk-dispatch.sh reuses psk-workflow-state.sh,
# psk-spawn.sh, and psk-bypass-log.sh as primitives; it adds no new state machines.
#
# Usage:
#   # Workflow mode — reads .portable-spec-kit/workflows/<wf>/phases.yml
#   bash agent/scripts/psk-dispatch.sh release [verb]
#
#   # Plan mode — reads agent/plans/<dated>-<slug>.md frontmatter phases:
#   bash agent/scripts/psk-dispatch.sh --plan <slug> [verb]
#
#   # Arbitrary-file mode — reads any phases.yml-shaped file (for tests)
#   bash agent/scripts/psk-dispatch.sh --phases-file <path> --workflow-id <id> [verb]
#
# Verbs:
#   init       # register workflow with psk-workflow-state.sh (idempotent)
#   next       # advance: verify artifact → run gate → mark-done → SPAWN next
#   status     # print current state + phase table
#   resume     # re-emit SPAWN for current paused phase (alias for retry-spawn)
#   retry      # re-emit SPAWN, increment retry counter (cap 3 → AWAITING_HUMAN_ARBITRATION)
#   done       # mark workflow complete
#   abandon    # mark workflow abandoned
#   list       # list all workflows from _audit.yml (or all plans from agent/plans/)
#   --validate <wf-or-slug>  # schema-check phases.yml without running (exit 0/2)
#   --help     # usage
#
# Bypass:
#   PSK_WORKFLOW_STATE_DISABLED=1   — psk-workflow-state.sh silently succeeds
#   PSK_SPAWN_FIDELITY_DISABLED=1   — psk-spawn.sh handles this
#   PSK_IDEMPOTENCY_DISABLED=1      — skip outer gate-check on `next`
#
# Exit codes:
#   0 ok (AWAITING_SUBAGENT or COMPLETE or MANUAL_CHECKPOINT)
#   1 missing artifact / plan not found / state error
#   2 schema invalid / usage error
#   3 gate failed
#   4 AWAITING_HUMAN_ARBITRATION (retry cap hit)

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STATE_DIR="${PSK_STATE_DIR:-$PROJ_ROOT/agent/.workflow-state}"
STATE_SCRIPT="$PROJ_ROOT/agent/scripts/psk-workflow-state.sh"
SPAWN_SCRIPT="$PROJ_ROOT/agent/scripts/psk-spawn.sh"
BYPASS_LOG_SCRIPT="$PROJ_ROOT/agent/scripts/psk-bypass-log.sh"
AUDIT_YML="$PROJ_ROOT/.portable-spec-kit/workflows/_audit.yml"
WORKFLOWS_DIR="$PROJ_ROOT/.portable-spec-kit/workflows"
PLANS_DIR="$PROJ_ROOT/agent/plans"

# Reflex phase commands/gates reference $REFLEX_PROJ_ROOT (normally exported by
# reflex/run.sh). Default it to PROJ_ROOT so the dispatcher can run reflex phases
# directly without crashing under `set -u` when the wrapper didn't export it.
: "${REFLEX_PROJ_ROOT:=$PROJ_ROOT}"
export REFLEX_PROJ_ROOT

# Substitute path-bearing variables in a mechanical command / gate string BEFORE
# eval so a checkout under a path with spaces ("/Users/Jane Doe/...") doesn't
# word-split. Handles BOTH ref styles a phases.yml command/gate may use:
#   "$VAR"  (already quoted, e.g. `test -d "$PASS_DIR"`)  → "<raw value>"
#           the source quotes already protect the space; raw keeps it valid.
#   $VAR    (bare, e.g. `bash $PROJ_ROOT/tests/x.sh`)     → <%q-escaped value>
#           %q escapes the space so an unquoted ref stays a single word.
# Order: replace the quoted form first so the bare-form pass can't touch it.
# REFLEX_* listed first so longer names substitute before PROJ_ROOT/PASS_DIR substrings.
_quote_path_vars() {
  local cmd="$1" v val q
  for v in REFLEX_PROJ_ROOT REFLEX_PASS_DIR PROJ_ROOT PASS_DIR; do
    [ -n "${!v:-}" ] || continue
    val="${!v}"
    q=$(printf '%q' "$val")
    cmd="${cmd//\"\$$v\"/\"$val\"}"   # "$VAR" → "raw value"
    cmd="${cmd//\$$v/$q}"             # bare $VAR → %q-escaped
  done
  printf '%s' "$cmd"
}

# Resolve a phase artifact path. Relative paths are resolved under PROJ_ROOT
# (the canonical kit convention: agent/plans/<slug>/artifacts/<id>.done.md).
# Absolute paths are returned as-is — psk-run-plan.sh historically tolerated
# absolute artifact paths, so a delegated plan declaring one must not be
# double-prefixed into "$PROJ_ROOT/<abs>".
_art_resolve() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s' "$PROJ_ROOT/$1" ;;
  esac
}

# ASCII Unit Separator — same delimiter as psk-run-plan.sh (load-bearing: non-whitespace,
# strict, does not collapse consecutive empty fields the way IFS whitespace does).
# Field order in emitted records:
#   workflow mode:  id|name|spawn_type|prompt|artifact|command|gate|commit_required|depends_on
#   plan mode:      id|name|spawn_type(always sub-agent)|prompt|artifact||gate|commit_required|depends_on
SEP=$'\x1f'

RETRY_CAP=3

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

DISPATCH_MODE="workflow"
PLAN_SLUG=""
FILE_PATH=""
WF_ID_OVERRIDE=""
WF_NAME=""

# Process leading --flags before positional args
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --plan)
      DISPATCH_MODE="plan"
      PLAN_SLUG="${2:-}"
      [ -z "$PLAN_SLUG" ] && { echo "usage: psk-dispatch.sh --plan <slug> [verb]" >&2; exit 2; }
      shift 2
      ;;
    --phases-file)
      DISPATCH_MODE="file"
      FILE_PATH="${2:-}"
      [ -z "$FILE_PATH" ] && { echo "usage: psk-dispatch.sh --phases-file <path> [verb]" >&2; exit 2; }
      shift 2
      ;;
    --workflow-id)
      WF_ID_OVERRIDE="${2:-}"
      shift 2
      ;;
    --validate)
      # Special: validate a workflow or plan schema without running.
      # Store target for deferred execution after all functions are defined.
      _DEFERRED_VALIDATE="${2:-}"
      shift 2 || true
      ;;
    --force)
      export PSK_IDEMPOTENCY_DISABLED=1
      shift
      ;;
    --help|-h)
      # Print header comment block
      sed -n '2,55p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

# First positional arg is workflow name (for workflow mode)
if [ "$DISPATCH_MODE" = "workflow" ]; then
  WF_NAME="${1:-}"
  [ -n "$WF_NAME" ] && shift || true
fi

VERB="${1:-next}"
[ -n "${1:-}" ] && shift || true

# ─────────────────────────────────────────────────────────────────────────────
# Phase source resolution
# ─────────────────────────────────────────────────────────────────────────────

_resolve_phases_source() {
  # Sets: PHASES_FILE, WORKFLOW_ID, IS_PLAN_MODE
  case "$DISPATCH_MODE" in
    workflow)
      [ -z "$WF_NAME" ] && { echo "psk-dispatch.sh: workflow name required (e.g. 'release')" >&2; exit 2; }
      PHASES_FILE="$WORKFLOWS_DIR/$WF_NAME/phases.yml"
      WORKFLOW_ID="$WF_NAME"
      IS_PLAN_MODE=0
      ;;
    plan)
      # Locate dated plan file (same logic as psk-run-plan.sh _find_plan_file)
      PHASES_FILE=$(ls -1 "$PLANS_DIR"/[0-9]*-"$PLAN_SLUG".md 2>/dev/null | sort -r | head -1)
      [ -z "$PHASES_FILE" ] && PHASES_FILE=$(ls -1 "$PLANS_DIR/$PLAN_SLUG.md" 2>/dev/null | head -1)
      if [ -z "$PHASES_FILE" ]; then
        echo "plan not found for slug: $PLAN_SLUG (looked in $PLANS_DIR)" >&2
        exit 1
      fi
      WORKFLOW_ID="run-plan-$PLAN_SLUG"
      IS_PLAN_MODE=1
      ;;
    file)
      [ -z "$FILE_PATH" ] && { echo "psk-dispatch.sh: --phases-file path required" >&2; exit 2; }
      [ -z "$WF_ID_OVERRIDE" ] && { echo "psk-dispatch.sh: --workflow-id required with --phases-file" >&2; exit 2; }
      PHASES_FILE="$FILE_PATH"
      WORKFLOW_ID="$WF_ID_OVERRIDE"
      IS_PLAN_MODE=0
      ;;
    *)
      echo "unknown DISPATCH_MODE: $DISPATCH_MODE" >&2; exit 2 ;;
  esac
}

_load_state_paths() {
  STATE_FILE="$STATE_DIR/$WORKFLOW_ID.state"
  GATES_FILE="$STATE_DIR/$WORKFLOW_ID.gates"
  # Workflow verb string — used in user-facing SPAWN output
  if [ "$DISPATCH_MODE" = "plan" ]; then
    WORKFLOW_VERB="psk-dispatch.sh --plan $PLAN_SLUG"
  elif [ "$DISPATCH_MODE" = "file" ]; then
    WORKFLOW_VERB="psk-dispatch.sh --phases-file $FILE_PATH --workflow-id $WORKFLOW_ID"
  else
    WORKFLOW_VERB="psk-dispatch.sh $WF_NAME"
  fi
}

# Source workflow-specific env file if present.  Mechanical phases that
# compute dynamic values (e.g. reflex pass-init writes PASS_DIR) export them
# by writing to agent/.workflow-state/<workflow>.env; this loader picks them
# up so subsequent gate commands can reference those vars in subshells.
_reload_workflow_env() {
  local env_file="$STATE_DIR/${WORKFLOW_ID}.env"
  [ -f "$env_file" ] || return 0
  set -a
  # shellcheck source=/dev/null
  source "$env_file"
  set +a
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase parsing — workflow mode (phases.yml)
# ─────────────────────────────────────────────────────────────────────────────
#
# Parses YAML phases.yml without yq/python. Uses ASCII Unit Separator (\x1f)
# as delimiter — same choice as psk-run-plan.sh with identical rationale:
# non-whitespace, strict, does not collapse consecutive empty fields.
#
# Field order: id|name|spawn_type|prompt|artifact|command|gate|commit_required|depends_on

_parse_workflow_phases() {
  local file="$1"
  awk -v SEP=$'\x1f' '
    BEGIN {
      in_phases = 0; have = 0
      id = ""; name = ""; spawn_type = ""; prompt = ""; artifact = ""
      command = ""; gate = ""; commit_required = "false"; depends_on = ""
    }
    /^phases:[[:space:]]*$/ { in_phases = 1; next }
    in_phases && /^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]/ && !/^[[:space:]]/ {
      # Top-level key after phases: — phases array ended
      if (have) {
        printf "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n",
          id, SEP, name, SEP, spawn_type, SEP, prompt, SEP, artifact, SEP,
          command, SEP, gate, SEP, commit_required, SEP, depends_on
        have = 0
      }
      in_phases = 0
      next
    }
    in_phases && /^[[:space:]]*-[[:space:]]*id:/ {
      if (have) {
        printf "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n",
          id, SEP, name, SEP, spawn_type, SEP, prompt, SEP, artifact, SEP,
          command, SEP, gate, SEP, commit_required, SEP, depends_on
      }
      id = ""; name = ""; spawn_type = "sub-agent"; prompt = ""; artifact = ""
      command = ""; gate = "true"; commit_required = "false"; depends_on = ""
      have = 1
      sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, ""); gsub(/[[:space:]]*$/, "")
      id = $0
      next
    }
    in_phases && have && /^[[:space:]]+name:/ {
      sub(/^[[:space:]]+name:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, ""); gsub(/[[:space:]]*$/, "")
      name = $0; next
    }
    in_phases && have && /^[[:space:]]+spawn_type:/ {
      sub(/^[[:space:]]+spawn_type:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, ""); gsub(/[[:space:]]*$/, "")
      spawn_type = $0; next
    }
    in_phases && have && /^[[:space:]]+prompt:/ {
      sub(/^[[:space:]]+prompt:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, ""); gsub(/[[:space:]]*$/, "")
      prompt = $0; next
    }
    in_phases && have && /^[[:space:]]+artifact:/ {
      sub(/^[[:space:]]+artifact:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, ""); gsub(/[[:space:]]*$/, "")
      artifact = $0; next
    }
    in_phases && have && /^[[:space:]]+command:/ {
      sub(/^[[:space:]]+command:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, ""); gsub(/[[:space:]]*$/, "")
      command = $0; next
    }
    in_phases && have && /^[[:space:]]+gate:/ {
      sub(/^[[:space:]]+gate:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, ""); gsub(/[[:space:]]*$/, "")
      gate = $0; next
    }
    in_phases && have && /^[[:space:]]+commit_required:/ {
      sub(/^[[:space:]]+commit_required:[[:space:]]*/, "")
      gsub(/[[:space:]]*$/, "")
      commit_required = $0; next
    }
    in_phases && have && /^[[:space:]]+depends_on:/ {
      sub(/^[[:space:]]+depends_on:[[:space:]]*/, "")
      gsub(/^\[|\]$/, ""); gsub(/[[:space:]"]/, ""); gsub(/[[:space:]]*$/, "")
      depends_on = $0; next
    }
    END {
      if (have) {
        printf "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n",
          id, SEP, name, SEP, spawn_type, SEP, prompt, SEP, artifact, SEP,
          command, SEP, gate, SEP, commit_required, SEP, depends_on
      }
    }
  ' "$file"
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase parsing — plan mode (frontmatter phases:)
# ─────────────────────────────────────────────────────────────────────────────
#
# Verbatim copy-adapt of psk-run-plan.sh _parse_phases logic. Plan phases always
# treated as spawn_type:sub-agent (plan schema_version:1 has no spawn_type field).
# Field order: id|name|spawn_type|prompt|artifact||gate|commit_required|depends_on
# (command field always empty for plan phases)

_parse_plan_phases() {
  local file="$1"
  awk -v SEP=$'\x1f' '
    BEGIN { fm = 0; in_phases = 0; have = 0 }
    /^---$/ {
      fm++
      if (fm == 2) exit
      next
    }
    fm == 1 && /^phases:[[:space:]]*$/ { in_phases = 1; next }
    fm == 1 && in_phases && /^[A-Za-z_][A-Za-z0-9_]*:/ {
      in_phases = 0
    }
    fm == 1 && in_phases && /^[[:space:]]*-[[:space:]]*id:/ {
      if (have) {
        printf "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n",
          id, SEP, name, SEP, "sub-agent", SEP, prompt, SEP, artifact, SEP,
          "", SEP, gate, SEP, commit_required, SEP, depends_on
      }
      id = ""; name = ""; prompt = ""; artifact = ""; gate = ""; commit_required = "false"; depends_on = ""
      have = 1
      sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, ""); gsub(/[[:space:]]*$/, "")
      id = $0; next
    }
    fm == 1 && in_phases && have && /^[[:space:]]+name:/ {
      sub(/^[[:space:]]+name:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, ""); gsub(/[[:space:]]*$/, "")
      name = $0; next
    }
    fm == 1 && in_phases && have && /^[[:space:]]+prompt:/ {
      sub(/^[[:space:]]+prompt:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, ""); gsub(/[[:space:]]*$/, "")
      prompt = $0; next
    }
    fm == 1 && in_phases && have && /^[[:space:]]+artifact:/ {
      sub(/^[[:space:]]+artifact:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, ""); gsub(/[[:space:]]*$/, "")
      artifact = $0; next
    }
    fm == 1 && in_phases && have && /^[[:space:]]+gate:/ {
      sub(/^[[:space:]]+gate:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, ""); gsub(/[[:space:]]*$/, "")
      gate = $0; next
    }
    fm == 1 && in_phases && have && /^[[:space:]]+commit_required:/ {
      sub(/^[[:space:]]+commit_required:[[:space:]]*/, "")
      gsub(/[[:space:]]*$/, "")
      commit_required = $0; next
    }
    fm == 1 && in_phases && have && /^[[:space:]]+spawn_type:/ {
      # Plan phases may declare spawn_type for forward-compat; read but always sub-agent
      next
    }
    fm == 1 && in_phases && have && /^[[:space:]]+depends_on:/ {
      sub(/^[[:space:]]+depends_on:[[:space:]]*/, "")
      gsub(/^\[|\]$/, ""); gsub(/[[:space:]"]/, ""); gsub(/[[:space:]]*$/, "")
      depends_on = $0; next
    }
    END {
      if (have) {
        printf "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n",
          id, SEP, name, SEP, "sub-agent", SEP, prompt, SEP, artifact, SEP,
          "", SEP, gate, SEP, commit_required, SEP, depends_on
      }
    }
  ' "$file"
}

# ─────────────────────────────────────────────────────────────────────────────
# Unified phase table (dispatch to correct parser by mode)
# ─────────────────────────────────────────────────────────────────────────────

# Compat detection — a legacy plan declares `compat_mode: true` in frontmatter
# and carries NO `phases:` array (§Plan Execution Protocol migration policy).
# Same awk as cmd_validate's compat probe; extracted so cmd_init can run compat
# plans end-to-end (synthetic single phase) instead of erroring on empty phases.
_plan_is_compat() {
  local f="$1"
  [ -f "$f" ] || return 1
  local c
  c=$(awk '/^---$/ { fm++; if (fm==2) exit; next } fm==1 && /^compat_mode:/ { sub(/^[^:]+:[[:space:]]*/,""); print; exit }' "$f")
  [ "$c" = "true" ]
}

_parse_phases_table() {
  if [ "${IS_PLAN_MODE:-0}" = "1" ]; then
    local rows; rows=$(_parse_plan_phases "$PHASES_FILE")
    if [ -z "$rows" ] && _plan_is_compat "$PHASES_FILE"; then
      # Synthetic single phase for a legacy compat plan: prompt = the whole plan
      # file, artifact = derived .compat.done.md, gate = file exists. Mirrors
      # psk-run-plan.sh cmd_start's compat path so dispatch can run legacy plans
      # through the SAME psk-spawn.sh-routed driver (closes the §Spawn-Fidelity
      # gap run-plan's direct-echo path had). Artifact path is RELATIVE to
      # PROJ_ROOT — dispatch resolves artifacts as "$PROJ_ROOT/$artifact" and
      # runs gates from `cd "$PROJ_ROOT"`, so an absolute path would double-prefix.
      local art="agent/.workflow-state/$WORKFLOW_ID.compat.done.md"
      printf '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n' \
        "compat" "$SEP" "Compat (legacy single-phase)" "$SEP" "sub-agent" "$SEP" \
        "$PHASES_FILE" "$SEP" "$art" "$SEP" "" "$SEP" "test -f $art" "$SEP" "false" "$SEP" ""
    else
      printf '%s\n' "$rows"
    fi
  else
    _parse_workflow_phases "$PHASES_FILE"
  fi
}

_parse_phase_ids() {
  _parse_phases_table | while IFS="$SEP" read -r id _ _ _ _ _ _ _ _; do
    [ -n "$id" ] && echo "$id"
  done
}

_get_phase_row() {
  local want_id="$1"
  _parse_phases_table | awk -F"$SEP" -v want="$want_id" '$1 == want { print; exit }'
}

# ─────────────────────────────────────────────────────────────────────────────
# Schema validation
# ─────────────────────────────────────────────────────────────────────────────

_validate_workflow_schema() {
  local file="$1"
  local errs=0
  if [ ! -f "$file" ]; then
    echo "phases.yml not found: $file" >&2; return 2
  fi
  local has_schema
  has_schema=$(awk '/^schema_version:/ { print $2; exit }' "$file")
  if [ -z "$has_schema" ]; then
    echo "schema_version missing in: $file" >&2; errs=$((errs+1))
  fi
  local rows
  rows=$(_parse_workflow_phases "$file")
  if [ -z "$rows" ]; then
    echo "no phases parsed from: $file" >&2; return 2
  fi
  while IFS="$SEP" read -r id _ spawn_type prompt artifact command gate _ _; do
    [ -z "$id" ] && continue
    [ -z "$spawn_type" ] && { echo "phase $id: missing spawn_type" >&2; errs=$((errs+1)); }
    [ -z "$gate" ]       && { echo "phase $id: missing gate" >&2; errs=$((errs+1)); }
    case "$spawn_type" in
      sub-agent)
        [ -z "$prompt" ]   && { echo "phase $id: sub-agent phase missing prompt" >&2; errs=$((errs+1)); }
        [ -z "$artifact" ] && { echo "phase $id: sub-agent phase missing artifact" >&2; errs=$((errs+1)); }
        ;;
      mechanical)
        [ -z "$command" ] && { echo "phase $id: mechanical phase missing command" >&2; errs=$((errs+1)); }
        ;;
      manual-checkpoint)
        : # no extra fields required
        ;;
      *)
        echo "phase $id: unknown spawn_type '$spawn_type'" >&2; errs=$((errs+1)) ;;
    esac
  done <<EOF
$rows
EOF
  [ "$errs" -gt 0 ] && return 2
  return 0
}

_validate_plan_schema() {
  local file="$1"
  # Reuse psk-run-plan.sh schema validation logic inline
  local errs=0
  if ! grep -q '^schema_version:' "$file" 2>/dev/null; then
    echo "PSK024: missing schema_version in frontmatter — $file" >&2; errs=$((errs+1))
  fi
  local has_phases
  has_phases=$(awk '/^---$/ { fm++; if (fm==2) exit; next } fm==1 && /^phases:[[:space:]]*$/ { print "yes"; exit }' "$file")
  if [ -z "$has_phases" ]; then
    local compat
    compat=$(awk '/^---$/ { fm++; if (fm==2) exit; next } fm==1 && /^compat_mode:/ { sub(/^[^:]+:[[:space:]]*/,""); print; exit }' "$file")
    if [ "$compat" = "true" ]; then return 0; fi
    echo "PSK024: missing phases: block — $file" >&2; return 2
  fi
  local rows; rows=$(_parse_plan_phases "$file")
  [ -z "$rows" ] && { echo "PSK024: phases: block present but no phases parsed — $file" >&2; return 2; }
  while IFS="$SEP" read -r id _ _ prompt artifact _ gate _ _; do
    [ -z "$id" ]       && { echo "PSK024: phase missing id" >&2; errs=$((errs+1)); }
    [ -z "$prompt" ]   && { echo "PSK024: phase $id missing prompt" >&2; errs=$((errs+1)); }
    [ -z "$artifact" ] && { echo "PSK024: phase $id missing artifact" >&2; errs=$((errs+1)); }
    [ -z "$gate" ]     && { echo "PSK024: phase $id missing gate" >&2; errs=$((errs+1)); }
  done <<EOF
$rows
EOF
  [ "$errs" -gt 0 ] && return 2
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Dependency resolution
# ─────────────────────────────────────────────────────────────────────────────
#
# Returns first actionable phase: status not done/in_progress + all deps done.
# For sequential dispatch (D1), always returns one phase at a time.

_next_actionable_phase() {
  [ ! -f "$STATE_FILE" ] && return 1
  local rows; rows=$(_parse_phases_table)
  while IFS="$SEP" read -r id _ _ _ _ _ _ _ deps; do
    [ -z "$id" ] && continue
    local status; status=$(grep "^PHASE_${id}=" "$STATE_FILE" 2>/dev/null | head -1 | cut -d= -f2-)
    case "$status" in
      done|in_progress) continue ;;
    esac
    # Check all deps done
    local ok=1
    if [ -n "$deps" ]; then
      local old_IFS="$IFS"
      IFS=','
      for d in $deps; do
        [ -z "$d" ] && continue
        local dstatus
        dstatus=$(grep "^PHASE_${d}=" "$STATE_FILE" 2>/dev/null | head -1 | cut -d= -f2-)
        if [ "$dstatus" != "done" ]; then ok=0; break; fi
      done
      IFS="$old_IFS"
    fi
    if [ "$ok" -eq 1 ]; then echo "$id"; return 0; fi
  done <<EOF
$rows
EOF
  return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# D2 — Cross-phase parallel dispatch
# parallel_dispatch: see _dispatch_next_batch() and _identify_parallel_batch()
# wait_for_parallel_batch: see _dispatch_next_batch() wait loop
# ─────────────────────────────────────────────────────────────────────────────
#
# Config dial: max_parallel_phases in .portable-spec-kit/config.md (default 1).
# When max_parallel_phases=1 (or absent), dispatch is purely sequential —
# identical to D1 behaviour. When max_parallel_phases>1, phases whose
# depends_on graphs are disjoint (all deps done, status pending) are emitted
# as concurrent SPAWN signals. State-file writes use atomic mv via
# psk-workflow-state.sh — safe for concurrent bash & subshells on macOS/Linux.

_read_max_parallel_phases() {
  local cfg="$PROJ_ROOT/.portable-spec-kit/config.md"
  local val=1  # sequential default — safe when key absent
  if [ -f "$cfg" ]; then
    local v; v=$(grep -E '^max_parallel_phases:' "$cfg" | head -1 | awk '{print $2}')
    [[ "$v" =~ ^[0-9]+$ ]] && val="$v"
  fi
  echo "$val"
}

# _identify_parallel_batch — returns space-separated list of phase IDs ready
# to run concurrently right now.
#
# A phase is eligible when:
#   1. status is pending (not done, not in_progress, not AWAITING:*)
#   2. ALL its depends_on entries have status=done
#
# Sequential mode (max_parallel_phases=1): returns exactly one phase.
# Parallel mode (max_parallel_phases>1): returns up to cap phases.

_identify_parallel_batch() {
  local cap; cap=$(_read_max_parallel_phases)
  local batch="" count=0
  local rows; rows=$(_parse_phases_table)
  while IFS="$SEP" read -r id _ _ _ _ _ _ _ deps; do
    [ -z "$id" ] && continue
    local status; status=$(grep "^PHASE_${id}=" "$STATE_FILE" 2>/dev/null | head -1 | cut -d= -f2-)
    case "$status" in
      done|in_progress|AWAITING:*) continue ;;
    esac
    # Check all deps done
    local ok=1
    if [ -n "$deps" ]; then
      local old_IFS="$IFS"
      IFS=','
      for d in $deps; do
        [ -z "$d" ] && continue
        local dstatus
        dstatus=$(grep "^PHASE_${d}=" "$STATE_FILE" 2>/dev/null | head -1 | cut -d= -f2-)
        [ "$dstatus" != "done" ] && { ok=0; break; }
      done
      IFS="$old_IFS"
    fi
    if [ "$ok" -eq 1 ]; then
      batch="$batch $id"
      count=$((count+1))
      [ "$count" -ge "$cap" ] && break
    fi
  done <<EOF
$rows
EOF
  echo "${batch# }"   # trim leading space
}

# _verify_parallel_batch_artifacts — checks that every sub-agent phase in the
# given batch has written a non-empty artifact file. Returns 0 when all are
# present, 1 on any missing artifact.

_verify_parallel_batch_artifacts() {
  local batch="$1"
  local all_ok=1
  for phase_id in $batch; do
    local st; st=$(grep "^PHASE_${phase_id}=" "$STATE_FILE" 2>/dev/null | head -1 | cut -d= -f2-)
    # Only check sub-agent phases in AWAITING state
    case "$st" in
      AWAITING:SUBAGENT_SPAWN|AWAITING:SUBAGENT_RETRY) ;;
      *) continue ;;
    esac
    local row; row=$(_get_phase_row "$phase_id")
    local _id _name _spawn_type _prompt artifact _command _gate _cr _deps
    IFS="$SEP" read -r _id _name _spawn_type _prompt artifact _command _gate _cr _deps <<<"$row"
    if [ ! -s "$(_art_resolve "$artifact")" ]; then
      echo "✗ artifact missing for parallel phase $phase_id: $artifact" >&2
      all_ok=0
    fi
  done
  [ "$all_ok" -eq 1 ]
}

# _dispatch_next_batch — core parallel dispatch function.
#
# When count=1: delegates to single sequential path (_emit_spawn_for_phase).
# When count>1: emits SPAWN signals concurrently using bash & + wait.
#
# For sub-agent phases the SPAWN requests run concurrently (psk-spawn.sh request
# calls) and the function exits — the caller (main agent) spawns each sub-agent
# via Task tool, then calls `next` again. The next `next` call detects that all
# phases are AWAITING and verifies their artifacts before advancing.
#
# For mechanical phases, subshells run concurrently and wait for completion.
# Per-phase exit codes are tracked individually — batch failure identifies
# exactly which phases failed.

_dispatch_next_batch() {
  local batch; batch=$(_identify_parallel_batch)
  if [ -z "$batch" ]; then
    _handle_completion
    return
  fi

  local count; count=$(echo "$batch" | wc -w | tr -d ' ')

  if [ "$count" -eq 1 ]; then
    # Single phase — same sequential path as D1
    _emit_spawn_for_phase "$batch"
    return
  fi

  # Parallel batch — emit SPAWN for each phase concurrently
  echo "── parallel batch: $count phases ($batch) ──"
  local pids="" phase_ids=()

  for phase_id in $batch; do
    local row; row=$(_get_phase_row "$phase_id")
    [ -z "$row" ] && { echo "phase '$phase_id' not found in phases declaration" >&2; continue; }
    local _id _name spawn_type prompt artifact command gate _cr _deps
    IFS="$SEP" read -r _id _name spawn_type prompt artifact command gate _cr _deps <<<"$row"

    case "$spawn_type" in
      sub-agent)
        # Idempotency: skip if already AWAITING (don't re-request an already-requested spawn)
        local st; st=$(grep "^PHASE_${phase_id}=" "$STATE_FILE" 2>/dev/null | head -1 | cut -d= -f2-)
        if [[ "$st" == "pending" || -z "$st" ]]; then
          (
            bash "$STATE_SCRIPT" mark-awaiting "$WORKFLOW_ID" "$phase_id" "SUBAGENT_SPAWN" >/dev/null 2>&1
          ) &
          pids="$pids $!"
          phase_ids+=("$phase_id:sub-agent")
        fi
        ;;
      mechanical)
        (
          bash "$STATE_SCRIPT" mark-in-progress "$WORKFLOW_ID" "$phase_id" >/dev/null 2>&1 || true
          # eval-allowlist: mechanical phase command from phases.yml (kit-controlled, path-quoted via _quote_path_vars)
          ( cd "$PROJ_ROOT" && eval "$(_quote_path_vars "$command")" )
          local ec=$?
          if [ "$ec" -eq 0 ]; then
            _reload_workflow_env   # pick up vars a phase just wrote (e.g. PASS_DIR) so the gate sees them
            bash "$STATE_SCRIPT" verify-gate "$WORKFLOW_ID" "$phase_id" >/dev/null 2>&1 || true
            bash "$STATE_SCRIPT" mark-done "$WORKFLOW_ID" "$phase_id" >/dev/null 2>&1 || true
          else
            echo "✗ mechanical phase $phase_id failed (exit $ec)" >&2
          fi
          exit "$ec"
        ) &
        pids="$pids $!"
        phase_ids+=("$phase_id:mechanical")
        ;;
      manual-checkpoint)
        # Manual checkpoints are not parallelisable — pause immediately
        echo "Manual checkpoint in parallel batch: $phase_id"
        bash "$STATE_SCRIPT" mark-awaiting "$WORKFLOW_ID" "$phase_id" "MANUAL_CHECKPOINT" >/dev/null 2>&1 || true
        ;;
    esac
  done

  # Wait for all parallel subshells; track per-phase exit codes
  local failed_phases=""
  local idx=0
  for pid in $pids; do
    wait "$pid"; local ec=$?
    local ph_entry="${phase_ids[$idx]:-unknown}"
    if [ "$ec" -ne 0 ]; then
      failed_phases="$failed_phases ${ph_entry}(exit $ec)"
    fi
    idx=$((idx+1))
  done

  if [ -n "$failed_phases" ]; then
    echo "✗ parallel batch failed on:$failed_phases" >&2
    exit 1
  fi

  echo "── parallel batch state-requests complete ──"

  # For sub-agent phases: all spawns are now AWAITING — emit SPAWN messages for
  # each so the main agent knows to launch Task tool sub-agents concurrently.
  # For mechanical phases: they are done — advance to next batch.
  local has_sub_agent=0
  for ph_entry in "${phase_ids[@]:-}"; do
    [[ "$ph_entry" == *":sub-agent" ]] && { has_sub_agent=1; break; }
  done

  if [ "$has_sub_agent" -eq 1 ]; then
    echo ""
    echo "  AWAITING_SUBAGENT_BATCH — workflow '$WORKFLOW_ID' paused for parallel batch:"
    echo "  Phases: $batch"
    echo ""
    echo "  MAIN AGENT PROTOCOL (mandatory — no inline alternative):"
    echo "  1. Spawn ALL of the following sub-agents concurrently (Task tool calls in same turn):"
    for ph_entry in "${phase_ids[@]:-}"; do
      [[ "$ph_entry" != *":sub-agent" ]] && continue
      local ph_id="${ph_entry%%:*}"
      local ph_row; ph_row=$(_get_phase_row "$ph_id")
      local _i _n _st ph_prompt ph_artifact _c _g _cr _d
      IFS="$SEP" read -r _i _n _st ph_prompt ph_artifact _c _g _cr _d <<<"$ph_row"
      local ph_model; ph_model=$(_resolve_spawn_model "$ph_id")
      echo "     Phase $ph_id: prompt=$ph_prompt artifact=$ph_artifact MODEL=$ph_model"
    done
    echo "  2. Pass each phase's MODEL (above) to its Task/Agent tool spawn — kit model-policy (cost/perf), not the session default."
    echo "  3. After ALL sub-agents complete, call: $WORKFLOW_VERB next"
    echo "  4. On any failure: $WORKFLOW_VERB retry"
    exit 0
  fi

  # All mechanical — advance to next batch
  echo "── all mechanical phases complete — advancing ──"
  _dispatch_next_batch
}

# ─────────────────────────────────────────────────────────────────────────────
# SPAWN emit
# ─────────────────────────────────────────────────────────────────────────────

# Resolve the model-policy model for a phase — PARITY with psk-spawn.sh
# (KIT-GAP / cycle-01/pass-002). The dispatcher's generic _emit_spawn + its
# parallel-batch protocol set AWAITING state directly (bypassing psk-spawn.sh),
# so driverless workflow-phase spawns never surfaced the policy model and silently
# inherited the driver's model. Resolve here so EVERY dispatcher spawn surface pins
# the model the same way psk-spawn.sh does. Echoes opus|sonnet|haiku|fable|inherit.
_resolve_spawn_model() {
  local phase_id="$1"
  local mp="$PROJ_ROOT/agent/scripts/psk-model-policy.sh"
  local m="inherit"
  if [ -f "$mp" ]; then
    m=$(bash "$mp" lookup "$phase_id" "$WORKFLOW_ID" 2>/dev/null || echo inherit)
    [ -z "$m" ] && m="inherit"
  fi
  printf '%s' "$m"
}

_emit_spawn() {
  local phase_id="$1" prompt="$2" artifact="$3" gate="$4"
  local spawn_model; spawn_model=$(_resolve_spawn_model "$phase_id")
  echo "SPAWN: phase=$phase_id prompt=$prompt artifact=$artifact gate=$gate"
  echo "MODEL=$spawn_model"
  echo ""
  echo "  AWAITING_SUBAGENT — workflow '$WORKFLOW_ID' paused at phase '$phase_id'"
  echo ""
  echo "  MAIN AGENT PROTOCOL (mandatory — no inline alternative):"
  echo "  1. Read prompt: $prompt"
  if [ "$spawn_model" = "inherit" ]; then
    echo "  2. Spawn sub-agent (Task tool) with that exact prompt (MODEL: inherit — current session model)"
  else
    echo "  2. Spawn sub-agent (Task tool) with that exact prompt — set model=$spawn_model on the Task/Agent tool"
    echo "       (kit model-policy, cost/perf; do NOT default to the session model — the policy chose $spawn_model on purpose)"
  fi
  echo "  3. Sub-agent writes its artifact to: $artifact"
  echo "  4. Then call: $WORKFLOW_VERB next   (verifies artifact + runs gate + advances)"
  echo "  5. On sub-agent failure / rate-limit: $WORKFLOW_VERB retry"
}

# ─────────────────────────────────────────────────────────────────────────────
# Gate verification and advance
# ─────────────────────────────────────────────────────────────────────────────

_verify_gate_and_advance() {
  local phase="$1" gate="$2"
  if ! bash "$STATE_SCRIPT" verify-gate "$WORKFLOW_ID" "$phase" 2>&1; then
    echo "✗ gate failed for phase $phase — not advancing"
    echo "  Gate command: $gate"
    exit 3
  fi
  if ! bash "$STATE_SCRIPT" mark-done "$WORKFLOW_ID" "$phase" 2>&1; then
    echo "✗ gate verified but mark-done refused for phase $phase" >&2
    exit 3
  fi
  # Use _dispatch_next_batch so parallel-eligible phases are emitted concurrently
  _dispatch_next_batch
}

_handle_completion() {
  if bash "$STATE_SCRIPT" "complete?" "$WORKFLOW_ID" >/dev/null 2>&1; then
    echo "COMPLETE — workflow '$WORKFLOW_ID' all phases done."
    exit 0
  fi
  echo "no next actionable phase but workflow not complete — dependency stuck?" >&2
  bash "$STATE_SCRIPT" status "$WORKFLOW_ID" >&2 || true
  exit 1
}

_emit_spawn_for_phase() {
  local phase_id="$1"
  local row; row=$(_get_phase_row "$phase_id")
  [ -z "$row" ] && { echo "phase '$phase_id' not found in phases declaration" >&2; exit 1; }
  local _id _name spawn_type prompt artifact command gate commit_required deps
  IFS="$SEP" read -r _id _name spawn_type prompt artifact command gate commit_required deps <<<"$row"

  case "$spawn_type" in
    sub-agent)
      # Spawn-driver phases: a sub-agent phase MAY declare a `command` that is its
      # spawn DRIVER (e.g. reflex qa-spawn → reflex/lib/spawn-qa.sh, dev-spawn →
      # spawn-dev.sh). The driver does the reflex-specific setup the generic emit
      # can't — creates the isolated git worktree / dev branch, writes the dynamic
      # task file, routes through psk-spawn.sh — then signals AWAITING via exit 2.
      # Without this, the v0.6.63 migration left qa-spawn/dev-spawn with no sandbox
      # worktree / dev branch (RLX-9). exit-2-as-pause is scoped to THIS sub-agent
      # branch, so mechanical phases (e.g. file-bugs.sh exit 2 = real failure) are
      # unaffected.
      if [ -n "${command:-}" ]; then
        bash "$STATE_SCRIPT" mark-in-progress "$WORKFLOW_ID" "$phase_id" >/dev/null 2>&1 || true
        local _drv; _drv=$(_quote_path_vars "$command")
        # eval-allowlist: plan driver command from phases.yml (kit-controlled, path-quoted)
        ( cd "$PROJ_ROOT" && eval "$_drv" )
        local drv_exit=$?
        if [ "$drv_exit" -eq 2 ]; then
          # Driver set up the worktree/branch + task file and signalled AWAITING.
          # Mark the dispatcher's phase AWAITING:SUBAGENT_SPAWN so cmd_next's
          # advance path recognises it on re-entry (not left as in_progress).
          bash "$STATE_SCRIPT" mark-awaiting "$WORKFLOW_ID" "$phase_id" "SUBAGENT_SPAWN" >/dev/null 2>&1 || true
          exit 0
        fi
        if [ "$drv_exit" -ne 0 ]; then
          echo "✗ spawn driver failed (exit $drv_exit) for phase $phase_id" >&2
          echo "  Command: $command" >&2
          exit 1
        fi
        # Driver exited 0 without pausing — fall through to the generic emit.
      fi
      bash "$STATE_SCRIPT" mark-awaiting "$WORKFLOW_ID" "$phase_id" "SUBAGENT_SPAWN" >/dev/null
      _emit_spawn "$phase_id" "$prompt" "$artifact" "$gate"
      exit 0
      ;;
    mechanical)
      # Idempotency for sub-agent phases is enforced by psk-spawn.sh's GATE_PASSED check.
      # D3's _check_mechanical_skip() does NOT apply to sub-agent phases.
      if _check_mechanical_skip "$phase_id" "${artifact:-}"; then
        echo "⏩ skip: mechanical phase $phase_id gate already passed — advancing"
        bash "$STATE_SCRIPT" mark-done "$WORKFLOW_ID" "$phase_id" >/dev/null
        _dispatch_next_batch
        return
      fi
      bash "$STATE_SCRIPT" mark-in-progress "$WORKFLOW_ID" "$phase_id" >/dev/null 2>&1 || true
      # Quote path variables that may contain spaces so eval word-splits correctly.
      local _cmd; _cmd=$(_quote_path_vars "$command")
      # eval-allowlist: mechanical phase command from phases.yml (kit-controlled, path-quoted)
      ( cd "$PROJ_ROOT" && eval "$_cmd" )
      local cmd_exit=$?
      if [ "$cmd_exit" -ne 0 ]; then
        echo "✗ mechanical command failed (exit $cmd_exit) for phase $phase_id" >&2
        echo "  Command: $command" >&2
        exit 1
      fi
      _reload_workflow_env
      _verify_gate_and_advance "$phase_id" "$gate"
      ;;
    manual-checkpoint)
      echo "Manual checkpoint: $phase_id"
      echo "  This phase requires operator confirmation before proceeding."
      echo "  After completing the work, run: $WORKFLOW_VERB next"
      bash "$STATE_SCRIPT" mark-awaiting "$WORKFLOW_ID" "$phase_id" "MANUAL_CHECKPOINT" >/dev/null 2>&1 || true
      exit 0
      ;;
    *)
      echo "Unknown spawn_type '$spawn_type' for phase $phase_id" >&2
      exit 1
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Run-state file (per-workflow, for retry counter + current phase tracking)
# ─────────────────────────────────────────────────────────────────────────────

_run_state_file() { echo "$STATE_DIR/$WORKFLOW_ID.dispatch.run"; }

_run_state_init() {
  mkdir -p "$STATE_DIR"
  local rf; rf=$(_run_state_file)
  {
    echo "WORKFLOW_ID=$WORKFLOW_ID"
    echo "DISPATCH_MODE=$DISPATCH_MODE"
    echo "PHASES_FILE=$PHASES_FILE"
    echo "STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "CURRENT_PHASE="
    echo "RETRIES=0"
    # Plan-mode compatibility: psk-run-plan.sh (thin router → this dispatcher)
    # reads SLUG= / PLAN_FILE= / COMPAT_MODE= from the .run file for its
    # status/health/slug-inference. Write them so a run-plan-delegated plan's
    # state is readable by both drivers (they share the .run path).
    if [ "$IS_PLAN_MODE" = "1" ]; then
      echo "SLUG=${PLAN_SLUG:-${WORKFLOW_ID#run-plan-}}"
      echo "PLAN_FILE=$PHASES_FILE"
      if _plan_is_compat "$PHASES_FILE"; then echo "COMPAT_MODE=true"; else echo "COMPAT_MODE=false"; fi
    fi
  } > "$rf"
}

_run_state_set() {
  local key="$1" val="$2"
  local rf; rf=$(_run_state_file)
  [ ! -f "$rf" ] && return 0
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
  local key="$1"
  local rf; rf=$(_run_state_file)
  [ ! -f "$rf" ] && echo "" && return 0
  grep "^${key}=" "$rf" | head -1 | cut -d= -f2-
}

# ─────────────────────────────────────────────────────────────────────────────
# Bypass logging
# ─────────────────────────────────────────────────────────────────────────────

_log_bypass() {
  local env_var="$1" cmd_summary="$2"
  if [ -x "$BYPASS_LOG_SCRIPT" ]; then
    bash "$BYPASS_LOG_SCRIPT" log \
      --env-var "$env_var" \
      --command "$cmd_summary" \
      --justification "${PSK_BYPASS_REASON:-not provided}" 2>/dev/null || true
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# D3 — Mechanical phase idempotency skip
# mechanical_skip_if_gate_passed: implemented as _check_mechanical_skip()
#
# Returns 0 (skip the mechanical command) when:
#   1. PSK_IDEMPOTENCY_DISABLED is not set to 1
#   2. GATE_PASSED_<phase_id>=<unix-ts> exists in the state file
#   3. If an artifact path is given, the artifact file exists and its mtime >= gate_ts
#
# Returns 1 (do NOT skip — run the command as normal) in all other cases.
#
# Portability: macOS uses `stat -f '%m'`; Linux uses `stat -c '%Y'`.
# Fallback `echo 0` covers unusual environments — better to re-run than to skip.
# Sub-agent phases: D3 does NOT touch sub-agent phases. Their idempotency is
# handled by psk-spawn.sh's GATE_PASSED check. This function is mechanical-only.
# ─────────────────────────────────────────────────────────────────────────────

_check_mechanical_skip() {
  local phase_id="$1" artifact_path="$2"

  # Honor bypass flag — if set, log it and return 1 (do not skip)
  if [ "${PSK_IDEMPOTENCY_DISABLED:-0}" = "1" ]; then
    bash "$BYPASS_LOG_SCRIPT" log \
      --env-var "PSK_IDEMPOTENCY_DISABLED" \
      --command "psk-dispatch.sh (--force on mechanical phase ${phase_id:-unknown})" \
      --justification "${PSK_BYPASS_REASON:-operator force-run}" 2>/dev/null || true
    return 1
  fi

  # Check for GATE_PASSED_<phase_id> marker in the state file
  [ ! -f "${STATE_FILE:-}" ] && return 1
  local gate_ts
  gate_ts=$(grep "^GATE_PASSED_${phase_id}=" "$STATE_FILE" | head -1 | cut -d= -f2-)
  [ -z "$gate_ts" ] && return 1

  # If an artifact path is provided, verify it exists and is fresh (mtime >= gate_ts)
  if [ -n "$artifact_path" ] && [ "$artifact_path" != "none" ]; then
    local full_artifact="$(_art_resolve "$artifact_path")"
    if [ ! -s "$full_artifact" ]; then return 1; fi
    local artifact_mtime
    artifact_mtime=$(stat -f '%m' "$full_artifact" 2>/dev/null \
                  || stat -c '%Y' "$full_artifact" 2>/dev/null \
                  || echo 0)
    if [ "$artifact_mtime" -lt "$gate_ts" ]; then return 1; fi
  fi

  # All checks passed — the gate already passed and the artifact is fresh
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Commands
# ─────────────────────────────────────────────────────────────────────────────

cmd_validate() {
  # Schema-check phases.yml without running (exit 0/2)
  [ ! -f "$PHASES_FILE" ] && { echo "phases file not found: $PHASES_FILE" >&2; exit 2; }
  if [ "${IS_PLAN_MODE:-0}" = "1" ]; then
    if _validate_plan_schema "$PHASES_FILE"; then
      echo "✓ plan schema valid: $PHASES_FILE"
      exit 0
    else
      echo "✗ plan schema invalid: $PHASES_FILE" >&2
      exit 2
    fi
  else
    if _validate_workflow_schema "$PHASES_FILE"; then
      echo "✓ workflow schema valid: $PHASES_FILE"
      exit 0
    else
      echo "✗ workflow schema invalid: $PHASES_FILE" >&2
      exit 2
    fi
  fi
}

cmd_init() {
  # Register workflow with psk-workflow-state.sh (idempotent)
  [ ! -f "$PHASES_FILE" ] && { echo "phases file not found: $PHASES_FILE" >&2; exit 1; }
  local ids
  ids=$(_parse_phase_ids | tr '\n' ',' | sed 's/,$//')
  [ -z "$ids" ] && { echo "no phases found in: $PHASES_FILE" >&2; exit 1; }
  bash "$STATE_SCRIPT" init "$WORKFLOW_ID" "$ids" >/dev/null
  # Register each phase's gate
  local rows; rows=$(_parse_phases_table)
  while IFS="$SEP" read -r id _ _ _ _ _ gate _ _; do
    [ -z "$id" ] && continue
    [ -n "$gate" ] && bash "$STATE_SCRIPT" register-gate "$WORKFLOW_ID" "$id" "$gate" >/dev/null
  done <<EOF
$rows
EOF
  _run_state_init
  # G28 (QA-D26-002): retire a pre-v0.6.62 legacy state orphan. Before the dispatcher
  # migration, workflows wrote `psk-<name>.state` (e.g. psk-release.state); the canonical
  # name is now `<name>.state` (release.state). A leftover legacy orphan — often a malformed
  # single-line collapse of all PHASE_ steps — can confuse psk-workflow-watchdog.sh. Now that
  # the canonical state exists, archive the legacy orphan to `.superseded` (same convention the
  # watchdog uses). Generic: fires for ANY workflow that migrated across the dispatcher boundary.
  local _legacy_orphan="$STATE_DIR/psk-${WORKFLOW_ID}.state"
  if [ -f "$_legacy_orphan" ] && [ -f "$STATE_DIR/${WORKFLOW_ID}.state" ]; then
    mv -f "$_legacy_orphan" "${_legacy_orphan}.superseded" 2>/dev/null \
      && echo "✓ psk-dispatch: archived legacy orphan psk-${WORKFLOW_ID}.state → .superseded"
  fi
  echo "✓ psk-dispatch: initialized workflow $WORKFLOW_ID"
  # return (not exit) so cmd_next's auto-init path falls through to dispatch the
  # first phase. The explicit `init` verb ends the script anyway (case is last).
  # Pre-v0.6.63 reflex ran phases after init; `exit 0` here regressed that —
  # `reflex/run.sh single` would init the workflow then stop without running.
  return 0
}

cmd_next() {
  # Advance: verify artifact (if sub-agent) → run gate → mark-done → SPAWN next
  [ ! -f "$PHASES_FILE" ] && { echo "phases file not found: $PHASES_FILE" >&2; exit 1; }

  # If not yet initialized, init first
  if [ ! -f "$STATE_FILE" ]; then
    echo "workflow '$WORKFLOW_ID' not initialized — running init first" >&2
    cmd_init
  fi

  # Collect all AWAITING/in_progress phases (parallel batch may have multiple)
  local all_awaiting; all_awaiting=$(grep -E '^PHASE_.*=AWAITING:|^PHASE_.*=in_progress' "$STATE_FILE" 2>/dev/null | sed 's/^PHASE_//; s/=.*//')
  local current; current=$(echo "$all_awaiting" | head -1)

  # If no AWAITING/in_progress phase, find next actionable batch (may be parallel)
  if [ -z "$current" ]; then
    _dispatch_next_batch
    return
  fi

  # Parallel batch return — when multiple phases are AWAITING simultaneously,
  # verify all their artifacts and advance each before dispatching next batch.
  local awaiting_count; awaiting_count=$(echo "$all_awaiting" | grep -c '[^[:space:]]' || echo 0)
  if [ "$awaiting_count" -gt 1 ]; then
    local batch_str; batch_str=$(echo "$all_awaiting" | tr '\n' ' ' | sed 's/[[:space:]]*$//')
    # Verify all artifacts in the parallel batch
    if ! _verify_parallel_batch_artifacts "$batch_str"; then
      echo "✗ parallel batch artifact check failed — not all sub-agents have completed" >&2
      echo "  Batch: $batch_str" >&2
      echo "  → $WORKFLOW_VERB retry   then spawn missing sub-agents again" >&2
      exit 1
    fi
    # Advance all phases in the batch
    for ph in $batch_str; do
      [ -z "$ph" ] && continue
      local ph_row; ph_row=$(_get_phase_row "$ph")
      [ -z "$ph_row" ] && continue
      local _i _n _st _pr _ar _cmd ph_gate _cr _dp
      IFS="$SEP" read -r _i _n _st _pr _ar _cmd ph_gate _cr _dp <<<"$ph_row"
      if ! bash "$STATE_SCRIPT" verify-gate "$WORKFLOW_ID" "$ph" 2>&1; then
        echo "✗ gate failed for parallel phase $ph — not advancing batch" >&2
        exit 3
      fi
      bash "$STATE_SCRIPT" mark-done "$WORKFLOW_ID" "$ph" >/dev/null 2>&1 || true
    done
    _run_state_set RETRIES 0
    echo "── parallel batch all phases verified and advanced ──"
    _dispatch_next_batch
    return
  fi

  # HF4b idempotency outer safety net (single phase path)
  if [ "${PSK_IDEMPOTENCY_DISABLED:-0}" != "1" ]; then
    if grep -q "^GATE_PASSED_${current}=" "$STATE_FILE" 2>/dev/null; then
      local gp_ts
      gp_ts=$(grep "^GATE_PASSED_${current}=" "$STATE_FILE" | head -1 | cut -d= -f2-)
      echo "Phase $current already complete (gate passed at $gp_ts). Advancing."
      bash "$STATE_SCRIPT" mark-done "$WORKFLOW_ID" "$current" >/dev/null 2>&1 || true
      _run_state_set RETRIES 0
      _dispatch_next_batch
      return
    fi
  else
    _log_bypass "PSK_IDEMPOTENCY_DISABLED" "$WORKFLOW_VERB next"
  fi

  # Read current phase row
  local row; row=$(_get_phase_row "$current")
  [ -z "$row" ] && { echo "phase '$current' not found in phases declaration" >&2; exit 1; }
  local _id _name spawn_type prompt artifact command gate commit_required deps
  IFS="$SEP" read -r _id _name spawn_type prompt artifact command gate commit_required deps <<<"$row"

  case "$spawn_type" in
    sub-agent)
      # Detect first vs advance call by checking phase status
      local phase_status
      phase_status=$(grep "^PHASE_${current}=" "$STATE_FILE" 2>/dev/null | head -1 | cut -d= -f2-)
      if [[ "$phase_status" == "pending" || -z "$phase_status" ]]; then
        # First call — emit SPAWN, do not verify artifact yet
        bash "$STATE_SCRIPT" mark-awaiting "$WORKFLOW_ID" "$current" "SUBAGENT_SPAWN" >/dev/null
        _emit_spawn "$current" "$prompt" "$artifact" "$gate"
        exit 0
      fi
      if [[ "$phase_status" == "AWAITING:SUBAGENT_SPAWN" || "$phase_status" == "AWAITING:SUBAGENT_RETRY" ]]; then
        # Second call — artifact should exist; verify and advance.
        # Reflex artifact paths carry a `pass-NNN` placeholder (e.g.
        # reflex/history/cycle-NN/pass-NNN/qa-result.md); resolve it to the real
        # pass dir ($PASS_DIR, set by pass-init) instead of the literal placeholder.
        local _art_abs="$(_art_resolve "$artifact")"
        case "$artifact" in
          *pass-NNN*) [ -n "${PASS_DIR:-}" ] && _art_abs="$PASS_DIR/$(basename "$artifact")" ;;
        esac
        if [ ! -s "$_art_abs" ]; then
          echo "✗ artifact missing or empty for phase '$current': $_art_abs" >&2
          echo "  sub-agent did not finish — do NOT mark done" >&2
          echo "  → $WORKFLOW_VERB retry   then spawn again" >&2
          exit 1
        fi
        _verify_gate_and_advance "$current" "$gate"
      fi
      ;;
    mechanical)
      # Idempotency for sub-agent phases is enforced by psk-spawn.sh's GATE_PASSED check.
      # D3's _check_mechanical_skip() does NOT apply to sub-agent phases.
      if _check_mechanical_skip "$current" "${artifact:-}"; then
        echo "⏩ skip: mechanical phase $current gate already passed — advancing"
        bash "$STATE_SCRIPT" mark-done "$WORKFLOW_ID" "$current" >/dev/null
        _run_state_set RETRIES 0
        _dispatch_next_batch
        return
      fi
      bash "$STATE_SCRIPT" mark-in-progress "$WORKFLOW_ID" "$current" >/dev/null 2>&1 || true
      local _cmd; _cmd=$(_quote_path_vars "$command")
      # eval-allowlist: mechanical phase command from phases.yml (kit-controlled, path-quoted)
      ( cd "$PROJ_ROOT" && eval "$_cmd" )
      local cmd_exit=$?
      if [ "$cmd_exit" -ne 0 ]; then
        echo "✗ mechanical command failed (exit $cmd_exit) for phase $current" >&2
        echo "  Command: $command" >&2
        exit 1
      fi
      _reload_workflow_env
      _verify_gate_and_advance "$current" "$gate"
      ;;
    manual-checkpoint)
      echo "Manual checkpoint: $current"
      echo "  This phase requires operator confirmation before proceeding."
      echo "  After completing the work, run: $WORKFLOW_VERB next"
      bash "$STATE_SCRIPT" mark-awaiting "$WORKFLOW_ID" "$current" "MANUAL_CHECKPOINT" >/dev/null 2>&1 || true
      exit 0
      ;;
    *)
      echo "Unknown spawn_type '$spawn_type' for phase $current" >&2; exit 1 ;;
  esac
}

cmd_status() {
  if [ ! -f "$STATE_FILE" ]; then
    echo "workflow '$WORKFLOW_ID' not initialized (no state file)"
    exit 1
  fi
  bash "$STATE_SCRIPT" status "$WORKFLOW_ID" 2>/dev/null || echo "(workflow state machine reports no entry)"
  local rf; rf=$(_run_state_file)
  if [ -f "$rf" ]; then
    echo ""
    echo "── dispatch run-state ──"
    cat "$rf"
  fi
  exit 0
}

cmd_resume() {
  # Re-emit SPAWN for current paused phase (for sub-agent phases)
  [ ! -f "$STATE_FILE" ] && { echo "workflow '$WORKFLOW_ID' not initialized" >&2; exit 1; }
  local current; current=$(grep -E '^PHASE_.*=AWAITING:' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/^PHASE_//; s/=.*//')
  if [ -z "$current" ]; then
    echo "no AWAITING phase found for '$WORKFLOW_ID' — nothing to resume"
    exit 0
  fi
  local row; row=$(_get_phase_row "$current")
  [ -z "$row" ] && { echo "phase '$current' not found in phases declaration" >&2; exit 1; }
  local _id _name spawn_type prompt artifact command gate _ _
  IFS="$SEP" read -r _id _name spawn_type prompt artifact command gate _ _ <<<"$row"
  echo "── resume: re-emitting SPAWN for phase '$current' ──"
  _emit_spawn "$current" "$prompt" "$artifact" "$gate"
  exit 0
}

cmd_retry() {
  # Re-emit SPAWN, increment retry counter; cap 3 → AWAITING_HUMAN_ARBITRATION
  [ ! -f "$STATE_FILE" ] && { echo "workflow '$WORKFLOW_ID' not initialized" >&2; exit 1; }

  local retries; retries=$(_run_state_get RETRIES)
  [ -z "$retries" ] && retries=0
  retries=$((retries+1))
  _run_state_set RETRIES "$retries"

  if [ "$retries" -gt "$RETRY_CAP" ]; then
    echo "⛔ AWAITING_HUMAN_ARBITRATION — retry cap ($RETRY_CAP) exceeded for workflow '$WORKFLOW_ID'" >&2
    echo "  The sub-agent has failed $retries times on the same phase." >&2
    echo "  Forward path requires explicit operator decision." >&2
    exit 4
  fi

  local current; current=$(grep -E '^PHASE_.*=AWAITING:' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/^PHASE_//; s/=.*//')
  [ -z "$current" ] && { echo "no AWAITING phase found for '$WORKFLOW_ID'" >&2; exit 1; }

  local row; row=$(_get_phase_row "$current")
  [ -z "$row" ] && { echo "phase '$current' not found in phases declaration" >&2; exit 1; }
  local _id _name spawn_type prompt artifact command gate _ _
  IFS="$SEP" read -r _id _name spawn_type prompt artifact command gate _ _ <<<"$row"

  bash "$STATE_SCRIPT" mark-awaiting "$WORKFLOW_ID" "$current" "SUBAGENT_RETRY" >/dev/null 2>&1 || true
  echo "── retry $retries/$RETRY_CAP for phase '$current' ──"
  _emit_spawn "$current" "$prompt" "$artifact" "$gate"
  exit 0
}

cmd_done() {
  # Mark workflow complete
  echo "✓ workflow '$WORKFLOW_ID' marked complete"
  local rf; rf=$(_run_state_file)
  [ -f "$rf" ] && _run_state_set CURRENT_PHASE "" || true
  exit 0
}

cmd_abandon() {
  # Mark workflow abandoned
  local sf="$STATE_FILE"
  local rf; rf=$(_run_state_file)
  if [ -f "$sf" ]; then mv "$sf" "$sf.abandoned.$(date +%s)"; fi
  [ -f "$rf" ] && mv "$rf" "$rf.abandoned.$(date +%s)"
  echo "✗ abandoned workflow '$WORKFLOW_ID'"
  exit 0
}

cmd_list() {
  if [ "$DISPATCH_MODE" = "workflow" ]; then
    # Read .portable-spec-kit/workflows/_audit.yml
    if [ -f "$AUDIT_YML" ]; then
      grep -E '^\s+- name:' "$AUDIT_YML" | sed 's/.*name:[[:space:]]*/  /'
    else
      echo "  (no _audit.yml found at $AUDIT_YML)"
    fi
  else
    # List all agent/plans/*.md files with status from frontmatter
    local found=0
    for f in "$PLANS_DIR"/[0-9]*.md "$PLANS_DIR"/*.md; do
      [ -f "$f" ] || continue
      found=1
      local slug; slug=$(awk '/^slug:/{print $2}' "$f" | head -1)
      local status; status=$(awk '/^status:/{print $2}' "$f" | head -1)
      [ -n "$slug" ] && printf '  %-40s %s\n' "$slug" "${status:-(no status)}"
    done
    [ "$found" -eq 0 ] && echo "  (no plans found in $PLANS_DIR)"
  fi
  exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Main dispatch
# ─────────────────────────────────────────────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Deferred --validate: handle after all functions are defined.
  # Set target into the right variable before resolving.
  if [ -n "${_DEFERRED_VALIDATE:-}" ]; then
    case "$DISPATCH_MODE" in
      workflow) WF_NAME="$_DEFERRED_VALIDATE" ;;
      plan)     PLAN_SLUG="$_DEFERRED_VALIDATE" ;;
    esac
  fi

  _resolve_phases_source
  _load_state_paths
  _reload_workflow_env

  if [ -n "${_DEFERRED_VALIDATE:-}" ]; then
    cmd_validate
    exit $?
  fi

  case "$VERB" in
    init)    cmd_init ;;
    next)    cmd_next ;;
    status)  cmd_status ;;
    resume)  cmd_resume ;;
    retry)   cmd_retry ;;
    done)    cmd_done ;;
    abandon) cmd_abandon ;;
    list)    cmd_list ;;
    *)       echo "Unknown verb: $VERB" >&2; echo "Run with --help for usage" >&2; exit 2 ;;
  esac
fi
