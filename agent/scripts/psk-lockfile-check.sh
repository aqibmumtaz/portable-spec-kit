#!/bin/bash
# mechanical-script: psk-lockfile-check.sh — manifest presence + lock-file freshness
# script-class: helper
# =============================================================
# psk-lockfile-check.sh — Manifest + lock-file freshness/auto-regenerate
#
# Extracted from psk-release.sh Step 5 (v0.6.62 release-workflow migration) so
# the dispatcher-driven release declaration (release/phases.yml step-5-counts)
# can invoke the SAME logic the monolithic release ran inline. Behavior is
# byte-for-byte preserved — this is a move, not a rewrite.
#
# What it does (advisory, NON-BLOCKING — always exits 0):
#   1. Manifest check — for each detected stack (psk-env.sh detect), verify the
#      stack's manifest is present (package.json / requirements.txt|pyproject /
#      Gemfile / go.mod / Cargo.toml). Missing manifests are reported, advisory.
#   2. Lock-file freshness — when a manifest is NEWER than its lock file the lock
#      is stale; auto-regenerate to keep the project reproducible. Manifests are
#      NEVER auto-modified (human judgment for version bumps); only lock files
#      (deterministic from manifest). Each regenerate runs inside the project's
#      saved env via psk-env.sh activate-cmd <stack>. Failures are advisory.
#
# Usage:  bash agent/scripts/psk-lockfile-check.sh
# Exit:   always 0 (advisory; never blocks a release)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -t 1 ]; then
  CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
  CYAN=''; GREEN=''; YELLOW=''; NC=''
fi

env_sh="$SCRIPT_DIR/psk-env.sh"
if [ ! -x "$env_sh" ]; then
  echo -e "${YELLOW}  psk-env.sh not found — skipping manifest + lock-file check${NC}"
  exit 0
fi

echo ""
echo -e "${CYAN}  Manifest check (advisory):${NC}"
detected_stacks=$(bash "$env_sh" detect 2>/dev/null)
missing_manifests=0
if [ -z "$detected_stacks" ]; then
  echo -e "${GREEN}    ✓ No runtime stack detected (kit-only / docs-only project)${NC}"
else
  while IFS= read -r stack; do
    [ -z "$stack" ] && continue
    case "$stack" in
      python)
        if [ -f "$PROJ_ROOT/requirements.txt" ] || [ -f "$PROJ_ROOT/pyproject.toml" ] || [ -f "$PROJ_ROOT/setup.py" ] || [ -f "$PROJ_ROOT/Pipfile" ]; then
          echo -e "${GREEN}    ✓ python: manifest present${NC}"
        else
          echo -e "${YELLOW}    ⚠ python: detected but no manifest (requirements.txt / pyproject.toml / setup.py / Pipfile)${NC}"
          missing_manifests=$((missing_manifests + 1))
        fi ;;
      node)
        if [ -f "$PROJ_ROOT/package.json" ]; then
          echo -e "${GREEN}    ✓ node: package.json present${NC}"
        else
          echo -e "${YELLOW}    ⚠ node: detected but no package.json${NC}"
          missing_manifests=$((missing_manifests + 1))
        fi ;;
      ruby)   [ -f "$PROJ_ROOT/Gemfile" ]    && echo -e "${GREEN}    ✓ ruby: Gemfile present${NC}"    || { echo -e "${YELLOW}    ⚠ ruby: no Gemfile${NC}";    missing_manifests=$((missing_manifests + 1)); } ;;
      go)     [ -f "$PROJ_ROOT/go.mod" ]     && echo -e "${GREEN}    ✓ go: go.mod present${NC}"     || { echo -e "${YELLOW}    ⚠ go: no go.mod${NC}";     missing_manifests=$((missing_manifests + 1)); } ;;
      rust)   [ -f "$PROJ_ROOT/Cargo.toml" ] && echo -e "${GREEN}    ✓ rust: Cargo.toml present${NC}" || { echo -e "${YELLOW}    ⚠ rust: no Cargo.toml${NC}"; missing_manifests=$((missing_manifests + 1)); } ;;
    esac
  done <<< "$detected_stacks"
fi
if [ "$missing_manifests" -gt 0 ]; then
  echo -e "${YELLOW}    Total missing manifests: $missing_manifests (advisory; non-blocking)${NC}"
fi

# Lock-file freshness check + auto-regenerate per stack (v0.6.14).
if [ -n "$detected_stacks" ]; then
  echo ""
  echo -e "${CYAN}  Lock-file freshness (auto-regenerate when stale):${NC}"
  stale_count=0; regenerated=0
  while IFS= read -r stack; do
    [ -z "$stack" ] && continue
    prefix=$(bash "$env_sh" activate-cmd "$stack" 2>/dev/null)
    case "$stack" in
      node)
        manifest="$PROJ_ROOT/package.json"
        lock="$PROJ_ROOT/package-lock.json"
        if [ -f "$manifest" ] && [ -f "$lock" ] && [ "$lock" -ot "$manifest" ]; then
          echo -e "${YELLOW}    ⚠ node: package-lock.json is older than package.json — regenerating...${NC}"
          if (cd "$PROJ_ROOT" && bash -c "$prefix npm install --package-lock-only --legacy-peer-deps" >/dev/null 2>&1); then
            echo -e "${GREEN}    ✓ node: package-lock.json regenerated${NC}"
            regenerated=$((regenerated + 1))
          else
            echo -e "${YELLOW}      regenerate failed — run 'npm install' manually${NC}"
          fi
          stale_count=$((stale_count + 1))
        elif [ -f "$lock" ]; then
          echo -e "${GREEN}    ✓ node: package-lock.json fresh${NC}"
        elif [ -f "$manifest" ]; then
          echo -e "${YELLOW}    ⚠ node: package.json present but no package-lock.json — run 'npm install' to generate${NC}"
        fi ;;
      python)
        # Python lock-file conventions vary by manager — only auto-update
        # when the manager is known. Otherwise just report staleness.
        if [ -f "$PROJ_ROOT/poetry.lock" ] && [ -f "$PROJ_ROOT/pyproject.toml" ] && [ "$PROJ_ROOT/poetry.lock" -ot "$PROJ_ROOT/pyproject.toml" ]; then
          echo -e "${YELLOW}    ⚠ python: poetry.lock stale — regenerating...${NC}"
          if (cd "$PROJ_ROOT" && bash -c "$prefix poetry lock --no-update" >/dev/null 2>&1); then
            echo -e "${GREEN}    ✓ python: poetry.lock regenerated${NC}"
            regenerated=$((regenerated + 1))
          else
            echo -e "${YELLOW}      regenerate failed — run 'poetry lock' manually${NC}"
          fi
          stale_count=$((stale_count + 1))
        elif [ -f "$PROJ_ROOT/uv.lock" ] && [ -f "$PROJ_ROOT/pyproject.toml" ] && [ "$PROJ_ROOT/uv.lock" -ot "$PROJ_ROOT/pyproject.toml" ]; then
          echo -e "${YELLOW}    ⚠ python: uv.lock stale — regenerating...${NC}"
          if (cd "$PROJ_ROOT" && bash -c "$prefix uv lock" >/dev/null 2>&1); then
            echo -e "${GREEN}    ✓ python: uv.lock regenerated${NC}"
            regenerated=$((regenerated + 1))
          else
            echo -e "${YELLOW}      regenerate failed — run 'uv lock' manually${NC}"
          fi
          stale_count=$((stale_count + 1))
        elif [ -f "$PROJ_ROOT/Pipfile.lock" ] && [ -f "$PROJ_ROOT/Pipfile" ] && [ "$PROJ_ROOT/Pipfile.lock" -ot "$PROJ_ROOT/Pipfile" ]; then
          echo -e "${YELLOW}    ⚠ python: Pipfile.lock stale — run 'pipenv lock'${NC}"
          stale_count=$((stale_count + 1))
        elif [ -f "$PROJ_ROOT/requirements.txt" ]; then
          echo -e "${GREEN}    ✓ python: requirements.txt present (no lock-file convention for plain pip)${NC}"
        else
          echo -e "${GREEN}    ✓ python: no lock-file staleness detected${NC}"
        fi ;;
      ruby)
        if [ -f "$PROJ_ROOT/Gemfile.lock" ] && [ -f "$PROJ_ROOT/Gemfile" ] && [ "$PROJ_ROOT/Gemfile.lock" -ot "$PROJ_ROOT/Gemfile" ]; then
          echo -e "${YELLOW}    ⚠ ruby: Gemfile.lock stale — regenerating...${NC}"
          if (cd "$PROJ_ROOT" && bash -c "$prefix bundle install --quiet" >/dev/null 2>&1); then
            echo -e "${GREEN}    ✓ ruby: Gemfile.lock regenerated${NC}"
            regenerated=$((regenerated + 1))
          else
            echo -e "${YELLOW}      regenerate failed — run 'bundle install' manually${NC}"
          fi
          stale_count=$((stale_count + 1))
        elif [ -f "$PROJ_ROOT/Gemfile" ]; then
          echo -e "${GREEN}    ✓ ruby: Gemfile.lock fresh (or absent — first install)${NC}"
        fi ;;
      go)
        if [ -f "$PROJ_ROOT/go.mod" ]; then
          # go.sum is the lock; `go mod tidy` regenerates it
          if [ -f "$PROJ_ROOT/go.sum" ] && [ "$PROJ_ROOT/go.sum" -ot "$PROJ_ROOT/go.mod" ]; then
            echo -e "${YELLOW}    ⚠ go: go.sum stale — running 'go mod tidy'...${NC}"
            if (cd "$PROJ_ROOT" && bash -c "$prefix go mod tidy" >/dev/null 2>&1); then
              echo -e "${GREEN}    ✓ go: go.sum regenerated${NC}"
              regenerated=$((regenerated + 1))
            else
              echo -e "${YELLOW}      regenerate failed — run 'go mod tidy' manually${NC}"
            fi
            stale_count=$((stale_count + 1))
          else
            echo -e "${GREEN}    ✓ go: go.sum fresh${NC}"
          fi
        fi ;;
      rust)
        if [ -f "$PROJ_ROOT/Cargo.lock" ] && [ -f "$PROJ_ROOT/Cargo.toml" ] && [ "$PROJ_ROOT/Cargo.lock" -ot "$PROJ_ROOT/Cargo.toml" ]; then
          echo -e "${YELLOW}    ⚠ rust: Cargo.lock stale — running 'cargo update --workspace'...${NC}"
          if (cd "$PROJ_ROOT" && bash -c "$prefix cargo update --workspace" >/dev/null 2>&1); then
            echo -e "${GREEN}    ✓ rust: Cargo.lock regenerated${NC}"
            regenerated=$((regenerated + 1))
          else
            echo -e "${YELLOW}      regenerate failed — run 'cargo update' manually${NC}"
          fi
          stale_count=$((stale_count + 1))
        elif [ -f "$PROJ_ROOT/Cargo.toml" ]; then
          echo -e "${GREEN}    ✓ rust: Cargo.lock fresh${NC}"
        fi ;;
    esac
  done <<< "$detected_stacks"
  if [ "$stale_count" -gt 0 ]; then
    echo -e "${CYAN}    Stale lock files: $stale_count detected, $regenerated auto-regenerated${NC}"
    if [ "$regenerated" -gt 0 ]; then
      echo -e "${YELLOW}    → review the regenerated lock file diff + commit before push${NC}"
    fi
  fi
fi

exit 0
