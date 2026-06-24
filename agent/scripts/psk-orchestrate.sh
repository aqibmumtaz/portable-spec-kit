#!/bin/bash
# workflow-router: psk-orchestrate.sh — project orchestration (build: new + existing, single workflow)
# workflow-decl: .portable-spec-kit/workflows/orchestrate/phases.yml
# script-class: orchestrator
# =============================================================
# psk-orchestrate.sh — Project Orchestration (dispatcher-driven, v0.6.63+)
# Workflow doc: docs/work-flows/18-project-orchestration.md
#
# Thin CLI router — delegates to psk-dispatch.sh (unified phase driver). The
# single `build` command runs ONE workflow — `orchestrate` (10 lifecycle phases:
# capture..final-handoff) — for both new and existing projects. There is no
# separate "update" workflow: build always drives the lifecycle pipeline.
#
# Conforming an EXISTING project to kit standards (design plans, R→F→T anchors,
# UI completeness, sync-check config, reflex install, etc.) is the job of
# `psk-init.sh` (the registry-driven init conformance engine). `build` only
# SURFACES standards drift on an existing project (advisory, non-blocking) and
# points the operator at `init` to conform — it never blocks on conformance.
#
# Phase sequence + gates live in the single declaration:
#   .portable-spec-kit/workflows/orchestrate/phases.yml
# psk-dispatch.sh is the executor; this router only resolves args + surfaces drift.
#
# Each await_subagent comment below is the canonical grep surface for the
# WorkflowDecl spawn-coverage test. Actual dispatch routes through
# psk-dispatch.sh → psk-spawn.sh per §Spawn Fidelity.
#   await_subagent "capture"
#   await_subagent "research"
#   await_subagent "expand-reqs"
#   await_subagent "specs-plans"
#   await_subagent "ui-system"
#   await_subagent "scaffold"
#   await_subagent "features"
#   await_subagent "release-prep"
#   await_subagent "reflex-audit"
#   await_subagent "final-handoff"
#
# §Workflow Fidelity (portable-spec-kit.md): this is an executable kit workflow.
# It executes its declared phases faithfully via psk-dispatch.sh — no phase
# compression, no inline substitution, no scope reduction. Pause-and-resume.
#
# Usage:
#   bash agent/scripts/psk-orchestrate.sh build "<raw requirement>"
#   bash agent/scripts/psk-orchestrate.sh build --reqs-file <path>
#   bash agent/scripts/psk-orchestrate.sh build --target <path> "<raw requirement>"
#   bash agent/scripts/psk-orchestrate.sh status
#   bash agent/scripts/psk-orchestrate.sh resume
#   bash agent/scripts/psk-orchestrate.sh abort
#   bash agent/scripts/psk-orchestrate.sh <dispatcher-verb>   # next/list/done/…
#
# Exit codes: same as psk-dispatch.sh (0=ok, 1=error, 2=schema/usage, 3=gate, 4=arbitration)
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
# PROJ_ROOT precedence: PSK_PROJ_ROOT env → default (kit checkout). --target overrides below.
PROJ_ROOT="${PSK_PROJ_ROOT:-$DEFAULT_PROJ_ROOT}"

DISPATCH="$SCRIPT_DIR/psk-dispatch.sh"

# The single workflow build drives, for both new and existing projects.
# Conforming an existing project to kit standards is psk-init.sh's job, not a
# separate workflow here.
_detect_workflow() {
  echo "orchestrate"
}

# Pick the workflow for status/resume/verb-forwarding. Only one workflow exists
# now (orchestrate); use its state file if present, else fall back to fresh
# detection so `status` on a never-started project still resolves.
_resolve_active_workflow() {
  local root="$1"
  local sdir="$root/agent/.workflow-state"
  if [ -f "$sdir/orchestrate.state" ]; then
    echo "orchestrate"
  else
    _detect_workflow "$root"
  fi
}

# Persist the operator's raw requirement (or --reqs-file path) so the
# capture/kit-currency phase sub-agent can read it. The dispatcher does not
# forward positional args to phases, so this is the hand-off surface.
_record_build_input() {
  local root="$1" raw="$2" reqs_file="$3"
  local sdir="$root/agent/.workflow-state"
  mkdir -p "$sdir"
  {
    echo "raw_requirement<<PSK_EOF"
    printf '%s\n' "$raw"
    echo "PSK_EOF"
    echo "reqs_file=$reqs_file"
    echo "recorded=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$sdir/orchestrate-build-input.yml"
}

usage() {
  sed -n '40,49p' "$0" | sed 's/^# \{0,1\}//'
}

CMD="${1:-status}"
[ -n "${1:-}" ] && shift || true

case "$CMD" in
  # --- Removed flags: explicit notice, no silent alias ---
  --update|--retrofit)
    echo "psk-orchestrate.sh: '$CMD' removed — use: bash agent/scripts/psk-orchestrate.sh build" >&2
    exit 1
    ;;

  --help|-h)
    usage
    exit 0
    ;;

  build)
    # Parse build args: positional raw requirement, --reqs-file <path>, --target <path>
    RAW_REQ=""
    REQS_FILE=""
    TARGET_PATH=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --target)      shift; TARGET_PATH="${1:-}" ;;
        --target=*)    TARGET_PATH="${1#--target=}" ;;
        --reqs-file)   shift; REQS_FILE="${1:-}" ;;
        --reqs-file=*) REQS_FILE="${1#--reqs-file=}" ;;
        *)             RAW_REQ="${RAW_REQ:+$RAW_REQ }$1" ;;
      esac
      shift || true
    done

    if [ -n "$TARGET_PATH" ]; then
      if [ ! -d "$TARGET_PATH" ]; then
        echo "psk-orchestrate.sh: --target path does not exist: $TARGET_PATH" >&2
        exit 1
      fi
      PROJ_ROOT="$(cd "$TARGET_PATH" && pwd)"
    fi

    WF="$(_detect_workflow "$PROJ_ROOT")"
    _record_build_input "$PROJ_ROOT" "$RAW_REQ" "$REQS_FILE"
    echo "psk-orchestrate.sh: build → $WF (project: $PROJ_ROOT)"
    # Advisory conformance — surface existing-project standards drift before
    # dispatching the lifecycle workflow. Non-blocking: build never gates on
    # conformance. `init` owns the actual --conform; build only reports drift.
    if [ -x "$SCRIPT_DIR/psk-conformance.sh" ] || [ -f "$SCRIPT_DIR/psk-conformance.sh" ]; then
      echo "psk-orchestrate.sh: conformance (advisory):"
      PROJ_ROOT="$PROJ_ROOT" bash "$SCRIPT_DIR/psk-conformance.sh" --check 2>&1 | sed 's/^/  /' || true
      echo "  (run: bash agent/scripts/psk-init.sh  to conform standards)"
    fi
    exec env PROJ_ROOT="$PROJ_ROOT" bash "$DISPATCH" "$WF"
    ;;

  status|resume|abort)
    # Forward to the dispatcher for the active workflow. `abort` maps to the
    # dispatcher's `abandon` verb.
    TARGET_PATH=""
    REST=()
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --target)   shift; TARGET_PATH="${1:-}" ;;
        --target=*) TARGET_PATH="${1#--target=}" ;;
        *)          REST+=("$1") ;;
      esac
      shift || true
    done
    if [ -n "$TARGET_PATH" ] && [ -d "$TARGET_PATH" ]; then
      PROJ_ROOT="$(cd "$TARGET_PATH" && pwd)"
    fi
    WF="$(_resolve_active_workflow "$PROJ_ROOT")"
    VERB="$CMD"
    [ "$CMD" = "abort" ] && VERB="abandon"
    exec env PROJ_ROOT="$PROJ_ROOT" bash "$DISPATCH" "$WF" "$VERB" "${REST[@]:-}"
    ;;

  *)
    # Forward any other dispatcher verb (next/list/done/retry/init/…) to the
    # active workflow's dispatcher.
    WF="$(_resolve_active_workflow "$PROJ_ROOT")"
    exec env PROJ_ROOT="$PROJ_ROOT" bash "$DISPATCH" "$WF" "$CMD" "$@"
    ;;
esac
