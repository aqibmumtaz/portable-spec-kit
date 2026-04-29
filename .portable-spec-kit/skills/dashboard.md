# Skill: Progress Dashboard
> Loaded when: User says `progress`, `dashboard`, `burndown`, `status report`, `how are we doing`, or `what's left`.

---

## Progress Dashboard

**Progress dashboard trigger:** When the user says `progress`, `dashboard`, `burndown`, `status report`, `how are we doing`, or `what's left` — generate a progress dashboard immediately from `agent/TASKS.md`. No scripts required. Agent reads TASKS.md directly and computes all metrics inline.

**Dashboard output format:**
```
══════════════════════════════════════════════════════════
  PROGRESS DASHBOARD — <Project Name>  (v0.N.x)
══════════════════════════════════════════════════════════
  Version: v0.N — <Theme>

  OVERALL
  ───────────────────────────────────────────────────────
  Done:     X tasks   [████████████░░░░░░░░]  XX%
  Pending:  Y tasks
  Total:    Z tasks

  BY VERSION
  ───────────────────────────────────────────────────────
  v0.0  ████████████████████  8/8   100% ✅ Done
  v0.1  ████████████████████  14/14 100% ✅ Done
  v0.4  ████████░░░░░░░░░░░░  7/16   44% 🔄 Current

  CURRENT VERSION TASKS (v0.N)
  ───────────────────────────────────────────────────────
  [x] Task 1
  [x] Task 2
  [ ] Task 3
  [ ] Task 4

  BLOCKERS
  ───────────────────────────────────────────────────────
  (none)

  NEXT ACTIONS
  ───────────────────────────────────────────────────────
  1. <next pending task>
  2. <next pending task>
══════════════════════════════════════════════════════════
```

If `@username` tags are present in TASKS.md, add a BY CONTRIBUTOR section:
```
  BY CONTRIBUTOR
  ───────────────────────────────────────────────────────
  @aqib      ████████████░░░░░░░░  6/8   75%
  @sara      ████░░░░░░░░░░░░░░░░  2/6   33%
  Unassigned ████░░░░░░░░░░░░░░░░  2/10  20%
```

**Dashboard computation rules:**
- Parse every `- [x]` and `- [ ]` line under each version heading in TASKS.md
- Count done vs total per version group
- Compute percentage: `done / total * 100`
- Build progress bar: each `█` = 5% of 100%. Bar width = 20 chars. Right-pad with `░`.
- Use ✅ for 100% complete versions, 🔄 for in-progress versions, 🔲 for not-started versions
- Current version = heading marked `— Current` (or last non-Backlog heading if no marker present)
- Backlog items are never counted in progress — they are future scope
- Blocked items (under `### Blocked`) count as pending but are listed separately in BLOCKERS

**Dashboard is read-only:** Never auto-show. Never modify any files. Generated on-demand only.

**Dashboard edge cases:**
- TASKS.md missing → "No TASKS.md found — run `init` to set up the project"
- No version headings detected → show flat list of all done/pending tasks
- All tasks done → "🎉 All tasks complete — ready for release"
- Current version has 0 tasks → "No tasks added for this version yet"
- Very long task list (50+ items) → truncate CURRENT VERSION TASKS to first 10 done + all pending; add "(X more done tasks — see TASKS.md)"
- No `### Blocked` section → omit BLOCKERS row entirely
- Progress bar max = 20 chars — never exceed
- Backlog: show count only ("Backlog: N tasks in future scope") — do not enumerate
