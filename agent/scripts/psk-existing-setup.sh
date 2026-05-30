#!/bin/bash
# workflow-router: psk-existing-setup.sh — existing-project setup (non-destructive retrofit)
# workflow-decl: .portable-spec-kit/workflows/existing-setup/phases.yml
# =============================================================
# psk-existing-setup.sh — Existing Project Setup (dispatcher-driven, v0.6.62+)
#
# Dual-mode router:
#   • bash psk-existing-setup.sh           → delegate to psk-dispatch.sh existing-setup
#   • bash psk-existing-setup.sh preflight  → src check + snapshot non-kit files (destructive-edit guard)
#   • bash psk-existing-setup.sh fill       → post-check vs snapshot (destructive-edit detection)
#   • bash psk-existing-setup.sh <verb> ... → forward dispatcher verbs
#
# Phase sequence + gates live in the declaration; psk-dispatch.sh is the executor.
#
# §Workflow Fidelity (portable-spec-kit.md): this is an executable kit workflow.
# It executes its declared phases faithfully and completely via psk-dispatch.sh —
# no phase compression, no inline substitution, no scope reduction under pressure.
# Pause-and-resume, never reduce-scope.
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
SNAPSHOT_DIR="$PROJ_ROOT/agent/.existing-setup-snapshot"

case "${1:-}" in
  preflight)
    echo -e "${CYAN}═══ Existing Project Setup — Preflight ═══${NC}"
    src_count=$(find "$PROJ_ROOT" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" -o -name "*.rb" -o -name "*.java" \) 2>/dev/null | grep -v node_modules | grep -v __pycache__ | wc -l | tr -d ' ')
    if [ "$src_count" -lt 1 ]; then
      echo -e "  ${YELLOW}⚠${NC} No source files found — consider new-setup instead"
    else
      echo -e "  ${GREEN}✓${NC} $src_count source file(s) detected"
    fi
    mkdir -p "$SNAPSHOT_DIR"; rm -f "$SNAPSHOT_DIR/manifest.txt"
    find "$PROJ_ROOT" -maxdepth 3 -type f \
      ! -path "*/node_modules/*" ! -path "*/__pycache__/*" ! -path "*/.git/*" \
      ! -path "*/agent/*" ! -path "*/.portable-spec-kit/*" \
      ! -name ".bypass-log" ! -name "portable-spec-kit.md" ! -name "CLAUDE.md" \
      ! -name ".cursorrules" ! -name ".windsurfrules" ! -name ".clinerules" \
      2>/dev/null | while read -r f; do
      sz=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
      echo "$sz $(echo "$f" | sed "s|$PROJ_ROOT/||")"
    done | sort > "$SNAPSHOT_DIR/manifest.txt"
    echo -e "  ${GREEN}✓${NC} Snapshot: $(wc -l < "$SNAPSHOT_DIR/manifest.txt" | tr -d ' ') existing file(s) protected"
    [ -f "$PROJ_ROOT/README.md" ] && echo -e "  ${GREEN}✓${NC} README.md exists — kit will augment not overwrite"
    echo -e "\n${CYAN}Next:${NC} retroactively fill agent/*.md per docs/work-flows/04-existing-project-setup.md, then: bash agent/scripts/psk-existing-setup.sh fill && bash agent/scripts/psk-existing-setup.sh next"
    exit 0
    ;;
  fill)
    echo -e "${CYAN}═══ Existing Project Setup — Destructive Check ═══${NC}"
    if [ -f "$SNAPSHOT_DIR/manifest.txt" ]; then
      suspect=0
      while read -r old_sz relpath; do
        current="$PROJ_ROOT/$relpath"
        if [ ! -f "$current" ]; then
          echo -e "  ${RED}✗${NC} $relpath was DELETED (was $old_sz bytes)"; suspect=$((suspect+1)); continue
        fi
        new_sz=$(wc -c < "$current" | tr -d ' ')
        diff=$(( new_sz > old_sz ? new_sz - old_sz : old_sz - new_sz ))
        if [ "$old_sz" -gt 100 ] && [ "$diff" -gt $((old_sz / 10)) ]; then
          echo -e "  ${YELLOW}⚠${NC} $relpath size changed: $old_sz → $new_sz (>10% drift — confirm intentional)"; suspect=$((suspect+1))
        fi
      done < "$SNAPSHOT_DIR/manifest.txt"
      if [ "$suspect" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠${NC} $suspect existing file(s) modified — review git diff (existing-setup should be non-destructive)."
      else
        echo -e "  ${GREEN}✓${NC} No destructive modifications detected"
      fi
      rm -rf "$SNAPSHOT_DIR"
    else
      echo -e "  ${YELLOW}⚠${NC} No snapshot — run psk-existing-setup.sh preflight first for destructive-edit protection"
    fi
    echo -e "  Run ${CYAN}bash agent/scripts/psk-existing-setup.sh next${NC} to advance to the validation gate."
    exit 0
    ;;
  ""|existing-setup)
    exec bash "$SCRIPT_DIR/psk-dispatch.sh" existing-setup
    ;;
  *)
    exec bash "$SCRIPT_DIR/psk-dispatch.sh" existing-setup "$@"
    ;;
esac
