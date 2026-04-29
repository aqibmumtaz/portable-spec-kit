# Changelog

All notable changes to the Portable Spec Kit are documented here.

> **Versioning:** Each release (v0.N) is built from a series of incremental patches (v0.N.x).
> Completed releases show minor only (v0.3, v0.2, v0.1, v0.0). Active release shows full patch version.

---

## v0.6 — AVACR Adversarial Framing + Sandbox Worktree + Peer-Exchange (April 2026)
**Built over:** v0.6.0 — v0.6.15 · **Tests:** 1747 (1602 framework + 145 benchmarking)

### v0.6.15 — Cycle-id continuation rule simplified to findings-first semantics (April 2026)

**Problem.** v0.6.14's false-GRANTED defense (empty-pass-shortcut text + findings>0 → DENIED override) was fragile because `file-bugs.sh` stamps signoff.md only on certain code paths. Stamp-less GRANTED-with-findings cases still slipped through. Live evidence: the playground campaign on `urdu-stt-distillation-v2` fragmented cycle-02 → cycle-03 across what was one continuous convergence journey (4 passes total: pass-001 → pass-004 → pass-005 → pass-006). Each `bash reflex/run.sh single` invocation that landed on a GRANTED-stamped signoff spawned a new cycle id even when findings.yaml had pending entries.

**Fix.** Replace the multi-clause cross-check in both `compute_next_cycle_id` (run.sh) and `next_cycle_id` (loop.sh) with a single findings-first rule:
1. If `findings.yaml` has ≥1 entry → return SAME cycle id (continue).
2. If signoff missing or verdict ≠ GRANTED → return SAME cycle id (continue).
3. Otherwise (zero findings + clean GRANTED) → increment cycle id (terminator).

The rule no longer cares about signoff text — only about findings.yaml count + GRANTED stamp. Manual fixes between reflex passes still count as the same cycle until QA itself reports zero findings, which matches the user's mental model: a "convergence cycle" = one journey from initial state to QA-clean. ADR-027.

**Test coverage.** N62 regression suite rewritten with 14 sub-tests including 7 synthetic-HISTORY scenarios (false-stamp + findings → continue · clean GRANTED + findings → continue · 0 findings + GRANTED → advance · DENIED → continue · missing signoff → continue · convergence-journey 12→3→0 → advance · in-flight 12→3 → continue). Tests directly exercise the extracted `compute_next_cycle_id` function against constructed `cycle-NN/pass-NNN/.cycle-meta` + `signoff.md` + `findings.yaml` trees, so any future regression in the cycle-id allocator surfaces deterministically.

**Compatibility.** v0.6.14's `count_findings_yaml()` helper retained verbatim (used by the new rule). Existing pass directories with old stamped signoffs continue to work — the new rule reads them correctly because it ignores stamp text. No migration needed.

### v0.6.14 — Rule Persistence + Kit-vs-Project Scope + Cycle-id hardening + `/optimize` + reflex no-op detection (April 2026)

**/optimize cat 9 — rule-duplication detection (stub-section pattern).** New detector flags `### ` headings whose entire body is a single skill-link blockquote (`> **Skill: X** — ... .md`) with no other substantive content — the pattern of legacy stubs left during refactoring. Tighter than naive "skill referenced ≥2 times" which over-flags legitimate cross-references. Caught and fixed earlier in this session: §Python Environment + §New Project Setup Procedure stubs. Detector now flags 7 more candidates in the kit for human judgment via the /optimize skill (each is either legacy stub for consolidation or load-bearing context anchor — judgment per stub). State schema gains `cat9_duplicate_skill_refs` field. ADR-026. 10 N69 regression tests with synthetic-fixture behavioral checks + false-positive guards.

**Generic environment management (Python · Node · Ruby · Go · Rust).** Replaces the Python-only / Conda-mandatory pattern with a generic detector + interactive-prompt + persistence layer. New `agent/scripts/psk-env.sh` (5-mode CLI: detect / status / list-envs / set / activate-cmd / check) + `.portable-spec-kit/skills/env-management.md` skill drive the flow. Per-project state in `.portable-spec-kit/env-config.yml` (committed) records `runtimes:` for each detected stack — every contributor + every machine + every AI agent uses the same env. Framework rule §Environment Selection (MANDATORY) requires: (1) auto-detect on session start, (2) prompt user when stack found but env not configured, (3) user picks existing OR creates new dedicated env, (4) every stack-runtime command thereafter (agent + user invocations) uses the activation prefix. New project setup makes env selection **Step 0** — no `pip install` / `npm install` runs before the env exists. ADR-025. 22 N68 regression tests. The legacy `python-environment.md` skill stays for backward compat.

**Optimization health tracking + breadcrumb indicator (lightweight observability).** New `.portable-spec-kit/optimize-state.yml` (committed) tracks last scan, candidates by category, recommended-next-scan date, and status (optimized / review / stale). `bash agent/scripts/psk-optimize.sh --health` emits one-liner: `🟢 optimized` / `🟡 review (N candidates)` / `🔴 stale (Nd, M candidates)`. Framework rule §Optimization Health Indicator instructs agents to append the indicator to the breadcrumb header on every reply (cost: ~5ms one-time YAML parse at session start, suppressed entirely if state file missing). Thresholds combine candidate count + days-since-scan: 0-2 candidates AND <30d → 🟢, 3-9 candidates OR 30-60d → 🟡, 10+ candidates OR >60d → 🔴. State auto-refreshes via prep-release Step 10's advisory scan. ADR-024. 14 N67 tests including perf assertion (--health <1s).

**Reflex no-op pass detection (token-cost optimization, accuracy-preserving).** When `git rev-parse HEAD` matches the recorded HEAD of the most-recent GRANTED pass, `reflex/run.sh` skips the pass with an informational message instead of spending 100-300K tokens + 3-10 min wall to confirm what's already known. Reflex preconditions enforce a clean working tree, so unchanged HEAD means unchanged audit surface — the verdict CANNOT change. `--force` flag re-runs anyway (for self-tests / reproducibility verification); `REFLEX_NO_OP_DETECTION=0` disables the check for environments that don't want it. HEAD now recorded in `.cycle-meta` (`head=<sha>` field). Prompt files (`reflex/prompts/qa-agent.md` / `dev-agent.md`) deliberately NOT trimmed — every line is load-bearing, cuts there could silently weaken rule classes. ADR-023. 9 N65 regression tests.


**`/optimize` token-bloat sweep skill (new, 8 detector categories).** `agent/scripts/psk-optimize.sh` mechanical detector + `.portable-spec-kit/skills/optimize.md` skill that walks candidates with per-cut atomic commit + gate verification + MANDATORY-line preservation check. Triggers: `/optimize` · `psk optimize` · `optimize tokens` · `clean up bloat`. Default mode is `--scan` (read-only); the skill applies cuts one at a time with explicit user approval, never in batch, never auto-apply.

The 8 detector categories:
- (1) Duplicate version-iteration entries in CHANGELOG/RELEASES
- (2) Stale numeric badges (test counts that drift from runner output)
- (3) Superseded-ADR rationale bloat in agent/PLANS.md ADL
- (4) Stale file references in markdown (broken `.md/.sh/.yml` links)
- (5) Unused env vars in `.env.example` (declared but never read in src/app/lib/server)
- (6) Oversized framework sections (>200 lines under one heading — skill-file extraction candidates)
- (7) **Reflex prompt bloat** (reflex/prompts/*.md >500 lines — every reflex pass loads these; multi-K token tax per pass)
- (8) **Reflex history retention bloat** (per-pass dirs >2× retention limit, REFLEX_EVAL_TRACE.md >100KB)

The skill also documents 2 semantic categories (cross-file rule duplication, ADL-narrative leakage) handled via agent judgment, not auto-detection. Out of scope for bash detector: dead code (use ts-prune/knip/vulture), bundle size (use stack-native build analyzer), DB indexes (use DBA tools).

ADR-021 (initial 3-category design) + ADR-022 (v2 expansion to 8 categories, headline addition: reflex token-cost detection). 24 regression tests across N63 (11) + N64 (13).

Three new framework rules + one runtime fix. Surfaced via the SearchSocialTruth playground reflex campaign + follow-on session work.

**§Rule Persistence (new, MANDATORY).** Everything the agent persists across sessions goes into a committed `agent/*` file. Personal auto-memory is not used at all. Context-aware: kit-dev (kit author in canonical checkout, `portable-spec-kit.md` is regular file → writable) vs end-user (project that installed the kit, `portable-spec-kit.md` is symlink → read-only). End-user write surface is exactly `agent/AGENT.md` (rules) + `agent/AGENT_CONTEXT.md` (state / observations / anything else). Rule revised three times in one session — final form (v3) removes earlier "use memory sparingly for ephemeral context" exemption that became a slow leak. ADR-018 + ADR-019 + ADR-020 + rule-churn ADL-2026-04-28 in `agent/PLANS.md`.

**§Kit-vs-Project Scope Separation (new, MANDATORY).** Genericity test before every commit: "would this exact change be correct for every project that installs the kit?" Yes → kit repo. No → project repo. Mixed → split commits cleanly (kit commit for generic root-cause, project commit for project-side mitigation, never bundled). Generalizes the routing logic that previously lived only in §Reflex Finding Classification — now applies to all work, not just reflex findings. ADR-017.

**Cycle-id continuation hardening (false-GRANTED defense).** Fixes cycle fragmentation in `reflex/run.sh::compute_next_cycle_id` + `reflex/lib/loop.sh::next_cycle_id`. Empty-pass shortcut was overwriting `signoff.md` with `**Verdict: GRANTED**` when `qa-result.md` awk returned 0 findings even if `findings.yaml` had real entries — next cycle-id computation read the stamp and incremented. Three-layer fix: new `count_findings_yaml()` helper + false-stamp signature detection (signoff contains `empty-pass shortcut` AND `findings.yaml` ≥1 entry → override to DENIED for continuation) + empty-pass writer cross-checks `findings.yaml` before stamping. 10 N62 regression tests added. Mental model: 1 cycle = 1 convergence campaign (may span N passes); new cycle only on genuine GRANTED with 0 findings. ADR-016.

Read-only contract on `portable-spec-kit.md` generalized — was previously documented only for the version field, now extends to the whole file. Examples + workspace-root copies synced.

### v0.6.13 — Nested per-cycle history layout + Dim 23 + cycle-summary aggregator + autoloop convergence (April 2026)

Closes the meta-gap class user surfaced in cycle-01 trace audit (5 issues + 4 sub-gaps), formalizes Dim 23 (auditor-output hygiene) so QA self-evolves to catch this class going forward, migrates reflex history to a nested per-cycle directory layout, and drops the hard-3-iter autoloop cap in favor of convergence-based stopping.

- **Dim 23 — Auditor-output hygiene (MANDATORY).** Five new probes (register hygiene · cost data persistence · parallel-directory disambiguation · cross-surface terminology consistency · self-output validation loop) catch the meta-gap class previous 22 dimensions didn't probe. `reflex/prompts/qa-agent.md` v0.6.13 grows from 22 → 23 dimensions; QA's own self-evolution loop (Dim 18) is now the mechanism by which new dimensions are added.
- **Nested per-cycle history layout.** `reflex/history/cycle-NN-pass-NNN/` → `cycle-NN/pass-NNN/` (autoloop) and `standalone/pass-NNN/` (single-pass). Sandbox mirrors history layout: `reflex/sandbox/cycle-NN/pass-NNN/`. Per-cycle parent dir hosts a `summary.md` aggregator generated by `reflex/lib/cycle-summary.sh`. Flat identity (`cycle-NN-pass-NNN`) reserved for git branches (`reflex/dev-cycle-NN-pass-NNN`), CSV pass id, and `[source: cycle-NN-pass-NNN]` commit trailers.
- **Autoloop runs until convergence.** Hard 3-iter cap dropped. `reflex/lib/loop.sh` MAX_ITER default ∞ (display only); SAFETY_CAP defaults to 20 (escape hatch, not primary stop). Primary stops are convergence-based: GRANTED · REGRESSION · FINDINGS_FLOOR · FINDINGS_INCREASED · FIX_RATE_DROP · PLATEAU.
- **cycle-summary.sh aggregator.** New `reflex/lib/cycle-summary.sh` generates `reflex/history/cycle-NN/summary.md` per cycle: totals (passes / findings / fixes / tokens / wall) + per-pass breakdown table. Companion to cross-cycle `REFLEX_EVAL_TRACE.md` register. Idempotent.
- **Cycle-01 trace audit fixes (9/9).** pass-002 visible in register as INCOMPLETE (was silently dropped from `update-eval-trace.sh:156` filter on findings.yaml existence); "Autoloop cycle" → "Reflex cycle" terminology unified across register + scripts + flow docs; sandbox-vs-history disambiguation in 17-reflex.md; score.sh `grep -c || echo 0` → `head -1` (closes multi-line "0\n0" bug breaking summary.csv); doc-code-diff.sh path-with-spaces fix (10× scan coverage: 12 → 120 docs); psk-doc-sync.sh --strict tightened (Missing>0 only).
- **First successful Dev-Agent run end-to-end.** cycle-01-pass-004 closed `QA-NOISE-RE-01` bucket A (NOISE_RE backtick-prefix SHA gap), 1 commit `667a7e7`, all 6 mechanical gates green, fast-forward auto-merge to main — first time QA→Dev→merge loop closed without manual intervention.
- **3-layer QA→Dev contract enforcement.** `resume-qa` requires findings.yaml + signoff.md; `resume-dev` requires dev-trace.md; `loop.sh` Phase 4 INCOMPLETE detection. Closes "Dev never spawned on partial QA timeout" silent-skip pattern observed in cycle-01-pass-002.
- **Iter-aware release-prep.** Iter 1 runs `prepare release` (full version bump + ARD/PDF regen); iter 2+ uses `refresh release` (no bump). ~$3-5 + 10 min wall savings per iter on multi-pass cycles.
- **Reflex install template aligned to v0.6.13 layout** (`reflex/install-into-project.sh` gitignore drops legacy `reflex-pass-*` patterns); `agent/scripts/psk-reflex.sh reset` updated for nested layout.

### v0.6.12 — Reflex iter-1 convergence anchor + close all 15 v0.6.11 audit findings (April 2026)

Anchor version for the reflex iter-1 convergence cycle. Consolidates 8 refresh-release commits from v0.6.11. Net: all 15 audit findings (5 pre-existing ARBs + 10 iter-1 QA findings) resolved or properly deferred; kit's own QA infrastructure self-validated end-to-end via reflex iter-1 self-test.

**iter-1 QA findings — all 10 closed:**

- `QA-REL-NONDETERM-01` (CRITICAL): tests/test-release-check.sh self-cleaning rft-cache.
- `QA-KIT-RFT-01` (MAJOR): reflex/lib/check-rft-integrity.sh:138 anchored regex (70 false-positives → 0).
- `QA-KIT-DCD-02` (MAJOR): reflex/lib/doc-code-diff.sh DOC_SURFACES expanded 6→11.
- `QA-PERF-PHASE0-01` (MAJOR): persistent test-ref cache. Cold 54s → warm 5s = 10.9× speedup.
- `QA-PERF-REDUN-01` (MINOR): spawn-qa.sh Layer 6 capture reordered.
- `QA-DOC-HELPER-01` (MINOR): documented audit-integrity.sh + token-report.sh.
- `QA-DOC-RETIRED-01` (MINOR): retired wrapper refs corrected.
- `QA-KIT-EXT-01` (MINOR): external-research.sh Layer 7 N/A short-circuit for bash-only.
- `QA-AUDIT-01` (MINOR): documented register-refresh timing.
- `QA-TEST-COUPLING-01` (MINOR): **Option C thematic split** — tests/lib.sh + tests/sections/{01-infrastructure,02-pipeline,03-reliability,04-reflex}.sh + thin orchestrator.

**5 pre-existing ARBs — all closed:** QA-ARCH-01 (Chrome→WeasyPrint per ADR-006), G2/G5 (verified already-shipped), QA-INT-F70-F1-ARB (C1.5 symlink target check), QA-INT-F70-F52-ARB (layered R→F→T documented as intentional).

**Refresh release commits since v0.6.11 baseline:** `93aaf51` (baseline) · `fff86c1` (Dim 17 + SCRIPT_DIR) · `54c6f1a` (gitignore reflex.lock) · `fd4bf2e` (Dim 18) · `eb27bca` (pass_score) · `825aeb6` (consolidated hotfix chain) · `4c12ac8` (5 ARBs) · `e123243` (9 iter-1 findings) · `3b33298` (Option C test split).

**Tests:** 1633 passing (1488 framework + 145 benchmarking). Per-section: 01-infra 346 / 02-pipeline 395 / 03-reliability 267 / 04-reflex 463. Sync-check 19/19. Release-check 70/70 pass with R→F→T coverage.

**Tagline:** *Iter-1 self-audit complete — kit closed every finding it surfaced about itself.*

### v0.6.11 — Reset allowlist + iter-aware refresh-release optimization (April 2026)

Two kit-infrastructure improvements driven by usage friction noticed during v0.6.10 wrap-up. Both reduce maintenance burden + cost without changing reflex semantics.

**Reset reflex — allowlist behavior + symmetric `--reset-hardening` flag:**

- `reflex/lib/reset.sh` switches from hardcoded glob lists to allowlist-based `find -mindepth 1 -maxdepth 1` traversal. Future-proof: any new pass-naming convention or ad-hoc artifact under `reflex/history/` + `reflex/sandbox/` is auto-cleaned without maintaining glob patterns.
- New `HISTORY_KEEP=("hardening-log.md")` allowlist preserves `reflex/history/hardening-log.md` (kit's structural-defense audit memory — Layer-4 H-NNN entries, append-only by design) across resets.
- Symmetric flag `--reset-hardening` (parallel to `--reset-consent`). Default keeps hardening-log; pass the flag for true clean-slate.
- Sandbox sweep now walks every subdir under `reflex/sandbox/` (entirely gitignored) — no allowlist needed.
- Doc surface updates: header comment, usage block, dry-run report, footer hint, README.md, docs/work-flows/17-reflex.md.
- `reflex/run.sh` parses `--reset-hardening` and forwards to reset.sh.
- +4 N55 test assertions: `--reset-hardening` flag, `HISTORY_KEEP` allowlist, run.sh passthrough, dry-run mentions hardening-log preservation.

**Iter-aware release-prep — `prepare` once, `refresh` thereafter:**

- `reflex/lib/loop.sh` Phase 1 now branches on `ITER`: iter 1 prints `psk-release.sh prepare` (full version bump + ARD/PDF regen — proper kit cadence). Iter 2+ prints `psk-release.sh refresh` (no version bump — captures Dev's auto-merged fixes from prior iter through the same critic gates at ~50% the token + wall-clock cost).
- Rationale: a single converged reflex cycle should not inflate versions. With refresh between iters, all of iter 2-N's Dev fixes accumulate under one version until convergence.
- Dev fixes still merge to main via auto-merge (`reflex/run.sh:421`) when gates green + no regression. Refresh-release commits the doc/test sync on top, satisfying preconditions Gate 2 (regex `^v[0-9]+\.[0-9]+\.[0-9]+:|prep release|refresh release`) for the next QA pass.
- +3 N45 test assertions: `RELEASE_CMD="prepare"` for iter 1, `RELEASE_CMD="refresh"` for iter 2+, iter-aware branching condition.
- docs/work-flows/17-reflex.md: iter-aware Phase 1 box + new "v0.6 Capability Reference" section addressing 24 cumulative doc-coverage gaps from v0.6.5-v0.6.10 surfaced by `psk-doc-sync.sh`.

**Stale-fixture sync (cumulative v0.6.x cleanup):**

- `examples/my-app/agent/RELEASES.md`, `examples/starter/agent/RELEASES.md`, `examples/my-app/agent/AGENT_CONTEXT.md`, `examples/starter/agent/AGENT_CONTEXT.md`, `tests/test-spd-benchmarking.sh` all bumped v0.6.9 → v0.6.10 baseline. Workspace-root `portable-spec-kit.md` synced v0.6.9 → v0.6.10 (was missed in v0.6.10 prep-release).

**Tests:** 1611 passing (1466 framework + 145 benchmarking; +7 new assertions for v0.6.11). Sync-check 19/19. Release-check 70/70 features pass with R→F→T coverage.

**Tagline:** *Reflex resets cleanly + refreshes between passes — same critic discipline, half the cost.*

#### v0.6.11 hotfixes (refresh release commits, in order)

The v0.6.11 baseline shipped at `93aaf51`; four hotfix commits followed under refresh-release semantics, each landing critical infrastructure:

- **`fff86c1` — Dimension 17 (cost & performance audit) + spawn-qa.sh SCRIPT_DIR hotfix.** New mandatory dimension — every pass measures kit efficiency (per-phase token cost, Phase 0 helper wall-clock, mechanical-tool redundancy, cost-per-finding ratio, orchestration overhead) AND project-under-test efficiency (test suite wall-clock, build cycle cost, CLI cold-start, dependency footprint). Findings emit `QA-PERF-{KIT|PROJECT}-{aspect}-NN` with `cost_baseline` + `cost_target` + `recommendation` + `estimated_savings`. Dev mirror principle 8 — performance-aware fixing. Bundled with hotfix to `reflex/lib/spawn-qa.sh:26` adding `SCRIPT_DIR` declaration after `set -uo pipefail` (was used at line 68 but never declared, causing unbound-variable crash on every Phase 0 invocation post-v0.6.7).

- **`54c6f1a` — gitignore reflex.lock for Gate 1 false-positive fix.** `reflex/run.sh` creates `agent/.release-state/reflex.lock` at startup as a concurrency lock (trap removes on EXIT). But `preconditions.sh` Gate 1 runs DURING the run (before EXIT), and the lock file wasn't gitignored — Gate 1 reported "working tree has uncommitted changes" even on a clean tree. Added `agent/.release-state/reflex.lock` to `.gitignore`.

- **`fd4bf2e` — Dimension 18 (QA + Dev philosophy self-audit, meta-evolution).** Closes the loop where the kit's audit philosophy was maintainer-curated. Every pass QA writes `philosophy-gaps.md` listing AT MINIMUM (a) one scenario the 18 dimensions don't cover, (b) one implicit assumption in the probe set, (c) one class of bug that would evade all 18 current dimensions. Each emits `QA-META-PHIL-NN` finding (MEDIUM, advisory, never blocking). Dev mirror — operating principle 9 — writes `dev-philosophy-gaps.md` for fix-pattern gaps + un-disambiguated trade-offs as `QA-META-DEV-PHIL-NN`. Maintainer reviews cross-pass; novel + reproducible scenarios land as Dim 19, 20, etc. **The dimension list grows from real audit-pass discoveries, not the maintainer's imagination.**

- **`eb27bca` — pass_score (Dim 17 ranking) per-pass ROI metric.** New `pass_score` column in `summary.csv` v3 schema (15 cols total, auto-migrates v1/v2 in place). Composite 0-100 score: `(findings_value × fix_efficiency) / ((total_tokens/1000)/findings_value + (wall_clock/60)/findings_value)` capped 0..100. Verdict bands: 70-100 Excellent · 40-70 Good · 20-40 OK · 0-20 Wasted. Surfaced in `REFLEX_EVAL_TRACE.md` per-pass header (`### pass-NNN — verdict: GRANTED · score: **48/100** (Good)`) + `**Cost:** N tokens, M min wall` line. Severity-weighted findings count read from `findings.yaml` (10×CRITICAL + 5×MAJOR + 1×MINOR). Empty score when findings == 0 AND tokens == 0 (insufficient data). Powers convergence stop signal "consistently scoring <20 = wasted budget, halt".

#### Field-test outcome (iter 1 QA pass on kit-self)

`reflex/run.sh single` against the kit produced 10 real findings on kit infrastructure:

- **CRITICAL:** `QA-REL-NONDETERM-01` — `tests/test-release-check.sh` returned 69/70 FAIL then 70/70 PASS minutes later on same HEAD (cache flake; same class as historical QA-REL-05)
- **MAJOR:** `QA-KIT-RFT-01` — `reflex/lib/check-rft-integrity.sh:138` unanchored regex false-positively flags ALL 70 features
- **MAJOR:** `QA-KIT-DCD-02` — `reflex/lib/doc-code-diff.sh` DOC_SURFACES list missing `reflex/README.md`, `agent/design/*.md`, `.portable-spec-kit/skills/*.md`
- **MAJOR:** `QA-PERF-PHASE0-01` — Phase 0 wall-clock 74s vs <2s target = 37× over (Dim 17 fired correctly on first pass)
- **MAJOR:** `QA-TEST-COUPLING-01` — 69/70 features share one test file → one flake breaks 69 features simultaneously
- 5 MINOR findings on documentation + Layer 7 messaging

Verdict: DENIED (3 blocking). Pass tokens: ~193K. Wall: ~25min. Tool calls: 68. **The kit's own QA infrastructure has bugs that escaped existing mechanical gates** — proving reflex's value at the meta level. Findings filed in `reflex/history/cycle-01-pass-001/findings.yaml`; queued for Dev pass to close.

### v0.6.10 — Closing v0.6.9 ARBs: kit's own RFT-debt backfilled + PSK018 strict by default (April 2026)

Acts on the v0.6.9 field-test verdict. Closes `QA-PIPE-FT-01-ARB`: backfilled all 55 missing `### F{N}` acceptance criteria blocks in `agent/SPECS.md` (F1 through F55, complementing the existing F56–F70 blocks). Flipped `PSK018` (per-feature pairwise check in `psk-sync-check.sh`) from advisory to strict-by-default — kit-self compliant first, then enforced.

**Backfill scope:** 55 features × 3-5 acceptance criteria each = ~200 testable acceptance bullets. Each block tied to feature name + design plan reference. All criteria written as `- [x]` (already-shipped) since the features themselves are `[x]` in the table.

**PSK018 flip:** `local strict="${PSK_FEATURE_CRITERIA_STRICT:-1}"` (was `:-${PSK_STRICT:-0}`). Default-strict means a future commit to `agent/SPECS.md` that adds an `[x]` row without a matching `### F{N}` block will fail pre-commit. Opt-out via `PSK_FEATURE_CRITERIA_STRICT=0` for genuine emergencies. Layer 1 R→F→T integrity check (`reflex/lib/check-rft-integrity.sh`) C2-criteria verdict on kit-self drops from 55 breaks → 0 breaks.

**v0.6.10 ARB items still deferred:** `QA-INT-F70-F52-ARB` (reflex × test-harness behavioral integration probe) and `QA-INT-F70-F1-ARB` (reflex × framework-file behavioral integration probe). Both require full QA + Dev pass scope — not field-test scope. Filed in `agent/TASKS.md` for v0.6.11+.

**Tests:** 1604 passing (1459 framework + 145 benchmarking). Sync-check 19/19. Release-check 70/70 features pass with R→F→T coverage.

### v0.6.9 — Field-test pass on kit-self + Layer 5 hub-suppression + Layer 4 hardening landed (April 2026)

**The kit is audited and improved by the reflex it built.** The 7-layer QA + Dev architecture built across v0.6.5-v0.6.8 — Phase 0 deterministic helpers + Senior/Principal-level QA philosophy + paired Dev operating system — was designed to find drift in user projects. v0.6.9 turned that exact machinery on the kit itself: Phase 0 helpers ran on kit-self; a real QA-Agent was spawned to investigate; Dev was assigned to fix what QA filed. **The same QA-Agent that catches bugs in your code caught real bugs in the code that builds the QA-Agent.** Phase 0 exposed 180 mechanical drift items (170 R→F→T pipeline breaks + 10 doc-code drifts) the kit's own existing mechanical gates had passed clean for months. QA filed 5 findings; Dev closed 2 inline (including a Layer-4 inadequacy that would have shipped the kit with 69 of 70 acceptance-criteria blocks deleted under the existing shallow gate). A tool sufficient to audit user projects must be sufficient to audit the project that built it — v0.6.13 proved that proposition. v0.6.9 captures the field-test artifacts as committed evidence + ships the fixes that came out of the pass.

**Field-test pass `field-test-v0.6.8` against kit-self:**

- Phase 0 helpers exposed **180 mechanical drift items** (170 R→F→T pipeline breaks + 10 doc↔code drifts). 0 state-diff deltas (kit-self detected, structurally complete).
- QA-Agent filed **5 findings** (3 MAJOR + 2 MINOR) prioritized for the field-test scope.
- Dev-Agent closed 2 inline + filed 3 to v0.6.10 ARB:
  - **`QA-DOC-FT-02` (Bucket A)** closed — live `kit-loop-state.yml` → `loop-state.yml` rename incompleteness from v0.6.2 caught and fixed in 4 files (`docs/work-flows/17-reflex.md`, `reflex/README.md`, `reflex/lib/loop.sh`, `reflex/lib/reset.sh`). CHANGELOG/RELEASES historical entries kept verbatim.
  - **`QA-TEST-INADEQUATE-F1` (Bucket B)** closed via Layer-4 hardening: `agent/scripts/psk-sync-check.sh` now has `check_feature_criteria_blocks()` (PSK018) doing per-feature pairwise check. Advisory by default; `PSK_FEATURE_CRITERIA_STRICT=1` promotes to hard fail. **Kit's own shallow gate that would have shipped with 69 of 70 acceptance-criteria blocks deleted, now fixed.** Hardening event `H-001` logged in `reflex/history/hardening-log.md`.

**v0.6.9 Layer 5 polish (commit `6aa852a`):**

- `reflex/lib/identify-integration-probes.sh` shared-target hub-suppression. When a single feature appears in ≥10 candidate pairs, it's a hub indexer (e.g. F70 reflex links many; F64 design pipeline cross-refs everything) — pairs involving hubs are mostly noise. New logic moves them to a "suppressed" callout, surfaces hub feature IDs separately. Result on kit-self: 77 → 13 candidate pairs (64 suppressed).
- +2 N61 regression assertions verify hub-suppression annotation + suppressed-count emission.

**Committed evidence (commit `4291fc9`):** the entire `reflex/history/field-test-v0.6.8/` pass directory — claims/state-diff/rft-integrity/doc-code-diff/behavioral-tests/integration-probes/external-research/kit-tools-output + findings/assumptions/coverage/signoff/dev-trace. Permanent record that the kit caught its own defects via its own machinery.

**Tests:** 1604 (1459 framework + 145 benchmarking).

**v0.6.10 ARB tasks deferred (filed in `agent/TASKS.md`):**

- `QA-PIPE-FT-01-ARB` — backfill 55 missing `### F{N}` acceptance criteria blocks (kit's own RFT debt, mechanical work)
- `QA-INT-F70-F52-ARB` — reflex × test-harness behavioral integration probe
- `QA-INT-F70-F1-ARB` — reflex × framework-file behavioral integration probe

After backfill (v0.6.10), `PSK018` flips from advisory to strict — making criteria-block missing a hard pre-commit fail going forward.

**Design discipline:** Same AVACR/Reflex name. The architecture was built v0.6.5-v0.6.8; v0.6.9 is the validation pass. The kit found its own bugs without human pointing — exactly the convergence the architecture promised.

### v0.6.8 — Reflex 7-layer Senior/Principal-level QA + Dev — full implementation (April 2026)

Completes v0.6.7's architecture by shipping deterministic helpers for Layers 3, 5, 7 (QA) and Layer 7 (Dev). All 7 layers now have deterministic-bash seed-helpers wherever possible — LLM creative work goes to genuine reasoning, not derivation.

**Four new helpers:**

- **`reflex/lib/scaffold-behavioral-tests.sh` (QA Layer 3):** generates `behavioral-tests/F{N}-test-plan.md` skeleton per `[x]` feature with 1+5+3+1 structure (1 happy + 5 edge + 3 adversarial + 1 integration). Pulls criteria from `### F{N}` blocks. QA fills TODOs — independence rule: design BEFORE reading Dev's test.
- **`reflex/lib/identify-integration-probes.sh` (QA Layer 5):** scans SPECS for feature interactions via design-plan + criteria-block cross-references. Emits `integration-probes.md` with candidate pairs.
- **`reflex/lib/external-research.sh` (QA Layer 7):** scans project manifests (`package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Dockerfile`) and emits `external-research.md` with seeded WebSearch/WebFetch queries: per-dependency CVE searches, framework-changelog URLs, OWASP Top 10 mapping for project class.
- **`reflex/lib/auto-extract-adl.sh` (Dev Layer 7):** post-pass, scans Dev's commits for substantive bodies (≥200 chars) with rationale keywords. Drafts ADL entries to `agent/.release-state/adl-drafts.md`.

**Wiring:** `reflex/lib/spawn-qa.sh` invokes the 3 new QA helpers in Phase 0 BEFORE sandbox creation. Pass dir contains 8 pre-populated artifacts when QA spawns. QA prompt + Dev prompt updated with new artifact references.

**Tests:** +32 N61 assertions. Total: 1601 (1456 framework + 145 benchmarking).

**Field-tested on kit-self:** Layer 3 produces 70 test-plan skeletons in <1s · Layer 5 finds 77 candidate pairs · Layer 7 QA gracefully detects stack signals · Layer 7 Dev drafts ADL entries when commits have rationale.

### v0.6.7 — Reflex 7-layer Senior/Principal-level QA system (April 2026)

Closes the user-articulated need for a fully-autonomous QA that "the user does not need to be QA of their own project." Builds on v0.6.6 Phase 0 pre-compute by adding four new verification layers, codifying Senior/Principal-level QA + Dev philosophies in the prompts, and structuring all per-pass artifacts so QA's findings derive entirely from the project's spec pipeline + kit toolkit + running system — zero human-curated lists.

**The 7 verification layers (run every pass):**

- **Layer 1 — R→F→T pipeline integrity** (`reflex/lib/check-rft-integrity.sh`, deterministic bash, Phase 0). For every `[x]` feature in `agent/SPECS.md`, verifies: maps to Rn in REQS.md (R→F traceability), has acceptance criteria block (`### F{N}`), has design plan at `agent/design/f{N}-*.md`, Tests column references real test file, test contains non-trivial assertions (no `toBeDefined` trivia / `test.skip` / TODO markers), test exits 0 when run, has `[x]` mark in TASKS.md. Each break = CRITICAL `QA-RFT-N` finding. Output: `rft-integrity.yaml` in pass dir.
- **Layer 2 — Bidirectional doc ↔ code consistency** (`reflex/lib/doc-code-diff.sh`, deterministic bash, Phase 0). Two-direction probe: doc-to-code (every named file/script/version/count/capability claim → grep code for backing), code-to-doc (every kit script + every `[x]` feature → at least one doc surface mentions it), plus numerical-claim cross-check (test count consistency across README/CHANGELOG/SPECS). Drift = finding. Output: `doc-code-diff.yaml`.
- **Layer 3 — Behavioral per-feature verification** (mandate in `qa-agent.md` Phase 2, LLM). For every `[x]` feature, QA generates its own test plan independently of Dev's test: 1 happy + 5 edge cases + 3 adversarial inputs + 1 integration scenario. **Independence rule**: design own test BEFORE reading Dev's. Output: `behavioral-tests/F{N}-test-plan.md` + `F{N}-results.yaml` per feature.
- **Layer 4 — Test-quality audit** (mandate in `qa-agent.md` Phase 3, LLM). After Layer 3, read Dev's test for each feature: would it catch QA's adversarial inputs? Are mocks honest? Coverage adequate? Inadequate Dev test = MAJOR `QA-TEST-INADEQUATE-F{N}` finding even if test currently passes. Output: `test-quality-audit.yaml`.
- **Layer 5 — Cross-feature integration probes** (mandate in `qa-agent.md` Phase 2, LLM). Identifies pairs of `[x]` features that interact (auth × data, search × permissions, export × authentication). Designs integration scenarios that surface compose-time bugs single-feature tests miss. Output: `integration-probes.md`.
- **Layer 6 — Production readiness via kit tools** (`reflex/lib/spawn-qa.sh` captures, Phase 0). Invokes the kit's existing instruments and lands their output as research input for QA: `psk-sync-check.sh --full`, `psk-doc-sync.sh`, `tests/test-release-check.sh agent/SPECS.md`, `psk-code-review.sh`. Every PSK error code, every MISSING in doc-sync, every R→F→T break in release-check becomes evidence backing a finding. Output: `kit-tools-output/{sync-check,doc-sync,release-check,code-review}.txt`.
- **Layer 7 — External reality check** (mandate in `qa-agent.md` Phase 2, LLM + WebSearch/WebFetch). For any code touching network / dependencies / standards / framework APIs: cross-check against latest OWASP Top 10, CVE feeds for project's dependencies, framework deprecations (e.g., transformers `as_target_processor()` removal in v4.44), best-practice patterns for the stack. Output: `external-research.md` with cited source URLs.

The original 16-dimension checklist is preserved as a **safety net** — runs after the 7 layers, catches classes the layers might miss. **Short-circuit rule**: if Layer 1 (`rft-integrity.yaml`) or Mode B (`state-diff.yaml`) shows CRITICAL deltas indicating structural break, halt the pass with those findings and skip the 16-dim sweep — fix structure first, behaviors second.

**Senior/Principal-level QA + Dev philosophies (codified in prompts):**

- `reflex/prompts/qa-agent.md` gains a "Your role and philosophy (v0.6.7)" preamble: Senior/Principal-level QA engineer; sources of truth are project-derived, never human-curated; 7 operating principles (independence, bidirectional consistency, aggressive coverage, test-the-test, use-the-toolkit, external reality, surface-everything); 4 forbidden moves (trusting Dev's test, skipping "obvious" features, self-filtering low-confidence findings, maintaining curated miss-lists).
- `reflex/prompts/dev-agent.md` gains a parallel preamble: Senior/Principal-level engineer who closes gaps QA surfaces and hardens the implementation; 7 operating principles (build-don't-just-patch, atomic commits, mechanical-gates-first, sibling-class hardening, no-speculation, update-spec-pipeline-alongside-fix, add-structure-that-prevents-recurrence); three gap classes per pass (fix findings + build unfulfilled claims + remediate state-diff deltas) — all in the same dev branch.

**Architecture plan committed to repo:** `agent/design/f70-reflex-senior-engineer-qa.md` documents the full 7-layer design, philosophy preambles, what stays from v0.6.5/v0.6.6, what was discarded (the qa-blind-spots registry approach explored mid-design then rejected as wrong-shape), and the v0.6.7-v0.6.11 implementation sequencing.

**Tests:** +39 N60 assertions (plan doc, Layer 1 helper + behavioral, Layer 2 helper + behavioral, qa-agent.md philosophy + 7 mandates + independence rule + 1+5+3+1 probe pattern, dev-agent.md philosophy + new artifact reads + sibling-class hardening, spawn-qa.sh wires Layer 1 + Layer 2 + Layer 6 capture, Phase 0 ordering, 16-dim safety net preserved). Total: 1569 (1424 framework + 145 benchmarking).

**Design discipline:** This is an extension within AVACR/Reflex, NOT a new framework. Adversarial Actor-Critic + verbal feedback + refinement loop unchanged. What changed: probe-set derivation (paper-defined → project-derived) + Critic phase structure (16-dim checklist as primary → 7-layer system + safety net) + Dev scope (patch-only → patch + build + remediate). Same outer name — Reflex.

**Impact on the user-articulated need:** the original playground scenario (Copilot scaffolds project without install.sh, reflex grants 3 passes despite empty agent/scripts/) is now caught by Layer 1 (rft-integrity flags missing test refs / criteria) + Layer 2 (doc-code-diff flags scripts mentioned in docs but not present) + Layer 6 (psk-sync-check captures structural drift) + Mode B (state-diff CRITICAL deltas auto-promote). Multiple layers redundantly catch the same class — by design, so a single layer's miss does not let the gap escape. **The user reviews `findings.yaml` and approves push. They do not investigate.**

### v0.6.6 — Reflex Phase 0 pre-compute (claims + reference-state + assumption probing) (April 2026)

Closes the meta-gap surfaced in v0.6.5 review: reflex QA ran 3 GRANTED passes against an infrastructurally-empty project and missed every kit gap because its probe set was a closed 16-dim checklist from the AVACR paper. Adding dimensions reactively fixes one case each but does not prevent the NEXT unknown class — QA always misses the bug outside its list.

This release moves reflex from "fixed checklist" to "probe-set derived from the project itself," **while keeping the 16-dimension checklist as a safety net** (not replaced). Three additions compose: claims, reference-state, and assumption surfacing. Each is deterministic bash pre-compute — <1s, <100 tokens — so QA's LLM budget focuses on semantic verification.

- **`reflex/lib/extract-claims.sh` (Mode A):** walks README, portable-spec-kit.md, SPECS, CHANGELOG, RELEASES, AGENT_CONTEXT, qa-agent.md — extracts every public claim (version numbers, test counts, feature counts, shipped capabilities, script inventory, skill count, install one-liner, dimension count). Emits `claims.yaml` with `probe_type` + `probe_target`. QA verifies each or files a finding. Unverified claim = finding. Vague claim = finding.
- **`reflex/reference-state/speckit-project.yaml` + `reflex/lib/state-diff.sh` (Mode B):** static reference defining what a complete speckit project must contain (required files, pipeline files, dirs, git hooks, entry-point symlinks, exclusions). State-diff compares actual vs reference and emits `state-diff.yaml` with every delta pre-classified by severity. CRITICAL deltas auto-promote to CRITICAL findings. Kit-self auto-detected — skips user-project-only checks.
- **QA Phase 0 wiring in `reflex/lib/spawn-qa.sh`:** both helpers run BEFORE sandbox creation so `claims.yaml` + `state-diff.yaml` land in the pass directory. QA reads these in Phase 0 (no LLM cost to re-derive) and uses them to plan Phase 1. The 16-dim checklist is explicitly labeled "safety net" catching classes the three modes might miss.
- **Assumption surfacing (Mode C) in `reflex/prompts/qa-agent.md`:** every pass writes `assumptions.md` listing every implicit assumption ("kit is installed," "test harness exits 0 on green," "every `[x]` feature implemented"). For each, QA MUST write a probe that verifies or falsifies it. Unverifiable assumption = MAJOR `QA-ASSUMPTION-NN` finding.
- **Dev-Agent "build, don't just patch" (expanded scope) in `reflex/prompts/dev-agent.md`:** Dev now closes three gap classes in the same pass — (a) findings from `findings.yaml`, (b) unverified claims from `claims.yaml`, (c) reference-state deltas from `state-diff.yaml`. Build missing capability to fulfill claim; restore missing infrastructure; add structure that makes assumptions self-verifying. Scope guardrails preserved (no out-of-SPECS features, protected files banned).
- **Short-circuit on CRITICAL state-diff:** if Phase 0 flags a CRITICAL delta (e.g. install.sh never ran), QA halts with that single finding instead of wasting budget on a 16-dim sweep of a structurally-broken project. Extends v0.6.5's bootstrap-gate principle inside the QA phase.

**Tests:** +31 N59 assertions (reference-state parseable, state-diff 0 deltas on kit + >0 on synthetic incomplete project, extract-claims emits probe types, qa-agent.md documents Phase 0 + preserves 16-dim, dev-agent.md has build directive, spawn-qa.sh invokes both helpers BEFORE sandbox creation, e2e pass-dir artifact presence). Total: 1518 (1373 framework + 145 benchmarking).

**Design discipline:** extension within AVACR/Reflex, NOT a new framework. QA is still Critic, Dev is still Actor, adversarial-with-collaborative-outcome loop unchanged. What changed is QA's probe-set derivation — paper-defined → project-derived — and Dev's scope — patch-only → patch + build + remediate.

### v0.6.5 — Kit-bootstrap integrity gate (4-layer defense against un-installed-kit projects) (April 2026)

Closes the failure mode where a non-kit-aware agent (Copilot asked to "set up a new project and run prep-release + reflex", plain-Claude writing `agent/*.md` by hand, or a clone of a repo that never ran install.sh) can scaffold a project, commit a `v0.N.N:` subject that satisfies reflex Gate 2, and proceed end-to-end through prep-release + reflex passes — all while the project has **zero kit scripts, no hooks, no skills, no CLAUDE.md, no `.portable-spec-kit/config.md`**. Surfaced by an audit of the `psk-playground/urdu-stt-distillation` project which passed 3 reflex GRANTED verdicts despite being infrastructurally empty.

- **New `agent/scripts/psk-bootstrap-check.sh`** (298 lines, shared helper): 7 structural checks (C1-C7) — framework file + entry-point symlink, `.portable-spec-kit/config.md`, core 6 kit scripts executable, ≥10 cached skill files, pre-commit hook wired to psk-sync-check, all 9 `agent/*.md` pipeline files, test harness. Modes: `--quiet` (exit codes only), `--json` (machine-readable verdict), `--remediate` (auto-invokes parent `install.sh`). Kit-self detected automatically via `portable-spec-kit.md` real-file + `install.sh` + `reflex/` — skips symlink/config checks for the kit repo itself.
- **Layer 2 — `psk-release.sh` Step 0 (fail-fast):** `run_bootstrap_gate()` fires before `init_state` on `prepare`/`refresh`. FAIL prints the full bootstrap report + remediation command and exits 1 — no release state written. Bypass: `PSK_BOOTSTRAP_CHECK_DISABLED=1` (genuine emergencies only).
- **Layer 3 — `reflex/lib/preconditions.sh` Gate 0a:** runs after Gate 0 (self-test identity) and before Gate 1 (clean tree). Script resolution prefers target project's own `psk-bootstrap-check.sh`; falls back to kit's copy (catches the exact case where target has zero scripts). Same bypass envvar.
- **Layer 4 — QA-Agent Dimension 16 (Kit-bootstrap integrity):** new mandatory dimension documented in `reflex/prompts/qa-agent.md`. Runs FIRST (even before Phase 1 Plan) — if C1-C7 fails, halt pass with single CRITICAL `QA-BOOTSTRAP-NN` finding. Defense-in-depth for bypassed precondition. Dimension count updated 15 → 16 throughout prompt.
- **Tests:** +11 N57 assertions (psk-bootstrap-check.sh presence + exec, kit self passes, `--json` emits parseable verdict, synthetic incomplete project correctly FAILS with `critical>=1`, detects missing scripts + config, psk-release.sh has gate wired, preconditions.sh has Gate 0a wired, qa-agent.md documents Dim-16, header says 16 dimensions). Total: 1488.
- **Flow docs updated:** `docs/work-flows/13-release-workflow.md` gains Step 0 box before Step 1; `docs/work-flows/17-reflex.md` expanded preconditions description to list Gates 0 / 0a / 1 / 2. Dimension count updated 14 → 16 in reflex doc.

**Impact:** structurally impossible now for an un-bootstrapped project to run prep-release or reflex. Kit self unaffected (passes all C1-C7 via kit-self detection). Any project scaffolded manually without running `install.sh` fails fast at Step 0 / Gate 0a with a copy-paste remediation command.

### v0.6.4 — Reflex convergence stopping + loop-resume fix + gates cache fix + token tracking (April 2026)

Five orchestration fixes surfaced by the autonomous v0.6.3 reflex run. All generic — apply identically to kit self-test, new projects, existing projects, any user project.

- **Convergence-based stopping (N56):** replaces the naïve "max 3 iterations" cap with real convergence signals. Stop conditions: GRANTED (primary), REGRESSION (safety), `findings_floor` reached, findings increased (Dev made it worse), plateau (findings didn't decrease for `patience_passes`), fix-rate drop (below `min_fix_rate`), or `max_iterations_safety` as escape hatch. Configurable in `reflex/config.yml` → `convergence:` block (defaults: `patience_passes: 2`, `min_fix_rate: 0.5`, `max_iterations_safety: 10`).
- **`--loop --resume` collision fix:** bare `--resume` used to hijack mode to `resume-qa`, silently skipping loop-state resume when combined with `--loop`. `run.sh` now defers flag resolution: `LOOP_FLAG` + `RESUME_FLAG` are set during arg parsing, then resolved after — `--loop --resume` routes to `loop-resume` mode (correctly invokes `loop.sh --resume`).
- **`gates.sh` cache-order bug:** `tests/test-release-check.sh` writes `agent/.release-state/rft-cache.txt` that `psk-sync-check.sh --with-tests` reads. Sequential gate runs saw stale cache → false failures. `gates.sh` now clears the cache at entry; each gate starts clean.
- **Token tracking (`reflex/lib/track-tokens.sh`):** per-pass qa_tokens + dev_tokens + tool_calls + wall_seconds aggregated into `reflex/history/token-usage.csv` with `tokens_per_finding` optimization signal. Per-pass + per-cycle budget warnings (`per_pass_budget_tokens: 250000`, `per_cycle_budget_tokens: 1500000`). Cross-pass trend detection surfaces improving/worsening tpf as diminishing-returns hint.
- **Iteration auto-chain on gate-fail:** spurious gate failures no longer abort the autoloop — only REGRESSION + verdict/findings-trend signals halt. Pass continues as long as convergence hasn't fired.

**Tests:** 1409 → 1465 (1320 framework + 145 benchmarking; +24 N56 assertions covering convergence config, loop.sh stop logic, gates cache-clear, `--loop --resume` resolution, loop-resume mode, track-tokens helper, budget warnings, tpf metric).

### v0.6.3 — Autonomous reflex run validation (April 2026)

Mechanical patch triggered by an autonomous end-to-end reflex run on the v0.6.2 consolidation. Prep-release validated the full reflex architecture (Dev-branch isolation, protected-files write-ban, autoloop, history retention, reset command, unified cycle naming) through the kit's own prepare-release pipeline. QA-Agent surfaced 11 findings (3 CRITICAL including a dead-code branch-regex in the 3-layer write-ban); Dev-Agent landed 11/11 fixes in 6 atomic commits on the dev branch, fast-forward merged to main.

### v0.6.2 — Dev-branch isolation + protected-files write-ban + autoloop + history retention (April 2026)

Closes the reflex execution-model loop: QA was already sandboxed; Dev now runs on a dedicated branch with a 3-layer write-ban on the two files the spec-persistent pipeline owns. Also unifies the "iterate until GRANTED" command for kit + user projects and adds bounded-disk history retention.

- **Dev-branch isolation:** every reflex pass runs Dev on a dedicated `reflex/dev-pass-NNN` branch created off current HEAD by `reflex/lib/spawn-dev.sh`. User's main branch stays untouched during the pass. On GRANTED + gates PASS + no regression, `reflex/run.sh` fast-forward merges (or falls back to `--no-ff` on divergence) into the parent branch and deletes the dev branch. On DENIED / REGRESSION / MANUAL_REVIEW the branch is retained (last 3 unhappy kept for diagnosis, older pruned). Commit convention `autoloop fix QA-<ID>: <reason>` + `[source: reflex-pass-NNN]` trailer verified by `reflex/lib/gates.sh`.
- **Protected-files write-ban:** 3-layer enforcement that `agent/AGENT.md` and `agent/AGENT_CONTEXT.md` are never modified by reflex findings. Layer 1 — `reflex/prompts/dev-agent.md` mandates NEVER modify these files + route recommendations touching them as Bucket D + human-arbitration. Layer 2 — `reflex/lib/gates.sh` branch-scoped diff check fails any commit on `reflex/dev-pass-*` that touches them. Layer 3 — `psk-sync-check.sh check_reflex_protected_files` blocks the commit at the pre-commit hook when on a reflex branch (PSK011 error code). Keeps the adversarial loop from rewriting the project's canonical narrative.
- **Autoloop generalization:** bare `bash reflex/run.sh` now defaults to autoloop (prep-release + reflex pass + iterate until GRANTED, max 3 iters). `--autoloop` / `--loop` / `--kit-loop` flag aliases retained for backward compat. Behavior identical across kit / new project / existing project / user project via kit-identity auto-detection. (Earlier `reflex/autoloop.sh` wrapper script consolidated into `run.sh` — see "Entry consolidation" bullet below.)
- **History retention:** new `reflex/lib/prune-history.sh` helper bounds disk growth. Config in `reflex/config.yml history_retention:` block with defaults `pass_dirs_keep: 10`, `dev_branches_keep: 3`, `qa_sandbox_keep: 3`. `reflex/run.sh` invokes prune at the start of every pass. `--purge-history --confirm` command wipes all prunable artifacts. Register + `summary.csv` kept forever; pruned pass dirs surface as `_(archived)_` rows in `REFLEX_EVAL_TRACE.md` with status still resolvable from TASKS.md, drill-down links removed.
- **Concurrency + empty-pass:** `agent/.release-state/reflex.lock` (flock preferred, PID-file fallback) refuses a second reflex run while one is active. Empty-pass shortcut: 0-finding QA passes write GRANTED verdict directly, no Dev branch created, no spawn needed — autoloop exits the loop cleanly.
- **Intake parser update:** `reflex/lib/intake.sh` YAML-block parser extracts findings from the embedded `findings.yaml` code block in GitHub issue bodies (matches the v0.6.2+ `--submit-to-kit` compose format). Deterministic awk + minimal Python, no PyYAML dependency.
- **Sandbox purge after QA:** `reflex/lib/file-bugs.sh` removes the current pass's QA sandbox worktree the moment findings are extracted into `reflex/history/<pass>/`. Dev physically cannot read QA's private workspace — structural enforcement, not trust-based.
- **Pass-dir naming — cycle + pass visible:** directories renamed to `cycle-NN-pass-NNN/` (autoloop) and `standalone-pass-NNN/` (single-pass). `ls reflex/history/` now shows cycle boundaries at a glance; alphabetically sortable; pass numbers stay globally monotonic. Sandbox worktrees follow: `reflex/sandbox/qa-cycle-NN-pass-NNN/`.
- **Cycle metadata + grouped register render:** each pass dir gets `.cycle-meta` (cycle id + iteration + mode + started timestamp) written at pass creation. `reflex/lib/update-eval-trace.sh` groups register blocks by autoloop cycle with `## Autoloop cycle N` headings and `iter N` labels per pass.
- **All per-pass artifacts committed:** `.gitignore` no longer excludes `pass-plan.md`, `project-understanding.md`, `qa-summary.md`, `qa-usage.yaml`, `test-plan.md`, `dev-trace.md`, `deferred-decisions.md`. Every file QA / Dev produces is now auditable from git. Retention policy bounds disk growth; only `reflex/sandbox/` stays gitignored.
- **Entry consolidation — single CLI surface:** `bash reflex/run.sh` is now the sole public entry; default mode = autoloop. Wrapper scripts retired: `reflex/autoloop.sh`, `reflex/kit-loop.sh`, `reflex/self-test.sh`, top-level `reflex/loop.sh`. New positional `single` flag invokes single-pass mode (used internally by loop.sh per iteration and exposed for debugging).
- **Unified cycle-NN-pass-NNN naming — no more standalone-pass:** every pass now gets a cycle id. Autoloop invocations share a cycle id across iterations; bare single-pass / `--qa-only` invocations auto-assign the next cycle id (1 cycle = 1 pass for ad-hoc runs). The previous `standalone-pass-NNN/` naming is retired; legacy names honored read-only.
- **Reflex reset command — nuclear wipe:** `bash reflex/run.sh --reset [--confirm] [--reset-consent]` via `reflex/lib/reset.sh`. Deletes every pass directory, sandbox worktree, dev branch, runtime state file, register, summary.csv, latest.md. Consent marker preserved by default. Dry-run without `--confirm`.

**Tests:** 1353 → 1465 (1320 framework + 145 benchmarking; +56 framework assertions across Dev-branch creation, 3-layer write-ban, autoloop, history retention, archived-pass rendering, lockfile, empty-pass shortcut, intake YAML parser, register integration test, sandbox purge, cycle metadata, grouped register, entry consolidation, pass-dir rename, unified cycle naming, reset command).

### v0.6.1 — Kit self-evolution loop: empirical kit evolution, MINIMAL template tier, 14 framework-gap closures (April 2026)

Large dual-track release closing the empirical-kit-evolution loop end-to-end and adding a third response-template tier for latency cuts.

**Reflex / AVACR evolution (adopter + maintainer sides)**
- **N33 adopter-side auto-submit:** new `reflex/lib/auto-submit.sh` dispatcher at end of every pass. Three modes: `manual` (default, no behavior change), `prompt` (y/n with 10s timeout), `auto` (fire-and-forget). Four guards: consent marker + pass filter (verdict in {NEEDS_FIX, REVOKED} OR kit/meta scope) + 24h rate limit + anonymize. Opt-in via `bash reflex/run.sh --enable-auto-submit --i-understand-privacy-implications`. Config in `reflex/config.yml` under `upstream_submission:`. Audit log at `reflex/history/auto-submit-log.csv`.
- **N38 maintainer-side intake automation:** new `reflex/lib/intake.sh` + `.github/workflows/kit-intake.yml`. Weekly Monday 09:00 UTC GitHub Action fetches open `avacr-eval` issues, parses kit/meta-scope findings, drafts `agent/tasks/Gxx-<slug>.md` task files from template, opens an intake-review PR with `intake-review-pending` label. Parser is deterministic Python (no LLM on intake path). Manual run via `bash reflex/intake.sh`.
- **N44/N45 general-purpose runner + kit-loop:** mode-less `bash reflex/run.sh [--target <path>]` where kit-identity detection drives routing automatically. New `--kit-loop` chains prep-release plus self-test with max 3 iterations via state machine at `agent/.release-state/kit-loop-state.yml`. Convenience wrappers `reflex/kit-loop.sh` and `reflex/self-test.sh` (retired in v0.6.2 per entry-consolidation; use `bash reflex/run.sh` and `bash reflex/run.sh --self-test`). `--help` / `-h` prints usage.
- **Trace continuity across passes (QA reads prior trace):** QA-Agent prompt now mandates reading the prior pass's `findings.yaml` (structured evidence with `regression_vector.invocation_verbatim` + `expected_assertion`) and `signoff.md` (verdict + deferred decisions) at Phase 1, plus the cross-pass `REFLEX_EVAL_TRACE.md` register. `spawn-qa.sh` surfaces all three paths in the task-file preamble.
- **Per-pass canonical trace (Q1):** every pass commits `findings.yaml` (structured, one entry per finding with citable_quote + regression_vector + recommendation) plus `signoff.md` (verdict GRANTED/DENIED + blocking findings + deferred decisions). Cross-pass `reflex/history/REFLEX_EVAL_TRACE.md` register auto-aggregates every finding from every `findings.yaml` into one reviewable index (id · severity · scope · status · one-line summary) via `reflex/lib/update-eval-trace.sh`. The earlier 8-section `AVACR_EVAL_TRACE.md` narrative was consolidated into this three-file model (structured + verdict + register) — reduces duplication across artifacts.
- **14 kit framework gaps closed (G1-G15 less G11):** parser + regex consistency across `reflex/lib/` (G1+G2+G5+G6); `test-templates.md` skill with live-uvicorn fixture (G7); G11 pre-shipped via canonical trace template; rate-limit escape-hatch docs (G13); serial-execution trade-off disclosure in f70-reflex design (G14); spawn-qa SQLite artifact purge (G9); per-pass token accounting with v2 summary.csv schema (G15); `file-bugs.sh` schema validator + dim-floor enforcement (G8); machine-readable coverage YAML block (G10); minimum-per-dimension probe count rule (G12); preconditions accept reflex-install commits (G3); `--recover` diagnostic + `reflex/lib/recover.sh` for partial Dev state (G4).

**Response Format Rule tier ladder + latency**
- **MINIMAL template (3rd tier) for short answers:** breadcrumb + border + headline + optional one-paragraph body + arrow. Target ~2s gen time, ~80-100 tokens. Use for yes/no / status checks / short factual recalls / simple acknowledgments. BRIEF remains default for multi-dimensional answers; DETAILED on explicit depth request.
- **Auto-dispatch rule:** trigger table maps answer shape to template tier — the agent picks, the user does not specify. Override phrases: `"shorter"` drops a tier, `"more depth"` promotes one, `"raw reply"` strips scaffolding.
- **Writing Style sub-section (5 editorial rules):** one idea per sentence · periods over em-dashes · drop semicolons · cut parenthetical asides unless load-bearing · one voice per reply.
- **Breadcrumb rules 6a + 6c + 6d:** trailing `✓`-hint of most-recently-closed sibling (6a) · skip breadcrumb on consecutive MINIMAL replies in same node (6c) · arrow footer optional in MINIMAL with no next action (6d). Rule 6b (IDs-only compact) shipped then reverted per user feedback — clarity beat the ~15-token savings.
- **Pre-send self-check:** mandatory 4-anchor check (breadcrumb · border · template body · arrow footer) run silently before every reply. No exemptions for "let's discuss" or "status update" or post-compact replies.

**Session-stack evolution (G18 follow-ups)**
- **3-tier long-session scalability:** T1 auto-collapse 3+ consecutive `✓` siblings into `Nx–Ny ✓ <summary>` · T2 default-render active chain on `"where was I"` (full tree on `"show full stack"`) · T3 mid-session chapter rotation at ≥15 KB or ≥80 nodes into `.session-archive/YYYY-MM-DD-chapter-NN.md`.
- **Promotion rule:** closed `✓` session-stack node with durable project work (code/docs changes) prompts for `agent/TASKS.md` entry before session end.
- **Pre-session read list updated:** `.session-stack.md` added to the session-start read order (item 4 of 11).
- **Skill trigger for "where was I" / "losing context" / "conversation-stack":** auto-loads `.portable-spec-kit/skills/session-trace.md`.
- **Skill trigger for "integration tests" / "FastAPI" / "live-server":** auto-loads the new `.portable-spec-kit/skills/test-templates.md`.

**Tooling quality-of-life**
- **Rule-revision post-mortem meta-rule:** an ADL entry is required in `agent/PLANS.md` when any framework rule is revised ≥3 times in a single session (learning-from-churn).
- **Unpushed-commit advisory in psk-sync-check:** `--full` mode warns at ≥10 unpushed commits on current branch. Threshold configurable via `PSK_UNPUSHED_WARN`.

**Tests:** 1152 → 1353 (1208 framework + 145 benchmarking; +79 framework assertions across G1-G15 coverage + MINIMAL/BRIEF/DETAILED template structure + Writing Style rules + dispatch rule + breadcrumb rules + N33 guards + N38 pipeline + N45 target flag + kit-loop state machine + trace continuity + cross-pass findings register).

### v0.6.0 — AVACR: Reflex evolves to adversarial goals with peer-to-peer exchange

F70 Reflex evolves from VACR (cooperative refinement) to **AVACR — Adversarial Verbal Actor-Critic Refinement Loop**. The loop gains explicit asymmetric goals (QA-Agent goal = FAIL the release, Dev-Agent goal = FOOLPROOF it against QA's hunt), physical sandbox isolation, and machine-parseable peer-to-peer YAML exchange — so humans read only the final signoff, never agent working output.

- **Adversarial-goal reframing:** QA defaults to DENIED and must affirmatively earn GRANTED across 14 dimensions with research-grounded evidence. Dev's goal is not "close the ticket" but "make the release unbreakable against QA's next hunt" (sibling-class hardening mandated). Convergence = QA hunts hard and cannot find a blocker, not "Dev says it's done."
- **Physical sandbox isolation:** QA-Agent operates in a git worktree at `reflex/sandbox/qa-pass-NNN/` with `agent/AGENT.md` and `agent/AGENT_CONTEXT.md` removed. Dev's narrative files cannot bias QA's fresh-context investigation — enforced by filesystem, not prompt discipline. Dev-Agent retains full-repo access for diagnosis + fix.
- **Peer-to-peer YAML exchange:** QA writes `findings.yaml` (per-finding: priority + dimension + blast_radius + confidence + reproducibility + escalation + citable_quote + regression_vector + standard + recommendation); Dev returns `dev-result.yaml` (fixed / rebuttals / routed_to_human / escalated / deferred). No human translation between the agents.
- **14-dimension adversarial hunt:** functional / edge-case / cross-pipeline / workflow / research-backed-quality / superficiality / production-readiness / security (OWASP) / performance / architectural-compliance / documentation / test-quality / tech-debt / readiness-affirmation.
- **4-persona testing:** every feature exercised as new-user / power-user / malicious-user / accessibility-user.
- **Research capability:** QA cites RFCs, OWASP, benchmarks, papers with real URLs and verbatim quotes; citable-quote honesty gate (bash grep-verifiable).
- **4-bucket Dev diagnosis + Bucket-D rebuttal:** A (doc wrong) / B (code wrong) / C (both) / D (QA misread — requires counter-citation in `dev-result.yaml > rebuttals`).
- **Human-arbitration escalation:** findings tagged `escalation: human-arbitration` are routed to `@<human>` in TASKS.md; Dev does not auto-fix cross-cutting / ADL-amendment concerns.
- **Flaky-vs-deterministic distinction:** non-reproducing findings trigger root-cause investigation, not patch-and-retry.
- **Coverage declaration + regression-vector re-execution:** QA writes `coverage.md` enumerating tested × dimensions AND untested surface (with reasons). Regression vectors preserved per-finding and re-executed verbatim every pass; failure upgrades priority by one level.
- **CHANGELOG truth-check mandate:** every bullet in the current version's CHANGELOG must have a test case; unverifiable claims → `QA-REL-{N}` blocks signoff.
- **Signoff discipline:** QA issues GRANTED (with affirmative readiness statement + evidence + acknowledged limitations) or DENIED (with exit criteria in ordered priority). Human reads only `signoff.md`.
- **Prompts rewritten:** [reflex/prompts/qa-agent.md](reflex/prompts/qa-agent.md) and [reflex/prompts/dev-agent.md](reflex/prompts/dev-agent.md) fully rewritten around the adversarial-goal framing with the 14-dimension schema and peer-exchange contract.
- **Sandbox mechanism:** [reflex/lib/spawn-qa.sh](reflex/lib/spawn-qa.sh) creates the worktree, removes prohibited files, passes dual-rooted access (`REFLEX_QA_WORKTREE` for reads, `REFLEX_QA_PROJECT` for invocations), cleans old worktrees (keeps last 3 for debugging history).
- **Design plan §4-5 and §18:** [agent/design/f70-reflex.md](agent/design/f70-reflex.md) rewritten to match new roles + paper outline updated with 16 novel primitives (was 6) including adversarial-goals-with-collaborative-convergence as #1.
- **Consistency sweep:** `cycle` → `pass` (~30 refs across live scripts + CSV header), `Refine` → `Reflex` (3 pre-existing stragglers including real install/update URL bugs), `Remediation` → `Refinement`.
- **Bug fixes surfaced during sweep:** [reflex/install-into-project.sh](reflex/install-into-project.sh) was installing into non-existent `$TARGET/refine` (fixed to `reflex`); [reflex/update.sh](reflex/update.sh) `KIT_RAW_BASE` pointed at 404 URL `/main/refine` (fixed to `/main/reflex`).
- **Paper title update:** VACR → *"Adversarial Verbal Actor-Critic Refinement (AVACR): Multi-Agent Verbal Reinforcement Learning with Asymmetric Goals for Spec-Grounded Post-Release Program Repair"* (target venues: ICSE / FSE / ASE).
- **SPD paper v2 §7.6 cross-reference:** AVACR cited as the functional-validation mechanism in the "gates replace review" framework (reading-speed ceiling argument).

**Tests:** 1007 framework + 145 benchmarking = 1152 (unchanged total; 2 assertion strings updated in Section 60m to verify AVACR formal name and black-box discipline).

---

## v0.5 — Full Development Pipeline + Requirements + Research (April 2026)
**Built over:** v0.5.1 — v0.5.23 · **Tests:** 1152 (1007 framework across 71 sections + 145 benchmarking)

### v0.5.23 — F70 Reflex: VACR formal naming + psk-reflex.sh command driver + literature grounding
- **Literature-grounded rename:** `autoloop/` → `reflex/`, `@autoloop-dev` → `@reflex-dev`, `f70-autoloop.md` → `f70-reflex.md`, `17-autoloop.md` → `17-reflex.md`. Formal name **Verbal Actor-Critic Refinement Loop (VACR)**.
- **Pattern classification (literature review):** Reflexion-style verbal reinforcement learning (Shinn et al. 2023) applied to multi-agent Automated Program Repair (APR), with convergence as fixed-point iteration. **Not** adversarial GAN (cooperative, no weight training). **Not** classical Actor-Critic RL (no policy gradient — inference-time topology only). Primary citations: **Reflexion** (Shinn et al. 2023), **Self-Refine** (Madaan et al. 2023), **Goodfellow et al. 2014** (topology reference), **Sutton & Barto** (Actor-Critic topology), **Liu et al. 2023** (Lost-in-the-middle — the principal failure mode this pattern counters), **SWE-agent** (Yang et al. 2024).
- **Deep-learning vocabulary mapping** (user-facing operational terms):
  - `epoch` = one full QA→Dev cycle
  - `loss` = open QA findings count (objective: → 0)
  - `convergence` / `equilibrium` = cycle with zero new findings AND no regressions (fixed-point reached)
  - `early stopping` = patience-based halt (P consecutive epochs without loss decrease)
- **`agent/scripts/psk-reflex.sh`** — new user-facing command driver with 7 subcommands:
  - `prepare` — auto-detects prepare-vs-refresh release and runs the full pipeline thoroughly before any refinement
  - `qa` / `qa --resume` — run QA-Agent (Critic) alone, save findings to TASKS.md, no Dev-Agent spawn
  - `dev` / `dev --resume` — run Dev-Agent (Actor) alone against existing QA findings; no new QA cycle
  - `epoch` — one full QA→Dev cycle
  - `train --epochs N [--patience P]` — up to N epochs with early stopping; stops on convergence OR P consecutive epochs with no loss decrease (defaults: N=5, P=2)
  - `status` — latest epoch verdict + summary.csv trend
  - `reset` — clear per-epoch state (keeps summary.csv)
- **Precondition strengthening:** `psk-reflex.sh prepare` wraps `psk-release.sh prepare` / `psk-release.sh refresh` (auto-detected). User must run `prepare` first (or already be at a prep-release HEAD) before any refinement subcommand.
- **Script header** carries the full research citation block as living documentation — reading `psk-reflex.sh` shows the 6 papers grounding the pattern, the DL-vocabulary mapping, and the pattern family classification.
- **Section 60m tests expanded** — driver presence, all 7 subcommands, `--epochs` + `--patience` flags, convergence detection, early stopping logic, epoch terminology, 6 literature citations, VACR formal name, prepare wraps psk-release.sh, autoloop/ removed. Framework tests: 987 → 1007.
- **install.sh** — `psk-reflex.sh` added to the reliability-scripts download list; `--install-autoloop` flag renamed to `--install-reflex`. README install line: 14 → 15 scripts.
- **Tests:** 987 → 1007 framework; 1132 → 1152 total (sections unchanged at 71).

### v0.5.21 — F70 Refine (Actor-Critic Remediation Loop)
- **`reflex/`** — new directory: orchestrator, lib helpers, Critic + Actor prompts, config, history. Post-prep-release automated QA + auto-fix cycle. Two fresh-context sub-agents (QA-Agent black-box + Dev-Agent full-repo) share one codebase, communicate via file-based protocol (`qa-task.md` / `qa-result.md`, `dev-task.md` / `dev-result.md`) — same pattern as existing `psk-critic-spawn.sh`.
- **QA-Agent (Critic)** — reads full speckit pipeline (REQS/SPECS/PLANS/DESIGN/TASKS/RELEASES + running system). Black-box: cannot read source (`src/*`, `agent/scripts/*`, `reflex/`). 7 verification levels (L1 requirements → L7 integration). Files bugs to TASKS.md with `@reflex-dev` assignment, citable spec refs, severity taxonomy (CRITICAL/MAJOR/MINOR/NIT).
- **Dev-Agent (Actor)** — reads `@reflex-dev` tasks, 4-bucket diagnosis (A doc-wrong / B code-wrong / C both / D QA-misread), atomic commits (1 task = 1 commit) with mechanical gates per commit. Max 3 retries before `[~]` human escalation. No feature creep — only closes QA-identified gaps.
- **Precondition** — HEAD must be a prep-release commit (detected via message pattern: `^v0.N.N:` / `prep release` / `refresh release`). Refuses mid-development state, prevents false positives from half-built features.
- **Regression diff** — `lib/regression-diff.sh` compares TASKS.md across cycles; flags previously-`[x]` tasks that reappear. `lib/score.sh` appends `reflex/history/summary.csv` with surprise_density + progress trend.
- **`install-into-project.sh`** — deploys reflex into any speckit project with auto-detected mechanical gates (npm test / pytest / go test / bash tests / psk-sync-check / psk-doc-sync / test-release-check). Verified on `examples/my-app/` and `examples/starter/`. `update.sh` refreshes from kit while preserving local `config.yml` + `history/`. `install.sh --install-reflex` opt-in flag installs reflex alongside the kit.
- **Integration** — reuses `agent/TASKS.md` multi-agent task tracking (`@username`), Jira sync via `psk-jira-sync.sh` (config-gated), hours tracking via `psk-tracker`. Full audit trail: TASKS → Jira → commits → RELEASES. No new bug-tracking system.
- **Smoke tests (both phases ran end-to-end on the kit):**
  - Phase 1 (QA-only): 5 real gaps existing structural gates cannot see (62 features missing design plans, F69 acceptance subsection missing, PLANS/AGENT stack inconsistency vs ADR-006, plan-template/actual mismatch, PLANS Verification test count drift).
  - Phase 2 (QA + Dev): 7 of 8 findings auto-fixed with atomic commits + green gates. QA-ARCH-01 properly escalated `@human`. Caught real latent distribution bug (`psk-doc-sync.sh` missing from `install.sh` / `sync.sh`).
- **Framework rule added** — plan-mode → implementation transition triggers the plan-to-pipeline sync: save plan to `agent/design/f{N}.md`, add SPECS F row + acceptance criteria subsection, add per-phase TASKS, update AGENT_CONTEXT phase, add PLANS.md ADL rows. Codified in `portable-spec-kit.md` Feature Plans section.
- **Docs** — flow doc `docs/work-flows/17-reflex.md`, design plan `agent/design/f70-reflex.md` (609 lines), README "Latest Release" mention, ARD Technical Overview F70 bullet.
- **Tests (Section 60m, 45 new):** directory structure, core scripts executable, QA black-box + citable-quote honesty, Dev atomic commits + retry + 4-bucket, precondition logic, `[~]` acknowledgment, file-bugs idempotency, gates.sh config reading, regression detection, score.sh CSV schema, run.sh 4 modes, installer validation + auto-detect + .gitignore, F70 SPECS/design/ADL presence, framework plan-to-pipeline sync rule.
- **ADRs** — ADR-012 (2-agent Actor-Critic over multi-agent pipeline), ADR-013 (same-repo `reflex/` over separate repo), ADR-014 (decoupled trigger + post-prep-release precondition), ADR-015 (reuse TASKS.md + Jira + `@reflex-dev` assignment over new bug DB).
- **Research foundations:** Generator-Discriminator topology (Goodfellow et al. 2014); Reflexion verbal feedback loops (Shinn et al. 2023); Process Reward Models (Lightman et al. 2023); Spec-driven program synthesis (Solar-Lezama 2008); Lost-in-the-middle failure mode (Liu et al. 2023) — the principal pattern reflex counters.
- **Tests:** 942 → 1007 framework; 1087 → 1152 total; 70 → 71 sections. 45 new tests in Section 60m.

### v0.5.20 — Full-surface documentation coverage analyzer + stale-state guard
- **Stale release-state detection (`state_is_stale()` in `psk-release.sh`)** — guards against the failure mode caught during this very release: a prior interrupted `prepare` left `agent/.release-state/state` with steps 1–8 marked `done`. On the next `prepare release` (day later, different target version), `next` silently skipped steps 1–8 because the markers still said `done`. Fix: `run_next` now refuses to resume if (a) `RUN_ID` is >24h old, or (b) `START_VERSION` (captured at `init_state`) differs from `AGENT_CONTEXT.md` AND `STEP_6_VERSION` is still pending. `init_state` also clears `.validate-stamp` so the critic gate starts fresh. Section 60l adds 8 tests.
- **`psk-doc-sync.sh`** — new CHANGELOG → full doc coverage analyzer. Extracts every feature from the current-minor CHANGELOG entry and checks coverage across ALL 5 documentation surfaces: `agent/*.md`, `docs/work-flows/*.md`, `docs/research/*.md`, `ard/*.html`, `README.md`. Reports per-feature COVERED (≥2 surfaces) / PARTIAL (1 surface) / MISSING (0 surfaces) with a surface-legend breakdown `[AFPDR]` and suggested target doc per gap.
- **Step 4 replaced with doc-sync analyzer** — the release-process skill, `13-release-workflow.md` flow doc, and Step 4 box-diagram now mandate running the analyzer; the old "scan flow-docs folder" heuristic is removed. Agent iterates: add to suggested doc OR create new flow doc, re-run analyzer, until `Missing=0`.
- **Critic prompts wired to the analyzer** — `STEP_4_FLOW_DOCS` and `STEP_9_VALIDATION` critic prompts now include an "AUTOMATED COVERAGE TOOL" clause: critic MUST run `psk-doc-sync.sh` and treat every `MISSING` line as a STALE verdict. Bash determinism + sub-agent semantic judgement pair up on the same evidence.
- **Extended noise filter** — drops internal PSK error codes, section headers, trailing-colon labels, paper-section refs, and release-meta phrases so the analyzer only reports real user-facing features.
- **Section 60k added (19 tests)** — analyzer existence, clean advisory run, all 5 doc surfaces covered, A/F/P/D/R legend codes, `--strict` flag, `suggest_doc()` presence, critic prompt references, skill/flow-doc wiring.
- **Surfaces real v0.5.x doc-drift backlog** — first run on the kit itself reports 27 MISSING features shipped through v0.5.8–v0.5.19 (PSK012–PSK017, bypass audit log, RFT cache, compact critic output, etc.) that need individual doc coverage. To be closed incrementally in v0.5.20+ now that the gate exists to enforce it.
- **Sync-check unchanged at 18 checks** — PSK016 (orchestrator ↔ flow-doc cross-ref) remains the commit-time mechanical gate. PSK017 verifies critic prompts retain OMISSION DETECTION + CROSS-DOC FEATURE COVERAGE language. The new analyzer is the Step 4 workflow tool, not a PreCommit check (that surface would be too noisy and not every local commit needs it; the gate fires at release).

### v0.5.19 — Prep Release Comprehensive (PSK016/017 + critic prompt hardening)
- **Critic prompts strengthened for omission detection** — root cause of v0.5.13–v0.5.18 flow doc drift was that `STEP_4_FLOW_DOCS` and `STEP_9_VALIDATION` critic prompts only caught **contradictions** (wrong info) but not **omissions** (missing info). Prompts now explicitly require: (a) read CHANGELOG current-minor entry, (b) for each feature, verify ≥1 flow doc mentions it, (c) for each feature, verify it appears in flow docs + README + ARD.
- **Orchestrator ↔ flow-doc cross-reference mandated in prompts** — each of the 5 executable-workflow orchestrators (`psk-release.sh`, `psk-new-setup.sh`, `psk-existing-setup.sh`, `psk-init.sh`+`psk-reinit.sh`, `psk-feature-complete.sh`) must be mentioned in its corresponding flow doc. Critic now explicitly checks these mappings.
- **PSK016 `check_flow_docs_content`** — mechanical counterpart to the critic prompt strengthening. Fires at every commit. Verifies each executable-workflow orchestrator script is mentioned by name in its corresponding flow doc. Caught real drift on kit's own repo: `05-project-init.md` was missing `psk-reinit.sh` reference.
- **PSK017 `check_critic_prompts_comprehensive`** — meta-check. Verifies `STEP_4_FLOW_DOCS` and `STEP_9_VALIDATION` critic prompts still contain the required "OMISSION DETECTION" and "CROSS-DOC FEATURE COVERAGE" sections. Prevents future edits from silently weakening the prompts and re-opening the drift loophole.
- **`05-project-init.md` updated** — now describes both `psk-init.sh` (3 lines) AND `psk-reinit.sh` orchestrators with their specific preflight behaviors. PSK016 validates this going forward.
- **Section 60j added (20 tests)** — PSK016/017 function presence + dispatch + error codes + all 5 orchestrator mappings + prompts actually contain the strengthening language.
- **Sync-check now 18 checks** (was 16). Direct commits still unforced (user preference preserved); prep release catches more when it runs.

### v0.5.18 — README Structural Checks (PSK013/014/015)
- **PSK013 `check_readme_install_list`** — verifies README Quick Start install list counts match disk. Checks three declared numbers in the `Installs:` line: reliability scripts (`ls agent/scripts/psk-*.sh | grep -vE '(jira|tracker)'`), skill files (`.portable-spec-kit/skills/*.md`), CI templates (`.portable-spec-kit/templates/ci/ci-*.yml`). Mismatch = blocked commit.
- **PSK014 `check_readme_agent_table`** — verifies the README "Agent Directory" table row count (Pipeline + Support rows) matches actual `agent/*.md` file count. Adding a 10th agent file without updating the table blocks commits.
- **PSK015 `check_readme_flow_table`** — verifies the README Flows table row count matches actual `docs/work-flows/*.md` file count. Adding/removing a flow doc without updating the table blocks commits.
- **Reliability-script definition refined** — excludes optional Jira/tracker scripts (`psk-jira-sync.sh`, `psk-tracker.sh`, `psk-tracker-report.sh`) which aren't "reliability" infrastructure. Install.sh already distinguishes these via separate `scripts` vs `optional` variables.
- **Section 60i added (13 tests)** — function presence + dispatch + error codes + jira/tracker exclusion + current kit state passes all 3 checks.
- **Sync-check now 16 checks** (was 13). README drift now blocked at 4 structural dimensions: Latest Release (PSK012), install list counts (PSK013), agent table rows (PSK014), flow table rows (PSK015).

### v0.5.17 — README Restructure + PSK012 README Content Check
- **README restructured** — Quick Start (install) moved to top right after the feature matrix. Installation command is now above the fold for any GitHub visitor.
- **"What's New in v0.5" → "Latest Release" (compact)** — replaced the accumulating narrative + patch-matrix table with a 2-line summary + links to CHANGELOG.md and GitHub Releases. Release details live in their dedicated page (CHANGELOG.md), not duplicated in README.
- **"What's New in v0.4" removed** — full history belongs in CHANGELOG.md, not in README.
- **Redundant Setup section deduplicated** — advanced install options (verify-before-running, non-interactive) consolidated; the verbose "what gets installed" bullet list is now in Quick Start near the top.
- **Framework rule updated** — `release-process.md` skill now mandates: "Latest Release" section in README is REPLACED (not appended) on minor version bump. Prevents README from growing unboundedly and pushing install instructions below the fold.
- **PSK012 check_readme_content** — new 13th deterministic check in `psk-sync-check.sh --full`. Verifies: (1) `## Latest Release` or `## What's New in v{current_minor}` heading exists, (2) section body references the current minor version, (3) section is substantive (≥200 chars, not placeholder), (4) section links to CHANGELOG.md, (5) at most one `## What's New in vX` heading (replace-don't-accumulate rule). Runs via PreCommit hook.
- **Section 60h added (7 tests)** — check_readme_content function + dispatch + PSK012 error code + framework rule + README has Latest Release + links to CHANGELOG + no accumulated What's New sections.

### v0.5.16 — Performance + Ecosystem + Compact Critic
- **RFT cache (Opt 10)** — `check_rft_gate` in `psk-sync-check.sh` now caches result at `agent/.release-state/rft-cache.txt`, invalidated when `agent/SPECS.md` or any `tests/*.sh` mtime exceeds cache mtime. **60× speedup on the kit repo** (18.5s → 0.3s). Bypass via `PSK_RFT_NO_CACHE=1`. Zero reliability impact — cache only reuses a result when no relevant input changed.
- **Compact critic output (Opt 7)** — `output_discipline()` footer now appended to every critic task file (all 8 templates). Instructs the sub-agent to return *only* CURRENT/QUOTE/STALE lines, target ≤400 tokens, skip preamble and explanation. Reduces per-release critic cost.
- **CI templates for user projects** — `.portable-spec-kit/templates/ci/` now ships 4 stack-aware GitHub Actions templates (`ci-node.yml`, `ci-python.yml`, `ci-go.yml`, `ci-generic.yml`) plus a README. Each runs the stack's native test command + R→F→T gate + `psk-sync-check --full` (incl. PSK011) + bypass-log detector. Agent copies the right template when user says "enable CI". `install.sh` + `sync.sh` now distribute the templates.
- **Section 60g added (16 tests)** — RFT cache presence + mtime invalidation + bypass env var · output_discipline function + wiring · 5 CI templates exist · each template runs sync-check · distribution script wiring · migration backup safety.

### v0.5.15 — Verbatim-Quote Critic (Sub-Agent Honesty Gate)
- **Closes the 70% architectural ceiling** on sub-agent honesty. Before: a lazy or hallucinating sub-agent could write `CURRENT: file.md` without ever reading the file. Now: every `CURRENT:` verdict requires a `QUOTE:` line on the next line with a verbatim string (≥20 chars) from the named file. Bash grep-verifies the quote actually exists in the file — fabricated quotes fail.
- **All 6 critic templates updated** — `STEP_4_FLOW_DOCS`, `STEP_8_RELEASES`, `STEP_9_VALIDATION`, `FEATURE_COMPLETE`, `INIT`, `REINIT`, `NEW_SETUP`, `EXISTING_SETUP` all require `CURRENT:` + `QUOTE:` pairs.
- **`verify_quotes()` added to `psk-validate.sh`** — parses `critic-result.md`, pairs every `CURRENT:` with its `QUOTE:`, and runs `grep -qF` against the named file. Rejections: missing QUOTE, QUOTE <20 chars, QUOTE not found in file. Fixed-string grep avoids regex interpretation of quote content.
- **Exit code 3 now fires on unverifiable quotes** — same path as `STALE:` verdicts. Critic must be re-spawned with real reads.
- **Section 60f added (12 tests)** — verify_quotes function presence, invocation, grep -F usage, min-length check, and all 8 templates (STEP_4/8/9 + 5 workflow) require QUOTE:.
- **Section 60 expanded with 2 new behavioral tests** — `CURRENT without QUOTE → exit 3`, `fabricated QUOTE → exit 3`. Plus existing `all-CURRENT with verified QUOTE → exit 0`.

### v0.5.14 — Distribution Gaps Closed + CI Workflow
- **`install.sh` expanded from 7 → 13 scripts** — previously missing `psk-validate.sh` + 5 orchestrators (`psk-feature-complete`, `psk-init`, `psk-reinit`, `psk-new-setup`, `psk-existing-setup`). New users running `curl | bash` now get the complete dual-gate infrastructure.
- **`sync.sh` expanded to match** — author's publish script now copies all 13 reliability scripts.
- **`.github/workflows/ci.yml` created** — framework previously *claimed* CI but no workflow existed. New file runs on every push/PR: test-spec-kit + test-spd-benchmarking + test-release-check + **psk-sync-check --full (including PSK011)** + bypass-log sanity check. Server-side enforcement now real, not aspirational.
- **Paper v2 Section 4.6.2a added** — "Security as Layer 2A Concern" — explains PSK011, placeholder-awareness, masked output. Paper now reflects both reliability and security hardening.
- **Section 60e added (7 new tests)** — install.sh ships all 13 scripts · sync.sh ships all 13 · ci.yml exists · CI runs each of the 4 gates. Catches future distribution drift.

### v0.5.13 — Secret Scanning (PSK011)
- **`check_secrets` added to `psk-sync-check.sh --full`** — new 12th deterministic check. Scans tracked files (via `git grep`) for real-format credentials and blocks commits that contain them.
- **12 high-signal secret patterns:** AWS access key (`AKIA[0-9A-Z]{16}`), AWS secret key (assignment form), GitHub PAT (`ghp_`), GitHub fine-grained PAT (`github_pat_`), GitHub OAuth/App tokens (`gho_`/`ghs_`), Anthropic API key (`sk-ant-api*`), Google API key (`AIza*`), Slack token (`xox[baprs]-*`), Stripe live/restricted keys (`sk_live_*`/`rk_live_*`), private key PEM headers (RSA/OPENSSH/EC/DSA/PGP/ENCRYPTED).
- **Placeholder-aware:** lines containing `paste-your`, `your-api-key`, `<your-`, `example.com`, `placeholder`, `changeme`, `XXXX`, `REDACTED`, `dummy`, `test-key`, `fake-`, `sample-` are excluded so `.env.example` and docs don't false-positive.
- **Path exclusions:** `.env.example/.sample`, `node_modules/`, `vendor/`, `tests/fixtures/`, `__pycache__/`, `.git/`, binary files (`*.pdf`, `*.png`, `*.zip`, fonts, media), minified JS, lock files, and the scanner itself.
- **Fast:** single `git grep` with combined regex alternation (one process, parallelized) instead of N-files × N-patterns fork loop. Completes in <2s on the kit repo.
- **Masked output:** when a hit is found, PSK011 prints `file:line: firstchars...` so the secret value itself doesn't end up in logs/CI output.
- **PreCommit hook automatically enforces:** since `check_secrets` runs as part of `--full`, and PreCommit hook already runs `--full`, any attempt to commit tracked files containing real credentials is blocked immediately.
- **Section 60d added (11 new tests):** presence of check_secrets + dispatch wire + PSK011 error code + 3 critical regex patterns (AWS / Anthropic / private-key) + placeholder exclusion + path exclusion + combined-regex 12-pattern count + AWS regex validity + placeholder regex validity + git-grep optimization.
- **Closes the gap** between the framework's security rule ("NEVER commit secrets") and mechanical enforcement — trust-only → structurally blocked.

### v0.5.12 — Confidence Hardening Across 7 Items
- **Step 4 per-flow-doc critic verdict** — replaces mtime-only check which could be satisfied by editing a single flow doc. `psk-release.sh` now spawns `STEP_4_FLOW_DOCS` critic and requires every flow doc file to have an explicit `CURRENT:` verdict (missing files flagged, any `STALE:` blocks).
- **Bypass audit log** — `agent/.bypass-log` records every use of `PSK_SYNC_CHECK_DISABLED=1` and `PSK_CRITIC_DISABLED=1` with timestamp, user, workflow. `psk-sync-check.sh --full` surfaces a warning if any bypass happened in the last 24h. Gitignored (local trail).
- **5 workflow orchestrators** — `psk-feature-complete.sh`, `psk-init.sh`, `psk-reinit.sh`, `psk-new-setup.sh`, `psk-existing-setup.sh`. Each runs workflow-specific preflight checks (feature-complete enforces R→F→T + design plan + no TODO stubs; reinit snapshots agent/*.md byte counts to detect content loss; existing-setup snapshots non-kit files to detect destructive edits) then delegates to the dual gate via `psk-validate.sh`.
- **Section 60c added** — 21 new tests verify orchestrators exist, call `psk-validate.sh`, have their specific preflight checks, Step 4 uses critic verdict, bypass audit logs both env vars + gitignored + surfaces in sync-check + behavioral "bypass triggers log entry" test.

### v0.5.11 — Behavioral Tests for Dual Gate
- **3 behavioral regression tests added to Section 60** — verify `psk-validate.sh release` actually behaves correctly: missing critic-result exits 2 (`AWAITING_CRITIC`), STALE exits 3 (blocks), all-CURRENT exits 0 (passes).
- Closes the "tests lie" gap from v0.5.10 (Section 60 had presence tests only, not behavioral).
- Tests use `PSK_SYNC_CHECK_DISABLED=1` to isolate critic-gate logic from bash critic. State is backed up/restored so tests don't disturb in-flight releases.

### v0.5.10 — Dual-Gate Reliability Across All Executable Workflows
- **`psk-validate.sh` generic dual-gate helper** — single entry point for final validation of 6 executable workflows (release, feature-complete, init, reinit, new-setup, existing-setup). Exit codes: 0 pass, 1 bash fail, 2 AWAITING_CRITIC, 3 critic stale, 4 usage.
- **5 new critic templates** — `FEATURE_COMPLETE`, `INIT`, `REINIT`, `NEW_SETUP`, `EXISTING_SETUP` with workflow-specific checks (R→F→T for feature, non-destructive adoption for existing-setup, content preservation for reinit).
- **psk-release.sh Step 9 refactored** — now delegates to `psk-validate.sh release`; single source of truth for dual-gate logic across workflows.
- **5 flow docs updated** — 03-new-project-setup, 04-existing-project-setup, 05-project-init, 11-spec-persistent-development (feature-complete), 13-release-workflow all reference `psk-validate.sh <workflow>`.
- **Framework MANDATORY rule** — portable-spec-kit.md + hooks-and-critics.md: agent runs psk-validate.sh at the end of every executable workflow.
- **Section 60 added** — 25 new tests verify dual-gate coverage end-to-end (helper presence, 6 workflow branches, freshness, bypass vars, 5 templates, release delegation, flow doc refs, core doc refs).
- **Paper v2 Section 4.6.4a** — "Uniform Application Across All Executable Workflows" with table of all 6 workflows + argument for uniformity.

### Highlights
- **Jira Cloud integration** — `psk-jira-sync.sh` syncs completed tasks to Jira via REST API v3. Explicit-only (`sync to jira`), never automatic. PID-based lock, 5× retry with Retry-After, sanitized SYNC_RESULT.json
- **Automatic hours tracking** — Track A (agent session wall-clock) + Track B (psk-tracker OS daemon). Combined, deduplicated, confirmed by user before any Jira post
- **psk-tracker daemon** — OS-level 10s poll, FOCUS/BLUR logs, macOS/Linux/Windows support, WSL detection, headless/Docker exit
- **Feature Design Pipeline** — every feature in SPECS.md gets a design plan in `agent/design/`. 3 triggers: explicit, auto on SPECS.md, implementation gate. Decisions auto-flow to PLANS.md ADL
- **Auto Code Review (F65)** — two-layer review (psk-code-review.sh mechanical + AI judgment). Security anti-patterns, naming, TODO, secrets, structure. Runs after feature completion, advisory not blocking
- **Scope Drift Detection (F66)** — 5-dimension drift check (feature drift, requirement gaps, scope creep, architecture drift, plan staleness). psk-scope-check.sh with drift score. Proactive at session start
- **Release pipeline expanded** — prepare release now 9 steps (added code review + scope check after tests). Summary block shows 11 rows
- **Agent directory structure** — `agent/` root = markdown only, `agent/design/` = plans, `agent/scripts/` = bash
- **Reliability Architecture (v0.5.8)** — 3-layer enforcement: Layer 2A bash critic (`psk-sync-check.sh`, 8 checks, mode auto-detection), Layer 2B sub-agent critic (`psk-critic-spawn.sh`, file protocol, 3 templates), Layer 3 hooks (PostToolUse warns, PreCommit blocks). Release pipeline reordered (validation at Step 9 final gate, version bump automated at Step 6). Core file reduced 1998→912 lines (54%), 17 skill files. `install.sh` bundles full infrastructure for end users. `psk-uninstall.sh` for clean removal. ARD HTML files (both Technical Overview + Guide) describe v0.5 features in full.
- **ARD content update rule (MANDATORY)** — ARDs must describe features added this release, not just version/count bumps. Added to release-process.md skill + flow doc 13 + release summary block.

### Framework Changes
- Jira Integration section + Time Tracking section added to portable-spec-kit.md
- AGENT.md template: Jira Config (URL, project key, mappings, transition mapping, idle threshold)
- ADL format updated: Plan Ref column links decisions back to design files
- Development flow: SPECS → design/ → PLANS.md → TASKS → RELEASES (5-stage pipeline)
- Sync rule: 5 pipeline files (includes plan state update)
- Agent-Created Files rule: scripts/ subdirectory, directory structure diagram

### New Files
| File | Purpose |
|------|---------|
| `agent/scripts/psk-jira-sync.sh` | Jira REST API v3 sync script |
| `agent/scripts/psk-tracker.sh` | OS-level window focus daemon |
| `agent/scripts/install-tracker.sh` | Daemon installer (macOS/Linux/Windows) |
| `agent/scripts/uninstall-tracker.sh` | Daemon uninstaller |
| `agent/scripts/psk-tracker-report.sh` | Track B JSON report generator |
| `tests/mock-jira-server.sh` | Mock Jira HTTP server for testing |
| `tests/fixtures/jira/*.json` | 7 Jira API fixture files |
| `agent/scripts/psk-code-review.sh` | Automated code review (mechanical layer) |
| `agent/scripts/psk-scope-check.sh` | Scope drift detection (5 dimensions) |
| `docs/work-flows/15-jira-integration.md` | Jira sync flow doc |
| `docs/work-flows/16-feature-design.md` | Feature design flow doc |

### Tests
| Section | Tests | What it validates |
|---------|:-----:|-------------------|
| Section 51 | 28 | Jira integration rules, scripts, Track A/B, dedup, commands |
| Section 52 | 15 | Auto code review rules, two-layer, trigger, advisory |
| Section 53 | 12 | Scope drift detection, 5 dimensions, drift score, triggers |

---

## v0.4 — CI/CD Pipeline + Spec-Based Test Generation + Team Intelligence (April 2026)
**Built over:** v0.4.1 — v0.4.11 · **Tests:** 781 (636 framework across 50 sections + 145 benchmarking)

### Highlights
- **GitHub Actions CI** — ci.yml runs all 3 test suites on every push and PR; release.yml verifies tag matches framework version on v* tag push
- **Framework CI/CD rules** — every user project now gets CI guidance during setup: ci.yml template, Step 7.5, stack-aware test commands (Jest/pytest/Go/Bash), Existing Project Setup checklist CI item
- **CI & Community Contributions section** — 4 rules: CI badge rule, branch protection guidance, PR workflow, contribution validation
- **Spec-Based Test Generation** — forward flow only: SPECS origin detection, per-feature acceptance criteria format (### F{n} subsections), stub generation trigger, stack-aware stubs, stub completion gate
- **`check_stub_complete()`** — added to test-release-check.sh (kit copy + template); blocks release if test stubs have unfilled TODO markers
- **Community files** — PR template, bug report + feature request issue templates
- **Cross-platform sed fix** — test-spd-benchmarking.sh now runs on Ubuntu (GitHub Actions)
- **Section 41 gate hardening** — 5 new tests enforce ARD version badge, flow doc Kit refs, benchmarking fixture Kit refs, example Kit fields — gaps that previously required manual doc audits
- **Section 42** (29 tests) + **Section 43** (15 tests) — CI/CD and spec-gen validated on every prepare release
- **Flow documentation overhaul** — `docs/system-flows/` → `docs/work-flows/`; 3 flow docs overhauled to reflect current system; `development-release.md` added (full 8-step gate with Section 41 groups, stub gate, pre-push gate)
- **`check_stub_complete()` grep bug fixed** — `grep -cE ... || echo 0` → `grep -E ... | wc -l` (macOS: grep -c exits 1 on 0 matches, causing doubled output and integer comparison failure)

### Framework Changes
- **CI & Community Contributions** — CI badge rule, branch protection guidance, PR workflow rule, contribution validation rule
- **ci.yml template** — shipped in portable-spec-kit.md with `{TEST_COMMAND}` + `{SETUP_STEPS}` placeholders; stack-aware command detection table
- **New Project Setup Step 7.5** — create `.github/workflows/ci.yml` after stack confirmed; always includes `test-release-check.sh agent/SPECS.md`
- **Existing Project Setup checklist** — CI item added
- **Branch & PR Workflow** — CI must be green before merging any PR; branch protection guidance
- **Spec-Based Test Generation section** — 8 rules: origin detection, per-feature criteria format, stub generation trigger, no-criteria edge case, retroactive flow rule, stub generation steps, stack-aware formats, stub completion gate
- **SPECS.md template** — global `## Acceptance Criteria` → per-feature `## Feature Acceptance Criteria / ### F{n}` format
- **test-release-check.sh template** — `check_stub_complete()` + stub gate added (shipped to all new user projects)
- **New Project Setup Step 4** — updated to mention stub generation when criteria written

### Flow Documentation (v0.4.3)
- `docs/system-flows/` → `docs/work-flows/` — renamed, all references updated across 20+ files
- `spec-persistent-development.md` — per-feature criteria in Phase 1; stub lifecycle (RED/GREEN) + CI update step in Phase 3; prepare release 8-step gate in Phase 4; CI step in Pipeline Sync
- `new-project-setup.md` — Step 1 per-feature criteria + stubs; Step 6 CI workflow creation; renumbered
- `development-release.md` — new: full prepare release gate, 3 test suites breakdown, Section 41 groups, stub gate, pre-push gate, edge cases
- Section 41 flow doc count test fixed: grep pattern updated "system flow" → "work flow"

### Flow Documentation (v0.4.5)
- **2 new flow docs** — `11-existing-project-setup.md`: Step 0 state detection (Mapped/Partial/New), full scan flow, edge cases table, contrast with returning session; `12-cicd-setup.md`: stack detection, ci.yml generation, CI badge, branch protection, pre-push gate, PR contribution gate
- **All 12 flow docs aligned** — 63-char box-line standard enforced via Python `unicodedata.east_asian_width`; emoji-wide characters (✅, 🔍) accounted for correctly
- Section 19 expanded: "All 12 Flows + Diagram Integrity" — file existence + title/trigger + content tests for all 12 flows
- README flow table: rows 11 + 12 added; "10 step-by-step flows" → "12 step-by-step flows"
- ARD HTML: flow table rebuilt (12 rows, # column), all count references updated

### Flow Documentation (v0.4.4)
- All 10 flow docs updated with ASCII box diagrams
- `development-release.md` — developer workflow diagram added (DEVELOP → run tests → prepare release → commit → push → verify)
- `returning-session.md` — Step 0 kit status, 5-step read order, Kit update flow with stale sweep + codebase scan, profile/scan decoupling
- `first-session-workspace.md` — profile/scan decoupling, scan announcement
- `file-management.md` — Kit Update scan flow, decision diagram, edge cases
- `user-profile-setup.md` — 2 missing edge cases from framework
- All remaining flows: diagrams added, content audited and accurate

### Flow Documentation + Commands (v0.4.6)
- **Flow docs reordered** — logical user journey: onboarding (01-06), session management (07-10), development (11-12), release (13). 10 files renumbered.
- **New `05-project-init.md`** — `init`/`reinit` explicit command flows: deep scan, agent file create/sync, SPECS/PLANS staleness check, edge cases table, init vs reinit comparison table
- **Renamed** — `12-project-lifecycle.md` (was requirements-to-delivery), `13-release-workflow.md` (was development-release)
- **`init` / `reinit` commands** — added as explicit signals in framework with full 10-step and 8-step flows respectively
- **Test Execution Flow** — extracted as named section, referenced by all test-running commands (run tests, prepare/update/refresh release, push gate). Eliminates redundancy across flows.
- **Version bump BEFORE push rule** — added to Versioning Rules: bump → commit → push order enforced, anti-pattern documented
- **README commands table** — expanded to all 9 commands with accurate descriptions; release summary corrected (10 steps, Flows step added)
- Section 19 updated: all 13 flow file names corrected

### Release Flow Hardened (v0.4.9)
- **ARD audit rule** — uses `ard/*.html` glob; covers all current and future ARD files (no hardcoded filenames)
- **WeasyPrint loop** — `for f in ard/*.html; do weasyprint "$f" "${f%.html}.pdf"; done` — works for any number of files
- **Section 41 + 2 tests** (total 33): kit `agent/AGENT_CONTEXT.md` Version+Kit match; `CHANGELOG.md` built-over range includes current version — closes last two silent failure modes
- **Section 41 count corrected** — documented as 28, actual was 31 → now 33; flow doc and ARD updated
- **ARD Guide version fix** — `ard/Portable_Spec_Kit_Guide.html` was stale at v0.4.6; now at v0.4.9
- **TASKS.md §8.1** — F58/F59/F62 confirmed implemented, marked `[x]`; paper test count updated to 781
- **Section 49 — Kit Self-Validation** (8 tests): example symlink validity (both examples, all 5 agent config files), Progress Summary table required in TASKS.md, AGENT.md/SPECS.md/RELEASES.md template compliance, root/Projects copy sync check; +7 symlink tests in Sections 6, 7, 11
- **Section 50 — Kit Framework Self-Validation** (11 tests): no `/Users/` or `/home/` absolute paths, no hardcoded tool binary paths (`anaconda3/bin/weasyprint`, etc.), WeasyPrint loop form enforced, ARD audit uses `ard/*.html` glob, no hardcoded `both X.html AND Y.html` pair, release summary PDF glob, flow docs/ARD HTML/sync.sh all clean

### Release Command Fix (v0.4.8)
- **`prepare release` corrected** — steps 1–7 only, no commit, no push. Release summary GitHub/Tag rows show `⏳ pending — run: commit and push`
- **`prepare release and push`** — the explicit command that runs steps 1–7 + commit + push + shows summary with GitHub/Tag ✅
- **`13-release-workflow.md`** — renamed to "7-step gate"; publish steps removed from prepare release box; trigger table corrected; 5 new edge cases (prepare release stops, prepare release to review, prepare release and push, changes after release, commit before release)
- **README commands table** — `prepare release` row says "No commit. No push."; release summary block shows `⏳` vs `✅` states per command type
- **Framework `portable-spec-kit.md`** — Release Process signals, prepare/refresh sequences, release notes publishing section all corrected

### Team Intelligence Layer (v0.4.7)
- **F58 — Progress Dashboard** — trigger words (`progress`, `dashboard`, `burndown`, `status report`, `how are we doing`, `what's left`) → inline burndown from TASKS.md; OVERALL / BY VERSION / CURRENT TASKS / NEXT ACTIONS / BLOCKERS / BY CONTRIBUTOR sections; progress bars (█=5%, 20-char, ░ padding); version icons ✅/🔄/🔲; read-only; backlog excluded; edge cases: missing TASKS.md, all-done, truncation at 50+
- **F59 — Multi-Agent Task Tracking** — `@username` ownership syntax in TASKS.md; per-user task view (`my tasks`, `my workload`); delegation/unassign protocol; cross-agent coordination via shared TASKS.md (file is the message bus); shared task rule (`@a @b`); TASKS.md human-readable plain markdown
- **F60 — Persistent Memory Architecture** — named concept for the 6 agent files collectively; 5 properties: Durable (git), Shared (any agent), Portable (Claude/Cursor/Copilot/Cline/Windsurf), Team-scale, Auditable; tracking = writing to persistent memory; no API/no message queue
- **F61 — Architecture Decision Log** — `### Decision Log` promoted to top-level `## Architecture Decision Log` in PLANS.md template; ADR-NNN format (3-digit zero-padded) with Date/Options/Chosen/Why/Impact columns; newest-first; immutable history; supersede pattern; kit PLANS.md updated with 7 retroactive ADRs (ADR-001–007)
- **F62 — AI-Powered Onboarding** — commit `agent/` for team/open-source projects (never gitignore); clone → briefed flow; CONTRIBUTING.md guidance in template; solo exception; sensitive content check; `.gitignore` comment for solo projects; Existing Project Setup checklist updated
- **New flow doc `14-team-collaboration.md`** — Multi-Agent Task Tracking and Progress Dashboard flows; Edge Cases table (11 conditions); Persistent Memory Architecture properties table; 63-char alignment enforced
- **Sections 44–48** — 70 new framework tests across 5 new sections; Section 19 expanded for flow 14 (+6 tests); framework total 531 → 607

### Tests
| Suite | Tests | Status |
|-------|-------|--------|
| test-spec-kit.sh (50 sections) | 636 | ✅ All passing |
| test-spd-benchmarking.sh | 145 | ✅ All passing |
| test-release-check.sh | 62/62 features | ✅ Release ready |

---

## v0.3 — Framework Hardening + R→F→T Traceability (April 2026)
**Built over:** v0.3.1 — v0.3.27 · **Tests:** 597 (452 framework + 145 benchmarking)

### Highlights
- Full **R→F→T traceability chain** — every done feature requires a test reference in SPECS.md before release
- **`tests/test-release-check.sh`** — R→F→T validator distributed as a kit template, created on every project setup
- **15 new enforcement sections** (26–41) — staleness checks, release triggers, scope change recording, no-slip task rule, pre-release gate
- **Release Process rule** — full 8-step sequence: tests → counts → version bump → PDFs → RELEASES.md → CHANGELOG.md → GitHub release → tag update
- **`update release` / `refresh release`** — `update release` is alias for `prepare release`; `refresh release` re-tests + syncs current release without bumping version
- **Section 41: Pre-Release Consistency Gate** — 23 tests checking cross-file sync before every push
- **Agent-agnostic examples** — `portable-spec-kit.md` + symlinks for all 5 agents in `examples/`
- **Simplified versioning** — aligned patches (`v0.N.x` for release `v0.N`), single `**Version:**` field, `**Kit:**` field in AGENT_CONTEXT

### Framework Changes
- **R→F→T traceability** — mandatory Tests column in SPECS.md; never mark a feature `[x]` without a test reference
- **SPECS.md staleness check** — non-empty SPECS.md can still be stale; agent checks count vs TASKS.md completed tasks
- **RELEASES.md trigger rule** — entry added immediately when all version tasks are `[x]` done
- **4 scope change types** (DROP/ADD/MODIFY/REPLACE) with R→F traceability format — tracked across all 4 pipeline files
- **No-slip task rule** — scan every message for implied tasks; session-end verification sweep
- **Session-start unified 5-step read order** — user profile → AGENT.md → AGENT_CONTEXT.md → TASKS.md → PLANS.md
- **Release Notes Publishing** — CHANGELOG.md always updated; GitHub Releases auto-published if `gh` authenticated; prompt to connect or skip if not
- **test-release-check.sh caching** — each test file runs once; result cached to prevent false failures
- **Rename/refactor completeness rule** — grep entire repo before marking a rename done; no stragglers
- **What Goes Where rule** — universal user rules in `portable-spec-kit.md`; author-only rules in `agent/AGENT.md`
- **Versioning examples** — all specific patch numbers replaced with generic `v0.N.x` / `v0.1.4 → v0.1.5` so rules never go stale
- **prepare release 8-step sequence** — tests → counts → version bump → PDFs → RELEASES.md → CHANGELOG.md → GitHub release → tag update to HEAD
- **`update release`** — alias for `prepare release` (same full 8-step sequence including version bump)
- **`refresh release`** — re-test and sync current release without bumping version; same 8-step sequence with step 3 skipped
- **Release notes scope rule** — only include changes committed and visible in public repo; never mention excluded files (private docs/, research papers)
- **GitHub release title format** — minor version (`v0.N — Title`) matching CHANGELOG headings; patch number visible via commit history
- **sync.sh fixes** — CHANGELOG-based title/notes extraction (RELEASE_VER lookup); `--draft=false --latest` flags; commit message from last commit subject; release tags re-pointed to semantically correct commits
- **Kit update summary template** — generic format: lists changes from CHANGELOG.md + each file changed; no hardcoded field names or file names that go stale
- **Author/kit header** — version, license, author, GitHub link, test count at top of all framework copies; visible to humans and AI agents
- **Existing project setup — scan announcement** — agent tells user *"Spec Kit is understanding your project..."* before scanning; Step 0 checks if project already scanned (skip / partial / full); 7 scan edge cases handled (no stack detected, monorepo, conflicting signals, .env values, large project, team-committed agent/ files)
- **GitHub repo as knowledge source** — agent fetches from repo on demand for any kit question; known source table maps question types to files; open-ended repo scan catches new docs added in the future
- **Session-start kit status display** — Step 0 shows status once when agent first loads: ✅ mapped / ⚠ partial / 🔍 new. Also runs after kit version update so user sees updated version in status.
- **Profile setup and project scan decoupled** — kit always proceeds to scan and setup even if user skips profile questions
- **Kit update re-scan clarified** — step 5 explicitly scans the user's project (source code, config files) to update AGENT.md + AGENT_CONTEXT.md; not a kit changelog summary. 5 edge cases: empty project, large project, accurate AGENT.md, document project, no project dir confirmed.

### README / Docs
- Critical Scenarios table — 8 real-world situations (new machine, agent switch, crash/wipe, team handoff, context window…)
- Development Guidelines section — pipeline, file update triggers, core commands, key principles, file management rule
- "First methodology native to the AI era" framing
- Terminal install commands single-line (horizontally scrollable)
- 6 Agent Files table — update triggers corrected per file
- Flow docs + test fixtures updated: `**Framework:**` → `**Kit:**` references throughout

### Tests
| Suite | Count | Notes |
|-------|------:|-------|
| Framework (`test-spec-kit.sh`) | 452 | 41 sections |
| Benchmarking (`test-spd-benchmarking.sh`) | 145 | 5 projects × 8 lifecycle phases |
| Release gate (`test-release-check.sh`) | 55/55 features | R→F→T coverage validator |
| **Total** | **597** | All passing |

---

## v0.2 — SPD Methodology + Research (April 2026)
**Built over:** v0.2.1 — v0.2.9 (9 patches leading to this release) · **Tests:** 443 (298 framework + 145 benchmarking)

### Highlights
- **Benchmarking suite** — 145 tests across 5 projects × 8 development lifecycle phases
- **Requirements-to-delivery flow** — 9-phase lifecycle with R→F traceability and 4 scope change types
- **Two-level versioning** — framework v0.0.x patches + release v0.x milestones
- **Existing project setup** — guide don't force, checklist, 9 project scenarios

### Framework Changes
- R→F traceability — Requirements (R1, R2…) trace to Features (F1, F2…) through all scope changes
- 4 scope change types: DROP, ADD, MODIFY, REPLACE — tracked across all 4 pipeline files
- Conda env selection flow — per-project, 9 edge cases handled
- Git rule — check `.git/` before committing
- Pipeline sync rule — SPECS, PLANS, TASKS, RELEASES stay in sync

---

## v0.1 — Personalized Profile + Flow Documentation (April 2026)
**Built over:** v0.1.1 — v0.1.9 (9 patches leading to this release) · **Tests:** 242 (22 sections)

### Highlights
- **User Profile system** — global (`~/.portable-spec-kit/`) + workspace (committed, per-user)
- **First-session setup** — GitHub auto-detect + 3 preference questions with RECOMMENDED/CURRENT labels
- **9 system flow documents** — user-profile-setup, new-project-setup, returning-session, agent-switching, and more
- **Fully agent-agnostic** — no hardcoded Claude paths or tool names
- **Technical Overview ARD** — HTML + PDF architecture reference
- **Repo made public** — April 1, 2026

---

## v0.0 — Initial Release (March 2026)
**Built over:** v0.0.1 — v0.0.9 (9 patches leading to this release) · **Tests:** 122 (13 sections)

### Highlights
- `portable-spec-kit.md` — single framework file, zero dependencies, zero install
- 6 agent file templates (AGENT.md, AGENT_CONTEXT.md, SPECS.md, PLANS.md, TASKS.md, RELEASES.md)
- README, CONTRIBUTING.md, PDF Quick Guide
- `examples/starter/` and `examples/my-app/`
- Sync script + symlink setup for 5 AI agents
