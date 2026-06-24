#!/usr/bin/env bash
# mechanical-script: deterministic, no AI prompts (Dim 28 allowlist — v0.6.60 HF7b)
# psk-generate-user-guide.sh — generate ard/user-guide.html from README.md + agent/AGENT.md
#
# Called automatically by psk-release.sh Step 7 when ard/user-guide.html is absent.
# Generic: works for any project stack. Content is derived entirely from the
# project's own files — no hardcoded project names or stack assumptions.
#
# Usage:  bash psk-generate-user-guide.sh [PROJECT_ROOT]
# Output: PROJECT_ROOT/ard/user-guide.html

set -euo pipefail

# KIT-GAP-0013 fix (v0.6.68): resolve PROJ_ROOT from the script's own location
# (../../) rather than `git rev-parse --show-toplevel`. The latter resolves to
# the OUTER workspace git root when the kit lives in a subdir of a parent
# git repo (e.g. Documents/Projects/portable-spec-kit/), which caused the
# generator to write the output one tree above the kit, leaving the kit's
# local ard/user-guide.html stale.
PROJ_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)}"
PROJ_ROOT="${PROJ_ROOT:-$(pwd)}"

README="$PROJ_ROOT/README.md"
AGENT_MD="$PROJ_ROOT/agent/AGENT.md"
AGENT_CTX="$PROJ_ROOT/agent/AGENT_CONTEXT.md"
OUT="$PROJ_ROOT/ard/user-guide.html"

mkdir -p "$PROJ_ROOT/ard"

# Derive project name from AGENT.md or README.md.
# NB: under `set -euo pipefail` a no-match grep exits 1 and pipefail propagates it through the
# downstream pipe — a missing field is a valid "use the default" signal, not an error, so each
# capture ends in `|| true` and the `[ -n ... ]` tests use `:-` for set -u safety.
project_name="Project"
if [ -f "$AGENT_MD" ]; then
  n=$(grep -m1 -E '^\*\*Project[:\s]|^# ' "$AGENT_MD" 2>/dev/null | sed 's/.*\*\*Project[: ]*//;s/\*\*.*//;s/^# //' | head -1 | tr -d '\r' || true)
  [ -n "${n:-}" ] && project_name="$n"
fi
if [ "$project_name" = "Project" ] && [ -f "$README" ]; then
  n=$(grep -m1 '^# ' "$README" 2>/dev/null | sed 's/^# //' | tr -d '\r' || true)
  [ -n "${n:-}" ] && project_name="$n"
fi

# Derive version — prefer AGENT_CONTEXT.md (kit's source-of-truth for Version),
# fall back to AGENT.md, then to v0.1 default. KIT-GAP-0013 fix (v0.6.68): the
# generator previously only read AGENT.md, which doesn't carry the kit's
# Version field; the output title stayed at the v0.1 default instead of
# tracking real releases.
version="v0.1"
for src in "$AGENT_CTX" "$AGENT_MD"; do
  [ -f "$src" ] || continue
  v=$(grep -m1 -E '\*\*Version[:\s]' "$src" 2>/dev/null | sed 's/.*\*\*Version[: ]*//;s/\*\*.*//' | tr -d ' \r' || true)
  if [ -n "${v:-}" ]; then
    version="$v"
    break
  fi
done

# Derive stack from AGENT.md Stack table
stack_rows=""
if [ -f "$AGENT_MD" ]; then
  stack_rows=$(awk '/\| Layer\s*\|/{p=1;next} p && /^\s*\|/{print} p && /^[^|]/{exit}' "$AGENT_MD" 2>/dev/null | head -20)
fi

# Derive API endpoints from AGENT.md or PLANS.md
api_rows=""
for src in "$AGENT_MD" "$PROJ_ROOT/agent/PLANS.md"; do
  [ -f "$src" ] || continue
  rows=$(awk '/\| Route\s*\|/{p=1;next} p && /^\s*\|/{print} p && /^[^|]/{exit}' "$src" 2>/dev/null | head -20)
  [ -n "$rows" ] && { api_rows="$rows"; break; }
done

# Extract setup section from README
setup_html=""
if [ -f "$README" ]; then
  setup_html=$(awk '/^## (Setup|Getting Started|Installation|Quick Start)/{p=1;next} p && /^## /{exit} p{print}' "$README" 2>/dev/null | \
    sed 's/^### /\<h4\>/;s/$/<\/h4>/' | \
    sed 's/^```bash/<pre><code class="language-bash">/;s/^```/<\/code><\/pre>/' | \
    sed 's/^- /\<li\>/;s/$/<\/li>/' | head -60)
fi

# Build stack table HTML
stack_table=""
if [ -n "$stack_rows" ]; then
  stack_table="<table>
  <tr><th>Layer</th><th>Technology</th><th>Purpose</th></tr>"
  while IFS='|' read -r _ col1 col2 col3 _; do
    col1=$(echo "$col1" | xargs); col2=$(echo "$col2" | xargs); col3=$(echo "$col3" | xargs)
    [ -z "$col1" ] && continue
    stack_table+="
  <tr><td>$col1</td><td>$col2</td><td>$col3</td></tr>"
  done <<< "$stack_rows"
  stack_table+="
</table>"
fi

# Build API table HTML
api_table=""
if [ -n "$api_rows" ]; then
  api_table="<table>
  <tr><th>Route</th><th>Method</th><th>Purpose</th></tr>"
  while IFS='|' read -r _ col1 col2 col3 _; do
    col1=$(echo "$col1" | xargs); col2=$(echo "$col2" | xargs); col3=$(echo "$col3" | xargs)
    [ -z "$col1" ] && continue
    api_table+="
  <tr><td><code>$col1</code></td><td>$col2</td><td>$col3</td></tr>"
  done <<< "$api_rows"
  api_table+="
</table>"
fi

today=$(date +%Y-%m-%d)

cat > "$OUT" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${project_name} — User Guide (${version})</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 960px; margin: 0 auto; padding: 2rem; color: #1a1a1a; }
    h1 { font-size: 2rem; border-bottom: 3px solid #2563eb; padding-bottom: 0.5rem; }
    h2 { font-size: 1.4rem; color: #1e40af; margin-top: 2rem; border-bottom: 1px solid #e5e7eb; padding-bottom: 0.25rem; }
    h3 { font-size: 1.1rem; color: #374151; }
    h4 { font-size: 1rem; color: #374151; margin-top: 1rem; }
    table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
    th { background: #2563eb; color: white; padding: 0.5rem 0.75rem; text-align: left; }
    td { padding: 0.5rem 0.75rem; border-bottom: 1px solid #e5e7eb; }
    tr:nth-child(even) td { background: #f9fafb; }
    code { background: #f3f4f6; padding: 0.1rem 0.3rem; border-radius: 3px; font-size: 0.9em; }
    pre { background: #1e293b; color: #e2e8f0; padding: 1rem; border-radius: 6px; overflow-x: auto; }
    pre code { background: transparent; color: inherit; padding: 0; }
    .badge { display: inline-block; padding: 0.2rem 0.6rem; border-radius: 9999px; font-size: 0.8rem; font-weight: 600; }
    .badge-blue { background: #dbeafe; color: #1e40af; }
    .badge-green { background: #d1fae5; color: #065f46; }
    ul { padding-left: 1.5rem; }
    li { margin: 0.25rem 0; }
  </style>
</head>
<body>

<h1>${project_name} — User Guide</h1>
<p>
  <span class="badge badge-blue">Version: ${version}</span>
  &nbsp;
  <span class="badge badge-green">Generated: ${today}</span>
</p>

<h2>Overview</h2>
<p>
  This guide covers setup, configuration, and day-to-day use of <strong>${project_name}</strong>.
  For architecture details and feature traceability, see <code>ard/technical-overview.html</code>.
</p>

<h2>Prerequisites</h2>
<ul>
  <li>Git</li>
  <li>Node.js / Python / runtime as declared in the Stack table below</li>
  <li>Environment variables configured in <code>.env</code> (copy from <code>.env.example</code>)</li>
</ul>

<h2>Setup</h2>
<ol>
  <li>Clone the repository and enter the project directory</li>
  <li>Copy <code>.env.example</code> to <code>.env</code> and fill in real values</li>
  <li>Install dependencies per the stack (e.g. <code>pnpm install</code> / <code>pip install -r requirements.txt</code>)</li>
  <li>Run any database migrations if applicable</li>
  <li>Start the development server</li>
</ol>

$([ -n "$setup_html" ] && echo "<h2>Quick Start</h2><div>$setup_html</div>")

<h2>Technology Stack</h2>
$([ -n "$stack_table" ] && echo "$stack_table" || echo "<p>See <code>agent/AGENT.md</code> Stack table.</p>")

<h2>API Reference</h2>
$([ -n "$api_table" ] && echo "$api_table" || echo "<p>See <code>agent/PLANS.md</code> API Endpoints section.</p>")

<h2>Environment Variables</h2>
<p>
  All required environment variables are listed in <code>.env.example</code> at the project root.
  Copy it to <code>.env</code> and replace placeholder values with real credentials.
  Never commit <code>.env</code> to version control.
</p>

<h2>Running Tests</h2>
<p>
  The project ships with a full test suite. Run all tests with the command declared
  in <code>agent/AGENT.md</code> (e.g. <code>pnpm test --run</code> / <code>pytest</code>).
  All tests must pass before any deployment.
</p>

<h2>Contributing</h2>
<p>
  See <code>agent/TASKS.md</code> for open tasks and <code>agent/SPECS.md</code> for
  feature acceptance criteria. All contributions must pass the full test suite and
  the kit's mechanical gates before merging.
</p>

<hr>
<p style="color:#6b7280;font-size:0.85rem;">
  Generated by Portable Spec Kit · ${project_name} · ${today}
</p>
</body>
</html>
HTML

echo "✓ user-guide.html written → $OUT"
