#!/bin/bash
# mechanical-script: psk-ui-polish-check.sh — frontend completeness probe (no AI invocation)
# ════════════════════════════════════════════════════════════════
# psk-ui-polish-check.sh — UI Polish Drift Detection (v0.6.23+, ADR-034)
#
# Scans implementation against kit's UI design system requirements.
# Verifies every UI-bearing project has: loading + empty + error states ·
# aria attributes for a11y · global error boundary · skip-link · dark-mode
# toggle · onboarding component · brand assets.
#
# Runs as part of /optimize cat 13 OR standalone for project-side audit.
#
# Usage:
#   bash agent/scripts/psk-ui-polish-check.sh [--json|--health]
# Bypass: PSK_UI_POLISH_DISABLED=1
# ════════════════════════════════════════════════════════════════

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
MODE="${1:---scan}"

if [ "${PSK_UI_POLISH_DISABLED:-0}" = "1" ]; then
  case "$MODE" in
    --json) echo '{"status":"disabled","gaps":[]}' ;;
    *) echo "ui-polish-check disabled (PSK_UI_POLISH_DISABLED=1)" ;;
  esac
  exit 0
fi

# Detect if project has a UI surface (Next.js/React/Vue indicator)
HAS_UI=0
[ -f "$PROJ_ROOT/package.json" ] && grep -qE '"(next|react|vue|svelte|nuxt)"' "$PROJ_ROOT/package.json" 2>/dev/null && HAS_UI=1
[ -d "$PROJ_ROOT/src/app" ] || [ -d "$PROJ_ROOT/pages" ] || [ -d "$PROJ_ROOT/src/components" ] && HAS_UI=1

if [ "$HAS_UI" -eq 0 ]; then
  case "$MODE" in
    --json) echo '{"status":"no-ui","reason":"No UI framework detected","gaps":[]}' ;;
    --health) echo "🟢 ui-polish: no UI surface detected (skipped)" ;;
    *) echo "No UI framework detected — psk-ui-polish-check.sh skipped" ;;
  esac
  exit 0
fi

# UI polish checks — each gap is one finding
GAPS=()

# 1. Loading state component
if ! find "$PROJ_ROOT/src" \( -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" \) -print0 2>/dev/null | xargs -0 grep -lE "Skeleton|LoadingState|Loader" 2>/dev/null | head -1 > /dev/null; then
  GAPS+=("loading-state:no-Skeleton-or-LoadingState-component-found")
fi

# 2. Empty state component
if ! find "$PROJ_ROOT/src" \( -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" \) -print0 2>/dev/null | xargs -0 grep -lE "EmptyState|empty-state|emptyState" 2>/dev/null | head -1 > /dev/null; then
  GAPS+=("empty-state:no-EmptyState-component-found")
fi

# 3. Error boundary
if ! find "$PROJ_ROOT/src" -name "error.tsx" -o -name "ErrorBoundary*" 2>/dev/null | head -1 > /dev/null; then
  GAPS+=("error-boundary:no-error.tsx-or-ErrorBoundary-component")
fi

# 4. Skip-to-main-content link
if ! find "$PROJ_ROOT/src" \( -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" \) -print0 2>/dev/null | xargs -0 grep -lE "skip.*main|skipNav|SkipLink" 2>/dev/null | head -1 > /dev/null; then
  GAPS+=("skip-link:no-skip-to-main-content-link-for-keyboard-nav")
fi

# 5. Dark mode toggle component
if ! find "$PROJ_ROOT/src" \( -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" \) -print0 2>/dev/null | xargs -0 grep -lE "ThemeToggle|DarkMode|darkMode" 2>/dev/null | head -1 > /dev/null; then
  GAPS+=("dark-mode-toggle:no-manual-theme-toggle-component-found")
fi

# 6. Onboarding component
if ! find "$PROJ_ROOT/src" \( -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" \) -print0 2>/dev/null | xargs -0 grep -lE "Onboarding|Tour|onboarding" 2>/dev/null | head -1 > /dev/null; then
  GAPS+=("onboarding:no-onboarding-component-found")
fi

# 7. Brand assets in public/
if [ ! -d "$PROJ_ROOT/public" ] || [ -z "$(ls -A "$PROJ_ROOT/public" 2>/dev/null | grep -E '\.(svg|png|ico)$' | head -1)" ]; then
  GAPS+=("brand-assets:public/-folder-empty-or-missing-brand-assets")
fi

# 8. ARIA-live region for status messages
if ! find "$PROJ_ROOT/src" \( -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" \) -print0 2>/dev/null | xargs -0 grep -lE 'aria-live' 2>/dev/null | head -1 > /dev/null; then
  GAPS+=("aria-live:no-aria-live-regions-for-screen-reader-status")
fi

GAP_COUNT=${#GAPS[@]}

case "$MODE" in
  --json)
    echo "{"
    echo "  \"schema_version\": 1,"
    echo "  \"scanned_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"has_ui\": true,"
    echo "  \"gap_count\": $GAP_COUNT,"
    echo "  \"gaps\": ["
    local first=true
    for gap in "${GAPS[@]}"; do
      [ "$first" = true ] && first=false || echo ","
      kind="${gap%%:*}"
      desc="${gap#*:}"
      printf "    {\"kind\":\"%s\",\"description\":\"%s\"}" "$kind" "$desc"
    done
    echo ""
    echo "  ]"
    echo "}"
    ;;
  --health)
    if [ "$GAP_COUNT" -eq 0 ]; then
      echo "🟢 ui-polish: 0 gaps (all 8 client-grade UI elements present)"
    elif [ "$GAP_COUNT" -le 2 ]; then
      echo "🟡 ui-polish: $GAP_COUNT gap(s) — minor polish drift"
    else
      echo "🔴 ui-polish: $GAP_COUNT gap(s) — UI not client-grade per P8 Client-Grade Output"
    fi
    ;;
  *)
    echo "═══════════════════════════════════════════════════════════"
    echo "  PSK UI Polish Check (v0.6.23+) — Client-Grade Output guarantee"
    echo "═══════════════════════════════════════════════════════════"
    echo "Project: $PROJ_ROOT"
    echo "UI surface detected: yes"
    echo "Gaps found: $GAP_COUNT / 8 client-grade elements"
    echo ""
    if [ "$GAP_COUNT" -gt 0 ]; then
      echo "Missing client-grade UI elements:"
      for gap in "${GAPS[@]}"; do
        echo "  ✗ ${gap/:/ → }"
      done
      echo ""
      echo "Per PHILOSOPHY.md P8 (Client-Grade Output by Default), these"
      echo "elements should be present in any project shipping a UI to clients."
      echo "Bypass: PSK_UI_POLISH_DISABLED=1"
    else
      echo "✓ All 8 client-grade UI elements present"
    fi
    ;;
esac

exit 0
