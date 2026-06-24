#!/bin/bash
# mechanical-script: deterministic engine; sub-agent FIXES route via psk-spawn.sh (Dim 28 clean)
# =============================================================
# psk-conformance.sh — Registry-driven conformance ENGINE (Stage-2, v0.6.62+)
#
# The core of the comprehensive idempotent `init`. init is dimension-AGNOSTIC:
# it iterates a REGISTRY of checks (detect → fix → re-detect) rather than a
# hardcoded dimension list. Adding a future kit standard = add a registry entry
# (DATA), never edit this engine.
#
# It CONSUMES the kit's EXISTING authoritative standards registries as built-in
# checks (does NOT duplicate them):
#   - sync-check-drift   → psk-sync-check.sh --full        (PSK0xx rules)
#   - mandate-gaps       → reflex/lib/mandate-audit.sh     (required dirs/files/layout)
#   - ui-completeness    → psk-ui-completeness.sh --strict (UI standards, frontend only)
#   - src-layout         → psk-scaffold-src.sh --check     (PSK022a/b opt-in subdirs)
# PLUS a thin extension registry at .portable-spec-kit/conformance/registry.yml
# (checks that do not fit the four built-ins above).
#
# Modes:
#   --check          detect-only across all checks; exit 0 clean, 1 if any drift (no fixes)
#   --conform        detect → fix → re-detect; mechanical fixes run inline;
#                    sub-agent fixes pause via psk-spawn.sh (§Spawn Fidelity).
#                    Exit 0 = conformant (or only sub-agent fixes pending → AWAITING),
#                    1 = unresolved mechanical drift.
#   --list           print the resolved check set (built-ins + registry entries)
#   --json           machine-readable status (with --check)
#
# Idempotent: re-running on a conformant project is a fast no-op (every detect
# exits 0, nothing dispatched). Honors EDGE E4: this engine NEVER pulls source.
#
# Bypass: PSK_CONFORMANCE_DISABLED=1 short-circuits to exit 0.
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="${PROJ_ROOT:-$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)}"
export PROJ_ROOT
# QA-D6-P8 (cycle-01 follow-up): registry-sourced detect/fix command strings are
# dispatched via `bash -c "$cmd"` (a fresh subshell), NOT `eval` (which the kit's
# own code-review bans, psk-code-review.sh). The built-in checks reference
# $SCRIPT_DIR, so it must be visible to the child shell — export it (a kit-internal
# path, never user input). PROJ_ROOT is already exported above.
export SCRIPT_DIR
REGISTRY="$PROJ_ROOT/.portable-spec-kit/conformance/registry.yml"
SPAWN_SCRIPT="$SCRIPT_DIR/psk-spawn.sh"
LOG="$PROJ_ROOT/agent/.workflow-state/init-conformance.log"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

MODE="check"
JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check)   MODE="check"; shift ;;
    --conform) MODE="conform"; shift ;;
    --list)    MODE="list"; shift ;;
    --json)    JSON=1; shift ;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [ "${PSK_CONFORMANCE_DISABLED:-0}" = "1" ]; then
  [ $JSON -eq 1 ] && echo '{"engine":"psk-conformance","skipped":"PSK_CONFORMANCE_DISABLED=1"}'
  [ $JSON -eq 0 ] && echo "psk-conformance: skipped (PSK_CONFORMANCE_DISABLED=1)"
  exit 0
fi

# ── project-shape detection (for applies_when gating) ────────────────────────
_is_frontend() {
  grep -qiE 'next\.js|react|vue|svelte|angular|tailwind|frontend' "$PROJ_ROOT/agent/PLANS.md" 2>/dev/null && return 0
  [ -f "$PROJ_ROOT/package.json" ] && grep -qiE '"(react|next|vue|svelte|@angular)' "$PROJ_ROOT/package.json" 2>/dev/null && return 0
  return 1
}
_is_python() { [ -f "$PROJ_ROOT/requirements.txt" ] || [ -f "$PROJ_ROOT/pyproject.toml" ] || [ -f "$PROJ_ROOT/setup.py" ]; }
_is_node()   { [ -f "$PROJ_ROOT/package.json" ]; }

_applies() {
  case "$1" in
    always|"") return 0 ;;
    frontend) _is_frontend ;;
    python)   _is_python ;;
    node)     _is_node ;;
    *)        return 0 ;;   # unknown gate → applies (fail-open: detect will decide)
  esac
}

# ── built-in checks (consume existing registries) ────────────────────────────
# Each emits one record:  id<TAB>spawn_type<TAB>detect-rc<TAB>applies(0/1)
# detect-rc: 0 conformant, 1 drift. We only RUN detect lazily in the loop.

# Built-in check table: id|applies_when|detect-cmd|fix-cmd|spawn_type
_builtin_checks() {
  cat <<EOF
sync-check-drift|always|bash "$SCRIPT_DIR/psk-sync-check.sh" --full|MANUAL|sub-agent
mandate-gaps|always|bash "$PROJ_ROOT/reflex/lib/mandate-audit.sh" --root "$PROJ_ROOT" --block-severity MAJOR|MANUAL|sub-agent
ui-completeness|frontend|bash "$SCRIPT_DIR/psk-ui-completeness.sh" --strict|MANUAL|sub-agent
src-layout|always|bash "$SCRIPT_DIR/psk-scaffold-src.sh" "$PROJ_ROOT" --check|bash "$SCRIPT_DIR/psk-scaffold-src.sh" "$PROJ_ROOT"|mechanical
EOF
}

# ── registry.yml extension checks ────────────────────────────────────────────
# Parse the flat `checks:` list. Substitute $PROJ_ROOT before use.
_registry_checks() {
  [ -f "$REGISTRY" ] || return 0
  awk -v P="|" '
    /^checks:[[:space:]]*$/ { in_c=1; next }
    in_c && /^[A-Za-z_]+:/ && !/^[[:space:]]/ { in_c=0 }
    in_c && /^[[:space:]]*-[[:space:]]*id:/ {
      if (id!="") print id P aw P det P fix P st
      id=""; aw="always"; det=""; fix=""; st="mechanical"
      sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/,""); gsub(/[[:space:]]*$/,""); id=$0; next
    }
    in_c && id!="" && /^[[:space:]]+applies_when:/ { sub(/^[[:space:]]+applies_when:[[:space:]]*/,""); gsub(/[[:space:]]*$/,""); aw=$0; next }
    in_c && id!="" && /^[[:space:]]+detect:/ { sub(/^[[:space:]]+detect:[[:space:]]*/,""); gsub(/^"/,""); gsub(/"$/,""); gsub(/[[:space:]]*$/,""); det=$0; next }
    in_c && id!="" && /^[[:space:]]+fix:/ { sub(/^[[:space:]]+fix:[[:space:]]*/,""); gsub(/^"/,""); gsub(/"$/,""); gsub(/[[:space:]]*$/,""); fix=$0; next }
    in_c && id!="" && /^[[:space:]]+spawn_type:/ { sub(/^[[:space:]]+spawn_type:[[:space:]]*/,""); gsub(/[[:space:]]*$/,""); st=$0; next }
    END { if (id!="") print id P aw P det P fix P st }
  ' "$REGISTRY"
}

_all_checks() { _builtin_checks; _registry_checks; }

# substitute $PROJ_ROOT in a registry-sourced / built-in command string BEFORE
# dispatch via `bash -c`. A checkout under a path with spaces ("/Users/Jane
# Doe/...") must not word-split.
# Mirror psk-dispatch.sh _quote_path_vars: replace the quoted form first ("$PROJ_ROOT"
# → "raw value"), then the bare form ($PROJ_ROOT → %q-escaped single word).
_subst() {
  local s="$1" q
  q=$(printf '%q' "$PROJ_ROOT")
  s="${s//\"\$PROJ_ROOT\"/\"$PROJ_ROOT\"}"   # "$PROJ_ROOT" → "raw value"
  s="${s//\$PROJ_ROOT/$q}"                    # bare $PROJ_ROOT → %q-escaped
  printf '%s' "$s"
}

# ── list mode ────────────────────────────────────────────────────────────────
if [ "$MODE" = "list" ]; then
  echo "Resolved conformance checks (built-ins + registry):"
  while IFS='|' read -r id aw det fix st; do
    [ -z "$id" ] && continue
    echo "  - $id  (applies_when=$aw, spawn_type=$st)"
  done < <(_all_checks)
  exit 0
fi

mkdir -p "$(dirname "$LOG")"

drift_ids=""; subagent_pending=""; mech_unresolved=""
total=0; conformant=0; fixed=0

while IFS='|' read -r id aw det fix st; do
  [ -z "$id" ] && continue
  total=$((total+1))
  if ! _applies "$aw"; then
    [ "$MODE" = "conform" ] && echo -e "  ${CYAN}∘${NC} $id — n/a for this project shape (skip)"
    conformant=$((conformant+1))
    continue
  fi
  det_cmd=$(_subst "$det")
  # QA-D6-P8: dispatch via `bash -c` (subshell), not `eval` — registry-driven
  # detector command from .portable-spec-kit/conformance/*.yml (kit-controlled).
  if ( cd "$PROJ_ROOT" && bash -c "$det_cmd" >/dev/null 2>&1 ); then
    [ "$MODE" = "conform" ] && echo -e "  ${GREEN}✓${NC} $id — conformant"
    conformant=$((conformant+1))
    echo "$(date -u +%FT%TZ) $id conformant" >> "$LOG"
    continue
  fi
  # Drift detected
  drift_ids="$drift_ids $id"
  if [ "$MODE" = "check" ]; then
    echo -e "  ${YELLOW}⚠${NC} $id — DRIFT (out of standard)"
    echo "$(date -u +%FT%TZ) $id drift" >> "$LOG"
    continue
  fi

  # --conform: dispatch fix
  if [ "$st" = "mechanical" ]; then
    fix_cmd=$(_subst "$fix")
    if [ "$fix_cmd" = "MANUAL" ]; then
      echo -e "  ${RED}✗${NC} $id — drift with no mechanical fix (sub-agent or operator required)"
      mech_unresolved="$mech_unresolved $id"
      continue
    fi
    echo -e "  ${CYAN}→${NC} $id — running mechanical fix"
    # QA-D6-P8: dispatch via `bash -c` (subshell), not `eval` — registry-driven
    # fix command from .portable-spec-kit/conformance/*.yml (kit-controlled).
    if ( cd "$PROJ_ROOT" && bash -c "$fix_cmd" ); then
      # QA-D6-P8: re-run detector after fix via `bash -c` (same source as above)
      if ( cd "$PROJ_ROOT" && bash -c "$det_cmd" >/dev/null 2>&1 ); then
        echo -e "  ${GREEN}✓${NC} $id — fixed (re-detect clean)"
        fixed=$((fixed+1))
        echo "$(date -u +%FT%TZ) $id fixed" >> "$LOG"
      else
        echo -e "  ${RED}✗${NC} $id — fix ran but re-detect still shows drift"
        mech_unresolved="$mech_unresolved $id"
        echo "$(date -u +%FT%TZ) $id fix-failed" >> "$LOG"
      fi
    else
      echo -e "  ${RED}✗${NC} $id — mechanical fix command failed"
      mech_unresolved="$mech_unresolved $id"
      echo "$(date -u +%FT%TZ) $id fix-error" >> "$LOG"
    fi
  else
    # sub-agent fix: route through psk-spawn.sh per §Spawn Fidelity. The engine
    # NEVER does the sub-agent's work inline (no inline-fallback branch). It
    # surfaces the pending spawn so the main agent dispatches it.
    subagent_pending="$subagent_pending $id"
    echo -e "  ${YELLOW}⊙${NC} $id — drift requires sub-agent fix: ${fix:-(built-in audit — fix per recommendation)}"
    echo "$(date -u +%FT%TZ) $id awaiting-subagent" >> "$LOG"
  fi
done < <(_all_checks)

# ── summary + exit ───────────────────────────────────────────────────────────
drift_ids="${drift_ids# }"; subagent_pending="${subagent_pending# }"; mech_unresolved="${mech_unresolved# }"

if [ "$MODE" = "check" ]; then
  if [ $JSON -eq 1 ]; then
    echo "{\"engine\":\"psk-conformance\",\"total\":$total,\"conformant\":$conformant,\"drift\":[\"$(echo $drift_ids | sed 's/ /","/g')\"]}" | sed 's/\[""\]/[]/'
  fi
  [ -n "$drift_ids" ] && { echo -e "${YELLOW}Conformance drift:${NC} $drift_ids"; exit 1; }
  echo -e "${GREEN}✓ project conformant — all $total checks clean${NC}"
  exit 0
fi

# conform mode
echo ""
echo -e "${CYAN}Conformance summary:${NC} $conformant conformant, $fixed fixed, ${subagent_pending:+sub-agent pending: $subagent_pending,} ${mech_unresolved:+unresolved: $mech_unresolved}"

if [ -n "$mech_unresolved" ]; then
  echo -e "${RED}✗ unresolved mechanical drift:${NC} $mech_unresolved" >&2
  echo "  (e.g. reflex-install — run 'install' to bring kit machinery in; init never pulls source per EDGE E4)" >&2
  exit 1
fi

if [ -n "$subagent_pending" ]; then
  echo -e "${YELLOW}⊙ sub-agent fixes pending:${NC} $subagent_pending"
  echo "  The init work phase spawns these via psk-spawn.sh (workload-driven, one per natural unit)."
  echo "  AWAITING_SUBAGENT — main agent dispatches the fix prompt(s) then re-runs conformance."
  # Exit 0: the dispatcher's manual-checkpoint/work phase keeps the workflow paused;
  # sub-agent dispatch is the main-agent's job, surfaced above.
  exit 0
fi

echo -e "${GREEN}✓ project fully conformant${NC}"
exit 0
