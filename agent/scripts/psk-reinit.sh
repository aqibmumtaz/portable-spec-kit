#!/bin/bash
# =============================================================
# psk-reinit.sh — Reinit Workflow Orchestrator
# Workflow doc: docs/work-flows/05-project-init.md
#
# Preflight: snapshot current agent/* byte counts so post-reinit
# dual gate can detect content loss. Final gate is dual critic.
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

SNAPSHOT_DIR="$PROJ_ROOT/agent/.reinit-snapshot"
MODE="${1:-complete}"

case "$MODE" in
  start)
    echo -e "${CYAN}═══ Reinit — Preflight ═══${NC}"

    # Preflight 1: agent/ must exist with content (else this should be init)
    if [ ! -d "$PROJ_ROOT/agent" ] || [ -z "$(ls -A "$PROJ_ROOT/agent"/*.md 2>/dev/null)" ]; then
      echo -e "  ${RED}✗${NC} agent/*.md files missing — use init instead of reinit"
      exit 1
    fi

    # Preflight 2: snapshot byte counts of existing agent/*.md
    mkdir -p "$SNAPSHOT_DIR"
    rm -f "$SNAPSHOT_DIR"/*
    for f in "$PROJ_ROOT"/agent/*.md; do
      [ -f "$f" ] || continue
      echo "$(wc -c < "$f" | tr -d ' ') $(basename "$f")" >> "$SNAPSHOT_DIR/byte-counts.txt"
    done
    echo -e "  ${GREEN}✓${NC} Snapshot taken: $(wc -l < "$SNAPSHOT_DIR/byte-counts.txt" | tr -d ' ') file(s)"

    # Preflight 3: git status clean (so any loss is visible in diff)
    if [ -n "$(cd "$PROJ_ROOT" && git status --porcelain agent/ 2>/dev/null)" ]; then
      echo -e "  ${YELLOW}⚠${NC} agent/ has uncommitted changes — content-loss detection less reliable"
    else
      echo -e "  ${GREEN}✓${NC} agent/ is clean in git — post-reinit diff will be visible"
    fi

    echo -e "\n${CYAN}Next:${NC} do the reinit work (re-sync agent/*.md from codebase)"
    echo -e "${CYAN}Then:${NC} bash agent/scripts/psk-reinit.sh complete"
    ;;

  complete)
    echo -e "${CYAN}═══ Reinit — Post-check + Final Gate ═══${NC}"

    # Post-check: compare byte counts against snapshot
    if [ -f "$SNAPSHOT_DIR/byte-counts.txt" ]; then
      local_fail=0
      while read -r old_bytes fname; do
        current="$PROJ_ROOT/agent/$fname"
        if [ ! -f "$current" ]; then
          echo -e "  ${RED}✗${NC} $fname was DELETED by reinit (lost $old_bytes bytes)"
          local_fail=$((local_fail + 1))
          continue
        fi
        new_bytes=$(wc -c < "$current" | tr -d ' ')
        # Allow growth; flag if reinit REDUCED byte count by more than 20%
        if [ "$new_bytes" -lt $((old_bytes * 80 / 100)) ]; then
          echo -e "  ${RED}✗${NC} $fname shrank: $old_bytes → $new_bytes bytes (possible content loss)"
          local_fail=$((local_fail + 1))
        fi
      done < "$SNAPSHOT_DIR/byte-counts.txt"

      if [ "$local_fail" -gt 0 ]; then
        echo -e "\n${RED}Content loss detected — review git diff agent/ and restore.${NC}"
        exit 1
      fi
      echo -e "  ${GREEN}✓${NC} No content loss detected vs snapshot"
      rm -rf "$SNAPSHOT_DIR"
    else
      echo -e "  ${YELLOW}⚠${NC} No snapshot found — run psk-reinit.sh start first for content-loss protection"
    fi

    bash "$SCRIPT_DIR/psk-validate.sh" reinit
    exit $?
    ;;

  *)
    echo "Usage: bash psk-reinit.sh [start|complete]"
    exit 4
    ;;
esac
