#!/bin/bash
# mechanical-script: psk-optimize.sh — token-bloat scanner (no AI invocation)
# ════════════════════════════════════════════════════════════════════
# psk-optimize.sh — token-bloat detector + safe pruner
#
# Surfaces accumulated bloat in framework + agent files: duplicate
# version entries, stale numeric badges, redundant cross-file rules,
# superseded-ADR rationale bloat. Outputs a punch list of candidates.
# Auto-pruning is opt-in; default is scan-only (read-only).
#
# Safety contract — no functionality lost after a prune sweep:
#   1. Per-cut atomic commit (revertable in isolation)
#   2. Pre-cut snapshot (gate suite must pass before starting)
#   3. Post-cut gate (gate suite must pass after each cut)
#   4. MANDATORY-line preservation (new count ≥ old count)
#   5. R→F→T preservation (test-release-check.sh must continue passing)
#   6. Dry-run by default — --apply flag required to mutate
#
# Usage:
#   bash agent/scripts/psk-optimize.sh                 # scan only (default)
#   bash agent/scripts/psk-optimize.sh --scan          # scan only (explicit)
#   bash agent/scripts/psk-optimize.sh --safety-check  # verify gate suite is green
#   bash agent/scripts/psk-optimize.sh --json          # machine-readable output
#
# What it detects (9 categories):
#   1. Duplicate version-iteration entries in CHANGELOG/RELEASES
#   2. Stale numeric badges (test counts drift from runner output)
#   3. Superseded-ADR rationale bloat (full Why/Options narrative
#      still present in rows marked "superseded by ADR-N")
#   4. Stale file references in markdown (links to .md/.sh/.yml
#      paths that don't exist on disk)
#   5. Unused env vars in .env.example (declared but never read in
#      src/app/lib/server)
#   6. Oversized framework sections (>200 lines under one heading
#      in portable-spec-kit.md — skill-file extraction candidates)
#   7. Reflex prompt bloat (reflex/prompts/*.md >500 lines — every
#      pass loads these; verbose narrative is per-pass token tax)
#   8. Reflex history retention bloat (per-pass dirs accumulated
#      beyond 2x retention limit; REFLEX_EVAL_TRACE.md >100KB)
#   9. Duplicate skill references (rule duplication detection) —
#      same .portable-spec-kit/skills/X.md referenced ≥2 times
#      outside the canonical skill table; usually a legacy stub
#      left during refactoring (enforces No-duplicate-instructions
#      framework principle)
#
# Out of scope (use stack-native tools):
#   - Dead code / unused exports — ts-prune / knip / vulture
#   - Bundle size — next build / vite build with size analysis
#   - DB indexes / N+1 queries — DBA tools / Prisma analyzer
#
# Author: Portable Spec Kit (kit-author maintained)
# ════════════════════════════════════════════════════════════════════

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors (no color when not a tty)
if [ -t 1 ]; then
  RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
else
  RED=''; YELLOW=''; GREEN=''; CYAN=''; NC=''
fi

# Defaults
MODE="scan"
JSON=false

while [ $# -gt 0 ]; do
  case "$1" in
    --scan)         MODE="scan" ;;
    --safety-check) MODE="safety-check" ;;
    --health)       MODE="health" ;;
    --json)         JSON=true ;;
    --help|-h)      sed -n '4,40p' "$0"; exit 0 ;;
    *)              echo -e "${RED}unknown flag: $1${NC}" >&2; exit 1 ;;
  esac
  shift
done

# State file — updated on every --scan, read by --health.
# Lives at .portable-spec-kit/optimize-state.yml (committed to repo so
# every contributor sees the current optimization health on session
# start, and the breadcrumb indicator works for everyone).
STATE_FILE="$PROJ_ROOT/.portable-spec-kit/optimize-state.yml"

# Deferred-candidates list — explicitly-preserved findings that should
# NOT trigger 🟡 review. Examples: reflex/prompts/qa-agent.md preserved
# per accuracy mandate; cat-9 stub sections that serve as load-bearing
# context anchors. Format: simple list of "category:identifier" entries.
DEFERRED_FILE="$PROJ_ROOT/.portable-spec-kit/optimize-deferred.yml"

# ---------- Detection helpers ----------

# Detect duplicate RELEASE-style version headers (### v0.6.14 — Title or
# ## v0.6.14 — Title) within a single file. Excludes subsections like
# "#### v0.6.11 hotfixes" or "### Still deferred (v0.6.11+ ARB)".
# Output format: "file<TAB>version<TAB>count" — tab-separated for safe
# display when file paths contain spaces.
# Portable awk — works with BSD awk + gawk + mawk.
detect_duplicate_version_blocks() {
  local file="$1"
  [ -f "$file" ] || return 0
  awk -v file="$file" '
    # Only match release-headers: 2-3 hashes, exact "vX.Y.Z" token,
    # followed by " — " (em-dash) marking a release title.
    /^##[#]? v[0-9]+\.[0-9]+\.[0-9]+ — / {
      ver = $2
      seen[ver]++
    }
    END {
      for (k in seen) {
        if (seen[k] >= 2) {
          printf "%s\t%s\t%d\n", file, k, seen[k]
        }
      }
    }
  ' "$file"
}

# Detect numeric badges that drift from the actual test count.
# Strategy: parse the framework + benchmarking suites if available,
# then grep every file for any 4-digit count that disagrees.
detect_stale_test_counts() {
  local fw_runner="$PROJ_ROOT/tests/test-spec-kit.sh"
  local bm_runner="$PROJ_ROOT/tests/test-spd-benchmarking.sh"

  # Skip if runners not present (kit-only tool)
  [ -x "$fw_runner" ] || [ -f "$fw_runner" ] || return 0

  # Re-entrancy guard — when invoked from inside a test run (e.g. N63
  # regression tests source this script), do NOT re-spawn the test
  # suite. Infinite recursion. Caller sets PSK_OPTIMIZE_SKIP_TESTRUN=1.
  if [ "${PSK_OPTIMIZE_SKIP_TESTRUN:-0}" = "1" ]; then
    return 0
  fi

  # Get actual counts from a quick run; cache to avoid re-running on
  # back-to-back invocations (~3s saved on warm cache).
  local cache="$PROJ_ROOT/tests/.psk-optimize-counts.cache"
  local fw_count=0 bm_count=0
  if [ -f "$cache" ] && [ "$(find "$cache" -mmin -10 2>/dev/null)" ]; then
    fw_count=$(awk -F= '$1=="fw"{print $2}' "$cache")
    bm_count=$(awk -F= '$1=="bm"{print $2}' "$cache")
  else
    fw_count=$(bash "$fw_runner" 2>&1 | awk '/RESULTS:/ { for(i=1;i<=NF;i++) if($i=="passed,") print $(i-1); exit }')
    bm_count=$(bash "$bm_runner" 2>&1 | awk '/TESTS:/ { for(i=1;i<=NF;i++) if($i=="passed,") print $(i-1); exit }')
    fw_count="${fw_count:-0}"
    bm_count="${bm_count:-0}"
    {
      echo "fw=$fw_count"
      echo "bm=$bm_count"
    } > "$cache" 2>/dev/null || true
  fi

  local total=$((fw_count + bm_count))
  [ "$total" -eq 0 ] && return 0

  # Files to scan for stale counts (kit-side only)
  local files=(
    "$PROJ_ROOT/portable-spec-kit.md"
    "$PROJ_ROOT/README.md"
    "$PROJ_ROOT/CHANGELOG.md"
    "$PROJ_ROOT/agent/SPECS.md"
    "$PROJ_ROOT/agent/AGENT.md"
    "$PROJ_ROOT/agent/AGENT_CONTEXT.md"
    "$PROJ_ROOT/agent/RELEASES.md"
  )

  local f drift_count=0
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    # Look for "(N framework + N benchmarking)" patterns where N drifted
    awk -v fw="$fw_count" -v bm="$bm_count" -v tot="$total" -v file="$f" '
      match($0, /([0-9]{3,5}) framework \+ ([0-9]{3,5}) benchmarking/, m) {
        if (m[1] != fw || m[2] != bm) {
          printf "%s:%d:STALE: \"%s framework + %s benchmarking\" (actual: %s + %s = %s)\n", file, NR, m[1], m[2], fw, bm, tot
        }
      }
    '
  done
}

# Detect superseded ADRs that still carry full rationale narrative.
# Rule: a row marked "(superseded by ADR-M)" should be 1-2 lines, not
# a full options-considered + why dump.
detect_superseded_adr_bloat() {
  local plans="$PROJ_ROOT/agent/PLANS.md"
  [ -f "$plans" ] || return 0

  awk '
    /^\| ADR-/ {
      if (match($0, /superseded by/)) {
        # Count pipe-separated cells; bloat threshold: row > 800 chars
        if (length($0) > 800) {
          printf "%s:%d:BLOAT: superseded ADR row is %d chars (consider trimming Why/Options to 1 line each)\n", FILENAME, NR, length($0)
        }
      }
    }
  ' "$plans"
}

# Cat 4 — Detect stale file references in markdown.
# Pattern: markdown link like [text](relative/path.md) or `path/to/file.sh`
# pointing to a path that doesn't exist on disk. False-positive avoidance:
# only flag .md / .sh / .yml / .yaml / .json paths (not http URLs, not
# anchors, not external-system identifiers).
detect_stale_file_refs() {
  local files=(
    "$PROJ_ROOT/portable-spec-kit.md"
    "$PROJ_ROOT/agent/AGENT.md"
    "$PROJ_ROOT/agent/AGENT_CONTEXT.md"
    "$PROJ_ROOT/agent/PLANS.md"
    "$PROJ_ROOT/CHANGELOG.md"
    "$PROJ_ROOT/agent/RELEASES.md"
  )
  local f
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    # Extract markdown-link paths and inline-code paths matching extensions.
    # gawk match-with-array isn't portable; use a sed+loop approach.
    local file_dir
    file_dir="$(dirname "$f")"
    grep -oE '\[[^]]+\]\(([^)]+\.(md|sh|yml|yaml|json|html))\)' "$f" 2>/dev/null \
      | sed -E 's|^\[[^]]+\]\(([^)]+)\)|\1|' \
      | while IFS= read -r ref; do
          # Skip URLs and anchors
          case "$ref" in
            http*|//*|'#'*) continue ;;
          esac
          # Strip any #anchor suffix
          local clean_ref="${ref%%#*}"
          # Markdown links resolve relative to the file's own directory
          # (not project root). Test that path first; fall back to root
          # for absolute-style refs starting with /.
          local abs
          if [ "${clean_ref:0:1}" = "/" ]; then
            abs="$PROJ_ROOT$clean_ref"
          else
            abs="$file_dir/$clean_ref"
          fi
          if [ ! -e "$abs" ]; then
            printf "%s:STALE_REF: %s (resolved to %s)\n" "$f" "$ref" "$abs"
          fi
        done
  done
}

# Cat 5 — Detect unused env vars in .env.example.
# Pattern: vars declared in .env.example but never referenced in src/ or
# project code. False-positive guard: skip vars marked with comment
# "# RUNTIME:" or starting with "PSK_" (kit infra) or "NEXT_PUBLIC_"
# (Next.js convention often referenced indirectly).
detect_unused_env_vars() {
  local example="$PROJ_ROOT/.env.example"
  [ -f "$example" ] || return 0

  # Source dirs to scan for usage
  local src_dirs=("$PROJ_ROOT/src" "$PROJ_ROOT/app" "$PROJ_ROOT/lib" "$PROJ_ROOT/server")

  # Read each line; honor `# RUNTIME:` comment marker on the SAME line as
  # the var declaration (e.g., `DATABASE_URL=... # RUNTIME: read by Prisma`).
  # Vars marked RUNTIME are runtime-injected by libraries / external runners
  # and shouldn't be flagged as unused even if not literally `process.env.X`.
  local line
  while IFS= read -r line; do
    # Skip comments + empty lines
    case "$line" in
      ''|'#'*) continue ;;
    esac
    # Skip lines explicitly marked runtime-only (inline `# RUNTIME:` comment)
    case "$line" in
      *'# RUNTIME:'*) continue ;;
    esac
    # Extract var name (everything before first =)
    local var="${line%%=*}"
    var="${var//[[:space:]]/}"  # trim whitespace
    [ -z "$var" ] && continue
    # Skip kit-prefixed and Next.js public conventions
    case "$var" in
      PSK_*|NEXT_PUBLIC_*|VERCEL_*) continue ;;
    esac

    # Search for any reference: process.env.VAR / os.environ['VAR'] / "$VAR"
    local found=false
    local d
    for d in "${src_dirs[@]}"; do
      [ -d "$d" ] || continue
      if grep -rq -E "(process\.env\.${var}|os\.environ\[['\"]${var}['\"]\]|getenv\(['\"]${var}['\"]\))" "$d" 2>/dev/null; then
        found=true
        break
      fi
    done

    if [ "$found" = false ]; then
      printf "%s:UNUSED_ENV: %s declared but never read in src/app/lib/server\n" "$example" "$var"
    fi
  done < "$example"
}

# Cat 6 — Detect oversized markdown sections that could be moved to
# skill files. Sections >200 lines under a single ## or ### heading
# are candidates. Excludes already-skill files and CHANGELOG/RELEASES
# (which legitimately accumulate content).
detect_oversized_markdown_sections() {
  local file="$PROJ_ROOT/portable-spec-kit.md"
  [ -f "$file" ] || return 0

  awk '
    /^##[#]? / {
      if (current_heading != "" && (NR - heading_line) > 200) {
        printf "%s:%d:OVERSIZED: section \"%s\" is %d lines — consider moving to a skill file\n", FILENAME, heading_line, current_heading, (NR - heading_line)
      }
      current_heading = $0
      heading_line = NR
    }
    END {
      if (current_heading != "" && (NR - heading_line) > 200) {
        printf "%s:%d:OVERSIZED: section \"%s\" is %d lines — consider moving to a skill file\n", FILENAME, heading_line, current_heading, (NR - heading_line)
      }
    }
  ' "$file"
}

# Cat 7 — Detect reflex prompt bloat. QA + Dev prompts are loaded fresh
# every pass; size matters for token cost. Threshold: >500 lines per
# prompt file → flag for review.
detect_reflex_prompt_bloat() {
  local prompts_dir="$PROJ_ROOT/reflex/prompts"
  [ -d "$prompts_dir" ] || return 0

  local f lines
  for f in "$prompts_dir"/*.md; do
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f")
    if [ "$lines" -gt 500 ]; then
      printf "%s:REFLEX_PROMPT_BLOAT: %d lines (>500 threshold) — every reflex pass loads this; consider trimming verbose narrative\n" "$f" "$lines"
    fi
  done
}

# Cat 9 — Detect rule-duplication via stub-section pattern.
# Pattern: a `### ` section whose ENTIRE body is a single skill-link
# blockquote (`> **Skill: X** — ... .md`) with no other substantive
# content. These are usually legacy stubs left behind when content
# moved into the canonical section + this stub was forgotten.
# Examples caught earlier today: §Python Environment (single-line
# pointer, superseded by §Environment Selection); §New Project Setup
# Procedure (single-line pointer, duplicate of §New Project Setup).
#
# False-positive guard: skill-cross-references INSIDE a section with
# its own substantive content are legitimate — only flag sections
# where the skill-link IS the section's content.
detect_duplicate_skill_refs() {
  local fwk="$PROJ_ROOT/portable-spec-kit.md"
  [ -f "$fwk" ] || return 0

  awk '
    /^### / {
      if (in_section && body_lines <= 2 && skill_link_in_body == 1) {
        printf "%s:%d:STUB_SECTION: \"%s\" is a single-skill-link stub (body=%d lines) — likely legacy duplicate, consolidate into canonical section\n", FILENAME, section_start, current_heading, body_lines
      }
      current_heading = $0
      sub(/^### /, "", current_heading)
      section_start = NR
      body_lines = 0
      skill_link_in_body = 0
      in_section = 1
      next
    }
    /^## / {
      if (in_section && body_lines <= 2 && skill_link_in_body == 1) {
        printf "%s:%d:STUB_SECTION: \"%s\" is a single-skill-link stub (body=%d lines) — likely legacy duplicate, consolidate into canonical section\n", FILENAME, section_start, current_heading, body_lines
      }
      in_section = 0
      next
    }
    in_section {
      if (/^[[:space:]]*$/) next  # blank lines do not count
      body_lines++
      if (/> \*\*Skill:.*\.md/) skill_link_in_body = 1
    }
    END {
      if (in_section && body_lines <= 2 && skill_link_in_body == 1) {
        printf "%s:%d:STUB_SECTION: \"%s\" is a single-skill-link stub (body=%d lines) — likely legacy duplicate, consolidate into canonical section\n", FILENAME, section_start, current_heading, body_lines
      }
    }
  ' "$fwk"
}

# Cat 8 — Detect reflex history retention violations.
# Per reflex/config.yml history_retention.pass_dirs_keep (default 10),
# old per-pass directories should be pruned. Flag if more than 2x the
# limit are accumulated (gives buffer for retention-script lag).
detect_reflex_history_bloat() {
  local hist="$PROJ_ROOT/reflex/history"
  local register="$hist/REFLEX_EVAL_TRACE.md"
  [ -d "$hist" ] || return 0

  local limit=10
  if [ -f "$PROJ_ROOT/reflex/config.yml" ]; then
    local cfg_limit
    cfg_limit=$(awk '/pass_dirs_keep:/ {gsub(/[^0-9]/,""); print; exit}' "$PROJ_ROOT/reflex/config.yml" 2>/dev/null)
    [ -n "$cfg_limit" ] && [ "$cfg_limit" -gt 0 ] 2>/dev/null && limit="$cfg_limit"
  fi

  local hard_cap=$((limit * 2))
  local pass_count
  pass_count=$(ls -1d "$hist"/cycle-*/pass-* "$hist"/standalone/pass-* 2>/dev/null | wc -l | tr -d ' ')

  if [ "$pass_count" -gt "$hard_cap" ]; then
    printf "%s:REFLEX_HISTORY_BLOAT: %d pass dirs accumulated (limit %d, hard cap %d) — run reflex/lib/prune-history.sh\n" "$hist" "$pass_count" "$limit" "$hard_cap"
  fi

  # Cumulative register size (each finding adds rows; can grow unbounded)
  if [ -f "$register" ]; then
    local size_kb
    size_kb=$(wc -c < "$register" | awk '{print int($1/1024)}')
    if [ "$size_kb" -gt 100 ]; then
      printf "%s:REFLEX_REGISTER_BLOAT: REFLEX_EVAL_TRACE.md is %dKB — consider archiving fully-closed cycles\n" "$register" "$size_kb"
    fi
  fi
}

# ---------- Output helpers ----------

print_punch_list() {
  echo -e "${CYAN}═══ psk-optimize scan ═══${NC}"
  echo "Project root: $PROJ_ROOT"
  echo ""

  local found_any=false

  # Cat 1 — duplicate version blocks
  echo -e "${CYAN}[1/9] Duplicate version-iteration entries${NC}"
  local f
  for f in "$PROJ_ROOT/CHANGELOG.md" "$PROJ_ROOT/agent/RELEASES.md"; do
    local out
    out=$(detect_duplicate_version_blocks "$f")
    if [ -n "$out" ]; then
      found_any=true
      echo -e "${YELLOW}  $f${NC}"
      echo "$out" | awk -F'\t' '{printf "    %s appears %s times — collapse into one block\n", $2, $3}'
    fi
  done
  echo ""

  # Cat 2 — stale numeric badges
  echo -e "${CYAN}[2/9] Stale numeric badges${NC}"
  local stale
  stale=$(detect_stale_test_counts 2>/dev/null)
  if [ -n "$stale" ]; then
    found_any=true
    echo "$stale" | sed "s|^|  ${YELLOW}|; s|\$|${NC}|"
  fi
  echo ""

  # Cat 3 — superseded-ADR bloat
  echo -e "${CYAN}[3/9] Superseded-ADR rationale bloat${NC}"
  local bloat
  bloat=$(detect_superseded_adr_bloat 2>/dev/null)
  if [ -n "$bloat" ]; then
    found_any=true
    echo "$bloat" | sed "s|^|  ${YELLOW}|; s|\$|${NC}|"
  fi
  echo ""

  # Cat 4 — stale file references
  echo -e "${CYAN}[4/9] Stale file references in markdown${NC}"
  local stale_refs
  stale_refs=$(detect_stale_file_refs 2>/dev/null)
  if [ -n "$stale_refs" ]; then
    found_any=true
    echo "$stale_refs" | sed "s|^|  ${YELLOW}|; s|\$|${NC}|"
  fi
  echo ""

  # Cat 5 — unused env vars
  echo -e "${CYAN}[5/9] Unused env vars in .env.example${NC}"
  local unused_env
  unused_env=$(detect_unused_env_vars 2>/dev/null)
  if [ -n "$unused_env" ]; then
    found_any=true
    echo "$unused_env" | sed "s|^|  ${YELLOW}|; s|\$|${NC}|"
  fi
  echo ""

  # Cat 6 — oversized markdown sections (skill candidates)
  echo -e "${CYAN}[6/9] Oversized framework sections (skill candidates)${NC}"
  local oversized
  oversized=$(detect_oversized_markdown_sections 2>/dev/null)
  if [ -n "$oversized" ]; then
    found_any=true
    echo "$oversized" | sed "s|^|  ${YELLOW}|; s|\$|${NC}|"
  fi
  echo ""

  # Cat 7 — reflex prompt bloat (token cost — every pass loads these)
  echo -e "${CYAN}[7/9] Reflex prompt bloat (token-cost optimization)${NC}"
  local prompt_bloat
  prompt_bloat=$(detect_reflex_prompt_bloat 2>/dev/null)
  if [ -n "$prompt_bloat" ]; then
    found_any=true
    echo "$prompt_bloat" | sed "s|^|  ${YELLOW}|; s|\$|${NC}|"
  fi
  echo ""

  # Cat 8 — reflex history retention violations
  echo -e "${CYAN}[8/9] Reflex history retention bloat${NC}"
  local hist_bloat
  hist_bloat=$(detect_reflex_history_bloat 2>/dev/null)
  if [ -n "$hist_bloat" ]; then
    found_any=true
    echo "$hist_bloat" | sed "s|^|  ${YELLOW}|; s|\$|${NC}|"
  fi
  echo ""

  # Cat 9 — duplicate skill references (rule duplication detection)
  echo -e "${CYAN}[9/9] Duplicate skill references (rule duplication)${NC}"
  local dup_skills
  dup_skills=$(detect_duplicate_skill_refs 2>/dev/null)
  if [ -n "$dup_skills" ]; then
    found_any=true
    echo "$dup_skills" | sed "s|^|  ${YELLOW}|; s|\$|${NC}|"
  fi
  echo ""

  # Cat 10 — rule-conflict detection (Phase 5 v0.6.21+)
  # Lazy: only check existence; full scan is invoked manually via psk-rule-conflicts.sh
  # to avoid slowness in /optimize --scan loop. Use --full-scan to invoke.
  echo -e "${CYAN}[10/13] Rule conflicts (always/never overlaps in MANDATORY rules)${NC}"
  if [ -x "$PROJ_ROOT/agent/scripts/psk-rule-conflicts.sh" ]; then
    if [ "${PSK_OPTIMIZE_FULL_SCAN:-0}" = "1" ]; then
      local rc_count
      rc_count=$(bash "$PROJ_ROOT/agent/scripts/psk-rule-conflicts.sh" --json 2>/dev/null | grep -oE '"conflict_count":[ ]*[0-9]+' | grep -oE '[0-9]+' | head -1)
      rc_count="${rc_count:-0}"
      if [ "$rc_count" -gt 0 ]; then
        found_any=true
        echo -e "  ${YELLOW}$rc_count potential conflict(s) detected — run psk-rule-conflicts.sh --scan for detail${NC}"
      fi
    else
      echo "  (lazy mode — run psk-rule-conflicts.sh --scan for live count, or set PSK_OPTIMIZE_FULL_SCAN=1)"
    fi
  else
    echo "  (psk-rule-conflicts.sh not present — skipped)"
  fi
  echo ""

  # Cat 11 — philosophy-violation scan (Phase 5 v0.6.21+)
  echo -e "${CYAN}[11/13] Philosophy violations (kit rules vs PHILOSOPHY.md principles)${NC}"
  if [ -f "$PROJ_ROOT/agent/PHILOSOPHY.md" ]; then
    # v1: count active principles + verify all 8 seeded
    local pcount
    pcount=$(grep -cE "^### P[0-9]+ — " "$PROJ_ROOT/agent/PHILOSOPHY.md" 2>/dev/null || echo 0)
    if [ "$pcount" -lt 8 ]; then
      found_any=true
      echo -e "  ${YELLOW}Only $pcount/8 principles seeded — PHILOSOPHY.md may be incomplete${NC}"
    fi
    # v1: deferred to LLM-probe layer for full violation detection
    # Currently advisory: just verify principles exist + check Mutation policy intact
    if ! grep -qiE "(mutation policy|never edited directly|gauntlet)" "$PROJ_ROOT/agent/PHILOSOPHY.md" 2>/dev/null; then
      found_any=true
      echo -e "  ${YELLOW}Mutation policy declaration missing in PHILOSOPHY.md (file could drift)${NC}"
    fi
  else
    echo "  (PHILOSOPHY.md not present — Phase 1 not yet shipped)"
  fi
  echo ""

  # Cat 12 — audit-coverage gap aggregation (Phase 5 v0.6.21+)
  echo -e "${CYAN}[12/13] Audit-coverage gaps (recurring patterns from QA philosophy-gaps.md)${NC}"
  local gaps_seen=0
  if [ -d "$PROJ_ROOT/reflex/history" ]; then
    # Find philosophy-gaps.md files across all reflex passes, aggregate gap-class mentions
    gaps_seen=$(find "$PROJ_ROOT/reflex/history" -name "philosophy-gaps.md" -exec grep -l "Audit-Coverage-Gaps" {} \; 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [ "$gaps_seen" -gt 0 ]; then
    echo "  $gaps_seen pass(es) with Audit-Coverage-Gaps section logged (review for recurring patterns)"
  else
    echo "  (no QA self-reflection data yet — Phase 2 reflex passes will populate this)"
  fi

  # v0.6.27+ — Tier 3 auto-probe-synthesis check.
  # Counts qa-blind-spots.md entries with status: open. These are
  # human-flagged misses needing a probe; synthesizer can scaffold proposals.
  local blind_spots_open=0
  if [ -f "$PROJ_ROOT/reflex/history/qa-blind-spots.md" ]; then
    blind_spots_open=$(grep -cE "^[[:space:]]+status:[[:space:]]+open" "$PROJ_ROOT/reflex/history/qa-blind-spots.md" 2>/dev/null | head -1)
    blind_spots_open="${blind_spots_open:-0}"
  fi
  if [ "$blind_spots_open" -gt 0 ]; then
    echo "  ${YELLOW}⚠ $blind_spots_open open blind-spot(s) in registry — run psk-blind-spot-synthesize.sh to scaffold probe proposals${NC}"
    found_any=1
  fi
  echo ""

  # Cat 13 — UI polish drift (Phase 7 v0.6.23+ — calls psk-ui-polish-check.sh)
  echo -e "${CYAN}[13/14] UI polish drift (P8 Client-Grade Output)${NC}"
  if [ -x "$PROJ_ROOT/agent/scripts/psk-ui-polish-check.sh" ]; then
    local ui_gap_count
    ui_gap_count=$(bash "$PROJ_ROOT/agent/scripts/psk-ui-polish-check.sh" --json 2>/dev/null | grep -oE '"gap_count":[ ]*[0-9]+' | grep -oE '[0-9]+' | head -1)
    ui_gap_count="${ui_gap_count:-0}"
    if [ "$ui_gap_count" -gt 0 ]; then
      found_any=true
      echo -e "  ${YELLOW}$ui_gap_count UI polish gap(s) — run psk-ui-polish-check.sh --scan for detail${NC}"
    fi
  else
    echo "  (psk-ui-polish-check.sh not present — skipped)"
  fi
  echo ""

  # Cat 14 — Probe redundancy (P9 Symmetric Self-Evolution, v0.6.28+)
  # Closes the structural blind spot user surfaced in v0.6.27: kit hunts for
  # gaps but not overlaps. Mode C 12-row seed shipped pure duplicate coverage
  # with no structural alarm. Cat 14 surfaces overlap clusters across
  # dimensions + Phase 0 helpers + sync-check functions + optimize cats.
  echo -e "${CYAN}[14/14] Probe redundancy (P9 Symmetric Self-Evolution)${NC}"
  if [ -x "$PROJ_ROOT/agent/scripts/psk-coverage-overlap-check.sh" ]; then
    local overlap_count
    overlap_count=$(bash "$PROJ_ROOT/agent/scripts/psk-coverage-overlap-check.sh" --json 2>/dev/null | grep -oE '"overlap_count":[ ]*[0-9]+' | grep -oE '[0-9]+' | head -1)
    overlap_count="${overlap_count:-0}"
    if [ "$overlap_count" -gt 0 ]; then
      found_any=true
      echo -e "  ${YELLOW}$overlap_count overlap cluster(s) detected — run psk-coverage-overlap-check.sh --scan for detail${NC}"
      echo -e "  ${YELLOW}Some overlaps are intentional defense-in-depth; review whether each cluster is consolidation candidate${NC}"
    else
      echo "  ✓ no overlap clusters — kit's probing mechanisms have non-redundant coverage"
    fi
  else
    echo "  (psk-coverage-overlap-check.sh not present — skipped)"
  fi
  echo ""

  if [ "$found_any" = false ]; then
    echo -e "${GREEN}✓ No bloat patterns detected. Files are token-optimized.${NC}"
    return 0
  fi

  echo -e "${CYAN}Next steps:${NC}"
  echo "  Review the punch list above. To apply cuts:"
  echo "    1. Run /optimize skill (agent walks each candidate, gate-verifies per cut)"
  echo "    2. Or fix manually — each cut must keep tests/test-spec-kit.sh + test-release-check.sh green"
  echo ""
  echo "  Safety contract: every cut is one atomic commit, gate-passed, revertable."
}

print_punch_list_json() {
  echo "{"
  echo "  \"project_root\": \"$PROJ_ROOT\","
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"candidates\": ["

  local first=true
  emit() {
    [ "$first" = false ] && echo ","
    first=false
    printf "    {\"category\":\"%s\",\"file\":\"%s\",\"line\":%s,\"summary\":\"%s\"}" "$1" "$2" "$3" "$4"
  }

  local f out
  for f in "$PROJ_ROOT/CHANGELOG.md" "$PROJ_ROOT/agent/RELEASES.md"; do
    out=$(detect_duplicate_version_blocks "$f")
    while IFS=$'\t' read -r dfile ver count; do
      [ -z "$dfile" ] && continue
      emit "duplicate_version_block" "$(basename "$dfile")" "0" "version $ver appears $count times"
    done <<< "$out"
  done

  out=$(detect_stale_test_counts 2>/dev/null)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local file ln summary
    file=$(echo "$line" | cut -d: -f1)
    ln=$(echo "$line" | cut -d: -f2)
    summary=$(echo "$line" | cut -d: -f3-)
    emit "stale_count" "$(basename "$file")" "$ln" "$summary"
  done <<< "$out"

  out=$(detect_superseded_adr_bloat 2>/dev/null)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local file ln summary
    file=$(echo "$line" | cut -d: -f1)
    ln=$(echo "$line" | cut -d: -f2)
    summary=$(echo "$line" | cut -d: -f3-)
    emit "superseded_adr_bloat" "$(basename "$file")" "$ln" "$summary"
  done <<< "$out"

  out=$(detect_stale_file_refs 2>/dev/null)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local file summary
    file=$(echo "$line" | cut -d: -f1)
    summary=$(echo "$line" | cut -d: -f2-)
    emit "stale_file_ref" "$(basename "$file")" "0" "$summary"
  done <<< "$out"

  out=$(detect_unused_env_vars 2>/dev/null)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local summary
    summary=$(echo "$line" | cut -d: -f2-)
    emit "unused_env_var" ".env.example" "0" "$summary"
  done <<< "$out"

  out=$(detect_oversized_markdown_sections 2>/dev/null)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local file ln summary
    file=$(echo "$line" | cut -d: -f1)
    ln=$(echo "$line" | cut -d: -f2)
    summary=$(echo "$line" | cut -d: -f3-)
    emit "oversized_section" "$(basename "$file")" "$ln" "$summary"
  done <<< "$out"

  out=$(detect_reflex_prompt_bloat 2>/dev/null)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local file summary
    file=$(echo "$line" | cut -d: -f1)
    summary=$(echo "$line" | cut -d: -f2-)
    emit "reflex_prompt_bloat" "$(basename "$file")" "0" "$summary"
  done <<< "$out"

  out=$(detect_reflex_history_bloat 2>/dev/null)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local file summary
    file=$(echo "$line" | cut -d: -f1)
    summary=$(echo "$line" | cut -d: -f2-)
    emit "reflex_history_bloat" "$(basename "$file")" "0" "$summary"
  done <<< "$out"

  out=$(detect_duplicate_skill_refs 2>/dev/null)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local file summary
    file=$(echo "$line" | cut -d: -f1)
    summary=$(echo "$line" | cut -d: -f2-)
    emit "duplicate_skill_ref" "$(basename "$file")" "0" "$summary"
  done <<< "$out"

  echo ""
  echo "  ]"
  echo "}"
}

# ---------- Safety check ----------

run_safety_check() {
  echo -e "${CYAN}═══ psk-optimize safety check ═══${NC}"
  echo "Verifies the kit's gate suite is green BEFORE any prune sweep."
  echo ""

  local fw_runner="$PROJ_ROOT/tests/test-spec-kit.sh"
  local rel_runner="$PROJ_ROOT/tests/test-release-check.sh"

  if [ ! -f "$fw_runner" ]; then
    echo -e "${YELLOW}⚠ tests/test-spec-kit.sh not found — kit-only tool. Skipping framework gate.${NC}"
  else
    echo "Running tests/test-spec-kit.sh ..."
    if bash "$fw_runner" >/dev/null 2>&1; then
      echo -e "${GREEN}  ✓ framework gate green${NC}"
    else
      echo -e "${RED}  ✗ framework gate FAILED — fix this before running a prune sweep${NC}"
      return 1
    fi
  fi

  if [ -f "$rel_runner" ]; then
    echo "Running tests/test-release-check.sh ..."
    if bash "$rel_runner" >/dev/null 2>&1; then
      echo -e "${GREEN}  ✓ release-check (R→F→T) gate green${NC}"
    else
      echo -e "${YELLOW}  ⚠ release-check gate FAILED — investigate before pruning${NC}"
    fi
  fi

  echo ""
  echo -e "${GREEN}Safety check passed. Pre-cut snapshot is clean — safe to begin a prune sweep.${NC}"
  echo "Record HEAD for revert anchor: $(git -C "$PROJ_ROOT" rev-parse --short HEAD 2>/dev/null || echo 'no-git')"
}

# ---------- State tracking ----------

# Compute total candidate count by running every detector and counting
# non-empty findings. Returns "<total>:<deferred-cat-list>".
compute_candidate_counts() {
  local cat1 cat2 cat3 cat4 cat5 cat6 cat7 cat8 cat9

  cat1=0
  for f in "$PROJ_ROOT/CHANGELOG.md" "$PROJ_ROOT/agent/RELEASES.md"; do
    local out; out=$(detect_duplicate_version_blocks "$f")
    [ -n "$out" ] && cat1=$((cat1 + $(echo "$out" | wc -l | tr -d ' ')))
  done
  cat2=$(detect_stale_test_counts 2>/dev/null | wc -l | tr -d ' ')
  cat3=$(detect_superseded_adr_bloat 2>/dev/null | wc -l | tr -d ' ')
  cat4=$(detect_stale_file_refs 2>/dev/null | wc -l | tr -d ' ')
  cat5=$(detect_unused_env_vars 2>/dev/null | wc -l | tr -d ' ')
  cat6=$(detect_oversized_markdown_sections 2>/dev/null | wc -l | tr -d ' ')
  cat7=$(detect_reflex_prompt_bloat 2>/dev/null | wc -l | tr -d ' ')
  cat8=$(detect_reflex_history_bloat 2>/dev/null | wc -l | tr -d ' ')
  cat9=$(detect_duplicate_skill_refs 2>/dev/null | wc -l | tr -d ' ')

  local total=$((cat1 + cat2 + cat3 + cat4 + cat5 + cat6 + cat7 + cat8 + cat9))
  echo "${total}|${cat1}|${cat2}|${cat3}|${cat4}|${cat5}|${cat6}|${cat7}|${cat8}|${cat9}"
}

# Update .portable-spec-kit/optimize-state.yml with current scan results.
# Idempotent + atomic (write to temp, mv into place).
write_state_file() {
  local counts="$1"
  local total c1 c2 c3 c4 c5 c6 c7 c8
  IFS='|' read -r total c1 c2 c3 c4 c5 c6 c7 c8 c9 <<< "$counts"

  local state_dir
  state_dir="$(dirname "$STATE_FILE")"
  [ -d "$state_dir" ] || mkdir -p "$state_dir"

  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Compute recommended_next_scan = now + 30 days (POSIX-portable).
  local next_ts
  if next_ts=$(date -u -v +30d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null); then
    : # macOS BSD date worked
  elif next_ts=$(date -u -d "+30 days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null); then
    : # GNU date worked
  else
    next_ts="unknown"
  fi

  # Status: optimized | review | stale (computed from total + age — we
  # only know "now" age; stale-by-age applies on read in --health mode).
  local status="optimized"
  if [ "$total" -ge 10 ]; then
    status="stale"
  elif [ "$total" -ge 3 ]; then
    status="review"
  fi

  local tmp="${STATE_FILE}.tmp.$$"
  {
    echo "# Generated by agent/scripts/psk-optimize.sh — do not edit by hand."
    echo "# Read by /optimize skill + breadcrumb-indicator rule (portable-spec-kit.md)."
    echo "schema_version: 1"
    echo "last_scan: $now"
    echo "candidates_total: $total"
    echo "candidates_by_category:"
    echo "  cat1_duplicate_versions: $c1"
    echo "  cat2_stale_badges: $c2"
    echo "  cat3_superseded_adr_bloat: $c3"
    echo "  cat4_stale_file_refs: $c4"
    echo "  cat5_unused_env_vars: $c5"
    echo "  cat6_oversized_sections: $c6"
    echo "  cat7_reflex_prompt_bloat: $c7"
    echo "  cat8_reflex_history_bloat: $c8"
    echo "  cat9_duplicate_skill_refs: $c9"
    echo "recommended_next_scan: $next_ts"
    echo "status: $status"
  } > "$tmp" && mv "$tmp" "$STATE_FILE"
}

# Read state file + emit one-line health indicator.
# Format: "<emoji> <status> [— <detail>]"
# Used by agents to append to breadcrumb header per portable-spec-kit.md
# §Optimization Health Indicator rule.
# Count deferred entries (lines under `deferred:` list in the deferred-config file).
count_deferred() {
  [ -f "$DEFERRED_FILE" ] || { echo 0; return; }
  awk '/^deferred:/{in_d=1; next} /^[a-zA-Z_]+:/{in_d=0} in_d && /^[[:space:]]*-[[:space:]]*id:/{c++} END{print c+0}' "$DEFERRED_FILE"
}

emit_health() {
  if [ ! -f "$STATE_FILE" ]; then
    echo "🔴 stale — never scanned (run: bash agent/scripts/psk-optimize.sh --scan)"
    return
  fi

  local last_scan total status deferred active
  last_scan=$(awk -F': ' '$1=="last_scan"{print $2; exit}' "$STATE_FILE")
  total=$(awk -F': ' '$1=="candidates_total"{print $2; exit}' "$STATE_FILE")
  total="${total:-0}"
  deferred=$(count_deferred)
  active=$((total - deferred))
  [ "$active" -lt 0 ] && active=0

  # Recompute status from active count (excluding deferred).
  if [ "$active" -ge 10 ]; then
    status="stale"
  elif [ "$active" -ge 3 ]; then
    status="review"
  else
    status="optimized"
  fi

  # Compute days-since-last-scan (POSIX-portable).
  local days=0
  if [ -n "$last_scan" ]; then
    local now_epoch scan_epoch
    if now_epoch=$(date -u +%s 2>/dev/null) && \
       scan_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_scan" +%s 2>/dev/null); then
      : # macOS
    elif scan_epoch=$(date -u -d "$last_scan" +%s 2>/dev/null); then
      : # GNU
    else
      scan_epoch=""
    fi
    if [ -n "$scan_epoch" ] && [ -n "$now_epoch" ]; then
      days=$(( (now_epoch - scan_epoch) / 86400 ))
    fi
  fi

  # Apply age-based escalation: review if >30d, stale if >60d.
  # Exception (KIT-GAP-N69 fix, 2026-05-30): if every candidate is explicitly
  # deferred (active=0 && deferred>0), the operator has handled the backlog —
  # honor that decision regardless of scan age. Deferral IS a form of handling;
  # ageing the indicator would punish the operator for organizing the backlog.
  if [ "$days" -gt 60 ] && { [ "$active" -gt 0 ] || [ "$deferred" -eq 0 ]; }; then
    status="stale"
  elif [ "$days" -gt 30 ] && [ "$status" = "optimized" ] && \
       { [ "$active" -gt 0 ] || [ "$deferred" -eq 0 ]; }; then
    status="review"
  fi

  case "$status" in
    optimized)
      if [ "$deferred" -gt 0 ]; then
        echo "🟢 optimized ($deferred deferred)"
      else
        echo "🟢 optimized"
      fi
      ;;
    review)
      if [ "$days" -gt 30 ]; then
        echo "🟡 review (${days}d since scan, $active candidates)"
      else
        if [ "$deferred" -gt 0 ]; then
          echo "🟡 review ($active candidates, $deferred deferred)"
        else
          echo "🟡 review ($active candidates)"
        fi
      fi
      ;;
    stale)
      echo "🔴 stale (${days}d since scan, $active candidates — sweep recommended)"
      ;;
    *)
      echo "⚪ unknown — re-run --scan to refresh state"
      ;;
  esac
}

# ---------- Dispatch ----------

case "$MODE" in
  scan)
    if [ "$JSON" = true ]; then
      print_punch_list_json
    else
      print_punch_list
    fi
    # State write — side-effect of every --scan. Counts already computed
    # by the print_punch_list helpers; recompute once for state file
    # (cheap: detectors are O(repo size) and cached at OS-buffer level
    # after the first run). Total added cost: ~5-50ms.
    write_state_file "$(compute_candidate_counts)"
    ;;
  health)
    # Read-only fast-path. ~5ms — just parses YAML state file.
    emit_health
    ;;
  safety-check)
    run_safety_check
    ;;
esac
