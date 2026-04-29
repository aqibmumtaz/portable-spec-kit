# Skill: Multi-Agent Task Tracking
> Loaded when: User says `my tasks`, `tasks for @username`, `what do I have`, `my workload`, `assign`, or `delegate`.

---

## Multi-Agent Task Tracking

**@username ownership syntax:** Tasks in TASKS.md can be tagged with `@username` to assign an owner. Username format = slugified `git config user.name` (lowercase, spaces → dashes — same format as user profile filenames). Multiple owners allowed. Tag anywhere in the task line (end preferred). Untagged tasks = unassigned.

```markdown
- [ ] Implement login API @aqib
- [ ] Write frontend tests @sara
- [ ] Review database schema @aqib @sara   ← shared task
- [ ] Deploy to staging                     ← unassigned
```

**Per-user task view trigger:** When user says `my tasks`, `tasks for @username`, `what do I have`, or `my workload` — detect current user from `git config user.name` (slugified), filter TASKS.md for tasks tagged `@{current-user}`, show per-user task view:

```
══════════════════════════════════════════════════════════
  TASKS — @aqib  (v0.N — <project>)
══════════════════════════════════════════════════════════
  v0.N — Current
  ───────────────────────────────────────────────────────
  [ ] Implement login API
  [ ] Review database schema  (shared with @sara)
  [x] Setup project structure

  ASSIGNED TO @aqib: 3 tasks (1 done, 2 pending)
══════════════════════════════════════════════════════════
```

**Delegation rule:** When user says `assign [task] to @username` or `delegate [task] to @username`:
- Find the task line in TASKS.md by feature number or keyword match
- Add `@username` tag to that line
- Confirm: "Assigned '[task]' to @username in **ProjectName** TASKS.md"
- If already assigned → skip, confirm: "Already assigned to @username"

**Unassign rule:** When user says `unassign @username from [task]`:
- Remove that `@username` tag from the task line
- If it was the only owner → task becomes unassigned
- Confirm: "Removed @username from '[task]' — now unassigned"

**Cross-agent coordination rule:** When two users share a git repo and each has their own AI agent — the agents coordinate through TASKS.md, not direct communication. Agent A assigns task → commits → pushes. Agent B pulls → sees the new assignment → shows task in per-user view. No APIs. No real-time connection. This is Persistent Memory Architecture applied to team task management.

**Shared task rule:** A task tagged `@a @b` is shared — counts as pending for both users until the task is marked `[x]`. The last person to mark it done completes it for both.

**Dashboard integration:** If any task in TASKS.md has `@username` tags, the Progress Dashboard automatically includes a BY CONTRIBUTOR section (see Progress Dashboard above).

**TASKS.md remains human-readable:** `@username` tags are visible plain markdown. Anyone reading TASKS.md sees who owns what — no tooling required.

**Multi-agent edge cases:**
- User not in any task → "No tasks assigned to @username. Unassigned tasks: N"
- Typo in `@username` → show as-is; never silently drop
- `@username` on a blocked task → still visible in per-user view, labeled "(blocked)"
- All tasks assigned to one user → note: "All tasks owned by @username — consider distributing"
- No tags yet (fresh project) → show all unassigned tasks + hint: "No tasks tagged to you yet. Add @{your-username} to any task to claim ownership"
- Git user not configured → fall back: "What's your username? (used for task filtering)"
- Shared task `@a @b`: if @a marks done but @b hasn't → still `[ ]` in @b's view; shown as "(shared with @b — pending their confirmation)" in @a's view
- Very long task list → truncate per-user view to 20 items, show "(N more — see TASKS.md)"
