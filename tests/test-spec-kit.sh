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
[ -f "$PROJ/docs/Portable_Spec_Kit_Guide.html" ] && pass "Guide HTML exists" || fail "Guide HTML MISSING"
[ -f "$PROJ/docs/Portable_Spec_Kit_Guide.pdf" ] && pass "Guide PDF exists" || fail "Guide PDF MISSING"
[ -d "$PROJ/examples/starter" ] && pass "examples/starter/ exists" || fail "examples/starter/ MISSING"
[ -d "$PROJ/examples/my-app" ] && pass "examples/my-app/ exists" || fail "examples/my-app/ MISSING"
[ -d "$PROJ/agent" ] && pass "agent/ dir exists (Documents-only)" || fail "agent/ MISSING"

# ═══════════════════════════════════════════════════════════════
section "2. Framework File Content"
# ═══════════════════════════════════════════════════════════════

grep -q "Portable Spec Kit — AI Agentic" "$PROJ/portable-spec-kit.md" && pass "Title correct" || fail "Title wrong"
grep -q "About the User" "$PROJ/portable-spec-kit.md" && pass "Has About the User section" || fail "Missing About the User"
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
grep -q "AI agent to do 90%" "$PROJ/portable-spec-kit.md" && pass "Generic AI agent reference" || fail "Claude-specific agent reference"

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
grep -q "Self-Scaffolding" "$PROJ/README.md" && pass "README: 8 features (Self-Scaffolding)" || fail "README: missing feature"
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
section "13. License"
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
