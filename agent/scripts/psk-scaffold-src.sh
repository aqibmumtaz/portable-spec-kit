#!/bin/bash
# mechanical-script: psk-scaffold-src.sh — src/ subdir scaffolder (no AI invocation)
# psk-scaffold-src.sh — Create opt-in src/ layered subdirs based on Stack table
#
# Reads agent/PLANS.md Stack table → derives required subdirs → creates them
# under src/ with README.md from src-subdir-readme-template.md.
#
# Always-on subdirs: core/, shared/
# Opt-in subdirs (gated on Stack):
#   ui/         — Stack declares any frontend framework
#   api/        — Stack declares any HTTP server / route handler
#   integrations/  — Stack declares any 3rd-party service or AI
#   platform/   — Stack declares any admin panel / RBAC / multi-tenant
#
# Usage:
#   psk-scaffold-src.sh <project-root>          # init mode (creates missing)
#   psk-scaffold-src.sh <project-root> --check  # report-only, no writes
#
# Exit codes:
#   0  layout created / verified
#   1  PLANS.md missing or unparseable
#   2  usage error

set -eo pipefail   # -e: exit on error; -o pipefail: catch failures through pipes too

PROJ_ROOT="${1:-}"
MODE="${2:-init}"

[ -z "$PROJ_ROOT" ] && { echo "usage: psk-scaffold-src.sh <project-root> [--check]" >&2; exit 2; }
[ ! -d "$PROJ_ROOT" ] && { echo "project root not found: $PROJ_ROOT" >&2; exit 2; }
[ ! -f "$PROJ_ROOT/agent/PLANS.md" ] && { echo "agent/PLANS.md missing" >&2; exit 1; }

PLANS="$PROJ_ROOT/agent/PLANS.md"
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE="$KIT_ROOT/.portable-spec-kit/templates/src-subdir-readme-template.md"

# Detect Stack signals from PLANS.md (case-insensitive grep)
_has() {
  grep -qi -E "$1" "$PLANS"
}

NEEDS_UI=0
NEEDS_API=0
NEEDS_INTEGRATIONS=0
NEEDS_PLATFORM=0

# Frontend frameworks → ui/
_has 'next\.js|react|vue|angular|svelte|astro|nuxt|remix' && NEEDS_UI=1

# Backend HTTP servers → api/
_has 'next\.js|fastapi|django|express|flask|hono|rails|gin|echo|spring' && NEEDS_API=1

# 3rd-party integrations → integrations/
_has 'twilio|stripe|openai|anthropic|claude|gpt|grok|gemini|s3|sendgrid|whatsapp' && NEEDS_INTEGRATIONS=1

# Admin / RBAC / multi-tenant → platform/
_has 'admin panel|rbac|role-based|multi-tenant|multi-role|billing' && NEEDS_PLATFORM=1

# Required (always)
REQUIRED_SUBDIRS=(core shared)

# Build full list
SUBDIRS=("${REQUIRED_SUBDIRS[@]}")
[ "$NEEDS_UI" = 1 ] && SUBDIRS+=(ui)
[ "$NEEDS_API" = 1 ] && SUBDIRS+=(api)
[ "$NEEDS_INTEGRATIONS" = 1 ] && SUBDIRS+=(integrations)
[ "$NEEDS_PLATFORM" = 1 ] && SUBDIRS+=(platform)

if [ "$MODE" = "--check" ]; then
  echo "expected src/ subdirs: ${SUBDIRS[*]}"
  for d in "${SUBDIRS[@]}"; do
    if [ -d "$PROJ_ROOT/src/$d" ]; then
      echo "  ✓ src/$d/ exists"
    else
      echo "  ✗ src/$d/ missing"
    fi
  done
  exit 0
fi

# Init mode — create missing
mkdir -p "$PROJ_ROOT/src"
for d in "${SUBDIRS[@]}"; do
  if [ ! -d "$PROJ_ROOT/src/$d" ]; then
    mkdir -p "$PROJ_ROOT/src/$d"
    if [ -f "$TEMPLATE" ]; then
      cp "$TEMPLATE" "$PROJ_ROOT/src/$d/README.md"
      # Replace <subdir> placeholder
      sed -i.bak "s/<subdir>/$d/g" "$PROJ_ROOT/src/$d/README.md"
      rm -f "$PROJ_ROOT/src/$d/README.md.bak"
    fi
    echo "  created src/$d/"
  fi
done

echo "src/ layout scaffolded: ${SUBDIRS[*]}"
