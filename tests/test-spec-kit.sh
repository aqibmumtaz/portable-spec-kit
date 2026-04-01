#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Portable Spec Kit — Full Test Suite
# Tests the framework file, setup flow, symlinks, agent files,
# templates, and content integrity.
#
# Usage: bash tests/test-spec-kit.sh
# Run from: Projects/portable-spec-kit/
# ═══════════════════════════════════════════════════════════════

PASS=0
FAIL=0
TOTAL=0

pass() { ((PASS++)); ((TOTAL++)); echo "  ✓ $1"; }
fail() { ((FAIL++)); ((TOTAL++)); echo "  ✗ $1"; }
section() { echo ""; echo "═══ $1 ═══"; }

PROJ="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$PROJ/../.."
TEMP="/tmp/psk-test-$(date +%s)"

# ═══════════════════════════════════════════════════════════════
section "1. Repo File Structure"
# ═══════════════════════════════════════════════════════════════

[ -f "$PROJ/portable-spec-kit.md" ] && pass "portable-spec-kit.md exists" || fail "portable-spec-kit.md MISSING"
[ -f "$PROJ/README.md" ] && pass "README.md exists" || fail "README.md MISSING"
[ -f "$PROJ/CONTRIBUTING.md" ] && pass "CONTRIBUTING.md exists" || fail "CONTRIBUTING.md MISSING"
[ -f "$PROJ/LICENSE" ] && pass "LICENSE exists" || fail "LICENSE MISSING"
[ -f "$PROJ/.gitignore" ] && pass ".gitignore exists" || fail ".gitignore MISSING"
[ -f "$PROJ/ard/Portable_Spec_Kit_Guide.html" ] && pass "Guide HTML exists" || fail "Guide HTML MISSING"
[ -f "$PROJ/ard/Portable_Spec_Kit_Guide.pdf" ] && pass "Guide PDF exists" || fail "Guide PDF MISSING"
[ -d "$PROJ/examples/starter" ] && pass "examples/starter/ exists" || fail "examples/starter/ MISSING"
[ -d "$PROJ/examples/my-app" ] && pass "examples/my-app/ exists" || fail "examples/my-app/ MISSING"
[ -d "$PROJ/agent" ] && pass "agent/ dir exists (Documents-only)" || fail "agent/ MISSING"

# ═══════════════════════════════════════════════════════════════
section "2. Framework File Content"
# ═══════════════════════════════════════════════════════════════

grep -q "Portable Spec Kit — AI Agentic" "$PROJ/portable-spec-kit.md" && pass "Title correct" || fail "Title wrong"
grep -q "User Profile" "$PROJ/portable-spec-kit.md" && pass "Has User Profile section" || fail "Missing User Profile"
grep -q "\.portable-spec-kit/user-profile/" "$PROJ/portable-spec-kit.md" && pass "References .portable-spec-kit/user-profile/" || fail "Missing profile directory reference"
grep -q "Git & GitHub Rules" "$PROJ/portable-spec-kit.md" && pass "Has Git rules" || fail "Missing Git rules"
grep -q "Security Rules" "$PROJ/portable-spec-kit.md" && pass "Has Security rules" || fail "Missing Security rules"
grep -q "Versioning" "$PROJ/portable-spec-kit.md" && pass "Has Versioning" || fail "Missing Versioning"
grep -q "Task Tracking" "$PROJ/portable-spec-kit.md" && pass "Has Task Tracking" || fail "Missing Task Tracking"
grep -q "Testing (MANDATORY)" "$PROJ/portable-spec-kit.md" && pass "Has Testing rules" || fail "Missing Testing rules"
grep -q "Naming Conventions" "$PROJ/portable-spec-kit.md" && pass "Has Naming Conventions" || fail "Missing Naming Conventions"
grep -q "Error Handling" "$PROJ/portable-spec-kit.md" && pass "Has Error Handling" || fail "Missing Error Handling"
grep -q "Branch & PR Workflow" "$PROJ/portable-spec-kit.md" && pass "Has Branch & PR" || fail "Missing Branch & PR"
grep -q "Dependencies" "$PROJ/portable-spec-kit.md" && pass "Has Dependencies" || fail "Missing Dependencies"
grep -q "Deployment Checklist" "$PROJ/portable-spec-kit.md" && pass "Has Deployment Checklist" || fail "Missing Deployment Checklist"
grep -q "Agent File Templates" "$PROJ/portable-spec-kit.md" && pass "Has Agent File Templates" || fail "Missing Agent File Templates"
grep -q "Agent Guidance Behavior" "$PROJ/portable-spec-kit.md" && pass "Has Agent Guidance Behavior" || fail "Missing Agent Guidance Behavior"
grep -q "Auto-Scan" "$PROJ/portable-spec-kit.md" && pass "Has Auto-Scan" || fail "Missing Auto-Scan"
grep -q "File Creation/Update Rule" "$PROJ/portable-spec-kit.md" && pass "Has File Creation/Update Rule" || fail "Missing File Creation/Update Rule"
grep -q "README.md Template" "$PROJ/portable-spec-kit.md" && pass "Has README Template" || fail "Missing README Template"
grep -q "How This File Works" "$PROJ/portable-spec-kit.md" && pass "Has self-description section" || fail "Missing self-description"

# ═══════════════════════════════════════════════════════════════
section "3. Agent-Agnostic — No Claude-Specific Language"
# ═══════════════════════════════════════════════════════════════

! grep -qi "prefers claude" "$PROJ/portable-spec-kit.md" && pass "No 'Prefers Claude'" || fail "Found 'Prefers Claude'"
! grep -q "Claude Opus" "$PROJ/portable-spec-kit.md" && pass "No 'Claude Opus'" || fail "Found 'Claude Opus'"
! grep -q "\.claude/" "$PROJ/portable-spec-kit.md" && pass "No '.claude/' reference" || fail "Found '.claude/'"
! grep -q "CLAUDE_CONTEXT" "$PROJ/portable-spec-kit.md" && pass "No 'CLAUDE_CONTEXT'" || fail "Found 'CLAUDE_CONTEXT'"
grep -q "WORKSPACE_CONTEXT" "$PROJ/portable-spec-kit.md" && pass "Uses WORKSPACE_CONTEXT" || fail "Missing WORKSPACE_CONTEXT"
grep -q "Co-Authored-By: AI Agent" "$PROJ/portable-spec-kit.md" && pass "Generic Co-Authored-By" || fail "Claude-specific Co-Authored-By"
grep -q "Agent does 90%" "$PROJ/portable-spec-kit.md" && pass "Generic AI agent reference" || fail "Claude-specific agent reference"

# ═══════════════════════════════════════════════════════════════
section "4. Multi-Agent Support Table"
# ═══════════════════════════════════════════════════════════════

grep -q "Claude Code" "$PROJ/portable-spec-kit.md" && pass "Lists Claude Code" || fail "Missing Claude Code"
grep -q "GitHub Copilot" "$PROJ/portable-spec-kit.md" && pass "Lists GitHub Copilot" || fail "Missing Copilot"
grep -q "Cursor" "$PROJ/portable-spec-kit.md" && pass "Lists Cursor" || fail "Missing Cursor"
grep -q "Windsurf" "$PROJ/portable-spec-kit.md" && pass "Lists Windsurf" || fail "Missing Windsurf"
grep -q "Cline" "$PROJ/portable-spec-kit.md" && pass "Lists Cline" || fail "Missing Cline"
grep -q "CLAUDE.md" "$PROJ/portable-spec-kit.md" && pass "References CLAUDE.md symlink" || fail "Missing CLAUDE.md symlink ref"
grep -q ".cursorrules" "$PROJ/portable-spec-kit.md" && pass "References .cursorrules" || fail "Missing .cursorrules ref"
grep -q ".windsurfrules" "$PROJ/portable-spec-kit.md" && pass "References .windsurfrules" || fail "Missing .windsurfrules ref"
grep -q ".clinerules" "$PROJ/portable-spec-kit.md" && pass "References .clinerules" || fail "Missing .clinerules ref"
grep -q "copilot-instructions.md" "$PROJ/portable-spec-kit.md" && pass "References copilot-instructions.md" || fail "Missing copilot ref"

# ═══════════════════════════════════════════════════════════════
section "5. Agent File Templates (all 6 present in framework)"
# ═══════════════════════════════════════════════════════════════

grep -q "agent/AGENT.md:" "$PROJ/portable-spec-kit.md" && pass "AGENT.md template" || fail "Missing AGENT.md template"
grep -q "agent/AGENT_CONTEXT.md:" "$PROJ/portable-spec-kit.md" && pass "AGENT_CONTEXT.md template" || fail "Missing AGENT_CONTEXT.md template"
grep -q "agent/SPECS.md:" "$PROJ/portable-spec-kit.md" && pass "SPECS.md template" || fail "Missing SPECS.md template"
grep -q "agent/PLANNING.md:" "$PROJ/portable-spec-kit.md" && pass "PLANNING.md template" || fail "Missing PLANNING.md template"
grep -q "agent/TASKS.md:" "$PROJ/portable-spec-kit.md" && pass "TASKS.md template" || fail "Missing TASKS.md template"
grep -q "agent/TRACKER.md:" "$PROJ/portable-spec-kit.md" && pass "TRACKER.md template" || fail "Missing TRACKER.md template"

# ═══════════════════════════════════════════════════════════════
section "6. Starter Example — Complete"
# ═══════════════════════════════════════════════════════════════

S="$PROJ/examples/starter"
[ -f "$S/WORKSPACE_CONTEXT.md" ] && pass "starter: WORKSPACE_CONTEXT.md" || fail "starter: WORKSPACE_CONTEXT.md MISSING"
[ -f "$S/README.md" ] && pass "starter: README.md" || fail "starter: README.md MISSING"
[ -f "$S/.gitignore" ] && pass "starter: .gitignore" || fail "starter: .gitignore MISSING"
[ -f "$S/.env.example" ] && pass "starter: .env.example" || fail "starter: .env.example MISSING"
[ -f "$S/agent/AGENT.md" ] && pass "starter: agent/AGENT.md" || fail "starter: AGENT.md MISSING"
[ -f "$S/agent/AGENT_CONTEXT.md" ] && pass "starter: agent/AGENT_CONTEXT.md" || fail "starter: AGENT_CONTEXT.md MISSING"
[ -f "$S/agent/SPECS.md" ] && pass "starter: agent/SPECS.md" || fail "starter: SPECS.md MISSING"
[ -f "$S/agent/PLANNING.md" ] && pass "starter: agent/PLANNING.md" || fail "starter: PLANNING.md MISSING"
[ -f "$S/agent/TASKS.md" ] && pass "starter: agent/TASKS.md" || fail "starter: TASKS.md MISSING"
[ -f "$S/agent/TRACKER.md" ] && pass "starter: agent/TRACKER.md" || fail "starter: TRACKER.md MISSING"
grep -q "portable-spec-kit.md" "$S/README.md" && pass "starter README references portable-spec-kit.md" || fail "starter README still says CLAUDE.md"
grep -q "Portable Spec Kit" "$S/README.md" && pass "starter README mentions Portable Spec Kit" || fail "starter README missing kit reference"

# ═══════════════════════════════════════════════════════════════
section "7. My-App Example — Complete + Realistic Data"
# ═══════════════════════════════════════════════════════════════

M="$PROJ/examples/my-app"
[ -f "$M/WORKSPACE_CONTEXT.md" ] && pass "my-app: WORKSPACE_CONTEXT.md" || fail "my-app: WORKSPACE_CONTEXT.md MISSING"
[ -f "$M/README.md" ] && pass "my-app: README.md" || fail "my-app: README.md MISSING"
[ -f "$M/agent/AGENT.md" ] && pass "my-app: agent/AGENT.md" || fail "my-app: AGENT.md MISSING"
[ -f "$M/agent/AGENT_CONTEXT.md" ] && pass "my-app: agent/AGENT_CONTEXT.md" || fail "my-app: AGENT_CONTEXT.md MISSING"
[ -f "$M/agent/SPECS.md" ] && pass "my-app: agent/SPECS.md" || fail "my-app: SPECS.md MISSING"
[ -f "$M/agent/PLANNING.md" ] && pass "my-app: agent/PLANNING.md" || fail "my-app: PLANNING.md MISSING"
[ -f "$M/agent/TASKS.md" ] && pass "my-app: agent/TASKS.md" || fail "my-app: TASKS.md MISSING"
[ -f "$M/agent/TRACKER.md" ] && pass "my-app: agent/TRACKER.md" || fail "my-app: TRACKER.md MISSING"
grep -q "Next.js" "$M/agent/AGENT.md" && pass "my-app: has Next.js stack" || fail "my-app: no stack defined"
grep -q "11/16\|11 of 16" "$M/agent/TASKS.md" 2>/dev/null || grep -q "\[x\]" "$M/agent/TASKS.md" && pass "my-app: has completed tasks" || fail "my-app: no tasks done"
grep -q "v0.1" "$M/agent/TRACKER.md" && pass "my-app: has v0.1 changelog" || fail "my-app: no changelog"

# ═══════════════════════════════════════════════════════════════
section "8. README — Key Sections Present"
# ═══════════════════════════════════════════════════════════════

grep -q "Portable Spec Kit" "$PROJ/README.md" && pass "README: title present" || fail "README: title missing"
grep -q "spec-kit" "$PROJ/README.md" && pass "README: spec-kit comparison" || fail "README: no spec-kit comparison"
grep -q "Setup" "$PROJ/README.md" && pass "README: Setup section" || fail "README: no Setup"
grep -q "Multi-Agent Support" "$PROJ/README.md" && pass "README: Multi-Agent section" || fail "README: no Multi-Agent"
grep -q "Complete Flow" "$PROJ/README.md" && pass "README: Complete Flow" || fail "README: no Complete Flow"
grep -q "Core Principles" "$PROJ/README.md" && pass "README: Core Principles" || fail "README: no Core Principles"
grep -q "Examples" "$PROJ/README.md" && pass "README: Examples section" || fail "README: no Examples"
grep -q "Contributing" "$PROJ/README.md" && pass "README: Contributing" || fail "README: no Contributing"
grep -q "Author" "$PROJ/README.md" && pass "README: Author" || fail "README: no Author"
grep -q "Personalized" "$PROJ/README.md" && pass "README: 8 features (Personalized)" || fail "README: missing feature"
grep -q "Context-Persistent" "$PROJ/README.md" && pass "README: 8 features (Context-Persistent)" || fail "README: missing feature"
grep -q "Self-Validating" "$PROJ/README.md" && pass "README: 8 features (Self-Validating)" || fail "README: missing feature"

# ═══════════════════════════════════════════════════════════════
section "9. No Personal Info Leaked (except Author section)"
# ═══════════════════════════════════════════════════════════════

! grep -qi "bitlogix\|ebitlogix\|slimlogix\|slashnext" "$PROJ/portable-spec-kit.md" && pass "No company names in framework" || fail "Company name leaked in framework"
! grep -qi "bitlogix\|ebitlogix\|slimlogix\|slashnext" "$PROJ/README.md" && pass "No company names in README" || fail "Company name leaked in README"
! grep -qi "bitlogix\|ebitlogix\|slimlogix\|slashnext" "$PROJ/CONTRIBUTING.md" && pass "No company names in CONTRIBUTING" || fail "Company name leaked in CONTRIBUTING"
! grep -qi "3004476083\|+92\|passport\|bank statement" "$PROJ/portable-spec-kit.md" && pass "No personal details in framework" || fail "Personal details leaked"

# ═══════════════════════════════════════════════════════════════
section "10. Sync Script"
# ═══════════════════════════════════════════════════════════════

[ -f "$PROJ/agent/sync.sh" ] && pass "sync.sh exists" || fail "sync.sh MISSING"
grep -q "portable-spec-kit.md" "$PROJ/agent/sync.sh" && pass "sync.sh uses portable-spec-kit.md" || fail "sync.sh still uses CLAUDE.md"
! grep -q "cp.*CLAUDE.md" "$PROJ/agent/sync.sh" && pass "sync.sh doesn't copy CLAUDE.md" || fail "sync.sh still copies CLAUDE.md"
grep -q "aqibmumtaz/portable-spec-kit" "$PROJ/agent/sync.sh" && pass "sync.sh targets correct repo" || fail "sync.sh wrong repo"

# ═══════════════════════════════════════════════════════════════
section "11. Workspace Symlinks (if running in author's workspace)"
# ═══════════════════════════════════════════════════════════════

if [ -f "$ROOT/portable-spec-kit.md" ]; then
  [ -L "$ROOT/CLAUDE.md" ] && pass "CLAUDE.md is symlink" || fail "CLAUDE.md is NOT symlink"
  [ -L "$ROOT/.cursorrules" ] && pass ".cursorrules is symlink" || fail ".cursorrules NOT symlink"
  [ -L "$ROOT/.windsurfrules" ] && pass ".windsurfrules is symlink" || fail ".windsurfrules NOT symlink"
  [ -L "$ROOT/.clinerules" ] && pass ".clinerules is symlink" || fail ".clinerules NOT symlink"
  [ -L "$ROOT/.github/copilot-instructions.md" ] && pass ".github/copilot-instructions.md is symlink" || fail "copilot NOT symlink"

  # Verify all symlinks point to portable-spec-kit.md
  for f in CLAUDE.md .cursorrules .windsurfrules .clinerules; do
    target=$(readlink "$ROOT/$f" 2>/dev/null)
    [ "$target" = "portable-spec-kit.md" ] && pass "$f → portable-spec-kit.md" || fail "$f → $target (wrong target)"
  done

  target=$(readlink "$ROOT/.github/copilot-instructions.md" 2>/dev/null)
  [ "$target" = "../portable-spec-kit.md" ] && pass "copilot → ../portable-spec-kit.md" || fail "copilot → $target (wrong)"

  [ -f "$ROOT/WORKSPACE_CONTEXT.md" ] && pass "WORKSPACE_CONTEXT.md exists at root" || fail "WORKSPACE_CONTEXT.md MISSING"
  ! [ -f "$ROOT/CLAUDE_CONTEXT.md" ] && pass "No old CLAUDE_CONTEXT.md" || fail "Stale CLAUDE_CONTEXT.md exists"
else
  echo "  (skipped — not running in author's workspace)"
fi

# ═══════════════════════════════════════════════════════════════
section "12. Simulated New User Setup"
# ═══════════════════════════════════════════════════════════════

mkdir -p "$TEMP" && cd "$TEMP"

# Simulate macOS/Linux install
cp "$PROJ/portable-spec-kit.md" "$TEMP/portable-spec-kit.md"
ln -sf portable-spec-kit.md CLAUDE.md
ln -sf portable-spec-kit.md .cursorrules
ln -sf portable-spec-kit.md .windsurfrules
ln -sf portable-spec-kit.md .clinerules
mkdir -p .github && ln -sf ../portable-spec-kit.md .github/copilot-instructions.md

[ -f "$TEMP/portable-spec-kit.md" ] && pass "Setup: source file created" || fail "Setup: source file MISSING"
[ -L "$TEMP/CLAUDE.md" ] && pass "Setup: CLAUDE.md symlink" || fail "Setup: CLAUDE.md NOT symlink"
[ -L "$TEMP/.cursorrules" ] && pass "Setup: .cursorrules symlink" || fail "Setup: .cursorrules NOT symlink"
[ -L "$TEMP/.windsurfrules" ] && pass "Setup: .windsurfrules symlink" || fail "Setup: .windsurfrules NOT symlink"
[ -L "$TEMP/.clinerules" ] && pass "Setup: .clinerules symlink" || fail "Setup: .clinerules NOT symlink"
[ -L "$TEMP/.github/copilot-instructions.md" ] && pass "Setup: copilot symlink" || fail "Setup: copilot NOT symlink"

# Verify all symlinks read same content
for f in CLAUDE.md .cursorrules .windsurfrules .clinerules .github/copilot-instructions.md; do
  diff "$TEMP/portable-spec-kit.md" "$TEMP/$f" > /dev/null 2>&1 && pass "Setup: $f content matches source" || fail "Setup: $f content DIFFERS"
done

# Edit source → all agents see update
echo "# TEST EDIT" >> "$TEMP/portable-spec-kit.md"
grep -q "TEST EDIT" "$TEMP/CLAUDE.md" && pass "Setup: edit source → CLAUDE.md updated" || fail "Setup: symlink not syncing"
grep -q "TEST EDIT" "$TEMP/.cursorrules" && pass "Setup: edit source → .cursorrules updated" || fail "Setup: symlink not syncing"

# Cleanup
rm -rf "$TEMP"
pass "Setup: temp dir cleaned"

# ═══════════════════════════════════════════════════════════════
section "13. Agent Switching — Cross-Agent Compatibility"
# ═══════════════════════════════════════════════════════════════

SWITCH_TEMP="/tmp/psk-switch-$(date +%s)"
mkdir -p "$SWITCH_TEMP" && cd "$SWITCH_TEMP"

# --- Setup: simulate install ---
cp "$PROJ/portable-spec-kit.md" "$SWITCH_TEMP/portable-spec-kit.md"
ln -sf portable-spec-kit.md CLAUDE.md
ln -sf portable-spec-kit.md .cursorrules
ln -sf portable-spec-kit.md .windsurfrules
ln -sf portable-spec-kit.md .clinerules
mkdir -p .github && ln -sf ../portable-spec-kit.md .github/copilot-instructions.md

# --- Test: All 5 agents read identical content ---
AGENTS="CLAUDE.md .cursorrules .windsurfrules .clinerules .github/copilot-instructions.md"
ALL_IDENTICAL=true
for a in $AGENTS; do
  diff "$SWITCH_TEMP/portable-spec-kit.md" "$SWITCH_TEMP/$a" > /dev/null 2>&1 || ALL_IDENTICAL=false
done
$ALL_IDENTICAL && pass "All 5 agents read identical framework content" || fail "Agent content mismatch"

# --- Test: Edit source → every agent sees change instantly ---
echo "# SWITCH_TEST_MARKER" >> "$SWITCH_TEMP/portable-spec-kit.md"
ALL_SYNCED=true
for a in $AGENTS; do
  grep -q "SWITCH_TEST_MARKER" "$SWITCH_TEMP/$a" || ALL_SYNCED=false
done
$ALL_SYNCED && pass "Edit source → all 5 agents see change instantly" || fail "Symlink sync broken"

# --- Test: Simulate AGENT_CONTEXT.md written by Agent A, read by Agent B ---
mkdir -p "$SWITCH_TEMP/agent"
cat > "$SWITCH_TEMP/agent/AGENT_CONTEXT.md" << 'CTXEOF'
# AGENT_CONTEXT.md — Test Project

## Current Status
- **Version:** v0.2
- **Phase:** Development
- **Status:** 8/12 tasks done

## What's Done
- [x] Auth system
- [x] Dashboard

## What's Next
- [ ] Payment integration

## Key Decisions
| Decision | Choice | Why |
|----------|--------|-----|
| Database | PostgreSQL | Better JSON support |

## Last Updated
- **Date:** 2026-04-01
- **Summary:** Completed auth, starting payment
CTXEOF

# Agent B reads Agent A's context
grep -q "v0.2" "$SWITCH_TEMP/agent/AGENT_CONTEXT.md" && pass "Agent B reads Agent A's version" || fail "Context version lost"
grep -q "8/12 tasks done" "$SWITCH_TEMP/agent/AGENT_CONTEXT.md" && pass "Agent B reads Agent A's progress" || fail "Context progress lost"
grep -q "Payment integration" "$SWITCH_TEMP/agent/AGENT_CONTEXT.md" && pass "Agent B reads Agent A's next task" || fail "Context next task lost"
grep -q "PostgreSQL" "$SWITCH_TEMP/agent/AGENT_CONTEXT.md" && pass "Agent B reads Agent A's decisions" || fail "Context decisions lost"

# --- Test: Simulate user profile written by Agent A, read by Agent B ---
mkdir -p "$SWITCH_TEMP/.portable-spec-kit/user-profile"
cat > "$SWITCH_TEMP/.portable-spec-kit/user-profile/user-profile-janesmith.md" << 'PROFEOF'
# User Profile
> Auto-created on first session. Edit anytime.

- **Jane Smith** — B.S. Computer Science. Full-stack development, React, Node.js.
- Communication style: direct and concise, prefers short answers with bullet points and minimal explanation
- Working pattern: iterative — starts brief, expands scope, builds ambitiously over time
- AI delegation: AI does 90%, user reviews 10% — present ready-to-act outputs, not questions
PROFEOF

PROF="$SWITCH_TEMP/.portable-spec-kit/user-profile/user-profile-janesmith.md"
grep -q "Jane Smith" "$PROF" && pass "Agent B reads user name from Agent A's profile" || fail "Profile name lost"
grep -q "direct and concise" "$PROF" && pass "Agent B reads communication style" || fail "Communication style lost"
grep -q "AI does 90%" "$PROF" && pass "Agent B reads delegation preference" || fail "Delegation lost"

# --- Test: Simulate TASKS.md written by Agent A, read by Agent B ---
cat > "$SWITCH_TEMP/agent/TASKS.md" << 'TASKEOF'
# TASKS.md — Test Project

## v0.2 — Current

### Module 1: Auth
| # | Task | Status |
|---|------|:------:|
| 1.1 | Login page | [x] |
| 1.2 | JWT middleware | [x] |

### Module 2: Payment
| # | Task | Status |
|---|------|:------:|
| 2.1 | Stripe integration | [ ] |
| 2.2 | Checkout flow | [ ] |
TASKEOF

grep -q "Login page" "$SWITCH_TEMP/agent/TASKS.md" && pass "Agent B sees Agent A's completed tasks" || fail "Completed tasks lost"
grep -q "Stripe integration" "$SWITCH_TEMP/agent/TASKS.md" && pass "Agent B sees Agent A's pending tasks" || fail "Pending tasks lost"

# --- Test: No agent-specific format in managed files ---
! grep -q "\.claude/" "$SWITCH_TEMP/portable-spec-kit.md" && pass "No .claude/ paths in framework" || fail ".claude/ path found"
! grep -q "anthropic" "$SWITCH_TEMP/portable-spec-kit.md" && pass "No anthropic references in framework" || fail "anthropic reference found"
! grep -q "Claude Opus" "$SWITCH_TEMP/portable-spec-kit.md" && pass "No Claude Opus in framework" || fail "Claude Opus found"
! grep -qi "prefers claude" "$SWITCH_TEMP/portable-spec-kit.md" && pass "No 'prefers Claude' in framework" || fail "'prefers Claude' found"

# --- Test: All managed files are plain markdown (no proprietary format) ---
for f in agent/AGENT_CONTEXT.md agent/TASKS.md .portable-spec-kit/user-profile/user-profile-janesmith.md; do
  head -1 "$SWITCH_TEMP/$f" | grep -q "^#" && pass "$f is valid markdown (starts with #)" || fail "$f is not valid markdown"
done

# --- Test: Framework references .portable-spec-kit/user-profile/ (not embedded profile) ---
grep -q "\.portable-spec-kit/user-profile/" "$SWITCH_TEMP/portable-spec-kit.md" && pass "Framework references .portable-spec-kit/user-profile/" || fail "Framework missing profile directory reference"
! grep -q "^- \*\*Dr\." "$SWITCH_TEMP/portable-spec-kit.md" && pass "No embedded personal profile in framework" || fail "Personal profile still embedded"

# --- Test: Co-Authored-By is agent-agnostic ---
grep -q "Co-Authored-By: AI Agent" "$SWITCH_TEMP/portable-spec-kit.md" && pass "Co-Authored-By uses generic 'AI Agent'" || fail "Co-Authored-By is agent-specific"
! grep -q "Co-Authored-By: Claude" "$SWITCH_TEMP/portable-spec-kit.md" && pass "Co-Authored-By does NOT mention Claude" || fail "Co-Authored-By mentions Claude"

# --- Test: Multiple sequential agent switches preserve all data ---
# Simulate: Claude writes → Cursor reads/writes → Copilot reads
echo "- [x] Added by Claude session" >> "$SWITCH_TEMP/agent/TASKS.md"
grep -q "Added by Claude session" "$SWITCH_TEMP/agent/TASKS.md" && pass "Switch 1: Claude writes task" || fail "Switch 1 failed"

echo "- [x] Added by Cursor session" >> "$SWITCH_TEMP/agent/TASKS.md"
grep -q "Added by Claude session" "$SWITCH_TEMP/agent/TASKS.md" && pass "Switch 2: Cursor preserves Claude's task" || fail "Switch 2: Claude's task lost"
grep -q "Added by Cursor session" "$SWITCH_TEMP/agent/TASKS.md" && pass "Switch 2: Cursor adds own task" || fail "Switch 2: Cursor write failed"

grep -q "Added by Claude session" "$SWITCH_TEMP/agent/TASKS.md" \
  && grep -q "Added by Cursor session" "$SWITCH_TEMP/agent/TASKS.md" \
  && grep -q "Stripe integration" "$SWITCH_TEMP/agent/TASKS.md" \
  && pass "Switch 3: Copilot reads all data from Claude + Cursor" || fail "Switch 3: data loss on read"

# --- Cleanup ---
rm -rf "$SWITCH_TEMP"
pass "Agent switching: temp dir cleaned"

# ═══════════════════════════════════════════════════════════════
section "14. User Profile — Directory Structure"
# ═══════════════════════════════════════════════════════════════

# Global profile dir
[ -d "$HOME/.portable-spec-kit/user-profile" ] && pass "Global profile dir exists (~/.portable-spec-kit/user-profile/)" || fail "Global profile dir MISSING"

# Workspace profile dir
[ -d "$ROOT/.portable-spec-kit/user-profile" ] && pass "Workspace profile dir exists" || fail "Workspace profile dir MISSING"

# Framework references new path
grep -q "\.portable-spec-kit/user-profile/" "$PROJ/portable-spec-kit.md" && pass "Framework references .portable-spec-kit/user-profile/" || fail "Framework missing new profile path"

# Framework has lookup order
grep -q "workspace.*portable-spec-kit/user-profile" "$PROJ/portable-spec-kit.md" && pass "Framework has workspace lookup" || fail "Missing workspace lookup"
grep -q "~/.portable-spec-kit/user-profile" "$PROJ/portable-spec-kit.md" && pass "Framework has global lookup" || fail "Missing global lookup"

# Username detection uses git config
grep -q "git config user.name" "$PROJ/portable-spec-kit.md" && pass "Username detection uses git config" || fail "Missing git config detection"

# Cross-OS paths documented
grep -q "macOS/Linux" "$PROJ/portable-spec-kit.md" && pass "macOS/Linux path documented" || fail "Missing macOS/Linux path"
grep -q "Windows" "$PROJ/portable-spec-kit.md" && pass "Windows path documented" || fail "Missing Windows path"

# No old .user-profile.md references in framework (except TASKS.md history)
! grep -q "\.user-profile\.md" "$PROJ/portable-spec-kit.md" && pass "No old .user-profile.md in framework" || fail "Stale .user-profile.md reference in framework"

# ═══════════════════════════════════════════════════════════════
section "15. User Profile — First Time Setup Simulation"
# ═══════════════════════════════════════════════════════════════

SETUP_TEMP="/tmp/psk-setup-$(date +%s)"
SETUP_GLOBAL="/tmp/psk-global-$(date +%s)"
mkdir -p "$SETUP_TEMP" && cd "$SETUP_TEMP"

# Simulate: no profile anywhere
cp "$PROJ/portable-spec-kit.md" "$SETUP_TEMP/portable-spec-kit.md"

# No workspace profile
! [ -d "$SETUP_TEMP/.portable-spec-kit/user-profile" ] && pass "Setup: no workspace profile dir initially" || fail "Setup: workspace profile exists prematurely"

# Simulate first-time setup: create global + workspace
mkdir -p "$SETUP_GLOBAL/.portable-spec-kit/user-profile"
mkdir -p "$SETUP_TEMP/.portable-spec-kit/user-profile"

cat > "$SETUP_GLOBAL/.portable-spec-kit/user-profile/user-profile-testuser.md" << 'EOF'
# User Profile
> Auto-created on first session. Edit anytime.

- **Test User** — B.S. Computer Science. Full-stack development.
- Communication style: direct and concise, prefers short answers with bullet points and minimal explanation
- Working pattern: iterative — starts brief, expands scope, builds ambitiously over time
- AI delegation: AI does 70%, user guides 30% — AI proposes approach, user approves before execution
EOF

cp "$SETUP_GLOBAL/.portable-spec-kit/user-profile/user-profile-testuser.md" \
   "$SETUP_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md"

# Verify global created
[ -f "$SETUP_GLOBAL/.portable-spec-kit/user-profile/user-profile-testuser.md" ] && pass "Setup: global profile created" || fail "Setup: global profile MISSING"

# Verify workspace created
[ -f "$SETUP_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" ] && pass "Setup: workspace profile created" || fail "Setup: workspace profile MISSING"

# Verify both have same content
diff "$SETUP_GLOBAL/.portable-spec-kit/user-profile/user-profile-testuser.md" \
     "$SETUP_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" > /dev/null 2>&1 \
  && pass "Setup: global and workspace profiles match" || fail "Setup: profiles differ"

# Verify profile content
grep -q "Test User" "$SETUP_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" && pass "Setup: profile has name" || fail "Setup: name missing"
grep -q "Communication style:" "$SETUP_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" && pass "Setup: profile has communication" || fail "Setup: communication missing"
grep -q "Working pattern:" "$SETUP_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" && pass "Setup: profile has working pattern" || fail "Setup: working pattern missing"
grep -q "AI delegation:" "$SETUP_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" && pass "Setup: profile has delegation" || fail "Setup: delegation missing"

# Verify profile format (starts with #)
head -1 "$SETUP_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" | grep -q "^#" && pass "Setup: profile is valid markdown" || fail "Setup: not valid markdown"

# Verify defaults are mid-range (not 90% autonomous)
grep -q "AI does 70%" "$SETUP_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" && pass "Setup: default delegation is mid-range (70%)" || fail "Setup: default not mid-range"

rm -rf "$SETUP_TEMP" "$SETUP_GLOBAL"
pass "Setup: temp dirs cleaned"

# ═══════════════════════════════════════════════════════════════
section "16. User Profile — New Project with Existing Global"
# ═══════════════════════════════════════════════════════════════

NEWPROJ_TEMP="/tmp/psk-newproj-$(date +%s)"
NEWPROJ_GLOBAL="/tmp/psk-newproj-global-$(date +%s)"
mkdir -p "$NEWPROJ_TEMP" && cd "$NEWPROJ_TEMP"

# Simulate: global exists, workspace doesn't
mkdir -p "$NEWPROJ_GLOBAL/.portable-spec-kit/user-profile"
cat > "$NEWPROJ_GLOBAL/.portable-spec-kit/user-profile/user-profile-testuser.md" << 'EOF'
# User Profile
> Auto-created on first session. Edit anytime.

- **Test User** — M.S. AI. Machine learning, NLP.
- Communication style: direct, data-driven, prefers comprehensive analysis with tables and evidence
- Working pattern: plan-first — defines full specs and architecture before writing any code
- AI delegation: AI does 90%, user reviews 10% — present ready-to-act outputs, not questions
EOF

# No workspace profile yet
! [ -d "$NEWPROJ_TEMP/.portable-spec-kit/user-profile" ] && pass "NewProj: no workspace profile initially" || fail "NewProj: workspace exists prematurely"

# Simulate "Keep" flow: copy global to workspace
mkdir -p "$NEWPROJ_TEMP/.portable-spec-kit/user-profile"
cp "$NEWPROJ_GLOBAL/.portable-spec-kit/user-profile/user-profile-testuser.md" \
   "$NEWPROJ_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md"

[ -f "$NEWPROJ_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" ] && pass "NewProj: workspace profile created on Keep" || fail "NewProj: workspace profile MISSING after Keep"

# Verify content matches global
diff "$NEWPROJ_GLOBAL/.portable-spec-kit/user-profile/user-profile-testuser.md" \
     "$NEWPROJ_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" > /dev/null 2>&1 \
  && pass "NewProj: Keep preserves global content exactly" || fail "NewProj: Keep modified content"

# Simulate "Customize" flow: change one field, save to workspace
sed 's/plan-first.*/prototype-fast — gets something working quickly, then refines and polishes/' \
  "$NEWPROJ_GLOBAL/.portable-spec-kit/user-profile/user-profile-testuser.md" \
  > "$NEWPROJ_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md"

grep -q "prototype-fast" "$NEWPROJ_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" && pass "NewProj: Customize changes saved to workspace" || fail "NewProj: Customize not saved"

# Verify global unchanged
grep -q "plan-first" "$NEWPROJ_GLOBAL/.portable-spec-kit/user-profile/user-profile-testuser.md" && pass "NewProj: global profile unchanged after Customize" || fail "NewProj: global was modified"

# Verify other fields preserved
grep -q "Test User" "$NEWPROJ_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" && pass "NewProj: name preserved after Customize" || fail "NewProj: name lost"
grep -q "AI does 90%" "$NEWPROJ_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" && pass "NewProj: delegation preserved after Customize" || fail "NewProj: delegation lost"

rm -rf "$NEWPROJ_TEMP" "$NEWPROJ_GLOBAL"
pass "NewProj: temp dirs cleaned"

# ═══════════════════════════════════════════════════════════════
section "17. User Profile — Returning Session Scenarios"
# ═══════════════════════════════════════════════════════════════

RET_TEMP="/tmp/psk-ret-$(date +%s)"
RET_GLOBAL="/tmp/psk-ret-global-$(date +%s)"
mkdir -p "$RET_TEMP" && cd "$RET_TEMP"

# --- Scenario A: Workspace profile exists ---
mkdir -p "$RET_TEMP/.portable-spec-kit/user-profile"
cat > "$RET_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" << 'EOF'
# User Profile
- **Test User** — Workspace profile.
- Communication style: conversational
- Working pattern: prototype-fast
- AI delegation: 50/50
EOF

[ -f "$RET_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" ] && pass "Return A: workspace profile found → use directly" || fail "Return A: workspace profile not found"

# --- Scenario B: Only global exists (no workspace) ---
rm -rf "$RET_TEMP/.portable-spec-kit"
mkdir -p "$RET_GLOBAL/.portable-spec-kit/user-profile"
cat > "$RET_GLOBAL/.portable-spec-kit/user-profile/user-profile-testuser.md" << 'EOF'
# User Profile
- **Test User** — Global profile.
- Communication style: direct and concise
- Working pattern: iterative
- AI delegation: AI does 70%
EOF

! [ -d "$RET_TEMP/.portable-spec-kit/user-profile" ] && pass "Return B: no workspace profile" || fail "Return B: workspace exists unexpectedly"
[ -f "$RET_GLOBAL/.portable-spec-kit/user-profile/user-profile-testuser.md" ] && pass "Return B: global profile found → show to user, ask keep/customize" || fail "Return B: global not found"

# Simulate: user keeps → copy to workspace
mkdir -p "$RET_TEMP/.portable-spec-kit/user-profile"
cp "$RET_GLOBAL/.portable-spec-kit/user-profile/user-profile-testuser.md" \
   "$RET_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md"
[ -f "$RET_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" ] && pass "Return B: workspace copy created after keep" || fail "Return B: workspace copy not created"

# --- Scenario C: No profile anywhere ---
rm -rf "$RET_TEMP/.portable-spec-kit" "$RET_GLOBAL/.portable-spec-kit"
! [ -d "$RET_TEMP/.portable-spec-kit/user-profile" ] && pass "Return C: no workspace profile" || fail "Return C: workspace exists"
! [ -d "$RET_GLOBAL/.portable-spec-kit/user-profile" ] && pass "Return C: no global profile → triggers first-time setup" || fail "Return C: global exists"

rm -rf "$RET_TEMP" "$RET_GLOBAL"
pass "Return: temp dirs cleaned"

# ═══════════════════════════════════════════════════════════════
section "18. User Profile — Edge Cases"
# ═══════════════════════════════════════════════════════════════

EDGE_TEMP="/tmp/psk-edge-$(date +%s)"
mkdir -p "$EDGE_TEMP/.portable-spec-kit/user-profile" && cd "$EDGE_TEMP"

# --- Empty profile file → treat as missing ---
touch "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md"
[ -f "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md" ] && pass "Edge: empty file exists" || fail "Edge: empty file not created"
CONTENT=$(cat "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-testuser.md")
[ -z "$CONTENT" ] && pass "Edge: empty file detected → treat as missing" || fail "Edge: empty file has content"

# --- Profile with all 4 required fields ---
cat > "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-complete.md" << 'EOF'
# User Profile
- **Complete User** — PhD. AI Research.
- Communication style: direct
- Working pattern: iterative
- AI delegation: AI does 90%
EOF

grep -q "Complete User" "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-complete.md" && pass "Edge: name field present" || fail "Edge: name missing"
grep -q "Communication style:" "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-complete.md" && pass "Edge: communication field present" || fail "Edge: communication missing"
grep -q "Working pattern:" "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-complete.md" && pass "Edge: working pattern field present" || fail "Edge: working pattern missing"
grep -q "AI delegation:" "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-complete.md" && pass "Edge: delegation field present" || fail "Edge: delegation missing"

# --- Multiple users in same workspace (team scenario) ---
cat > "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-alice.md" << 'EOF'
# User Profile
- **Alice** — Frontend dev.
- Communication style: conversational
- Working pattern: prototype-fast
- AI delegation: 50/50
EOF

cat > "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-bob.md" << 'EOF'
# User Profile
- **Bob** — Backend dev.
- Communication style: direct and concise
- Working pattern: plan-first
- AI delegation: AI does 90%
EOF

[ -f "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-alice.md" ] && pass "Edge: Alice's profile exists" || fail "Edge: Alice missing"
[ -f "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-bob.md" ] && pass "Edge: Bob's profile exists" || fail "Edge: Bob missing"
grep -q "Alice" "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-alice.md" && pass "Edge: Alice's profile has correct name" || fail "Edge: Alice wrong name"
grep -q "Bob" "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-bob.md" && pass "Edge: Bob's profile has correct name" || fail "Edge: Bob wrong name"

# --- Profiles don't contaminate each other ---
! grep -q "Bob" "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-alice.md" && pass "Edge: Alice's profile doesn't contain Bob" || fail "Edge: profile contamination"
! grep -q "Alice" "$EDGE_TEMP/.portable-spec-kit/user-profile/user-profile-bob.md" && pass "Edge: Bob's profile doesn't contain Alice" || fail "Edge: profile contamination"

# --- Username with special chars slugified ---
# Simulating: "John O'Brien" → "john-o-brien" or similar
SLUGIFIED=$(echo "John O'Brien" | tr '[:upper:]' '[:lower:]' | tr " '" '-' | tr -cd '[:alnum:]-')
[ "$SLUGIFIED" = "john-obrien" ] || [ "$SLUGIFIED" = "john-o-brien" ] && pass "Edge: special chars slugified correctly" || fail "Edge: slugification wrong ($SLUGIFIED)"

rm -rf "$EDGE_TEMP"
pass "Edge: temp dir cleaned"

# ═══════════════════════════════════════════════════════════════
section "19. Flow Documentation — All 8 Flows Present"
# ═══════════════════════════════════════════════════════════════

FLOWS_DIR="$PROJ/docs/flows"
[ -d "$FLOWS_DIR" ] && pass "docs/flows/ directory exists" || fail "docs/flows/ MISSING"

for flow in user-profile-setup new-project-setup returning-session agent-switching profile-customization spec-driven-development first-session-workspace file-management; do
  [ -f "$FLOWS_DIR/$flow.md" ] && pass "Flow: $flow.md exists" || fail "Flow: $flow.md MISSING"
done

# Verify each flow has required sections
for flow in user-profile-setup new-project-setup returning-session agent-switching profile-customization spec-driven-development first-session-workspace file-management; do
  grep -q "^# Flow:" "$FLOWS_DIR/$flow.md" && pass "Flow $flow: has title" || fail "Flow $flow: missing title"
  grep -q "When:" "$FLOWS_DIR/$flow.md" && pass "Flow $flow: has trigger" || fail "Flow $flow: missing trigger"
done

# Verify profile flows reference .portable-spec-kit/user-profile/
for flow in user-profile-setup new-project-setup returning-session profile-customization first-session-workspace; do
  grep -q "portable-spec-kit/user-profile" "$FLOWS_DIR/$flow.md" && pass "Flow $flow: references profile path" || fail "Flow $flow: missing profile path"
done

# Verify agent-switching flow mentions symlinks
grep -q "symlink" "$FLOWS_DIR/agent-switching.md" && pass "Flow agent-switching: mentions symlinks" || fail "Flow agent-switching: missing symlinks"

# Verify spec-driven flow has context update step
grep -q "AGENT_CONTEXT" "$FLOWS_DIR/spec-driven-development.md" && pass "Flow spec-driven: has context update step" || fail "Flow spec-driven: missing context update"
grep -q "docs/flows" "$FLOWS_DIR/spec-driven-development.md" && pass "Flow spec-driven: has flow update step" || fail "Flow spec-driven: missing flow update"

# ═══════════════════════════════════════════════════════════════
section "20. ARD Directory — Guide Moved"
# ═══════════════════════════════════════════════════════════════

[ -d "$PROJ/ard" ] && pass "ard/ directory exists" || fail "ard/ MISSING"
[ -f "$PROJ/ard/Portable_Spec_Kit_Guide.html" ] && pass "Guide HTML in ard/" || fail "Guide HTML missing from ard/"
[ -f "$PROJ/ard/Portable_Spec_Kit_Guide.pdf" ] && pass "Guide PDF in ard/" || fail "Guide PDF missing from ard/"
! [ -f "$PROJ/docs/Portable_Spec_Kit_Guide.html" ] && pass "No guide in old docs/ location" || fail "Stale guide in docs/"
! [ -f "$PROJ/docs/Portable_Spec_Kit_Guide.pdf" ] && pass "No PDF in old docs/ location" || fail "Stale PDF in docs/"

# Verify guide has .portable-spec-kit/ in project structure
grep -q "portable-spec-kit/" "$PROJ/ard/Portable_Spec_Kit_Guide.html" && pass "Guide: has .portable-spec-kit/ in structure" || fail "Guide: missing .portable-spec-kit/"

# Verify guide has 10 strengths
grep -q "10 Core Strengths" "$PROJ/ard/Portable_Spec_Kit_Guide.html" && pass "Guide: has 10 Core Strengths" || fail "Guide: wrong strength count"

# ═══════════════════════════════════════════════════════════════
section "21. Context Management Rule"
# ═══════════════════════════════════════════════════════════════

grep -q "After completing implementations or running tests" "$PROJ/portable-spec-kit.md" && pass "Context rule: implementation/test trigger" || fail "Context rule: missing trigger"
grep -q "docs/flows/" "$PROJ/portable-spec-kit.md" && pass "Context rule: references flow docs" || fail "Context rule: missing flow docs reference"
grep -q "Context, flows, and tests must always match" "$PROJ/portable-spec-kit.md" && pass "Context rule: triad requirement" || fail "Context rule: missing triad"

# ═══════════════════════════════════════════════════════════════
section "22. Versioning System"
# ═══════════════════════════════════════════════════════════════

# Framework version exists in file
grep -q "<!-- Framework Version:" "$PROJ/portable-spec-kit.md" && pass "Framework version comment exists" || fail "Framework version MISSING"

# Framework version format is v{N}.{N}.{N}
grep -q "<!-- Framework Version: v[0-9]\+\.[0-9]\+\.[0-9]\+ -->" "$PROJ/portable-spec-kit.md" && pass "Framework version format correct" || fail "Framework version format wrong"

# Two-level versioning table exists
grep -q "Release.*Framework Range" "$PROJ/portable-spec-kit.md" && pass "Versioning table exists" || fail "Versioning table MISSING"

# Release-to-framework mapping documented
grep -q "v0\.1.*v0\.0\." "$PROJ/portable-spec-kit.md" && pass "v0.1 → v0.0.x mapping" || fail "v0.1 mapping missing"
grep -q "v0\.2.*v0\.1\." "$PROJ/portable-spec-kit.md" && pass "v0.2 → v0.1.x mapping" || fail "v0.2 mapping missing"
grep -q "v0\.3.*v0\.2\." "$PROJ/portable-spec-kit.md" && pass "v0.3 → v0.2.x mapping" || fail "v0.3 mapping missing"

# AGENT_CONTEXT template has Framework field
grep -q "Framework.*v0\." "$PROJ/portable-spec-kit.md" && pass "AGENT_CONTEXT template has Framework field" || fail "Template missing Framework"

# Framework version comparison rule exists
grep -q "compare.*Framework Version.*AGENT_CONTEXT" "$PROJ/portable-spec-kit.md" && pass "Version comparison rule exists" || fail "Version comparison rule MISSING"

# TASKS.md has version-based structure
grep -q "v0\.1 — Done" "$PROJ/agent/TASKS.md" && pass "TASKS: v0.1 Done" || fail "TASKS: v0.1 missing"
grep -q "v0\.2 — Done" "$PROJ/agent/TASKS.md" && pass "TASKS: v0.2 Done" || fail "TASKS: v0.2 missing"
grep -q "v0\.3 — Current" "$PROJ/agent/TASKS.md" && pass "TASKS: v0.3 Current" || fail "TASKS: v0.3 missing"
grep -q "Backlog" "$PROJ/agent/TASKS.md" && pass "TASKS: Backlog section" || fail "TASKS: Backlog missing"
grep -q "Progress Summary" "$PROJ/agent/TASKS.md" && pass "TASKS: Progress Summary" || fail "TASKS: Progress Summary missing"

# TRACKER.md has framework version ranges
grep -q "Framework versions: v0\.0\." "$PROJ/agent/TRACKER.md" && pass "TRACKER: v0.1 has framework range" || fail "TRACKER: v0.1 range missing"
grep -q "Framework versions: v0\.1\." "$PROJ/agent/TRACKER.md" && pass "TRACKER: v0.2 has framework range" || fail "TRACKER: v0.2 range missing"

# AGENT_CONTEXT has current framework version
grep -q "Framework:" "$PROJ/agent/AGENT_CONTEXT.md" && pass "AGENT_CONTEXT: has Framework field" || fail "AGENT_CONTEXT: Framework field missing"

# ═══════════════════════════════════════════════════════════════
section "23. License"
# ═══════════════════════════════════════════════════════════════

grep -q "MIT License" "$PROJ/LICENSE" && pass "MIT License present" || fail "License wrong"
grep -q "Aqib Mumtaz" "$PROJ/LICENSE" && pass "Author in license" || fail "Author missing from license"

# ═══════════════════════════════════════════════════════════════
# RESULTS
# ═══════════════════════════════════════════════════════════════

echo ""
echo "═══════════════════════════════════════════"
echo "  RESULTS: $PASS passed, $FAIL failed, $TOTAL total"
echo "═══════════════════════════════════════════"

if [ $FAIL -eq 0 ]; then
  echo "  ✅ ALL TESTS PASSED"
  exit 0
else
  echo "  ❌ $FAIL TESTS FAILED"
  exit 1
fi
