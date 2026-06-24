#!/usr/bin/env bash
# psk-behavior-parity.sh — Baseline + parity-diff probe for Class B workflows.
# doc-coverage-exempt: internal mechanical helper — no user-facing R->F->T claim
#
# mechanical-script: deterministic baseline-diff probe; no AI invocation
# workflow-role: gate for A3-A6 retrofits of unified-workflow-declarations (v0.6.62)
#
# Captures and diffs behavioral baselines for the 8 Class B legacy workflows.
# The baselines are the ground truth that the unified-workflow-declarations
# retrofits (A3-A6) must match — bit-for-bit, structurally.
#
# CLI:
#   bash agent/scripts/psk-behavior-parity.sh <workflow>          — run parity check
#   bash agent/scripts/psk-behavior-parity.sh <workflow> --regenerate
#                                                                  — overwrite baseline (admin override)
#   bash agent/scripts/psk-behavior-parity.sh --all                — check all 8 workflows
#   bash agent/scripts/psk-behavior-parity.sh --list               — show baseline status
#
# Strategy: static-analysis. Each workflow's behavior is derived from:
#   1. register-gate calls in the workflow script (phase enumeration)
#   2. psk-spawn.sh / psk-critic-spawn.sh / spawn-qa.sh / spawn-dev.sh /
#      await_subagent invocations (spawn call sequence)
#   3. files_modified declared in .portable-spec-kit/workflows/_audit.yml
#   4. exit-code points (per-phase pass/fail signals)
#
# This way the baseline can be re-derived deterministically at any time, and
# retrofit-time comparison is meaningful — only structural behavior is
# compared, not incidental data like timestamps, commit SHAs, or temp dirs.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BASELINE_DIR="$PROJ_ROOT/.portable-spec-kit/workflows/_baselines"
AUDIT_FILE="$PROJ_ROOT/.portable-spec-kit/workflows/_audit.yml"
BYPASS_LOG="$PROJ_ROOT/agent/.bypass-log"

WORKFLOWS=(
  release
  orchestrate
  feature-complete
  init
  new-setup
  existing-setup
  reflex-autoloop
  reflex-single-pass
)

# Each workflow's source script
script_for_workflow() {
  case "$1" in
    release)                  echo "agent/scripts/psk-release.sh" ;;
    orchestrate)   echo "agent/scripts/psk-orchestrate.sh" ;;
    feature-complete)         echo "agent/scripts/psk-feature-complete.sh" ;;
    init)                     echo "agent/scripts/psk-init.sh" ;;
    new-setup)                echo "agent/scripts/psk-new-setup.sh" ;;
    existing-setup)           echo "agent/scripts/psk-existing-setup.sh" ;;
    reflex-autoloop)          echo "reflex/run.sh" ;;
    reflex-single-pass)       echo "reflex/run.sh" ;;
    *)                        echo "" ;;
  esac
}

# State-machine workflow name for register-gate calls
state_name_for_workflow() {
  case "$1" in
    release)                  echo "psk-release" ;;
    orchestrate)   echo "psk-orchestrate" ;;
    feature-complete)         echo "psk-feature-complete" ;;
    init)                     echo "psk-init" ;;
    new-setup)                echo "psk-new-setup" ;;
    existing-setup)           echo "psk-existing-setup" ;;
    reflex-autoloop)          echo "reflex-pass" ;;
    reflex-single-pass)       echo "reflex-pass" ;;
    *)                        echo "" ;;
  esac
}

# Baseline alias — some workflows share a baseline because they share a source
# script. reflex-single-pass shares reflex/run.sh with reflex-autoloop, and the
# phases.yml header at .portable-spec-kit/workflows/reflex-single-pass/phases.yml
# declares baseline-sharing as the intentional design (A2b did not differentiate
# single vs autoloop). Capture+compare uses the aliased workflow's data source.
baseline_alias() {
  case "$1" in
    reflex-single-pass)       echo "reflex-autoloop" ;;
    *)                        echo "$1" ;;
  esac
}

# ---------------------------------------------------------------------------
# Normalization — strip non-deterministic fields before comparison
# ---------------------------------------------------------------------------
normalize() {
  # ISO-8601 timestamps        → <TIMESTAMP>
  # 7-40 char git SHAs         → <SHA>
  # tmp/ random dirs           → <TMP>
  # absolute project root path → <PROJ>
  #
  # Note: BSD sed (macOS default) does not recognize \b as a word boundary —
  # it treats \b literally and the SHA patterns do not fire. Drop the \b
  # anchors and rely on explicit context (lookahead via grouped patterns).
  # The 40-char rule must fire before the 7-12 char rule to avoid partial
  # replacement chewing up a leading prefix of a longer SHA.
  sed -E \
    -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[A-Z+0-9:.-]*/<TIMESTAMP>/g' \
    -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/<TIMESTAMP>/g' \
    -e 's/[0-9a-f]{40}/<SHA>/g' \
    -e 's/([^a-zA-Z0-9])[0-9a-f]{7,12}([^a-zA-Z0-9])/\1<SHA>\2/g' \
    -e 's|/tmp/[A-Za-z0-9._-]+|<TMP>|g' \
    -e 's|/var/folders/[A-Za-z0-9/._-]+|<TMP>|g'
}

# ---------------------------------------------------------------------------
# Baseline header — every baseline file is self-documenting
# ---------------------------------------------------------------------------
emit_header() {
  local wf="$1"
  local strategy="$2"
  local kind="$3"
  local source_commit
  source_commit="$(cd "$PROJ_ROOT" && git rev-parse HEAD 2>/dev/null || echo unknown)"
  cat <<EOF
# Baseline for workflow: $wf
# Captured: <TIMESTAMP>
# Strategy: $strategy
# Source commit: $source_commit
# A2 audit reference: .portable-spec-kit/workflows/_audit.yml#$wf
# Purpose: ground-truth for A3-A6 retrofit behavior-parity gate
# Kind: $kind
#
EOF
}

# ---------------------------------------------------------------------------
# Trace capture — stdout markers and phase headers from the workflow script
# ---------------------------------------------------------------------------
capture_trace() {
  local wf="$1"
  local script_rel
  script_rel="$(script_for_workflow "$wf")"
  local script_abs="$PROJ_ROOT/$script_rel"

  emit_header "$wf" "static-analysis" "trace"
  echo "# Source: $script_rel"
  echo "# Pattern: register-gate phase ids + key echo markers"
  echo ""
  echo "## Phase enumeration (from register-gate calls)"
  # Match every register-gate invocation in the script. The 2nd token after
  # `register-gate` is the workflow-state name (literal or variable); the 3rd
  # is the phase id. We emit the phase id only, since that is what
  # uniquely identifies each phase within this workflow.
  grep -nE "register-gate[[:space:]]+" "$script_abs" 2>/dev/null \
    | grep -vE "^[0-9]+:[[:space:]]*#" \
    | sed -E 's/^[0-9]+://' \
    | awk '{
        for (i = 1; i <= NF; i++) {
          if ($i == "register-gate") {
            phase = $(i + 2)
            gsub(/^"|"$/, "", phase)
            if (phase != "") print phase
            break
          }
        }
      }' \
    | sort -u \
    | head -50 || true
  echo ""
  echo "## Phase header echoes (announce markers)"
  grep -nE "(print_phase_header|echo.*Phase [0-9]+|echo.*Step [0-9]+)" "$script_abs" 2>/dev/null \
    | grep -vE "^[0-9]+:[[:space:]]*#" \
    | sed -E 's/^[0-9]+://' \
    | sed -E 's/^[[:space:]]+//' \
    | head -60 \
    | normalize || true
  echo ""
  echo "## Expected phases (from audit YAML — authoritative)"
  awk -v wf="$wf" '
    BEGIN { in_target = 0; in_phases = 0 }
    /^[[:space:]]*-[[:space:]]+name:[[:space:]]/ {
      gsub(/^[[:space:]]*-[[:space:]]+name:[[:space:]]+/, "")
      gsub(/[[:space:]]+$/, "")
      if ($0 == wf) { in_target = 1 } else { in_target = 0 }
      in_phases = 0
      next
    }
    in_target && /^[[:space:]]+phases:/ { in_phases = 1; next }
    in_target && in_phases && /^[[:space:]]+-[[:space:]]+id:[[:space:]]/ {
      gsub(/^[[:space:]]+-[[:space:]]+id:[[:space:]]+/, "")
      gsub(/[[:space:]]+$/, "")
      print
    }
  ' "$AUDIT_FILE"
}

# ---------------------------------------------------------------------------
# Files-modified capture — derived from audit YAML (authoritative)
# ---------------------------------------------------------------------------
capture_files() {
  local wf="$1"
  emit_header "$wf" "static-analysis" "files"
  echo "# Source: .portable-spec-kit/workflows/_audit.yml § $wf"
  echo "# Sorted list of files this workflow modifies/creates across all phases."
  echo ""
  # Walk the audit YAML — emit files_modified under this workflow only
  awk -v wf="$wf" '
    BEGIN { in_target = 0; in_files = 0 }
    /^[[:space:]]*-[[:space:]]+name:[[:space:]]/ {
      # Top-level workflow entry
      gsub(/^[[:space:]]*-[[:space:]]+name:[[:space:]]+/, "")
      gsub(/[[:space:]]+$/, "")
      if ($0 == wf) { in_target = 1 } else { in_target = 0 }
      in_files = 0
      next
    }
    in_target && /^[[:space:]]+files_modified:[[:space:]]*\[\]/ {
      in_files = 0
      next
    }
    in_target && /^[[:space:]]+files_modified:/ {
      in_files = 1
      next
    }
    in_target && in_files && /^[[:space:]]+-[[:space:]]+/ {
      gsub(/^[[:space:]]+-[[:space:]]+/, "")
      gsub(/[[:space:]]+$/, "")
      print
      next
    }
    in_target && in_files && !/^[[:space:]]+-/ && !/^[[:space:]]*$/ {
      in_files = 0
    }
  ' "$AUDIT_FILE" | sort -u
}

# ---------------------------------------------------------------------------
# Exit-code capture — explicit exit points per phase
# ---------------------------------------------------------------------------
capture_exit_codes() {
  local wf="$1"
  local script_rel
  script_rel="$(script_for_workflow "$wf")"
  local script_abs="$PROJ_ROOT/$script_rel"

  emit_header "$wf" "static-analysis" "exit-codes"
  echo "# Source: $script_rel"
  echo "# Exit points the workflow can take per phase (0 = success, non-zero = fail/pause)."
  echo ""
  grep -nE "^[[:space:]]*(exit |return )[0-9]+" "$script_abs" 2>/dev/null \
    | sed -E 's/^([0-9]+):[[:space:]]*/L\1: /' \
    | sed -E 's/[[:space:]]+$//' \
    | head -80
}

# ---------------------------------------------------------------------------
# Spawn-call capture — every sub-agent invocation in canonical form
# ---------------------------------------------------------------------------
capture_spawn_calls() {
  local wf="$1"
  local script_rel
  script_rel="$(script_for_workflow "$wf")"
  local script_abs="$PROJ_ROOT/$script_rel"

  emit_header "$wf" "static-analysis" "spawn-calls"
  echo "# Source: $script_rel"
  echo "# Canonical form: <kind> <phase>"
  echo "# Kinds: psk-spawn (HF1+ wrapper) | psk-critic-spawn (critic template) | "
  echo "#        spawn-qa (reflex QA) | spawn-dev (reflex Dev) | await_subagent (orchestrator)"
  echo ""

  # psk-critic-spawn.sh write <template>   (direct invocation)
  grep -nE "psk-critic-spawn\.sh[[:space:]]+write[[:space:]]+[A-Z_0-9]+" "$script_abs" 2>/dev/null \
    | sed -E 's/.*psk-critic-spawn\.sh[[:space:]]+write[[:space:]]+([A-Z_0-9]+).*/psk-critic-spawn \1/' \
    | sort -u || true

  # critic_script indirection — bash "$critic_script" write <template>
  grep -nE '"\$critic_script"[[:space:]]+write[[:space:]]+[A-Z_0-9]+' "$script_abs" 2>/dev/null \
    | sed -E 's/.*write[[:space:]]+([A-Z_0-9]+).*/psk-critic-spawn \1/' \
    | sort -u || true

  # psk-spawn.sh request <workflow> <phase> — skip comment lines
  grep -nE "psk-spawn\.sh[[:space:]]+request[[:space:]]+" "$script_abs" 2>/dev/null \
    | grep -vE "^[0-9]+:[[:space:]]*#" \
    | sed -E 's/.*psk-spawn\.sh[[:space:]]+request[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+).*/psk-spawn \1 \2/' \
    | grep -vE "^psk-spawn[[:space:]]+\(" \
    | sort -u || true

  # spawn-qa.sh / spawn-dev.sh
  grep -nE "(spawn-qa|spawn-dev)\.sh" "$script_abs" 2>/dev/null \
    | grep -vE "^[0-9]+:[[:space:]]*#" \
    | sed -E 's/.*[/](spawn-qa|spawn-dev)\.sh.*/reflex-\1/' \
    | sort -u || true

  # await_subagent <phase> <description>
  grep -nE "^[[:space:]]*await_subagent[[:space:]]+\"" "$script_abs" 2>/dev/null \
    | sed -E 's/^[0-9]+:[[:space:]]*await_subagent[[:space:]]+"([^"]+)".*/await_subagent \1/' \
    | sort -u || true

  # Indirect spawns — psk-validate.sh dispatches through psk-critic-spawn.sh.
  # Audit YAML's critic_template field is authoritative for these phases.
  awk -v wf="$wf" '
    BEGIN { in_target = 0; in_phases = 0; current_id = "" }
    /^[[:space:]]*-[[:space:]]+name:[[:space:]]/ {
      gsub(/^[[:space:]]*-[[:space:]]+name:[[:space:]]+/, "")
      gsub(/[[:space:]]+$/, "")
      if ($0 == wf) { in_target = 1 } else { in_target = 0 }
      next
    }
    in_target && /^[[:space:]]+phases:/ { in_phases = 1; next }
    in_target && in_phases && /^[[:space:]]+-[[:space:]]+id:[[:space:]]/ {
      gsub(/^[[:space:]]+-[[:space:]]+id:[[:space:]]+/, "")
      gsub(/[[:space:]]+$/, "")
      current_id = $0
      next
    }
    in_target && in_phases && /^[[:space:]]+critic_template:[[:space:]]+[A-Z_0-9]+/ {
      tpl = $2
      gsub(/[[:space:]]+$/, "", tpl)
      if (tpl != "null" && current_id != "") {
        print "psk-critic-spawn " tpl " (via psk-validate.sh)"
      }
    }
  ' "$AUDIT_FILE" | sort -u
}

# ---------------------------------------------------------------------------
# Per-workflow baseline writer
# ---------------------------------------------------------------------------
write_baseline() {
  local wf="$1"
  local script_rel
  script_rel="$(script_for_workflow "$wf")"
  if [ -z "$script_rel" ]; then
    echo "ERROR: unknown workflow: $wf" >&2
    return 1
  fi
  if [ ! -f "$PROJ_ROOT/$script_rel" ]; then
    echo "ERROR: source script missing: $script_rel" >&2
    return 1
  fi
  # Aliased workflows share their alias's baseline — skip standalone capture.
  local alias_wf
  alias_wf="$(baseline_alias "$wf")"
  if [ "$alias_wf" != "$wf" ]; then
    echo "  ↪ $wf: shares baseline with $alias_wf (alias — no separate baseline written)"
    return 0
  fi

  mkdir -p "$BASELINE_DIR"
  capture_trace        "$wf" > "$BASELINE_DIR/$wf-pre-retrofit-trace.txt"
  capture_files        "$wf" > "$BASELINE_DIR/$wf-pre-retrofit-files.txt.tmp"
  # files file: header + sorted body
  emit_header "$wf" "static-analysis" "files" > "$BASELINE_DIR/$wf-pre-retrofit-files.txt"
  echo "# Source: .portable-spec-kit/workflows/_audit.yml § $wf" >> "$BASELINE_DIR/$wf-pre-retrofit-files.txt"
  echo "# Sorted list of files this workflow modifies/creates across all phases." >> "$BASELINE_DIR/$wf-pre-retrofit-files.txt"
  echo "" >> "$BASELINE_DIR/$wf-pre-retrofit-files.txt"
  tail -n +9 "$BASELINE_DIR/$wf-pre-retrofit-files.txt.tmp" | grep -v "^#" | grep -v "^$" | sort -u >> "$BASELINE_DIR/$wf-pre-retrofit-files.txt"
  rm -f "$BASELINE_DIR/$wf-pre-retrofit-files.txt.tmp"

  capture_exit_codes   "$wf" > "$BASELINE_DIR/$wf-pre-retrofit-exit-code.txt"
  capture_spawn_calls  "$wf" > "$BASELINE_DIR/$wf-pre-retrofit-spawn-calls.txt"

  echo "  ✓ $wf: 4 baseline files written"
}

# ---------------------------------------------------------------------------
# Per-workflow parity check — diff current capture vs baseline
# ---------------------------------------------------------------------------
parity_check() {
  local wf="$1"
  local strict_mode="${2:-strict}"
  local rc=0
  local diff_kinds=()
  # Resolve baseline alias — workflows that share a source script share
  # baselines (see baseline_alias() above). For aliased workflows, the
  # data-source workflow drives both the captured payload and the baseline
  # filename, so a single ground-truth document parity for the underlying
  # script.
  local alias_wf
  alias_wf="$(baseline_alias "$wf")"

  for kind in trace files exit-code spawn-calls; do
    local baseline="$BASELINE_DIR/$alias_wf-pre-retrofit-$kind.txt"
    if [ ! -f "$baseline" ]; then
      echo "  ✗ $wf: missing baseline $(basename "$baseline")"
      rc=1
      continue
    fi
    local current_tmp
    current_tmp="$(mktemp)"
    case "$kind" in
      trace)       capture_trace        "$alias_wf" > "$current_tmp" ;;
      files)
        emit_header "$alias_wf" "static-analysis" "files" > "$current_tmp"
        echo "# Source: .portable-spec-kit/workflows/_audit.yml § $alias_wf" >> "$current_tmp"
        echo "# Sorted list of files this workflow modifies/creates across all phases." >> "$current_tmp"
        echo "" >> "$current_tmp"
        capture_files "$alias_wf" | tail -n +9 | grep -v "^#" | grep -v "^$" | sort -u >> "$current_tmp"
        ;;
      exit-code)   capture_exit_codes   "$alias_wf" > "$current_tmp" ;;
      spawn-calls) capture_spawn_calls  "$alias_wf" > "$current_tmp" ;;
    esac
    # Diff with normalization (strip Captured: <TIMESTAMP> line which differs)
    if ! diff <(normalize < "$baseline" | grep -v "^# Captured:") \
              <(normalize < "$current_tmp" | grep -v "^# Captured:") >/dev/null; then
      diff_kinds+=("$kind")
      rc=1
    fi
    rm -f "$current_tmp"
  done

  if [ $rc -eq 0 ]; then
    echo "  ✓ $wf: parity passed (4/4 baselines match)"
  else
    echo "  ✗ $wf: parity FAILED in kinds: ${diff_kinds[*]}"
    if [ "$strict_mode" = "verbose" ]; then
      for kind in "${diff_kinds[@]}"; do
        echo "    --- diff for $wf/$kind ---"
        local baseline="$BASELINE_DIR/$alias_wf-pre-retrofit-$kind.txt"
        local current_tmp
        current_tmp="$(mktemp)"
        case "$kind" in
          trace)       capture_trace        "$alias_wf" > "$current_tmp" ;;
          files)
            emit_header "$alias_wf" "static-analysis" "files" > "$current_tmp"
            echo "# Source: .portable-spec-kit/workflows/_audit.yml § $alias_wf" >> "$current_tmp"
            echo "# Sorted list of files this workflow modifies/creates across all phases." >> "$current_tmp"
            echo "" >> "$current_tmp"
            capture_files "$alias_wf" | tail -n +9 | grep -v "^#" | grep -v "^$" | sort -u >> "$current_tmp"
            ;;
          exit-code)   capture_exit_codes   "$alias_wf" > "$current_tmp" ;;
          spawn-calls) capture_spawn_calls  "$alias_wf" > "$current_tmp" ;;
        esac
        diff <(normalize < "$baseline" | grep -v "^# Captured:") \
             <(normalize < "$current_tmp" | grep -v "^# Captured:") | head -40 || true
        rm -f "$current_tmp"
      done
    fi
  fi
  return $rc
}

# ---------------------------------------------------------------------------
# --list mode — status of each workflow's baseline
# ---------------------------------------------------------------------------
list_status() {
  echo "Baseline status — .portable-spec-kit/workflows/_baselines/"
  echo ""
  printf "%-26s %-12s %-12s %-12s %-12s\n" "workflow" "trace" "files" "exit-code" "spawn-calls"
  printf "%-26s %-12s %-12s %-12s %-12s\n" "--------" "-----" "-----" "---------" "-----------"
  for wf in "${WORKFLOWS[@]}"; do
    local cells=()
    local alias_wf
    alias_wf="$(baseline_alias "$wf")"
    for kind in trace files exit-code spawn-calls; do
      local f="$BASELINE_DIR/$alias_wf-pre-retrofit-$kind.txt"
      if [ -s "$f" ]; then
        if [ "$alias_wf" != "$wf" ]; then
          cells+=("alias")
        else
          cells+=("ok")
        fi
      else
        cells+=("MISSING")
      fi
    done
    printf "%-26s %-12s %-12s %-12s %-12s\n" "$wf" "${cells[@]}"
  done
}

# ---------------------------------------------------------------------------
# CLI dispatch
# ---------------------------------------------------------------------------
log_bypass() {
  local action="$1"
  # QA-D7-BYPASS-LOG fix (v0.6.83): route through the canonical JSON logger so
  # PSK027's JSON-only counter sees this entry (raw TSV was invisible to it).
  local _bypass_logger
  _bypass_logger="$(dirname "${BASH_SOURCE[0]}")/psk-bypass-log.sh"
  if [ -x "$_bypass_logger" ]; then
    bash "$_bypass_logger" log --env-var PSK_BEHAVIOR_PARITY_BYPASS \
      --command "psk-behavior-parity.sh $action" \
      --justification "${PSK_BYPASS_REASON:-not provided}" >/dev/null 2>&1 || true
  else
    mkdir -p "$(dirname "$BYPASS_LOG")"
    printf '%s psk-behavior-parity.sh %s\n' "$(date -u +%FT%TZ)" "$action" >> "$BYPASS_LOG"
  fi
}

usage() {
  cat <<'EOF'
Usage:
  psk-behavior-parity.sh <workflow>              Run parity check for one workflow
  psk-behavior-parity.sh <workflow> --regenerate Overwrite baseline (admin override)
  psk-behavior-parity.sh <workflow> --verbose    Show diffs on failure
  psk-behavior-parity.sh --all                   Check all 8 workflows
  psk-behavior-parity.sh --regenerate-all        Regenerate baselines for all 8
  psk-behavior-parity.sh --list                  Show baseline status table

Workflows: release · orchestrate · feature-complete ·
           init · new-setup · existing-setup · reflex-autoloop · reflex-single-pass
           (reflex-single-pass shares baselines with reflex-autoloop — same script.)
EOF
}

is_workflow() {
  local target="$1"
  for wf in "${WORKFLOWS[@]}"; do
    [ "$wf" = "$target" ] && return 0
  done
  return 1
}

main() {
  case "${1:-}" in
    --list|list)
      list_status
      ;;
    --all|all)
      local total_rc=0
      echo "Running parity check across ${#WORKFLOWS[@]} workflows..."
      for wf in "${WORKFLOWS[@]}"; do
        parity_check "$wf" "strict" || total_rc=1
      done
      exit $total_rc
      ;;
    --regenerate-all)
      log_bypass "regenerate-all"
      echo "Regenerating baselines for ${#WORKFLOWS[@]} workflows..."
      for wf in "${WORKFLOWS[@]}"; do
        write_baseline "$wf"
      done
      ;;
    --help|-h|help|"")
      usage
      ;;
    *)
      if ! is_workflow "$1"; then
        echo "ERROR: unknown workflow or flag: $1" >&2
        usage >&2
        exit 2
      fi
      local wf="$1"
      shift || true
      case "${1:-}" in
        --regenerate|regenerate)
          log_bypass "regenerate $wf"
          write_baseline "$wf"
          ;;
        --verbose|verbose)
          parity_check "$wf" "verbose"
          ;;
        ""|--check|check)
          parity_check "$wf" "strict"
          ;;
        *)
          echo "ERROR: unknown sub-flag for $wf: $1" >&2
          usage >&2
          exit 2
          ;;
      esac
      ;;
  esac
}

main "$@"
