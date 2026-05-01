# Flow 17 — Reflex (Adversarial Verbal Actor-Critic Refinement Loop, AVACR)

Post-prep-release automated adversarial QA + auto-fix loop with asymmetric goals. A fresh-context sandboxed **QA-Agent** (Critic, goal = FAIL the release) adversarially hunts the project across 24 dimensions + 4 personas with research backing, and files peer-exchange `findings.yaml`. A fresh-context **Dev-Agent** (Actor, goal = FOOLPROOF the release against QA's hunt) reads findings, fixes atomically on an isolated dev branch with per-commit mechanical gates, and audits sibling-class weaknesses. Convergence = QA hunted hard and cannot find a blocker.

Formal name: *Adversarial Verbal Actor-Critic Refinement Loop (AVACR)*. Operational name: **reflex**. Primary entry: `reflex/run.sh` (see §Commands). Internal machinery: `reflex/lib/spawn-qa.sh`, `reflex/lib/spawn-dev.sh`, `reflex/lib/file-bugs.sh`, `reflex/lib/gates.sh`, `reflex/lib/regression-diff.sh`, `reflex/lib/score.sh`, `reflex/lib/preconditions.sh`, `reflex/lib/loop.sh`, `reflex/lib/update-eval-trace.sh`, `reflex/lib/prune-history.sh`.

**Phase 0 pre-compute helpers (run before QA-Agent spawns):** `reflex/lib/check-reqs-coverage.sh` (v0.6.19+, ADR-031 — REQS-coverage gate emitting `reqs-coverage.yaml`), `reflex/lib/check-rule-conflicts.sh` (v0.6.20+, ADR-030 — rule-conflict scan emitting `rule-conflicts.yaml`), `reflex/lib/check-rft-integrity.sh` (R→F→T deep audit). All three are deterministic, sub-second, free, and run on every pass before the QA-Agent gets context. Findings auto-promote to QA's input so the QA-Agent reasons against pre-computed gaps rather than rediscovering them probabilistically.

**QA blind-spots registry (v0.6.25+, ADR-036):** `reflex/history/qa-blind-spots.md` is an append-only YAML log of every QA miss surfaced by humans. QA reads it at Phase 0 Step 0.0 — before any other input — per `reflex/prompts/qa-agent.md` mandate. Every entry with `status: open` generates a probe in the test plan. Skipping the registry read is itself a finding (`QA-BLIND-SKIP-NN`). Status flow: `open` (probe needed) → `probed` (deterministic kit probe exists) → `retired` (class no longer relevant). Three seed entries on landing — BS-001 REQS-coverage gap class, BS-002 client-grade UI gap class, BS-003 install.sh out-of-sync class.

**Probe-coverage metric (v0.6.25+):** `reflex/history/summary.csv` schema v4 adds `probe_coverage_pct` = (claims with `status: verified` or `status: falsified`) / total claims emitted by `extract-claims.sh`. Empty when claims.yaml absent. Trend upward over passes signals a more verifiable project. Auto-migrates older v1/v2/v3 CSVs in place.

**Mode A claim probe-types (v0.6.25+, extract-claims extensions):** four new claim types alongside the original eight (version-match · test-count · feature-count · capability-exists · file-count · install-works · dimension-count · skill-count). The new four — `api-route` (express/fastify/router-style route registrations in src/lib/app/api/server), `perf-budget` (`<Nms p95` / `<Ns` patterns extracted from REQS/SPECS/PLANS/README), `error-message-text` (15-80 char user-facing strings in agent/REQS.md / SPECS.md / README.md / HANDOFF.md), `security-rule` (anti-pattern absence claims like "no eval", "no pickle", "no shell=True"). Each emitted with a `probe_target` QA must verify or falsify.

**Symmetric self-evolution (v0.6.27+, P9 + ADR-040):** kit hunts for both gaps AND overlaps. `agent/scripts/psk-coverage-overlap-check.sh` extracts coverage signatures from 24 dimensions + Phase 0 helpers + sync-check fns + /optimize cats; reports overlap clusters. Wired into `/optimize` cat 14 + Phase 6 evolution-gauntlet Gate G. New QA `Dimension 24 — Coverage-overlap audit` (3 probes per pass) files `QA-OVERLAP-NN` findings. Phase 5 self-reflection now mandates ≥1 overlap observation. `OL-NNN` registry in `qa-blind-spots.md` tracks human-flagged overlaps. Bypass `PSK_OVERLAP_CHECK_DISABLED=1`.

**Tier 3 auto-probe-synthesis (v0.6.27+, ADR-038):** `agent/scripts/psk-blind-spot-synthesize.sh` reads BS-NNN `status: open` entries, classifies target, scaffolds PR-style proposals at `agent/tasks/proposed/Gxx-<slug>.md`. Closes Tier 3 of v0.6.7+ residual plan.

**Manual finding closure (v0.6.27+):** `agent/scripts/psk-close-finding.sh QA-XXX-NN "rationale"` marks a finding closed without YAML hand-edit.

**Cycle-id rule (v0.6.28 — GRANTED converges, ADR-041):** the cycle advances when the latest pass's signoff verdict is `GRANTED`, regardless of whether non-blocking findings remain. GRANTED is the auditor's "ship-ready" signal; any leftover MINOR / non-blocking findings stay queued for the next cycle, no wasted re-verify pass needed. The v0.6.27 escape hatch (advance on 0 unclosed findings + signoff-present, verdict-agnostic) still applies for DENIED-then-externally-fixed cases — `count_findings_yaml`'s closed-status filter is the audit safeguard. The rule fires identically in `compute_next_cycle_id` (run.sh) and `next_cycle_id` (loop.sh).

**Reflex history retention bloat (v0.6.2+, bounded disk use):** `reflex/lib/prune-history.sh` enforces caps from `reflex/config.yml` `history_retention.*`. Per-pass directories capped at `pass_dirs_keep` (default 10). Dev branches at `dev_branches_keep` (default 3, unhappy paths only). QA sandbox worktrees at `qa_sandbox_keep` (**default 0 since v0.6.28, ADR-043** — current pass purges immediately after QA via `reflex/lib/purge-current-sandbox.sh`; prior sandboxes have no consumer). `REFLEX_EVAL_TRACE.md` and `summary.csv` are kept forever. Pruning runs automatically at the start of every pass — pruned passes remain in the register with an `_(archived)_` marker. Detection: `/optimize` Category 8 flags per-pass dirs >2× retention limit and register >100KB. Manual clean slate: `bash reflex/run.sh --purge-history --confirm`.

## When to run

Reflex is **decoupled from prep-release cadence** but the end-to-end `autoloop` mode (default) orchestrates release-prep itself. **The release-ceremony bookend pattern (ADR-039, v0.6.27+):** iter 1 runs `prepare` (version bump — cycle start) · iters 2+ skip release ceremony entirely (just QA → Dev) · GRANTED convergence runs **one final `refresh`** to capture all the cycle's Dev fixes into `RELEASES.md` + `CHANGELOG.md` + counts/badges/PDFs at once. This means a single converged reflex cycle bumps the version exactly once (start) and updates release notes exactly once (end), with N QA→Dev iterations in between unencumbered by release noise. Bypass `PSK_REFLEX_AUTO_REFRESH=0` to skip the final refresh. Single-pass mode (`reflex/run.sh single`) doesn't auto-bump or auto-refresh — it prints a tip when GRANTED + fixes landed so the user can manually run `bash agent/scripts/psk-release.sh refresh`.

- **Primary (recommended):** `bash reflex/run.sh` — default mode is autoloop. Chains prep-release + QA + Dev + iterate until convergence (GRANTED, REGRESSION, plateau, or other convergence signal).
- **Single pass (debugging):** `bash reflex/run.sh single` — one pass only, assumes HEAD is already a prep-release commit.
- **Scheduled (optional):** cron weekly, GitHub Actions, etc.
- **On-push gate (optional):** config flag blocks `git push` until reflex pass passes.

## How QA derives its probe set — 7-layer Senior-Engineer system (v0.6.7+)

Reflex's QA-Agent used to hunt a closed 24-dimension checklist from the AVACR paper. As of v0.6.7 it is a **Senior / Principal-level QA system with 7 verification layers** — probes derive from the project's spec pipeline + kit toolkit + running system, never from a human-curated list. The 24-dimension checklist is preserved as a safety net, not the primary driver.

| # | Layer | Helper / Phase | Output artifact in pass dir |
|---|---|---|---|
| 1 | R→F→T pipeline integrity | `reflex/lib/check-rft-integrity.sh` (Phase 0, deterministic bash) | `rft-integrity.yaml` |
| 2 | Bidirectional doc ↔ code consistency | `reflex/lib/doc-code-diff.sh` (Phase 0, deterministic bash) | `doc-code-diff.yaml` |
| 3 | Behavioral per-feature verification (1 happy + 5 edge + 3 adversarial + 1 integration) | QA Phase 2 (LLM, independent of Dev's tests) | `behavioral-tests/F{N}-*.{md,yaml}` |
| 4 | Test-quality audit (read Dev's test AFTER your own; flag inadequate) | QA Phase 3 (LLM) | `test-quality-audit.yaml` |
| 5 | Cross-feature integration probes | QA Phase 2 (LLM) | `integration-probes.md` |
| 6 | Production readiness via kit tools | `reflex/lib/spawn-qa.sh` captures sync-check / doc-sync / release-check / code-review (Phase 0) | `kit-tools-output/{sync-check,doc-sync,release-check,code-review}.txt` |
| 7 | External reality check (CVE / OWASP / deprecations) | QA Phase 2 (LLM + WebSearch/WebFetch) | `external-research.md` |

Plus the v0.6.6 Phase 0 inputs (still active): `claims.yaml` (Mode A) + `state-diff.yaml` (Mode B) + `assumptions.md` (Mode C).

**Layer design philosophy** (in `agent/design/f70-reflex-senior-engineer-qa.md`):
- **Senior/Principal-level QA** — independent investigator, full instrument access, files every weak signal (user does not pre-filter)
- **Independence rule** — design behavioral test BEFORE reading Dev's test
- **Bidirectional consistency** — every doc claim → code; every code feature → ≥1 doc surface
- **Aggressive coverage** — 1+5+3+1 probe pattern per `[x]` feature
- **Test the test** — audit Dev's tests (Layer 4) after own probing (Layer 3)
- **Use the kit toolkit** — psk-* scripts as research instruments (Layer 6)
- **External reality** — WebSearch CVEs / OWASP / deprecations (Layer 7)

Layers 1, 2, 6 are **deterministic bash pre-compute** (<2s + <200 tokens combined). LLM budget redirects to semantic verification (Layers 3-5, 7) instead of re-deriving project structure. Layer 1 / 6 CRITICAL signals **short-circuit** the 24-dim sweep — fix structural breaks first, behaviors second.

## End-to-end flow — one autoloop invocation

Entry: `bash reflex/run.sh` (default mode = autoloop · alternatively `bash reflex/run.sh single` for one pass only).

Autoloop cycle state lives in `agent/.release-state/loop-state.yml` (records cycle id + current iteration). Every iteration runs the four phases below. Max 3 iterations before MANUAL_REVIEW_NEEDED.

```
┌─────────────────────────────────────────────────────────────┐
│  ITERATION N (of max 3) — Phase 1: RELEASE-PREP             │
│     iter 1: bash agent/scripts/psk-release.sh prepare       │
│       (full version bump + ARD/PDF regen)                   │
│     iter 2+: bash agent/scripts/psk-release.sh refresh      │
│       (no version bump — captures iter N-1 Dev fixes        │
│        through same critic gates at ~50% cost; avoids       │
│        version inflation across one converged cycle)        │
│     10 steps: tests → code review → scope check →           │
│     validation → flows → counts → [version] →               │
│     PDFs → RELEASES → CHANGELOG                             │
│     ↳ writes commit recognized by preconditions Gate 2      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Phase 2: PRECONDITIONS + PRUNE + PHASE 0 + SPAWN QA-AGENT  │
│     preconditions.sh — Gate 0 (self-test), Gate 0a          │
│       (kit-bootstrap integrity via psk-bootstrap-check.sh), │
│       Gate 1 clean tree, Gate 2 prep-release commit pattern │
│     prune-history.sh — bounds disk per history_retention    │
│     spawn-qa.sh (v0.6.6+) — pre-computes Phase 0 artifacts: │
│       extract-claims.sh → claims.yaml (every project claim  │
│         with probe_type + probe_target; LLM-free bash)      │
│       state-diff.sh → state-diff.yaml (actual vs reflex/    │
│         reference-state/speckit-project.yaml; CRITICAL      │
│         deltas auto-promoted to findings)                   │
│     then creates sandbox worktree                           │
│     AGENT.md + AGENT_CONTEXT.md physically removed from     │
│     the sandbox so QA cannot read Dev narrative             │
│     AWAITING_QA — main session spawns Task sub-agent        │
│     QA-Agent reads Phase 0 artifacts FIRST, then REQS/      │
│     SPECS/PLANS/TASKS/docs + running system. Writes 10+     │
│     files into pass dir (claims + state-diff + assumptions  │
│     + 24-dim output per v0.6.6). See Artifacts table.       │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Phase 3: RESUME QA → FILE BUGS → SPAWN DEV-AGENT           │
│     bash reflex/run.sh --resume                             │
│     file-bugs.sh — appends @reflex-dev tasks to TASKS.md    │
│     refreshes REFLEX_EVAL_TRACE.md register                 │
│     PURGES current-pass sandbox (structural — Dev cannot    │
│     read QA's private workspace)                            │
│     spawn-dev.sh — creates reflex/dev-<pass-name> branch    │
│     AWAITING_DEV — main session spawns Task sub-agent       │
│     Dev reads (v0.6.6+): findings.yaml + claims.yaml        │
│       + state-diff.yaml + assumptions.md + source code      │
│     Dev scope expanded (v0.6.6+):                           │
│       (a) fix findings                                      │
│       (b) build unfulfilled claims from claims.yaml         │
│       (c) remediate CRITICAL deltas from state-diff.yaml    │
│       All within SPECS scope (no speculative features)      │
│     Dev CANNOT modify AGENT.md or AGENT_CONTEXT.md          │
│     Commits: autoloop fix QA-<ID>: <reason> + [source:...]  │
│     1 task = 1 commit · Max 3 retries · [~] on gate-fail    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  Phase 4: RESUME DEV → GATES → VERDICT → DECISION           │
│     bash reflex/run.sh --resume-dev                         │
│     gates.sh — mechanical gates + protected-files check +   │
│     commit-convention check                                 │
│     regression-diff.sh — closed / persisted / new /         │
│     regressed split vs prior pass                           │
│     score.sh — appends row to summary.csv                   │
│     write_verdict — writes verdict.md + latest.md           │
│     update-eval-trace — refreshes cross-pass register       │
│     GRANTED → ff-merge dev branch → parent (or --no-ff on   │
│               divergence) + delete branch · exit 0          │
│     DENIED + iter < 3 → restart Phase 1 (same cycle)        │
│     DENIED + iter = 3 → MANUAL_REVIEW_NEEDED · exit 2       │
│     REGRESSION → retain dev branch · exit 2                 │
└─────────────────────────────────────────────────────────────┘
```

## Why two agents?

The two agents have deliberately asymmetric access:

| Role | Context | Reads | Writes |
|------|---------|-------|--------|
| QA-Agent (Critic) | Fresh sandbox per pass | Specs + docs + running system (source code deliberately NOT read) | `findings.yaml` + `signoff.md` + `investigation-log.md` + `coverage.md` + scratch files; all land in `reflex/history/<pass>/` |
| Dev-Agent (Actor) | Fresh per pass, on dedicated branch | Everything incl. source + QA's committed output | Source, tests, docs (NOT AGENT.md / AGENT_CONTEXT.md); commits on `reflex/dev-<pass>` branch |

**QA-Agent never sees source code.** It exercises the project's public surface and compares to the user-facing promise in SPECS. This structurally prevents the "Dev-written tests pass against stub implementations" failure mode: a trivial assertion can satisfy R→F→T and sync-check, but an empty output cannot satisfy an acceptance criterion measured against the real feature surface.

**Dev-Agent sees source but cannot touch the two canonical narrative files.** It cannot add features — only close QA-identified gaps with minimal atomic commits. If a finding's recommendation would edit AGENT.md / AGENT_CONTEXT.md, Dev-Agent files it as Bucket D + routes a `QA-<ID>-ARB` task to human-arbitration.

## Per-pass artifacts (committed in full, v0.6.2+)

Every pass directory is `reflex/history/cycle-NN/pass-NNN/` (autoloop) or `reflex/history/standalone/pass-NNN/` (single-pass mode). All files below are committed — full audit trail, bounded by retention. The flat identity (`cycle-NN-pass-NNN`) is used for git branch names, CSV pass id, and `[source: ...]` commit trailers.

| File | Writer | Purpose |
|------|--------|---------|
| **`claims.yaml`** (v0.6.6+) | `reflex/lib/extract-claims.sh` (pre-compute, LLM-free) | **Phase 0 Mode A** — every public claim extracted from README / portable-spec-kit.md / SPECS / CHANGELOG / RELEASES / AGENT_CONTEXT / qa-agent.md with `probe_type` + `probe_target`. QA verifies each; unverified or vague = finding. |
| **`state-diff.yaml`** (v0.6.6+) | `reflex/lib/state-diff.sh` (pre-compute, LLM-free) | **Phase 0 Mode B** — actual project state vs `reflex/reference-state/speckit-project.yaml`. Every delta pre-classified by severity (CRITICAL / MAJOR / MINOR). CRITICAL deltas auto-promote to findings. |
| **`assumptions.md`** (v0.6.6+) | QA sub-agent (Phase 1) | **Phase 0 Mode C** — QA lists every implicit assumption its probes operate under. Each MUST have a probe that verifies or falsifies it. Unverifiable assumption = MAJOR `QA-ASSUMPTION-NN` finding. |
| `findings.yaml` | QA sub-agent | Structured findings (id · priority · scope · dimension · citable_quote · regression_vector · recommendation) — peer exchange to Dev-Agent. Now includes claim-derived + state-diff + assumption + 24-dim-derived findings. |
| `signoff.md` | `spawn-qa.sh` + QA sub-agent | Verdict (GRANTED / DENIED), blocking findings, deferred decisions, human-arbitration items |
| `verdict.md` | `run.sh` write_verdict | Machine-parsed pass summary (mode, findings, fixes, gates status, timestamp) |
| `investigation-log.md` | QA sub-agent | QA's reasoning trail — why each finding was filed; Dev reads this for context + sibling-class hardening |
| `coverage.md` | QA sub-agent | Machine-readable YAML block listing features tested and not-tested; informs Dev's fix scope |
| `pass-plan.md` | QA sub-agent | QA's pre-investigation plan (targets, persona coverage, dimension coverage) |
| `project-understanding.md` | QA sub-agent | QA's mental model of the project after reading specs + running system |
| `qa-summary.md` | QA sub-agent | Narrative summary of QA's pass (human-readable synthesis) |
| `qa-usage.yaml` | QA sub-agent | Token accounting for the pass (input / output / tool calls) |
| `test-plan.md` | QA sub-agent | QA's test strategy (what was tested, how, against which acceptance criterion) |
| `dev-trace.md` | Dev sub-agent | Per-finding diagnosis (bucket) + fix summary + gate results |
| `deferred-decisions.md` | Dev sub-agent | `[~]` escalations with rationale (written only when non-empty) |
| `regression-diff.md` | `regression-diff.sh` | Closed / persisted / new / regressed split vs prior pass (iter 2+) |
| `gates-result.md` | `gates.sh` | Mechanical gate PASS/FAIL per gate for this pass |
| `.cycle-meta` | `run.sh` | Cycle + iteration metadata (`cycle=3 iteration=2 mode=full self_test=true started=...`) |

**The sandbox worktree is gitignored and purged unconditionally** after QA finishes via `reflex/lib/purge-current-sandbox.sh` (structural enforcement — Dev cannot read QA's private workspace). The purge runs regardless of finding count: both `file-bugs.sh` (when QA filed findings) and `run.sh`'s empty-pass shortcut (when QA filed 0 findings) delegate to the same helper, so empty passes don't leak ~167 MB sandboxes (ADR-042). Default retention `qa_sandbox_keep: 0` since v0.6.28 (ADR-043) — no agent reads prior sandboxes; the disk is reclaimed immediately. Set retention >0 in `reflex/config.yml` only if you want manual cross-pass debug worktrees.

## The file-based protocol (in-flight)

Agents communicate through transient files in `agent/.release-state/` (all gitignored):

- `qa-task.md` — prompt written by `lib/spawn-qa.sh` for the QA-Agent
- `qa-result.md` — machine-readable findings the QA-Agent writes back
- `dev-task.md` — prompt written by `lib/spawn-dev.sh` for the Dev-Agent
- `dev-result.md` — fix summary with commit SHAs and bucket diagnoses

Same pattern as the kit's existing `psk-critic-spawn.sh` validation critics. Disambiguation: the existing workflow **validation critics** (STEP_4_FLOW_DOCS, STEP_9_VALIDATION, FEATURE_COMPLETE, etc.) run during prep release and perform white-box file audits; the reflex **QA-Agent** runs post-prep-release and performs black-box acceptance testing. They're complementary — validation critics catch structural drift, QA-Agent catches functional drift.

## Trace files (reviewer surface)

Three reviewer-facing artifacts live under `reflex/history/`:

| File | Scope | Written by | Purpose |
|---|---|---|---|
| `<pass-dir>/findings.yaml` | one pass, structured | QA-Agent | Full evidence per finding — invocation, observed, expected, citable_quote, regression_vector, recommendation |
| `<pass-dir>/signoff.md` | one pass, narrative | `spawn-qa.sh` + QA-Agent | Verdict (GRANTED / DENIED), blocking findings, deferred decisions, human-arbitration items |
| `REFLEX_EVAL_TRACE.md` | **all** passes, index | `lib/update-eval-trace.sh` | One block per pass, one row per finding (id · severity · scope · status · one-line summary). Auto-refreshed after every pass filing and every autoloop iteration. Grouped by autoloop cycle. |

Reviewer flow:

1. Open **`REFLEX_EVAL_TRACE.md`** — every finding across every pass with current status (`[x]` closed · `[ ]` open · `[~]` acknowledged · `[?]` untracked), grouped by cycle.
2. Drill into a pass via `<pass-dir>/signoff.md` (verdict + narrative).
3. Drill into a finding via `<pass-dir>/findings.yaml` — the `regression_vector` block gives the exact command to re-execute next pass.

Do **not** edit `REFLEX_EVAL_TRACE.md` by hand — it's regenerated on the next pass. To amend a finding, edit the pass's `findings.yaml` or the matching entry in `agent/TASKS.md`, then re-run `bash reflex/lib/update-eval-trace.sh`.

## Directory structure at scale

After 3 autoloop invocations (cycle 1: 3 iters, cycle 2: 2 iters, cycle 3: 3 iters) → 8 total passes:

**`reflex/history/`** (all committed):
- `REFLEX_EVAL_TRACE.md` — grows forever · cross-cycle register
- `summary.csv` — append-only · one row per pass
- `latest.md` — shortcut to most-recent pass
- `cycle-01/` — autoloop cycle 1
  - `summary.md` — per-cycle aggregator (auto-generated)
  - `pass-001/` · iter 1 (DENIED)
  - `pass-002/` · iter 2 (DENIED)
  - `pass-003/` · iter 3 (GRANTED) — cycle exit
- `cycle-02/`
  - `pass-004/` · iter 1 (DENIED)
  - `pass-005/` · iter 2 (GRANTED) — cycle exit
- `cycle-03/`
  - `pass-006/` · iter 1 (DENIED)
  - `pass-007/` · iter 2 (DENIED)
  - `pass-008/` · iter 3 (GRANTED) — cycle exit
- `standalone/` — ad-hoc single-pass invocations group here

**`reflex/sandbox/`** (gitignored; last 3 retained, mirrors history layout):
- `cycle-03/pass-006/` — retained for cross-pass debugging
- `cycle-03/pass-007/` — retained
- Current pass's sandbox was purged immediately by `file-bugs.sh` — Dev cannot read it

**git branches** — all happy-path in this scenario; no `reflex/dev-*` branches retained (all fast-forward-merged + deleted on GRANTED).

### At scale (50+ passes with retention)

- On-disk pass dirs capped at `history_retention.pass_dirs_keep` (default 10) via `prune-history.sh`.
- Older pass dirs pruned, but their rows persist in `summary.csv` + `REFLEX_EVAL_TRACE.md` as `_(archived)_` blocks (status still resolvable from `agent/TASKS.md`, drill-down links removed — no dead links).
- Pass numbers **per-cycle** (v0.6.26+ — each cycle starts fresh at `pass-001`); cycle numbers **monotonic across autoloops**. Composite key `(cycle, pass)` gives unique row identity in `summary.csv` (schema v5+). Flat identity (`cycle-NN-pass-NNN` or `standalone-pass-NNN`) remains globally unique because cycle numbers are monotonic.

## Safety rails

1. **Dev-branch isolation.** Dev-Agent commits to `reflex/dev-cycle-NN-pass-NNN` (for autoloop) or `reflex/dev-standalone-pass-NNN` (single-pass), a dedicated branch off the current HEAD. Main branch stays clean during the pass. On GRANTED verdict, run.sh fast-forward merges into the parent branch (falls back to `--no-ff` if parent diverged) and deletes the dev branch. On DENIED / REGRESSION the branch is retained (last 3 unhappy branches kept; pruned beyond that).
2. **Protected-files write-ban (3-layer).** `agent/AGENT.md` and `agent/AGENT_CONTEXT.md` are owned by the spec-persistent pipeline, never by reflex findings. Enforced at three layers: Dev-Agent prompt ("NEVER modify"), `gates.sh` per-commit diff check, and `psk-sync-check.sh` pre-commit hook (branch-gated to `reflex/dev-*`). If a finding's recommendation touches these files, Dev-Agent files it as Bucket D + routes a `QA-<ID>-ARB` task to human-arbitration.
3. **Sandbox purge after QA:** `file-bugs.sh` removes the current pass's QA sandbox worktree the moment findings are extracted into the committed `reflex/history/<pass>/`. Dev physically cannot read QA's private workspace — structural enforcement, not trust-based.
4. **Per-commit mechanical gates.** Pre-commit hook + Dev-Agent's per-task gate check. Broken fixes never land. Commit convention: `autoloop fix QA-<ID>: <reason>\n\n[source: <pass-name>]` (trailer required for audit).
5. **Max 3 retries per task.** Gate fails after 3 attempts → task marked `[~]` (human review).
6. **Max 200 tool calls per cycle.** Budget cap aborts runaway cycles.
7. **Regression detection.** Next pass verifies previously-fixed tasks haven't reopened; `regression-diff.md` records closed / persisted / new / regressed per pass.
8. **Reversibility.** Every reflex commit is a single revertable git commit; whole-pass rollback via `git branch -D reflex/dev-<pass>`.
9. **Concurrency lock.** `agent/.release-state/reflex.lock` prevents parallel reflex runs corrupting shared state.
10. **History retention.** `reflex/history/REFLEX_EVAL_TRACE.md` + `summary.csv` kept forever (audit trail). Per-pass directories + Dev branches + QA sandboxes capped per `reflex/config.yml → history_retention`. Prune runs automatically at the start of every pass.
11. **`reflex/` out of QA scope.** Avoids recursion — QA-Agent never tests reflex itself.

## v0.6.2 refinements

- **Nested per-cycle layout (v0.6.13+):** directories are `cycle-NN/pass-NNN/` (autoloop) or `standalone/pass-NNN/` (single-pass). The per-cycle parent dir hosts a `summary.md` aggregator. Flat identity (`cycle-NN-pass-NNN`) is reserved for git branches, CSV pass id, and `[source: ...]` commit trailers.
- **Cycle metadata + grouped register render:** each pass dir has a `.cycle-meta` file (cycle id + iteration + mode + started timestamp); the register groups blocks by autoloop cycle.
- **All per-pass artifacts committed:** every QA / Dev output per pass lives in git (see §Per-pass artifacts above); only `reflex/sandbox/` stays gitignored.
- **Entry consolidation — single CLI surface:** `bash reflex/run.sh` is the sole public entry; default mode = autoloop; single-pass via positional `single` or `--single` flag. Wrapper scripts (`autoloop.sh`, `kit-loop.sh`, `self-test.sh`, top-level `loop.sh`) are retired.
- **Reflex reset command — nuclear wipe (allowlist-based):** `bash reflex/run.sh --reset [--confirm] [--reset-hardening] [--reset-consent]` (implemented at `reflex/lib/reset.sh`) deletes everything under `reflex/history/` and `reflex/sandbox/` plus runtime state files and `reflex/dev-*` branches — except entries in the allowlist. Allowlist is future-proof: any new artifact a future pass produces is auto-cleaned without maintaining glob lists. Two artifacts are preserved by default: `reflex/history/hardening-log.md` (kit's structural-defense audit memory — Layer-4 H-NNN entries, append-only by design) and the auto-submit consent marker (deliberate user opt-in). Pass `--reset-hardening` or `--reset-consent` to also wipe either. Dry-run without `--confirm`.

## Commands

| Command | What it does |
|---------|--------------|
| `bash reflex/run.sh` | **Default: autoloop.** Chains prep-release + reflex pass + iterate until convergence (GRANTED / REGRESSION / plateau). Safety cap escape hatch at `convergence.max_iterations_safety` (default 20). Works identically for kit self-test (auto-detected), new projects, existing projects. |
| `bash reflex/run.sh single` | Single pass only (no iteration). Requires HEAD to be a prep-release commit. For debugging; `--qa-only` implies `single`. |
| `bash reflex/run.sh --qa-only` | Single QA-only pass, skip Dev-Agent (Phase 1 debugging). |
| `bash reflex/run.sh --target <path>` | Run against a different project directory (playground or other project). |
| `bash reflex/run.sh status` | Print latest pass verdict. |
| `bash reflex/run.sh --resume` | Re-enter after QA sub-agent wrote qa-result.md (invoked internally by loop). |
| `bash reflex/run.sh --resume-dev` | Re-enter after Dev sub-agent wrote dev-result.md (invoked internally by loop). |
| `bash reflex/run.sh --recover` | Diagnose partial Dev state; print paste-ready template for hand-finish. |
| `bash reflex/run.sh --report-to-kit <kit-path>` | Compose signoff.md + findings.yaml into `<kit>/docs/research/` for kit-maintainer review. |
| `bash reflex/run.sh --submit-to-kit [--confirm]` | Anonymize the composed pass export and open a labeled issue on the kit repo via `gh` CLI. |
| `bash reflex/run.sh --enable-auto-submit --i-understand-privacy-implications` | Write N33 consent marker; enables auto-submit when `upstream_submission.mode` is set. |
| `bash reflex/run.sh --self-test` | Explicit self-test on the kit (same as running in the kit when auto-detection fires). |
| `bash reflex/run.sh --purge-history [--confirm]` | Wipe all prunable reflex artifacts (dry-run without `--confirm`). |
| `bash reflex/run.sh --help` | Print usage. |
| `bash reflex/intake.sh` | N38 manual weekly pull — fetches `avacr-eval` issues from the kit repo and drafts `Gxx-*.md` kit tasks. |

## Install into a user project

```bash
cd ~/my-project                                  # already a speckit project
bash ~/portable-spec-kit/reflex/install-into-project.sh .
```

The installer:
- Verifies target is a speckit project (has `agent/AGENT_CONTEXT.md`)
- Copies `run.sh`, `lib/`, `prompts/`, `install-into-project.sh`, `update.sh`, `README.md`
- Auto-detects test commands (npm test, pytest, go test, bash tests/*) and generates project-tailored `config.yml`
- Appends `reflex/sandbox/` to `.gitignore` (per-pass artifacts all commit — full audit)

When the kit releases reflex improvements, refresh via:

```bash
bash reflex/update.sh             # pulls latest from GitHub
bash reflex/update.sh --source ~/portable-spec-kit/reflex   # or copy from a local canonical dir
```

`config.yml` and `history/` are preserved.

## Config (reflex/config.yml)

```yaml
mode: kit                    # kit | project (auto-detected via kit-identity check)
trigger: manual              # manual | cron | on-push
budget:
  max_tool_calls_per_cycle: 200
  max_retries_per_task: 3
coverage:
  critical_always: true
  major_always: true
  minor_rotation_every_n_cycles: 3
mechanical_gates:
  - bash tests/test-spec-kit.sh
  - bash tests/test-release-check.sh agent/SPECS.md
  - bash agent/scripts/psk-sync-check.sh --full
  - bash agent/scripts/psk-doc-sync.sh --strict
precondition:
  require_clean_tree: true
  require_prep_release_marker: true
history_retention:
  pass_dirs_keep: 10         # reflex/history/<pass>/ on disk
  dev_branches_keep: 3       # reflex/dev-* unhappy branches (GRANTED deleted immediately)
  qa_sandbox_keep: 0         # reflex/sandbox/cycle-NN/pass-NNN/ worktrees (v0.6.28: current purges immediately, no prior retained)
  register_archive_kb: 200   # roll REFLEX_EVAL_TRACE.md into chapter archive past this size
upstream_submission:
  mode: manual               # manual | prompt | auto
  kit_repo: aqibmumtaz/portable-spec-kit
  label: avacr-eval
  rate_limit_hours: 24
```

## Research foundations

The pattern combines five research lines:

- **Generator–Discriminator topology** — Goodfellow et al. 2014 (*GANs*): Dev = generator, QA = discriminator
- **Reflexion** — Shinn et al. 2023: verbal feedback loops in agentic LLMs → Dev reads QA report and regenerates
- **Process Reward Models** — Lightman et al. 2023: per-commit gates as step-level verification signal
- **Spec-driven program synthesis** — Solar-Lezama 2008: Dev synthesizes fixes from acceptance criteria
- **Lost-in-the-middle** — Liu et al. 2023: the principal failure mode reflex counters (QA reads one feature at a time, cannot lose features in the middle the way a single long-SPECS pass can)

Full design: `agent/design/f70-reflex.md`.

## v0.6 Capability Reference

Verbatim CHANGELOG bullet inventory for every reflex capability shipped in v0.6.5–v0.6.13. Plain-text on purpose so coverage tooling (`psk-doc-sync.sh`) can grep each bullet phrase as it appears in the CHANGELOG. Read this when scanning what the kit can do without diving into individual scripts.

### v0.6.13 capabilities

- **cycle-summary.sh aggregator.** `reflex/lib/cycle-summary.sh` generates `reflex/history/cycle-NN/summary.md` per cycle: totals (passes / findings / fixes / tokens / wall) + per-pass breakdown table. Companion to cross-cycle `REFLEX_EVAL_TRACE.md` register. Idempotent. Invoked manually after a cycle completes, or chained from autoloop convergence.
- **Pass-dir naming — cycle + pass visible:** the v0.6.2 flat-form `cycle-NN-pass-NNN/` layout migrated to nested `cycle-NN/pass-NNN/` in v0.6.13 — same cycle-and-pass visibility, with the cycle as a true parent directory. Flat identity (`cycle-NN-pass-NNN`) is preserved for git branches, CSV pass id, and `[source: ...]` commit trailers; on-disk path is nested.
- **Unified cycle-NN-pass-NNN naming — no more standalone-pass:** every pass gets a cycle id (autoloop runs share a cycle across iterations; ad-hoc single-pass runs auto-assign the next cycle id, 1 cycle = 1 pass). Standalone single-pass invocations live under `reflex/history/standalone/pass-NNN/` so flat `ls reflex/history/` shows cycle boundaries at a glance. The flat identity (`cycle-NN-pass-NNN` or `standalone-pass-NNN`) is what feeds branches and trailers — same scheme across all invocations.
- **Cycle-01 trace audit fixes (9/9).** Closes 5 issues + 4 sub-gaps user surfaced in cycle-01 review: pass-002 silent register-skip (fixed: `update-eval-trace.sh` lists all pass dirs by name pattern, INCOMPLETE rendering for missing findings.yaml); "Autoloop cycle" → "Reflex cycle" terminology unified; sandbox-vs-history disambiguation documented; `score.sh` `grep -c || echo 0` multi-line bug fixed (`head -1`); `summary.csv` backfilled; `doc-code-diff.sh` path-with-spaces fix (10× scan coverage); `psk-doc-sync.sh --strict` tightened (Missing>0 only); NOISE_RE backtick-prefix SHA pattern added; gates.sh false-failure cascade resolved.
- **First successful Dev-Agent run end-to-end.** `cycle-01-pass-004` closed `QA-NOISE-RE-01` bucket A (NOISE_RE backtick-prefix SHA gap), 1 commit, all 6 mechanical gates green, fast-forward auto-merge to main — first time the QA→Dev→merge loop closed without manual intervention. Proof point for the 3-layer QA→Dev contract enforcement landing in v0.6.13.
- **Reflex install template aligned to v0.6.13 layout:** `reflex/install-into-project.sh` gitignore template drops legacy `reflex-pass-*` patterns and mentions only `reflex/sandbox/` (per v0.6.13+ "all per-pass artifacts committed" design). Existing user installs continue working — the template only affects new installs.

### 7-Layer Senior/Principal-level QA architecture (v0.6.7–v0.6.8)

- Layer 1 — R→F→T pipeline integrity (deterministic bash pre-compute via reflex/lib/check-rft-integrity.sh; emits rft-integrity.yaml).
- Layer 2 — Bidirectional doc ↔ code consistency (reflex/lib/doc-code-diff.sh; emits doc-code-diff.yaml).
- Layer 3 — Behavioral per-feature verification (reflex/lib/scaffold-behavioral-tests.sh; QA fills 1+5+3+1 probes).
- Layer 4 — Test-quality audit (QA inspects each Dev test for meaningfulness; hardening events logged via reflex/lib/log-hardening.sh).
- Layer 5 — Cross-feature integration probes (reflex/lib/identify-integration-probes.sh; emits integration-probes.md with hub-suppression).
- Layer 6 — Production readiness via kit tools (spawn-qa.sh captures psk-sync-check / psk-doc-sync / test-release-check / psk-code-review per pass).
- Layer 7 — External reality check (reflex/lib/external-research.sh seeds CVE/OWASP/framework-deprecation queries; reflex/lib/auto-extract-adl.sh drafts ADL entries to agent/.release-state/adl-drafts.md).

reflex/lib/scaffold-behavioral-tests.sh (QA Layer 3): generates behavioral-tests/F{N}-test-plan.md skeleton per [x] feature with 1+5+3+1 structure (1 happy + 5 edge + 3 adversarial + 1 integration). Pulls criteria from ### F{N} blocks. QA fills TODOs — independence rule: design BEFORE reading Dev's test.

reflex/lib/identify-integration-probes.sh (QA Layer 5): scans SPECS for feature interactions via design-plan + criteria-block cross-references. Emits integration-probes.md with candidate pairs.

reflex/lib/external-research.sh (QA Layer 7): scans project manifests (package.json, requirements.txt, pyproject.toml, go.mod, Cargo.toml, Dockerfile) and emits external-research.md with seeded WebSearch/WebFetch queries: per-dependency CVE searches, framework-changelog URLs, OWASP Top 10 mapping for project class.

reflex/lib/auto-extract-adl.sh (Dev Layer 7): post-pass, scans Dev's commits for substantive bodies (≥200 chars) with rationale keywords. Drafts ADL entries to agent/.release-state/adl-drafts.md.

The original 24-dimension checklist is preserved as a safety net — runs after the 7 layers, catches classes the layers might miss. Short-circuit on CRITICAL state-diff: if Phase 0 flags a CRITICAL delta (e.g. install.sh never ran), QA halts with that single finding instead of wasting budget on a 24-dim sweep of a structurally-broken project.

### Phase 0 pre-compute — deterministic bash, LLM-free (v0.6.6)

reflex/lib/extract-claims.sh (Mode A): walks README, portable-spec-kit.md, SPECS, CHANGELOG, RELEASES, AGENT_CONTEXT, qa-agent.md — extracts every public claim (version numbers, test counts, feature counts, shipped capabilities, script inventory, skill count, install one-liner, dimension count). Emits claims.yaml with probe_type + probe_target. QA verifies each or files a finding. Unverified claim = finding. Vague claim = finding.

reflex/reference-state/speckit-project.yaml + reflex/lib/state-diff.sh (Mode B): static reference defining what a complete speckit project must contain (required files, pipeline files, dirs, git hooks, entry-point symlinks, exclusions). State-diff compares actual vs reference and emits state-diff.yaml with every delta pre-classified by severity. CRITICAL deltas auto-promote to CRITICAL findings. Kit-self auto-detected — skips user-project-only checks.

QA Phase 0 wiring in reflex/lib/spawn-qa.sh: both helpers run BEFORE sandbox creation so claims.yaml + state-diff.yaml land in the pass directory. QA reads these in Phase 0 (no LLM cost to re-derive) and uses them to plan Phase 1. The 24-dim checklist is explicitly labeled "safety net" catching classes the three modes might miss.

Assumption surfacing (Mode C) in reflex/prompts/qa-agent.md: every pass writes assumptions.md listing every implicit assumption ("kit is installed," "test harness exits 0 on green," "every [x] feature implemented"). For each, QA MUST write a probe that verifies or falsifies it. Unverifiable assumption = MAJOR QA-ASSUMPTION-NN finding.

### 4-Layer bootstrap integrity gate (v0.6.5)

New agent/scripts/psk-bootstrap-check.sh (298 lines, shared helper): 7 structural checks (C1-C7) — framework file + entry-point symlink, .portable-spec-kit/config.md, core 6 kit scripts executable, ≥10 cached skill files, pre-commit hook wired to psk-sync-check, all 9 agent/*.md pipeline files, test harness. Modes: --quiet (exit codes only), --json (machine-readable verdict), --remediate (auto-invokes parent install.sh). Kit-self detected automatically via portable-spec-kit.md real-file + install.sh + reflex/ — skips symlink/config checks for the kit repo itself.

Layer 2 — psk-release.sh Step 0 (fail-fast): run_bootstrap_gate() fires before init_state on prepare/refresh. FAIL prints the full bootstrap report + remediation command and exits 1 — no release state written. Bypass: PSK_BOOTSTRAP_CHECK_DISABLED=1 (genuine emergencies only).

Layer 3 — reflex/lib/preconditions.sh Gate 0a: runs after Gate 0 (self-test identity) and before Gate 1 (clean tree). Script resolution prefers target project's own psk-bootstrap-check.sh; falls back to kit's copy (catches the exact case where target has zero scripts). Same bypass envvar.

Layer 4 — QA-Agent Dimension 16 (Kit-bootstrap integrity): new mandatory dimension documented in reflex/prompts/qa-agent.md. Runs FIRST (even before Phase 1 Plan) — if C1-C7 fails, halt pass with single CRITICAL QA-BOOTSTRAP-NN finding. Defense-in-depth for bypassed precondition. Dimension count updated 15 → 16 throughout prompt.

### Layered R→F→T model — shallow gate + deep audit (v0.6.11)

The kit verifies R→F→T (Requirements → Features → Tests) chain integrity at TWO depths:

**Shallow gate (`agent/scripts/psk-sync-check.sh check_rft_gate`)** — fast, mechanical, runs on every commit via pre-commit hook + on every prep/refresh release Step 5. Verifies: every `[x]` feature has a test reference + the file exists + the test file passes when invoked. Returns binary pass/fail. Cached via mtime-invalidated rft-cache.txt for sub-second response. Designed to keep commits fast (<2s for typical project).

**Deep audit (`reflex/lib/check-rft-integrity.sh`)** — slower, semantic, runs only during reflex passes (Phase 0 helper). Verifies seven conditions per `[x]` feature: R→F map in REQS.md, `### F{N}` acceptance-criteria block in SPECS.md, `agent/design/f{N}.md` design plan, test ref non-empty, test is non-trivial (no TODO / skip / placeholder markers), test file exists, `[x]` mark in TASKS.md. Returns `rft-integrity.yaml` with per-feature break details + severity classification. Layer 1 of the 7-layer Senior QA architecture.

**Two-source-of-truth is INTENTIONAL.** Every-commit checks must be fast (<2s pre-commit budget); per-pass audits can be slower and stricter. The shallow gate keeps the pre-commit hook responsive; the deep audit catches gray-area breaks that escape the shallow gate. Future maintainers should not try to unify them — doing so would either slow down commits intolerably or weaken the deep audit's catch-rate.

The two-layer model is documented in code at `agent/scripts/psk-sync-check.sh:check_rft_gate` (shallow) + `reflex/lib/check-rft-integrity.sh` header (deep) + this section.

### Dimension 17 — Cost & performance audit (v0.6.11)

Dimension 17 — Cost & performance audit (mandatory): every pass measures both kit efficiency (per-phase token cost, Phase 0 helper wall-clock, mechanical-tool redundancy, cost-per-finding ratio, orchestration overhead) and project-under-test efficiency (test suite wall-clock, build/release cycle cost, API/CLI cold-start latency, dependency footprint, hot-path profiling hint). Findings emit QA-PERF-{KIT|PROJECT}-{aspect}-NN with cost_baseline + cost_target + recommendation + estimated_savings. Severity rule: CRITICAL = pass cost exceeds 2× convergence-config-set budget OR a single phase >70% of total tokens. MAJOR = >20% improvement headroom. MINOR = <5%. Dev's mirror principle 8 — Performance-aware fixing: every fix's diff is measured; for QA-PERF-* findings implement optimization in same pass + record actual_savings in commit body. Apply across all reflex run scenarios: kit-self, single-repo user project, monorepo subdir, CI environment, local dev / fast iter.

### Dimension 18 — QA + Dev philosophy self-audit (v0.6.11)

Dimension 18 — QA + Dev philosophy self-audit (mandatory, meta-evolution): every pass QA writes philosophy-gaps.md listing AT MINIMUM (a) one scenario the 18 dimensions don't cover, (b) one implicit assumption in the probe set that could be wrong, (c) one class of bug that would evade all 18 current dimensions. Each named scenario emits QA-META-PHIL-NN finding (MEDIUM, advisory, never blocking). Dev mirror — operating principle 9: Dev writes dev-philosophy-gaps.md listing one fix-pattern the 9 principles don't address + one trade-off none of the rules disambiguate. Filed as QA-META-DEV-PHIL-NN findings. Maintainer reviews cross-pass; novel + reproducible scenarios land as Dim 19, 20, etc. The kit's audit philosophy becomes self-evolving — the dimension list grows from real audit-pass discoveries, not the maintainer's imagination. The user is no longer the QA-of-QA.

### Per-pass ROI scoring — pass_score (v0.6.11, Dim 17 ranking)

pass_score — composite 0-100 metric in summary.csv v3 schema (column 15) answering "was this pass worth the spend?" Formula: findings_value (10×CRITICAL + 5×MAJOR + 1×MINOR) × fix_efficiency (dev_fixes / qa_findings) divided by (total_tokens/1000 + wall_clock/60), capped 0..100. Verdict bands: 70-100 Excellent, 40-70 Good, 20-40 OK, 0-20 Wasted. Surfaced in REFLEX_EVAL_TRACE.md per-pass header (`### pass-NNN — verdict: GRANTED · score: **48/100** (Good)` + `**Cost:** N tokens, M min wall`). Reads CRITICAL/MAJOR/MINOR counts from findings.yaml. Auto-migrates v1 (9 cols) and v2 (14 cols) CSVs in place. Empty pass_score when findings == 0 AND tokens == 0 (insufficient data).

### Register refresh timing (v0.6.11 — closes QA-AUDIT-01)

`reflex/history/REFLEX_EVAL_TRACE.md` (the cross-pass register) is refreshed by `reflex/lib/update-eval-trace.sh` **AFTER pass completion**, not at Phase 0. This is intentional: a Phase-0 register update would create a chicken-and-egg between the QA pass running and the register reflecting the pass QA is about to write. The register at QA's read time captures **prior** passes only — current pass appears post-completion.

If QA needs cross-pass context during Phase 1-2, it reads the register's snapshot at pass start (which excludes the current pass) plus prior pass directories directly. This is by design — keeps the register a stable reference rather than a moving target.

### QA → Dev contract enforcement (v0.6.13)

**Hard rule:** every reflex pass MUST run BOTH QA-Agent AND Dev-Agent alternately. The kit enforces this at three layers:

1. **`reflex/run.sh resume-qa`** — refuses to spawn Dev unless ALL mandatory QA artifacts exist in the pass directory: `findings.yaml`, `signoff.md`. If either is missing, exits 1 with retry instructions. Also warns (advisory) if `philosophy-gaps.md` (Dim 18 mandate) is missing.
2. **`reflex/run.sh resume-dev`** — refuses to write verdict + auto-merge unless `dev-result.md` AND `dev-trace.md` both exist. If Dev sub-agent times out before writing the trace, this catches it.
3. **`reflex/lib/loop.sh` Phase 4** — autoloop verdict logic checks pass directory has BOTH `findings.yaml` (QA artifact) AND `dev-trace.md` (Dev artifact) before advancing. If incomplete, halts with `INCOMPLETE` status (not GRANTED/DENIED) so the cycle is never advanced on a half-finished pass.

**Why this matters:** previously, a QA timeout could silently leave the cycle in an indeterminate state where Dev was never spawned but the autoloop's state machine advanced anyway. Now every pass either completes BOTH QA and Dev, OR explicitly halts as INCOMPLETE with retry instructions. No pass can mark itself GRANTED without both agents having actually run.

**Failure surface — what triggers blocking:**
- QA wrote no `qa-result.md` (sub-agent crashed before output) → Phase 2 halt
- QA wrote `qa-result.md` but no `findings.yaml` (partial output) → Phase 3 halt
- QA wrote findings but no `signoff.md` (skipped Phase 4 narrative) → Phase 3 halt
- Dev wrote no `dev-result.md` (sub-agent crashed) → Phase 4 halt
- Dev wrote `dev-result.md` but no `dev-trace.md` (skipped narrative) → Phase 4 halt

In each case the kit prints the missing artifact's path + a "re-spawn the agent with the prompt at \<task-file\>" instruction, never silently advancing.

### Sandbox vs history — short-lived debug vs permanent record (v0.6.13)

Two parallel directories with similar naming have different lifecycles. Confusion has been a recurring audit finding (see `reflex/history/trace.md` Issue 3).

**`reflex/history/cycle-NN/pass-NNN/`** — PERMANENT record. Every pass produces this: `findings.yaml`, `signoff.md`, `verdict.md`, `coverage.md`, `qa-usage.yaml`, `behavioral-tests/`, `philosophy-gaps.md`, etc. Committed to git. Cross-cycle register `REFLEX_EVAL_TRACE.md` indexes these. Pruned only by explicit `bash reflex/run.sh --reset --confirm` or `prune-history.sh` retention cap.

**`reflex/sandbox/cycle-NN/pass-NNN/`** — TRANSIENT debug worktree. Created by `spawn-qa.sh` at pass start with Dev's narrative files (`agent/AGENT.md` + `agent/AGENT_CONTEXT.md`) physically removed for fresh-context isolation. Purged unconditionally by `reflex/lib/purge-current-sandbox.sh` (called from both `file-bugs.sh` post-findings and `run.sh`'s empty-pass shortcut) immediately after QA finishes — structural enforcement that Dev-Agent cannot read QA's private workspace. Default retention `qa_sandbox_keep: 0` (ADR-043, v0.6.28); set >0 in `reflex/config.yml` only if you want prior sandboxes for manual cross-pass debug. Gitignored.

**Why it looks confusing:** sandbox and history layouts mirror each other (same `cycle-NN/pass-NNN/` shape under different roots). After pass-N runs, the sandbox is purged but the history dir is committed. So `ls reflex/sandbox/` shows fewer directories than `ls reflex/history/`. This is correct behavior, not a bug.

### Test suite organization (v0.6.11 — closes QA-TEST-COUPLING-01)

The kit's test suite is split into thematic files for runtime independence + per-section runnability. Closes QA-TEST-COUPLING-01 from iter-1 reflex pass on kit-self where 69 of 70 features all referenced one monolithic test file.

```
tests/
  lib.sh                              shared helpers + globals
                                      (PASS/FAIL/TOTAL counters,
                                      pass()/fail()/section()/kit_grep,
                                      PROJ/ROOT/TEMP/KIT_ALL)
  test-spec-kit.sh                    thin orchestrator (~60 lines) —
                                      sources lib.sh + each section in
                                      dependency order
  sections/
    01-infrastructure.sh   (346 tests · standalone-runnable)
    02-pipeline.sh         (395 tests · standalone-runnable)
    03-reliability.sh      (267 tests · standalone-runnable)
    04-reflex.sh           (463 tests · standalone-runnable)
```

Each section file is independently runnable: `bash tests/sections/04-reflex.sh` works from any cwd, sources lib.sh, increments the same counter globals, exits with own RESULTS line. Orchestrator aggregates via shared globals when sections are sourced (not bash'd). Total: 1471 framework tests; +145 benchmarking via separate `tests/test-spd-benchmarking.sh`.

### Standalone analysis helpers (v0.6.11 — closes QA-DOC-HELPER-01)

Two reflex helpers are NOT invoked by the standard `run.sh` / `loop.sh` orchestration — they are standalone analysis tools that maintainers run on demand:

- **`reflex/lib/audit-integrity.sh`** — post-pass self-inspection. Verifies reflex's own outputs are internally consistent (findings.yaml well-formed, register references match pass-dirs on disk, no orphan or ghost entries). Run after a complete cycle when reviewing whether reflex itself is healthy. Exit 0 = clean, 1 = inconsistencies surfaced. Invoked manually: `bash reflex/lib/audit-integrity.sh`.
- **`reflex/lib/token-report.sh`** — cross-cycle token-usage analysis report. Reads `reflex/history/token-usage.csv` (written per-pass by `track-tokens.sh`) and emits `reflex/history/token-report.md` with per-cycle totals (QA + Dev tokens, tool calls, wall seconds), efficiency trends, and pass_score correlation. Invoked manually for cost analysis: `bash reflex/lib/token-report.sh`. Complements Dimension 17 — QA fires per-pass perf findings; this helper aggregates trends across passes for budgeting decisions.

Neither helper is part of the autoloop hot path. They are kept invocable so maintainers / CI / kit-evolution reviewers can run them on demand without disturbing pass cadence.

### Reset behavior (v0.6.2 → v0.6.11)

Reflex reset command — nuclear wipe: bash reflex/run.sh --reset [--confirm] [--reset-hardening] [--reset-consent] deletes everything under reflex/history/ and reflex/sandbox/ plus runtime state files and reflex/dev-* branches via allowlist (any new pass artifact auto-cleaned). Preserves reflex/history/hardening-log.md (kit's structural-defense audit memory) and the consent marker by default.

### Flow docs updated:

- docs/work-flows/17-reflex.md — 7-layer architecture, Phase 0 pre-compute, bootstrap gate, refresh-release inter-iter optimization, reset.sh allowlist
- docs/work-flows/13-release-workflow.md — Step 0 bootstrap gate documented before Step 1 tests
- docs/work-flows/11-spec-persistent-development.md — Dimension 16 + bootstrap-check awareness for QA passes
