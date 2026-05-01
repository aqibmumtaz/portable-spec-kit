# Flow: Release Workflow

> **When:** User says "prepare release", "update release", or "refresh release". Agent runs `bash agent/scripts/psk-release.sh prepare` which fires the bootstrap gate (Step 0) before `init_state`, then repeats `psk-release.sh next` until all 10 steps complete. Automated steps run directly. Agent steps (4, 8) pause for action. Validation is Step 9 (final gate). **No commit. No push.** Commit and push only when explicitly instructed.

## Prepare Release Flow (steps 0–10)

```
┌─────────────────────────────────────────────────────────────┐
│  Step 0: BOOTSTRAP GATE (automated, fail-fast)              │
│     bash agent/scripts/psk-bootstrap-check.sh --quiet       │
│     Runs BEFORE init_state on prepare/refresh. Verifies     │
│     kit was properly installed: scripts, hooks, skills,     │
│     config, entry-point symlinks. Catches projects          │
│     scaffolded manually by non-kit-aware agents (Copilot,   │
│     plain Claude, etc.) that skipped install.sh.            │
│     FAIL → exit 1 with remediation command. No state init.  │
│     Bypass: PSK_BOOTSTRAP_CHECK_DISABLED=1 (emergencies).   │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 1: RUN ALL TEST SUITES (automated)                    │
│     tests/test-spec-kit.sh (framework)                      │
│     tests/test-spd-benchmarking.sh (benchmarking)           │
│     tests/test-release-check.sh (R→F→T gate)                │
│     All must pass. Failures → fix → re-run.                 │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 2: CODE REVIEW (automated, config-gated)              │
│     bash agent/scripts/psk-code-review.sh                   │
│     Advisory — does not block release.                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 3: SCOPE DRIFT CHECK (automated, config-gated)        │
│     bash agent/scripts/psk-scope-check.sh                   │
│     Advisory — flagged in summary.                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 4: UPDATE DOCS — FULL SURFACE (agent + critic)        │
│     Run: bash agent/scripts/psk-doc-sync.sh                 │
│     Analyzer checks every CHANGELOG feature across 5 doc    │
│     surfaces (agent/*, flow-docs, paper, ARD, README).      │
│     Reports COVERED / PARTIAL / MISSING per feature.        │
│     Agent fills gaps: add to suggested doc OR create new    │
│       flow doc (next sequential number, update README).     │
│     Sub-agent critic re-runs analyzer at Step 9.            │
│     Loop: fix → re-run → until Missing=0.                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 5: CONSISTENCY SWEEP (automated + agent)              │
│     psk-sync-check.sh --full — now 15 checks                │
│     (PSK001–PSK015, was 8 at release):                      │
│       PSK001-004B counts/versions/SPECS-staleness           │
│       PSK005 R→F→T gate (result cached for 60× speedup)     │
│       PSK006-010 perms/dirs/CHANGELOG/ARD/Stack             │
│       PSK011 secret scanning (12 credential patterns)       │
│       PSK012 README "Latest Release" section content        │
│       PSK013 README install list counts on disk             │
│       PSK014 README agent directory table vs agent/*.md     │
│       PSK015 README flow table vs docs/work-flows/*.md      │
│     + ARD content: describe new features in ard/*.html      │
│     Mismatches → agent fixes → script re-runs.              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 6: VERSION BUMP (fully automated)                     │
│     Script reads current version, computes next patch,      │
│     seds all files automatically. Verify via sync-check.    │
│     Skipped for refresh release.                            │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 7: REGENERATE PDFs (automated)                        │
│     WeasyPrint for every ard/*.html                         │
│     Verify non-zero file size.                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 8: UPDATE RELEASES.md + CHANGELOG.md (agent + critic) │
│     Agent writes prose. Sub-agent critic verifies prose     │
│     matches what actually shipped (git log comparison).     │
│     Loop: fix → critic re-checks → until all CURRENT.       │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 9: FINAL VALIDATION — DUAL GATE (THE GATE)            │
│     Delegates to psk-validate.sh release:                   │
│       Layer 2A: psk-sync-check.sh --full (15 checks,        │
│                 PSK001–PSK015 incl. secrets + README)       │
│       Layer 2B: sub-agent critic via Task tool              │
│                 (fresh context, STEP_9_VALIDATION prompt)   │
│     Verbatim-quote gate (v0.5.15): every CURRENT verdict    │
│       must include a QUOTE: line grep-verified against the  │
│       named file. Fabricated quotes → exit 3, blocked.      │
│     Both layers must pass. Catches drift from steps 4-8.    │
│     NOTHING ships until Step 9 passes.                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Step 10: RELEASE SUMMARY                                   │
│     Evidence checklist per step.                            │
│     Stops here. User reviews before committing.             │
└─────────────────────────────────────────────────────────────┘
```

## Step Categories

| Type | Steps | What happens |
|------|-------|-------------|
| **Automated** | 1, 2, 3, 5, 6, 7, 10 | Script runs directly. Agent acts only if failures. |
| **Agent + critic** | 4, 8 | Agent does work. Sub-agent critic verifies. Loop until pass. |
| **Final gate** | 9 | Bash sync-check + sub-agent critic. Both must pass. |

## Release Summary Block

```
══════════════════════════════════════════════
  RELEASE SUMMARY — v0.N.x
══════════════════════════════════════════════
  1. Tests        all passing
  2. Code Review  passed / disabled
  3. Scope Check  passed / advisory
  4. Docs Sync    all surfaces covered (doc-sync + critic)
  5. Counts       aligned (sync-check passed)
  6. Version      bumped / unchanged
  7. PDFs         regenerated
  8. RELEASES     updated (critic verified)
  9. Validation   final gate passed
  10. Summary     evidence checklist complete
  11. GitHub      pending / published
  12. Tag         pending / updated
══════════════════════════════════════════════
```

## Trigger Signals

| Signal | What it does |
|--------|-------------|
| `prepare release` | Steps 1–10 + summary. No commit. No push. |
| `refresh release` | Same but no version bump (Step 6 skipped). |
| `prepare release and push` | Steps 1–10 → commit → push → GitHub release. |
| `refresh release and push` | Same but no version bump. |
| `commit` | Stage + commit. PreCommit hook runs sync-check. |
| `push` | Pre-push gate → push via sync.sh. |
| `run tests` | Run all 3 suites. No release steps. |

## Enforcement Architecture

| Layer | When | What |
|-------|------|------|
| **Bash critic (sync-check)** | Steps 5, 9 + every commit + CI | 18 deterministic checks (PSK001–PSK017 incl. secrets + README drift + RFT cache + flow-doc content + critic-prompt meta-check) |
| **Sub-agent critic** | Steps 4, 8, 9 | Semantic content verification via `psk-validate.sh` generic dual-gate helper; `verify_quotes()` rejects fabricated verdicts |
| **PreCommit hook** | Every commit | Blocks if sync-check fails |
| **PostToolUse hook** | Every edit | Warns on drift (silent if clean) |

## Reliability Infrastructure Changelog (v0.5.x)

Every release since v0.5.8 added a structural enforcement mechanism. This section is the canonical reference for what each check does — the analyzer at Step 4 (`psk-doc-sync.sh`) will re-surface any of these if they're dropped from docs elsewhere.

| Release | Added | What it enforces |
|---------|-------|-----------------|
| v0.5.8 | **Reliability Architecture (v0.5.8)** — 3-layer dual-gate | Bash critic + sub-agent critic + git/editor hooks. No workflow completes without both critics passing. |
| v0.5.10 | **psk-validate.sh generic dual-gate helper** + **psk-release.sh Step 9 refactored** | Same validation gate reused across all 6 executable workflows (release, feature-complete, init, reinit, new-setup, existing-setup). |
| v0.5.12 | **Step 4 per-flow-doc critic verdict** + **Bypass audit log** | Step 4 requires `CURRENT:` per flow doc. `agent/.bypass-log` records every `PSK_SYNC_CHECK_DISABLED=1` / `PSK_CRITIC_DISABLED=1` / `--no-verify`; sync-check surfaces 24h warning. |
| v0.5.13 | **check_secrets added to psk-sync-check.sh --full** (PSK011 — 12 credential patterns) | AWS/GitHub/Anthropic/Google/Slack/Stripe/private-key PEM patterns blocked at commit. Placeholder-aware; masked output. |
| v0.5.15 | **verify_quotes() added to psk-validate.sh** (sub-agent honesty gate) | Every `CURRENT:` verdict requires a `QUOTE:` line verbatim from the named file. Bash `grep -F` rejects fabricated quotes. |
| v0.5.16 | **RFT cache** + **Compact critic output** + **CI templates** | RFT 60× speedup (mtime invalidation). Critic target ≤400 tokens. 4 stack-aware CI template files. |
| v0.5.17 | **`check_readme_content` (PSK012)** + **README restructured** + **Release pipeline expanded** | README "Latest Release" section must reference current version substantively. Release pipeline grew from 7 to 10 steps with validation as final gate. |
| v0.5.18 | **`check_readme_install_list` (PSK013)** + **`check_readme_agent_table` (PSK014)** + **`check_readme_flow_table` (PSK015)** | README Quick Start install counts match disk; agent directory + flow tables match file counts. |
| v0.5.19 | **`check_flow_docs_content` (PSK016)** + **`check_critic_prompts_comprehensive` (PSK017)** + **Critic prompts strengthened for omission detection** + **Orchestrator ↔ flow-doc cross-reference mandated in prompts** + **Sync-check now 18 checks** | Each executable orchestrator mentioned in its flow doc; critic prompts retain OMISSION DETECTION + CROSS-DOC FEATURE COVERAGE sections. |
| v0.5.20 | **`psk-doc-sync.sh` full-surface analyzer** + **Critic prompts wired to the analyzer** + **Extended noise filter** + **Stale release-state detection (state_is_stale() in psk-release.sh)** | Step 4 checks every CHANGELOG feature across 5 doc surfaces. Critic prompts run the analyzer and treat MISSING as STALE. `psk-release.sh` `run_next` refuses to resume if RUN_ID >24h old OR base version drifted outside the release flow — prevents `done` markers from a prior version silently satisfying today's release. Surfaces real v0.5.x doc-drift backlog. |
| v0.6.19 | **REQS-Coverage Gate (`check_reqs_coverage`, PSK016)** + **Phase 0 helper `reflex/lib/check-reqs-coverage.sh`** | Sync-check now mechanically validates every R-row in REQS.md maps to ≥1 F-row in SPECS.md (or is documented in §Out of scope). Sub-detector `check_reqs_numeric_drift` regex-extracts numerals from R-acceptance vs F-acceptance vs code constants. Fast (<2s), deterministic, free. Reflex Phase 0 helper writes `reqs-coverage.yaml` per pass so QA-Agent reads pre-computed gap list rather than rediscovering. ADR-031. |
| v0.6.23 | **Client-Grade Output (`psk-ui-polish-check.sh`, ADR-034)** + **`check_ui_requirements_coverage` (PSK017 + PSK017-UI-MIN)** | UI-bearing projects MUST pass (a) the 8-element polish check (loading/empty/error states · skip-link · dark-mode toggle · onboarding · brand assets · aria-live regions) and (b) every R-row tagged `Category: UI/UX` must own a feature in SPECS. Mandatory minimum 12 UI/UX R-rows on UI projects. Bypass `PSK_UI_REQS_COVERAGE_DISABLED=1` for non-UI projects after explicit confirm. Phase 7 of the self-evolving plan. |

## Pre-Push Gate

Before every push — sync-check must pass (enforced by PreCommit hook).

```
┌─────────────────────────────────────────────────────────────┐
│  User: "push"                                               │
│     PreCommit hook: psk-sync-check.sh --full                │
│     ├─ Pass → push via sync.sh                              │
│     └─ Fail → show mismatches, block push                   │
└─────────────────────────────────────────────────────────────┘
```

## Stub Completion Gate

Feature cannot be marked [x] until test stubs are fully implemented:

```
┌─────────────────────────────────────────────────────────────┐
│  Stub generated (RED — TODO markers)                        │
│     → User implements feature code                          │
│     → User fills stub implementations                       │
│     → check_stub_complete() verifies no markers             │
│     → Tests pass → mark [x] in SPECS.md                     │
└─────────────────────────────────────────────────────────────┘
```

## Final Validation (Step 9) — dual gate via psk-validate.sh

Step 9 is the terminal gate of the release pipeline. Internally, `psk-release.sh` delegates to the generic `psk-validate.sh` helper that every executable workflow uses. This keeps release validation consistent with `init`, `reinit`, `feature-complete`, `new-setup`, and `existing-setup`.

```bash
# Direct invocation (what Step 9 runs):
bash agent/scripts/psk-validate.sh release
```

The helper runs:
1. **Layer 2A** — `psk-sync-check.sh --full` (15 deterministic checks, PSK001–PSK015; includes PSK011 secrets scan + PSK012/013/014/015 README drift checks; RFT gate cached for 60× speedup on repeat runs)
2. **Layer 2B** — `psk-critic-spawn.sh write STEP_9_VALIDATION` → exits `AWAITING_CRITIC` (exit code 2). Agent spawns sub-agent, writes `critic-result.md`, re-runs.

Both must pass before the release is marked ready. Bypass flags (emergency only): `PSK_SYNC_CHECK_DISABLED=1`, `PSK_CRITIC_DISABLED=1`.
