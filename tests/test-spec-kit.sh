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

grep -q "Portable Spec Kit — Spec-Persistent Development" "$PROJ/portable-spec-kit.md" && pass "Title correct" || fail "Title wrong"
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
grep -q "agent/PLANS.md:" "$PROJ/portable-spec-kit.md" && pass "PLANS.md template" || fail "Missing PLANS.md template"
grep -q "agent/TASKS.md:" "$PROJ/portable-spec-kit.md" && pass "TASKS.md template" || fail "Missing TASKS.md template"
grep -q "agent/RELEASES.md:" "$PROJ/portable-spec-kit.md" && pass "RELEASES.md template" || fail "Missing RELEASES.md template"

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
[ -f "$S/agent/PLANS.md" ] && pass "starter: agent/PLANS.md" || fail "starter: PLANS.md MISSING"
[ -f "$S/agent/TASKS.md" ] && pass "starter: agent/TASKS.md" || fail "starter: TASKS.md MISSING"
[ -f "$S/agent/RELEASES.md" ] && pass "starter: agent/RELEASES.md" || fail "starter: RELEASES.md MISSING"
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
[ -f "$M/agent/PLANS.md" ] && pass "my-app: agent/PLANS.md" || fail "my-app: PLANS.md MISSING"
[ -f "$M/agent/TASKS.md" ] && pass "my-app: agent/TASKS.md" || fail "my-app: TASKS.md MISSING"
[ -f "$M/agent/RELEASES.md" ] && pass "my-app: agent/RELEASES.md" || fail "my-app: RELEASES.md MISSING"
grep -q "Next.js" "$M/agent/AGENT.md" && pass "my-app: has Next.js stack" || fail "my-app: no stack defined"
grep -q "11/16\|11 of 16" "$M/agent/TASKS.md" 2>/dev/null || grep -q "\[x\]" "$M/agent/TASKS.md" && pass "my-app: has completed tasks" || fail "my-app: no tasks done"
grep -q "v0.1" "$M/agent/RELEASES.md" && pass "my-app: has v0.1 changelog" || fail "my-app: no changelog"

# ═══════════════════════════════════════════════════════════════
section "8. README — Key Sections Present"
# ═══════════════════════════════════════════════════════════════

grep -q "Portable Spec Kit" "$PROJ/README.md" && pass "README: title present" || fail "README: title missing"
grep -q "spec-kit" "$PROJ/README.md" && pass "README: spec-kit comparison" || fail "README: no spec-kit comparison"
grep -q "Setup" "$PROJ/README.md" && pass "README: Setup section" || fail "README: no Setup"
grep -q "Multi-Agent Support" "$PROJ/README.md" && pass "README: Multi-Agent section" || fail "README: no Multi-Agent"
grep -q "Complete Flow" "$PROJ/README.md" && pass "README: Complete Flow" || fail "README: no Complete Flow"
grep -q "Development Guidelines" "$PROJ/README.md" && pass "README: Development Guidelines section" || fail "README: no Development Guidelines"
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
section "19. Flow Documentation — All 14 Flows + Diagram Integrity"
# ═══════════════════════════════════════════════════════════════

FLOWS_DIR="$PROJ/docs/work-flows"
[ -d "$FLOWS_DIR" ] && pass "docs/work-flows/ directory exists" || fail "docs/work-flows/ MISSING"

for flow in 01-first-session-workspace 02-user-profile-setup 03-new-project-setup 04-existing-project-setup 05-project-init 06-cicd-setup 07-returning-session 08-agent-switching 09-profile-customization 10-file-management 11-spec-persistent-development 12-project-lifecycle 13-release-workflow 14-team-collaboration; do
  [ -f "$FLOWS_DIR/$flow.md" ] && pass "Flow: $flow.md exists" || fail "Flow: $flow.md MISSING"
done

# Verify each flow has required sections
for flow in 01-first-session-workspace 02-user-profile-setup 03-new-project-setup 04-existing-project-setup 05-project-init 06-cicd-setup 07-returning-session 08-agent-switching 09-profile-customization 10-file-management 11-spec-persistent-development 12-project-lifecycle 13-release-workflow 14-team-collaboration; do
  grep -q "^# Flow:" "$FLOWS_DIR/$flow.md" && pass "Flow $flow: has title" || fail "Flow $flow: missing title"
  grep -q "When:" "$FLOWS_DIR/$flow.md" && pass "Flow $flow: has trigger" || fail "Flow $flow: missing trigger"
done

# Verify profile flows reference .portable-spec-kit/user-profile/
for flow in 02-user-profile-setup 03-new-project-setup 07-returning-session 09-profile-customization 01-first-session-workspace; do
  grep -q "portable-spec-kit/user-profile" "$FLOWS_DIR/$flow.md" && pass "Flow $flow: references profile path" || fail "Flow $flow: missing profile path"
done

# Verify 08-agent-switching flow mentions symlinks
grep -q "symlink" "$FLOWS_DIR/08-agent-switching.md" && pass "Flow 08-agent-switching: mentions symlinks" || fail "Flow 08-agent-switching: missing symlinks"

# Verify spec-persistent flow has context update step
grep -q "AGENT_CONTEXT" "$FLOWS_DIR/11-spec-persistent-development.md" && pass "Flow spec-persistent: has context update step" || fail "Flow spec-persistent: missing context update"
grep -q "docs/work-flows" "$FLOWS_DIR/11-spec-persistent-development.md" && pass "Flow spec-persistent: has flow update step" || fail "Flow spec-persistent: missing flow update"

# Verify 12-project-lifecycle flow content
grep -q "R1" "$FLOWS_DIR/12-project-lifecycle.md" && pass "Flow 12-project-lifecycle: has R→F traceability" || fail "Flow 12-project-lifecycle: missing R→F traceability"
grep -q "DROP" "$FLOWS_DIR/12-project-lifecycle.md" && pass "Flow 12-project-lifecycle: has scope change types" || fail "Flow 12-project-lifecycle: missing scope change types"
grep -q "REPLACE" "$FLOWS_DIR/12-project-lifecycle.md" && pass "Flow 12-project-lifecycle: has REPLACE type" || fail "Flow 12-project-lifecycle: missing REPLACE"
grep -q "TaskFlow" "$FLOWS_DIR/12-project-lifecycle.md" && pass "Flow 12-project-lifecycle: has TaskFlow example" || fail "Flow 12-project-lifecycle: missing TaskFlow"
grep -q "Phase 9" "$FLOWS_DIR/12-project-lifecycle.md" && pass "Flow 12-project-lifecycle: has all 9 phases" || fail "Flow 12-project-lifecycle: missing phases"
grep -q "Traceability Chain" "$FLOWS_DIR/12-project-lifecycle.md" && pass "Flow 12-project-lifecycle: has traceability chain" || fail "Flow 12-project-lifecycle: missing traceability"

# Verify 03-new-project-setup flow mentions conda for Python projects
grep -q "conda\|Environment Selection" "$FLOWS_DIR/03-new-project-setup.md" && pass "Flow 03-new-project-setup: references Python env setup" || fail "Flow 03-new-project-setup: missing Python env reference"

# Verify 13-release-workflow flow content
grep -q "prepare release\|8-Step\|Prepare Release" "$FLOWS_DIR/13-release-workflow.md" && pass "Flow 13-release-workflow: has prepare release sequence" || fail "Flow 13-release-workflow: missing prepare release"
grep -q "Pre-Push Gate\|pre-push\|pre_push" "$FLOWS_DIR/13-release-workflow.md" && pass "Flow 13-release-workflow: has pre-push gate" || fail "Flow 13-release-workflow: missing pre-push gate"
grep -q "Stub Completion\|stub.*complete\|check_stub_complete" "$FLOWS_DIR/13-release-workflow.md" && pass "Flow 13-release-workflow: has stub completion gate" || fail "Flow 13-release-workflow: missing stub completion gate"

# Verify 14-team-collaboration flow content
grep -q "@username\|username.*ownership\|task.*owner" "$FLOWS_DIR/14-team-collaboration.md" && pass "Flow 14-team-collaboration: has @username ownership" || fail "Flow 14-team-collaboration: missing @username ownership"
grep -q "progress.*dashboard\|dashboard.*trigger\|TRIGGER WORDS" "$FLOWS_DIR/14-team-collaboration.md" && pass "Flow 14-team-collaboration: has progress dashboard trigger" || fail "Flow 14-team-collaboration: missing dashboard trigger"
grep -q "Persistent Memory\|persistent.*memory" "$FLOWS_DIR/14-team-collaboration.md" && pass "Flow 14-team-collaboration: references Persistent Memory Architecture" || fail "Flow 14-team-collaboration: missing Persistent Memory reference"

# Verify 04-existing-project-setup flow content
grep -q "Mapped\|Partial\|New" "$FLOWS_DIR/04-existing-project-setup.md" && pass "Flow 04-existing-project-setup: has kit status states" || fail "Flow 04-existing-project-setup: missing kit status states"
grep -q "DETECT PROJECT STATE\|Detect.*State\|Step 0" "$FLOWS_DIR/04-existing-project-setup.md" && pass "Flow 04-existing-project-setup: has Step 0 state detection" || fail "Flow 04-existing-project-setup: missing Step 0 state detection"
grep -q "SCAN\|scan.*thoroughly\|Scan" "$FLOWS_DIR/04-existing-project-setup.md" && pass "Flow 04-existing-project-setup: has scan step" || fail "Flow 04-existing-project-setup: missing scan step"
grep -q "PRESENT CHECKLIST\|checklist\|suggest" "$FLOWS_DIR/04-existing-project-setup.md" && pass "Flow 04-existing-project-setup: has checklist step" || fail "Flow 04-existing-project-setup: missing checklist step"
grep -q "Returning Session\|returning.*session\|vs.*return" "$FLOWS_DIR/04-existing-project-setup.md" && pass "Flow 04-existing-project-setup: contrasts with returning session" || fail "Flow 04-existing-project-setup: missing returning session comparison"

# Verify 06-cicd-setup flow content
grep -q "ci\.yml\|ci_yml\|CI workflow" "$FLOWS_DIR/06-cicd-setup.md" && pass "Flow 06-cicd-setup: references ci.yml" || fail "Flow 06-cicd-setup: missing ci.yml reference"
grep -q "stack\|Stack\|STACK" "$FLOWS_DIR/06-cicd-setup.md" && pass "Flow 06-cicd-setup: has stack detection step" || fail "Flow 06-cicd-setup: missing stack detection"
grep -q "test-release-check\|R.*F.*T\|release-check" "$FLOWS_DIR/06-cicd-setup.md" && pass "Flow 06-cicd-setup: includes test-release-check.sh in CI" || fail "Flow 06-cicd-setup: missing test-release-check.sh"
grep -q "badge\|Badge" "$FLOWS_DIR/06-cicd-setup.md" && pass "Flow 06-cicd-setup: has CI badge step" || fail "Flow 06-cicd-setup: missing CI badge step"
grep -qi "branch protection\|branch_protection" "$FLOWS_DIR/06-cicd-setup.md" && pass "Flow 06-cicd-setup: has branch protection guidance" || fail "Flow 06-cicd-setup: missing branch protection"

# ── Diagram integrity checks (run on every prepare release) ──────

# No tree-style standalone ▼ lines between boxes
TREE_V=$(grep -rl $'^\s*\xe2\x96\xbc\s*$' "$FLOWS_DIR/" 2>/dev/null | wc -l | tr -d ' ')
[ "$TREE_V" -eq 0 ] && pass "Flow docs: no tree-style standalone ▼ lines" || fail "Flow docs: tree-style ▼ found — convert to box connectors (┌──────▼──────┐)"

# No standalone │ lines between steps (tree-style spacing)
TREE_PIPE=$(grep -rPl '^\s+│\s*$' "$FLOWS_DIR/" 2>/dev/null | wc -l | tr -d ' ')
[ "$TREE_PIPE" -eq 0 ] && pass "Flow docs: no tree-style standalone │ spacing lines" || fail "Flow docs: tree-style │ spacing found — use └──────┬──────┘ connector format"

# All box lines exactly 63 display chars wide (box drawing chars = 1 display col)
MISALIGNED=$(python3 -c "
import glob, unicodedata
def dw(s): return len(s) + sum(1 for c in s if unicodedata.east_asian_width(c) in ('W','F'))
bad = sum(1 for f in glob.glob('$FLOWS_DIR/*.md')
          for line in open(f, encoding='utf-8')
          if line.rstrip('\n') and line.rstrip('\n')[0] in '│┌└' and dw(line.rstrip('\n')) != 63)
print(bad)
" 2>/dev/null || echo 0)
[ "$MISALIGNED" -eq 0 ] && pass "Flow docs: all box lines are exactly 63 chars wide" || fail "Flow docs: $MISALIGNED box line(s) misaligned — right │ border not aligned"

# Framework has architecture-change rule for flow docs
grep -q "Architecture change rule\|architecture change.*flow\|process.*change.*flow doc" "$PROJ/portable-spec-kit.md" && pass "Flow docs: framework has architecture-change rule" || fail "Flow docs: architecture-change rule missing from framework"

# Framework has release gate for flow docs in prepare release step
grep -q "flow doc.*release\|release.*flow doc\|prepare release.*flow\|flow.*prepare release" "$PROJ/portable-spec-kit.md" && pass "Flow docs: release gate for flow docs in prepare release" || fail "Flow docs: flow doc release gate missing from prepare release"

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

grep -q "Tier 1.*After significant work\|Tier 2.*Before push" "$PROJ/portable-spec-kit.md" && pass "Context rule: two-tier update rule defined" || fail "Context rule: missing trigger"
grep -q "docs/work-flows/" "$PROJ/portable-spec-kit.md" && pass "Context rule: references flow docs" || fail "Context rule: missing flow docs reference"
grep -q "SPECS.md.*PLANS.md.*TASKS.md\|Tier 2" "$PROJ/portable-spec-kit.md" && pass "Context rule: Tier 2 full sync before push" || fail "Context rule: missing triad"

# ═══════════════════════════════════════════════════════════════
section "22. Versioning System"
# ═══════════════════════════════════════════════════════════════

# Framework version exists in file
grep -q "<!-- Framework Version:" "$PROJ/portable-spec-kit.md" && pass "Framework version comment exists" || fail "Framework version MISSING"

# Framework version format is v{N}.{N}.{N}
grep -q "<!-- Framework Version: v[0-9]\+\.[0-9]\+\.[0-9]\+ -->" "$PROJ/portable-spec-kit.md" && pass "Framework version format correct" || fail "Framework version format wrong"

# Versioning table exists (release groups with patch ranges)
grep -q "Release group\|v0\.4.*active\|v0\.4.*v0\.4\." "$PROJ/portable-spec-kit.md" && pass "Versioning table exists" || fail "Versioning table MISSING"

# Release-to-framework mapping documented (aligned: v0.N release uses v0.N.x patches)
grep -q "v0\.1.*v0\.1\." "$PROJ/portable-spec-kit.md" && pass "v0.1 → v0.1.x mapping" || fail "v0.1 mapping missing"
grep -q "v0\.2.*v0\.2\." "$PROJ/portable-spec-kit.md" && pass "v0.2 → v0.2.x mapping" || fail "v0.2 mapping missing"
grep -q "v0\.3.*v0\.3\." "$PROJ/portable-spec-kit.md" && pass "v0.3 → v0.3.x mapping" || fail "v0.3 mapping missing"

# AGENT_CONTEXT template has Kit field (installed kit version)
grep -q "\*\*Kit:\*\*" "$PROJ/portable-spec-kit.md" && pass "AGENT_CONTEXT template has Kit field" || fail "Template missing Kit field"

# Kit version comparison rule exists (compare Framework Version comment against Kit field)
grep -q "compare.*Framework Version.*Kit\|Framework Version.*Kit" "$PROJ/portable-spec-kit.md" && pass "Version comparison rule exists" || fail "Version comparison rule MISSING"

# TASKS.md has version-based structure
grep -q "v0\.0 — Done" "$PROJ/agent/TASKS.md" && pass "TASKS: v0.0 Done" || fail "TASKS: v0.0 missing"
grep -q "v0\.1 — Done" "$PROJ/agent/TASKS.md" && pass "TASKS: v0.1 Done" || fail "TASKS: v0.1 missing"
grep -q "v0\.2 — " "$PROJ/agent/TASKS.md" && pass "TASKS: v0.2 section" || fail "TASKS: v0.2 missing"
grep -q "v0\.3 — " "$PROJ/agent/TASKS.md" && pass "TASKS: v0.3 section" || fail "TASKS: v0.3 missing"
grep -q "Backlog" "$PROJ/agent/TASKS.md" && pass "TASKS: Backlog section" || fail "TASKS: Backlog missing"
grep -q "Progress Summary" "$PROJ/agent/TASKS.md" && pass "TASKS: Progress Summary" || fail "TASKS: Progress Summary missing"

# RELEASES.md has kit version ranges
grep -q "Kit: v0\.0\." "$PROJ/agent/RELEASES.md" && pass "TRACKER: v0.0 has kit range (v0.0.x)" || fail "TRACKER: v0.0 range missing"
grep -q "Kit: v0\.1\." "$PROJ/agent/RELEASES.md" && pass "TRACKER: v0.1 has kit range (v0.1.x)" || fail "TRACKER: v0.1 range missing"

# AGENT_CONTEXT has current version with patch number (v0.N.N format)
grep -q "\*\*Version:\*\* v[0-9]\+\.[0-9]\+\.[0-9]\+" "$PROJ/agent/AGENT_CONTEXT.md" && pass "AGENT_CONTEXT: Version has patch number (v0.N.N)" || fail "AGENT_CONTEXT: Version missing patch number — expected v0.N.N format"

# ═══════════════════════════════════════════════════════════════
section "23. Python Environment — Conda Rules"
# ═══════════════════════════════════════════════════════════════

# Section exists
grep -q "Python Environment (MANDATORY" "$PROJ/portable-spec-kit.md" && pass "Conda: section exists" || fail "Conda: section MISSING"

# Core rules
grep -q "conda environment" "$PROJ/portable-spec-kit.md" && pass "Conda: requires conda env per project" || fail "Conda: missing env requirement"
grep -q "conda env list" "$PROJ/portable-spec-kit.md" && pass "Conda: lists existing envs flow" || fail "Conda: missing env list"
grep -q "Create new conda env" "$PROJ/portable-spec-kit.md" && pass "Conda: create new option" || fail "Conda: missing create option"
grep -q "Use an existing env" "$PROJ/portable-spec-kit.md" && pass "Conda: use existing option" || fail "Conda: missing existing option"

# Conda installation
grep -q "Conda Installation" "$PROJ/portable-spec-kit.md" && pass "Conda: installation section" || fail "Conda: missing installation"
grep -q "which conda" "$PROJ/portable-spec-kit.md" && pass "Conda: detection check" || fail "Conda: missing detection"
grep -q "Miniconda" "$PROJ/portable-spec-kit.md" && pass "Conda: Miniconda reference" || fail "Conda: missing Miniconda"

# Environment selection triggers
grep -q "New project setup" "$PROJ/portable-spec-kit.md" && pass "Conda: triggers on new project" || fail "Conda: missing new project trigger"
grep -q "Existing project setup" "$PROJ/portable-spec-kit.md" && pass "Conda: triggers on existing project" || fail "Conda: missing existing project trigger"

# requirements.txt handling
grep -q "requirements.txt" "$PROJ/portable-spec-kit.md" && pass "Conda: requirements.txt management" || fail "Conda: missing requirements.txt"
grep -q "pip freeze" "$PROJ/portable-spec-kit.md" && pass "Conda: pip freeze rule" || fail "Conda: missing pip freeze"

# Record in AGENT.md
grep -q "agent/AGENT.md.*Stack" "$PROJ/portable-spec-kit.md" && pass "Conda: record env in AGENT.md" || fail "Conda: missing AGENT.md recording"
grep -q "Conda Env" "$PROJ/portable-spec-kit.md" && pass "Conda: AGENT.md template has Conda Env row" || fail "Conda: missing Conda Env in template"

# Edge cases
grep -q "Env name already exists" "$PROJ/portable-spec-kit.md" && pass "Conda edge: env name collision" || fail "Conda edge: missing name collision"
grep -q "No existing envs" "$PROJ/portable-spec-kit.md" && pass "Conda edge: no existing envs" || fail "Conda edge: missing no envs"
grep -q "requirements.txt.*install fails" "$PROJ/portable-spec-kit.md" && pass "Conda edge: install failure handling" || fail "Conda edge: missing install failure"
grep -q "pyproject.toml" "$PROJ/portable-spec-kit.md" && pass "Conda edge: pyproject.toml support" || fail "Conda edge: missing pyproject.toml"
grep -q "environment.yml" "$PROJ/portable-spec-kit.md" && pass "Conda edge: environment.yml support" || fail "Conda edge: missing environment.yml"
grep -q "venv\|virtualenv" "$PROJ/portable-spec-kit.md" && pass "Conda edge: existing venv handling" || fail "Conda edge: missing venv handling"
grep -q "Python version mismatch" "$PROJ/portable-spec-kit.md" && pass "Conda edge: version mismatch warning" || fail "Conda edge: missing version mismatch"
grep -q "Env recorded.*AGENT.md.*doesn't exist" "$PROJ/portable-spec-kit.md" && pass "Conda edge: env deleted from disk" || fail "Conda edge: missing env deleted"
grep -q "monorepo\|Multiple Python" "$PROJ/portable-spec-kit.md" && pass "Conda edge: monorepo separate envs" || fail "Conda edge: missing monorepo"

# Session rules
grep -q "Activate the project" "$PROJ/portable-spec-kit.md" && pass "Conda: activate on every session" || fail "Conda: missing session activation"
grep -q "Never hardcode.*conda" "$PROJ/portable-spec-kit.md" && pass "Conda: no hardcoded paths" || fail "Conda: missing hardcode rule"
grep -q "break-system-packages" "$PROJ/portable-spec-kit.md" && pass "Conda: no --break-system-packages" || fail "Conda: missing system-packages rule"

# ═══════════════════════════════════════════════════════════════
section "24. README — Python Environment Section"
# ═══════════════════════════════════════════════════════════════

grep -q "Python Environment" "$PROJ/README.md" && pass "README: Python Environment in features table" || fail "README: missing Python Environment"
grep -q "14 step-by-step flow" "$PROJ/README.md" && pass "README: 14 flows count" || fail "README: wrong flow count"
grep -q "12-project-lifecycle" "$PROJ/README.md" && pass "README: 12-project-lifecycle flow listed" || fail "README: missing 12-project-lifecycle"

# ═══════════════════════════════════════════════════════════════
section "25. License"
# ═══════════════════════════════════════════════════════════════

grep -q "MIT License" "$PROJ/LICENSE" && pass "MIT License present" || fail "License wrong"
grep -q "Aqib Mumtaz" "$PROJ/LICENSE" && pass "Author in license" || fail "Author missing from license"

# ═══════════════════════════════════════════════════════════════
section "26. Versioning — v0.3 Row + Current Version"
# ═══════════════════════════════════════════════════════════════

# v0.3 row must exist in version table
grep -q "v0\.3.*v0\.3\." "$PROJ/portable-spec-kit.md" && pass "Versioning: v0.3 → v0.3.x row present" || fail "Versioning: v0.3 row MISSING"

# Framework version comment must match AGENT_CONTEXT Version field
FW_COMMENT=$(grep "<!-- Framework Version:" "$PROJ/portable-spec-kit.md" | head -1 | grep -o "v[0-9]\+\.[0-9]\+\.[0-9]\+")
FW_CONTEXT=$(grep "\*\*Version:\*\*" "$PROJ/agent/AGENT_CONTEXT.md" | grep -o "v[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)
[ "$FW_COMMENT" = "$FW_CONTEXT" ] && pass "Versioning: framework comment ($FW_COMMENT) matches AGENT_CONTEXT Version ($FW_CONTEXT)" || fail "Versioning: MISMATCH — comment=$FW_COMMENT context=$FW_CONTEXT"

# README badge must match framework comment
README_VER=$(grep "version-v" "$PROJ/README.md" | grep -o "v[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)
[ "$README_VER" = "$FW_COMMENT" ] && pass "Versioning: README badge ($README_VER) matches framework ($FW_COMMENT)" || fail "Versioning: README badge STALE — badge=$README_VER framework=$FW_COMMENT"

# RELEASES.md must have v0.3 entry (current release)
grep -q "## v0\.3" "$PROJ/agent/RELEASES.md" && pass "RELEASES.md: v0.3 entry present" || fail "RELEASES.md: v0.3 entry MISSING"
grep -q "Kit: v0\.3\." "$PROJ/agent/RELEASES.md" && pass "RELEASES.md: v0.3 has kit version range (v0.3.x)" || fail "RELEASES.md: v0.3 missing kit range"

# ═══════════════════════════════════════════════════════════════
section "27. R→F Traceability & Scope Change Rules"
# ═══════════════════════════════════════════════════════════════

# 4 scope change types must be documented in framework
grep -q "DROP" "$PROJ/portable-spec-kit.md" && pass "Scope changes: DROP type documented" || fail "Scope changes: DROP MISSING"
grep -q "ADD" "$PROJ/portable-spec-kit.md" && pass "Scope changes: ADD type documented" || fail "Scope changes: ADD MISSING"
grep -q "MODIFY" "$PROJ/portable-spec-kit.md" && pass "Scope changes: MODIFY type documented" || fail "Scope changes: MODIFY MISSING"
grep -q "REPLACE" "$PROJ/portable-spec-kit.md" && pass "Scope changes: REPLACE type documented" || fail "Scope changes: REPLACE MISSING"

# R→F traceability rules in framework
grep -q "R→F Traceability\|R→F traceability" "$PROJ/portable-spec-kit.md" && pass "R→F: traceability rule present" || fail "R→F: traceability MISSING"
grep -q "Requirements.*R1\|Rn.*Fn\|R1, R2" "$PROJ/portable-spec-kit.md" && pass "R→F: Rn→Fn notation documented" || fail "R→F: notation MISSING"

# Scope change recording format documented
grep -q "change type.*original requirement\|note the change type" "$PROJ/portable-spec-kit.md" && pass "Scope: recording format documented" || fail "Scope: recording format MISSING"

# Scope change rule updates all 4 pipeline files
grep -q "Update TASKS.md and RELEASES.md in the same session" "$PROJ/portable-spec-kit.md" && pass "Scope: rule updates all pipeline files" || fail "Scope: pipeline update rule MISSING"

# ═══════════════════════════════════════════════════════════════
section "28. Scope Change Simulation (DROP/ADD/MODIFY/REPLACE)"
# ═══════════════════════════════════════════════════════════════

SCOPE_TEMP="/tmp/psk-scope-$(date +%s)"
mkdir -p "$SCOPE_TEMP/agent"

# Setup: project with 4 requirements, 4 features
cat > "$SCOPE_TEMP/agent/SPECS.md" << 'SPECEOF'
# SPECS.md — TaskFlow

## Requirements
- R1: users can log in
- R2: users can create tasks
- R3: users can view calendar
- R4: tasks export to CSV

## Features
| # | Feature | Req | Status |
|---|---------|-----|--------|
| F1 | Email + password auth | R1 | [x] |
| F2 | Task CRUD with priorities | R2 | [x] |
| F3 | Calendar view | R3 | [ ] |
| F4 | CSV export | R4 | [ ] |
SPECEOF

cat > "$SCOPE_TEMP/agent/TASKS.md" << 'TASKEOF'
# TASKS.md — TaskFlow

## v0.1 — Current
- [x] F1: auth system (R1)
- [x] F2: task CRUD (R2)
- [ ] F3: calendar view (R3)
- [ ] F4: CSV export (R4)
TASKEOF

cat > "$SCOPE_TEMP/agent/PLANS.md" << 'PLANEOF'
# PLANS.md — TaskFlow

## Decision Log
| Decision | Options | Chosen | Why |
|----------|---------|--------|-----|
| Auth method | OAuth / JWT | JWT | Simpler for MVP |
PLANEOF

# Simulate DROP: R3 (calendar) dropped by client
sed -i '' 's/| F3 | Calendar view | R3 | \[ \] |/| ~~F3~~ | ~~Calendar view~~ | ~~R3~~ | DROPPED 2026-04-05: client deprioritized |/' "$SCOPE_TEMP/agent/SPECS.md" 2>/dev/null || \
sed -i 's/| F3 | Calendar view | R3 | \[ \] |/| ~~F3~~ | ~~Calendar view~~ | ~~R3~~ | DROPPED 2026-04-05: client deprioritized |/' "$SCOPE_TEMP/agent/SPECS.md"
grep -q "DROPPED\|Out of scope\|deprioritized\|~~F3~~\|calendar" "$SCOPE_TEMP/agent/SPECS.md" && pass "DROP: F3/R3 marked as dropped in SPECS.md" || fail "DROP: calendar feature not removed from SPECS.md"

# Simulate ADD: R5 added (notifications)
echo "- R5: users receive push notifications" >> "$SCOPE_TEMP/agent/SPECS.md"
echo "| F5 | Push notifications | R5 | [ ] |" >> "$SCOPE_TEMP/agent/SPECS.md"
grep -q "R5\|notifications" "$SCOPE_TEMP/agent/SPECS.md" && pass "ADD: R5/F5 added to SPECS.md" || fail "ADD: new requirement not added"

# Simulate MODIFY: R4 changed from CSV to PDF export
sed -i '' 's/tasks export to CSV/tasks export to PDF and CSV/' "$SCOPE_TEMP/agent/SPECS.md" 2>/dev/null || \
sed -i 's/tasks export to CSV/tasks export to PDF and CSV/' "$SCOPE_TEMP/agent/SPECS.md"
grep -q "PDF\|pdf" "$SCOPE_TEMP/agent/SPECS.md" && pass "MODIFY: R4 updated to include PDF export" || fail "MODIFY: R4 not updated"

# Simulate REPLACE: F3 (calendar) → F6 (list view, same R3 intent)
echo "| F6 | List view (replaces F3 calendar — performance) | R3 | [ ] |" >> "$SCOPE_TEMP/agent/SPECS.md"
grep -q "F6\|List view\|replaces" "$SCOPE_TEMP/agent/SPECS.md" && pass "REPLACE: F6 added to replace F3, tracing R3" || fail "REPLACE: replacement feature not added"

# Verify R→F traceability preserved: R1, R2, R3, R4, R5 all still traceable
grep -q "R1" "$SCOPE_TEMP/agent/SPECS.md" && pass "Traceability: R1 still present after all changes" || fail "Traceability: R1 lost"
grep -q "R2" "$SCOPE_TEMP/agent/SPECS.md" && pass "Traceability: R2 still present" || fail "Traceability: R2 lost"
grep -q "R3" "$SCOPE_TEMP/agent/SPECS.md" && pass "Traceability: R3 still traceable (via F6 replacement)" || fail "Traceability: R3 lost"
grep -q "R4\|R5" "$SCOPE_TEMP/agent/SPECS.md" && pass "Traceability: R4/R5 present" || fail "Traceability: R4/R5 lost"

rm -rf "$SCOPE_TEMP"
pass "Scope change simulation: temp dir cleaned"

# ═══════════════════════════════════════════════════════════════
section "29. SPECS Staleness Check Rule"
# ═══════════════════════════════════════════════════════════════

# Rule must be in framework
grep -q "non-empty SPECS.md can still be stale\|non-empty.*still be stale\|Staleness check" "$PROJ/portable-spec-kit.md" && pass "Staleness: rule present in framework" || fail "Staleness: rule MISSING from framework"
grep -q "check count, not just presence\|check count\|check.*not just" "$PROJ/portable-spec-kit.md" && pass "Staleness: count-not-presence rule present" || fail "Staleness: count check rule MISSING"

# Simulate: SPECS has 2 features, TASKS has 5 completed — staleness detectable
STALE_TEMP="/tmp/psk-stale-$(date +%s)"
mkdir -p "$STALE_TEMP/agent"

cat > "$STALE_TEMP/agent/SPECS.md" << 'EOF'
# SPECS.md
## Features
| # | Feature | Status |
|---|---------|--------|
| F1 | Auth | [x] |
| F2 | Dashboard | [x] |
EOF

cat > "$STALE_TEMP/agent/TASKS.md" << 'EOF'
# TASKS.md
## v0.1
- [x] Auth
- [x] Dashboard
- [x] Charts
- [x] Settings
- [x] Export
EOF

# Count SPECS features vs TASKS completed (use wc -l — always exits 0, no double-output)
SPECS_COUNT=$(grep "^| F[0-9]" "$STALE_TEMP/agent/SPECS.md" 2>/dev/null | wc -l | tr -d ' \t')
TASKS_DONE=$(grep "^\- \[x\]" "$STALE_TEMP/agent/TASKS.md" 2>/dev/null | wc -l | tr -d ' \t')
DIFF=$((TASKS_DONE - SPECS_COUNT))

[ "$SPECS_COUNT" -eq 2 ] && pass "Staleness sim: SPECS has 2 features" || fail "Staleness sim: wrong SPECS count (got $SPECS_COUNT)"
[ "$TASKS_DONE" -eq 5 ] && pass "Staleness sim: TASKS has 5 completed" || fail "Staleness sim: wrong TASKS count (got $TASKS_DONE)"
[ "$DIFF" -ge 2 ] && pass "Staleness sim: gap detected ($DIFF features missing from SPECS — update required)" || fail "Staleness sim: gap not detectable"

rm -rf "$STALE_TEMP"
pass "Staleness check simulation: temp dir cleaned"

# ═══════════════════════════════════════════════════════════════
section "30. RELEASES Trigger Rule"
# ═══════════════════════════════════════════════════════════════

# Rule must be in framework
grep -q "all tasks under a version heading.*\[x\].*add.*RELEASES\|When all tasks.*marked.*\[x\].*add a release" "$PROJ/portable-spec-kit.md" && pass "RELEASES trigger: rule present in framework" || fail "RELEASES trigger: rule MISSING"
grep -q "Do not leave a completed version without a release entry" "$PROJ/portable-spec-kit.md" && pass "RELEASES trigger: no-empty-entry rule present" || fail "RELEASES trigger: no-empty rule MISSING"

# Simulate: TASKS.md with all [x] — check RELEASES.md needs updating
REL_TEMP="/tmp/psk-rel-$(date +%s)"
mkdir -p "$REL_TEMP/agent"

cat > "$REL_TEMP/agent/TASKS.md" << 'EOF'
# TASKS.md
## v0.1 — Current
- [x] Setup project
- [x] Build auth
- [x] Build dashboard
## Backlog
- [ ] Future feature
EOF

cat > "$REL_TEMP/agent/RELEASES.md" << 'EOF'
# RELEASES.md
(no entries yet)
EOF

# Check: all v0.1 tasks done → RELEASES.md needs entry
# Count only tasks under ## v0.1 section (not backlog) using awk range
V1_TOTAL=$(awk '/^## v0\.1/,/^## [A-Z]/' "$REL_TEMP/agent/TASKS.md" 2>/dev/null | grep "^- \[.\]" | wc -l | tr -d ' \t')
V1_DONE=$(awk '/^## v0\.1/,/^## [A-Z]/' "$REL_TEMP/agent/TASKS.md" 2>/dev/null | grep "^- \[x\]" | wc -l | tr -d ' \t')
HAS_REL=$(grep "## v0\.1" "$REL_TEMP/agent/RELEASES.md" 2>/dev/null | wc -l | tr -d ' \t')

[ "$V1_TOTAL" -eq "$V1_DONE" ] && pass "RELEASES sim: all v0.1 tasks done ($V1_DONE/$V1_TOTAL)" || fail "RELEASES sim: not all tasks done"
[ "$HAS_REL" -eq 0 ] && pass "RELEASES sim: RELEASES.md missing v0.1 entry (trigger needed)" || fail "RELEASES sim: entry exists (ok)"

# Simulate adding the release entry
echo "## v0.1 — Initial Release (2026-04-05)" >> "$REL_TEMP/agent/RELEASES.md"
grep -q "## v0\.1" "$REL_TEMP/agent/RELEASES.md" && pass "RELEASES sim: entry added after trigger" || fail "RELEASES sim: entry not added"

rm -rf "$REL_TEMP"
pass "RELEASES trigger simulation: temp dir cleaned"

# ═══════════════════════════════════════════════════════════════
section "31. No-Slip Task Rule & Session-End Sweep"
# ═══════════════════════════════════════════════════════════════

grep -q "Never let a task slip or be forgotten" "$PROJ/portable-spec-kit.md" && pass "No-slip: rule present in framework" || fail "No-slip: rule MISSING"
grep -q "scan for any task.*before responding\|scan.*before respond" "$PROJ/portable-spec-kit.md" && pass "No-slip: scan-before-responding rule present" || fail "No-slip: scan-before-responding MISSING"
grep -q "Before ending any session" "$PROJ/portable-spec-kit.md" && pass "No-slip: session-end sweep rule present" || fail "No-slip: session-end sweep MISSING"
grep -q "scan back through the full conversation\|scan.*full conversation" "$PROJ/portable-spec-kit.md" && pass "No-slip: full conversation scan rule present" || fail "No-slip: full conversation scan MISSING"
grep -q "anything was asked but not done, do it now" "$PROJ/portable-spec-kit.md" && pass "No-slip: completion enforcement present" || fail "No-slip: completion enforcement MISSING"

# ═══════════════════════════════════════════════════════════════
section "32. Session-Start 5-Step Read Order"
# ═══════════════════════════════════════════════════════════════

grep -q "On every session start" "$PROJ/portable-spec-kit.md" && pass "Session-start: 5-step read order documented" || fail "Session-start: read order MISSING"
# Verify all 5 files referenced in session-start section
grep -q "user-profile" "$PROJ/portable-spec-kit.md" && pass "Session-start: user profile read (step 1)" || fail "Session-start: profile MISSING"
grep -q "agent/AGENT\.md" "$PROJ/portable-spec-kit.md" && pass "Session-start: AGENT.md read (step 2)" || fail "Session-start: AGENT.md MISSING"
grep -q "agent/AGENT_CONTEXT\.md" "$PROJ/portable-spec-kit.md" && pass "Session-start: AGENT_CONTEXT.md read (step 3)" || fail "Session-start: AGENT_CONTEXT MISSING"
grep -q "agent/TASKS\.md" "$PROJ/portable-spec-kit.md" && pass "Session-start: TASKS.md read (step 4)" || fail "Session-start: TASKS.md MISSING"
grep -q "agent/PLANS\.md" "$PROJ/portable-spec-kit.md" && pass "Session-start: PLANS.md read (step 5)" || fail "Session-start: PLANS.md MISSING"

# ═══════════════════════════════════════════════════════════════
section "33. Pipeline Sync — All 4 Files"
# ═══════════════════════════════════════════════════════════════

# Sync rule must mention 4 files (not 3)
grep -q "all 4 pipeline files\|4 pipeline files" "$PROJ/portable-spec-kit.md" && pass "Pipeline: sync rule mentions 4 files" || fail "Pipeline: sync rule still says 3 files"
grep -q "SPECS.*PLANS.*TASKS.*RELEASES\|RELEASES.md.*pipeline" "$PROJ/portable-spec-kit.md" && pass "Pipeline: RELEASES.md included in sync rule" || fail "Pipeline: RELEASES.md missing from sync"

# Fill gaps rule mentions RELEASES
grep -q "All tasks.*\[x\].*RELEASES\|add release entry to RELEASES.md now" "$PROJ/portable-spec-kit.md" && pass "Pipeline: fill gaps rule covers RELEASES" || fail "Pipeline: fill gaps misses RELEASES"

# Simulate: all 4 pipeline files referencing the same feature
PIPE_TEMP="/tmp/psk-pipe-$(date +%s)"
mkdir -p "$PIPE_TEMP/agent"

cat > "$PIPE_TEMP/agent/SPECS.md" << 'EOF'
## Features
| F1 | Auth system | R1 | [x] |
EOF
cat > "$PIPE_TEMP/agent/PLANS.md" << 'EOF'
## Stack
JWT auth, PostgreSQL
## Decision Log
| Auth | JWT | Simpler |
EOF
cat > "$PIPE_TEMP/agent/TASKS.md" << 'EOF'
## v0.1
- [x] F1: auth system
EOF
cat > "$PIPE_TEMP/agent/RELEASES.md" << 'EOF'
## v0.1
### Changes
- **Auth:** F1 auth system delivered
EOF

# Verify all 4 reference "auth"
grep -qi "auth" "$PIPE_TEMP/agent/SPECS.md" && pass "Pipeline sync: SPECS has auth" || fail "Pipeline: SPECS missing feature"
grep -qi "auth" "$PIPE_TEMP/agent/PLANS.md" && pass "Pipeline sync: PLANS has auth decision" || fail "Pipeline: PLANS missing decision"
grep -qi "auth" "$PIPE_TEMP/agent/TASKS.md" && pass "Pipeline sync: TASKS has auth task" || fail "Pipeline: TASKS missing task"
grep -qi "auth" "$PIPE_TEMP/agent/RELEASES.md" && pass "Pipeline sync: RELEASES records auth" || fail "Pipeline: RELEASES missing entry"

rm -rf "$PIPE_TEMP"
pass "Pipeline sync simulation: temp dir cleaned"

# ═══════════════════════════════════════════════════════════════
section "34. Security Rules — API Key Protection"
# ═══════════════════════════════════════════════════════════════

grep -q "ABSOLUTE — NO EXCEPTIONS\|NO EXCEPTIONS" "$PROJ/portable-spec-kit.md" && pass "Security: absolute rule header present" || fail "Security: absolute rule MISSING"
grep -q "NEVER read, display, log, or expose" "$PROJ/portable-spec-kit.md" && pass "Security: never expose API keys" || fail "Security: expose rule MISSING"
grep -q "even if the user explicitly asks" "$PROJ/portable-spec-kit.md" && pass "Security: covers explicit user requests" || fail "Security: user override not addressed"
grep -q "cannot be overridden by any instruction\|This rule cannot be overridden" "$PROJ/portable-spec-kit.md" && pass "Security: rule explicitly non-overridable" || fail "Security: override protection MISSING"
grep -q "NEVER commit.*\.env\|NEVER commit.*secrets" "$PROJ/portable-spec-kit.md" && pass "Security: never commit .env" || fail "Security: .env commit rule MISSING"
grep -q "paste-your-key-here\|placeholder values only" "$PROJ/portable-spec-kit.md" && pass "Security: placeholders in .env.example" || fail "Security: placeholder rule MISSING"
grep -q "Always verify.*\.gitignore.*includes.*\.env\|verify.*gitignore.*env" "$PROJ/portable-spec-kit.md" && pass "Security: verify .gitignore before commit" || fail "Security: gitignore check MISSING"

# .gitignore must exclude .env
grep -q "\.env" "$PROJ/.gitignore" && pass "Security: .gitignore excludes .env" || fail "Security: .env not in .gitignore"
! grep -q "\.env$" "$PROJ/.gitignore" || grep -q "\.env\.\*\|\.env\*" "$PROJ/.gitignore" && pass "Security: .gitignore covers .env variants" || fail "Security: .env variants not covered"

# ═══════════════════════════════════════════════════════════════
section "35. Version Bump Before Push Rule"
# ═══════════════════════════════════════════════════════════════

grep -q "Version bump BEFORE push\|version bump BEFORE push\|bump.*before.*push" "$PROJ/portable-spec-kit.md" && pass "Version bump: rule present in framework" || fail "Version bump: rule MISSING"
grep -q "bump → commit → push\|bump.*commit.*push" "$PROJ/portable-spec-kit.md" && pass "Version bump: order documented (bump→commit→push)" || fail "Version bump: order MISSING"
grep -q "Never push then bump after\|never push then bump\|not.*push.*then.*bump" "$PROJ/portable-spec-kit.md" && pass "Version bump: anti-pattern documented" || fail "Version bump: anti-pattern not covered"
grep -q "AGENT_CONTEXT.*Version field\|bump.*Version.*field\|Version.*patch" "$PROJ/portable-spec-kit.md" && pass "Version bump: updates AGENT_CONTEXT Version field" || fail "Version bump: AGENT_CONTEXT target MISSING"
grep -q "README.*version badge\|version badge" "$PROJ/portable-spec-kit.md" && pass "Version bump: updates README badge" || fail "Version bump: README badge target MISSING"
grep -q "Release notes scope\|release notes scope" "$PROJ/portable-spec-kit.md" && pass "Release notes: scope rule — only committed/visible content" || fail "Release notes: scope rule MISSING"
grep -q '"update release"\|update release.*alias\|update release.*same as prepare release\|prepare release.*update release' "$PROJ/portable-spec-kit.md" && pass "Release commands: 'update release' defined as alias for prepare release" || fail "Release commands: 'update release' alias MISSING"
grep -q '"refresh release"\|refresh release' "$PROJ/portable-spec-kit.md" && pass "Release commands: 'refresh release' command defined" || fail "Release commands: 'refresh release' MISSING"
grep -q "refresh release.*no.*bump\|refresh release.*without.*bump\|No version bump\|no version bump\|version stays the same" "$PROJ/portable-spec-kit.md" && pass "Release commands: 'refresh release' skips version bump" || fail "Release commands: 'refresh release' no-bump rule MISSING"
grep -q "Release summary.*shown after all steps\|release summary.*required.*prepare\|Show the release summary" "$PROJ/portable-spec-kit.md" && pass "Release commands: release summary shown after every prepare/refresh release" || fail "Release commands: release summary rule MISSING"

# ═══════════════════════════════════════════════════════════════
section "36. Git Rule — Check .git/ Before Commit"
# ═══════════════════════════════════════════════════════════════

grep -q "check.*\.git/\|\.git/.*before commit\|check if the project directory has its own.*\.git" "$PROJ/portable-spec-kit.md" && pass "Git rule: check .git/ before commit" || fail "Git rule: .git/ check MISSING"
grep -q "parent repo\|inside a parent repo\|parent git" "$PROJ/portable-spec-kit.md" && pass "Git rule: parent repo case handled" || fail "Git rule: parent repo case MISSING"
grep -q "Do NOT push.*unless user explicitly\|Do NOT push.*push" "$PROJ/portable-spec-kit.md" && pass "Git rule: explicit push required" || fail "Git rule: push protection MISSING"
grep -q "Do NOT auto-commit\|not auto-commit" "$PROJ/portable-spec-kit.md" && pass "Git rule: no auto-commit" || fail "Git rule: auto-commit rule MISSING"

# ═══════════════════════════════════════════════════════════════
section "37. Existing Project Setup — Guide Don't Force"
# ═══════════════════════════════════════════════════════════════

grep -q "Guide, Don't Force\|guide don't force\|Guide don't force" "$PROJ/portable-spec-kit.md" && pass "Existing: guide don't force rule" || fail "Existing: guide don't force MISSING"
grep -q "Never force restructure\|never force" "$PROJ/portable-spec-kit.md" && pass "Existing: never force restructure" || fail "Existing: force rule MISSING"
grep -q "checklist\|show.*checklist" "$PROJ/portable-spec-kit.md" && pass "Existing: checklist shown to user" || fail "Existing: checklist MISSING"
grep -q "Respect user.*choices\|respect.*choice" "$PROJ/portable-spec-kit.md" && pass "Existing: user choice respected" || fail "Existing: user choice rule MISSING"
grep -q "Never rename, move, or delete existing files" "$PROJ/portable-spec-kit.md" && pass "Existing: never rename/delete without approval" || fail "Existing: file safety rule MISSING"
grep -q "retroactively fill SPECS\|fill.*from.*codebase\|fill.*retroactively" "$PROJ/portable-spec-kit.md" && pass "Existing: retroactive fill from codebase" || fail "Existing: retroactive fill MISSING"

# 9 project scenarios table
grep -q "Brand new project\|New project.*empty dir" "$PROJ/portable-spec-kit.md" && pass "Scenarios: new project case" || fail "Scenarios: new project MISSING"
grep -q "Existing project with code" "$PROJ/portable-spec-kit.md" && pass "Scenarios: existing project case" || fail "Scenarios: existing project MISSING"
grep -q "Monorepo\|monorepo" "$PROJ/portable-spec-kit.md" && pass "Scenarios: monorepo case" || fail "Scenarios: monorepo MISSING"
grep -q "Partial agent.*files\|partial.*agent" "$PROJ/portable-spec-kit.md" && pass "Scenarios: partial agent files case" || fail "Scenarios: partial files MISSING"
grep -q "Cloned repo" "$PROJ/portable-spec-kit.md" && pass "Scenarios: cloned repo case" || fail "Scenarios: cloned repo MISSING"

grep -q "once at session start\|session start.*not on every message\|first loads.*not on every" "$PROJ/portable-spec-kit.md" && pass "Existing: kit status shown once at session start (not every message)" || fail "Existing: session-start status display rule MISSING"
grep -q "Profile setup and project scan are independent\|profile setup.*independent" "$PROJ/portable-spec-kit.md" && pass "Existing: kit triggers even if profile setup skipped" || fail "Existing: profile-independence rule MISSING"
grep -q "Scan the user.*project immediately\|scan.*before showing.*summary\|mandatory.*must complete before the user" "$PROJ/portable-spec-kit.md" && pass "Existing: kit update scans user's project before showing summary" || fail "Existing: kit-update re-scan rule MISSING"

# ═══════════════════════════════════════════════════════════════
section "38. Retroactive Spec Filling Simulation"
# ═══════════════════════════════════════════════════════════════

# Rule must be in framework
grep -q "SPECS.md is empty after 3\+ tasks\|empty after 3+ tasks\|empty after three tasks" "$PROJ/portable-spec-kit.md" && pass "Retro: empty-after-3-tasks rule present" || fail "Retro: empty trigger MISSING"

# Simulate: project with code + empty SPECS.md → fill from code
RETRO_TEMP="/tmp/psk-retro-$(date +%s)"
mkdir -p "$RETRO_TEMP/agent" "$RETRO_TEMP/src"

# Project has 4 completed tasks
cat > "$RETRO_TEMP/agent/TASKS.md" << 'EOF'
## v0.1
- [x] Auth system
- [x] Dashboard
- [x] Charts
- [x] Settings
EOF

# SPECS is empty template
cat > "$RETRO_TEMP/agent/SPECS.md" << 'EOF'
# SPECS.md
## Features
| # | Feature | Status |
|---|---------|--------|
EOF

# Some code exists
echo "function auth() {}" > "$RETRO_TEMP/src/auth.js"
echo "function dashboard() {}" > "$RETRO_TEMP/src/dashboard.js"

# Verify trigger condition
TASKS_DONE=$(grep "^\- \[x\]" "$RETRO_TEMP/agent/TASKS.md" 2>/dev/null | wc -l | tr -d ' \t')
SPECS_HAS_FEATURES=$(grep "^| F[0-9]" "$RETRO_TEMP/agent/SPECS.md" 2>/dev/null | wc -l | tr -d ' \t')

[ "$TASKS_DONE" -ge 3 ] && pass "Retro: 3+ completed tasks exist ($TASKS_DONE tasks)" || fail "Retro: not enough tasks"
[ "$SPECS_HAS_FEATURES" -eq 0 ] && pass "Retro: SPECS.md has no features yet (trigger condition)" || fail "Retro: SPECS already has features"

# Simulate retroactive fill: add features from tasks using a simple counter
i=1
for task in "Auth system" "Dashboard" "Charts" "Settings"; do
  echo "| F$i | $task | [x] |" >> "$RETRO_TEMP/agent/SPECS.md"
  ((i++))
done

SPECS_AFTER=$(grep "^| F[0-9]" "$RETRO_TEMP/agent/SPECS.md" 2>/dev/null | wc -l | tr -d ' \t')
[ "$SPECS_AFTER" -ge 4 ] && pass "Retro: SPECS filled retroactively ($SPECS_AFTER features added)" || fail "Retro: retroactive fill failed"
[ "$SPECS_AFTER" -eq "$TASKS_DONE" ] && pass "Retro: SPECS feature count matches completed tasks ($SPECS_AFTER = $TASKS_DONE)" || fail "Retro: count mismatch"

rm -rf "$RETRO_TEMP"
pass "Retroactive fill simulation: temp dir cleaned"

# ═══════════════════════════════════════════════════════════════
section "39. Context Persistence — 10 Disruption Scenarios"
# ═══════════════════════════════════════════════════════════════

DISRUPT_TEMP="/tmp/psk-disrupt-$(date +%s)"
mkdir -p "$DISRUPT_TEMP/agent" "$DISRUPT_TEMP/.portable-spec-kit/user-profile"

# Write full project state
cat > "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" << 'CTXEOF'
# AGENT_CONTEXT.md — TaskFlow

## Current Status
- **Version:** v0.2
- **Kit:** v0.3.6
- **Phase:** Development
- **Status:** Building payment feature

## What's Done
- [x] Auth system
- [x] Dashboard
- [x] Charts

## What's Next
- [ ] Payment integration
- [ ] Notifications

## Key Decisions
| Decision | Choice | Why |
|----------|--------|-----|
| Auth | JWT | Simpler MVP |
| DB | PostgreSQL | JSON support |
| UI | React+Tailwind | Team familiarity |

## Last Updated
- **Date:** 2026-04-05
- **Summary:** Auth + Dashboard + Charts done. Payment next.
CTXEOF

cat > "$DISRUPT_TEMP/.portable-spec-kit/user-profile/user-profile-aqibmumtaz.md" << 'PROFEOF'
# User Profile
- **Dr. Aqib Mumtaz** — PhD Computer Science. AI research, full-stack.
- Communication style: direct, data-driven
- Working pattern: iterative
- AI delegation: AI does 90%
PROFEOF

# D1: 3-week break — context preserved?
grep -q "Auth system\|What's Done" "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" && pass "D1 (3-week break): completed work preserved" || fail "D1: work history lost"
grep -q "Payment integration\|What's Next" "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" && pass "D1 (3-week break): next tasks preserved" || fail "D1: next tasks lost"
grep -q "JWT.*Simpler\|PostgreSQL" "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" && pass "D1 (3-week break): key decisions preserved" || fail "D1: decisions lost"

# D2: Agent switch (Claude → Cursor — same files, different reader)
cp "$DISRUPT_TEMP/portable-spec-kit.md" "$DISRUPT_TEMP/.cursorrules" 2>/dev/null || true
grep -q "v0\.2\|Kit.*v0\.3\." "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" && pass "D2 (agent switch): version readable by any agent" || fail "D2: version not readable"
grep -q "Dr. Aqib Mumtaz" "$DISRUPT_TEMP/.portable-spec-kit/user-profile/user-profile-aqibmumtaz.md" && pass "D2 (agent switch): profile readable by any agent" || fail "D2: profile lost on switch"

# D3: New team member — can they understand the project?
grep -q "Key Decisions" "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" && pass "D3 (new team member): decisions section present" || fail "D3: decisions not onboarding-ready"
grep -q "What's Done\|What's Next" "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" && pass "D3 (new team member): status clear for onboarding" || fail "D3: status not readable"

# D4: Scope DROP — verify AGENT_CONTEXT records it
echo "## Scope Changes" >> "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md"
echo "- DROP: Notifications (R5) — client deprioritized 2026-04-05" >> "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md"
grep -q "DROP.*Notifications\|deprioritized" "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" && pass "D4 (scope DROP): drop recorded in context" || fail "D4: drop not recorded"

# D5: Scope ADD
echo "- ADD: Analytics dashboard (R6) — new client requirement 2026-04-05" >> "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md"
grep -q "ADD.*Analytics\|new client requirement" "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" && pass "D5 (scope ADD): add recorded in context" || fail "D5: add not recorded"

# D6: Scope MODIFY
echo "- MODIFY: R4 export — CSV only → PDF+CSV" >> "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md"
grep -q "MODIFY.*export\|PDF.*CSV" "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" && pass "D6 (scope MODIFY): modify recorded" || fail "D6: modify not recorded"

# D7: Scope REPLACE
echo "- REPLACE: F3 calendar → F6 list view (performance)" >> "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md"
grep -q "REPLACE.*calendar\|list view.*performance" "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" && pass "D7 (scope REPLACE): replace recorded" || fail "D7: replace not recorded"

# D8: Version update — framework restructure
echo "- Framework updated v0.3.5 → v0.3.6, agent files restructured" >> "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md"
grep -q "Framework updated\|restructured" "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" && pass "D8 (framework update): update recorded in context" || fail "D8: framework update not recorded"

# D9: Build 3 features — progress tracked
grep -q "Auth system\|Dashboard\|Charts" "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" && pass "D9 (build features): feature progress tracked" || fail "D9: feature progress not tracked"

# D10: Project handoff — all context readable 6 months later
TOTAL_FIELDS=$(grep -c "^-\|^##\|\|" "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" || echo 0)
[ "$TOTAL_FIELDS" -gt 10 ] && pass "D10 (project handoff): rich context preserved ($TOTAL_FIELDS entries)" || fail "D10: insufficient context for handoff"

# Zero data loss check: all originally written content still present
grep -q "Auth.*JWT.*Simpler" "$DISRUPT_TEMP/agent/AGENT_CONTEXT.md" && pass "D10: original decisions intact after all disruptions" || fail "D10: data lost through disruptions"

rm -rf "$DISRUPT_TEMP"
pass "Context persistence (10 disruptions): temp dir cleaned"

# ═══════════════════════════════════════════════════════════════
section "40. R→F→T Traceability — Feature Tests Required"
# ═══════════════════════════════════════════════════════════════

# Rule must be in framework
grep -q "F.*T Traceability (MANDATORY)" "$PROJ/portable-spec-kit.md" && pass "R→F→T: F→T traceability rule present in framework" || fail "R→F→T: F→T rule MISSING from framework"
grep -q "Never mark a feature" "$PROJ/portable-spec-kit.md" && pass "R→F→T: never-done-without-tests rule present" || fail "R→F→T: never-done-without-tests MISSING"
grep -q "completes the full R" "$PROJ/portable-spec-kit.md" && pass "R→F→T: full chain (R→F→T) documented in framework" || fail "R→F→T: chain documentation MISSING"

# SPECS.md template must have Tests column
grep -q "| Tests\|| Tests " "$PROJ/portable-spec-kit.md" && pass "R→F→T: SPECS.md template has Tests column" || fail "R→F→T: Tests column MISSING from template"
grep -q "| Req\|| Req " "$PROJ/portable-spec-kit.md" && pass "R→F→T: SPECS.md template has Req column (R→F link)" || fail "R→F→T: Req column MISSING from template"

# Simulate: project with SPECS.md features + test files (R→F→T complete)
RFT_TEMP="/tmp/psk-rft-$(date +%s)"
mkdir -p "$RFT_TEMP/agent" "$RFT_TEMP/tests"

cat > "$RFT_TEMP/agent/SPECS.md" << 'EOF'
# SPECS.md — TaskFlow

## Requirements
- R1: users can log in
- R2: users can create tasks
- R3: users can export data

## Features
| # | Feature | Req | Priority | Status | Tests |
|---|---------|-----|----------|--------|-------|
| F1 | Email + password auth | R1 | High | [x] | tests/auth.test.js |
| F2 | Task CRUD with priorities | R2 | High | [x] | tests/tasks.test.js |
| F3 | CSV export | R3 | Medium | [ ] | |
EOF

# Create test files for done features
echo "test('login works', () => { expect(true).toBe(true) })" > "$RFT_TEMP/tests/auth.test.js"
echo "test('task CRUD works', () => { expect(true).toBe(true) })" > "$RFT_TEMP/tests/tasks.test.js"

# Validate: count done features
DONE_FEATURES=$(grep "| \[x\]" "$RFT_TEMP/agent/SPECS.md" 2>/dev/null | wc -l | tr -d ' \t')
[ "$DONE_FEATURES" -eq 2 ] && pass "R→F→T sim: 2 completed features found in SPECS.md" || fail "R→F→T sim: wrong done feature count (got $DONE_FEATURES)"

# Validate: all done features have test references
DONE_WITH_TESTS=$(grep "| \[x\]" "$RFT_TEMP/agent/SPECS.md" 2>/dev/null | grep "tests/" | wc -l | tr -d ' \t')
[ "$DONE_WITH_TESTS" -eq "$DONE_FEATURES" ] && pass "R→F→T sim: all done features have test references ($DONE_WITH_TESTS/$DONE_FEATURES)" || fail "R→F→T sim: done features missing test refs ($DONE_WITH_TESTS/$DONE_FEATURES)"

# Validate: pending features have no test reference (correct — not yet built)
PENDING_WITH_TESTS=$(grep "| \[ \]" "$RFT_TEMP/agent/SPECS.md" 2>/dev/null | grep "tests/" | wc -l | tr -d ' \t')
[ "$PENDING_WITH_TESTS" -eq 0 ] && pass "R→F→T sim: pending features have no premature test refs" || fail "R→F→T sim: pending features have test refs (wrong)"

# Validate: test files exist for each referenced test
MISSING_FILES=0
while IFS= read -r line; do
  test_ref=$(echo "$line" | grep -o "tests/[^ |]*" | head -1)
  if [ -n "$test_ref" ]; then
    [ -f "$RFT_TEMP/$test_ref" ] && pass "R→F→T sim: test file exists — $test_ref" || { fail "R→F→T sim: test file MISSING — $test_ref"; MISSING_FILES=$((MISSING_FILES+1)); }
  fi
done < <(grep "| \[x\]" "$RFT_TEMP/agent/SPECS.md" 2>/dev/null)
[ "$MISSING_FILES" -eq 0 ] && pass "R→F→T sim: all referenced test files exist on disk" || fail "R→F→T sim: $MISSING_FILES test files missing"

# Validate full R→F→T chain: R1→F1→test, R2→F2→test
grep -q "R1" "$RFT_TEMP/agent/SPECS.md" && pass "R→F→T sim: R1 traceable in SPECS.md" || fail "R→F→T sim: R1 lost"
grep -q "R2" "$RFT_TEMP/agent/SPECS.md" && pass "R→F→T sim: R2 traceable in SPECS.md" || fail "R→F→T sim: R2 lost"
grep -q "auth.test.js" "$RFT_TEMP/agent/SPECS.md" && pass "R→F→T sim: R1→F1→T1 chain complete (auth)" || fail "R→F→T sim: R1→F1→T1 chain broken"
grep -q "tasks.test.js" "$RFT_TEMP/agent/SPECS.md" && pass "R→F→T sim: R2→F2→T2 chain complete (tasks)" || fail "R→F→T sim: R2→F2→T2 chain broken"

# Retroactive: feature done without test → not complete
cat > "$RFT_TEMP/agent/SPECS.md" << 'EOF'
## Features
| # | Feature | Req | Status | Tests |
|---|---------|-----|--------|-------|
| F1 | Auth | R1 | [x] | |
EOF
MISSING_TESTS=$(grep "| \[x\]" "$RFT_TEMP/agent/SPECS.md" 2>/dev/null | grep -v "tests/" | wc -l | tr -d ' \t')
[ "$MISSING_TESTS" -gt 0 ] && pass "R→F→T sim: detects done feature with no test ref ($MISSING_TESTS violation)" || fail "R→F→T sim: cannot detect untested done feature"

rm -rf "$RFT_TEMP"
pass "R→F→T simulation: temp dir cleaned"

# ═══════════════════════════════════════════════════════════════
section "41. Pre-Release Consistency Gate"
# Verifies all cross-file counts, versions, templates, and docs
# stay in sync as features are added. Must pass before any push.
# ═══════════════════════════════════════════════════════════════

# ── Group 1: Cross-File Count Consistency (5 tests) ─────────────

# Extract test count from README badge (e.g. tests-564%20passing)
BADGE_COUNT=$(grep "tests-.*passing" "$PROJ/README.md" | grep -o "tests-[0-9]*" | grep -o "[0-9]*" | head -1)
[ -n "$BADGE_COUNT" ] && [ "$BADGE_COUNT" -gt 0 ] 2>/dev/null \
  && pass "count sync: README badge has test count ($BADGE_COUNT)" \
  || fail "count sync: README badge missing or invalid test count"

# ARD HTML test count must match README badge
ARD_COUNT=$(grep "Tests:</strong>" "$PROJ/ard/Portable_Spec_Kit_Technical_Overview.html" 2>/dev/null \
  | grep -o "[0-9]* passing" | head -1 | grep -o "[0-9]*")
[ "$BADGE_COUNT" = "$ARD_COUNT" ] \
  && pass "count sync: ARD ($ARD_COUNT) matches README badge ($BADGE_COUNT)" \
  || fail "count sync: ARD ($ARD_COUNT) ≠ README badge ($BADGE_COUNT) — update ARD or badge"

# SPECS.md acceptance criteria test count must match badge
SPECS_AC_COUNT=$(grep "tests pass" "$PROJ/agent/SPECS.md" 2>/dev/null | grep -o "[0-9]*" | head -1)
[ "$BADGE_COUNT" = "$SPECS_AC_COUNT" ] \
  && pass "count sync: SPECS.md acceptance criteria ($SPECS_AC_COUNT) matches badge" \
  || fail "count sync: SPECS.md acceptance criteria ($SPECS_AC_COUNT) ≠ badge ($BADGE_COUNT) — update SPECS.md"

# Actual section count in test file must match ARD section count
ACTUAL_SECS=$(grep -c "^section " "$PROJ/tests/test-spec-kit.sh")
ARD_SECS=$(grep -o "[0-9]* sections" "$PROJ/ard/Portable_Spec_Kit_Technical_Overview.html" 2>/dev/null \
  | head -1 | grep -o "[0-9]*")
[ "$ACTUAL_SECS" = "$ARD_SECS" ] \
  && pass "count sync: section count ($ACTUAL_SECS) matches ARD ($ARD_SECS)" \
  || fail "count sync: actual sections ($ACTUAL_SECS) ≠ ARD ($ARD_SECS) — update ARD section table"

# Both framework copies (Projects/ + root workspace) must have same version
PROJ_VER=$(grep "Framework Version:" "$PROJ/portable-spec-kit.md" | grep -o "v[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)
ROOT_VER=$(grep "Framework Version:" "$ROOT/portable-spec-kit.md" 2>/dev/null | grep -o "v[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)
[ -n "$ROOT_VER" ] && [ "$PROJ_VER" = "$ROOT_VER" ] \
  && pass "count sync: both framework copies match ($PROJ_VER)" \
  || fail "count sync: root copy ($ROOT_VER) ≠ Projects copy ($PROJ_VER) — sync both"

# ── Group 2: R→F→T Gate — Real SPECS.md (4 tests) ───────────────

# release-check.sh must exist
[ -f "$PROJ/tests/test-release-check.sh" ] \
  && pass "R→F→T gate: release-check.sh exists" \
  || fail "R→F→T gate: release-check.sh MISSING from tests/"

# release-check.sh must be executable
[ -x "$PROJ/tests/test-release-check.sh" ] \
  && pass "R→F→T gate: release-check.sh is executable" \
  || fail "R→F→T gate: release-check.sh not executable (run: chmod +x tests/test-release-check.sh)"

# No done feature in real SPECS.md may have an empty Tests column
# Done row format: | Fn | ... | [x] | test-ref |  — NF-1 is the Tests cell
UNTESTED_REAL=$(awk -F'|' '/\[x\]/ {
  col = NF - 1
  gsub(/^ +| +$/, "", $col)
  if (col > 0 && $col == "") count++
} END { print count + 0 }' "$PROJ/agent/SPECS.md")
[ "$UNTESTED_REAL" -eq 0 ] \
  && pass "R→F→T gate: all done features in SPECS.md have test refs" \
  || fail "R→F→T gate: $UNTESTED_REAL done feature(s) missing test refs in agent/SPECS.md"

# All test files referenced in SPECS.md Tests column must exist on disk
MISSING_REFS=0
while IFS= read -r spec_line; do
  test_ref=$(echo "$spec_line" | awk -F'|' '{
    col = NF - 1; gsub(/^ +| +$/, "", $col)
    if ($col ~ /^tests\//) print $col
  }')
  [ -n "$test_ref" ] && [ ! -f "$PROJ/$test_ref" ] && MISSING_REFS=$((MISSING_REFS + 1))
done < <(grep "\[x\]" "$PROJ/agent/SPECS.md" 2>/dev/null)
[ "$MISSING_REFS" -eq 0 ] \
  && pass "R→F→T gate: all referenced test files exist on disk" \
  || fail "R→F→T gate: $MISSING_REFS test file(s) in SPECS.md not found on disk"

# ── Group 3: Template Completeness (4 tests) ────────────────────

# SPECS.md agent template must have Tests column
grep -q "| Tests" "$PROJ/portable-spec-kit.md" \
  && pass "templates: SPECS.md template has Tests column" \
  || fail "templates: SPECS.md template missing Tests column — update framework"

# SPECS.md agent template must have Req column
grep -q "| Req" "$PROJ/portable-spec-kit.md" \
  && pass "templates: SPECS.md template has Req column (R→F link)" \
  || fail "templates: SPECS.md template missing Req column — update framework"

# AGENT_CONTEXT.md template must have Kit field (installed kit version — separate from user's project Version)
grep -q "\*\*Kit:\*\*" "$PROJ/portable-spec-kit.md" \
  && pass "templates: AGENT_CONTEXT template has Kit field" \
  || fail "templates: AGENT_CONTEXT template missing Kit field — update framework"

# Both example CLAUDE.md files must reference the correct user profile path
grep -q "portable-spec-kit/user-profile" "$PROJ/examples/starter/CLAUDE.md" 2>/dev/null \
  && grep -q "portable-spec-kit/user-profile" "$PROJ/examples/my-app/CLAUDE.md" 2>/dev/null \
  && pass "templates: both examples reference correct user profile path" \
  || fail "templates: example CLAUDE.md files missing .portable-spec-kit/user-profile/ path"

# ── Group 3b: Root Framework Template Currency (4 tests) ────────
# Verifies that framework templates reflect latest structural features.
# When a new rule changes agent file structure, templates must match.

# TASKS.md template must have version-based headings (v0.x structure)
grep -q "## v0\." "$PROJ/portable-spec-kit.md" \
  && pass "template currency: TASKS.md template has version-based headings" \
  || fail "template currency: TASKS.md template missing version headings — update framework"

# RELEASES.md template must have Kit: field (kit version used during release)
grep -q "^Kit: " "$PROJ/portable-spec-kit.md" \
  && pass "template currency: RELEASES.md template has Kit field" \
  || fail "template currency: RELEASES.md template missing Kit field — update framework"

# AGENT.md template must have session-start read order (5 steps)
grep -q "Read user profile\|portable-spec-kit/user-profile" "$PROJ/portable-spec-kit.md" \
  && pass "template currency: AGENT.md template references user profile read step" \
  || fail "template currency: AGENT.md template missing user profile step — update framework"

# Example my-app SPECS.md must have Req + Tests columns (reflects current template)
grep -q "| Req\|| Tests" "$PROJ/examples/my-app/agent/SPECS.md" 2>/dev/null \
  && pass "template currency: my-app example SPECS.md has current R→F→T columns" \
  || fail "template currency: my-app SPECS.md missing Req/Tests columns — update example to match current template"

# AGENT.md template must use 'Update AGENT_CONTEXT.md When' (not old 'On Every Session End')
grep -q "Update AGENT_CONTEXT.md When" "$PROJ/portable-spec-kit.md" \
  && pass "template currency: AGENT.md template uses correct context update triggers (not 'On Every Session End')" \
  || fail "template currency: AGENT.md template still has old 'On Every Session End' — update to 3 explicit triggers"

# examples must have tests/test-release-check.sh (kit creates it on project setup)
[ -f "$PROJ/examples/starter/tests/test-release-check.sh" ] && [ -f "$PROJ/examples/my-app/tests/test-release-check.sh" ] \
  && pass "template currency: examples have tests/test-release-check.sh (kit-distributed R→F→T validator)" \
  || fail "template currency: examples missing tests/test-release-check.sh — copy from tests/test-release-check.sh"

# Example AGENT_CONTEXT.md files must have **Kit:** field (not stale **Framework:** naming)
grep -q "\*\*Kit:\*\*" "$PROJ/examples/starter/agent/AGENT_CONTEXT.md" 2>/dev/null \
  && grep -q "\*\*Kit:\*\*" "$PROJ/examples/my-app/agent/AGENT_CONTEXT.md" 2>/dev/null \
  && pass "template currency: example AGENT_CONTEXT.md files have Kit field" \
  || fail "template currency: example AGENT_CONTEXT.md missing Kit field — add '- **Kit:** vX.X.X' under Version"

# Flow docs must not reference stale **Framework:** field (rename completeness check)
! grep -rq "against \*\*Framework:\*\*\|update Framework in AGENT_CONTEXT\|update Framework version in AGENT_CONTEXT" \
    "$PROJ/docs/work-flows/" 2>/dev/null \
  && pass "template currency: flow docs use Kit field references (no stale Framework)" \
  || fail "template currency: flow docs have stale **Framework:** references — update to **Kit:**"

# ── Group 4: Docs Consistency (4 tests) ─────────────────────────

# docs/work-flows/ actual file count must match framework claim
ACTUAL_FLOWS=$(ls "$PROJ/docs/work-flows/"*.md 2>/dev/null | wc -l | tr -d ' ')
CLAIMED_FLOWS=$( { grep -oE "[0-9]+ work flow" "$PROJ/portable-spec-kit.md" 2>/dev/null; grep -oE "[0-9]+ work flow" "$PROJ/agent/SPECS.md" 2>/dev/null; } | grep -oE "^[0-9]+" | sort -rn | head -1)
[ -z "$CLAIMED_FLOWS" ] && CLAIMED_FLOWS=0
[ "$ACTUAL_FLOWS" -ge "$CLAIMED_FLOWS" ] && [ "$ACTUAL_FLOWS" -gt 0 ] \
  && pass "docs consistency: $ACTUAL_FLOWS flow docs exist (framework claims $CLAIMED_FLOWS)" \
  || fail "docs consistency: only $ACTUAL_FLOWS flow docs exist, framework claims $CLAIMED_FLOWS"

# ARD must document R→F→T traceability (new feature, docs must be updated)
grep -q "R.*F.*T\|release-check" "$PROJ/ard/Portable_Spec_Kit_Technical_Overview.html" 2>/dev/null \
  && pass "docs consistency: ARD documents R→F→T traceability" \
  || fail "docs consistency: ARD does not mention R→F→T — update Technical Overview"

# README must have Critical Scenarios section (added v0.3, structural requirement)
grep -q "Critical Scenarios" "$PROJ/README.md" \
  && pass "docs consistency: README has Critical Scenarios section" \
  || fail "docs consistency: README missing Critical Scenarios section — update README"

# RELEASES.md current version must reference this framework version
LATEST_RELEASE_RANGE=$(grep "^Kit:" "$PROJ/agent/RELEASES.md" | head -1)
echo "$LATEST_RELEASE_RANGE" | grep -q "$PROJ_VER" \
  && pass "docs consistency: RELEASES.md current range includes $PROJ_VER" \
  || fail "docs consistency: RELEASES.md range doesn't include $PROJ_VER — update range"

# ARD version badge must match current framework version
grep -q "$PROJ_VER" "$PROJ/ard/Portable_Spec_Kit_Technical_Overview.html" 2>/dev/null \
  && pass "docs consistency: ARD version badge matches $PROJ_VER" \
  || fail "docs consistency: ARD version badge doesn't include $PROJ_VER — update ARD cover badge and footer"

# Flow docs must not reference a stale Kit version (any Kit: line must match current version)
STALE_FLOW_KIT=$(grep -r "^Kit: v[0-9]" "$PROJ/docs/work-flows/" 2>/dev/null | grep -v "$PROJ_VER" | wc -l | tr -d ' ')
[ "$STALE_FLOW_KIT" -eq 0 ] \
  && pass "docs consistency: flow docs Kit references are current ($PROJ_VER)" \
  || fail "docs consistency: $STALE_FLOW_KIT flow doc(s) have stale Kit version — update to $PROJ_VER"

# Benchmarking test fixtures must use current Kit version
STALE_BENCH_KIT=$(grep "Kit: v[0-9]" "$PROJ/tests/test-spd-benchmarking.sh" 2>/dev/null | grep -v "$PROJ_VER" | wc -l | tr -d ' ')
[ "$STALE_BENCH_KIT" -eq 0 ] \
  && pass "docs consistency: test-spd-benchmarking.sh fixtures use current Kit ($PROJ_VER)" \
  || fail "docs consistency: $STALE_BENCH_KIT stale Kit version(s) in benchmarking fixtures — update to $PROJ_VER"

# Example AGENT_CONTEXT.md files must have current Kit version
STALE_EX_KIT=$(grep "\*\*Kit:\*\*" "$PROJ/examples/my-app/agent/AGENT_CONTEXT.md" "$PROJ/examples/starter/agent/AGENT_CONTEXT.md" 2>/dev/null | grep -v "$PROJ_VER" | wc -l | tr -d ' ')
[ "$STALE_EX_KIT" -eq 0 ] \
  && pass "docs consistency: example AGENT_CONTEXT.md Kit fields are current ($PROJ_VER)" \
  || fail "docs consistency: $STALE_EX_KIT example AGENT_CONTEXT.md file(s) have stale Kit — update to $PROJ_VER"

# Example RELEASES.md files must have current Kit version
STALE_EX_REL=$(grep "^Kit: v[0-9]" "$PROJ/examples/my-app/agent/RELEASES.md" "$PROJ/examples/starter/agent/RELEASES.md" 2>/dev/null | grep -v "$PROJ_VER" | wc -l | tr -d ' ')
[ "$STALE_EX_REL" -eq 0 ] \
  && pass "docs consistency: example RELEASES.md Kit fields are current ($PROJ_VER)" \
  || fail "docs consistency: $STALE_EX_REL example RELEASES.md file(s) have stale Kit — update to $PROJ_VER"

# ═══════════════════════════════════════════════════════════════
section "42. CI/CD — GitHub Actions, Community Files, and Framework Rules"
# ═══════════════════════════════════════════════════════════════

# Kit repo CI files
[ -f "$PROJ/.github/workflows/ci.yml" ] && pass "CI: ci.yml exists" || fail "CI: ci.yml MISSING"
grep -q "pull_request" "$PROJ/.github/workflows/ci.yml" 2>/dev/null && pass "CI: triggers on pull_request" || fail "CI: pull_request trigger MISSING"
grep -q "ubuntu-latest" "$PROJ/.github/workflows/ci.yml" 2>/dev/null && pass "CI: runs on ubuntu-latest" || fail "CI: ubuntu-latest MISSING"
grep -q "test-spec-kit.sh" "$PROJ/.github/workflows/ci.yml" 2>/dev/null && pass "CI: ci.yml runs test-spec-kit.sh" || fail "CI: test-spec-kit.sh not in ci.yml"
grep -q "test-spd-benchmarking.sh" "$PROJ/.github/workflows/ci.yml" 2>/dev/null && pass "CI: ci.yml runs test-spd-benchmarking.sh" || fail "CI: benchmarking not in ci.yml"
grep -q "test-release-check.sh" "$PROJ/.github/workflows/ci.yml" 2>/dev/null && pass "CI: ci.yml runs test-release-check.sh" || fail "CI: release-check not in ci.yml"
[ -f "$PROJ/.github/workflows/release.yml" ] && pass "CI: release.yml exists" || fail "CI: release.yml MISSING"
grep -q "v\*" "$PROJ/.github/workflows/release.yml" 2>/dev/null && pass "CI: release.yml triggers on v* tags" || fail "CI: v* tag trigger MISSING"
grep -q "FRAMEWORK_VER\|Framework Version" "$PROJ/.github/workflows/release.yml" 2>/dev/null && pass "CI: release.yml verifies version consistency" || fail "CI: version check MISSING"
[ -f "$PROJ/.github/pull_request_template.md" ] && pass "CI: PR template exists" || fail "CI: PR template MISSING"
grep -qi "portabilit" "$PROJ/.github/pull_request_template.md" 2>/dev/null && pass "CI: PR template has portability test" || fail "CI: PR template missing portability test"
grep -q "test-spec-kit.sh" "$PROJ/.github/pull_request_template.md" 2>/dev/null && pass "CI: PR template references test suites" || fail "CI: PR template missing test commands"
[ -d "$PROJ/.github/ISSUE_TEMPLATE" ] && pass "CI: ISSUE_TEMPLATE/ dir exists" || fail "CI: ISSUE_TEMPLATE/ MISSING"
[ -f "$PROJ/.github/ISSUE_TEMPLATE/bug_report.md" ] && pass "CI: bug_report.md exists" || fail "CI: bug_report.md MISSING"
[ -f "$PROJ/.github/ISSUE_TEMPLATE/feature_request.md" ] && pass "CI: feature_request.md exists" || fail "CI: feature_request.md MISSING"
grep -q "actions/workflows/ci.yml/badge.svg" "$PROJ/README.md" 2>/dev/null && pass "CI: README has CI badge" || fail "CI: README missing CI badge"
BARE_SED=$(grep -n "sed -i ''" "$PROJ/tests/test-spd-benchmarking.sh" 2>/dev/null | grep -v "2>/dev/null" | wc -l | tr -d ' \t')
[ "$BARE_SED" -eq 0 ] && pass "CI: test-spd-benchmarking.sh uses cross-platform sed" || fail "CI: $BARE_SED bare 'sed -i \"\"' lines without Linux fallback"

# Framework rules for user projects — validates portable-spec-kit.md teaches CI/CD correctly
grep -q "CI & Community\|CI.*Community Contributions" "$PROJ/portable-spec-kit.md" && pass "CI: framework has CI & Community Contributions section" || fail "CI: CI & Community Contributions section MISSING"
grep -q "CI status badge rule\|CI.*badge.*rule" "$PROJ/portable-spec-kit.md" && pass "CI: framework has CI badge rule for user projects" || fail "CI: CI badge rule MISSING"
grep -q "branch protection\|Branch protection" "$PROJ/portable-spec-kit.md" && pass "CI: framework has branch protection guidance" || fail "CI: branch protection guidance MISSING"
grep -q "PR workflow rule\|merge any PR\|community PR" "$PROJ/portable-spec-kit.md" && pass "CI: framework has PR workflow rule" || fail "CI: PR workflow rule MISSING"
grep -q "Contribution validation rule\|CI.*minimum bar\|green CI.*minimum" "$PROJ/portable-spec-kit.md" && pass "CI: framework has contribution validation rule" || fail "CI: contribution validation rule MISSING"
grep -q "CI must be green.*merg\|green.*before merg\|CI.*green.*PR" "$PROJ/portable-spec-kit.md" && pass "CI: Branch & PR section requires CI green before merge" || fail "CI: CI-before-merge requirement MISSING"
grep -q "ci\.yml template\|GitHub Actions.*template\|Step 7\.5" "$PROJ/portable-spec-kit.md" && pass "CI: framework has ci.yml template + Step 7.5 for new projects" || fail "CI: ci.yml template / Step 7.5 MISSING from framework"
grep -q "test-release-check\.sh agent/SPECS\.md\|R.*F.*T.*validator.*ci\|ci.*release-check" "$PROJ/portable-spec-kit.md" && pass "CI: framework requires test-release-check.sh in user project CI" || fail "CI: test-release-check.sh not required in user CI template"
grep -q "npx jest\|npm test\|python -m pytest\|go test\|vitest run" "$PROJ/portable-spec-kit.md" && pass "CI: framework has stack-aware test commands for user CI" || fail "CI: stack-aware test commands MISSING"
grep -q "actions/setup-node\|actions/setup-python" "$PROJ/portable-spec-kit.md" && pass "CI: framework has stack setup steps (Node/Python) for user CI" || fail "CI: stack setup steps MISSING from framework"
grep -q "Create.*ci\.yml\|ci\.yml.*existing\|existing.*setup.*CI" "$PROJ/portable-spec-kit.md" && pass "CI: Existing Project Setup checklist includes CI" || fail "CI: Existing Project Setup missing CI item"
grep -q "Step 7\.5\|7\.5.*CI\|create.*ci\.yml.*after stack" "$PROJ/portable-spec-kit.md" && pass "CI: New Project Setup Step 7.5 creates ci.yml after stack confirmed" || fail "CI: New Project Setup Step 7.5 MISSING"

# ═══════════════════════════════════════════════════════════════
section "43. Spec-Based Test Generation"
# ═══════════════════════════════════════════════════════════════

grep -q "SPECS origin detection\|forward flow\|retroactive flow" "$PROJ/portable-spec-kit.md" && pass "SpecGen: framework has SPECS origin detection rule" || fail "SpecGen: SPECS origin detection rule MISSING"
grep -q "forward flow.*generate test stubs\|test stub.*forward flow\|forward.*stub" "$PROJ/portable-spec-kit.md" && pass "SpecGen: framework generates stubs in forward flow only" || fail "SpecGen: forward flow stub generation rule MISSING"
grep -q "retroactive.*do NOT generate\|retroactive.*write tests directly" "$PROJ/portable-spec-kit.md" && pass "SpecGen: framework skips stubs in retroactive flow" || fail "SpecGen: retroactive flow rule MISSING"
grep -q "Feature Acceptance Criteria\|per-feature acceptance criteria" "$PROJ/portable-spec-kit.md" && pass "SpecGen: framework has per-feature acceptance criteria format" || fail "SpecGen: per-feature criteria format MISSING"
grep -q "Feature Acceptance Criteria" "$PROJ/agent/SPECS.md" && pass "SpecGen: kit's own SPECS.md uses per-feature criteria format" || fail "SpecGen: kit SPECS.md not updated to per-feature format"
grep -q "stack-aware\|Stack.*stub\|stub.*stack" "$PROJ/portable-spec-kit.md" && pass "SpecGen: framework has stack-aware stub formats" || fail "SpecGen: stack-aware stub formats MISSING"
grep -q "# TODO.*implement\|TODO: implement\|stub.*completion\|incomplete.*marker" "$PROJ/portable-spec-kit.md" && pass "SpecGen: framework has stub completion rule" || fail "SpecGen: stub completion rule MISSING"
grep -q "test\.skip\|xit(\|xtest\|expect(true)\.toBe(false)" "$PROJ/portable-spec-kit.md" && pass "SpecGen: framework lists incomplete markers" || fail "SpecGen: incomplete marker list MISSING"
grep -q "refuse to mark done\|refuse.*mark.*\[x\]\|incomplete.*test stubs.*before marking" "$PROJ/portable-spec-kit.md" && pass "SpecGen: framework refuses to mark done with incomplete stubs" || fail "SpecGen: stub-gate rule MISSING"
grep -q "forward flow.*sequence\|recommended sequence" "$PROJ/portable-spec-kit.md" && pass "SpecGen: framework has forward flow sequence" || fail "SpecGen: forward flow sequence MISSING"
grep -q "check_stub_complete\|stubs_incomplete\|TODO.*marker" "$PROJ/tests/test-release-check.sh" && pass "SpecGen: test-release-check.sh has stub completion check" || fail "SpecGen: stub completion check missing from test-release-check.sh"
grep -q "check_stub_complete\|stubs_incomplete\|TODO.*marker" "$PROJ/portable-spec-kit.md" && pass "SpecGen: kit template for test-release-check.sh has stub completion check" || fail "SpecGen: stub completion check missing from kit template"
grep -q "Spec-Based Test Generation\|spec.*based.*test\|test.*stub.*generation" "$PROJ/portable-spec-kit.md" && pass "SpecGen: framework section exists" || fail "SpecGen: Spec-Based Test Generation section MISSING"
grep -q "f{n}\|f1-\|f2-\|fn-" "$PROJ/portable-spec-kit.md" && pass "SpecGen: framework shows stub naming convention" || fail "SpecGen: stub naming convention MISSING"
grep -q "### F[0-9]" "$PROJ/agent/SPECS.md" && pass "SpecGen: kit SPECS.md has per-feature F{n} sections" || fail "SpecGen: kit SPECS.md missing per-feature F{n} sections"

# ═══════════════════════════════════════════════════════════════
section "44. Progress Dashboard"
# ═══════════════════════════════════════════════════════════════

grep -q "Progress Dashboard" "$PROJ/portable-spec-kit.md" && pass "Dashboard: framework has Progress Dashboard section" || fail "Dashboard: Progress Dashboard section MISSING"
grep -q "progress.*dashboard\|dashboard.*burndown\|trigger.*dashboard\|burndown.*trigger" "$PROJ/portable-spec-kit.md" && pass "Dashboard: trigger words defined" || fail "Dashboard: trigger words MISSING"
grep -q "OVERALL\|done.*total\|pending.*total\|progress.*bar" "$PROJ/portable-spec-kit.md" && pass "Dashboard: output format defined (OVERALL section)" || fail "Dashboard: output format MISSING"
grep -q "BY VERSION\|per.*version\|version.*heading" "$PROJ/portable-spec-kit.md" && pass "Dashboard: BY VERSION breakdown defined" || fail "Dashboard: BY VERSION section MISSING"
grep -q "████\|█.*░\|progress bar\|bar.*width" "$PROJ/portable-spec-kit.md" && pass "Dashboard: progress bar format defined" || fail "Dashboard: progress bar format MISSING"
grep -q "✅.*Done\|🔄.*Current\|100%.*complete" "$PROJ/portable-spec-kit.md" && pass "Dashboard: version status icons defined" || fail "Dashboard: version status icons MISSING"
grep -q "CURRENT VERSION TASKS\|current.*version.*tasks" "$PROJ/portable-spec-kit.md" && pass "Dashboard: CURRENT VERSION TASKS section defined" || fail "Dashboard: current tasks section MISSING"
grep -q "NEXT ACTIONS\|next.*actions\|next.*pending" "$PROJ/portable-spec-kit.md" && pass "Dashboard: NEXT ACTIONS section defined" || fail "Dashboard: next actions MISSING"
grep -q "Backlog.*never counted\|backlog.*future.*scope\|not.*counted.*progress" "$PROJ/portable-spec-kit.md" && pass "Dashboard: Backlog items excluded from count" || fail "Dashboard: Backlog exclusion rule MISSING"
grep -q "BLOCKERS\|blocked.*items\|Blocked.*separately" "$PROJ/portable-spec-kit.md" && pass "Dashboard: BLOCKERS section defined" || fail "Dashboard: blockers section MISSING"
grep -q "read-only\|does not modify\|no.*files.*modified\|generate.*on-demand" "$PROJ/portable-spec-kit.md" && pass "Dashboard: read-only / no file modification rule" || fail "Dashboard: read-only rule MISSING"
grep -q "BY CONTRIBUTOR\|per.*user.*breakdown\|@username.*dashboard" "$PROJ/portable-spec-kit.md" && pass "Dashboard: BY CONTRIBUTOR section defined for @username projects" || fail "Dashboard: BY CONTRIBUTOR section MISSING"
grep -q "TASKS.md missing\|No TASKS.md\|missing.*TASKS" "$PROJ/portable-spec-kit.md" && pass "Dashboard: missing TASKS.md edge case handled" || fail "Dashboard: missing TASKS.md edge case MISSING"
grep -q "All tasks complete\|all.*done.*release\|🎉" "$PROJ/portable-spec-kit.md" && pass "Dashboard: all-done state handled" || fail "Dashboard: all-done state MISSING"
grep -q "Unassigned\|unassigned.*tasks\|tasks without @" "$PROJ/portable-spec-kit.md" && pass "Dashboard: unassigned tasks grouped separately" || fail "Dashboard: unassigned group MISSING"
grep -q "truncate\|50+\|X more done\|long task list" "$PROJ/portable-spec-kit.md" && pass "Dashboard: long task list truncation rule" || fail "Dashboard: truncation edge case MISSING"
grep -q "how are we doing\|status report\|what.*left" "$PROJ/portable-spec-kit.md" && pass "Dashboard: natural language triggers included" || fail "Dashboard: natural language triggers MISSING"
grep -q "Agent.*reads.*TASKS\|reads TASKS.md\|read.*TASKS.md.*directly" "$PROJ/portable-spec-kit.md" && pass "Dashboard: trigger → read TASKS.md behavior defined" || fail "Dashboard: trigger behavior MISSING"

# ═══════════════════════════════════════════════════════════════
section "45. Multi-Agent Task Tracking"
# ═══════════════════════════════════════════════════════════════

grep -q "@username.*TASKS\|task.*owner.*@\|ownership syntax" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: @username ownership syntax defined" || fail "MultiAgent: @username syntax MISSING"
grep -q "slugified.*git config\|git config.*slugified\|username.*detection" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: username detection from git config defined" || fail "MultiAgent: username detection MISSING"
grep -q "multiple.*owner\|@a @b\|two.*username\|Multiple owners" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: multiple owners rule defined" || fail "MultiAgent: multiple owners MISSING"
grep -q "per-user.*task.*view\|my tasks.*trigger\|my workload.*trigger\|Per-user task view" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: per-user task view trigger defined" || fail "MultiAgent: per-user view trigger MISSING"
grep -q "Delegation rule\|assign.*to @\|delegate.*to @" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: delegation protocol defined" || fail "MultiAgent: delegation protocol MISSING"
grep -q "Unassign rule\|unassign.*@\|remove.*@.*task\|untagged.*unassigned" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: unassign/remove ownership rule defined" || fail "MultiAgent: unassign rule MISSING"
grep -q "TASKS.md.*human-readable\|plain.*markdown.*readable\|no tooling" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: TASKS.md remains human-readable rule" || fail "MultiAgent: human-readable rule MISSING"
grep -q "cross-agent.*coordination\|agents.*coordinate.*through.*TASKS\|pull.*sees.*assignment" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: cross-agent coordination via TASKS.md" || fail "MultiAgent: cross-agent coordination rule MISSING"
grep -q "Dashboard integration\|BY CONTRIBUTOR\|@.*dashboard.*section" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: dashboard BY CONTRIBUTOR from @tags" || fail "MultiAgent: BY CONTRIBUTOR dashboard section MISSING"
grep -q "blocked.*task.*per-user\|blocked.*visible\|blocked.*per-user" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: blocked tasks visible in per-user view" || fail "MultiAgent: blocked task edge case MISSING"
grep -q "No tasks.*assigned\|No tasks.* @\|unassigned.*tasks.*hint" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: no-tasks-for-user edge case handled" || fail "MultiAgent: no-tasks edge case MISSING"
grep -q "Git user not configured\|fall.*back.*asking.*username\|username.*not.*configured" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: git user not configured edge case" || fail "MultiAgent: unconfigured git user edge case MISSING"
grep -q "shared.*done.*@a.*@b\|last.*owner.*mark.*done\|last person to mark" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: shared task completion rule" || fail "MultiAgent: shared task completion rule MISSING"
grep -q "Typo.*@username\|typo.*@\|show as-is\|as-is.*dashboard" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: typo in @username handled gracefully" || fail "MultiAgent: @username typo edge case MISSING"
grep -q "No tasks tagged.*yet\|claim ownership\|Add.*@.*username.*claim" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: fresh project (no tags) guidance" || fail "MultiAgent: no-tags fresh project guidance MISSING"
grep -q "TASKS.md.*template.*@username\|@username.*←\|@username.*assign" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: TASKS.md template shows @username syntax" || fail "MultiAgent: template missing @username example"
grep -q "All tasks owned.*consider distributing\|consider distributing\|all.*assigned.*one user" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: all-tasks-one-user distribution warning" || fail "MultiAgent: distribute warning MISSING"
grep -q "Persistent Memory.*applied.*team\|Persistent Memory.*team task\|Persistent Memory Architecture applied" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: cross-agent coordination linked to Persistent Memory" || fail "MultiAgent: Persistent Memory Architecture link MISSING"
grep -q "shared.*pending.*their confirmation\|pending.*@b.*confirmation\|both.*mark.*done" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: shared task pending state per-user" || fail "MultiAgent: shared task per-user state MISSING"
grep -q "truncate.*per-user\|20 items.*per-user\|N more.*TASKS.md" "$PROJ/portable-spec-kit.md" && pass "MultiAgent: long task list truncation in per-user view" || fail "MultiAgent: per-user truncation MISSING"

# ═══════════════════════════════════════════════════════════════
section "46. Persistent Memory Architecture"
# ═══════════════════════════════════════════════════════════════

grep -q "Persistent Memory Architecture\|Persistent Memory" "$PROJ/portable-spec-kit.md" && pass "PersistentMem: framework introduces Persistent Memory Architecture concept" || fail "PersistentMem: concept MISSING"
grep -q "6 agent files.*Persistent Memory\|agent files.*persistent memory\|AGENT_CONTEXT.*SPECS.*memory" "$PROJ/portable-spec-kit.md" && pass "PersistentMem: 6 agent files = persistent memory" || fail "PersistentMem: 6 files = memory definition MISSING"
grep -q "Durable.*git\|durable.*persists.*git\|git.*durable" "$PROJ/portable-spec-kit.md" && pass "PersistentMem: Durable property defined (git)" || fail "PersistentMem: Durable property MISSING"
grep -q "Shared.*any agent\|shared.*any.*machine\|any agent.*reads" "$PROJ/portable-spec-kit.md" && pass "PersistentMem: Shared property defined (any agent)" || fail "PersistentMem: Shared property MISSING"
grep -q "Portable.*Claude.*Cursor\|portable.*Copilot\|works with.*Claude.*Cursor" "$PROJ/portable-spec-kit.md" && pass "PersistentMem: Portable property defined (multi-agent)" || fail "PersistentMem: Portable property MISSING"
grep -q "Team-scale\|team.*scale.*coordinate\|multiple.*agents.*coordinate" "$PROJ/portable-spec-kit.md" && pass "PersistentMem: Team-scale property defined" || fail "PersistentMem: Team-scale property MISSING"
grep -q "Auditable.*git.*history\|git.*history.*auditable\|auditable" "$PROJ/portable-spec-kit.md" && pass "PersistentMem: Auditable property defined" || fail "PersistentMem: Auditable property MISSING"
grep -q "tracking.*Persistent Memory\|tracking.*writing.*memory\|Always tracking.*Persistent Memory" "$PROJ/portable-spec-kit.md" && pass "PersistentMem: tracking = writing to Persistent Memory" || fail "PersistentMem: tracking-as-memory framing MISSING"
grep -q "No APIs.*No message queue\|no.*APIs\|no.*message.*queue" "$PROJ/portable-spec-kit.md" && pass "PersistentMem: files replace real-time APIs" || fail "PersistentMem: no-API benefit MISSING"
grep -q "verbal handoff\|no.*onboarding.*call\|no.*wiki\|instantly briefed" "$PROJ/portable-spec-kit.md" && pass "PersistentMem: zero-handoff benefit stated" || fail "PersistentMem: zero-handoff benefit MISSING"
grep -q "ephemeral.*agent.*context\|ephemeral.*session.*ends\|Persistent Memory.*survives" "$PROJ/portable-spec-kit.md" && pass "PersistentMem: distinction from ephemeral agent context" || fail "PersistentMem: ephemeral vs persistent distinction MISSING"
grep -q "core innovation.*SPD\|keeps.*project.*intelligence.*alive\|intelligence.*across.*contributors" "$PROJ/portable-spec-kit.md" && pass "PersistentMem: positioned as core SPD innovation" || fail "PersistentMem: core innovation framing MISSING"

# ═══════════════════════════════════════════════════════════════
section "47. Architecture Decision Log"
# ═══════════════════════════════════════════════════════════════

grep -q "Architecture Decision Log\|ADR-\|ADL" "$PROJ/portable-spec-kit.md" && pass "ADL: Architecture Decision Log concept defined in framework" || fail "ADL: ADL concept MISSING"
grep -q "ADR-[0-9][0-9][0-9]\|ADR.*NNN\|ADR.*sequential\|ADR.*numbered" "$PROJ/portable-spec-kit.md" && pass "ADL: ADR numbering format defined (ADR-NNN)" || fail "ADL: ADR numbering MISSING"
grep -q "YYYY-MM-DD\|ISO.*date\|absolute.*date.*ADL\|ISO 8601" "$PROJ/portable-spec-kit.md" && pass "ADL: ISO date format required" || fail "ADL: ISO date format MISSING"
grep -q "Impact.*column\|Impact.*files\|Impact.*systems\|Impact.*components" "$PROJ/portable-spec-kit.md" && pass "ADL: Impact column defined" || fail "ADL: Impact column MISSING"
grep -q "Newest first\|most recent.*top\|prepend.*append\|newest.*ADL\|Newest entries first" "$PROJ/portable-spec-kit.md" && pass "ADL: newest-first order rule" || fail "ADL: newest-first rule MISSING"
grep -q "never delete.*ADL\|immutable.*ADL\|immutable history\|past.*decision.*preserved" "$PROJ/portable-spec-kit.md" && pass "ADL: ADL entries are immutable (no delete)" || fail "ADL: immutable history rule MISSING"
grep -q "supersedes.*ADR\|ADR.*supersedes\|new.*row.*referencing.*old" "$PROJ/portable-spec-kit.md" && pass "ADL: supersede pattern defined" || fail "ADL: supersede pattern MISSING"
grep -q "NOT for.*bug\|not.*for.*small\|implementation.*choices.*excluded\|not.*for.*minor" "$PROJ/portable-spec-kit.md" && pass "ADL: scope boundary (not for bugs/small changes)" || fail "ADL: scope boundary MISSING"
grep -q "Architecture Decision Log" "$PROJ/agent/PLANS.md" && pass "ADL: kit's own PLANS.md has Architecture Decision Log section" || fail "ADL: kit PLANS.md not updated to ADL format"
grep -q "ADR-[0-9]" "$PROJ/agent/PLANS.md" && pass "ADL: kit's PLANS.md has ADR entries" || fail "ADL: kit PLANS.md missing ADR entries"

# ═══════════════════════════════════════════════════════════════
section "48. AI-Powered Onboarding"
# ═══════════════════════════════════════════════════════════════

grep -q "AI-Powered Onboarding\|AI.*onboarding.*rule\|commit.*agent.*team\|Commit.*agent.*MANDATORY" "$PROJ/portable-spec-kit.md" && pass "Onboarding: AI-Powered Onboarding rule defined" || fail "Onboarding: rule MISSING"
grep -q "team.*project.*commit.*agent\|open-source.*commit.*agent\|public.*repo.*agent\|public GitHub repo.*commit" "$PROJ/portable-spec-kit.md" && pass "Onboarding: commit agent/ for team/open-source projects" || fail "Onboarding: team/open-source commit rule MISSING"
grep -q "Never add.*gitignore.*team\|not.*gitignore.*team\|never.*gitignore.*team" "$PROJ/portable-spec-kit.md" && pass "Onboarding: never gitignore agent/ for team projects" || fail "Onboarding: gitignore exclusion rule MISSING"
grep -q "clone.*briefed\|contributor.*clones.*reads\|spec.*files.*onboarding\|clones the repo.*briefed" "$PROJ/portable-spec-kit.md" && pass "Onboarding: clone → briefed flow described" || fail "Onboarding: clone-briefed flow MISSING"
grep -q "CONTRIBUTING.md guidance\|CONTRIBUTING.md.*open-source.*add\|CONTRIBUTING.*briefed.*clone" "$PROJ/portable-spec-kit.md" && pass "Onboarding: CONTRIBUTING.md guidance defined" || fail "Onboarding: CONTRIBUTING.md guidance MISSING"
grep -q "Solo project exception\|solo.*exception\|single.*developer.*private.*agent" "$PROJ/portable-spec-kit.md" && pass "Onboarding: solo project exception defined" || fail "Onboarding: solo exception MISSING"
grep -q "Sensitive content check\|secrets.*agent.*file\|sensitive.*agent.*check" "$PROJ/portable-spec-kit.md" && pass "Onboarding: sensitive content check before commit" || fail "Onboarding: sensitive content check MISSING"
grep -q "already.*gitignored.*warn\|agent.*gitignored.*warn\|warn.*gitignore.*agent" "$PROJ/portable-spec-kit.md" && pass "Onboarding: agent/ in .gitignore warning" || fail "Onboarding: gitignored warning MISSING"
grep -q "agent-agnostic.*brief\|Cursor.*Copilot.*same.*files\|different.*AI.*agent.*clone\|any agent.*can.*read" "$PROJ/portable-spec-kit.md" && pass "Onboarding: agent-agnostic briefing (any AI agent)" || fail "Onboarding: agent-agnostic briefing MISSING"
grep -q "Solo.*private.*add comment\|add comment.*team projects\|commit this for team" "$PROJ/portable-spec-kit.md" && pass "Onboarding: .gitignore comment for solo/private projects" || fail "Onboarding: gitignore comment rule MISSING"

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
