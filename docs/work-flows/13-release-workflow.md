# Flow: Release Workflow

> **When:** User says "prepare release", "update release", or "refresh release". Agent runs steps 1–7 (tests → flow docs → counts → version bump → PDFs → RELEASES.md → CHANGELOG.md) and shows a release summary for review. **No commit. No push.** Commit and push only when explicitly instructed separately or via "prepare release and push".

## End-to-End Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. DEVELOP                                                 │
│     Write code / add rules / update templates               │
│     Add tasks to TASKS.md as you go (no-slip rule)          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. "run tests"                                             │
│     bash tests/test-spec-kit.sh          → 608 tests        │
│     bash tests/test-spd-benchmarking.sh  → 145 tests        │
│     bash tests/test-release-check.sh     → 62/62 features   │
│     Review results before continuing                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. "prepare release"  (steps 1–7, NO commit/push)          │
│                                                             │
│  Step 1   Run ALL suites to completion — collect failures   │
│           Show failure summary + fix plan → user consent    │
│  Step 2   Update flow docs FIRST — update changed flows,    │
│           create new flows, check logical order, renumber   │
│  Step 3   Update counts + ARD audit (MANDATORY) — README,   │
│           all ard/*.html: version, test count, flow table   │
│  Step 4   Bump version — AGENT_CONTEXT.md + README badge    │
│  Step 5   Generate PDFs — WeasyPrint both ard/*.html files  │
│  Step 6   Update agent/RELEASES.md — new version entry      │
│  Step 7   Update CHANGELOG.md — grouped by minor release    │
│  Step 8   Show release summary (GitHub + Tag = ⏳ pending)  │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  4. "commit"                                                │
│     Stage and commit all changes                            │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  5. "push"                                                  │
│     git push origin main                                    │
│     → pushes to remote                                      │
│     → CI runs all 3 suites on GitHub Actions                │
│     → updates v0.N tag to HEAD                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  6. VERIFY (after push)                                     │
│     CI badge turns green on GitHub (~2 min)                 │
│     GitHub Release shows correct notes                      │
│     v0.N tag points to HEAD                                 │
└─────────────────────────────────────────────────────────────┘
```

## Trigger Signals

| Signal | What it does |
|--------|-------------|
| `init` | Deep scan → create/fill agent/ files from codebase → optional changes checklist. See [05-project-init.md](05-project-init.md) |
| `reinit` | Re-scan → sync stale agent files → SPECS/PLANS staleness check. See [05-project-init.md](05-project-init.md) |
| `run tests` | Runs all 3 suites — failure summary + fix plan if any fail. No commits, no version changes |
| `prepare release` / `update release` | Steps 1–7 only — tests, flow docs, counts, ARD audit, version bump, PDFs, RELEASES.md, CHANGELOG.md + show summary. **No commit. No push.** |
| `prepare release and push` / `prepare release, commit and push` | Steps 1–7 → commit all changes → push via sync.sh → show summary (GitHub + Tag ✅) |
| `refresh release` | Steps 1–7, **no version bump** (step 4 skipped) — re-test and sync current version. **No commit. No push.** |
| `refresh release and push` / `refresh release, commit and push` | Steps 1–7 (no version bump) → commit → push via sync.sh |
| `commit` | Stages and commits — no push |
| `push` | Pre-push gate (check files changed since last prepare release) → push via sync.sh |

**Agent never auto-triggers any of these.** Wait for explicit user signal.

## The 7-Step Prepare Release Gate (+ summary)

```
┌─────────────────────────────────────────────────────────────┐
│  Step 1: Run ALL test suites to completion                  │
│     tests/test-spec-kit.sh          ← framework gate        │
│     tests/test-spd-benchmarking.sh  ← SPD benchmarking      │
│     tests/test-release-check.sh agent/SPECS.md              │
│                                    ← R→F→T + stub gate      │
│     Do NOT stop on first failure — collect all results      │
│     If failures: show failure summary + fix plan            │
│       → Ask user consent → fix → re-run → all must pass     │
│       → User declines → release stops                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 2: Update flow docs (FIRST)                           │
│     Update existing flows that describe changed processes   │
│     Create new flow docs for new processes implemented      │
│     Order check — verify 01-, 02-,... is logical user       │
│       journey; renumber if needed + update ALL references   │
│       (README, Section 19 tests, ARD HTML, CHANGELOG,       │
│       RELEASES, cross-links) — no stragglers                │
│     Box-style format, 63-char lines                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 3: Update all counts + ARD audit (MANDATORY)          │
│     README.md — version badge + test count badge            │
│     ALL ard/*.html — cover version badge, Key Highlights    │
│       (version + flow count + test count), Version          │
│       Changelog (bump Kit range, update counts), flow       │
│       diagrams section if flows changed                     │
│     Every version/test/flow count field must match          │
│     Never skip ARD updates                                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 4: Bump version  (SKIPPED for "refresh release")      │
│     agent/AGENT_CONTEXT.md — Version field (v0.N.x → next)  │
│     README.md — version badge                               │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 5: Generate PDFs (MANDATORY on every release)         │
│     for f in ard/*.html; do                                 │
│       weasyprint "$f" "${f%.html}.pdf"; done                │
│     Verify non-zero file size. GLib warnings = harmless.    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 6: Update agent/RELEASES.md                           │
│     Add/update entry for this version                       │
│     Kit range (v0.N.first — v0.N.current)                   │
│     Changes grouped by category, test results summary       │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 7: Update CHANGELOG.md                                │
│     Single grouped entry per minor release (## v0.N — Title)│
│     "Built over: v0.N.1 — v0.N.x"                           │
│     Completed releases show minor only (never per-patch)    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 8: Show release summary block                         │
│     GitHub row → ⏳ pending — run: commit and push          │
│     Tag row    → ⏳ pending — run: commit and push          │
│     ── Stops here. User reviews before committing. ──       │
└─────────────────────────────────────────────────────────────┘
```

## Release Summary Block (shown after all steps complete)

```
══════════════════════════════════════════════
  RELEASE SUMMARY — v0.N.x
══════════════════════════════════════════════
  1. Tests        Framework: X passed ✅  Benchmarking: X passed ✅
                  R→F→T: X/X features release-ready ✅
                  Total: X/X passing ✅
  2. Flows        docs/work-flows/ current ✅
  3. Counts       README, ARD, RELEASES, CHANGELOG ✅
  4. Version      v0.N.x-1 → v0.N.x ✅       (prepare/update only)
                  unchanged — v0.N.x —         (refresh only)
  5. PDFs         all ard/*.pdf regenerated ✅                
  6. RELEASES.md  updated ✅
  7. CHANGELOG.md updated ✅
  8. GitHub       ⏳ pending — run: commit and push   (prepare release)
                  published ✅                        (prepare release and push)
  9. Tag          ⏳ pending — run: commit and push   (prepare release)
                  updated ✅                          (prepare release and push)
══════════════════════════════════════════════
```

## The 3 Test Suites — What Each Gate Checks

### tests/test-spec-kit.sh — Framework Gate (48 sections)

| Section group | What it validates |
|--------------|-------------------|
| 1–10 | Core framework content — sections, rules, templates present |
| 11–20 | User profile, agent-agnostic rules, security, versioning |
| 21–30 | Existing project setup, scenarios, retro fill, context persistence |
| 31–38 | Session start, returning session, profile customization, sync |
| 39–40 | R→F traceability, R→F→T traceability chain |
| **41** | **Pre-release consistency gate** (31 tests) — see below |
| 42 | CI/CD — kit GitHub Actions files + framework CI rules for user projects |
| 43 | Spec-Based Test Generation — origin detection, stubs, completion gate |
| 44 | Progress Dashboard — triggers, output format, computation rules, edge cases |
| 45 | Multi-Agent Task Tracking — @username syntax, per-user view, delegation, coordination |
| 46 | Persistent Memory Architecture — concept, 5 properties, no-API rule |
| 47 | Architecture Decision Log — ADR format, immutability, supersede, scope boundary |
| 48 | AI-Powered Onboarding — team/OS commit rule, clone→briefed flow, agent-agnostic |

**Section 41 — Pre-Release Consistency Gate (33 tests):**

| Group | Tests | What it checks |
|-------|-------|----------------|
| 1: Count sync | 5 | README badge ↔ ARD count ↔ SPECS criteria ↔ test-spec-kit.sh section count ↔ AGENT_CONTEXT version |
| 2: R→F→T gate | 4 | Every done feature has test ref, test files exist, tests pass (via test-release-check.sh) |
| 3: Template completeness | 4 | Kit agent file templates present (SPECS Tests col, Req col, AGENT_CONTEXT Kit field, user profile path) |
| 3b: Template currency | 8 | Framework template freshness — TASKS headings, RELEASES Kit field, AGENT.md triggers, example currency, flow doc Kit refs |
| 4: Docs consistency | 12 | ARD (all ard/*.html) ↔ current Kit; flow docs Kit refs current; benchmarking fixture Kit current; example AGENT_CONTEXT.md + RELEASES.md Kit current; RELEASES.md range; kit own AGENT_CONTEXT.md Version+Kit; CHANGELOG built-over range; R→F→T in ARD; README Critical Scenarios; flow count |

### tests/test-spd-benchmarking.sh — SPD Benchmarking (145 tests)

Simulates 5 projects × 3 methodologies (SPD, agile, waterfall):
- Tests lifecycle phases: setup → spec → plan → execute → test → scope change → release
- Validates that SPD handles all 9 project scenarios (new, existing, monorepo, partial, etc.)
- Validates 4 scope change types (DROP, ADD, MODIFY, REPLACE) tracked across all pipeline files

### tests/test-release-check.sh — R→F→T + Stub Gate

For every feature in SPECS.md marked `[x]`:
1. **Test reference exists** in Tests column
2. **Test file exists** on disk at that path
3. **Stub completion check** (`check_stub_complete()`) — no `# TODO`, `test.skip`, `expect(true).toBe(false)`, `assert False`, `t.Skip()` markers
4. **Tests pass** — auto-detects runner (Jest / pytest / Go / bash) and runs
5. Reports: `✓ F1 — passing`, `⚠ NO TEST REF`, `✗ STUBS NOT FILLED (2 TODO markers)`, `✗ FAILED`

Exit 0 = all done features have passing tests = release ready.
Exit 1 = missing refs, missing files, incomplete stubs, or test failures = block release.

## Pre-Push Gate

Before every push — all 3 suites must pass. If user says "push" without having run "prepare release" in this session → run tests first, show results, then push. Never push with known failures.

```
┌─────────────────────────────────────────────────────────────┐
│  User: "push"                                               │
│     Was "prepare release" run this session?                 │
│     ├─ Yes, tests passed → push                             │
│     └─ No → run all 3 suites                                │
│           ├─ All pass → push                                │
│           └─ Any fail → show failures, stop push            │
└─────────────────────────────────────────────────────────────┘
```

## Stub Completion Gate (forward-flow features)

A feature cannot be marked `[x]` done until its test stubs are fully implemented:

```
┌─────────────────────────────────────────────────────────────┐
│  Stub generated (RED — all TODO markers)                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  User implements feature code                               │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  User fills stub implementations                            │
│     Remove TODO markers — write real assertions             │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  check_stub_complete() — grep for incomplete markers        │
│     Markers found → refuse [x], show count                  │
│                     "F1 has 2 incomplete stubs"             │
│     No markers → run tests                                  │
│       Fail → fix code, re-run                               │
│       Pass → mark [x], update Tests column in SPECS.md      │
└─────────────────────────────────────────────────────────────┘
```

## Edge Cases

| Condition | Behaviour |
|-----------|-----------|
| No test suites exist | Show "No test suites — skipping" in summary block; proceed. Required before v1.0. |
| Test failures found | Run all suites to completion. Show failure summary + fix plan. Ask user consent. Fix → re-run → all must pass before proceeding. |
| New suite added this session | Include it in summary automatically |
| test-release-check.sh shows untested features | Do NOT finalize release — add test refs to SPECS.md, ensure tests pass, re-run |
| New flow needed | Create in docs/work-flows/ with number based on logical position in user journey. If inserting mid-sequence, renumber subsequent files + update all references repo-wide. |
| Flow order wrong | Renumber affected files to restore logical sequence. Update README, Section 19 tests, ARD HTML, CHANGELOG, RELEASES, any cross-links — no stragglers. |
| GitHub release already exists | Update with `gh release edit`, not create new |
| CHANGELOG.md entry missing | Add it before publishing |
| No git tags in use | Skip tag update step, note it |
| Release notes scope | Only include changes committed and visible in public repo. Never mention private docs, research papers, local-only scripts |
| User says "prepare release" | Stop after step 7 + show summary. Do NOT commit or push. Wait for explicit instruction. |
| User says "prepare release to review" | Same as above — "to review" reinforces stop-before-push. Show summary, await confirmation. |
| User says "prepare release and push" | Run all steps 1–7 + commit + push + show summary (GitHub ✅, Tag ✅) in one sequence. |
| Changes made after prepare release | Do NOT re-run prepare release automatically. Wait for user to say "prepare release" again or "commit". |
| User commits before prepare release | Valid — commit is always separate. But prepare release still needed before push to ensure all docs are current. |
