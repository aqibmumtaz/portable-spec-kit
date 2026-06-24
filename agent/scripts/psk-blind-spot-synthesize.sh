#!/bin/bash
# mechanical-script: deterministic pattern-analyzer that emits PR-style suggestions to agent/tasks/proposed/; no AI invocation (Dim 28 allowlist — v0.6.60 HF7b)
# ════════════════════════════════════════════════════════════════
# psk-blind-spot-synthesize.sh — Tier 3 of v0.6.7+ auto-evolving QA plan
#
# Closes the v0.6.7+ residual: when a human flags a missed issue in
# qa-blind-spots.md, this script analyzes the entry, derives a probe
# pattern (regex / structure / claim-type seed), and proposes adding
# it to extract-claims.sh / reference-state YAML / a new Phase 0 helper
# as a PR-style suggestion in agent/tasks/proposed/Gxx-<slug>.md.
#
# Same audit-trail format as kit-finding routing (`[source: ...]`).
#
# Implements P6 — Structural Enforcement Over Trust + the qa-blind-
# spots maintenance rule 3 (probed status requires deterministic probe).
#
# Usage:
#   bash agent/scripts/psk-blind-spot-synthesize.sh [--dry-run] [--id BS-XXX]
#
# Exit codes:
#   0 — synthesized 0+ proposals successfully
#   1 — qa-blind-spots.md missing
#   2 — invalid args
# ════════════════════════════════════════════════════════════════

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
REGISTRY="${REGISTRY:-$PROJ_ROOT/reflex/history/qa-blind-spots.md}"
PROPOSED_DIR="$PROJ_ROOT/agent/tasks/proposed"
DRY_RUN=0
SINGLE_ID=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DRY_RUN=1; shift ;;
    --id)       SINGLE_ID="$2"; shift 2 ;;
    --help|-h)
      sed -n '/^# Usage:/,/^# ====/p' "$0" | head -10
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ ! -f "$REGISTRY" ]; then
  echo "[blind-spot-synthesize] $REGISTRY not found" >&2
  exit 1
fi

mkdir -p "$PROPOSED_DIR"

# Extract open BS entries with their issue + should_add_probe_to fields.
# Format in registry:
#   - id: BS-NNN
#     ...
#     issue: |
#       ...multiline...
#     should_add_probe_to: <target>
#     status: open
extract_open_entries() {
  # Each real BS entry lives under a `### BS-NNN — title` heading (not the
  # template ## Format section). Walk per-heading sections; skip entries
  # whose id contains a `{` (placeholder template like `BS-{NNN}`).
  awk '
    /^### BS-/ {
      if (entry_id != "" && status == "open" && entry_id !~ /\{/) {
        printf "ID=%s\nISSUE=%s\nTARGET=%s\nSEVERITY=%s\n---\n",
               entry_id, issue, target, severity
      }
      entry_id = ""
      issue = ""
      target = ""
      severity = ""
      status = ""
      in_section = 1
      in_issue = 0
      next
    }
    /^### / && !/^### BS-/ { in_section = 0; in_issue = 0; next }
    !in_section            { next }
    /^- id: BS-/           { entry_id = $3; next }
    /^  issue: \|/         { in_issue = 1; next }
    in_issue && /^    /    { line = $0; sub(/^    /, "", line); issue = issue line " "; next }
    in_issue && /^  [a-z]/ { in_issue = 0 }
    /^  should_add_probe_to:/ {
      val = $0
      sub(/^  should_add_probe_to:[[:space:]]*/, "", val)
      target = val
    }
    /^  severity_when_observed:/ {
      val = $0
      sub(/^  severity_when_observed:[[:space:]]*/, "", val)
      severity = val
    }
    /^  status:/ {
      val = $0
      sub(/^  status:[[:space:]]*/, "", val)
      sub(/[[:space:]]+#.*$/, "", val)
      status = val
    }
    END {
      if (entry_id != "" && status == "open" && entry_id !~ /\{/) {
        printf "ID=%s\nISSUE=%s\nTARGET=%s\nSEVERITY=%s\n---\n",
               entry_id, issue, target, severity
      }
    }
  ' "$REGISTRY"
}

# Map a target string to one of: extract-claims | reference-state | sync-check | new-helper | unknown
classify_target() {
  local t="$1"
  case "$t" in
    *extract-claims*)            echo "extract-claims" ;;
    *reference-state*|*speckit*) echo "reference-state" ;;
    *sync-check*|*psk-sync*)     echo "sync-check" ;;
    *check-*.sh*|*reflex/lib*)   echo "new-helper" ;;
    *)                           echo "unknown" ;;
  esac
}

# Derive a slug from BS id + issue first words
derive_slug() {
  local bs_id="$1" issue="$2"
  local first_words
  first_words=$(echo "$issue" | head -c 60 | tr -c 'a-zA-Z0-9' '-' | sed 's/--*/-/g; s/^-//; s/-$//' | tr 'A-Z' 'a-z')
  local short_bs
  short_bs=$(echo "$bs_id" | sed 's/BS-//')
  echo "G${short_bs}-${first_words}" | head -c 80
}

# Generate proposal markdown for a target class
generate_proposal() {
  local bs_id="$1" issue="$2" target="$3" severity="$4" target_class="$5" slug="$6"
  local out_file="$PROPOSED_DIR/${slug}.md"

  cat > "$out_file" << EOF
# ${slug} — Auto-synthesized probe proposal for ${bs_id}

**Status:** proposed (auto-synthesized by psk-blind-spot-synthesize.sh)
**Source:** \`reflex/history/qa-blind-spots.md\` entry \`${bs_id}\`
**Severity at observation:** ${severity}
**Date synthesized:** $(date -u +%Y-%m-%d)
**Target class:** ${target_class}
**Proposed target file:** ${target}

## What this proposal closes

${issue}

## Proposed probe (v1 — kit maintainer reviews + refines)

EOF

  case "$target_class" in
    extract-claims)
      cat >> "$out_file" << 'EOF'
Add a new claim-extractor block to `reflex/lib/extract-claims.sh` along
the same pattern as the existing `# --- N. <category> claims ---` blocks.

```bash
# --- N. <new claim type derived from BS-XXX> ---
# Issue cited: see BS-XXX in reflex/history/qa-blind-spots.md
for f in <files-to-scan>; do
  [ -f "$PROJ_ROOT/$f" ] || continue
  matches=$(grep -oE '<regex-derived-from-issue>' "$PROJ_ROOT/$f" 2>/dev/null | sort -u | head -10)
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    emit_claim "$f" "Claim: <description>" "<probe-type-name>" "$m"
  done <<< "$matches"
done
```

**Kit maintainer:** replace `<regex>`, `<files-to-scan>`, `<probe-type-name>`,
and the description with the concrete pattern derived from the issue text
above. The synthesizer cannot infer the regex from natural language alone
— this scaffold is a starting point for review.
EOF
      ;;
    reference-state)
      cat >> "$out_file" << 'EOF'
Add a new entry to `reflex/reference-state/speckit-project.yaml` (or a
new stack-specific file like `reference-state/python-fastapi.yaml`) so
`reflex/lib/state-diff.sh` catches the gap class.

```yaml
# Add to the relevant section:
expected_files:
  - path: <file-or-pattern>
    severity: <CRITICAL|MAJOR>
    rationale: "Cited in BS-XXX — see reflex/history/qa-blind-spots.md"
```

**Kit maintainer:** define `<file-or-pattern>` and severity per the
issue context above. If this is a stack-specific concern (e.g.,
"every Next.js project must have middleware.ts"), create the new
stack file rather than polluting the generic speckit-project.yaml.
EOF
      ;;
    sync-check)
      cat >> "$out_file" << 'EOF'
Add a new check function to `agent/scripts/psk-sync-check.sh` mirroring
the existing pattern (e.g., `check_reqs_coverage`, `check_ui_requirements_coverage`).

```bash
check_<new_dimension>() {
  if [ "${PSK_<NEW>_DISABLED:-0}" = "1" ]; then
    return 0
  fi
  # ... derive deterministic check from issue ...
  if [ "$found_problem" = "true" ]; then
    emit_issue "PSK0XX" "<dimension>" "<details>" "<fix-hint>"
  else
    emit_pass "<Dimension> clean"
  fi
}
```

Then wire `check_<new_dimension>` into `main()` `--full` dispatch.
**Kit maintainer:** assign next free PSK error code, write the check
logic, add to ADR-XXX rationale.
EOF
      ;;
    new-helper)
      cat >> "$out_file" << 'EOF'
Create a new Phase 0 helper at `reflex/lib/check-<dimension>.sh` mirroring
`reflex/lib/check-installer-coverage.sh` or `check-reqs-coverage.sh`:

```bash
#!/bin/bash
# reflex/lib/check-<dimension>.sh — Phase 0 helper
# Closes <BS-XXX> from qa-blind-spots.md
set -uo pipefail
PASS_DIR="${1:-}"
[ -z "$PASS_DIR" ] && { echo "Usage: $0 <pass-dir>" >&2; exit 1; }
PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
OUT="$PASS_DIR/<dimension>-coverage.yaml"
mkdir -p "$PASS_DIR"
# ... derive deterministic check from issue ...
cat > "$OUT" << YAML
schema_version: 1
generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
status: <clean|issues_found>
total: <count>
YAML
exit 0
```

Then wire the helper into `reflex/lib/spawn-qa.sh` Phase 0 invocations
(see existing CHECK_REQS_COVERAGE / CHECK_INSTALLER pattern at lines 83-87).
EOF
      ;;
    *)
      cat >> "$out_file" << 'EOF'
The synthesizer could not auto-classify the target. Kit maintainer:
review the issue above and decide which kit surface should host the
probe (extract-claims.sh / reference-state YAML / sync-check function
/ new Phase 0 helper / qa-agent.md prompt addition).
EOF
      ;;
  esac

  cat >> "$out_file" << EOF

## Acceptance criteria for this proposal landing

- [ ] Probe implemented per the scaffold above (kit maintainer fills concrete pattern).
- [ ] Probe tested against a synthetic fixture that demonstrates the regression class.
- [ ] BS-${bs_id##*-} status flipped \`open\` → \`probed\` with \`probed_at\` + \`probe_implementation\` fields filled.
- [ ] Regression test added to \`tests/sections/04-reflex.sh\` (new N-section or extension of existing).
- [ ] ADR entry added to \`agent/PLANS.md\` documenting the choice.

## Audit trail

\`[source: psk-blind-spot-synthesize.sh / ${bs_id} / $(date -u +%Y-%m-%dT%H:%M:%SZ)]\`

When this proposal lands, commit message must include the trailer above
so the lineage from human-flagged blind spot → synthesizer scaffold →
landed kit change is visible in \`git log --grep="source: ${bs_id}"\`.
EOF

  echo "$out_file"
}

# Main loop
proposals_written=0
proposals_skipped=0

tmp_entries=$(mktemp)
extract_open_entries > "$tmp_entries"

bs_id="" issue="" target="" severity=""
while IFS= read -r line; do
  case "$line" in
    ID=*)        bs_id="${line#ID=}" ;;
    ISSUE=*)     issue="${line#ISSUE=}" ;;
    TARGET=*)    target="${line#TARGET=}" ;;
    SEVERITY=*)  severity="${line#SEVERITY=}" ;;
    ---)
      [ -z "$bs_id" ] && continue
      if [ -n "$SINGLE_ID" ] && [ "$bs_id" != "$SINGLE_ID" ]; then
        bs_id="" issue="" target="" severity=""
        continue
      fi

      target_class=$(classify_target "$target")
      slug=$(derive_slug "$bs_id" "$issue")

      if [ -f "$PROPOSED_DIR/${slug}.md" ]; then
        proposals_skipped=$((proposals_skipped + 1))
        echo "  [skip] ${bs_id} → $PROPOSED_DIR/${slug}.md (already exists)" >&2
      elif [ "$DRY_RUN" = "1" ]; then
        echo "  [dry-run] would synthesize: ${bs_id} → $PROPOSED_DIR/${slug}.md (target_class: $target_class)"
        proposals_written=$((proposals_written + 1))
      else
        out=$(generate_proposal "$bs_id" "$issue" "$target" "$severity" "$target_class" "$slug")
        echo "  [synthesized] ${bs_id} → $out (target_class: $target_class)"
        proposals_written=$((proposals_written + 1))
      fi
      bs_id="" issue="" target="" severity=""
      ;;
  esac
done < "$tmp_entries"
rm -f "$tmp_entries"

echo ""
if [ "$DRY_RUN" = "1" ]; then
  echo "[blind-spot-synthesize] dry-run complete — no files written"
else
  echo "[blind-spot-synthesize] done — proposals in $PROPOSED_DIR/"
  echo "Kit maintainer: review each Gxx-*.md and run psk-evolution-gauntlet.sh on it before landing."
fi
exit 0
