#!/usr/bin/env bash
# mechanical-script: psk-behavior-live.sh — dynamic live-run gate for workflow migrations (no AI invocation)
# doc-coverage-exempt: internal mechanical helper — no user-facing R->F->T claim
#
# THE missing gate. The v0.6.62 dispatcher migration was approved by STATIC parity
# (psk-behavior-parity.sh) that never RAN the workflow — so dropped mechanical hooks
# (spawn-qa/spawn-dev/write_verdict/merge) were invisible. This harness closes that
# hole: it actually exercises a migrated workflow's declaration through the live
# dispatcher at runtime and asserts it loads, validates, previews, and enumerates its
# phases without error — a runtime check static grep-diffing cannot give.
#
# It is INTENTIONALLY non-destructive: it drives the read/validate/enumerate path
# (psk-dispatch.sh --validate + list, psk-preview.sh) which exercises the real
# phases.yml parser + dependency graph + dispatch wiring, WITHOUT executing phase
# side-effects (no version bumps, no scaffolds, no sub-agent spawns). Combined with
# the static parity gate + a workflow-specific real invocation in the migration's
# own commit, this is the per-workflow live gate mandated by the rebuild plan.
#
# Usage:
#   bash agent/scripts/psk-behavior-live.sh <workflow>     # live-gate one workflow
#   bash agent/scripts/psk-behavior-live.sh --all          # every migrated workflow
# Exit: 0 = live gate passed · 1 = a workflow with phases.yml failed the live path
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DISPATCH="$PROJ_ROOT/agent/scripts/psk-dispatch.sh"
PREVIEW="$PROJ_ROOT/agent/scripts/psk-preview.sh"
WORKFLOWS_DIR="$PROJ_ROOT/.portable-spec-kit/workflows"

if [ -t 1 ]; then GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else GREEN=''; RED=''; YELLOW=''; CYAN=''; NC=''; fi

live_gate_one() {
  local wf="$1"
  local decl="$WORKFLOWS_DIR/$wf/phases.yml"
  if [ ! -f "$decl" ]; then
    echo -e "  ${YELLOW}⊘${NC} $wf: no phases.yml — still monolithic (not yet migrated), live gate N/A"
    return 0
  fi
  local fails=0

  # 1. The dispatcher must VALIDATE the declaration live (parses phases.yml,
  #    checks required per-phase fields + dependency graph).
  if bash "$DISPATCH" --validate "$wf" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} $wf: dispatcher --validate (phases.yml parses + schema + deps)"
  else
    echo -e "  ${RED}✗${NC} $wf: dispatcher --validate FAILED — phases.yml does not load cleanly"
    fails=$((fails+1))
  fi

  # 2. The preview tool must render the declaration without error (exercises the
  #    same parser path a human/operator uses to inspect the workflow).
  if [ -x "$PREVIEW" ] && bash "$PREVIEW" "$wf" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} $wf: psk-preview.sh renders the declaration"
  else
    echo -e "  ${RED}✗${NC} $wf: psk-preview.sh FAILED to render"
    fails=$((fails+1))
  fi

  # 3. Every declared sub-agent phase must point at a prompt file that exists, and
  #    every mechanical phase must declare a command — the runtime contract the
  #    dispatcher relies on (a dropped prompt/command is the exact silent-break class).
  local missing
  missing=$(awk '
    /^[[:space:]]*-[[:space:]]*id:/ { id=$0; sub(/.*id:[[:space:]]*/,"",id); st=""; pr=""; cm="" }
    /^[[:space:]]+spawn_type:/ { st=$0; sub(/.*spawn_type:[[:space:]]*/,"",st) }
    /^[[:space:]]+prompt:/ { pr=$0; sub(/.*prompt:[[:space:]]*/,"",pr); gsub(/"/,"",pr) }
    /^[[:space:]]+command:/ { cm=$0 }
    /^[[:space:]]*-[[:space:]]*id:/ || /^[A-Za-z]/ {
      if (prev_id!="") {
        if (prev_st ~ /sub-agent/ && prev_pr=="") print "phase " prev_id ": sub-agent missing prompt"
        if (prev_st ~ /mechanical/ && prev_cm=="") print "phase " prev_id ": mechanical missing command"
      }
    }
    { prev_id=id; prev_st=st; prev_pr=pr; prev_cm=cm }
    END {
      if (prev_st ~ /sub-agent/ && prev_pr=="") print "phase " prev_id ": sub-agent missing prompt"
      if (prev_st ~ /mechanical/ && prev_cm=="") print "phase " prev_id ": mechanical missing command"
    }' "$decl" 2>/dev/null)
  # Cross-check sub-agent prompt files exist on disk.
  local pf pmiss=""
  while IFS= read -r pf; do
    [ -z "$pf" ] && continue
    case "$pf" in /*) : ;; *) pf="$PROJ_ROOT/$pf" ;; esac
    [ -f "$pf" ] || pmiss="$pmiss $(basename "$pf")"
  done < <(awk '/^[[:space:]]+prompt:/ {sub(/.*prompt:[[:space:]]*/,"");gsub(/"/,"");print}' "$decl")
  if [ -z "$missing" ] && [ -z "$pmiss" ]; then
    echo -e "  ${GREEN}✓${NC} $wf: every sub-agent phase has a prompt file, every mechanical phase has a command"
  else
    [ -n "$missing" ] && echo -e "  ${RED}✗${NC} $wf: $missing"
    [ -n "$pmiss" ] && echo -e "  ${RED}✗${NC} $wf: missing prompt file(s):$pmiss"
    fails=$((fails+1))
  fi

  return $fails
}

main() {
  local arg="${1:-}"
  [ -z "$arg" ] && { echo "usage: psk-behavior-live.sh <workflow> | --all" >&2; exit 2; }
  echo -e "${CYAN}═══ live-run gate ═══${NC}"
  local total_fail=0
  if [ "$arg" = "--all" ]; then
    local d base
    for d in "$WORKFLOWS_DIR"/*/; do
      [ -d "$d" ] || continue
      base="$(basename "$d")"
      case "$base" in _*) continue ;; esac   # skip _baselines / _audit etc.
      live_gate_one "$base" || total_fail=$((total_fail+1))
    done
  else
    live_gate_one "$arg" || total_fail=$((total_fail+1))
  fi
  if [ "$total_fail" -eq 0 ]; then
    echo -e "${GREEN}✓ live gate passed${NC}"
    exit 0
  fi
  echo -e "${RED}✗ live gate failed for $total_fail workflow(s)${NC}" >&2
  exit 1
}
main "$@"
