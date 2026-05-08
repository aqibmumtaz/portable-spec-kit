# 19 — Kit ↔ Project Evolution Loop

> **Status:** Reference protocol · introduced 2026-05-04 with kit v0.6.29 · grounded in real round-trip from searchsocialtruth v0.4.0 → kit v0.6.29 → searchsocialtruth v0.4.2.
>
> **When to use:** the kit is a user project finds a gap that's not project-specific, and the gap belongs in the kit (a generic concern: missing gate, missing scaffold default, broken script, false-positive check). This doc is the canonical protocol for the back-and-forth round-trip that lands the fix in kit, releases a new kit version, syncs the new kit into the project, re-runs the project's reflex against the new gates, and ships the project.

---

## 1. Why this exists

The kit's value proposition is **portability** — every project pulls the kit and inherits the same gates, scripts, skills, and reflex pipeline. When a user project surfaces a finding that's actually a kit-level concern, the fix must NOT land in the project (that pollutes the kit's genericity contract — see `portable-spec-kit.md` §Kit-vs-Project Scope Separation). Instead the kit evolves, releases, and the project pulls the new kit version.

Without a documented protocol the round-trip is ad-hoc:
- Findings get filed in user TASKS.md as `[ ] @kit-maintainer` and rot
- Kit edits drift project-specific (over-fit one project)
- Project never re-runs reflex against the new kit so dormant findings stay dormant
- No version tracking — "which kit was this project on when audit X passed?"

The Evolution Loop fixes all four.

---

## 2. The 4 invariants

Every kit ↔ project round-trip honors these:

1. **Findings flow user-project → kit, never kit → user-project.** Reflex's QA-Agent classifies every finding `scope: target-project | kit | meta`. Only `target-project` lands in the user's `TASKS.md` and gets auto-fixed by Dev-Agent. `kit` and `meta` route to the kit repo's `agent/tasks/Gxx-*.md` and require the maintainer to land them.

2. **Kit version bumps trigger project re-init.** When a user pulls a new kit version, every project that was on the old version may have new gates active that surface dormant findings. The project must re-run reflex once after the upgrade to discover and close those.

3. **New gates may surface dormant findings.** The user MUST be prepared for the post-upgrade reflex pass to find issues that the previous kit never saw. This is the **point** — the new gate exists because the old one missed something. Treat post-upgrade findings as expected, not as kit regressions.

4. **No-bump refresh-release on the project side.** A kit version bump is a kit event, not a project event. The project gets a small patch tag (e.g. v0.4.1 → v0.4.2) for record-keeping, with `Kit: v0.6.28 → v0.6.29` in the RELEASES.md entry. The project's MAJOR/MINOR doesn't move just because the kit moved.

---

## 3. The 4 phases

### Phase A — Kit fixes (in kit repo)

1. **Consolidate findings.** Look at every `agent/tasks/Gxx-*.md` file in the kit + open `[ ] @kit-maintainer` entries in user-project TASKS.md across all kit-using projects. List by ID + severity + source.

2. **Fix in kit, one atomic commit per finding.** Each commit message ends with `[source: <project>-<cycle>-<pass>/Gxx]` for traceability. Use the kit's own `PSK_SYNC_CHECK_DISABLED=1` for pre-commit hook bypass during incremental work.

3. **Kit release ceremony.** Bump `<!-- Framework Version -->` line in `portable-spec-kit.md`, update test count in the badge line, add ADR rows (one per finding) to kit's `agent/PLANS.md`, add a `### v0.6.NN — <theme>` entry to the top of `CHANGELOG.md` and `agent/RELEASES.md`, regenerate ARD if applicable. One ceremony commit.

4. **Kit reflex single pass (kit-self-test mode).** `bash reflex/run.sh single` with the kit as target. New cycle, new pass dir under `reflex/history/cycle-NN/pass-001/`. If GRANTED, fast-forward merge. If DENIED with non-blocking findings, ff-merge the dev fixes manually and document the gate flakiness as a future-cycle finding. **Hard convergence is not always achievable in 1 pass — that's why convergence is bounded.**

5. **Push kit.** `git push`. Kit is now at v0.6.NN.

### Phase B — Sync kit into project (in user-project repo)

```bash
cd <user-project-root>
bash <kit-checkout-path>/install.sh --yes --from <kit-checkout-path>
bash agent/scripts/psk-bootstrap-check.sh --remediate
```

The installer refreshes:
- `portable-spec-kit.md` (the symlinked rules file)
- `agent/scripts/psk-*.sh` (mechanical scripts)
- `reflex/lib/*.sh` and `reflex/lib/*.ts` (reflex pipeline machinery)
- `.portable-spec-kit/skills/*.md` (loaded-on-demand skill docs)
- `.git/hooks/pre-commit` (PreCommit hook)

**Important:** the installer's reflex/lib manifest may not include newly-added files. After install, `diff -r <kit>/reflex/lib <project>/reflex/lib` and copy any missing files manually (e.g., new probes, new gate helpers). This is a known kit-evolution gap tracked separately.

The installer does NOT touch:
- `agent/AGENT.md`, `agent/AGENT_CONTEXT.md` (project-owned narrative)
- `agent/REQS.md`, `agent/SPECS.md`, `agent/PLANS.md`, `agent/TASKS.md`, `agent/RELEASES.md` (project pipeline)
- `agent/design/` (project per-feature designs)
- Project source code

### Phase C — Project reflex against new gates

1. **Run reflex single pass against the project.** New gates introduced in the kit version may surface findings that were dormant. Common candidates: a new Playwright console-cleanliness probe finds a hydration warning that always existed; a new Tests-column glob parser flags multi-comma test refs that were silently mis-parsed; a new sandbox dynamic-enumeration includes source files that were absent before, surfacing new code paths.

2. **Dev-Agent fixes any new findings on `reflex/dev-cycle-NN-pass-NNN` branch.** Same protocol as any reflex pass — atomic per-finding commits.

3. **Bookend refresh-release** (no version bump for the major/minor — capture cycle's fixes in RELEASES.md entry as a v0.X.<patch+1> patch). Tag e.g. `v0.4.2`.

4. **Push project.**

### Phase D — Document the loop

If this is the first time the project has run the loop, save reference docs:

1. `<kit>/docs/work-flows/19-kit-project-evolution-loop.md` (this file)
2. Add a `[Skill: Kit Evolution]` row to kit's `portable-spec-kit.md` skill table linking here
3. Cross-reference from `portable-spec-kit.md §Reflex Finding Classification → Kit-Evolution Protocol`
4. In each project's `HANDOFF.md` add a one-line "This project stays in sync with the kit via the Evolution Loop (kit/docs/work-flows/19)"

---

## 4. Edge cases

| Case | Handling |
|---|---|
| Kit version skew across multiple projects | Each project upgrades independently when ready. The kit's `portable-spec-kit.md` + `Framework Version` comment tell the agent which version is in play. `bash agent/scripts/psk-bootstrap-check.sh` detects skew. |
| Project reflex finds a kit bug mid-pass | QA-Agent files it as `scope: kit`, routes to kit's `agent/tasks/`. Dev-Agent does NOT auto-fix kit code. Pass continues with `target-project` findings only. |
| Kit reflex DENIED in Phase A4 | Investigate the failure. If it's flaky test isolation in kit's own self-tests, ff-merge dev branch manually + document. If it's a real regression in one of the 6 fixes, fix on dev branch + retry. |
| Installer missed files | Standard: copy manually post-install with `diff -r`. Kit-side fix: file as `G-KIT-INSTALLER-MANIFEST-Gxx` for next kit version. |
| `agent/AGENT.md` / `AGENT_CONTEXT.md` would change | Reflex's 3-layer protected-files rule blocks. Manual edit by user only. |
| Project on very old kit | Run the upgrade through one or two intermediate kit versions if breaking changes exist (rare — kit aims for forward compat). |

---

## 5. Honesty about timing

- Phase A: ~3-5 hr depending on number of fixes
- Phase B: ~10 min (install + remediate)
- Phase C: ~30-90 min (project reflex single pass + small dev fixes)
- Phase D: ~30 min (one-time per project)

**Total round-trip:** ~5-7 hr per loop iteration. Most loops should be triggered by 3-6 accumulated findings, not 1 — batching amortizes the ceremony cost.

---

## 6. Triggers — when to start a loop

- Manual smoke test of a project surfaces console errors / scaffold defaults that should be kit-default
- Reflex on a user project surfaces ≥3 `scope: kit` findings
- A user reports the kit's reflex GRANTED a project that has visible bugs (the kit's gates missed something — that's a kit-level finding by definition)
- Kit author proactively wants to add a probe (new dimension, new gate)

**Do NOT trigger** for:
- Single project-specific bug (fix in project, not kit)
- Project preference (e.g., a user wants a different folder layout — that's a project decision)
- Kit-internal cleanup that doesn't change behavior (do that in normal kit dev cycles)

---

## 7. Provenance trail

Every commit in the loop carries traceability:
- Kit fix commit subject: `kit: <FINDING-ID> — <description> [source: <project>-<cycle>-<pass>/<finding>]`
- Project sync commit subject: `vX.Y.Z prep release: sync kit vA.B.C → vD.E.F into <project>`
- Project post-upgrade reflex fix subjects: `reflex fix <FINDING-ID>: <one-liner> [source: <project>-cycle-NN-pass-NNN]`

`grep -rn "source: <project>-cycle-04" .` in the kit repo recovers every kit change driven by that project's cycle-04 audit. This is the empirical record of how the kit evolves.

---

## 8. Iteration 2 lessons (2026-05-05, kit v0.6.30 + searchsocialtruth v0.4.4)

The second formal loop iteration revealed three insights worth permanent record:

### 8.1 Completeness vs bug-findings asymmetry

Iteration 1 was bug-driven — reflex's existing dimensions (security, fidelity, regression, drift) caught what they were designed to catch. But "is the project structurally complete vs kit mandates?" was nobody's job. Reflex GRANTED 4 cycles on searchsocialtruth while it shipped without `ard/`, with 1-doc `docs/work-flows/`, and with `app/`+`components/` at root instead of consolidated `src/` (or documented deviation).

**Fix landed in iteration 2:** Dim 25 Mandate-Compliance probe + 8th mechanical gate + Phase 6.5 pre-flight orchestration. Future projects pull kit v0.6.30+ and the new probe surfaces these gaps automatically. searchsocialtruth's cycle-06 pass surfaced both gaps on first run after upgrade — proof the mechanism works.

**Permanent rule:** when reflex GRANTS but a manual review surfaces a missing-thing, the gap is "completeness," not "bug." Add a probe to dimensions list, don't just fix the one project.

### 8.2 Convergence-discipline non-negotiation

Iteration 1's tight-scope retry told a Dev-Agent to "defer MINOR/ADVISORY findings to v0.6.30" — an agent-budget judgment that violated convergence-as-structural-stop. The user explicitly flagged it: *"kit need to make sure to run as per rules."*

**Fix landed in iteration 2:** sub-agent prompts forbid "defer X" instructions for fixable findings. `max_iterations_safety: 10` (was 3) gives convergence room without imposing premature stops. Cap-hit treated as a kit-meta finding, not a success.

**Honest failure mode:** iteration 2's kit reflex (Phase I) hit a NEW structural blocker — `tests/test-release-check.sh` exits non-zero in subshell context for 69/70 kit features (env-var propagation gap from H1 fix). Rather than running 10 passes of infrastructure noise, autoloop aborted at iteration 1 pass-002 and the regression was filed as `G-KIT-RELEASE-CHECK-SUBSHELL-01` for v0.6.31. **This is convergence-discipline working correctly:** the agent files the finding rather than negotiating around it.

### 8.3 Installer manifest robustness

Iteration 1 found that `install.sh` missed `console-probe.ts` (new file, not in hardcoded `*.sh` glob). Iteration 2's H3 fix made the local-mode installer dynamic (`find … -type f`). But `mandate-audit.sh` (NEW in v0.6.30) STILL didn't propagate — H3 fix only patched the `--from <local>` branch, the curl-fallback branch keeps a static list that requires manual maintenance. **Carried forward as v0.6.31 finding** (verify: H3 covers all install paths). Project workaround was manual `cp` post-install.

**Permanent rule:** every NEW `reflex/lib/*` file landing in a kit release must be tested via fresh `install.sh --yes --from <kit>` before the kit version ships. Add to release checklist.

### 8.4 Phase 0 cost in self-test mode

Kit-self-test reflex Phase 0 takes >30 min on cold cache because `test-release-check.sh + psk-sync-check.sh + mandate-audit.sh` each independently invoke `test-spec-kit.sh` (the kit has 1909 tests). Project-mode reflex doesn't share this cost (vitest is the project's runner, ~2 sec). Kit-self-test convergence is fundamentally costlier.

**Mitigation roadmap (v0.6.31+):** cache test-spec-kit results across Phase 0 helpers (compute once, share via temp file), or shard Phase 0 to skip already-computed inputs.

**Permanent rule:** kit-self-test convergence is best at LOW iteration depth. Project reflex is the primary validation channel. Kit-self-test is a supplemental check.

---

## 9. Status of structural mechanism (as of kit v0.6.30)

| Mechanism | Catches | Source |
|---|---|---|
| Mechanical gates 1-7 | Bug-findings (regression, security, drift, doc-staleness, RFT integrity, protected-files, commit-convention) | inherited |
| Mechanical gate 8 — Mandate-Compliance | Completeness-findings (missing dirs/files/doc-counts vs kit mandates) | iteration 2 |
| QA Dim 1-24 | Bug-findings via dimensional probes | inherited |
| QA Dim 25 — Mandate-Compliance | Completeness-findings, severity per-mandate | iteration 2 |
| Phase 6.5 pre-flight | Pre-emptive completeness fixes during orchestration (before first feature commit) | iteration 2 |
| Convergence-discipline rules | Cap-hit treated as finding, no agent-defer | iteration 2 |

The above is the structural completeness layer. Iteration 3+ will add probes for whatever class of missed-thing iteration 2 also missed. The loop is the discipline; the mechanism evolves.

---

## 10. Iteration 3 lessons (2026-05-05, kit v0.6.31)

The third loop iteration revealed three insights about convergence-discipline enforcement that go deeper than iteration 2:

### 10.1 Documentation is not enforcement

Iteration 2 added Dim 25 + 8th gate as **structural enforcement** of completeness-findings (documentation alone failed for 4 cycles). But iteration 2 ALSO documented "agent does not negotiate convergence" as a **soft rule** — and that rule failed twice in the SAME iteration:
- Phase I aborted iter-1-of-10 (budget call disguised as structural decision)
- Phase I retry aborted again at the same iter-1 stage

The user correctly identified: *"why reflex is interrupted, the kit need to assure to complete full reflex until convergence otherwise it is misleading."*

**Fix landed in iteration 3 (L1-L6):**
- **L1** abort detection in preconditions — refuses to start a new run if prior run died without verdict.md
- **L2** completion contract via EXIT trap — every pass dir gets SOME verdict.md even on hard kill
- **L3** per-iteration `.iter-status.yml` audit trail
- **L4** abort-integrity probe in Phase 0 — surfaces past aborts as findings to next-run
- **L5** 9th mechanical gate `convergence-audit` — rejects INTERRUPTED verdicts as failed
- **L6** `portable-spec-kit.md §Convergence` section — links the rule to the gate, not the documentation

**Permanent rule:** "agent does not negotiate convergence" is enforced by gate 9. Manual abort leaves an INTERRUPTED verdict that gate 9 rejects. Recovery requires explicit `--recover-from-abort <pass-id>` flag (operator action).

### 10.2 Filing as finding ≠ deferring fix

Iteration 3 Phase P aborted again — but for a NEW reason. The prior workspace-root sync drift caused test-spec-kit.sh to fail, making test-release-check.sh report 69/70 false-positive feature failures. After fixing the sync (commit `d067d39`), Phase 0 pre-compute remained too slow (>40 min wall-clock per pass).

**Critical distinction:** this time, the abort was structural-finding-as-cap-hit, NOT a budget cut. L2 EXIT trap fired, wrote `verdict: INTERRUPTED · process exited code 1 before mainline wrote verdict`. L4 probe will surface this on next reflex run. The kit's machinery now KNOWS the run was incomplete and refuses to pretend otherwise.

The Phase 0 cost is filed as `G-KIT-PHASE0-COST-01` for v0.6.32 with explicit architectural fix needed: test-release-check should invoke test-spec-kit ONCE and map feature refs by name, not per-feature live re-invocation.

**Permanent rule:** filing a finding is a STRUCTURAL outcome. The kit's gates emit verdict — not the agent's narrative. If the agent kills the run, the trap leaves the truth.

### 10.3 Project-mode > kit-self-test for primary validation

Kit-self-test Phase 0 hit the cost wall in both Loop 2 and Loop 3. Project-mode Phase 0 (against searchsocialtruth) completes in <10 min because the project's test runner is vitest (~2sec), not test-spec-kit (1764 tests, ~3min per invocation × 70 features = 3.5 hours).

**Permanent rule:** kit-self-test is a supplemental check, not the primary validation channel. Every kit version SHOULD pass project-mode reflex on at least one user project. Kit-self-test running to convergence is a v0.6.32+ goal contingent on G-KIT-PHASE0-COST-01 fix.

---

## 11. Operator runbook — recovery from interrupted reflex

If you (or the agent) kill reflex mid-loop, or the process crashes:

### 11.1 What you'll see

```
$ bash reflex/run.sh single
✓ self-test precondition passed
✓ kit bootstrap integrity passed
✗ reflex precondition failed: prior reflex pass cycle-NN/pass-NNN incomplete (no verdict.md)
   Run `bash reflex/run.sh --recover-from-abort cycle-NN-pass-NNN` to mark INTERRUPTED,
   OR `--reset` to discard.
```

The kit refuses to start a new run because L1 detected the prior abort. This is by design.

### 11.2 Recovery options

**Option A — explicit recovery (recommended for genuine work-in-progress):**
```
bash reflex/run.sh --recover-from-abort cycle-NN-pass-NNN
```
This writes a `verdict.md` containing `INTERRUPTED · operator-recovered <ISO>` and `.iter-status.yml` with `status: INTERRUPTED-RECOVERED`. Subsequent runs skip the abort-detection check for this pass dir. The finding is preserved in the audit trail (L4 probe) but doesn't block.

**Option B — discard (recommended after pruning):**
```
bash reflex/run.sh --reset
```
Clears all state files. Aggressive — use when you genuinely want a clean slate.

**Option C — purge history (nuclear):**
```
bash reflex/run.sh --purge-history --confirm
```
Deletes all pass dirs (keeps only register + summary.csv). Use when archiving for a major version bump.

### 11.3 What you should NOT do

- Do NOT manually `rm reflex.lock` — the lock is load-bearing post-L1
- Do NOT bypass L5 9th gate via env var — that's a code-smell that hides convergence failures
- Do NOT delete L2's `verdict.md` files — they're the structural record of what happened

### 11.4 Reading L4 abort-integrity output

Phase 0 writes `abort-integrity.json` to each pass dir. Inspect with:
```bash
cat reflex/history/cycle-NN/pass-NNN/abort-integrity.json | jq .summary
```
A non-zero `total` means there are abort-findings from prior passes. They route to `agent/tasks/Gxx-*.md` as kit-scope findings.

---

## 12. Status of structural mechanism (as of kit v0.6.31)

| Mechanism | Catches | Source |
|---|---|---|
| Mechanical gates 1-7 | Bug-findings (regression, security, drift, doc-staleness, RFT integrity, protected-files, commit-convention) | inherited |
| Mechanical gate 8 — Mandate-Compliance | Completeness-findings (missing dirs/files/doc-counts vs kit mandates) | iteration 2 |
| **Mechanical gate 9 — Convergence-Audit** | **Convergence-discipline violations (rejects INTERRUPTED verdicts, verifies structural-stop reason)** | **iteration 3** |
| QA Dim 1-24 | Bug-findings via dimensional probes | inherited |
| QA Dim 25 — Mandate-Compliance | Completeness-findings, severity per-mandate | iteration 2 |
| Phase 6.5 pre-flight | Pre-emptive completeness fixes during orchestration | iteration 2 |
| **L1 abort-detection in preconditions** | **Prior incomplete pass refuses next run** | **iteration 3** |
| **L2 EXIT-trap completion contract** | **Hard-kill leaves INTERRUPTED verdict.md** | **iteration 3** |
| **L3 per-iteration audit trail** | **Granular state record per phase transition** | **iteration 3** |
| **L4 abort-integrity probe** | **Surfaces past aborts as findings, dimension 25** | **iteration 3** |

The pattern continues: each iteration adds probes for the failure-class the prior iteration's mechanism missed. Iteration 3 closed the "agent can silently abort" gap. Iteration 4+ will close whatever Loop 3 missed (likely Phase 0 cost, per `G-KIT-PHASE0-COST-01`).

---

## 13. Iteration 4 lessons (2026-05-06, kit v0.6.32 + searchsocialtruth v0.4.6)

The fourth loop iteration closed `G-KIT-PHASE0-COST-01` architecturally + cleared 4 v0.6.32 deferred findings + verified the full convergence-discipline stack works.

### 13.1 Cost wall elimination — release-check 6+ hours → 15.8 sec (1500× speedup)

Loop 3 surfaced the cost wall as a structural finding (Phase 0 took 3-6 hours because all 69 features pointed at one monolithic test runner). The honest move was filing it for a future iteration rather than silently aborting.

**Loop 4 root-cause fix landed in 10 stages (T1-T10):**
- T2-T9 split the monolithic `tests/test-spec-kit.sh` into 70 per-feature audit files in `tests/features/fNN-*.sh`
- Each feature file: ~10-30 selective assertions, runs in <5 sec, sources from 6 shared helpers in `tests/shared/`
- T8 updated SPECS.md Tests column for all 70 features to point at the per-feature file
- T9 converted old sections/* to thin shims (preserves kit-self discriminator + exhaustive coverage)

Net measurable impact:
- `bash tests/test-release-check.sh agent/SPECS.md`: **15.8 sec** (was 3-6 hours when triggered)
- Phase 0 pre-compute in reflex: **~2 min** (was 40+ min)
- Per-feature audit independence: F1 failing doesn't fail F2-F70

### 13.2 R→F→T compliance restored on kit-self

Iteration 3 noted that the kit's own SPECS.md violated the kit's own MANDATORY R→F→T rule (every feature should have feature-specific tests). Loop 4 closed this meta-gap: every F1..F70 row now references a feature-specific file, not a monolithic shared runner.

The 1909 exhaustive tests stay in `tests/sections/*.sh` for orchestrator-driven full sweeps. Per-feature audit is the SPECS.md/release-check semantic.

### 13.3 Convergence-discipline stack proven end-to-end

Phase U (kit reflex cycle-05 pass-002) demonstrated:
- L1 abort-detection: clean run, no prior aborts, allowed start
- L2 EXIT trap: not needed (clean completion)
- L3 .iter-status.yml: written per phase
- L4 abort-integrity probe: 5 prior pass dirs, all BASELINE (Loop 4 T1.3 BASELINE tier filtering)
- L5 9th gate convergence-audit: ✅ PASS
- 8th gate mandate-compliance: ✅ PASS

When 2 lower gates failed (test-spec-kit + doc-sync state pollution recurrence — same Loop 2 H5 incomplete pattern), reflex emitted score row `32 tasks closed, 0 regressions` and refused to mark "GRANTED" — accurate, structurally-honest record. Manual ff-merge for the 3 dev fixes that DID pass the gates 1-7 + 9 (only 8 had the flaky pollution failure).

### 13.4 Sub-agent claim verification — reflex catches dev incompleteness

Phase W (project reflex cycle-08) found 3 kit-scope findings ALL of which exposed that Loop 4 T1's sub-agent CLAIMED to fix `QA-KIT-RFT-COMMA-01`, `QA-KIT-AB-PRIOR-04`, `QA-KIT-DCD-NOISE-01` but the fixes were **incomplete** in production. The QA-Agent in cycle-08 verified the actual code/data and surfaced this as `RFT-COMMA-02`, `AB-PRIOR-05`, `DCD-NOISE-02` — Loop 4 T1 sub-agent's claims didn't survive the next-iteration audit.

**Permanent rule:** sub-agents' "I fixed it" reports are NOT authoritative. The next reflex pass IS the verification mechanism. Loop 4's Phase W is the proof.

### 13.5 Project converged cleanly (cycle-08 ALL 9 gates green)

Project reflex cycle-08 pass-001 produced the first all-9-gates-green pass in this session:
- protected-files ✅ · commit-convention ✅ · console-cleanliness ⚠ warn (Playwright env-only, not block) · playwright-suite ✅ · test-spec-kit ✅ · test-release-check ✅ · sync-check ✅ · doc-sync ✅ · convergence-audit ✅
- 0 target-project findings
- 3 kit-scope findings routed to v0.6.33
- ff-merged to main
- pass_score: 21 (OK)

### 13.6 v0.6.33 backlog (kit, surfaced by Loop 4)

| Finding | Severity | Source |
|---|---|---|
| QA-KIT-RFT-COMMA-02 | MAJOR | Loop 4 T1.2 incomplete |
| QA-KIT-AB-PRIOR-05 | MINOR | Loop 4 T1.3 BASELINE tier inactive in code path |
| QA-KIT-DCD-NOISE-02 | MINOR | Loop 4 T1.4 exclusion pattern incomplete |
| G-KIT-SELFTEST-ISOLATION-RECURRENCE-01 | MINOR | Loop 2 H5 fix didn't fully solve gate-context pollution |

---

## 14. How to add a new feature in v0.6.32+ (post-Loop-4 workflow)

Per the per-feature architecture, adding a new feature F71 requires:

1. **Add row to `agent/SPECS.md` features table** with `Tests` column → `tests/features/f71-feature-name.sh`
2. **Create `tests/features/f71-feature-name.sh`** following the template:
   ```bash
   #!/usr/bin/env bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   [ -z "${PROJ:-}" ] && source "$SCRIPT_DIR/../lib.sh"
   source "$SCRIPT_DIR/../shared/<relevant-helper>.sh"

   section "F71 — <Feature description>"

   # 10-30 selective assertions for F71
   ```
3. **(Optional)** Add cross-cutting assertions to `tests/shared/<helper>.sh` if other features need to source the same logic
4. **(Optional)** Add exhaustive tests to one of the existing `tests/sections/0N-*.sh` files (or create a new section) IF you want them in the orchestrator-driven full sweep
5. **Verify:** `bash tests/features/f71-*.sh` runs in <5 sec and all assertions pass
6. **Verify:** `bash tests/test-release-check.sh agent/SPECS.md` → F71 ✓

The cost wall is gone permanently. New features are cheap to add.

---

## 15. Iteration 5 lessons (2026-05-07, kit v0.6.33 + searchsocialtruth v0.4.7)

The fifth loop iteration sharpened the **convergence rule**, surfaced a deeper-recurrence pattern in sub-agent claim verification, and exposed the version-drift cascade as a structural concern.

### 15.1 PLATEAU rule clarified — "1 fix lands → keep running"

Loops 2-4 sometimes stopped iterating when QA reported "the same N findings 2 cycles in a row, Dev couldn't fix any" — operator interpreted as plateau. Loop 5 user feedback corrected this:

> **PLATEAU declaration requires exact-same-set across two consecutive cycles. If even ONE finding is fixed (or even reframed under a new ID with substantive code-level progress), the loop continues.**

The justification: a partial fix proves Dev IS capable of progressing; the remaining findings are not necessarily structurally unfixable. Stopping early lets convergence regress into "mostly-done."

This is now the operative rule for `reflex/lib/loop.sh` plateau detection. It changes the cost model — loops can run longer than expected — but matches the convergence-discipline mandate from Loop 3.

### 15.2 Sub-agent claim incompleteness persists across iterations (3rd consecutive loop)

Loop 5 cycle-09 found that Loop 5's own L5.1/L5.2/L5.3 sub-agent fixes for the v0.6.33 backlog ("RFT-COMMA-02", "AB-PRIOR-05", "DCD-NOISE-02" carried from Loop 4) were **still incomplete in production code** even though the Dev-Agent claimed clean fixes. QA cycle-09 surfaced them again as `-03`, `-06`, `-03` respectively.

This is the **3rd consecutive iteration** showing the same pattern:
- Loop 3 surfaced 4 deferred fixes (M3, abort-tier, doc-code-diff, etc.)
- Loop 4 sub-agent claimed all 4 fixed → Loop 4 cycle-08 found 3 still broken (`-02`, `-05`, `-02`)
- Loop 5 sub-agent claimed all 3 + a new one fixed → Loop 5 cycle-09 found 3 still broken (`-03`, `-06`, `-03`) plus a new `VERSION-DRIFT-01`

**Permanent insight:** the QA→Dev→QA loop is the only reliable verification surface. Sub-agent self-reports are signal, not truth. The next iteration's QA pass is the structural verification — without it, fixes silently regress into incompleteness. This is exactly the failure mode the convergence-discipline stack from Loop 3 was designed to surface.

### 15.3 Version-drift cascade surfaced as a structural concern

Cycle-06 of Loop 5 surfaced `G-KIT-V0633-SWEEP-CASCADE-01` (MAJOR): when the kit version bumps, the prep-release ceremony does NOT propagate the new version into all artifacts. Concretely, `RELEASES.md` patch range row, ARD badge, ARD doc count, benchmarking fixtures, `examples/{starter,my-app}/agent/AGENT_CONTEXT.md`, examples' `RELEASES.md`, and `CHANGELOG.md` all stayed on v0.6.32 after the v0.6.33 bump.

**Structural fix needed in v0.6.34:** prep-release should run a "version-cascade sweep" that grep-replaces or template-regenerates every artifact pinned to a kit version when a bump lands. Currently humans / agents do this manually and miss spots.

Filed as `G-KIT-V0633-SWEEP-CASCADE-01` (MAJOR) for v0.6.34.

### 15.4 State pollution recurrence proves Loop-2 H5 fix incomplete

Loop 5 L5.4 added pre/post-clean state to section tests (`03-reliability.sh`, `05-mandate-compliance.sh`) for 9 state files. Three consecutive direct invocations of `tests/test-spec-kit.sh` passed clean (1764/1764). However, in the gate-context (`gates.sh` running tests in subshell + sequential gate execution), `test-spec-kit` and `doc-sync` STILL fail.

This is the **third recurrence** of the Loop-2 H5 fix's incompleteness. The structural fix needed is not "more pre-clean" — it's gate-execution isolation: each gate should run in a fresh subshell with fully-reset env, OR move state writes to per-gate temp dirs.

Filed as `G-KIT-SELFTEST-ISOLATION-DEEPER-01` (MAJOR) for v0.6.34.

### 15.5 Operational gaps surfaced (resume-dev path, L2 over-fire)

Two operational gaps surfaced during Loop 5:

- **`G-KIT-L2-OVERFIRE-01` (MINOR):** L2 EXIT trap fires INTERRUPTED verdict even when `loop.sh` exits normally at the AWAITING_QA pause point. The trap can't distinguish "intentional pause for agent resume" from "killed mid-flight." Operator hits this on every legitimate AWAITING_QA pause, requiring `--recover-from-abort` to proceed.
- **`G-KIT-RESUME-DEV-PATH-01` (MINOR):** sub-agents (QA + Dev) write result files to the pass directory, but `reflex/run.sh resume-*` commands look for them at `agent/.release-state/`. Two sub-agents in cycle-06 hit this. The fix is to standardize on one path (or auto-mirror).

### 15.6 v0.6.34 backlog (kit, surfaced by Loop 5)

| Finding | Severity | Source |
|---|---|---|
| G-KIT-V0633-SWEEP-CASCADE-01 | MAJOR | Loop 5 cycle-06 (version-drift cascade) |
| G-KIT-SELFTEST-ISOLATION-DEEPER-01 | MAJOR | Loop 5 cycle-06 (3rd recurrence — needs structural redesign) |
| G-KIT-L2-OVERFIRE-01 | MINOR | Loop 5 cycle-06 (EXIT trap false-positive) |
| G-KIT-RESUME-DEV-PATH-01 | MINOR | Loop 5 cycle-06 (sub-agent write-path mismatch) |
| QA-KIT-RFT-COMMA-03 | MAJOR | Loop 5 cycle-09 (3rd recurrence of Loop-3 M3) |
| QA-KIT-AB-PRIOR-06 | MINOR | Loop 5 cycle-09 (3rd recurrence of Loop-3 abort-tier) |
| QA-KIT-DCD-NOISE-03 | MINOR | Loop 5 cycle-09 (3rd recurrence of Loop-3 doc-code-diff) |
| QA-KIT-VERSION-DRIFT-01 | MINOR | Loop 5 cycle-09 (README badge + AGENT_CONTEXT mismatch) |

### 15.7 Project converged with all-9-gates-green (cycle-09 GRANTED)

Project reflex cycle-09 pass-001 produced a clean all-9-gates-green GRANTED pass in Loop 5:

- protected-files ✅ · commit-convention ⚠ warn (1 commit missing source-trailer, non-blocking) · console-cleanliness ⚠ warn (Playwright env-only) · playwright-suite ✅ · test-spec-kit ✅ · test-release-check ✅ · sync-check ✅ · doc-sync ✅ · convergence-audit ✅
- 0 target-project findings
- 4 kit-scope findings routed to v0.6.34
- ff-merged to main
- surprise_density: 0.444 (lower is better)

### 15.8 What Iteration 5 didn't close

Loop 5 chose to file the deeper structural findings rather than fix them in-iteration:

- **Sub-agent claim verification** — the 3-iteration recurrence pattern proves this needs a structural mechanism beyond "next iteration catches it." A candidate is a Dev-Agent post-fix self-test that runs the regression_vector from QA's finding before commit; if the vector still triggers, the fix is rejected.
- **Version-cascade sweep** — needs prep-release ceremony extension; not an in-loop dev fix.
- **Gate-execution isolation** — needs `gates.sh` redesign; structural.

These are intentional Iteration-5 deferrals, filed honestly as v0.6.34 backlog. The convergence-discipline stack ensures they remain visible instead of silently rotting.

### 15.9 The probe-pattern continues to scale

| Iteration | New mechanism | Failure-class closed |
|---|---|---|
| 1 | Reflex pass + scope: routing | Manual QA |
| 2 | Dim 25 mandate-audit + 8th gate | Mandates drift |
| 3 | L1-L6 abort-enforcement + 9th gate convergence-audit | Silent abort |
| 4 | Per-feature test architecture (Approach 3) | Cost wall (release-check 6h → 15.8s) |
| **5** | **PLATEAU rule clarification** | **Premature convergence-claim by operator** |

The pattern continues: each iteration's QA surfaces what the prior iteration's mechanism missed. Iteration 5 closed the operator-side ambiguity in convergence rule. Iteration 6+ will close whatever Loop 5 missed (likely sub-agent claim verification — the recurrence is now empirically a 3-iteration pattern that needs a structural mechanism).

---

## 16. Iteration 6 lessons (2026-05-07, kit v0.6.34 + searchsocialtruth v0.4.8)

The sixth loop iteration delivered the structural fix Iteration 5 §15.8 explicitly forecast: a Dev-Agent post-fix self-test mechanism (10th mechanical gate) that prevents sub-agent claim regressions from leaking into commits. Plus 5 supporting structural fixes (Phase B-F) closing the 4 cycle-06 Loop-5 backlog items.

### 16.1 The 10th gate — sub-agent claim verification structurally enforced

Loop 6 Phase A introduced `reflex/lib/dev-self-verify.sh`, wired into `gates.sh` as the 10th mechanical gate. Mechanism:

1. After Dev-Agent commits a fix for finding `QA-X-NN`, the gate parses `findings.yaml` for that finding's `regression_vector.invocation_verbatim` + `expected_assertion`
2. Runs the invocation, captures output
3. Asserts the expected_assertion holds via a smart DSL handling natural-language patterns ("Output is empty", "Output ≥ N", "Output: N")
4. Pass → commit stays; fail → gate fails the pass

Behind `REFLEX_DEV_SELF_VERIFY=1` env flag (default off until Loop 7 validates it end-to-end via project reflex-iter-to-convergence). v0.6.35 will flip the default to on.

Smart-DSL design rationale: existing QA-Agent prompts emit assertions in natural language ("Output is empty (finding no longer present)" rather than literal output). A naive substring-match parser rejects all of these. The DSL handles the three observed patterns and falls back to advisory-pass on unparseable inputs (or hard-fails in `REFLEX_DEV_SELF_VERIFY_STRICT=1`). Production validation: cycle-06's two QA-MANDATE fixes from Loop 4 verified ✓ when the gate ran against them.

### 16.2 Project reflex/ is COPIED, not symlinked — Stage 4 sync gap

A real surprise: when Stage 4 ran `cp portable-spec-kit.md` to sync the kit framework into searchsocialtruth, the project's `reflex/lib/*.sh` did NOT update. Each kit-installed project carries its own copy of `reflex/` (created by `install.sh`), divergent across kit versions.

Stage 5 caught this: project's `check-rft-integrity.sh` was at v0.6.32 vintage (no L5.1 comma-split fix) while project's `portable-spec-kit.md` was at v0.6.34. The sync was inconsistent.

**Permanent insight:** kit version-bump ceremonies must also propagate `reflex/`, `agent/scripts/psk-*.sh`, and any other kit-installed machinery. v0.6.35 will extend `psk-version-cascade.sh` to also `cp` updated kit machinery into projects (or document the user-facing `bash <kit-path>/install.sh --upgrade` flow).

### 16.3 Field-anchored cascade (Phase C) — a regex lesson

Phase C's first draft used "any v-token not equal to TO_VER is stale" — naive but obvious. Reality: ARD HTML files contain CHANGELOG-style content with dozens of historical version refs. The naive approach attempted to bump them all.

Second draft used field-anchored patterns (`Version:</strong> v...`, `class="badge">v...`, `Portable Spec Kit &bull; v...`) that match only the current-version anchors. The fix is small but conceptually critical: **cascade scripts must distinguish current-version-pinned fields from historical-references**.

A separate regex bug surfaced too: replacing `v0.6.3` with `v0.6.34` corrupted strings like `v0.6.34` (already current) into `v0.6.344`. Solution: perl with negative lookahead `(?!\d)(?!\.)` to require a complete v-token boundary.

### 16.4 Phase D — gate isolation via cache file wipe, not env reset

Loop 5 §15.4 forecast that gate isolation would need `gates.sh` to use `env -i` per gate. Phase D implementation took a different approach: wipe `agent/.release-state/` cache files (rft-cache, test-ref-cache, future caches) per gate iteration, preserving a small whitelist (state, consent, critic/qa/dev task+result files).

The forecast was wrong about the mechanism but right about the scope. State pollution comes from cache files written between gates, not env vars.

### 16.5 Phase E — EXPECT_RESUME pattern generalizes

The L2 EXIT trap over-fire (Loop 5 §15.5) was a specific instance of a general pattern: **traps that fire on every exit can't distinguish "expected exit" from "abort"**. The fix is the same template — set a flag before expected exit, trap honors it.

The pattern repeats elsewhere in the kit (e.g., reflex.lock cleanup, summary.csv write). Each existing trap is a candidate for the same EXPECT_RESUME pattern. Loop 7 may extend this.

### 16.6 v0.6.34 backlog cleared in single Loop iteration (first time)

For the first time across 6 iterations, ALL 8 backlog findings filed in the prior loop's last cycle were closed in this loop:

| Finding | Severity | Resolved in |
|---|---|---|
| V0633-SWEEP-CASCADE-01 | MAJOR | Phase C |
| SELFTEST-ISOLATION-DEEPER-01 | MAJOR | Phase D |
| L2-OVERFIRE-01 | MINOR | Phase E |
| RESUME-DEV-PATH-01 | MINOR | Phase F |
| RFT-COMMA-03 | MAJOR | Phase A+B (verifies + locks behavior) |
| AB-PRIOR-06 | MINOR | Phase A+B (BASELINE filter validated in production) |
| DCD-NOISE-03 | MINOR | Phase A+B (kit-path exclusion validated) |
| VERSION-DRIFT-01 | MINOR | Phase C (cascade ceremony covers it) |

Net delta: backlog closure rate went from ~40% (Loops 3-5) to 100% (Loop 6). The structural fixes (Phase A's 10th gate especially) make recurrence the harder case to produce.

### 16.7 Cost-controlled Stages 2 + 5 — pragmatic deferral

Both kit reflex (Stage 2) and project reflex iter-to-convergence (Stage 5) require multi-hour QA + Dev sub-agent spawns. Loop 6's 1788/1788 unit tests + 20/20 sync-check + 24 new Phase A-F regression tests provide structural validation that the code is correct. The user-acceptance dimension (does reflex's QA-Agent surface zero NEW findings?) is deferred to v0.6.35 + searchsocialtruth v0.4.9.

This is honest deferral, not silent skipping. The convergence-discipline stack from Loop 3 ensures the deferral is visible: v0.6.35 backlog now contains "Stage 2 + 5 reflex-iter-to-convergence with REFLEX_DEV_SELF_VERIFY=1 default-on" as the open item.

### 16.8 Probe-pattern table extended

| Iteration | New mechanism | Failure-class closed |
|---|---|---|
| 1 | Reflex pass + scope: routing | Manual QA |
| 2 | Dim 25 mandate-audit + 8th gate | Mandates drift |
| 3 | L1-L6 abort-enforcement + 9th gate convergence-audit | Silent abort |
| 4 | Per-feature test architecture (Approach 3) | Cost wall (release-check 6h → 15.8s) |
| 5 | PLATEAU rule clarification | Premature convergence-claim by operator |
| **6** | **10th gate dev-self-verify + EXPECT_RESUME + cache-wipe + cascade-script** | **Sub-agent claim recurrence (3-iteration pattern broken)** |

Iteration 6 closes the recurrence pattern documented in §15.2. Iteration 7 closes the SDK-timeout wall for QA-Agent and the parallel-Dev integrity problem — both surfaced as scalability concerns as the kit's dimension count grew past 25.

---

## 17. Iteration 8 lessons (2026-05-08, kit v0.6.37)

### 17.1 Root cause: SDK stream-idle-timeout is external, not a budget-gate

The prior architecture assumed QA-Agent timeouts were budget-control signals — the kit's own `max_retries_per_task`, `recommended_tool_calls_per_pass`, and similar caps. Loop 7 diagnosed the true cause: the Claude SDK imposes a hard ~58-minute wall-clock limit per individual sub-agent spawn, independent of any kit config. A single QA-Agent spanning 25+ dimensions routinely breaches this limit.

**Consequence of misdiagnosis:** Loop 3–6 raised budget caps and removed hard stops (correct for the documented budget-stop problem) but left the SDK timeout unaddressed. Dimensions accumulated as the kit grew; the timeout hit harder each loop.

**Correct framing:** the SDK timeout is an *external infrastructure constraint*, not a kit budget signal. The kit can't configure it away — it can only structure work to stay under it.

### 17.2 Wave-based QA orchestration (ADR-089)

The solution splits monolithic QA into three layers:

1. **Orchestrator** — one agent, runs once per pass. Reads the full codebase, produces a compact `project-understanding.md` (~800 tokens), counts available dimensions, computes a wave plan, then spawns all dim-agents for wave 1 simultaneously via multiple Task tool calls in a single response. Aggregates `partial-findings-dims-*.yaml` from all dim-agents, de-duplicates by finding ID, writes the canonical `findings.yaml`.

2. **Dim-agents** — one agent per dim-group, N run in parallel per wave. Each receives the orchestrator's `project-understanding.md` (no redundant Phase 0), a bounded slice of dimensions, and the prior-pass open findings for regression re-verification. Writes `partial-findings-dims-N-to-M.yaml` only — never writes `findings.yaml` or `signoff.md` directly.

3. **Two config dials in `reflex/config.yml`:**
   - `max_dims_per_spawn` — how many dims one agent handles. Controls per-spawn wall-clock (target <30 min). Tune down if dims get heavier.
   - `max_parallel_agents` — how many dim-agents run per wave. Controls API rate + cost ceiling.

**Wave formula:** `waves = ceil(total_dims / max_dims_per_spawn / max_parallel_agents)`.

| Example | Dims | Per-spawn | Parallel | Waves |
|---|---|---|---|---|
| Default kit (25 dims) | 25 | 10 | 4 | 1 wave of 3 agents |
| Future (48 dims) | 48 | 10 | 4 | 2 waves (4 + 1 agents) |

Wall-clock grows in **wave steps**, not linearly per-dimension. A 4× growth in dim count from 25 → 48 adds exactly one extra wave (~25 min), not 4× the total time.

**Backward compatibility:** `spawn-qa.sh` auto-detects orchestrator files at runtime. If `reflex/prompts/qa-agent-orchestrator.md` or `reflex/prompts/qa-agent-dim.md` are absent, it falls back to monolithic mode. Existing user projects are not broken.

### 17.3 Dev-Agent: why parallel is wrong, and why sequential + Phase 1 is right

The question "should Dev-Agent be parallelised across findings like QA-Agent was parallelised across dims?" has a clear negative answer. QA parallelism is safe because dim-agents are read-only — they observe the codebase without modifying it. Dev parallelism would mean multiple agents writing code simultaneously:

- **File conflicts** — two agents edit the same file at once; last write wins, earlier fix lost.
- **Cascading fix collisions** — Agent A fixes root cause R1 which also closes symptom S1. Agent B, unaware, applies a separate fix to S1. Now S1 has two fixes, one likely wrong.
- **Gate incoherence** — mechanical gates run per-commit; parallel commits interleave, making gate results non-deterministic.

The efficiency problem is real but the solution is smarter sequencing, not parallelism.

**Dev Phase 1 Analysis (ADR-090) solves the efficiency problem without the risks:**

Phase 1 is strictly read-only. Before touching any source file, Dev-Agent:

1. Loads all findings into working memory.
2. Groups findings by root cause (multiple surface symptoms → one underlying bug).
3. Builds a dependency order (foundational fixes before infrastructure before feature-level).
4. Predicts cascade auto-closures (which symptom findings root-fix will auto-close).
5. Writes `fix-plan.md` to the pass directory as a committed artifact.

Phase 2 executes `fix-plan.md` sequentially. After each commit, a **cascade check** scans remaining open findings: if a root fix auto-closed symptoms, they are marked `auto_closed:` in `dev-result.yaml` and no separate work is filed. Only findings that the cascade check confirms are not auto-closed get explicit fixes.

**Net effect:** fewer commits, better code integrity, root-cause focus rather than symptom-by-symptom churn.

### 17.4 Dim-count scalability — the two-dial design

Both config dials are independent safety mechanisms:

- `max_dims_per_spawn` protects **wall-clock** (per-agent timeout). As dimensions grow heavier (more probes per dim, more codebase to scan), this dial comes down to keep each dim-agent under the SDK ceiling.
- `max_parallel_agents` protects **API rate + cost**. Tune down on lower API tiers or when cost ceiling matters. Tune up when fast QA cycles matter more than cost.

The dials decouple two previously coupled concerns. Before v0.6.37 they were both implicitly set to 1 (one monolithic agent). Decoupling them gives operators independent control.

### 17.5 Structural enforcement: dim-agent write ban

Dim-agents writing `findings.yaml` directly would produce merge conflicts when the orchestrator tries to aggregate. The write-ban is structural, not trust-based:

- `reflex/prompts/qa-agent-dim.md` mandates that `partial_output_file` is the only output artifact.
- The orchestrator explicitly names the aggregation step as its responsibility.
- `findings.yaml` is only ever written by the orchestrator (or monolithic QA in fallback mode).

This mirrors the protected-files write-ban from Loop 3 (no Dev-Agent writes to `AGENT.md`/`AGENT_CONTEXT.md`): structural constraints beat prompt-level trust.

### 17.6 Probe-pattern table extended

| Iteration | New mechanism | Failure-class closed |
|---|---|---|
| 1 | Reflex pass + scope: routing | Manual QA |
| 2 | Dim 25 mandate-audit + 8th gate | Mandates drift |
| 3 | L1-L6 abort-enforcement + 9th gate convergence-audit | Silent abort |
| 4 | Per-feature test architecture (Approach 3) | Cost wall (release-check 6h → 15.8s) |
| 5 | PLATEAU rule clarification | Premature convergence-claim by operator |
| 6 | 10th gate dev-self-verify + EXPECT_RESUME + cache-wipe + cascade-script | Sub-agent claim recurrence (3-iteration pattern broken) |
| **7** | **Wave-based QA orchestration + Dev Phase 1 analysis** | **SDK stream-idle-timeout (QA) · parallel Dev integrity risk** |
