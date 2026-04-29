#!/bin/bash
# =============================================================
# psk-existing-setup.sh — Existing Project Setup Orchestrator
#
# Preflight: snapshot existing non-kit files so post-setup check
# can detect destructive modification. Final gate is dual critic.
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

SNAPSHOT_DIR="$PROJ_ROOT/agent/.existing-setup-snapshot"
MODE="${1:-complete}"

case "$MODE" in
  start)
    echo -e "${CYAN}═══ Existing Project Setup — Preflight ═══${NC}"

    # Preflight 1: project actually has existing code
    src_count=$(find "$PROJ_ROOT" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" -o -name "*.rb" -o -name "*.java" \) 2>/dev/null | grep -v node_modules | grep -v __pycache__ | wc -l | tr -d ' ')
    if [ "$src_count" -lt 1 ]; then
      echo -e "  ${YELLOW}⚠${NC} No source files found — consider new-setup instead"
    else
      echo -e "  ${GREEN}✓${NC} $src_count source file(s) detected"
    fi

    # Preflight 2: snapshot file list + sizes of non-kit files (to detect destructive edits)
    mkdir -p "$SNAPSHOT_DIR"
    rm -f "$SNAPSHOT_DIR/manifest.txt"
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

    # Preflight 3: warn if README already exists (won't overwrite)
    if [ -f "$PROJ_ROOT/README.md" ]; then
      echo -e "  ${GREEN}✓${NC} README.md already exists — kit will augment not overwrite"
    fi

    echo -e "\n${CYAN}Next:${NC} retroactively fill agent/*.md per docs/work-flows/04-existing-project-setup.md"
    echo -e "${CYAN}Then:${NC} bash agent/scripts/psk-existing-setup.sh complete"
    ;;

  complete)
    echo -e "${CYAN}═══ Existing Project Setup — Destructive Check + Final Gate ═══${NC}"

    # Post-check: any existing non-kit file that CHANGED size by >10% is suspicious
    if [ -f "$SNAPSHOT_DIR/manifest.txt" ]; then
      suspect=0
      while read -r old_sz relpath; do
        current="$PROJ_ROOT/$relpath"
        if [ ! -f "$current" ]; then
          echo -e "  ${RED}✗${NC} $relpath was DELETED (was $old_sz bytes)"
          suspect=$((suspect + 1))
          continue
        fi
        new_sz=$(wc -c < "$current" | tr -d ' ')
        diff=$(( new_sz > old_sz ? new_sz - old_sz : old_sz - new_sz ))
        # Allow 10% drift for whitespace etc; flag anything larger
        if [ "$old_sz" -gt 100 ] && [ "$diff" -gt $((old_sz / 10)) ]; then
          echo -e "  ${YELLOW}⚠${NC} $relpath size changed: $old_sz → $new_sz (>10% drift — confirm intentional)"
          suspect=$((suspect + 1))
        fi
      done < "$SNAPSHOT_DIR/manifest.txt"

      if [ "$suspect" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠${NC} $suspect existing file(s) modified — existing-setup should be non-destructive"
        echo -e "  ${YELLOW}  Review git diff and confirm each edit was intentional.${NC}"
      else
        echo -e "  ${GREEN}✓${NC} No destructive modifications detected"
      fi
      rm -rf "$SNAPSHOT_DIR"
    else
      echo -e "  ${YELLOW}⚠${NC} No snapshot — run psk-existing-setup.sh start first for destructive-edit protection"
    fi

    bash "$SCRIPT_DIR/psk-validate.sh" existing-setup
    exit $?
    ;;

  *)
    echo "Usage: bash psk-existing-setup.sh [start|complete]"
    exit 4
    ;;
esac
