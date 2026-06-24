#!/usr/bin/env bash
# mechanical-script: regenerate install.sh manifests from disk reality.
# doc-coverage-exempt: internal mechanical helper — no user-facing R->F->T claim
#
# Writes two committed manifests the network installer (curl path) reads so it
# never drifts from disk:
#   agent/scripts/.manifest   — every psk-*.sh (required|optional)
#   reflex/lib/.manifest      — every reflex/lib helper (.sh/.ts/.js/.mjs/.py)
#
# Idempotent: run anytime a script is added/removed/renamed. PSK036 sync-check
# fails when these manifests drift from disk, so this is the remediation command.
set -euo pipefail

# Resolve project root (parent of agent/scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJ_ROOT"

scripts_manifest="agent/scripts/.manifest"
lib_manifest="reflex/lib/.manifest"

# --- agent/scripts/.manifest ---
{
  echo "# Manifest of agent/scripts/ files install.sh must fetch. Generated from disk."
  echo "# Format: <filename> <required|optional>. Regenerate: bash agent/scripts/psk-gen-manifest.sh"
  echo "# Sync-check rule PSK036 fails when this manifest drifts from disk reality."
  for f in $(find agent/scripts -maxdepth 1 -name 'psk-*.sh' -type f -print0 2>/dev/null | xargs -0 -n1 basename | sort); do
    case "$f" in
      psk-jira-sync.sh|psk-tracker.sh|psk-tracker-report.sh) echo "$f optional" ;;
      *) echo "$f required" ;;
    esac
  done
} > "$scripts_manifest"

# --- reflex/lib/.manifest ---
if [ -d reflex/lib ]; then
  {
    echo "# Manifest of reflex/lib/ helper files install.sh must fetch. Generated from disk."
    echo "# Format: <filename>. Regenerate: bash agent/scripts/psk-gen-manifest.sh"
    echo "# Sync-check rule PSK036 fails when this manifest drifts from disk reality."
    find reflex/lib -maxdepth 1 -type f \
      \( -name '*.sh' -o -name '*.ts' -o -name '*.js' -o -name '*.mjs' -o -name '*.py' \) \
      | xargs -n1 basename | sort
  } > "$lib_manifest"
fi

echo "[psk-gen-manifest] $scripts_manifest: $(grep -cvE '^#' "$scripts_manifest") entries"
[ -f "$lib_manifest" ] && echo "[psk-gen-manifest] $lib_manifest: $(grep -cvE '^#' "$lib_manifest") entries"
