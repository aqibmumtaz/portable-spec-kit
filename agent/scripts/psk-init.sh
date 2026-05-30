#!/bin/bash
# workflow-router: psk-init.sh — init workflow (conform project to kit standards)
# workflow-decl: .portable-spec-kit/workflows/init/phases.yml
# =============================================================
# psk-init.sh — Init Workflow (dispatcher-driven, registry-conformance, v0.6.62+)
#
# `init` conforms the PROJECT to current kit STANDARDS via the registry-driven
# conformance ENGINE (psk-conformance.sh). It is dimension-AGNOSTIC: the engine
# iterates a registry of checks (detect → fix → re-detect, idempotent) rather
# than a hardcoded dimension list. Adding a future kit standard = add a registry
# entry (DATA), never edit init's code.
#
# State-detected, idempotent CREATE-vs-REFRESH:
#   • CREATE  — empty project (no substantive agent/*.md pipeline): scaffold the
#               agent/*.md pipeline from kit templates, then conform.
#   • REFRESH — existing kit-managed project: conform the existing artifacts to
#               current kit standards (no clobber of hand-written content).
#   Re-running on a conformant project = fast no-op (every detect exits 0).
#
# EDGE E4 (standalone init, no kit machinery): init NEVER pulls source. If the
# kit machinery is absent → fail-fast "kit not installed — run install first".
#
# Dual-mode router:
#   • bash psk-init.sh                 → delegate to psk-dispatch.sh init (drives
#                                         the 3-phase declaration in phases.yml)
#   • bash psk-init.sh preflight       → E4 gate + CREATE/REFRESH detect + (CREATE)
#                                         scaffold agent/*.md + advisory conformance --check
#   • bash psk-init.sh complete        → run conformance --conform (the actual conform)
#   • bash psk-init.sh <verb> [...]    → forward dispatcher verbs (next/status/resume/…)
#
# The phase sequence + gates live in the declaration (single source of truth);
# psk-dispatch.sh is the executor. This script keeps the preflight + conform LOGIC
# (which the declaration's phases call back into) plus the delegation.
#
# §Workflow Fidelity (portable-spec-kit.md): this is an executable kit workflow.
# It executes its declared phases faithfully and completely via psk-dispatch.sh —
# no phase compression, no inline substitution where a sub-agent is specified, no
# scope reduction under rate/context pressure. Pause-and-resume, never reduce-scope.
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="${PROJ_ROOT:-$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)}"
export PROJ_ROOT

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

CONFORMANCE="$SCRIPT_DIR/psk-conformance.sh"
TEMPLATES_DIR="$PROJ_ROOT/.portable-spec-kit/templates"
SNAPSHOT_DIR="$PROJ_ROOT/agent/.init-snapshot"   # content-loss guard (REFRESH mode)

# ── E4: kit-machinery presence gate ──────────────────────────────────────────
# init NEVER pulls source. If the kit machinery is absent → fail-fast.
# Canonical signal: psk-bootstrap-check.sh (kit-install integrity gate). Fall back
# to a minimal structural probe if the bootstrap-check script itself is missing.
_kit_installed() {
  if [ -x "$SCRIPT_DIR/psk-bootstrap-check.sh" ]; then
    bash "$SCRIPT_DIR/psk-bootstrap-check.sh" --quiet >/dev/null 2>&1 && return 0
    return 1
  fi
  # Minimal fallback probe (bootstrap-check itself absent = machinery absent)
  [ -f "$SCRIPT_DIR/psk-dispatch.sh" ] && [ -f "$SCRIPT_DIR/psk-conformance.sh" ] \
    && [ -d "$PROJ_ROOT/.portable-spec-kit" ]
}

# ── CREATE-vs-REFRESH state detection (EDGE E2) ───────────────────────────────
# REFRESH when ≥1 substantive agent/*.md pipeline file exists OR src/ has content.
# Otherwise CREATE. Partial pipelines → treated as REFRESH (backfill, never wipe).
_init_mode() {
  local f
  for f in REQS SPECS PLANS DESIGN TASKS AGENT AGENT_CONTEXT RESEARCH RELEASES; do
    [ -s "$PROJ_ROOT/agent/$f.md" ] && { echo "REFRESH"; return 0; }
  done
  # src/ with real content also signals an existing project
  if [ -d "$PROJ_ROOT/src" ] && [ -n "$(find "$PROJ_ROOT/src" -type f 2>/dev/null | head -1)" ]; then
    echo "REFRESH"; return 0
  fi
  echo "CREATE"
}

# ── CREATE-mode scaffold: agent/*.md from kit templates ──────────────────────
# Non-destructive: only creates files that are missing or empty (idempotent).
_scaffold_pipeline() {
  mkdir -p "$PROJ_ROOT/agent"
  local pair name tpl created=0
  for pair in \
    "REQS:agent-reqs-template.md" \
    "SPECS:agent-specs-template.md" \
    "PLANS:agent-plans-template.md" \
    "DESIGN:agent-design-template.md" \
    "RESEARCH:agent-research-template.md" \
    "TASKS:agent-tasks-template.md" \
    "AGENT:agent-AGENT-template.md" \
    "AGENT_CONTEXT:agent-AGENT_CONTEXT-template.md" \
    "RELEASES:agent-releases-template.md"; do
    name="${pair%%:*}"; tpl="${pair#*:}"
    local dest="$PROJ_ROOT/agent/$name.md"
    [ -s "$dest" ] && continue   # idempotent — never clobber existing content
    if [ -f "$TEMPLATES_DIR/$tpl" ]; then
      cp "$TEMPLATES_DIR/$tpl" "$dest"
      created=$((created+1))
    else
      printf '# %s\n\n<!-- scaffolded by init CREATE mode — fill from codebase -->\n' "$name" > "$dest"
      created=$((created+1))
    fi
  done
  echo -e "  ${GREEN}✓${NC} CREATE mode: scaffolded $created agent/*.md pipeline file(s) from templates"
}

case "${1:-}" in
  preflight)
    echo -e "${CYAN}═══ Init — Preflight ═══${NC}"

    # E4 — kit-machinery gate (init never pulls source)
    if ! _kit_installed; then
      echo -e "  ${RED}✗${NC} kit not installed — run install first" >&2
      echo -e "     ${YELLOW}init NEVER pulls source.${NC} Install the kit machinery, then re-run init:" >&2
      echo -e "       bash <kit-path>/install.sh --yes --from <kit-path>" >&2
      echo -e "       curl -fsSL https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/install.sh | bash" >&2
      exit 1
    fi
    echo -e "  ${GREEN}✓${NC} kit machinery present (init may proceed)"

    MODE="$(_init_mode)"
    echo -e "  ${CYAN}∘${NC} init mode: ${MODE}"
    if [ "$MODE" = "CREATE" ]; then
      _scaffold_pipeline
    else
      echo -e "  ${GREEN}✓${NC} REFRESH mode: existing pipeline detected — conform in place (no clobber)"
      # E3 — non-destructive REFRESH. Snapshot byte-counts of every agent/*.md so
      # the complete-phase post-check can detect any content loss (folded from the
      # retired reinit content-loss guard). Conform updates/merges, never wipes.
      mkdir -p "$SNAPSHOT_DIR"; rm -f "$SNAPSHOT_DIR"/byte-counts.txt
      for f in "$PROJ_ROOT"/agent/*.md; do
        [ -f "$f" ] || continue
        echo "$(wc -c < "$f" | tr -d ' ') $(basename "$f")" >> "$SNAPSHOT_DIR/byte-counts.txt"
      done
      [ -f "$SNAPSHOT_DIR/byte-counts.txt" ] \
        && echo -e "  ${GREEN}✓${NC} content-loss snapshot taken: $(wc -l < "$SNAPSHOT_DIR/byte-counts.txt" | tr -d ' ') file(s)"
    fi

    # Advisory conformance --check (end-to-end engine run, never fails preflight —
    # the work phase's --conform resolves drift; preflight only reports it).
    echo -e "  ${CYAN}∘${NC} conformance check (advisory):"
    if [ -x "$CONFORMANCE" ]; then
      bash "$CONFORMANCE" --check 2>&1 | sed 's/^/    /' || true
    else
      echo -e "    ${YELLOW}⚠${NC} psk-conformance.sh not found — registry engine unavailable"
    fi

    echo -e "\n${CYAN}Next:${NC} fill/conform agent/*.md per docs/work-flows/05-project-init.md, then: bash agent/scripts/psk-init.sh next"
    exit 0
    ;;
  complete)
    echo -e "${CYAN}═══ Init — Conform (registry-driven) ═══${NC}"
    if [ ! -x "$CONFORMANCE" ]; then
      echo -e "  ${RED}✗${NC} psk-conformance.sh not found — cannot conform" >&2
      exit 1
    fi
    # Run the conformance engine: mechanical fixes inline, sub-agent fixes paused
    # via psk-spawn.sh (§Spawn Fidelity, surfaced as AWAITING by the engine).
    # Exit non-zero ONLY on unresolved mechanical drift (engine contract).
    if ! bash "$CONFORMANCE" --conform; then
      echo -e "  ${RED}✗${NC} unresolved mechanical drift — see conformance output above." >&2
      exit 1
    fi
    echo -e "  ${GREEN}✓${NC} conformance pass complete (mechanical drift resolved)."

    # E3 — content-loss post-check (REFRESH mode). Compare against the preflight
    # byte-count snapshot; any agent/*.md that was deleted or shrank >20% signals
    # a clobber regression (folded from the retired reinit guard).
    if [ -f "$SNAPSHOT_DIR/byte-counts.txt" ]; then
      loss_fail=0
      while read -r old_bytes fname; do
        current="$PROJ_ROOT/agent/$fname"
        if [ ! -f "$current" ]; then
          echo -e "  ${RED}✗${NC} $fname was DELETED during conform (lost $old_bytes bytes)"; loss_fail=$((loss_fail+1)); continue
        fi
        new_bytes=$(wc -c < "$current" | tr -d ' ')
        if [ "$new_bytes" -lt $((old_bytes * 80 / 100)) ]; then
          echo -e "  ${RED}✗${NC} $fname shrank: $old_bytes → $new_bytes bytes (possible content loss)"; loss_fail=$((loss_fail+1))
        fi
      done < "$SNAPSHOT_DIR/byte-counts.txt"
      if [ "$loss_fail" -gt 0 ]; then
        echo -e "\n  ${RED}Content loss detected — review git diff agent/ and restore.${NC}" >&2; exit 1
      fi
      echo -e "  ${GREEN}✓${NC} no content loss vs snapshot (REFRESH was non-destructive)"; rm -rf "$SNAPSHOT_DIR"
    fi

    echo -e "  Run ${CYAN}bash agent/scripts/psk-init.sh next${NC} to advance to the validation gate."
    exit 0
    ;;
  ""|init)
    exec bash "$SCRIPT_DIR/psk-dispatch.sh" init
    ;;
  *)
    # Forward dispatcher verbs (next / status / resume / retry / done / abandon / --validate ...)
    exec bash "$SCRIPT_DIR/psk-dispatch.sh" init "$@"
    ;;
esac
