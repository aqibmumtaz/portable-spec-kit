#!/bin/bash
# =============================================================
# psk-critic-spawn.sh — Sub-Agent Critic File Protocol
#
# Manages the file-based protocol between psk-release.sh and
# the main agent for spawning sub-agent critics.
#
# Protocol:
#   1. psk-release.sh calls: psk-critic-spawn.sh write <step> <task>
#      → Writes critic-task.md with the prompt
#      → Sets AWAITING_CRITIC state
#
#   2. Main agent reads critic-task.md, spawns sub-agent via Task tool,
#      writes response to critic-result.md
#
#   3. psk-release.sh calls: psk-critic-spawn.sh check <step>
#      → Reads critic-result.md
#      → Returns 0 if all CURRENT, 1 if any STALE
#
# Usage:
#   bash agent/scripts/psk-critic-spawn.sh write STEP_4_FLOW_DOCS
#   bash agent/scripts/psk-critic-spawn.sh check STEP_4_FLOW_DOCS
#   bash agent/scripts/psk-critic-spawn.sh status
#   bash agent/scripts/psk-critic-spawn.sh clear
#
# Exit codes:
#   0 = critic passed (all CURRENT) or task written successfully
#   1 = critic failed (STALE found) or iteration cap reached
#   2 = configuration error
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/../.release-state"
TASK_FILE="$STATE_DIR/critic-task.md"
RESULT_FILE="$STATE_DIR/critic-result.md"
ITERATION_FILE="$STATE_DIR/critic-iterations"
PROJ_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"

MAX_ITERATIONS=5

# Colors
if [ -t 1 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; CYAN=''; NC=''
fi

ACTION="${1:-status}"
STEP="${2:-}"

# --- Critic task templates ---
# v0.5.16 Opt 7 — compact output discipline appended to every critic prompt.
# Shared to keep per-release token cost low without diluting per-step checks.
output_discipline() {
  cat <<'FOOTER'

OUTPUT DISCIPLINE (v0.5.16 — enforced):
- Return ONLY the CURRENT/QUOTE/STALE lines. No preamble, no "I'll analyze…", no summary, no markdown headers, no explanations.
- Target ≤400 tokens total. Reasoning is internal; your output is machine-parsed.
- Any prose outside the CURRENT/QUOTE/STALE format is ignored AND may trigger verifier rejection for malformed output.
- QUOTE lines: copy an existing line from the file verbatim. Do not paraphrase. The verifier runs `grep -F` against the file.
FOOTER
}

get_critic_prompt() {
  local step="$1"
  case "$step" in
    STEP_4_FLOW_DOCS)
      cat <<'PROMPT'
You are a flow-docs verification critic. You have NOT seen the main conversation. You have no prior context on what the main agent did.

Task: Read every .md file in docs/work-flows/. For each file, verify it accurately describes the CURRENT release process and workflows.

Checks to perform per file:
1. Compare step counts in the doc vs. actual scripts (psk-release.sh, psk-critic-spawn.sh).
2. Verify validation is described at Step 9 (not Step 4).
3. Verify all feature/version/test count mentions match agent/AGENT_CONTEXT.md current state.
4. Check for references to old/removed features (grep CHANGELOG for "removed" patterns — these should NOT be in flow docs).
5. Check for process descriptions that contradict current framework rules (e.g., old "agent marks done" if that was replaced with artifact gates).

Do NOT trust file mtimes. READ the actual content line-by-line.

Additional check: compare each flow doc's scope keywords (release, jira, init, etc.) against CHANGELOG entries for the current version. If a feature that changed this release has no corresponding flow doc update, flag it as STALE.

OMISSION DETECTION (MANDATORY — this is the primary gap critic caught you missing previously):
1. Read the current-minor entry in CHANGELOG.md (look for `## v0.N` where N = current minor from AGENT_CONTEXT.md).
2. Extract every bullet point / feature / script / capability listed under that entry and its patch sub-entries (`### v0.N.x`).
3. For each extracted feature, grep ALL flow docs for a mention (by script name, PSK error code, feature keyword, or section name).
4. If ANY current-minor feature has ZERO flow doc references → that is STALE with format:
   `STALE: docs/work-flows/ — feature "<feature-name>" in CHANGELOG v0.N.x but no flow doc mentions it`
5. Critical: this catches OMISSIONS (missing info), not just contradictions (wrong info). Both are stale. Omission is the more common failure mode and was what caused v0.5.13–v0.5.18 flow doc drift.

AUTOMATED COVERAGE TOOL (MANDATORY — run before manual inspection):
Run `bash agent/scripts/psk-doc-sync.sh` and read its output. It checks every feature in the current-minor CHANGELOG against 5 doc surfaces (agent/*.md, docs/work-flows/*.md, docs/research/*.md, ard/*.html, README.md) and reports COVERED / PARTIAL / MISSING per feature with suggested target docs. Any MISSING entry from that tool is automatically STALE:
   `STALE: docs/work-flows/ — feature "<feature>" reported MISSING by psk-doc-sync.sh (0 doc surfaces)`
A PARTIAL (1-surface) feature for a user-facing workflow is STALE too. PARTIAL is acceptable only for internal/infrastructure items that belong on 1 surface by design.

Executable-workflow ↔ orchestrator script cross-reference (MANDATORY):
- `03-new-project-setup.md` must mention `psk-new-setup.sh`
- `04-existing-project-setup.md` must mention `psk-existing-setup.sh`
- `05-project-init.md` must mention `psk-init.sh` AND `psk-reinit.sh`
- `11-spec-persistent-development.md` must mention `psk-feature-complete.sh`
- `13-release-workflow.md` must mention `psk-release.sh` AND `psk-validate.sh`
- `06-cicd-setup.md` must mention the CI templates directory (`.portable-spec-kit/templates/ci`)
If any mapping is missing → STALE with that flow doc named.

Return in this EXACT format (one entry per file, no prose):
CURRENT: <filename>
QUOTE: <exact line from that file — will be grep-verified against the file>
STALE: <filename>:<line_number> — "<specific stale content>"

Every flow doc must be listed. Each CURRENT verdict REQUIRES a QUOTE on the next line with a distinctive exact line (≥20 chars, verbatim) from that file. The bash verifier will grep the file for the exact QUOTE string — if not found, the verdict is rejected as unread. No omissions.
PROMPT
      ;;
    STEP_8_RELEASES)
      cat <<'PROMPT'
You are a release-notes verification critic. You have NOT seen the main conversation.

Task: Verify agent/RELEASES.md and CHANGELOG.md content for the current version MATCHES reality AND is SUBSTANTIVE (not a copy from the previous version).

Mandatory checks:
1. Open agent/AGENT_CONTEXT.md, read current version.
2. Extract the RELEASES.md and CHANGELOG.md sections for this version.
3. Verify entry has:
   - At least 3 distinct feature/change items (not copy-pasted placeholders)
   - Specific feature names that are implemented in the codebase (check agent/SPECS.md [x] features)
   - Test count matches README badge
   - Does not contain the phrase "TBD", "placeholder", or "see above"
4. Compare CHANGELOG and RELEASES for this version — they should describe the SAME release but in different levels of detail (not verbatim duplicates).
5. Compare against git log since the last version tag — any files changed should have at least one corresponding item in RELEASES or CHANGELOG.
6. Also check ARD files (ard/*.html): does the v0.N Version Changelog section exist with content describing THIS version's features?

Return in this EXACT format (each CURRENT REQUIRES a QUOTE on the next line — verbatim line ≥20 chars from that file; bash will grep-verify):
CURRENT: RELEASES.md
QUOTE: <exact line from RELEASES.md>
CURRENT: CHANGELOG.md
QUOTE: <exact line from CHANGELOG.md>
CURRENT: ard/Portable_Spec_Kit_Technical_Overview.html
QUOTE: <exact line from the ARD>
or (for any issues):
STALE: <filename>:<line> — "<specific mismatch>"
STALE: <filename> — "copy from v0.N-1, not this version"
STALE: <filename> — "<feature X in SPECS but not in this entry>"
PROMPT
      ;;
    STEP_9_VALIDATION)
      cat <<'PROMPT'
You are a comprehensive release verification critic. You have NOT seen the main conversation. This is the FINAL GATE before release ships — any missed drift will reach users.

Task: Read these files and perform cross-file verification:
- agent/AGENT_CONTEXT.md — current version, phase, what's done
- agent/RELEASES.md — current version entry
- CHANGELOG.md — current version entry
- agent/SPECS.md — [x] features
- agent/TASKS.md — [x] completed tasks
- README.md — badges, "What's New" section
- ard/*.html — Key Highlights + Version Changelog

Mandatory verifications:
1. Version consistency: same version appears in all 5 core files (AGENT_CONTEXT, README badge, CHANGELOG, RELEASES, portable-spec-kit.md).
2. Feature count consistency: SPECS.md [x] count matches mentions in RELEASES and CHANGELOG (in release note contexts, not directory tree examples).
3. Phase description currency: AGENT_CONTEXT.md phase line describes NEXT work (from TASKS.md Backlog), not already-done work from this release.
4. ARD content completeness: Technical Overview and Guide both have a section for the current minor version describing features shipped (not just a version badge bump).
5. Flow docs currency: docs/work-flows/ describe the process as implemented (cross-check psk-release.sh step order, psk-critic-spawn.sh templates).
6. Copy-paste detection: check RELEASES entry doesn't contain content that also appears in the PREVIOUS version entry (verbatim duplicate).
7. Release script consistency: confirm psk-release.sh state file shows STEP_9_VALIDATION as the final gate before summary.

8. CROSS-DOC FEATURE COVERAGE (MANDATORY — primary drift catcher):
   Read the current-minor CHANGELOG entry (`## v0.N` + all `### v0.N.x` sub-entries).
   For EVERY feature/capability/script listed, verify coverage across ALL five documentation surfaces:
   (a) agent/*.md — architecture/pipeline description
   (b) docs/work-flows/*.md — at least ONE user-facing workflow mentions it
   (c) docs/research/*.md — methodology paper (if applicable)
   (d) ard/*.html — at least one ARD has it in a current-minor section
   (e) README.md — Latest Release section or narrative
   A feature present in CHANGELOG but ABSENT from ALL surfaces (zero-surface) = STALE with format:
   `STALE: <doc-surface> — feature "<feature>" in CHANGELOG but not reflected in any doc`
   A user-facing workflow present on only 1 surface is also STALE.

   AUTOMATED RUN (mandatory): execute `bash agent/scripts/psk-doc-sync.sh` and treat every MISSING line as a STALE verdict here. That tool performs the same check deterministically across all 5 surfaces — its output IS this check's evidence.
   This catches OMISSIONS across the doc surface — not just contradictions. It's the primary reason flow docs went stale through v0.5.13–v0.5.18 and must fire now.

9. Orchestrator script flow doc cross-check (MANDATORY):
   Each psk-*.sh orchestrator must have a corresponding flow doc that mentions it by filename:
   - `psk-release.sh` → `docs/work-flows/13-release-workflow.md`
   - `psk-new-setup.sh` → `docs/work-flows/03-new-project-setup.md`
   - `psk-existing-setup.sh` → `docs/work-flows/04-existing-project-setup.md`
   - `psk-init.sh` + `psk-reinit.sh` → `docs/work-flows/05-project-init.md`
   - `psk-feature-complete.sh` → `docs/work-flows/11-spec-persistent-development.md`
   Missing mention = STALE.

Return in this EXACT format (each CURRENT REQUIRES a QUOTE on the next line — verbatim line ≥20 chars from that file; bash will grep-verify the quote actually exists in the named file):
CURRENT: <filename>
QUOTE: <exact line from the file>
STALE: <filename>:<line> — "<specific drift, with fix suggestion if possible>"

If you find ZERO issues, return only CURRENT+QUOTE pairs. Anything less than a full audit is unacceptable. Missing or unverifiable QUOTE lines are treated as "critic did not actually read this file" and the verdict is rejected.
PROMPT
      ;;
    FEATURE_COMPLETE)
      cat <<'PROMPT'
You are a feature-completion verification critic. You have NOT seen the main conversation. Your job is to confirm a feature is genuinely done before it is marked [x].

Task: Identify the feature just completed (most recent [x] in agent/SPECS.md without a matching [x] entry in agent/TASKS.md — OR the feature the agent is about to mark done). Then verify cross-file coherence.

Mandatory checks:
1. agent/SPECS.md — feature row has [x], Completed date filled, Tests column populated (not empty, not "TBD").
2. agent/TASKS.md — matching [x] task under current version heading with completion date.
3. tests/ — file referenced in SPECS Tests column exists; grep for test names shows actual test bodies (not empty stubs, no `// TODO`, no `test.skip`, no `assert False`).
4. agent/design/f{N}.md — design plan exists for this feature; Current State = Done.
5. agent/PLANS.md ADL — if design plan has `## Decisions`, each decision has a corresponding ADL row with Plan Ref link.
6. agent/AGENT_CONTEXT.md — What's Done list reflects this feature; What's Next updated (not stale pointing at this feature still).
7. tests/test-release-check.sh output — run `bash tests/test-release-check.sh agent/SPECS.md` if present; all done features must pass R→F→T gate.

Return in this EXACT format (each CURRENT REQUIRES a QUOTE on the next line — verbatim line ≥20 chars from that file; bash will grep-verify):
CURRENT: agent/SPECS.md
QUOTE: <exact line from SPECS.md showing the [x] feature row>
CURRENT: agent/TASKS.md
QUOTE: <exact line showing the [x] task>
CURRENT: tests/<file>
QUOTE: <exact test function name or assertion from the test file>
CURRENT: agent/design/f<N>.md
QUOTE: <exact line from design plan>
CURRENT: agent/PLANS.md
QUOTE: <exact ADL row>
CURRENT: agent/AGENT_CONTEXT.md
QUOTE: <exact line showing current phase/status>

Or, for any issue found:
STALE: <filename> — "<specific problem, e.g., Tests column empty for F12>"
STALE: <filename> — "<ADL missing for Decision 'use Redis over Postgres'>"
PROMPT
      ;;
    INIT)
      cat <<'PROMPT'
You are an init-workflow verification critic. You have NOT seen the main conversation. Your job is to confirm `init` produced a fully coherent agent/ state.

Task: After `init` ran, verify all 9 agent/ files exist and are populated from the codebase (not left as empty templates).

Mandatory checks (apply to agent/ directory):
1. File presence: REQS.md, SPECS.md, PLANS.md, DESIGN.md, RESEARCH.md, TASKS.md, RELEASES.md, AGENT.md, AGENT_CONTEXT.md — all present, non-empty.
2. Template staleness: no file should contain "<Project Name>", "{{project}}", or other unsubstituted placeholders.
3. Stack consistency: agent/AGENT.md Stack table matches codebase detectables (package.json name/deps, requirements.txt, Gemfile, go.mod). Flag if AGENT.md says "React" but package.json has no react.
4. Feature retroactive fill: SPECS.md has a features table with at least F1 populated. If repo has multiple commits and substantial code, SPECS must have multiple features.
5. R→F links: SPECS.md features have Req column entries referencing REQS.md (R1, R2…). REQS.md has at least R1.
6. TASKS.md: has a current version heading matching AGENT_CONTEXT.md Version. Completed tasks (if any from git history) marked [x].
7. AGENT_CONTEXT.md: Version set (not "v0.0.0"), Phase describes current work (not placeholder), What's Done lists real items.
8. No empty "must fill" sections — any line like "TODO: fill this" or empty bullet lists under required headings is STALE.

Return in EXACT format (each CURRENT REQUIRES a QUOTE on the next line — verbatim line ≥20 chars; bash will grep-verify):
CURRENT: agent/REQS.md
QUOTE: <exact line from REQS.md showing a real requirement>
CURRENT: agent/SPECS.md
QUOTE: <exact line showing a feature row>
(one CURRENT+QUOTE pair per file)

Or:
STALE: agent/<file> — "<specific problem>"
STALE: agent/AGENT.md — "Stack says Python but repo has package.json (Node)"
PROMPT
      ;;
    REINIT)
      cat <<'PROMPT'
You are a reinit verification critic. You have NOT seen the main conversation. Your job is to confirm `reinit` synced agent/ to current codebase state WITHOUT losing prior content.

Task: After `reinit` ran, verify the existing agent/ files were enriched (not overwritten) and match current codebase.

Mandatory checks:
1. No content loss: check `git diff HEAD~1 -- agent/` (or equivalent). Any file that LOST completed [x] tasks, decided ADL rows, or release entries is STALE — reinit should only ADD or UPDATE, never DELETE history.
2. Stack freshness: agent/AGENT.md Stack matches package.json/requirements.txt. Flag drift.
3. SPECS vs TASKS sync: count of [x] in SPECS features vs count of [x] tasks in TASKS.md matches (within +/-1 for in-progress work).
4. AGENT_CONTEXT.md Version == the version shown in portable-spec-kit.md `<!-- Framework Version -->` comment.
5. ADL continuity: agent/PLANS.md ADL has no orphan Plan Ref (every Plan Ref points to an existing agent/design/*.md file) and no design/ file lacks an ADL entry.
6. If new pipeline files were added in this framework version (e.g. DESIGN.md, RESEARCH.md), they must exist and be populated.

Return in EXACT format (each CURRENT REQUIRES a QUOTE on the next line — verbatim line ≥20 chars; bash will grep-verify):
CURRENT: agent/<file>
QUOTE: <exact line from that file>
or
STALE: agent/<file> — "<lost content / drift / missing ADL>"
PROMPT
      ;;
    NEW_SETUP)
      cat <<'PROMPT'
You are a new-project-setup verification critic. You have NOT seen the main conversation. Your job is to confirm the brand-new project scaffold is complete, coherent, and ready for development.

Task: After `new project setup` ran, verify directory structure + file scaffold + config match the project type chosen.

Mandatory checks:
1. Core files: README.md, .gitignore, .env.example present at repo root. README has project name populated (not "<Project Name>").
2. agent/ scaffold: all 9 agent/*.md files present with default templates populated (AGENT_CONTEXT Version set, AGENT.md Stack table filled).
3. Source directory matches project type: AGENT.md Stack declares a type (web / python / mobile / etc.); the corresponding source directory template is created (src/, frontend/, backend/, etc.).
4. Tests directory: tests/ exists and has at least one test file or a test-release-check.sh script reference.
5. Config: .portable-spec-kit/config.md exists with default values. .portable-spec-kit/user-profile/ present (copied from global).
6. .gitignore excludes: .env*, node_modules/ (if node), __pycache__/ (if python), cache/, logs/, build outputs.
7. No sensitive data: .env file, if created, contains placeholder values only (never real secrets).
8. README has install + run commands matching the stack (npm install / pip install / go mod tidy / etc.).

Return in EXACT format (each CURRENT REQUIRES a QUOTE on the next line — verbatim line ≥20 chars; bash will grep-verify):
CURRENT: README.md
QUOTE: <exact line from README showing project name or install command>
CURRENT: .gitignore
QUOTE: <exact line from .gitignore>
CURRENT: agent/AGENT.md
QUOTE: <exact line from AGENT.md>
(etc., one CURRENT+QUOTE pair per scaffolded file)

Or:
STALE: <file> — "<missing or malformed>"
PROMPT
      ;;
    EXISTING_SETUP)
      cat <<'PROMPT'
You are an existing-project setup verification critic. You have NOT seen the main conversation. Your job is to confirm kit adoption onto an existing codebase did NOT damage existing files and DID populate agent/ from the codebase.

Task: After `existing project setup` ran, verify (a) no existing project files were modified unexpectedly, and (b) agent/ is populated retroactively from what's already built.

Mandatory checks:
1. Non-destructive: compare git status. Only NEW files (agent/, .portable-spec-kit/, kit symlinks) or EXPLICIT additions (ci.yml if CI enabled) should appear. Existing source files should NOT have been auto-edited.
2. agent/ populated retroactively: SPECS.md has features reflecting what's ALREADY built (not empty, not placeholder). TASKS.md shows [x] for completed work.
3. Stack detection: AGENT.md Stack table matches what's actually in package.json/requirements.txt/go.mod/etc.
4. Language matches: AGENT.md lists actual primary language (Python if .py files dominant, JavaScript/TypeScript if .js/.ts, etc.).
5. README.md: if existed, not overwritten — only augmented (kit marker added at bottom, or unchanged). If didn't exist, created with project name inferred from package.json/pyproject.toml/folder name.
6. .gitignore: augmented with kit patterns (.portable-spec-kit/user-profile/ if ignored, .env*) but existing patterns preserved.

Return in EXACT format (each CURRENT REQUIRES a QUOTE on the next line — verbatim line ≥20 chars; bash will grep-verify):
CURRENT: <file>
QUOTE: <exact line from that file>
STALE: <file> — "<destructive edit | missing retroactive fill | stack mismatch>"
PROMPT
      ;;
    *)
      echo "Unknown step: $step"
      return 1
      ;;
  esac
}

# --- Write critic task ---
write_task() {
  if [ -z "$STEP" ]; then
    echo -e "${RED}Usage: psk-critic-spawn.sh write <STEP_NAME>${NC}"
    exit 2
  fi

  mkdir -p "$STATE_DIR"

  # Track iterations
  local current_iter=0
  if [ -f "$ITERATION_FILE" ]; then
    current_iter=$(grep "^${STEP}=" "$ITERATION_FILE" 2>/dev/null | cut -d= -f2 || echo 0)
  fi
  current_iter=$((current_iter + 1))

  if [ "$current_iter" -gt "$MAX_ITERATIONS" ]; then
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  CRITIC ITERATION CAP REACHED ($MAX_ITERATIONS attempts)${NC}"
    echo -e "${RED}  Step: $STEP${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Human review required. Options:${NC}"
    echo -e "${YELLOW}  (a) Override: bash agent/scripts/psk-critic-spawn.sh clear${NC}"
    echo -e "${YELLOW}  (b) Investigate: read critic-result.md for last findings${NC}"
    exit 1
  fi

  # Save iteration count
  if [ -f "$ITERATION_FILE" ]; then
    grep -v "^${STEP}=" "$ITERATION_FILE" > "$ITERATION_FILE.tmp" 2>/dev/null || true
    mv "$ITERATION_FILE.tmp" "$ITERATION_FILE"
  fi
  echo "${STEP}=${current_iter}" >> "$ITERATION_FILE"

  # Write task file — append shared output-discipline footer (v0.5.16 Opt 7)
  local prompt discipline
  prompt=$(get_critic_prompt "$STEP")
  discipline=$(output_discipline)

  cat > "$TASK_FILE" <<EOF
---
step: $STEP
iteration: $current_iter
max_iterations: $MAX_ITERATIONS
---

$prompt
$discipline
EOF

  # Clear previous result
  rm -f "$RESULT_FILE"

  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  AWAITING CRITIC — $STEP (iteration $current_iter/$MAX_ITERATIONS)${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  ${YELLOW}Agent: spawn sub-agent with the prompt in:${NC}"
  echo -e "  ${CYAN}  $TASK_FILE${NC}"
  echo ""
  echo -e "  ${YELLOW}Write the sub-agent's response to:${NC}"
  echo -e "  ${CYAN}  $RESULT_FILE${NC}"
  echo ""
  echo -e "  ${YELLOW}Then run: bash agent/scripts/psk-release.sh done${NC}"
  echo ""

  return 0
}

# --- Check critic result ---
check_result() {
  if [ -z "$STEP" ]; then
    echo -e "${RED}Usage: psk-critic-spawn.sh check <STEP_NAME>${NC}"
    exit 2
  fi

  if [ ! -f "$RESULT_FILE" ]; then
    echo -e "${RED}  No critic result file found at: $RESULT_FILE${NC}"
    echo -e "${RED}  Agent must spawn sub-agent and write result before proceeding.${NC}"
    return 1
  fi

  # Parse result
  local stale_count=0
  local current_count=0
  local stale_lines=""

  while IFS= read -r line; do
    case "$line" in
      CURRENT:*) current_count=$((current_count + 1)) ;;
      STALE:*)
        stale_count=$((stale_count + 1))
        stale_lines="${stale_lines}\n  ${RED}$line${NC}"
        ;;
    esac
  done < "$RESULT_FILE"

  if [ "$stale_count" -eq 0 ]; then
    echo -e "  ${GREEN}✓ Critic verified: $current_count files, all CURRENT${NC}"
    return 0
  else
    echo -e "  ${RED}✗ Critic found $stale_count stale item(s):${NC}"
    echo -e "$stale_lines"
    echo ""
    echo -e "  ${YELLOW}Fix the flagged items, then run: psk-release.sh done${NC}"
    echo -e "  ${YELLOW}(Critic will re-run automatically — iteration tracked)${NC}"
    return 1
  fi
}

# --- Status ---
show_status() {
  echo -e "${CYAN}Critic Protocol Status:${NC}"
  if [ -f "$TASK_FILE" ]; then
    local step_name
    step_name=$(grep "^step:" "$TASK_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' ')
    local iter
    iter=$(grep "^iteration:" "$TASK_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' ')
    echo -e "  Task pending: ${YELLOW}$step_name${NC} (iteration $iter)"
  else
    echo -e "  ${GREEN}No pending critic task${NC}"
  fi

  if [ -f "$RESULT_FILE" ]; then
    local stale
    stale=$(grep -c "^STALE:" "$RESULT_FILE" 2>/dev/null || echo 0)
    local current
    current=$(grep -c "^CURRENT:" "$RESULT_FILE" 2>/dev/null || echo 0)
    echo -e "  Last result: ${GREEN}$current CURRENT${NC}, ${RED}$stale STALE${NC}"
  else
    echo -e "  No result file"
  fi
}

# --- Clear ---
clear_state() {
  rm -f "$TASK_FILE" "$RESULT_FILE" "$ITERATION_FILE"
  echo -e "${GREEN}Critic state cleared.${NC}"
}

# === MAIN ===
case "$ACTION" in
  write)   write_task ;;
  check)   check_result ;;
  status)  show_status ;;
  clear)   clear_state ;;
  *)
    echo "Usage: bash agent/scripts/psk-critic-spawn.sh [write|check|status|clear] [STEP_NAME]"
    exit 2
    ;;
esac
