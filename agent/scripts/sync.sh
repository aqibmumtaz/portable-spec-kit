#!/bin/bash
# mechanical-script: deterministic, no AI prompts (Dim 28 allowlist — v0.6.60 HF7b)
# QA-7-01 (cycle-01-pass-001): declare shell error-handling options, matching the
# kit's dominant convention (59/60 scripts use `set -uo pipefail`). sync.sh is the
# repo-sync / release-publishing surface (git push + tag/release updates) where an
# unset variable or a silently-failing intermediate step has the highest blast
# radius — so error hygiene matters most here.
set -uo pipefail
# Sync portable-spec-kit to GitHub repo
# Usage: bash agent/scripts/sync.sh "commit message"
# Run from: Projects/portable-spec-kit/
#
# GitHub releases: auto-created/updated on every push.
# Release version read from agent/AGENT_CONTEXT.md (e.g. v0.3).
# Notes extracted from CHANGELOG.md for that version.
# Requires: gh auth login (one-time setup).

PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
TEMP="/tmp/portable-spec-kit-sync"

echo "=== Syncing Portable Spec Kit ==="

# 1. Copy latest portable-spec-kit.md from workspace root → Projects + examples
cp "$PROJ/../../portable-spec-kit.md" "$PROJ/portable-spec-kit.md"
cp "$PROJ/portable-spec-kit.md" "$PROJ/examples/starter/portable-spec-kit.md"
cp "$PROJ/portable-spec-kit.md" "$PROJ/examples/my-app/portable-spec-kit.md"
echo "✓ Synced portable-spec-kit.md from root (including examples)"

# 2. Clone or update temp repo
# KIT-GAP-0148: validate the clone. A corrupt/partial $TEMP/.git from a prior run
# (exists but `git` rejects it) silently broke every git op below yet still printed
# "✓ Pushed". Now an invalid temp is removed + re-cloned fresh, and a failed clone
# aborts the sync instead of continuing into a false success.
if git -C "$TEMP" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$TEMP" pull --rebase || { echo "⚠ pull failed — re-cloning fresh"; rm -rf "$TEMP"; git clone https://github.com/aqibmumtaz/portable-spec-kit.git "$TEMP" || { echo "✗ clone FAILED — aborting sync"; exit 1; }; }
  echo "✓ Updated local clone"
else
  rm -rf "$TEMP"
  git clone https://github.com/aqibmumtaz/portable-spec-kit.git "$TEMP" || { echo "✗ clone FAILED — aborting sync"; exit 1; }
  echo "✓ Cloned repo"
fi

# 3. Remove stale files from repo if exists
rm -f "$TEMP/CLAUDE.md" "$TEMP/CLAUDE_CONTEXT.md" "$TEMP/setup.sh"

# 4. Sync files (NOT agent/ dir — that's Documents-only)
cp "$PROJ/portable-spec-kit.md" "$PROJ/README.md" "$PROJ/CONTRIBUTING.md" "$PROJ/LICENSE" "$PROJ/.gitignore" "$PROJ/CHANGELOG.md" "$PROJ/install.sh" "$TEMP/"
rm -rf "$TEMP/docs" "$TEMP/ard" "$TEMP/examples" "$TEMP/tests" "$TEMP/.github" "$TEMP/agent" "$TEMP/.portable-spec-kit" "$TEMP/.claude" "$TEMP/.git-hooks"
cp -r "$PROJ/docs/" "$TEMP/docs/"
rm -rf "$TEMP/docs/research"  # research is private — not published to GitHub
cp -r "$PROJ/ard/" "$TEMP/ard/"
cp -r "$PROJ/examples/" "$TEMP/examples/"
cp -r "$PROJ/tests/" "$TEMP/tests/"
cp -r "$PROJ/.github/" "$TEMP/.github/"

# Reliability infrastructure — distributed to end users
mkdir -p "$TEMP/agent/scripts" "$TEMP/.portable-spec-kit/skills" "$TEMP/.claude" "$TEMP/.git-hooks"
# KIT-GAP-0148: ship ALL kit scripts, not a hardcoded subset. The prior 19-name
# allowlist went stale as the kit grew to 67 scripts — published psk-install-hooks.sh
# + psk-sync-check.sh referenced scripts (the chunked-drive guard, progress monitor,
# bootstrap-check, dispatch, spawn, workflow-state, etc.) that were never shipped, so a
# fresh public install failed its own gates (PSK029/047/051 …). reflex/ stays dev-only
# (intentionally NOT copied below — kept private for now).
for script in "$PROJ"/agent/scripts/*.sh; do
  cp "$script" "$TEMP/agent/scripts/"
done
cp -r "$PROJ/.portable-spec-kit/skills/" "$TEMP/.portable-spec-kit/skills/"
cp "$PROJ/.claude/settings.json" "$TEMP/.claude/settings.json" 2>/dev/null || true
cp "$PROJ/.git-hooks/pre-commit" "$TEMP/.git-hooks/pre-commit" 2>/dev/null || true

# v0.5.16 — CI templates for user projects
mkdir -p "$TEMP/.portable-spec-kit/templates/ci"
cp -r "$PROJ/.portable-spec-kit/templates/ci/"* "$TEMP/.portable-spec-kit/templates/ci/" 2>/dev/null || true

echo "✓ Files copied (including reliability infrastructure + CI templates)"

# 5. Commit and push
cd "$TEMP"
git config user.name "Aqib Mumtaz"
git config user.email "aqib.mumtaz@gmail.com"
git add -A

MSG="${1:-$(git -C "$PROJ" log -1 --format="%s")}"
if git diff --cached --quiet; then
  echo "✓ No changes to push"
else
  git commit -m "$MSG" || { echo "✗ commit FAILED — aborting sync"; exit 1; }
  if git push; then
    echo "✓ Pushed to aqibmumtaz/portable-spec-kit"
  else
    echo "✗ push FAILED — public repo NOT updated"; exit 1
  fi
fi

# 6. Create/update GitHub releases — ALL versions from CHANGELOG, not just current
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  # Full version e.g. v0.5.2 — single source of truth
  FULL_VER=$(grep "^\- \*\*Version:\*\*" "$PROJ/agent/AGENT_CONTEXT.md" | grep -o "v[0-9]*\.[0-9]*\.[0-9]*" | head -1)
  RELEASE_VER=$(echo "$FULL_VER" | grep -o "v[0-9]*\.[0-9]*" | head -1)

  if [ -n "$RELEASE_VER" ]; then
    # Update/create tag for current release
    git tag -f "$RELEASE_VER" HEAD
    git push origin "$RELEASE_VER" --force 2>/dev/null

    # Update ALL releases from CHANGELOG (newest first = --latest on current only)
    for ver in $(grep "^## v[0-9]" "$PROJ/CHANGELOG.md" | grep -o "v[0-9]*\.[0-9]*" | sort -t. -k1,1n -k2,2n); do
      NOTES=$(awk -v ver="$ver" 'index($0,"## " ver)==1{p=1;next} /^---/{if(p)exit} p' "$PROJ/CHANGELOG.md")
      TITLE=$(awk -v ver="$ver" 'index($0,"## " ver)==1{print;exit}' "$PROJ/CHANGELOG.md" | sed 's/^## //')
      [ -z "$TITLE" ] || [ -z "$NOTES" ] && continue

      LATEST_FLAG=""
      [ "$ver" = "$RELEASE_VER" ] && LATEST_FLAG="--latest"

      if gh release view "$ver" >/dev/null 2>&1; then
        gh release edit "$ver" --title "$TITLE" --notes "$NOTES" --draft=false $LATEST_FLAG 2>/dev/null
      else
        git tag -f "$ver" HEAD 2>/dev/null
        git push origin "$ver" --force 2>/dev/null
        gh release create "$ver" --title "$TITLE" --notes "$NOTES" $LATEST_FLAG 2>/dev/null
      fi
    done
    echo "✓ All GitHub releases updated from CHANGELOG.md"
  else
    echo "⚠ Could not detect release version — skipping GitHub releases"
  fi
else
  echo "⚠ gh CLI not authenticated — skipping GitHub release (run: gh auth login)"
fi
