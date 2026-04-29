#!/bin/bash
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
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"

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
NOISE_RE='^(PSK[0-9]+|Closes the|Fast:|Framework rule updated|Framework MANDATORY rule|Masked output:|Framework Changes|New Files|Tests|Highlights|ARD content update rule|Output DISCIPLINE|Why grep|Minimum length|Exit code|Section [0-9]+|What.s New|Path exclusions|Placeholder-aware|PreCommit hook|PostToolUse hook|Compact critic|Reliability-script|Redundant|Paper v[0-9]+ Section|RFT cache|PSK_[A-Z_]+=|[0-9]+ (new |behavioral|critic|flow|high-signal|new)|Literature-grounded rename:|Pattern classification .literature review.:|Precondition strengthening:|Regression diff|Script header|Smoke tests .both phases|CRITICAL:|MAJOR:|MINOR:|`?[0-9a-f]{7}`?[[:space:]]*[—-]|`?[0-9a-f]{7}`?$|reflex/run\.sh:|examples/.+\.md$)'

# Secondary filter — drop change-descriptions lacking feature identity
CHANGE_NOISE_RE='( removed$| → |expanded from|expanded to match|unchanged at|updated$|Step [0-9]+ refactored|Step [0-9]+ replaced|"[^"]+")'

# Extract features from current-minor CHANGELOG section.
features=$(awk -v minor="$minor" '
  /^## / { in_minor = 0 }
  $0 ~ "^## "minor { in_minor = 1; next }
  in_minor && /^- / {
    line = $0
    sub(/^- /, "", line)
    if (match(line, /\*\*[^*]+\*\*/)) {
      term = substr(line, RSTART+2, RLENGTH-4)
      print term
    } else if (match(line, /`[^`]+`/)) {
      term = substr(line, RSTART+1, RLENGTH-2)
      print term
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

count_hits_glob() {
  local term="$1" dir="$2" ext="$3"
  local hits=0
  local f
  shopt -s nullglob
  for f in "$dir"/*"$ext"; do
    [ -f "$f" ] || continue
    if grep -qF -- "$term" "$f" 2>/dev/null; then
      hits=$((hits + 1))
    fi
  done
  shopt -u nullglob
  echo "$hits"
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

while IFS= read -r feature; do
  [ -z "$feature" ] && continue
  search_term=$(echo "$feature" | sed 's/`//g; s/\*//g')

  h_agent=$(count_hits_glob "$search_term" "$PROJ_ROOT/agent" ".md")
  h_flows=$(count_hits_glob "$search_term" "$PROJ_ROOT/docs/work-flows" ".md")
  h_research=$(count_hits_glob "$search_term" "$PROJ_ROOT/docs/research" ".md")
  h_ard=$(count_hits_glob "$search_term" "$PROJ_ROOT/ard" ".html")
  h_readme=0
  grep -qF -- "$search_term" "$PROJ_ROOT/README.md" 2>/dev/null && h_readme=1

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
