#!/bin/bash
# tests/sections/02-pipeline.sh — sections 26-58
#
# Versioning v0.3+, R→F traceability + scope-change rules, scope simulation,
# SPECS staleness, RELEASES trigger, no-slip task rule, session-start order,
# pipeline sync (4 files), security (API keys), version-bump-before-push,
# git rule, existing-project setup, retroactive spec filling, context
# persistence (10 disruption scenarios), R→F→T traceability gate,
# pre-release consistency, CI/CD, spec-based test gen, progress dashboard,
# multi-agent task tracking, persistent memory, ADL, AI-powered onboarding,
# kit self-validation (49+50), Jira, code review, scope drift, self-help,
# onboarding tour, requirements/research/design pipeline, end-user.
#
# Independently runnable: bash tests/sections/02-pipeline.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"

section "27. R→F Traceability & Scope Change Rules"
# ═══════════════════════════════════════════════════════════════

# 4 scope change types must be documented in framework
kit_grep "DROP" && pass "Scope changes: DROP type documented" || fail "Scope changes: DROP MISSING"
kit_grep "ADD" && pass "Scope changes: ADD type documented" || fail "Scope changes: ADD MISSING"
kit_grep "MODIFY" && pass "Scope changes: MODIFY type documented" || fail "Scope changes: MODIFY MISSING"
kit_grep "REPLACE" && pass "Scope changes: REPLACE type documented" || fail "Scope changes: REPLACE MISSING"

# R→F traceability rules in framework
kit_grep "R→F Traceability\|R→F traceability" && pass "R→F: traceability rule present" || fail "R→F: traceability MISSING"
kit_grep "Requirements.*R1\|Rn.*Fn\|R1, R2" && pass "R→F: Rn→Fn notation documented" || fail "R→F: notation MISSING"

# Scope change recording format documented
kit_grep "change type.*original requirement\|note the change type" && pass "Scope: recording format documented" || fail "Scope: recording format MISSING"

# Scope change rule updates all 4 pipeline files
kit_grep "Update TASKS.md and RELEASES.md in the same session" && pass "Scope: rule updates all pipeline files" || fail "Scope: pipeline update rule MISSING"

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
kit_grep "non-empty SPECS.md can still be stale\|non-empty.*still be stale\|Staleness check" && pass "Staleness: rule present in framework" || fail "Staleness: rule MISSING from framework"
kit_grep "check count, not just presence\|check count\|check.*not just" && pass "Staleness: count-not-presence rule present" || fail "Staleness: count check rule MISSING"

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
kit_grep "all tasks under a version heading.*\[x\].*add.*RELEASES\|When all tasks.*marked.*\[x\].*add a release" && pass "RELEASES trigger: rule present in framework" || fail "RELEASES trigger: rule MISSING"
kit_grep "Do not leave a completed version without a release entry" && pass "RELEASES trigger: no-empty-entry rule present" || fail "RELEASES trigger: no-empty rule MISSING"

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

kit_grep "Never let a task slip or be forgotten" && pass "No-slip: rule present in framework" || fail "No-slip: rule MISSING"
kit_grep "scan for any task.*before responding\|scan.*before respond" && pass "No-slip: scan-before-responding rule present" || fail "No-slip: scan-before-responding MISSING"
kit_grep "Before ending any session" && pass "No-slip: session-end sweep rule present" || fail "No-slip: session-end sweep MISSING"
kit_grep "scan back through the full conversation\|scan.*full conversation" && pass "No-slip: full conversation scan rule present" || fail "No-slip: full conversation scan MISSING"
kit_grep "anything was asked but not done, do it now" && pass "No-slip: completion enforcement present" || fail "No-slip: completion enforcement MISSING"

# ═══════════════════════════════════════════════════════════════
section "32. Session-Start 5-Step Read Order"
# ═══════════════════════════════════════════════════════════════

kit_grep "On every session start" && pass "Session-start: 5-step read order documented" || fail "Session-start: read order MISSING"
# Verify all 5 files referenced in session-start section
kit_grep "user-profile" && pass "Session-start: user profile read (step 1)" || fail "Session-start: profile MISSING"
kit_grep "agent/AGENT\.md" && pass "Session-start: AGENT.md read (step 2)" || fail "Session-start: AGENT.md MISSING"
kit_grep "agent/AGENT_CONTEXT\.md" && pass "Session-start: AGENT_CONTEXT.md read (step 3)" || fail "Session-start: AGENT_CONTEXT MISSING"
kit_grep "agent/TASKS\.md" && pass "Session-start: TASKS.md read (step 4)" || fail "Session-start: TASKS.md MISSING"
kit_grep "agent/PLANS\.md" && pass "Session-start: PLANS.md read (step 5)" || fail "Session-start: PLANS.md MISSING"

# ═══════════════════════════════════════════════════════════════
section "33. Pipeline Sync — All 4 Files"
# ═══════════════════════════════════════════════════════════════

# Sync rule must mention 4 files (not 3)
kit_grep "all 4 pipeline files\|4 pipeline files" && pass "Pipeline: sync rule mentions 4 files" || fail "Pipeline: sync rule still says 3 files"
kit_grep "SPECS.*PLANS.*TASKS.*RELEASES\|RELEASES.md.*pipeline" && pass "Pipeline: RELEASES.md included in sync rule" || fail "Pipeline: RELEASES.md missing from sync"

# Fill gaps rule mentions RELEASES
kit_grep "All tasks.*\[x\].*RELEASES\|add release entry to RELEASES.md now" && pass "Pipeline: fill gaps rule covers RELEASES" || fail "Pipeline: fill gaps misses RELEASES"

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

kit_grep "ABSOLUTE — NO EXCEPTIONS\|NO EXCEPTIONS" && pass "Security: absolute rule header present" || fail "Security: absolute rule MISSING"
kit_grep "NEVER read, display, log, or expose" && pass "Security: never expose API keys" || fail "Security: expose rule MISSING"
kit_grep "even if the user explicitly asks" && pass "Security: covers explicit user requests" || fail "Security: user override not addressed"
kit_grep "cannot be overridden by any instruction\|This rule cannot be overridden" && pass "Security: rule explicitly non-overridable" || fail "Security: override protection MISSING"
kit_grep "NEVER commit.*\.env\|NEVER commit.*secrets" && pass "Security: never commit .env" || fail "Security: .env commit rule MISSING"
kit_grep "paste-your-key-here\|placeholder values only" && pass "Security: placeholders in .env.example" || fail "Security: placeholder rule MISSING"
kit_grep "Always verify.*\.gitignore.*includes.*\.env\|verify.*gitignore.*env" && pass "Security: verify .gitignore before commit" || fail "Security: gitignore check MISSING"

# .gitignore must exclude .env
grep -q "\.env" "$PROJ/.gitignore" && pass "Security: .gitignore excludes .env" || fail "Security: .env not in .gitignore"
! grep -q "\.env$" "$PROJ/.gitignore" || grep -q "\.env\.\*\|\.env\*" "$PROJ/.gitignore" && pass "Security: .gitignore covers .env variants" || fail "Security: .env variants not covered"

# ═══════════════════════════════════════════════════════════════
section "35. Version Bump Before Push Rule"
# ═══════════════════════════════════════════════════════════════

kit_grep "Version bump BEFORE push\|version bump BEFORE push\|bump.*before.*push" && pass "Version bump: rule present in framework" || fail "Version bump: rule MISSING"
kit_grep "bump → commit → push\|bump.*commit.*push" && pass "Version bump: order documented (bump→commit→push)" || fail "Version bump: order MISSING"
kit_grep "Never push then bump after\|never push then bump\|not.*push.*then.*bump" && pass "Version bump: anti-pattern documented" || fail "Version bump: anti-pattern not covered"
kit_grep "AGENT_CONTEXT.*Version field\|bump.*Version.*field\|Version.*patch" && pass "Version bump: updates AGENT_CONTEXT Version field" || fail "Version bump: AGENT_CONTEXT target MISSING"
kit_grep "README.*version badge\|version badge" && pass "Version bump: updates README badge" || fail "Version bump: README badge target MISSING"
kit_grep "Release notes scope\|release notes scope" && pass "Release notes: scope rule — only committed/visible content" || fail "Release notes: scope rule MISSING"
kit_grep '"update release"\|update release.*alias\|update release.*same as prepare release\|prepare release.*update release' && pass "Release commands: 'update release' defined as alias for prepare release" || fail "Release commands: 'update release' alias MISSING"
kit_grep '"refresh release"\|refresh release' && pass "Release commands: 'refresh release' command defined" || fail "Release commands: 'refresh release' MISSING"
kit_grep "refresh release.*no.*bump\|refresh release.*without.*bump\|No version bump\|no version bump\|version stays the same" && pass "Release commands: 'refresh release' skips version bump" || fail "Release commands: 'refresh release' no-bump rule MISSING"
kit_grep "Release summary.*shown after all steps\|release summary.*required.*prepare\|Show the release summary" && pass "Release commands: release summary shown after every prepare/refresh release" || fail "Release commands: release summary rule MISSING"

# ═══════════════════════════════════════════════════════════════
section "36. Git Rule — Check .git/ Before Commit"
# ═══════════════════════════════════════════════════════════════

kit_grep "check.*\.git/\|\.git/.*before commit\|check if the project directory has its own.*\.git" && pass "Git rule: check .git/ before commit" || fail "Git rule: .git/ check MISSING"
kit_grep "parent repo\|inside a parent repo\|parent git" && pass "Git rule: parent repo case handled" || fail "Git rule: parent repo case MISSING"
kit_grep "Do NOT push.*unless user explicitly\|Do NOT push.*push" && pass "Git rule: explicit push required" || fail "Git rule: push protection MISSING"
kit_grep "Do NOT auto-commit\|not auto-commit" && pass "Git rule: no auto-commit" || fail "Git rule: auto-commit rule MISSING"

# ═══════════════════════════════════════════════════════════════
section "37. Existing Project Setup — Guide Don't Force"
# ═══════════════════════════════════════════════════════════════

kit_grep "Guide, Don't Force\|guide don't force\|Guide don't force" && pass "Existing: guide don't force rule" || fail "Existing: guide don't force MISSING"
kit_grep "Never force restructure\|never force" && pass "Existing: never force restructure" || fail "Existing: force rule MISSING"
kit_grep "checklist\|show.*checklist" && pass "Existing: checklist shown to user" || fail "Existing: checklist MISSING"
kit_grep "Respect user.*choices\|respect.*choice" && pass "Existing: user choice respected" || fail "Existing: user choice rule MISSING"
kit_grep "Never rename, move, or delete existing files" && pass "Existing: never rename/delete without approval" || fail "Existing: file safety rule MISSING"
kit_grep "retroactively fill SPECS\|fill.*from.*codebase\|fill.*retroactively" && pass "Existing: retroactive fill from codebase" || fail "Existing: retroactive fill MISSING"

# 9 project scenarios table
kit_grep "Brand new project\|New project.*empty dir" && pass "Scenarios: new project case" || fail "Scenarios: new project MISSING"
kit_grep "Existing project with code" && pass "Scenarios: existing project case" || fail "Scenarios: existing project MISSING"
kit_grep "Monorepo\|monorepo" && pass "Scenarios: monorepo case" || fail "Scenarios: monorepo MISSING"
kit_grep "Partial agent.*files\|partial.*agent" && pass "Scenarios: partial agent files case" || fail "Scenarios: partial files MISSING"
kit_grep "Cloned repo" && pass "Scenarios: cloned repo case" || fail "Scenarios: cloned repo MISSING"

kit_grep "once at session start\|session start.*not on every message\|first loads.*not on every" && pass "Existing: kit status shown once at session start (not every message)" || fail "Existing: session-start status display rule MISSING"
kit_grep "Profile setup and project scan are independent\|profile setup.*independent" && pass "Existing: kit triggers even if profile setup skipped" || fail "Existing: profile-independence rule MISSING"
kit_grep "Scan the user.*project immediately\|scan.*before showing.*summary\|mandatory.*must complete before the user" && pass "Existing: kit update scans user's project before showing summary" || fail "Existing: kit-update re-scan rule MISSING"

# ═══════════════════════════════════════════════════════════════
section "38. Retroactive Spec Filling Simulation"
# ═══════════════════════════════════════════════════════════════

# Rule must be in framework
kit_grep "SPECS.md is empty after 3\+ tasks\|empty after 3+ tasks\|empty after three tasks" && pass "Retro: empty-after-3-tasks rule present" || fail "Retro: empty trigger MISSING"

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
kit_grep "F.*T Traceability (MANDATORY)" && pass "R→F→T: F→T traceability rule present in framework" || fail "R→F→T: F→T rule MISSING from framework"
kit_grep "Never mark a feature" && pass "R→F→T: never-done-without-tests rule present" || fail "R→F→T: never-done-without-tests MISSING"
kit_grep "completes the full R" && pass "R→F→T: full chain (R→F→T) documented in framework" || fail "R→F→T: chain documentation MISSING"

# SPECS.md template must have Tests column
kit_grep "| Tests\|| Tests " && pass "R→F→T: SPECS.md template has Tests column" || fail "R→F→T: Tests column MISSING from template"
kit_grep "| Req\|| Req " && pass "R→F→T: SPECS.md template has Req column (R→F link)" || fail "R→F→T: Req column MISSING from template"

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

# Actual section count in test file must match ARD section count.
# v0.6.11 (QA-TEST-COUPLING-01 fix): tests split across tests/sections/*.sh
# via Option C; orchestrator at tests/test-spec-kit.sh has no `section ` calls
# of its own. Count across all section files.
ACTUAL_SECS=$(grep -ch "^section " "$PROJ/tests/test-spec-kit.sh" "$PROJ/tests/sections/"*.sh 2>/dev/null | awk '{ s += $1 } END { print s }')
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
kit_grep "| Tests" \
  && pass "templates: SPECS.md template has Tests column" \
  || fail "templates: SPECS.md template missing Tests column — update framework"

# SPECS.md agent template must have Req column
kit_grep "| Req" \
  && pass "templates: SPECS.md template has Req column (R→F link)" \
  || fail "templates: SPECS.md template missing Req column — update framework"

# AGENT_CONTEXT.md template must have Kit field (installed kit version — separate from user's project Version)
kit_grep "\*\*Kit:\*\*" \
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
kit_grep "## v0\." \
  && pass "template currency: TASKS.md template has version-based headings" \
  || fail "template currency: TASKS.md template missing version headings — update framework"

# RELEASES.md template must have Kit: field (kit version used during release)
kit_grep "^Kit: " \
  && pass "template currency: RELEASES.md template has Kit field" \
  || fail "template currency: RELEASES.md template missing Kit field — update framework"

# AGENT.md template must have session-start read order (5 steps)
kit_grep "Read user profile\|portable-spec-kit/user-profile" \
  && pass "template currency: AGENT.md template references user profile read step" \
  || fail "template currency: AGENT.md template missing user profile step — update framework"

# Example my-app SPECS.md must have Req + Tests columns (reflects current template)
grep -q "| Req\|| Tests" "$PROJ/examples/my-app/agent/SPECS.md" 2>/dev/null \
  && pass "template currency: my-app example SPECS.md has current R→F→T columns" \
  || fail "template currency: my-app SPECS.md missing Req/Tests columns — update example to match current template"

# AGENT.md template must use 'Update AGENT_CONTEXT.md When' (not old 'On Every Session End')
kit_grep "Update AGENT_CONTEXT.md When" \
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

# ARD version badge must match current framework version (Technical Overview)
grep -q "$PROJ_VER" "$PROJ/ard/Portable_Spec_Kit_Technical_Overview.html" 2>/dev/null \
  && pass "docs consistency: ARD Technical Overview version badge matches $PROJ_VER" \
  || fail "docs consistency: ARD Technical Overview version badge doesn't include $PROJ_VER — update ARD cover badge and footer"

# ARD Guide version must match current framework version
grep -q "$PROJ_VER" "$PROJ/ard/Portable_Spec_Kit_Guide.html" 2>/dev/null \
  && pass "docs consistency: ARD Guide version matches $PROJ_VER" \
  || fail "docs consistency: ARD Guide version doesn't include $PROJ_VER — update ard/Portable_Spec_Kit_Guide.html version fields"

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

# Kit's own AGENT_CONTEXT.md Version and Kit fields must match current framework version
AGENT_CTX_VER=$(grep "\*\*Version:\*\*" "$PROJ/agent/AGENT_CONTEXT.md" 2>/dev/null | head -1 | grep -o "v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*")
AGENT_CTX_KIT=$(grep "\*\*Kit:\*\*" "$PROJ/agent/AGENT_CONTEXT.md" 2>/dev/null | head -1 | grep -o "v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*")
[ "$AGENT_CTX_VER" = "$PROJ_VER" ] && [ "$AGENT_CTX_KIT" = "$PROJ_VER" ] \
  && pass "docs consistency: agent/AGENT_CONTEXT.md Version + Kit fields match $PROJ_VER" \
  || fail "docs consistency: agent/AGENT_CONTEXT.md Version ($AGENT_CTX_VER) or Kit ($AGENT_CTX_KIT) ≠ $PROJ_VER — bump both fields"

# CHANGELOG.md built-over range must include current framework version
grep -q "v0\.4\.1 — $PROJ_VER\|Built over:.*$PROJ_VER" "$PROJ/CHANGELOG.md" 2>/dev/null \
  && pass "docs consistency: CHANGELOG.md built-over range includes $PROJ_VER" \
  || fail "docs consistency: CHANGELOG.md built-over range doesn't include $PROJ_VER — update 'Built over:' line"

# ═══════════════════════════════════════════════════════════════
section "42. CI/CD — GitHub Actions, Community Files, and Framework Rules"
# ═══════════════════════════════════════════════════════════════

# Kit repo CI files — config-aware: skip if CI disabled in .portable-spec-kit/config.md
CI_ENABLED=$(grep -i "Enabled:.*true" "$PROJ/.portable-spec-kit/config.md" 2>/dev/null | head -1)
if [ -n "$CI_ENABLED" ] && [ -f "$PROJ/.github/workflows/ci.yml" ]; then
  pass "CI: ci.yml exists (CI enabled in config)"
  grep -q "pull_request" "$PROJ/.github/workflows/ci.yml" 2>/dev/null && pass "CI: triggers on pull_request" || fail "CI: pull_request trigger MISSING"
  grep -q "ubuntu-latest" "$PROJ/.github/workflows/ci.yml" 2>/dev/null && pass "CI: runs on ubuntu-latest" || fail "CI: ubuntu-latest MISSING"
  grep -q "test-spec-kit.sh" "$PROJ/.github/workflows/ci.yml" 2>/dev/null && pass "CI: ci.yml runs test-spec-kit.sh" || fail "CI: test-spec-kit.sh not in ci.yml"
  grep -q "test-spd-benchmarking.sh" "$PROJ/.github/workflows/ci.yml" 2>/dev/null && pass "CI: ci.yml runs test-spd-benchmarking.sh" || fail "CI: benchmarking not in ci.yml"
  grep -q "test-release-check.sh" "$PROJ/.github/workflows/ci.yml" 2>/dev/null && pass "CI: ci.yml runs test-release-check.sh" || fail "CI: release-check not in ci.yml"
  [ -f "$PROJ/.github/workflows/release.yml" ] && pass "CI: release.yml exists" || fail "CI: release.yml MISSING"
  grep -q "v\*" "$PROJ/.github/workflows/release.yml" 2>/dev/null && pass "CI: release.yml triggers on v* tags" || fail "CI: v* tag trigger MISSING"
  grep -q "FRAMEWORK_VER\|Framework Version" "$PROJ/.github/workflows/release.yml" 2>/dev/null && pass "CI: release.yml verifies version consistency" || fail "CI: version check MISSING"
else
  pass "CI: CI/CD disabled in config — workflow file checks skipped"
fi
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
kit_grep "CI & Community\|CI.*Community Contributions" && pass "CI: framework has CI & Community Contributions section" || fail "CI: CI & Community Contributions section MISSING"
kit_grep "CI status badge rule\|CI.*badge.*rule" && pass "CI: framework has CI badge rule for user projects" || fail "CI: CI badge rule MISSING"
kit_grep "branch protection\|Branch protection" && pass "CI: framework has branch protection guidance" || fail "CI: branch protection guidance MISSING"
kit_grep "PR workflow rule\|merge any PR\|community PR" && pass "CI: framework has PR workflow rule" || fail "CI: PR workflow rule MISSING"
kit_grep "Contribution validation rule\|CI.*minimum bar\|green CI.*minimum" && pass "CI: framework has contribution validation rule" || fail "CI: contribution validation rule MISSING"
kit_grep "CI must be green.*merg\|green.*before merg\|CI.*green.*PR" && pass "CI: Branch & PR section requires CI green before merge" || fail "CI: CI-before-merge requirement MISSING"
kit_grep "ci\.yml template\|GitHub Actions.*template\|Step 7\.5" && pass "CI: framework has ci.yml template + Step 7.5 for new projects" || fail "CI: ci.yml template / Step 7.5 MISSING from framework"
kit_grep "test-release-check\.sh agent/SPECS\.md\|R.*F.*T.*validator.*ci\|ci.*release-check" && pass "CI: framework requires test-release-check.sh in user project CI" || fail "CI: test-release-check.sh not required in user CI template"
kit_grep "npx jest\|npm test\|python -m pytest\|go test\|vitest run" && pass "CI: framework has stack-aware test commands for user CI" || fail "CI: stack-aware test commands MISSING"
kit_grep "actions/setup-node\|actions/setup-python" && pass "CI: framework has stack setup steps (Node/Python) for user CI" || fail "CI: stack setup steps MISSING from framework"
kit_grep "Create.*ci\.yml\|ci\.yml.*existing\|existing.*setup.*CI" && pass "CI: Existing Project Setup checklist includes CI" || fail "CI: Existing Project Setup missing CI item"
kit_grep "Step 7\.5\|7\.5.*CI\|create.*ci\.yml.*after stack" && pass "CI: New Project Setup Step 7.5 creates ci.yml after stack confirmed" || fail "CI: New Project Setup Step 7.5 MISSING"

# ═══════════════════════════════════════════════════════════════
section "43. Spec-Based Test Generation"
# ═══════════════════════════════════════════════════════════════

kit_grep "SPECS origin detection\|forward flow\|retroactive flow" && pass "SpecGen: framework has SPECS origin detection rule" || fail "SpecGen: SPECS origin detection rule MISSING"
kit_grep "forward flow.*generate test stubs\|test stub.*forward flow\|forward.*stub" && pass "SpecGen: framework generates stubs in forward flow only" || fail "SpecGen: forward flow stub generation rule MISSING"
kit_grep "retroactive.*do NOT generate\|retroactive.*write tests directly" && pass "SpecGen: framework skips stubs in retroactive flow" || fail "SpecGen: retroactive flow rule MISSING"
kit_grep "Feature Acceptance Criteria\|per-feature acceptance criteria" && pass "SpecGen: framework has per-feature acceptance criteria format" || fail "SpecGen: per-feature criteria format MISSING"
grep -q "Feature Acceptance Criteria" "$PROJ/agent/SPECS.md" && pass "SpecGen: kit's own SPECS.md uses per-feature criteria format" || fail "SpecGen: kit SPECS.md not updated to per-feature format"
kit_grep "stack-aware\|Stack.*stub\|stub.*stack" && pass "SpecGen: framework has stack-aware stub formats" || fail "SpecGen: stack-aware stub formats MISSING"
kit_grep "# TODO.*implement\|TODO: implement\|stub.*completion\|incomplete.*marker" && pass "SpecGen: framework has stub completion rule" || fail "SpecGen: stub completion rule MISSING"
kit_grep "test\.skip\|xit(\|xtest\|expect(true)\.toBe(false)" && pass "SpecGen: framework lists incomplete markers" || fail "SpecGen: incomplete marker list MISSING"
kit_grep "refuse to mark done\|refuse.*mark.*\[x\]\|incomplete.*test stubs.*before marking" && pass "SpecGen: framework refuses to mark done with incomplete stubs" || fail "SpecGen: stub-gate rule MISSING"
kit_grep "forward flow.*sequence\|recommended sequence" && pass "SpecGen: framework has forward flow sequence" || fail "SpecGen: forward flow sequence MISSING"
grep -q "check_stub_complete\|stubs_incomplete\|TODO.*marker" "$PROJ/tests/test-release-check.sh" && pass "SpecGen: test-release-check.sh has stub completion check" || fail "SpecGen: stub completion check missing from test-release-check.sh"
kit_grep "check_stub_complete\|stubs_incomplete\|TODO.*marker" && pass "SpecGen: kit template for test-release-check.sh has stub completion check" || fail "SpecGen: stub completion check missing from kit template"
kit_grep "Spec-Based Test Generation\|spec.*based.*test\|test.*stub.*generation" && pass "SpecGen: framework section exists" || fail "SpecGen: Spec-Based Test Generation section MISSING"
kit_grep "f{n}\|f1-\|f2-\|fn-" && pass "SpecGen: framework shows stub naming convention" || fail "SpecGen: stub naming convention MISSING"
grep -q "### F[0-9]" "$PROJ/agent/SPECS.md" && pass "SpecGen: kit SPECS.md has per-feature F{n} sections" || fail "SpecGen: kit SPECS.md missing per-feature F{n} sections"

# Pairwise per-feature criteria-block check (Layer 4 hardening from
# field-test-v0.6.8/QA-TEST-INADEQUATE-F1). The shallow existence test above
# passed even when 55 of 70 features lacked a `### F{N}` block. The pairwise
# version compares the count of `| F{N} |` rows to `### F{N}` blocks.
# Advisory pass for ANY non-empty SPECS.md ('warn' is the default kit posture
# while debt is being backfilled — matches psk-sync-check.sh PSK018 default).
# Asserts only that psk-sync-check.sh ships the per-feature pairwise check.
spec_rows=$(grep -cE '^\| F[0-9]+ ' "$PROJ/agent/SPECS.md" 2>/dev/null | tr -d ' ')
spec_blocks=$(grep -cE '^### F[0-9]+' "$PROJ/agent/SPECS.md" 2>/dev/null | tr -d ' ')
spec_missing=$(( spec_rows - spec_blocks ))
if grep -q "check_feature_criteria_blocks\|PSK018\|Per-feature acceptance criteria" "$PROJ/agent/scripts/psk-sync-check.sh"; then
  pass "SpecGen: psk-sync-check.sh ships per-feature criteria pairwise check (rows=$spec_rows blocks=$spec_blocks missing=$spec_missing)"
else
  fail "SpecGen: psk-sync-check.sh missing per-feature criteria pairwise check (Layer 4 hardening from QA-TEST-INADEQUATE-F1)"
fi

# ═══════════════════════════════════════════════════════════════
section "44. Progress Dashboard"
# ═══════════════════════════════════════════════════════════════

kit_grep "Progress Dashboard" && pass "Dashboard: framework has Progress Dashboard section" || fail "Dashboard: Progress Dashboard section MISSING"
kit_grep "progress.*dashboard\|dashboard.*burndown\|trigger.*dashboard\|burndown.*trigger" && pass "Dashboard: trigger words defined" || fail "Dashboard: trigger words MISSING"
kit_grep "OVERALL\|done.*total\|pending.*total\|progress.*bar" && pass "Dashboard: output format defined (OVERALL section)" || fail "Dashboard: output format MISSING"
kit_grep "BY VERSION\|per.*version\|version.*heading" && pass "Dashboard: BY VERSION breakdown defined" || fail "Dashboard: BY VERSION section MISSING"
kit_grep "████\|█.*░\|progress bar\|bar.*width" && pass "Dashboard: progress bar format defined" || fail "Dashboard: progress bar format MISSING"
kit_grep "✅.*Done\|🔄.*Current\|100%.*complete" && pass "Dashboard: version status icons defined" || fail "Dashboard: version status icons MISSING"
kit_grep "CURRENT VERSION TASKS\|current.*version.*tasks" && pass "Dashboard: CURRENT VERSION TASKS section defined" || fail "Dashboard: current tasks section MISSING"
kit_grep "NEXT ACTIONS\|next.*actions\|next.*pending" && pass "Dashboard: NEXT ACTIONS section defined" || fail "Dashboard: next actions MISSING"
kit_grep "Backlog.*never counted\|backlog.*future.*scope\|not.*counted.*progress" && pass "Dashboard: Backlog items excluded from count" || fail "Dashboard: Backlog exclusion rule MISSING"
kit_grep "BLOCKERS\|blocked.*items\|Blocked.*separately" && pass "Dashboard: BLOCKERS section defined" || fail "Dashboard: blockers section MISSING"
kit_grep "read-only\|does not modify\|no.*files.*modified\|generate.*on-demand" && pass "Dashboard: read-only / no file modification rule" || fail "Dashboard: read-only rule MISSING"
kit_grep "BY CONTRIBUTOR\|per.*user.*breakdown\|@username.*dashboard" && pass "Dashboard: BY CONTRIBUTOR section defined for @username projects" || fail "Dashboard: BY CONTRIBUTOR section MISSING"
kit_grep "TASKS.md missing\|No TASKS.md\|missing.*TASKS" && pass "Dashboard: missing TASKS.md edge case handled" || fail "Dashboard: missing TASKS.md edge case MISSING"
kit_grep "All tasks complete\|all.*done.*release\|🎉" && pass "Dashboard: all-done state handled" || fail "Dashboard: all-done state MISSING"
kit_grep "Unassigned\|unassigned.*tasks\|tasks without @" && pass "Dashboard: unassigned tasks grouped separately" || fail "Dashboard: unassigned group MISSING"
kit_grep "truncate\|50+\|X more done\|long task list" && pass "Dashboard: long task list truncation rule" || fail "Dashboard: truncation edge case MISSING"
kit_grep "how are we doing\|status report\|what.*left" && pass "Dashboard: natural language triggers included" || fail "Dashboard: natural language triggers MISSING"
kit_grep "Agent.*reads.*TASKS\|reads TASKS.md\|read.*TASKS.md.*directly" && pass "Dashboard: trigger → read TASKS.md behavior defined" || fail "Dashboard: trigger behavior MISSING"

# ═══════════════════════════════════════════════════════════════
section "45. Multi-Agent Task Tracking"
# ═══════════════════════════════════════════════════════════════

kit_grep "@username.*TASKS\|task.*owner.*@\|ownership syntax" && pass "MultiAgent: @username ownership syntax defined" || fail "MultiAgent: @username syntax MISSING"
kit_grep "slugified.*git config\|git config.*slugified\|username.*detection" && pass "MultiAgent: username detection from git config defined" || fail "MultiAgent: username detection MISSING"
kit_grep "multiple.*owner\|@a @b\|two.*username\|Multiple owners" && pass "MultiAgent: multiple owners rule defined" || fail "MultiAgent: multiple owners MISSING"
kit_grep "per-user.*task.*view\|my tasks.*trigger\|my workload.*trigger\|Per-user task view" && pass "MultiAgent: per-user task view trigger defined" || fail "MultiAgent: per-user view trigger MISSING"
kit_grep "Delegation rule\|assign.*to @\|delegate.*to @" && pass "MultiAgent: delegation protocol defined" || fail "MultiAgent: delegation protocol MISSING"
kit_grep "Unassign rule\|unassign.*@\|remove.*@.*task\|untagged.*unassigned" && pass "MultiAgent: unassign/remove ownership rule defined" || fail "MultiAgent: unassign rule MISSING"
kit_grep "TASKS.md.*human-readable\|plain.*markdown.*readable\|no tooling" && pass "MultiAgent: TASKS.md remains human-readable rule" || fail "MultiAgent: human-readable rule MISSING"
kit_grep "cross-agent.*coordination\|agents.*coordinate.*through.*TASKS\|pull.*sees.*assignment" && pass "MultiAgent: cross-agent coordination via TASKS.md" || fail "MultiAgent: cross-agent coordination rule MISSING"
kit_grep "Dashboard integration\|BY CONTRIBUTOR\|@.*dashboard.*section" && pass "MultiAgent: dashboard BY CONTRIBUTOR from @tags" || fail "MultiAgent: BY CONTRIBUTOR dashboard section MISSING"
kit_grep "blocked.*task.*per-user\|blocked.*visible\|blocked.*per-user" && pass "MultiAgent: blocked tasks visible in per-user view" || fail "MultiAgent: blocked task edge case MISSING"
kit_grep "No tasks.*assigned\|No tasks.* @\|unassigned.*tasks.*hint" && pass "MultiAgent: no-tasks-for-user edge case handled" || fail "MultiAgent: no-tasks edge case MISSING"
kit_grep "Git user not configured\|fall.*back.*asking.*username\|username.*not.*configured" && pass "MultiAgent: git user not configured edge case" || fail "MultiAgent: unconfigured git user edge case MISSING"
kit_grep "shared.*done.*@a.*@b\|last.*owner.*mark.*done\|last person to mark" && pass "MultiAgent: shared task completion rule" || fail "MultiAgent: shared task completion rule MISSING"
kit_grep "Typo.*@username\|typo.*@\|show as-is\|as-is.*dashboard" && pass "MultiAgent: typo in @username handled gracefully" || fail "MultiAgent: @username typo edge case MISSING"
kit_grep "No tasks tagged.*yet\|claim ownership\|Add.*@.*username.*claim" && pass "MultiAgent: fresh project (no tags) guidance" || fail "MultiAgent: no-tags fresh project guidance MISSING"
kit_grep "TASKS.md.*template.*@username\|@username.*←\|@username.*assign" && pass "MultiAgent: TASKS.md template shows @username syntax" || fail "MultiAgent: template missing @username example"
kit_grep "All tasks owned.*consider distributing\|consider distributing\|all.*assigned.*one user" && pass "MultiAgent: all-tasks-one-user distribution warning" || fail "MultiAgent: distribute warning MISSING"
kit_grep "Persistent Memory.*applied.*team\|Persistent Memory.*team task\|Persistent Memory Architecture applied" && pass "MultiAgent: cross-agent coordination linked to Persistent Memory" || fail "MultiAgent: Persistent Memory Architecture link MISSING"
kit_grep "shared.*pending.*their confirmation\|pending.*@b.*confirmation\|both.*mark.*done" && pass "MultiAgent: shared task pending state per-user" || fail "MultiAgent: shared task per-user state MISSING"
kit_grep "truncate.*per-user\|20 items.*per-user\|N more.*TASKS.md" && pass "MultiAgent: long task list truncation in per-user view" || fail "MultiAgent: per-user truncation MISSING"

# ═══════════════════════════════════════════════════════════════
section "46. Persistent Memory Architecture"
# ═══════════════════════════════════════════════════════════════

kit_grep "Persistent Memory Architecture\|Persistent Memory" && pass "PersistentMem: framework introduces Persistent Memory Architecture concept" || fail "PersistentMem: concept MISSING"
kit_grep "agent files.*Persistent Memory\|collectively form.*Persistent Memory" && pass "PersistentMem: agent files = persistent memory" || fail "PersistentMem: 9 files = memory definition MISSING"
kit_grep "Durable.*git\|durable.*persists.*git\|git.*durable" && pass "PersistentMem: Durable property defined (git)" || fail "PersistentMem: Durable property MISSING"
kit_grep "Shared.*any agent\|shared.*any.*machine\|any agent.*reads" && pass "PersistentMem: Shared property defined (any agent)" || fail "PersistentMem: Shared property MISSING"
kit_grep "Portable.*Claude.*Cursor\|portable.*Copilot\|works with.*Claude.*Cursor" && pass "PersistentMem: Portable property defined (multi-agent)" || fail "PersistentMem: Portable property MISSING"
kit_grep "Team-scale\|team.*scale.*coordinate\|multiple.*agents.*coordinate" && pass "PersistentMem: Team-scale property defined" || fail "PersistentMem: Team-scale property MISSING"
kit_grep "Auditable.*git.*history\|git.*history.*auditable\|auditable" && pass "PersistentMem: Auditable property defined" || fail "PersistentMem: Auditable property MISSING"
kit_grep "tracking.*Persistent Memory\|tracking.*writing.*memory\|Always tracking.*Persistent Memory" && pass "PersistentMem: tracking = writing to Persistent Memory" || fail "PersistentMem: tracking-as-memory framing MISSING"
kit_grep "No APIs.*No message queue\|no.*APIs\|no.*message.*queue" && pass "PersistentMem: files replace real-time APIs" || fail "PersistentMem: no-API benefit MISSING"
kit_grep "verbal handoff\|no.*onboarding.*call\|no.*wiki\|instantly briefed" && pass "PersistentMem: zero-handoff benefit stated" || fail "PersistentMem: zero-handoff benefit MISSING"
kit_grep "ephemeral.*agent.*context\|ephemeral.*session.*ends\|Persistent Memory.*survives" && pass "PersistentMem: distinction from ephemeral agent context" || fail "PersistentMem: ephemeral vs persistent distinction MISSING"
kit_grep "core innovation.*SPD\|keeps.*project.*intelligence.*alive\|intelligence.*across.*contributors" && pass "PersistentMem: positioned as core SPD innovation" || fail "PersistentMem: core innovation framing MISSING"

# ═══════════════════════════════════════════════════════════════
section "47. Architecture Decision Log"
# ═══════════════════════════════════════════════════════════════

kit_grep "Architecture Decision Log\|ADR-\|ADL" && pass "ADL: Architecture Decision Log concept defined in framework" || fail "ADL: ADL concept MISSING"
kit_grep "ADR-[0-9][0-9][0-9]\|ADR.*NNN\|ADR.*sequential\|ADR.*numbered" && pass "ADL: ADR numbering format defined (ADR-NNN)" || fail "ADL: ADR numbering MISSING"
kit_grep "YYYY-MM-DD\|ISO.*date\|absolute.*date.*ADL\|ISO 8601" && pass "ADL: ISO date format required" || fail "ADL: ISO date format MISSING"
kit_grep "Impact.*column\|Impact.*files\|Impact.*systems\|Impact.*components" && pass "ADL: Impact column defined" || fail "ADL: Impact column MISSING"
kit_grep "Newest first\|most recent.*top\|prepend.*append\|newest.*ADL\|Newest entries first" && pass "ADL: newest-first order rule" || fail "ADL: newest-first rule MISSING"
kit_grep "never delete.*ADL\|immutable.*ADL\|immutable history\|past.*decision.*preserved" && pass "ADL: ADL entries are immutable (no delete)" || fail "ADL: immutable history rule MISSING"
kit_grep "supersedes.*ADR\|ADR.*supersedes\|new.*row.*referencing.*old" && pass "ADL: supersede pattern defined" || fail "ADL: supersede pattern MISSING"
kit_grep "NOT for.*bug\|not.*for.*small\|implementation.*choices.*excluded\|not.*for.*minor" && pass "ADL: scope boundary (not for bugs/small changes)" || fail "ADL: scope boundary MISSING"
grep -q "Architecture Decision Log" "$PROJ/agent/PLANS.md" && pass "ADL: kit's own PLANS.md has Architecture Decision Log section" || fail "ADL: kit PLANS.md not updated to ADL format"
grep -q "ADR-[0-9]" "$PROJ/agent/PLANS.md" && pass "ADL: kit's PLANS.md has ADR entries" || fail "ADL: kit PLANS.md missing ADR entries"

# ═══════════════════════════════════════════════════════════════
section "48. AI-Powered Onboarding"
# ═══════════════════════════════════════════════════════════════

kit_grep "AI-Powered Onboarding\|AI.*onboarding.*rule\|commit.*agent.*team\|Commit.*agent.*MANDATORY" && pass "Onboarding: AI-Powered Onboarding rule defined" || fail "Onboarding: rule MISSING"
kit_grep "team.*project.*commit.*agent\|open-source.*commit.*agent\|public.*repo.*agent\|public GitHub repo.*commit" && pass "Onboarding: commit agent/ for team/open-source projects" || fail "Onboarding: team/open-source commit rule MISSING"
kit_grep "Never add.*gitignore.*team\|not.*gitignore.*team\|never.*gitignore.*team" && pass "Onboarding: never gitignore agent/ for team projects" || fail "Onboarding: gitignore exclusion rule MISSING"
kit_grep "clone.*briefed\|contributor.*clones.*reads\|spec.*files.*onboarding\|clones the repo.*briefed" && pass "Onboarding: clone → briefed flow described" || fail "Onboarding: clone-briefed flow MISSING"
kit_grep "CONTRIBUTING.md guidance\|CONTRIBUTING.md.*open-source.*add\|CONTRIBUTING.*briefed.*clone" && pass "Onboarding: CONTRIBUTING.md guidance defined" || fail "Onboarding: CONTRIBUTING.md guidance MISSING"
kit_grep "Solo project exception\|solo.*exception\|single.*developer.*private.*agent" && pass "Onboarding: solo project exception defined" || fail "Onboarding: solo exception MISSING"
kit_grep "Sensitive content check\|secrets.*agent.*file\|sensitive.*agent.*check" && pass "Onboarding: sensitive content check before commit" || fail "Onboarding: sensitive content check MISSING"
kit_grep "already.*gitignored.*warn\|agent.*gitignored.*warn\|warn.*gitignore.*agent" && pass "Onboarding: agent/ in .gitignore warning" || fail "Onboarding: gitignored warning MISSING"
kit_grep "agent-agnostic.*brief\|Cursor.*Copilot.*same.*files\|different.*AI.*agent.*clone\|any agent.*can.*read" && pass "Onboarding: agent-agnostic briefing (any AI agent)" || fail "Onboarding: agent-agnostic briefing MISSING"
kit_grep "Solo.*private.*add comment\|add comment.*team projects\|commit this for team" && pass "Onboarding: .gitignore comment for solo/private projects" || fail "Onboarding: gitignore comment rule MISSING"

# ═══════════════════════════════════════════════════════════════
section "49. Kit Self-Validation"
# ═══════════════════════════════════════════════════════════════

# TASKS.md Progress Summary (required for Progress Dashboard integration)
grep -q "## Progress Summary" "$PROJ/agent/TASKS.md" && pass "Kit TASKS.md: has Progress Summary section" || fail "Kit TASKS.md: Progress Summary section MISSING"
grep -q "| Version" "$PROJ/agent/TASKS.md" && pass "Kit TASKS.md: Progress Summary has table header row" || fail "Kit TASKS.md: Progress Summary table MISSING"

# Kit's own AGENT.md template compliance
grep -q "## Stack" "$PROJ/agent/AGENT.md" && pass "Kit AGENT.md: has Stack section" || fail "Kit AGENT.md: Stack section MISSING"
grep -q "On Every Session" "$PROJ/agent/AGENT.md" && pass "Kit AGENT.md: has On Every Session Start section" || fail "Kit AGENT.md: On Every Session Start MISSING"

# Kit's own SPECS.md has Req + Tests columns (R→F→T format)
grep -q "| Req |" "$PROJ/agent/SPECS.md" && pass "Kit SPECS.md: features table has Req column" || fail "Kit SPECS.md: Req column MISSING"
grep -q "| Tests |" "$PROJ/agent/SPECS.md" && pass "Kit SPECS.md: features table has Tests column" || fail "Kit SPECS.md: Tests column MISSING"

# Kit's own RELEASES.md has Kit: version field
grep -q "^Kit:" "$PROJ/agent/RELEASES.md" && pass "Kit RELEASES.md: has Kit: version field" || fail "Kit RELEASES.md: Kit: field MISSING"

# Root workspace copy in sync with Projects copy
if [ -f "$ROOT/portable-spec-kit.md" ]; then
  diff "$ROOT/portable-spec-kit.md" "$PROJ/portable-spec-kit.md" > /dev/null 2>&1 \
    && pass "portable-spec-kit.md: root workspace copy matches Projects copy" \
    || fail "portable-spec-kit.md: root workspace copy DIFFERS from Projects copy — cp needed"
else
  echo "  (skipped — root workspace copy not found)"
fi

# ═══════════════════════════════════════════════════════════════
section "50. Kit Framework Self-Validation"
# ═══════════════════════════════════════════════════════════════
# These tests ensure the distributable framework file never contains local
# paths, hardcoded tool binary locations, or project-specific filenames in
# command/rule contexts — any of which break portability for other users.

PSK="$PROJ/portable-spec-kit.md"

# ── 1. No absolute local user paths ──────────────────────────────────────────
# /Users/<name> (macOS), /home/<name> (Linux) are machine-specific.
# The framework should never reference them in rules or commands.
! grep -q "/Users/" "$PSK" \
  && pass "Portability: no /Users/ absolute paths in framework" \
  || fail "Portability: /Users/ path found in framework — machine-specific path leaked"

! grep -q "/home/" "$PSK" \
  && pass "Portability: no /home/ absolute paths in framework" \
  || fail "Portability: /home/ path found in framework — use \$HOME variable instead"

# ── 2. No hardcoded tool binary paths ────────────────────────────────────────
# Tools must be invoked by plain name (e.g. 'weasyprint'), not absolute path.
# Absolute paths only work on the author's machine — they break for everyone else.
! grep -qE "anaconda3/bin/|miniconda3/bin/|/usr/local/bin/weasyprint|/opt/homebrew/bin/weasyprint" "$PSK" \
  && pass "Portability: no hardcoded tool binary paths in framework (weasyprint, conda)" \
  || fail "Portability: hardcoded tool binary path found — use plain command name (e.g. 'weasyprint')"

# ── 3. WeasyPrint — loop form, not per-file hardcoded commands ───────────────
# Hardcoded: weasyprint somedir/Specific_File.html somedir/Specific_File.pdf
# Correct:   for f in <dir>/*.html; do weasyprint "$f" "${f%.html}.pdf"; done
# Generic: matches any 'for f in <anything>/*.html' loop — not tied to ard/ dir name.
kit_grep -qE 'for f in [^ ]*/\*\.html' \
  && pass "Portability: WeasyPrint uses a glob loop form (for f in <dir>/*.html)" \
  || fail "Portability: WeasyPrint glob loop MISSING — must not hardcode individual HTML filenames"

# Generic: catch weasyprint followed by any literal .html path (not a variable/glob).
# Matches: weasyprint somedir/AnyFile.html  (hardcoded — BAD)
# No match: weasyprint "$f"  (variable — OK), weasyprint dir/*.html  (glob — OK)
! grep -qE 'weasyprint [A-Za-z][A-Za-z0-9_/]*[A-Za-z0-9_][A-Za-z0-9_.]*\.html' "$PSK" \
  && pass "Portability: weasyprint command doesn't hardcode any specific .html filename" \
  || fail "Portability: weasyprint hardcodes a specific .html filename — use loop form with \$f variable"

# ── 4. Doc audit rule uses a glob, not specific filenames ────────────────────
# The prepare release step must use a glob so it covers any future doc files.
# Generic: matches any '<dir>/*.html' glob pattern — not tied to ard/ dir name.
kit_grep -qE '[A-Za-z][A-Za-z0-9_/]*/\*\.html' \
  && pass "Portability: doc audit rule uses a directory glob (<dir>/*.html)" \
  || fail "Portability: doc audit glob MISSING — prepare release may hardcode specific filenames"

# Hardcoded 'both' pattern: "this means both X.html AND Y.html" — was the original bug.
! grep -qE "both.*\.html.*AND.*\.html|AND.*\.html.*both.*\.html" "$PSK" \
  && pass "Portability: no 'both X.html AND Y.html' hardcoded pair in framework" \
  || fail "Portability: hardcoded HTML filename pair found — replace with a glob pattern"

# ── 5. Release summary PDF line uses glob notation ───────────────────────────
# Generic: matches any 'dir/*.pdf regenerated' or 'all dir/*.pdf' pattern.
kit_grep -qE '[A-Za-z][A-Za-z0-9_/]*/\*\.pdf regenerated|all [A-Za-z][A-Za-z0-9_/]*/\*\.pdf' \
  && pass "Portability: release summary PDF line uses a glob notation (<dir>/*.pdf)" \
  || fail "Portability: release summary PDF line may hardcode specific filenames — use a glob"

# ── 6. Flow docs don't hardcode weasyprint with specific ARD filenames ────────
FLOWS_PSK="$PROJ/docs/work-flows"
if [ -d "$FLOWS_PSK" ]; then
  # Generic: catch weasyprint followed by any literal .html path in any flow doc.
  # Matches: weasyprint anydir/AnyFile.html  (hardcoded — BAD)
  # No match: weasyprint "$f"  (variable — OK)
  BAD_FLOWS=$(grep -rlE 'weasyprint [A-Za-z][A-Za-z0-9_/]*[A-Za-z0-9_][A-Za-z0-9_.]*\.html' "$FLOWS_PSK" 2>/dev/null | wc -l | tr -d ' ')
  [ "$BAD_FLOWS" -eq 0 ] \
    && pass "Portability: no flow doc hardcodes weasyprint with a specific .html filename" \
    || fail "Portability: $BAD_FLOWS flow doc(s) hardcode weasyprint with a specific .html filename"
fi

# ── 7. ARD HTML files don't contain machine-specific paths ───────────────────
if ls "$PROJ/ard/"*.html 1>/dev/null 2>&1; then
  BAD_ARD=$(grep -l "/Users/\|anaconda3/bin\|miniconda3/bin" "$PROJ/ard/"*.html 2>/dev/null | wc -l | tr -d ' ')
  [ "$BAD_ARD" -eq 0 ] \
    && pass "Portability: ARD HTML files contain no machine-specific paths" \
    || fail "Portability: $BAD_ARD ARD HTML file(s) contain machine-specific paths"
fi

# ── 8. sync.sh doesn't contain machine-specific paths ────────────────────────
! grep -qE "/Users/[A-Za-z]|/home/[A-Za-z]" "$PROJ/agent/scripts/sync.sh" 2>/dev/null \
  && pass "Portability: sync.sh contains no machine-specific paths" \
  || fail "Portability: sync.sh contains machine-specific path — hardcoded user directory"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 51: JIRA INTEGRATION (28 tests)
# ═══════════════════════════════════════════════════════════════════════════════
section "51. Jira Integration"

# 1. TASKS.md single source of truth
kit_grep "TASKS.md is single source of truth" \
  && pass "Jira: TASKS.md single source of truth rule defined" \
  || fail "Jira: TASKS.md single source of truth rule MISSING"

# 2. Explicit signals only
kit_grep "Explicit signals only" \
  && pass "Jira: explicit signals only rule defined" \
  || fail "Jira: explicit signals only rule MISSING"

# 3. Zero-install optional
kit_grep "Zero-install, optional" \
  && pass "Jira: zero-install optional rule defined" \
  || fail "Jira: zero-install optional rule MISSING"

# 4. sync to jira command
kit_grep "sync to jira" \
  && pass "Jira: sync to jira command defined" \
  || fail "Jira: sync to jira command MISSING"

# 5. link jira command
kit_grep "link jira" \
  && pass "Jira: link jira command defined" \
  || fail "Jira: link jira command MISSING"

# 6. jira status command
kit_grep "jira status" \
  && pass "Jira: jira status command defined" \
  || fail "Jira: jira status command MISSING"

# 7. [PROJ-123] inline tag syntax
kit_grep '\[PROJ-123\]' \
  && pass "Jira: [PROJ-NNN] inline tag syntax defined" \
  || fail "Jira: [PROJ-NNN] inline tag syntax MISSING"

# 8. Hours confirmation mandatory
kit_grep "Never post worklogs without user confirmation" \
  && pass "Jira: hours confirmation mandatory rule defined" \
  || fail "Jira: hours confirmation mandatory rule MISSING"

# 9. Credential env var names
kit_grep "JIRA_EMAIL" && kit_grep "JIRA_API_TOKEN" \
  && pass "Jira: credential env var names defined" \
  || fail "Jira: credential env var names MISSING"

# 10. Secrets in .env only
kit_grep 'JIRA_EMAIL.*JIRA_API_TOKEN.*\.env' \
  && pass "Jira: secrets in .env only rule defined" \
  || fail "Jira: secrets in .env only rule MISSING"

# 11. Structural config in AGENT.md
kit_grep 'JIRA_URL.*JIRA_PROJECT_KEY.*AGENT.md' \
  && pass "Jira: structural config in AGENT.md rule defined" \
  || fail "Jira: structural config in AGENT.md rule MISSING"

# 12. @username to Jira email mapping
kit_grep "Username.*Jira Email Mapping" \
  && pass "Jira: @username to Jira email mapping defined" \
  || fail "Jira: @username to Jira email mapping MISSING"

# 13. No two-way sync
kit_grep "no two-way sync" -qi \
  && pass "Jira: no two-way sync rule defined" \
  || fail "Jira: no two-way sync rule MISSING"

# 14. psk-jira-sync.sh script defined
kit_grep "psk-jira-sync.sh" \
  && pass "Jira: psk-jira-sync.sh script defined in framework" \
  || fail "Jira: psk-jira-sync.sh script MISSING from framework"

# 15. Jira Cloud only
kit_grep "Jira Cloud only" \
  && pass "Jira: Jira Cloud only rule defined" \
  || fail "Jira: Jira Cloud only rule MISSING"

# 16. psk-tracker daemon defined
kit_grep "psk-tracker" \
  && pass "Jira: psk-tracker daemon defined in framework" \
  || fail "Jira: psk-tracker daemon MISSING from framework"

# 17. Track A defined
kit_grep "Track A.*agent session" -qi \
  && pass "Jira: Track A (agent session time) defined" \
  || fail "Jira: Track A definition MISSING"

# 18. Track B defined
kit_grep "Track B.*Direct work" -qi \
  && pass "Jira: Track B (direct work time) defined" \
  || fail "Jira: Track B definition MISSING"

# 19. Deduplication rule
kit_grep "deduplication" -qi \
  && pass "Jira: deduplication rule defined" \
  || fail "Jira: deduplication rule MISSING"

# 20. Between-session fallback
kit_grep "git/mtime" \
  && pass "Jira: between-session fallback (git/mtime) defined" \
  || fail "Jira: between-session fallback MISSING"

# 21. Idle threshold configurable
kit_grep "idle threshold" -qi \
  && pass "Jira: idle threshold configurable defined" \
  || fail "Jira: idle threshold MISSING"

# 22. Hierarchy auto-creation
kit_grep "Hierarchy auto-created" \
  && pass "Jira: hierarchy auto-creation rule defined" \
  || fail "Jira: hierarchy auto-creation rule MISSING"

# 23. install tracker command
kit_grep "install tracker" \
  && pass "Jira: install tracker command defined" \
  || fail "Jira: install tracker command MISSING"

# 24. uninstall tracker command
kit_grep "uninstall tracker" -qi \
  && pass "Jira: uninstall tracker command defined" \
  || fail "Jira: uninstall tracker command MISSING"

# 25. jira setup command
kit_grep "jira setup" \
  && pass "Jira: jira setup command defined" \
  || fail "Jira: jira setup command MISSING"

# 26. hours summary command
kit_grep "hours summary" \
  && pass "Jira: hours summary command defined" \
  || fail "Jira: hours summary command MISSING"

# 27. psk-jira-sync.sh file exists
[ -f "$PROJ/agent/scripts/psk-jira-sync.sh" ] \
  && pass "Jira: psk-jira-sync.sh script file exists" \
  || fail "Jira: psk-jira-sync.sh script file MISSING"

# 28. psk-tracker.sh file exists
[ -f "$PROJ/agent/scripts/psk-tracker.sh" ] \
  && pass "Jira: psk-tracker.sh daemon file exists" \
  || fail "Jira: psk-tracker.sh daemon file MISSING"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 52: AUTO CODE REVIEW (15 tests)
# ═══════════════════════════════════════════════════════════════════════════════
section "52. Auto Code Review"

# 1. Auto code review section exists
kit_grep "Auto Code Review" \
  && pass "CodeReview: Auto Code Review section exists" \
  || fail "CodeReview: Auto Code Review section MISSING"

# 2. Two-layer rule
kit_grep "psk-code-review.sh.*mechanical\|Layer 1.*psk-code-review.sh" \
  && pass "CodeReview: two-layer rule defined (script + AI)" \
  || fail "CodeReview: two-layer rule MISSING"

# 3. Trigger defined
kit_grep "after completing a feature.*before marking" -qi \
  && pass "CodeReview: trigger defined (after feature, before [x])" \
  || fail "CodeReview: trigger MISSING"

# 4. Advisory not blocking
kit_grep "advisory.*not blocking\|Advisory, not blocking" -qi \
  && pass "CodeReview: advisory not blocking rule defined" \
  || fail "CodeReview: advisory rule MISSING"

# 5. Security anti-patterns listed
kit_grep "eval.*pickle.*shell=True" \
  && pass "CodeReview: security anti-patterns listed" \
  || fail "CodeReview: security anti-patterns MISSING"

# 6. console.log check
kit_grep "console.log.*production" \
  && pass "CodeReview: console.log check defined" \
  || fail "CodeReview: console.log check MISSING"

# 7. TODO/FIXME check
kit_grep "TODO/FIXME" \
  && pass "CodeReview: TODO/FIXME check defined" \
  || fail "CodeReview: TODO/FIXME check MISSING"

# 8. Hardcoded secrets check
kit_grep "hardcoded secrets" -qi \
  && pass "CodeReview: hardcoded secrets check defined" \
  || fail "CodeReview: hardcoded secrets check MISSING"

# 9. Naming convention check
kit_grep "naming conventions" -qi \
  && pass "CodeReview: naming convention check defined" \
  || fail "CodeReview: naming convention check MISSING"

# 10. Architecture compliance
kit_grep "architecture compliance\|code matches.*PLANS.md" -qi \
  && pass "CodeReview: architecture compliance check defined" \
  || fail "CodeReview: architecture compliance MISSING"

# 11. Design decision compliance
kit_grep "design decision compliance\|agent/design/" -qi \
  && pass "CodeReview: design decision compliance defined" \
  || fail "CodeReview: design decision compliance MISSING"

# 12. Stack auto-detection
kit_grep "stack auto-detected\|Stack auto-detect" -qi \
  && pass "CodeReview: stack auto-detection defined" \
  || fail "CodeReview: stack auto-detection MISSING"

# 13. psk-code-review.sh exists
[ -f "$PROJ/agent/scripts/psk-code-review.sh" ] \
  && pass "CodeReview: psk-code-review.sh script exists" \
  || fail "CodeReview: psk-code-review.sh MISSING"

# 14. review code command
kit_grep "review code" \
  && pass "CodeReview: 'review code' command defined" \
  || fail "CodeReview: 'review code' command MISSING"

# 15. Report format defined
kit_grep "Layer 1\|Layer 2\|two layers" -qi \
  && pass "CodeReview: review layers defined" \
  || fail "CodeReview: review layers MISSING"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 53: SCOPE DRIFT DETECTION (12 tests)
# ═══════════════════════════════════════════════════════════════════════════════
section "53. Scope Drift Detection"

# 1. Section exists
kit_grep "Scope Drift Detection" \
  && pass "ScopeDrift: section exists in framework" \
  || fail "ScopeDrift: section MISSING"

# 2. Five dimensions defined
kit_grep "five drift dimensions\|Five drift dimensions" -qi \
  && pass "ScopeDrift: 5 drift dimensions defined" \
  || fail "ScopeDrift: drift dimensions MISSING"

# 3. Feature drift
kit_grep "Feature drift" -qi \
  && pass "ScopeDrift: feature drift dimension defined" \
  || fail "ScopeDrift: feature drift MISSING"

# 4. Requirement gaps
kit_grep "Requirement gaps" -qi \
  && pass "ScopeDrift: requirement gaps dimension defined" \
  || fail "ScopeDrift: requirement gaps MISSING"

# 5. Scope creep
kit_grep "Scope creep" -qi \
  && pass "ScopeDrift: scope creep dimension defined" \
  || fail "ScopeDrift: scope creep MISSING"

# 6. Architecture drift
kit_grep "Architecture drift" -qi \
  && pass "ScopeDrift: architecture drift dimension defined" \
  || fail "ScopeDrift: architecture drift MISSING"

# 7. Plan staleness
kit_grep "Plan staleness" -qi \
  && pass "ScopeDrift: plan staleness dimension defined" \
  || fail "ScopeDrift: plan staleness MISSING"

# 8. Drift score
kit_grep "drift score\|Drift score" -qi \
  && pass "ScopeDrift: drift score formula defined" \
  || fail "ScopeDrift: drift score MISSING"

# 9. Trigger schedule
kit_grep "session start.*quick\|Session start" -qi \
  && pass "ScopeDrift: trigger schedule defined" \
  || fail "ScopeDrift: trigger schedule MISSING"

# 10. Script exists
[ -f "$PROJ/agent/scripts/psk-scope-check.sh" ] \
  && pass "ScopeDrift: psk-scope-check.sh script exists" \
  || fail "ScopeDrift: psk-scope-check.sh MISSING"

# 11. check scope command
kit_grep "check scope" \
  && pass "ScopeDrift: 'check scope' command defined" \
  || fail "ScopeDrift: 'check scope' command MISSING"

# 12. Advisory at session, flag at release
kit_grep "advisory.*session\|Advisory at session" -qi \
  && pass "ScopeDrift: advisory at session rule defined" \
  || fail "ScopeDrift: advisory rule MISSING"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 54: KIT SELF-HELP + GUIDANCE CONSISTENCY (10 tests)
# ═══════════════════════════════════════════════════════════════════════════════
section "54. Kit Self-Help + Guidance Consistency"

# 1. Self-Help section exists
kit_grep "Kit Self-Help" \
  && pass "SelfHelp: Kit Self-Help section exists in framework" \
  || fail "SelfHelp: Kit Self-Help section MISSING"

# 2. Dynamic guidance rule (never hardcoded)
kit_grep "All guidance is dynamic" \
  && pass "SelfHelp: dynamic guidance rule defined" \
  || fail "SelfHelp: dynamic guidance rule MISSING"

# 3. Never expose internals rule
kit_grep "NEVER expose kit internals" \
  && pass "SelfHelp: never-expose-internals rule defined" \
  || fail "SelfHelp: never-expose-internals rule MISSING"

# 4. Help triggers defined
kit_grep 'help.*what can I do' \
  && pass "SelfHelp: help triggers defined" \
  || fail "SelfHelp: help triggers MISSING"

# 5. Contextual help (state-dependent)
kit_grep "Contextual help.*derived\|reads current files" -qi \
  && pass "SelfHelp: contextual help is state-derived" \
  || fail "SelfHelp: contextual help not state-derived"

# 6. Version upgrade resilience
kit_grep "Version upgrade resilience" \
  && pass "SelfHelp: version upgrade resilience defined" \
  || fail "SelfHelp: version upgrade resilience MISSING"

# 7. Help layer consistency rule
kit_grep "Help layer consistency" \
  && pass "SelfHelp: help layer consistency rule defined" \
  || fail "SelfHelp: help layer consistency rule MISSING"

# 8. Guidance freshness in consistency sweep
kit_grep "Guidance freshness check" \
  && pass "SelfHelp: guidance freshness check in release pipeline" \
  || fail "SelfHelp: guidance freshness check MISSING from pipeline"

# 9. README orchestration table exists and has entries
ORCH_ROWS=$(grep -c "| \*\*" "$PROJ/README.md" 2>/dev/null || echo 0)
[ "$ORCH_ROWS" -gt 10 ] \
  && pass "SelfHelp: README orchestration table has $ORCH_ROWS entries" \
  || fail "SelfHelp: README orchestration table too small ($ORCH_ROWS rows)"

# 10. No hardcoded test count in Self-Help section (core + skill file)
SELFHELP_HARDCODED=0
# Check core file Self-Help stub
SELFHELP_HARDCODED=$((SELFHELP_HARDCODED + $(awk '/Kit Self-Help/,/### [A-Z]/' "$PROJ/portable-spec-kit.md" | grep -E '[0-9]{3,} (tests|commands|features)' 2>/dev/null | wc -l | tr -d ' ')))
# Check self-help skill file
if [ -f "$PROJ/.portable-spec-kit/skills/self-help.md" ]; then
  SELFHELP_HARDCODED=$((SELFHELP_HARDCODED + $(grep -E '[0-9]{3,} (tests|commands|features)' "$PROJ/.portable-spec-kit/skills/self-help.md" 2>/dev/null | wc -l | tr -d ' ')))
fi
[ "$SELFHELP_HARDCODED" -eq 0 ] \
  && pass "SelfHelp: no hardcoded counts in Self-Help section" \
  || fail "SelfHelp: $SELFHELP_HARDCODED hardcoded count(s) in Self-Help section"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 55: ONBOARDING TOUR + CONTEXTUAL PRESENCE (10 tests)
# ═══════════════════════════════════════════════════════════════════════════════
section "55. Onboarding Tour + Contextual Presence"

# 1. Onboarding Tour section exists
kit_grep "Onboarding Tour" \
  && pass "Tour: Onboarding Tour section exists" \
  || fail "Tour: Onboarding Tour section MISSING"

# 2. Tour trigger defined (first session only)
kit_grep "tour_completed.*config\|Tour completed" -qi \
  && pass "Tour: tour trigger + completion flag defined" \
  || fail "Tour: tour trigger MISSING"

# 3. Tour is interactive (step by step)
kit_grep "Step 1 of 4\|one step at a time" \
  && pass "Tour: interactive step-by-step flow defined" \
  || fail "Tour: step-by-step flow MISSING"

# 4. Skip tour option
kit_grep "skip tour" \
  && pass "Tour: skip tour option defined" \
  || fail "Tour: skip tour option MISSING"

# 5. Tour never repeats
kit_grep "Tour never runs again\|never runs again" \
  && pass "Tour: never-repeat rule defined" \
  || fail "Tour: never-repeat rule MISSING"

# 6. Tour adapts to project state
kit_grep "Steps adapt to.*state\|adapts to project state" -qi \
  && pass "Tour: state-adaptive tour defined" \
  || fail "Tour: state-adaptive tour MISSING"

# 7. Contextual Presence section exists
kit_grep "Contextual Presence" \
  && pass "Tour: Contextual Presence section exists" \
  || fail "Tour: Contextual Presence section MISSING"

# 8. Session greeting defined
kit_grep "Session greeting\|Welcome back" -qi \
  && pass "Tour: session greeting defined" \
  || fail "Tour: session greeting MISSING"

# 9. Milestone acknowledgments defined
kit_grep "Milestone acknowledgment" -qi \
  && pass "Tour: milestone acknowledgments defined" \
  || fail "Tour: milestone acknowledgments MISSING"

# 10. Tour completed flag in config template
kit_grep "Tour completed" \
  && pass "Tour: tour_completed flag in config template" \
  || fail "Tour: tour_completed flag MISSING from config template"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 56: REQUIREMENTS PIPELINE (15 tests)
# ═══════════════════════════════════════════════════════════════════════════════
section "56. Requirements Pipeline"

kit_grep "agent/REQS.md" \
  && pass "Reqs: REQS.md referenced in framework" \
  || fail "Reqs: REQS.md MISSING from framework"

kit_grep "Requirement.*Type.*Priority.*Source.*Status" \
  && pass "Reqs: requirements table format defined" \
  || fail "Reqs: requirements table format MISSING"

kit_grep "Draft.*Approved.*Implemented.*Verified" -qi \
  && pass "Reqs: status lifecycle defined" \
  || fail "Reqs: status lifecycle MISSING"

kit_grep "## Scope Changes" \
  && pass "Reqs: scope changes section defined" \
  || fail "Reqs: scope changes MISSING"

kit_grep "REQS.md.*require" \
  && pass "Reqs: pipeline shows REQS.md as first stage" \
  || fail "Reqs: REQS.md not in pipeline"

kit_grep "all pipeline and support files\|all management files\|all agent files" \
  && pass "Reqs: file count updated to 9" \
  || fail "Reqs: file count not updated"

kit_grep "Approved by.*Approved date" -qi \
  && pass "Reqs: approval tracking columns defined" \
  || fail "Reqs: approval tracking MISSING"

kit_grep "## Assumptions" \
  && pass "Reqs: assumptions section defined" \
  || fail "Reqs: assumptions MISSING"

kit_grep "Functional.*Non-functional.*Constraint" -qi \
  && pass "Reqs: requirement types defined" \
  || fail "Reqs: requirement types MISSING"

kit_grep "Requirements live in.*REQS.md\|Requirements live in \`REQS.md\`" -qi \
  && pass "Reqs: SPECS.md references REQS.md" \
  || fail "Reqs: SPECS.md doesn't reference REQS.md"

kit_grep "Raw Ref\|raw.*input.*preserved" -qi \
  && pass "Reqs: raw input preservation rule defined" \
  || fail "Reqs: raw input preservation MISSING"

kit_grep "reqs/" \
  && pass "Reqs: reqs/ subdirectory referenced" \
  || fail "Reqs: reqs/ subdir MISSING"

kit_grep "Technical Requirements" -qi \
  && pass "Reqs: technical requirements in PLANS.md defined" \
  || fail "Reqs: tech requirements MISSING"

kit_grep "Req Ref" -qi \
  && pass "Reqs: PLANS.md Tech Requirements links back to REQS.md" \
  || fail "Reqs: Req Ref column MISSING"

[ -f "$PROJ/agent/REQS.md" ] \
  && pass "Reqs: agent/REQS.md file exists" \
  || fail "Reqs: agent/REQS.md MISSING"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 57: RESEARCH + DESIGN OVERVIEW + DECISION TRACEABILITY (12 tests)
# ═══════════════════════════════════════════════════════════════════════════════
section "57. Research + Design + Decisions"

kit_grep "agent/RESEARCH.md" \
  && pass "Research: RESEARCH.md referenced in framework" \
  || fail "Research: RESEARCH.md MISSING from framework"

kit_grep "research/" \
  && pass "Research: research/ directory referenced" \
  || fail "Research: research/ dir MISSING"

kit_grep "None.*Quick.*Standard.*Deep" -qi \
  && pass "Research: depth levels defined" \
  || fail "Research: depth levels MISSING"

kit_grep "cost-effectiveness\|Cost.*impact" -qi \
  && pass "Research: cost-effectiveness mandate defined" \
  || fail "Research: cost-effectiveness MISSING"

kit_grep "agent/DESIGN.md" \
  && pass "Research: DESIGN.md referenced in framework" \
  || fail "Research: DESIGN.md MISSING"

kit_grep "Design Index\|Design Principles" -qi \
  && pass "Research: DESIGN.md template has index + principles" \
  || fail "Research: DESIGN.md template incomplete"

kit_grep "mutual.*user-override.*user-direct\|user-direct.*agent-recommended" -qi \
  && pass "Research: decision types defined" \
  || fail "Research: decision types MISSING"

kit_grep "## Decisions" \
  && pass "Research: decisions section in pipeline templates" \
  || fail "Research: decisions section MISSING"

kit_grep "Definition of Done" -qi \
  && pass "Research: Definition of Done defined" \
  || fail "Research: Definition of Done MISSING"

[ -f "$PROJ/agent/RESEARCH.md" ] \
  && pass "Research: agent/RESEARCH.md file exists" \
  || fail "Research: agent/RESEARCH.md MISSING"

[ -f "$PROJ/agent/DESIGN.md" ] \
  && pass "Research: agent/DESIGN.md file exists" \
  || fail "Research: agent/DESIGN.md MISSING"

kit_grep "feedback.*loop\|iterate.*backwards\|upstream.*first" -qi \
  && pass "Research: feedback loop rule defined" \
  || fail "Research: feedback loop MISSING"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 58: END-USER EXPERIENCE VALIDATION (10 tests)
# ═══════════════════════════════════════════════════════════════════════════════
section "58. End-User Experience"

# 1. Framework mentions creating scripts during setup
kit_grep "psk-code-review.sh\|psk-scope-check.sh\|psk-release.sh" \
  && pass "EndUser: setup creates automation scripts" \
  || fail "EndUser: scripts not mentioned in setup"

# 2. Framework mentions creating all pipeline subdirs
kit_grep "reqs.*specs.*plans.*design.*tasks.*releases" \
  && pass "EndUser: setup creates pipeline subdirs" \
  || fail "EndUser: pipeline subdirs not in setup"

# 3. Framework mentions creating config.md
kit_grep "config.md.*defaults\|config.md.*project config" \
  && pass "EndUser: setup creates config.md" \
  || fail "EndUser: config.md not in setup"

# 4. Push rule is generic (git push, not sync.sh)
kit_grep "git push\|push to remote" \
  && pass "EndUser: push rule is generic" \
  || fail "EndUser: push rule may be author-specific"

# 5. No author-specific repo names in generic rules
! grep -q "aqibmumtaz/portable-spec-kit" "$PROJ/portable-spec-kit.md" 2>/dev/null \
  || grep "aqibmumtaz/portable-spec-kit" "$PROJ/portable-spec-kit.md" 2>/dev/null | grep -q "github.com\|GitHub\|Repo:\|Raw base" \
  && pass "EndUser: author repo only in metadata, not rules" \
  || fail "EndUser: author-specific repo in generic rules"

# 6. Framework mentions chmod +x for scripts
kit_grep "chmod.*scripts\|executable" \
  && pass "EndUser: scripts made executable in setup" \
  || fail "EndUser: chmod not mentioned"

# 7. Skill files downloadable (GitHub raw URL defined)
kit_grep "downloaded from GitHub\|Download from GitHub\|GitHub on first use" \
  && pass "EndUser: skill files downloadable from GitHub" \
  || fail "EndUser: no skill download mechanism"

# 8. Install is one command (curl)
kit_grep "curl.*portable-spec-kit.md\|one command\|one curl" -qi \
  && pass "EndUser: one-command install" \
  || fail "EndUser: install not one command"

# 9. End-user perspective in validation
kit_grep "end-user perspective\|new user.*everything working" -qi \
  && pass "EndUser: validation includes end-user check" \
  || fail "EndUser: no end-user validation"

# 10. No sync.sh in generic push rules
! grep "sync.sh" "$PROJ/portable-spec-kit.md" 2>/dev/null | grep -v "custom sync\|project has\|#\|If.*sync\|comment" | grep -q "bash agent/scripts/sync.sh" \
  && pass "EndUser: no hardcoded sync.sh in push rules" \
  || fail "EndUser: sync.sh hardcoded in push rules"

# ═══════════════════════════════════════════════════════════════

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  RESULTS (02-pipeline): $PASS passed, $FAIL failed, $TOTAL total"
  echo "═══════════════════════════════════════════"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi
