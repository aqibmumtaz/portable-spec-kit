# Skill: Session Trace (`.session-stack.md`)

> **Purpose:** Real-time conversation branching log. Prevents users from losing track of what they were working on when a chat branches deep.
>
> **Loaded when:** user mentions losing track / context / conversation-stack / "where was I" / or any multi-step task branches.

---

## Why this exists

`agent/AGENT_CONTEXT.md` captures PROJECT state across all sessions — it's too coarse and too slow to update for in-chat topic branching. Within a single conversation you can branch 5 layers deep and lose the original task. `.session-stack.md` is the missing mid-granularity layer.

## File layout

Two files, project-root:

| File | Purpose | Git |
|---|---|---|
| `.session-stack.md` | Live index + current active session tree | gitignored |
| `.session-archive/YYYY-MM-DD-HH-MM.md` | Frozen per-session tree, never deleted | gitignored |

The active session tree lives at the bottom of `.session-stack.md`. When session ends, it moves to `.session-archive/` with a filename timestamp, and `.session-stack.md` keeps a one-line index entry.

## Format — tree with node IDs and icon markers

```markdown
# Session Stack — SearchSocialTruth eval follow-up

## Session 2026-04-21-10-15 [active]

N1 ⏸ 10:15 │ G-walk — ROOT
├── N2 ⏸ 10:30 │ Template redesign
│   ├── N3 ✓ 11:20 │ v5.1 SUMMARY (be0b56c)
│   ├── N4 ✓ 11:35 │ Border rule clarified
│   └── N5 → 11:50 │ Session stack design ← CURRENT
├── N6 · 10:20 │ G1 demoed, not applied
└── N7 · 10:40 │ G2 demoed, not applied
```

### Node ID format

`N{integer}` — auto-assigned on creation, sequential within session. Used for all transitions.

### Markers (strict vocabulary segregation from `agent/TASKS.md`)

| Marker | Meaning | Replaces task-world equivalent |
|---|---|---|
| `→` | **current** — exactly one per tree | (never use `[active]` here) |
| `⏸` | **parked** — paused, can resume | (never use `[ ]`) |
| `✓` | **closed** — branch complete | (never use `[x]`) |
| `·` | **queued** — not yet started | (never use `[ ]`) |
| `✗` | **abandoned** — won't resume | (never use `[~]`) |

### Vocabulary

Branch-speak only: **opened / closed / parked / resumed / queued / abandoned**.
Never use task-speak: done / pending / in-progress / complete / acknowledged.

## State transitions — 4 automatic triggers

Agent detects these in user messages and rewrites the stack BEFORE responding:

| Trigger pattern | Action on current (`→`) | Action on target |
|---|---|---|
| `"back to <name\|ID>"` / `"resume <name\|ID>"` | `→` → `⏸` | target becomes `→` |
| `"done"` / `"next"` / task-complete signal + no new topic | `→` → `✓` (with SHA if commit landed) | parent becomes `→` |
| `"skip <name\|ID>"` / `"abandon"` | `→` → `✗` | parent becomes `→` |
| New sub-topic detected (branches current) | `→` → `⏸` | new child appended as `→` |

Invariant: **exactly one `→` node at any time**. Violation = drift.

## Commands (user-triggered)

| Phrase | Effect |
|---|---|
| `"where was I"` / `"status"` / `"context"` / `"stack"` | Agent renders current tree + runs drift check |
| `"mark <ID> done"` / `"mark <ID> ✓"` | Agent closes that node + commit SHA if available |
| `"abandon <ID>"` | Agent marks node `✗` + moves active to parent |
| `"reparent <ID> under <parent-ID>"` | Agent moves subtree |
| `"end session"` | Agent archives tree to `.session-archive/` and starts new session |

## Ambiguity handling

If a `"back to <name>"` matches 0 or >1 parked branches:

- **0 matches** → agent asks: `⚠ No parked branch matches "<name>". Closest: <suggestions>. Reply with ID.`
- **>1 matches** → agent asks: `⚠ N branches match "<name>": [list with IDs]. Reply with ID.`

Never silent guess.

## Drift detection (runs on every `"where was I"`)

Agent validates on render:
- Exactly one `→` node → else `⚠ drift: N active nodes`
- Every `✓` child → if all siblings also `✓` and parent has no pending, suggest marking parent `✓`
- Parent `✓` but has `→` / `·` children → `⚠ inconsistency: parent closed with open children`

## Auto-writes from agent

Agent MUST write to `.session-stack.md` at these moments:

| Moment | What happens |
|---|---|
| New sub-topic branched | PUSH new child `→`, old active → `⏸` |
| Commit landed matching current task | Current `→` → `✓ (SHA)`, parent → `→` |
| User triggers switch-back | Sed-edit: old `→` → `⏸`, target → `→` |
| `"where was I"` called | READ file + render tree in reply |
| Chat session ending (or inactivity trigger) | Archive current tree, stamp session closed |

All writes via `bash` append or `sed` edit — single-call, ~1 ms each.

## Overhead

| Cost | Magnitude |
|---|---|
| Write per transition | ~1 ms, ~50 bytes |
| Read on `"where was I"` | ~1 ms, whole session file ~1-10 KB |
| Per-session size at end | ~1-10 KB |
| User friction | Zero — agent-managed, user never edits by hand |

## Scalability for long sessions (MANDATORY — 3-tier compaction)

Users who work in one very long session can accumulate 100+ nodes in a single tree. Without compaction, the file grows unbounded and the tree becomes unreadable (stale `✓` noise obscures active work). Three tiers handle this without breaking any other rule.

### Tier 1 — Closed-range collapse (automatic, every render)

When 3+ consecutive sibling nodes are all `✓` with no children, collapse them to a single range line:

```
├── N11–N14 ✓ Template design iterations
```

- Trigger: 3+ adjacent `✓` siblings under the same parent
- Summary: agent-generated one-liner that covers the range's theme
- Full node detail preserved in git history — range line is display-only
- Applies on every tree render; does NOT rewrite the live file unless node count exceeds Tier-3 threshold

### Tier 2 — Active-chain render (default for `"where was I"`)

By default, tree rendering in replies shows only the **active chain + its immediate context**, not the full tree:

| Shown by default | Hidden by default |
|---|---|
| Root node and every ancestor on the active chain | Closed (`✓`) sub-trees under already-closed ancestors |
| The current `→` node and its siblings (parked / queued / abandoned) | Closed (`✓`) siblings if not collapsed via Tier 1 |
| Queued (`·`) work directly relevant to current context | Abandoned (`✗`) nodes older than the current root visit |

User commands to reveal more:
- `"show full stack"` / `"full tree"` → render entire tree including all closed sub-trees
- `"show chapter N"` → render contents of archived chapter file
- `"back to <name\|ID>"` → auto-reveal target if it's in a collapsed range or archived chapter

Target default render: ≤ 25 lines regardless of tree size.

### Tier 3 — Mid-session chapter rotation (automatic, threshold-triggered)

When the live session tree hits a size threshold, agent rotates closed sub-trees into a chapter archive and leaves a one-line reference in the live file:

| Trigger (either) | Action |
|---|---|
| `.session-stack.md` live section ≥ 15 KB | Rotate oldest fully-closed sub-trees into chapter |
| Total nodes in live tree ≥ 80 | Rotate oldest fully-closed sub-trees into chapter |

Rotation mechanics:
1. Agent identifies oldest contiguous block of fully-closed sub-trees (no `→` / `⏸` / `·` descendants)
2. Moves that block to `.session-archive/YYYY-MM-DD-chapter-NN.md` (NN is zero-padded, starts at 01)
3. Replaces the block in live file with a one-line reference:
   ```
   ├── [chapter-01: N2–N28, 27 nodes closed — see .session-archive/2026-04-21-chapter-01.md]
   ```
4. Live file shrinks; active chain + parked peers remain intact
5. Chapter files are permanent (never deleted) — the one-line reference keeps titles queryable

Rotation rules:
- Never rotate a node with a non-closed descendant (would strand active work)
- Never rotate the current `→` node or any ancestor in its active chain
- Reference line uses square brackets `[chapter-NN: ...]` — distinct from tree `N{id}` syntax so drift-check never mistakes it for a node
- `"back to <name>"` matching checks live file first, then chapter files in reverse order

### Tier tradeoffs

| Tier | Cost | Benefit |
|---|---|---|
| T1 compact | Zero — display only | Cuts visible noise immediately |
| T2 active-view | Zero — render-only filter | Keeps replies skimmable on any tree size |
| T3 rotation | ~1 file-write per 50-100 nodes | Unbounded session size becomes bounded (~15 KB live file) |

Reversibility: all three tiers are reversible. T1/T2 are render-only; T3 preserves full history in chapter files. User never loses data.

## Reading the file for context restore

Across-session: agent reads `.session-stack.md` top (index) + latest `.session-archive/*.md` if user says `"last session"`.

Within-session: agent reads current tree at bottom of `.session-stack.md` on every `"where was I"`.

## Integration with other kit rules

- **Task Tracking (MANDATORY):** `agent/TASKS.md` is still the source of truth for PROJECT tasks. Session-stack is only conversation branching. Do not move entries from one file to the other — they are different layers.
- **Response Format Rule:** Agent reply after a switch-back includes the updated tree only if user explicitly asked for it via `"where was I"`. Silent auto-updates keep the reply uncluttered.
- **Vocabulary segregation rule:** Agent NEVER uses `[x]` / `[ ]` / `[~]` in `.session-stack.md`. Agent NEVER uses `→` / `⏸` / `✓` / `·` / `✗` in `agent/TASKS.md`. Full file-format-specific vocabulary.
- **Breadcrumb Header Rule:** Every reply prepends `↳ **Nx** root › **Ny** parent › **Nz** current` followed by a `---` border — passive orientation without requiring `"where was I"`. Rule 6a adds a single trailing `› ✓**Nw** <name>` hint showing the most-recently-closed sibling of the deepest active node (or most-recently-closed child of root when active IS root), so the reader sees "what just wrapped up here" without opening the stack file. Replaced on newer close, never dropped otherwise. Rule documented in `portable-spec-kit.md` → "Breadcrumb Header Rule". Breadcrumb reads directly from this session-stack file; node-ID references (including the `✓` hint) are actionable (`"back to N7"` maps to the target node by ID regardless of its current state).

## When not to use session-stack

- Single-topic linear conversation (no branching) — stack is overhead, no value
- Brief one-shot question + answer — don't create a tree for one round-trip
- Users who prefer to re-read the chat manually — turn off via config `session_stack: disabled`
