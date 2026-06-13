#!/bin/bash
# mechanical-script: psk-doc-sync.sh — ARD/docs reconciliation (no AI invocation)
# =============================================================
# psk-doc-sync.sh — CHANGELOG → Full Documentation Coverage Analyzer
#
# Purpose: during prepare release Step 4, identify which features
# in the current-minor CHANGELOG entry are not yet reflected in
# ANY documentation surface. Used by the agent to know where to
# update (existing file), create (new flow doc), or expand.
#
# Covered surfaces:
#   agent/*.md               — pipeline + support files
#   docs/work-flows/*.md     — all 16 workflow docs
#   docs/research/*.md       — research paper(s)
#   ard/*.html               — architecture reference docs
#   README.md                — top-level overview
#
# This is an ADVISORY tool — reports gaps, does not modify files.
# Agent reads the report and acts.
#
# Usage:
#   bash agent/scripts/psk-doc-sync.sh              # advisory report
#   bash agent/scripts/psk-doc-sync.sh --strict     # exit 1 if any gap
#
# Exit codes:
#   0 = all features covered OR advisory mode (default)
#   1 = gaps found AND --strict flag set
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Honor a caller-provided PROJ_ROOT (testability + explicit-root invocation); fall
# back to the script-relative location otherwise. Anchored fallback — no CWD reliance.
PROJ_ROOT="${PROJ_ROOT:-$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

STRICT=false
[ "${1:-}" = "--strict" ] && STRICT=true

CHANGELOG="$PROJ_ROOT/CHANGELOG.md"
CTX="$PROJ_ROOT/agent/AGENT_CONTEXT.md"

[ ! -f "$CHANGELOG" ] && { echo "No CHANGELOG.md — skipping"; exit 0; }
[ ! -f "$CTX" ] && { echo "No agent/AGENT_CONTEXT.md — skipping"; exit 0; }

# Current minor version
cur_ver=$(grep -E '^\- \*\*Version:\*\*' "$CTX" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
minor=$(echo "$cur_ver" | grep -oE 'v[0-9]+\.[0-9]+')
[ -z "$minor" ] && { echo "Cannot determine current minor from AGENT_CONTEXT.md"; exit 0; }

echo -e "${CYAN}═══ psk-doc-sync — CHANGELOG $minor → Full Documentation Coverage ═══${NC}"

# Noise filter — drop release-meta phrases that aren't real features
# Matches: internal error codes, release headers, trailing-colon headers, test/ARD meta,
#         env vars, change-description phrases ("X removed", "Y → Z"), numeric-count
#         sentences, and historical narrative lines.
# QA-D25 fix: also drop internal trace/finding identifiers (KIT-GAP-*, QA-* finding
# IDs, ADR-*, ADL-*) — these are bolded in CHANGELOG bullets as the change's anchor
# but are infrastructure references, never user-facing "features" needing doc coverage.
NOISE_RE='^(KIT-GAP-[0-9A-Za-z]+|QA-[A-Z0-9][A-Z0-9-]*|ADR-[0-9]+|ADL-|PSK[0-9]+|Closes the|Fast:|Framework rule updated|Framework MANDATORY rule|Masked output:|Framework Changes|New Files|Tests|Highlights|ARD content update rule|Output DISCIPLINE|Why grep|Minimum length|Exit code|Section [0-9]+|What.s New|Path exclusions|Placeholder-aware|PreCommit hook|PostToolUse hook|Compact critic|Reliability-script|Redundant|Paper v[0-9]+ Section|RFT cache|PSK_[A-Z_]+=|[0-9]+ (new |behavioral|critic|flow|high-signal|new)|Literature-grounded rename:|Pattern classification .literature review.:|Precondition strengthening:|Regression diff|Script header|Smoke tests .both phases|CRITICAL:|MAJOR:|MINOR:|`?[0-9a-f]{7}`?[[:space:]]*[—-]|`?[0-9a-f]{7}`?$|reflex/run\.sh:|examples/.+\.md$)'

# Secondary filter — drop change-descriptions lacking feature identity
CHANGE_NOISE_RE='( removed$| → |expanded from|expanded to match|unchanged at|updated$|Step [0-9]+ refactored|Step [0-9]+ replaced|"[^"]+")'

# Extract features from current-minor CHANGELOG section.
features=$(awk -v minor="$minor" '
  /^## / { in_minor = 0 }
  $0 ~ "^## "minor { in_minor = 1; next }
  in_minor && /^- / {
    line = $0
    sub(/^- /, "", line)
    # QA-DOC-11-01: emit "term \t fullline" — the bolded term is the display name
    # + name-match key; the full bullet line is the source for identity-token
    # extraction (script names / flags / codes live in the DESCRIPTION, not the
    # bold name). The NOISE_RE/CHANGE_NOISE_RE filters are ^-anchored to the term,
    # so they still filter correctly on field 1.
    if (match(line, /\*\*[^*]+\*\*/)) {
      term = substr(line, RSTART+2, RLENGTH-4)
      print term "\t" line
    } else if (match(line, /`[^`]+`/)) {
      term = substr(line, RSTART+1, RLENGTH-2)
      print term "\t" line
    }
  }
' "$CHANGELOG" | grep -vE "$NOISE_RE" | grep -vE "$CHANGE_NOISE_RE" | sort -u)

if [ -z "$features" ]; then
  echo -e "${YELLOW}No features extracted from CHANGELOG $minor section.${NC}"
  exit 0
fi

feature_count=$(echo "$features" | wc -l | tr -d ' ')

n_agent=$(ls "$PROJ_ROOT"/agent/*.md 2>/dev/null | wc -l | tr -d ' ')
n_flows=$(ls "$PROJ_ROOT"/docs/work-flows/*.md 2>/dev/null | wc -l | tr -d ' ')
n_research=$(ls "$PROJ_ROOT"/docs/research/*.md 2>/dev/null | wc -l | tr -d ' ')
n_ard=$(ls "$PROJ_ROOT"/ard/*.html 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo -e "Analyzing ${CYAN}$feature_count${NC} features against:"
echo -e "  ${CYAN}$n_agent${NC} agent/*.md  ·  ${CYAN}$n_flows${NC} docs/work-flows/*.md  ·  ${CYAN}$n_research${NC} docs/research/*.md  ·  ${CYAN}$n_ard${NC} ard/*.html  ·  README.md"
echo ""

# QA-DOC-11-01: a CHANGELOG feature line is a whole prose phrase
# ("B3 reflex/run.sh: wired the missing --resume-dims re-entry…"). Docs never
# repeat that exact prose, so full-phrase grep -F false-reports MISSING for any
# feature that IS documented under its identity tokens (script name, flag, PSK /
# KIT-GAP code). Extract those stable identifiers so a feature counts as covered
# when its script/flag/code appears in a surface — not only when the whole
# sentence does.
extract_identity_tokens() {
  printf '%s\n' "$1" | grep -oE '[A-Za-z0-9_-]+\.(sh|ts|js|mjs|py)|--[a-z][a-z0-9-]+|PSK[0-9]+|KIT-GAP-[0-9]+|ADR-[0-9]+' | sort -u
}

# PERF (no-silent-wait follow-up, cycle-01/pass-002): the original matcher spawned
# one `grep` per (feature × file × identity-token) — an O(features×files×tokens)
# subprocess explosion that made a full run take ~11 MINUTES (the kit's single
# slowest op, dominating every test suite + reflex gate). Replaced with an in-memory
# match against a per-surface corpus read ONCE: zero per-feature subprocesses.
# MISSING detection (total==0) is byte-for-byte identical; `total` now counts COVERED
# SURFACES (0-5) instead of matching files — the same signal the `surf` legend (the
# user-facing A/F/P/D/R flags) already shows, so COVERED/PARTIAL semantics stay
# meaningful ("documented across ≥2 doc surfaces") and the --strict gate (Missing>0)
# is unchanged. Cuts an ~11-minute op to seconds.
# TRUE if ANY of a feature's patterns (its name + identity tokens, $2 newline-
# delimited) appears in $1 — a precomputed PER-SURFACE present-set (the small set of
# patterns that actually occur in that surface; built by the inverted scan below).
# Matching the tiny present-set instead of the full multi-hundred-KB corpus is what
# takes a run from ~90s to a few seconds. `case` substring matching is semantically
# identical to the old per-file `grep -F` (both substring), so MISSING detection
# (total==0, the --strict gate) and the 203/27/26 result are unchanged. `total` now
# counts COVERED SURFACES (0-5) — the signal the user-facing A/F/P/D/R legend shows.
_set_covers() {
  local present="$1" pats="$2" p
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$present" in *"$p"*) return 0 ;; esac
  done <<< "$pats"
  return 1
}

suggest_doc() {
  local term="$1"
  local lc
  lc=$(echo "$term" | tr '[:upper:]' '[:lower:]')
  case "$lc" in
    *psk01*|*critic*|*sync-check*|*reliability*|*check_*|*verbatim*|*bypass*)
      echo "13-release-workflow.md (reliability infrastructure)" ;;
    *release*|*prepare*|*changelog*)
      echo "13-release-workflow.md" ;;
    *feature*|*spec*|*plan*|*design*)
      echo "11-spec-persistent-development.md or 16-feature-design.md" ;;
    *ci*|*actions*|*github*)
      echo "06-cicd-setup.md" ;;
    *init*|*reinit*)
      echo "05-project-init.md" ;;
    *setup*|*scaffold*|*project*)
      echo "03-new-project-setup.md or 04-existing-project-setup.md" ;;
    *jira*|*tracker*|*hours*)
      echo "15-jira-integration.md" ;;
    *onboard*|*tour*|*profile*|*config*)
      echo "02-user-profile-setup.md or 09-profile-customization.md" ;;
    *agent*|*pipeline*)
      echo "11-spec-persistent-development.md" ;;
    *)
      echo "NEW_DOC — consider creating a dedicated flow doc" ;;
  esac
}

covered=0
partial=0
missing=0
gap_lines=""

# INVERTED SCAN (perf — see _set_covers note above). Build the union of EVERY
# feature's patterns once, then read each surface's files ONCE with a single
# grep -ohFf to learn which patterns are present there (a small per-surface set).
# Classification then matches each feature against these tiny sets — O(surfaces)
# file reads instead of O(features×files×tokens) greps. ~90s → a few seconds.
_ALL_PAT=$(mktemp)
{
  cut -f1 <<< "$features" | sed 's/`//g; s/\*//g'       # feature display names
  extract_identity_tokens "$(cut -f2 <<< "$features")"  # tokens from all full-lines at once
} | grep -v '^[[:space:]]*$' | sort -u > "$_ALL_PAT"

# present-set per surface; guard empty file lists (nullglob) so grep never reads stdin.
_present() { [ "$#" -eq 0 ] && return 0; grep -ohFf "$_ALL_PAT" "$@" 2>/dev/null | sort -u; }
shopt -s nullglob
_PRESENT_AGENT=$(_present "$PROJ_ROOT"/agent/*.md)
_PRESENT_FLOWS=$(_present "$PROJ_ROOT"/docs/work-flows/*.md)
_PRESENT_RESEARCH=$(_present "$PROJ_ROOT"/docs/research/*.md)
_PRESENT_ARD=$(_present "$PROJ_ROOT"/ard/*.html)
_PRESENT_README=$(_present "$PROJ_ROOT"/README.md)
shopt -u nullglob

while IFS=$'\t' read -r feature fullline; do
  [ -z "$feature" ] && continue
  search_term=$(echo "$feature" | sed 's/`//g; s/\*//g')
  # token source = the full CHANGELOG line (script names / flags live in the
  # description); fall back to the name when no description was captured.
  token_src="${fullline:-$feature}"

  # This feature's patterns (name + tokens), computed ONCE, matched against each
  # surface's tiny present-set (not the full corpus).
  _feat_pats=$(printf '%s\n' "$search_term"; extract_identity_tokens "$token_src")
  h_agent=0;    _set_covers "$_PRESENT_AGENT"    "$_feat_pats" && h_agent=1
  h_flows=0;    _set_covers "$_PRESENT_FLOWS"    "$_feat_pats" && h_flows=1
  h_research=0; _set_covers "$_PRESENT_RESEARCH" "$_feat_pats" && h_research=1
  h_ard=0;      _set_covers "$_PRESENT_ARD"      "$_feat_pats" && h_ard=1
  h_readme=0;   _set_covers "$_PRESENT_README"   "$_feat_pats" && h_readme=1

  total=$((h_agent + h_flows + h_research + h_ard + h_readme))

  surf=""
  [ "$h_agent" -gt 0 ] && surf="${surf}A" || surf="${surf}."
  [ "$h_flows" -gt 0 ] && surf="${surf}F" || surf="${surf}."
  [ "$h_research" -gt 0 ] && surf="${surf}P" || surf="${surf}."
  [ "$h_ard" -gt 0 ] && surf="${surf}D" || surf="${surf}."
  [ "$h_readme" -gt 0 ] && surf="${surf}R" || surf="${surf}."

  short_term=$(echo "$search_term" | cut -c1-50)

  if [ "$total" -eq 0 ]; then
    missing=$((missing + 1))
    suggestion=$(suggest_doc "$search_term")
    gap_lines="${gap_lines}  ${RED}✗${NC} MISSING [$surf] ${short_term}\n       → suggested: $suggestion\n"
  elif [ "$total" -lt 2 ]; then
    partial=$((partial + 1))
    printf "  ${YELLOW}◐${NC} PARTIAL [%s] %s\n" "$surf" "$short_term"
  else
    covered=$((covered + 1))
    printf "  ${GREEN}✓${NC} COVERED [%s] %s\n" "$surf" "$short_term"
  fi
done <<< "$features"
rm -f "$_ALL_PAT" 2>/dev/null || true

echo ""
if [ -n "$gap_lines" ]; then
  echo -e "${YELLOW}── Zero-surface gaps (feature in CHANGELOG but in NO doc) ──${NC}"
  printf "%b" "$gap_lines"
fi

echo ""
echo "──────────────────────────────────────────────────────"
echo -e "  Surface legend: [A]gent  [F]low-docs  [P]aper  AR[D]  [R]eadme"
echo -e "  Covered (≥2 surfaces): ${GREEN}$covered${NC} / $feature_count"
echo -e "  Partial (1 surface):   ${YELLOW}$partial${NC} / $feature_count"
echo -e "  Missing (0 surfaces):  ${RED}$missing${NC} / $feature_count"
echo "──────────────────────────────────────────────────────"

total_gaps=$((missing + partial))
if [ "$total_gaps" -gt 0 ]; then
  echo ""
  echo -e "${YELLOW}Agent action during Step 4:${NC}"
  echo "  1. For each MISSING feature — decide:"
  echo "     (a) add to suggested existing doc, OR"
  echo "     (b) create NEW flow doc if feature is a distinct user-facing workflow"
  echo "         (numbered next sequential — e.g. 17-new-feature.md)"
  echo "  2. For PARTIAL (1-surface) features — decide if more surfaces need it:"
  echo "     - User-facing workflow → flow-docs"
  echo "     - Architecture/agent behavior → agent/*.md"
  echo "     - Methodology → research paper"
  echo "     - Public overview → README Latest Release"
  echo "     - Technical detail → ard/*.html"
  echo "  3. If new flow doc created → update README Flows table (PSK015 blocks otherwise)"
  echo "  4. Re-run: bash agent/scripts/psk-doc-sync.sh"
  echo "  5. Iterate until Missing=0 and Partial is acceptable (author's judgment)"

  # v0.6.13 — --strict semantics tightened (closes ambiguity surfaced via QA pass-004
  # gate failure): fail ONLY on Missing>0 (zero-surface features). Partial (1-surface)
  # is acceptable for internal infrastructure that legitimately belongs on one surface
  # by design — matches the QA prompt rule "PARTIAL is acceptable for internal items".
  [ "$STRICT" = true ] && [ "$missing" -gt 0 ] && exit 1
fi

exit 0
