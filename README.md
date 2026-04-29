# Portable Spec Kit — Spec-Persistent Development

**Spec-Persistent Development — a lightweight, zero-install, personalized framework for AI-assisted engineering.**

> Drop one file into any project. Your AI agent personalizes to you, maintains living specifications throughout development, learns and follows your engineering practices, and preserves context across sessions — specs always exist, always current, never block.

[![Version](https://img.shields.io/badge/version-v0.6.15-blue.svg)](portable-spec-kit.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-1747%20passing-brightgreen.svg)](tests/)
[![Changelog](https://img.shields.io/badge/changelog-CHANGELOG.md-lightgrey.svg)](CHANGELOG.md)
<!-- CI badge — CI/CD disabled in .portable-spec-kit/config.md. Enable: say "enable ci"
[![CI](https://github.com/aqibmumtaz/portable-spec-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/aqibmumtaz/portable-spec-kit/actions/workflows/ci.yml)
-->

<table>
<tr>
<td width="25%" align="center"><strong>🪶 Lightweight</strong><br><sub>Single markdown file<br>Zero dependencies<br>Zero install</sub></td>
<td width="25%" align="center"><strong>📦 Portable</strong><br><sub>One file → any repo<br>Works instantly<br>Symlinks for all agents</sub></td>
<td width="25%" align="center"><strong>👤 Personalized</strong><br><sub>GitHub profile auto-detect<br>Adapts to your expertise<br>Tailored AI behavior</sub></td>
<td width="25%" align="center"><strong>📋 Spec-Persistent</strong><br><sub>REQS → SPECS → PLANS → DESIGN → TASKS → RELEASES<br>Every feature gets a design plan<br>Your workflow, your choice</sub></td>
</tr>
<tr>
<td width="25%" align="center"><strong>🤖 Agent-Agnostic</strong><br><sub>Claude · Copilot · Cursor<br>Windsurf · Cline<br>One source, all agents sync</sub></td>
<td width="25%" align="center"><strong>🧠 Context-Persistent</strong><br><sub>Remembers across sessions<br>Pick up after weeks<br>Never lose context</sub></td>
<td width="25%" align="center"><strong>🛡️ Reliably Enforced</strong><br><sub>3-layer gate architecture<br>Dual critic at every workflow<br>Agent physically can't skip steps</sub></td>
<td width="25%" align="center"><strong>🔄 Non-Blocking</strong><br><sub>Code first, specs later<br>Agent tracks silently<br>Never blocks the developer</sub></td>
</tr>
<tr>
<td width="25%" align="center"><strong>🔒 Security Scanning</strong><br><sub>12 credential patterns blocked<br>PreCommit hook enforced<br>Placeholder-aware, masked output</sub></td>
<td width="25%" align="center"><strong>🔍 Sub-Agent Honesty Gate</strong><br><sub>Verdicts require verbatim quotes<br>Bash grep-verifies reading<br>Fabricated quotes blocked</sub></td>
<td width="25%" align="center"><strong>🏗️ Self-Scaffolding</strong><br><sub>Auto-creates 9 agent files<br>8 stack templates built-in<br>Ready to code in seconds</sub></td>
<td width="25%" align="center"><strong>✅ Self-Validating</strong><br><sub>Agent tests everything<br>Fixes before presenting<br>98%+ coverage target</sub></td>
</tr>
<tr>
<td width="25%" align="center"><strong>🧪 Automated Test Generation</strong><br><sub>Criteria → stubs instantly<br>Stack-aware formats<br>Stub gate blocks incomplete work</sub></td>
<td width="25%" align="center"><strong>🔁 CI/CD Ready</strong><br><sub>Stack-aware templates shipped<br>Kit gates run on every push/PR<br>R→F→T gate enforced server-side</sub></td>
<td width="25%" align="center"><strong>🧰 6 Executable Workflows</strong><br><sub>release · feature-complete<br>init · reinit · new-setup · existing-setup<br>Each with preflight + dual gate</sub></td>
<td width="25%" align="center"><strong>📝 Bypass Audit Log</strong><br><sub>Every gate bypass recorded<br>Surfaced on next sync-check<br>No silent reliability loss</sub></td>
</tr>
</table>

> **Inspired by GitHub's [spec-kit](https://github.com/github/spec-kit).** A different philosophy — specs persist alongside your code, maintained by the agent, never blocking. No CLI install, no Python dependency, no package managers. One file — zero friction.

---

## Quick Start

**macOS / Linux — one command:**
```
curl -fsSL https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/install.sh | bash
```

**Windows (PowerShell) — markdown-only; run from WSL for full hook enforcement:**
```
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/portable-spec-kit.md" -OutFile "portable-spec-kit.md"; Copy-Item portable-spec-kit.md CLAUDE.md; Copy-Item portable-spec-kit.md .cursorrules; Copy-Item portable-spec-kit.md .windsurfrules; Copy-Item portable-spec-kit.md .clinerules; New-Item -ItemType Directory -Force -Path .github | Out-Null; Copy-Item portable-spec-kit.md .github/copilot-instructions.md
```

**Or paste to any AI agent (Claude, Cursor, Copilot, Windsurf, Cline):**
> Install the Portable Spec Kit: run `curl -fsSL https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/install.sh | bash` then read CLAUDE.md and set up my project.

Installs: `portable-spec-kit.md` (~980 lines) · 19 reliability scripts (+ 3 optional helpers) · 25 skill files (JIT-loaded) · 4 stack-aware CI templates · PreCommit + PostToolUse hooks · symlinks for all supported agents.

Open any AI agent after install — personalized profile, project scan, 4-step guided tour, and you're building in under 2 minutes. **[Full install details ↓](#setup)** · **Uninstall:** `bash agent/scripts/psk-uninstall.sh` (preserves your `agent/*.md` pipeline files).

---

## Latest Release

**v0.6.13 (Nested per-cycle history layout + Dim 23 + cycle-summary aggregator + autoloop convergence):** closes the meta-gap class user surfaced in cycle-01 trace audit (5 issues + 4 sub-gaps), formalizes Dim 23 — Auditor-output hygiene with five new probes (register hygiene · cost data persistence · parallel-directory disambiguation · cross-surface terminology consistency · self-output validation loop) so QA self-evolves to catch this class going forward. Migrates reflex history from flat `cycle-NN-pass-NNN/` to nested `cycle-NN/pass-NNN/`; sandbox mirrors. Per-cycle parent dir hosts a `summary.md` aggregator (`reflex/lib/cycle-summary.sh`). **Drops the hard 3-iter autoloop cap** in favor of convergence-based stopping (GRANTED · REGRESSION · findings_floor · plateau · fix-rate drop); `max_iterations_safety` (default 20) is escape hatch only. **First successful Dev-Agent run end-to-end:** cycle-01-pass-004 closed `QA-NOISE-RE-01` bucket A, all 6 mechanical gates green, fast-forward auto-merge — first time QA→Dev→merge loop closed without manual intervention. 3-layer QA→Dev contract enforcement closes "Dev never spawned on partial QA timeout" silent-skip pattern from cycle-01-pass-002. `reflex/install-into-project.sh` gitignore template aligned to v0.6.13 layout.

**v0.6.12 (Reflex iter-1 convergence anchor + close all 15 v0.6.11 audit findings):** anchor version for the reflex iter-1 convergence cycle. Consolidates 8 refresh-release commits from v0.6.11 baseline. All 15 audit findings (5 pre-existing ARBs + 10 iter-1 QA findings) resolved or properly deferred; kit's own QA infrastructure self-validated end-to-end via reflex iter-1 self-test on kit-self. Persistent test-ref cache: cold 54s → warm 5s = 10.9× speedup. Dim 17 cost/perf audit + Dim 18 philosophy self-audit added to QA prompt + Dev mirror principles 8/9. pass_score (Dim 17 ranking) v3 summary.csv schema. Option C thematic test-suite split (`tests/lib.sh` + `tests/sections/{01-infrastructure,02-pipeline,03-reliability,04-reflex}.sh`).

**v0.6.11 (Reset allowlist + iter-aware refresh-release optimization):** `reflex/lib/reset.sh` switched from hardcoded glob lists to allowlist-based `find` traversal with `HISTORY_KEEP=("hardening-log.md")`. Symmetric `--reset-hardening` flag for true clean-slate. `reflex/lib/loop.sh` Phase 1 now branches on `ITER`: iter 1 = `prepare release` (version bump), iter 2+ = `refresh release` (no bump — captures Dev's auto-merged fixes through same critic gates at ~50% cost).

**v0.6.10 (Closing v0.6.9 ARBs — kit's own RFT debt backfilled + PSK018 strict):** the v0.6.9 field-test surfaced 55 missing `### F{N}` acceptance-criteria blocks in the kit's own SPECS.md. v0.6.10 backfilled all 55 (3-5 testable bullets each, ~200 lines) and flipped `PSK018` (per-feature pairwise check in `psk-sync-check.sh`) from advisory to strict-by-default. The kit's own Layer 1 RFT integrity goes from 55 C2-criteria breaks → 0. Future commits that add an `[x]` feature without a matching block fail pre-commit. Opt-out: `PSK_FEATURE_CRITERIA_STRICT=0`.

**v0.6.9 (The kit is audited and improved by the reflex it built):** the architecture built across v0.6.5-v0.6.8 was designed to find drift in user projects. v0.6.9 ran that exact machinery against the kit itself. **The same QA-Agent that catches bugs in your code caught real bugs in the code that builds the QA-Agent** — 180 mechanical drift items + 5 QA findings + 1 live regression the kit's own existing gates had passed clean. A tool sufficient to audit your projects must be sufficient to audit the project that built it — v0.6.9 proved that proposition.

- **Phase 0 helpers exposed 180 mechanical drift items** (170 R→F→T pipeline breaks + 10 doc↔code drifts) on kit-self
- **5 QA findings filed.** Dev closed 2 inline: live `kit-loop-state.yml` → `loop-state.yml` rename incompleteness + `psk-sync-check.sh` Layer-4 inadequacy
- **Layer 5 hub-suppression:** 77 → 13 candidate pairs after F64/F70 hub features filtered
- **Layer 4 hardening shipped:** new `PSK018` per-feature pairwise check; would have caught a "69 of 70 acceptance-criteria blocks deleted" silent ship
- Field-test artifacts committed as permanent evidence in `reflex/history/field-test-v0.6.8/`
- 3 ARBs queued for v0.6.10: backfill 55 missing `### F{N}` blocks + 2 behavioral integration probes

**v0.6.8 (Reflex 7-layer full implementation — deterministic helpers for all layers):** completes v0.6.7's architecture. All 7 layers now have deterministic-bash seed-helpers wherever possible.

- **`reflex/lib/scaffold-behavioral-tests.sh` (QA L3)** generates 1+5+3+1 test-plan skeleton per `[x]` feature.
- **`reflex/lib/identify-integration-probes.sh` (QA L5)** finds feature-pair candidates from cross-references.
- **`reflex/lib/external-research.sh` (QA L7)** seeds CVE/framework/OWASP queries from manifests.
- **`reflex/lib/auto-extract-adl.sh` (Dev L7)** drafts ADL entries from commit-body rationale.

Phase 0 produces 8 pre-populated artifacts in pass dir before QA spawns. LLM budget redirects to creative reasoning, not derivation.

**v0.6.7 (Reflex 7-layer Senior/Principal-level QA system):** the user must NOT be QA of their own project. Reflex now operates with a 7-layer Senior/Principal-level QA system that derives all probes from the project's spec pipeline + kit toolkit + running system — zero human-curated lists.

- **Layer 1 — `check-rft-integrity.sh`** verifies R→F→T pipeline (every `[x]` feature → Rn map / criteria block / design plan / non-trivial test / TASKS mark). Each break = CRITICAL.
- **Layer 2 — `doc-code-diff.sh`** bidirectional consistency: every doc claim → code; every code feature → ≥1 doc surface.
- **Layers 3-5 / 7** — qa-agent.md mandates: behavioral per-feature (1 happy + 5 edge + 3 adversarial + 1 integration), test-quality audit (after own test), cross-feature integration probes, external research (CVE / OWASP / deprecations).
- **Layer 6** — spawn-qa.sh captures `psk-sync-check`, `psk-doc-sync`, `test-release-check`, `psk-code-review` outputs as research input.
- **Senior/Principal-level philosophies** codified in qa-agent.md + dev-agent.md prompts.
- **Architecture plan** committed at `agent/design/f70-reflex-senior-engineer-qa.md`.

**v0.6.6 (Reflex Phase 0 pre-compute — claims + reference-state + assumption probing):** closes the meta-gap where reflex QA ran 3 GRANTED passes on an infrastructurally-empty project because its probe set was a closed 16-dim checklist. Moves reflex from "fixed checklist" to "probe-set derived from the project itself" — while keeping the 16-dim checklist as a safety net.

- **Mode A — `reflex/lib/extract-claims.sh`:** walks public docs, extracts every claim (version, test count, shipped capabilities) with `probe_type` + `probe_target`. Unverified or vague claim = finding.
- **Mode B — `reflex/reference-state/speckit-project.yaml` + `reflex/lib/state-diff.sh`:** reference definition of a complete speckit project; state-diff pre-classifies every delta by severity. CRITICAL deltas auto-promote to findings.
- **Mode C — assumption surfacing in `qa-agent.md`:** every pass writes `assumptions.md`; each assumption gets a probe. Unverifiable assumption = MAJOR finding.
- **Dev-Agent expanded scope:** fix findings + build unfulfilled claims + remediate state-diff deltas — all in the same pass.

**v0.6.5 (Kit-bootstrap integrity gate — 4-layer defense against un-installed-kit projects):** closes the failure mode where a non-kit-aware agent scaffolds a project manually and still proceeds through prep-release + reflex on an infrastructurally-empty project.

- **Layer 1 — `install.sh`** (unchanged, canonical installer).
- **Layer 2 — `psk-release.sh` Step 0** — `run_bootstrap_gate()` fires before `init_state` on `prepare`/`refresh`; FAIL exits 1 with remediation command.
- **Layer 3 — `reflex/lib/preconditions.sh` Gate 0a** — runs between Gate 0 (self-test) and Gate 1 (clean tree); script resolution falls back to kit's copy when target has no scripts.
- **Layer 4 — QA Dimension 16 "Kit-bootstrap integrity"** — new mandatory dimension; runs FIRST and halts pass with CRITICAL `QA-BOOTSTRAP-NN` on C1-C7 fail.
- **`agent/scripts/psk-bootstrap-check.sh`** (298 lines, shared helper): 7 checks (framework file + entry point symlink, config, core scripts, cached skills, pre-commit hook, pipeline files, test harness). Modes: `--quiet`, `--json`, `--remediate`. Kit-self auto-detected.

**v0.6.4 (Reflex convergence + loop-resume + gates cache + token tracking):** Five orchestration fixes surfaced by the autonomous v0.6.3 reflex run.

- **Convergence-based stopping (N56):** replaces "max 3 iters" with real signals (GRANTED, REGRESSION, findings_floor, plateau, fix-rate drop, safety cap).
- **--loop --resume collision fix:** deferred flag resolution — `run.sh --loop --resume` routes to `loop-resume` instead of hijacking to resume-qa.
- **gates.sh cache-order bug:** rft-cache cleared at gate entry so sequential gates don't see stale data.
- **Token tracking (reflex/lib/track-tokens.sh):** `reflex/history/token-usage.csv` + `tokens_per_finding` metric + per-pass/per-cycle budget warnings.
- **Iteration auto-chain on gate-fail:** spurious gate failures no longer abort the autoloop; only REGRESSION + verdict signals halt.

**v0.6.3 (Autonomous reflex run validation):** Mechanical patch minted from an autonomous end-to-end reflex run on the v0.6.2 consolidation. QA surfaced 11 findings (3 CRITICAL); Dev fixed 11/11 in 6 atomic commits on the dev branch, fast-forward merged to main.

**v0.6.2 (Dev-branch isolation + protected-files write-ban + autoloop + history retention):** Closes the reflex execution-model loop — QA was sandboxed; Dev now runs on an isolated branch with a 3-layer write-ban on the two spec-persistent-owned files. Unified `autoloop` command for kit + user projects, plus bounded-disk history retention.

- **Dev-branch isolation:** every reflex pass runs Dev on `reflex/dev-cycle-NN-pass-NNN`. Fast-forward merge back on GRANTED + auto-delete; unhappy branches kept (last 3) for review.
- **Protected-files write-ban:** `agent/AGENT.md` + `agent/AGENT_CONTEXT.md` enforced unmodifiable from reflex via 3-layer gate — prompt constraint + `gates.sh` diff check + `psk-sync-check.sh` pre-commit hook on reflex dev branches.
- **Autoloop generalization:** `bash reflex/run.sh` (default mode; `--loop` / `--kit-loop` / `--autoloop` aliases retained for backward compat) — one command for kit self-test, new projects, existing projects. Use `bash reflex/run.sh single` for single-pass mode.
- **History retention:** `pass_dirs_keep: 10`, `dev_branches_keep: 3`, `qa_sandbox_keep: 3`; register + summary.csv forever. Archived passes marked `_(archived)_` in register with status still resolvable from TASKS.md. Manual: `--purge-history --confirm`.
- **Concurrency + empty-pass:** `flock`-based lockfile prevents parallel reflex corruption; 0-finding passes shortcut to GRANTED with no Dev spawn.
- **Intake parser update:** `reflex/lib/intake.sh` now reads `findings.yaml` YAML block from GitHub issue bodies (matches v0.6.2+ submission format).
- **Sandbox purge after QA:** `file-bugs.sh` removes the current pass's QA sandbox worktree immediately after findings are extracted — Dev physically cannot read QA's private workspace.
- **Nested per-cycle layout (v0.6.13+):** directories are `cycle-NN/pass-NNN/` (autoloop) and `standalone/pass-NNN/` (single-pass); `ls reflex/history/cycle-NN/` walks one cycle at a glance. Per-cycle parent dir hosts a `summary.md` aggregator (`reflex/lib/cycle-summary.sh`). Flat identity (`cycle-NN-pass-NNN`) is reserved for git branches, CSV pass id, and `[source: ...]` commit trailers.
- **Cycle metadata + grouped register render:** each pass has `.cycle-meta` pinning it to its autoloop cycle; register groups blocks by cycle.
- **All per-pass artifacts committed:** every QA/Dev output per pass now lives in git (no scratch gitignore); retention policy bounds disk.
- **Entry consolidation — single CLI surface:** `bash reflex/run.sh` is the sole public entry, default mode = autoloop; wrapper scripts retired.
- **Reflex reset command — nuclear wipe:** `bash reflex/run.sh --reset [--confirm] [--reset-hardening] [--reset-consent]` deletes every pass / sandbox / dev branch / state file via allowlist (any new pass artifact auto-cleaned). Preserves `reflex/history/hardening-log.md` (kit's structural-defense audit memory) and the consent marker by default; pass the matching flag to also wipe either.

---

**v0.6.1 (Kit self-evolution loop + MINIMAL template tier + 14 framework-gap closures):** Dual-track release closing the empirical-kit-evolution loop and adding a third response-template tier.

- **N33 adopter-side auto-submit:** opt-in dispatcher at end of every pass (manual/prompt/auto modes, 4 guards).
- **N38 maintainer-side intake automation:** weekly GitHub Action parses avacr-eval issues into `agent/tasks/Gxx-*.md` drafts.
- **N44/N45 general-purpose runner + kit-loop:** mode-less `reflex/run.sh` with kit-identity detection and `--kit-loop` chaining prep-release + self-test.
- **Trace continuity across passes (QA reads prior trace):** QA Phase 1 mandates reading prior pass's `findings.yaml` + `signoff.md` + the cross-pass register.
- **Per-pass canonical trace (Q1):** `findings.yaml` (structured) + `signoff.md` (verdict) per pass; `reflex/history/REFLEX_EVAL_TRACE.md` (cross-pass findings register) indexes them all.
- **14 kit framework gaps closed (G1-G15 less G11):** parsing, recovery, schema validation, coverage YAML, token accounting.
- **MINIMAL template (3rd tier) for short answers:** ~2s, ~80-100 tokens — yes/no / status / short factual.
- **Auto-dispatch rule:** trigger table picks tier by answer shape; user does not specify.
- **Writing Style sub-section (5 editorial rules):** one idea per sentence · periods over em-dashes · drop semicolons · cut parentheticals · one voice per reply.
- **Breadcrumb rules 6a + 6c + 6d:** closed-sibling ✓-hint, MINIMAL breadcrumb skip on consecutive same-node replies, optional MINIMAL footer.
- **Pre-send self-check:** 4-anchor validation (breadcrumb · border · template body · arrow) silently before every reply.
- **3-tier long-session scalability:** T1 auto-collapse · T2 active-chain render · T3 chapter rotation at ≥15 KB / ≥80 nodes.
- **Promotion rule:** closed ✓ session-stack node with durable project work prompts for `agent/TASKS.md` entry before session end.
- **Pre-session read list updated:** `.session-stack.md` added at item 4 of 11.
- **Skill trigger for "where was I" / "losing context" / "conversation-stack":** auto-loads `session-trace.md`.
- **Skill trigger for "integration tests" / "FastAPI" / "live-server":** auto-loads `test-templates.md`.
- **Rule-revision post-mortem meta-rule:** ADL entry required after 3+ rule revisions in one session.
- **Unpushed-commit advisory in psk-sync-check:** `--full` warns at ≥10 unpushed commits (threshold via `PSK_UNPUSHED_WARN`).
- **Signoff discipline:** `signoff.md` lists blocking findings explicitly; GRANTED only when zero CRITICAL + zero MAJOR blocking.
- **Prompts rewritten:** QA-Agent + Dev-Agent prompts updated for adversarial framing, sandbox mechanism reference, citable-quote gate, and trace continuity.
- **Paper title update:** AVACR formal title lands.
- **SPD paper v2 §7.6 cross-reference:** paper methodology cross-references AVACR evaluation harness.
- **Design plan §4-5 and §18:** `agent/design/f70-reflex.md` sections updated for v0.6.1 shape.
- **Adversarial-goal reframing:** convergence criterion narrowed.
- **Sandbox mechanism:** dual-rooted access documentation added.
- **14-dimension adversarial hunt:** carries through from v0.6.0.
- **4-persona testing:** carries through from v0.6.0.
- **Coverage declaration + regression-vector re-execution:** findings persist with exact invocation + expected assertion across passes.
- **Flaky-vs-deterministic distinction:** separates root-cause investigation from patch-retry.
- **4-bucket Dev diagnosis + Bucket-D rebuttal:** A doc / B code / C both / D QA-misread (requires counter-citation).
- **Human-arbitration escalation:** routes cross-cutting / ADL-amendment findings to `@<human>`.
- **Physical sandbox isolation:** see v0.6.0 — v0.6.1 adds dual-rooted access docs.
- **Research capability:** v0.6.0 framework continues; WebSearch/WebFetch for RFCs, OWASP Top 10, CVEs, papers.
- **Consistency sweep:** cycle → pass rename carries through to live scripts + CSV column.
- **CHANGELOG truth-check mandate:** every bullet requires a test case; unverifiable claims block signoff.
- **Bug fixes surfaced during sweep:** installer path + update URL regressions fixed.

**v0.6.0 (F70 Reflex evolves to AVACR — Adversarial Verbal Actor-Critic Refinement Loop):** architectural shift from cooperative VACR to **adversarial goals with collaborative convergence.** QA-Agent's goal = FAIL the release; Dev-Agent's goal = FOOLPROOF it against QA's hunt. The tension forces gray-area superficial implementations to become production-grade over successive passes. Convergence = QA hunts hard across 14 dimensions and cannot find a blocker, not "Dev says it's done." **Physical sandbox isolation:** QA runs in a git worktree with `agent/AGENT.md` + `agent/AGENT_CONTEXT.md` removed (Dev's narrative can't bias QA's fresh-context investigation). **Peer-to-peer YAML exchange:** `findings.yaml` → `dev-result.yaml`. Human reads only `signoff.md` (GRANTED or DENIED with exit criteria) — never agent working output. **14-dimension adversarial hunt** (functional / edge / pipeline / workflow / research-backed-quality / superficiality / production-readiness / security / performance / arch-compliance / docs / test-quality / tech-debt / readiness) × **4 personas** (new-user / power-user / malicious-user / accessibility-user). **Research-grounded findings** with citable-quote honesty gate. **Dev sibling-class hardening** + Bucket-D grounded rebuttals + human-arbitration routing for architectural findings. See `docs/work-flows/17-reflex.md` and `agent/design/f70-reflex.md`.

**v0.5** — Full Development Pipeline + Reliability Architecture. 3-layer enforcement (bash critic · sub-agent critic · git/editor hooks), dual-gate validation across all 6 executable workflows, security scanning (PSK011 — 12 credential patterns blocked at commit), verbatim-quote critic gate, 5 workflow orchestrators with preflight, CI templates for user projects.

**v0.5.20** added `psk-doc-sync.sh` — a full-surface documentation coverage analyzer that extracts every feature from the current-minor CHANGELOG and verifies it's reflected across all 5 doc surfaces (`agent/*.md`, `docs/work-flows/*.md`, `docs/research/*.md`, `ard/*.html`, `README.md`). Mandatory at release Step 4; sub-agent critic re-runs it at Step 9 and any MISSING entry blocks the release. Earlier v0.5.18–v0.5.19 PSK012–PSK017 added README/ARD/flow-doc structural checks and OMISSION DETECTION language to the critic prompts, closing the "agent claims done without reading" gap structurally.

**v0.5.23 (F70 Reflex — VACR, Verbal Actor-Critic Refinement Loop):** initial shipping of post-prep-release automated QA + auto-fix cycle. A fresh-context QA-Agent (black-box) systematically tests every SPECS acceptance criterion, files bugs to `agent/TASKS.md` as `@reflex-dev` tasks, and a fresh-context Dev-Agent fixes them atomically with per-commit mechanical gates. Counters lost-in-the-middle. Evolved into AVACR in v0.6.0 above.

**→ Full release notes:** [CHANGELOG.md](CHANGELOG.md) · [GitHub Releases](https://github.com/aqibmumtaz/portable-spec-kit/releases)

---

## The Methodology: Spec-Persistent Development

**Specs always exist and stay current, but never block.**

Traditional approaches force a choice: write specs first (waterfall) or skip them (agile). Spec-Persistent Development is the first methodology native to the AI era — specifications persist throughout development, maintained by the AI agent, evolving with your code, never gating your work.

| | **Waterfall** | **Agile** | **Spec-First** (spec-kit) | **Spec-Persistent** (this kit) |
|---|:---:|:---:|:---:|:---:|
| **Specs exist?** | Yes, upfront | Often no | Yes, formal | **Always — living documents** |
| **Specs block code?** | Yes | No | Yes | **Never** |
| **When written?** | Before code | Rarely | Before code | **Before, during, or after** |
| **Who maintains?** | Humans | Humans (skip) | Humans | **Agent (90%)** |
| **Context persists?** | In docs | In people's heads | Per-session | **Across sessions, weeks, months** |
| **Your workflow** | Sequential | Iterative | 6-phase | **Your choice — any style** |

### The Framework Doesn't Enforce a Methodology

You choose how you work. The kit adapts:

- **Want waterfall?** Follow SPECS → Design Plans → Architecture → TASKS → RELEASES sequentially. The kit supports it.
- **Want agile?** Jump into coding. The agent tracks tasks, fills specs and plans retroactively.
- **Want a mix?** Write rough specs, start coding, refine as you go. The agent keeps everything in sync — plans included.
- **Want to change mid-project?** Started agile but need specs now? The agent fills them from what's built.

The only constant: **specs persist**. However you work, the agent ensures SPECS.md, PLANS.md, TASKS.md, and RELEASES.md always reflect the current state of your project.

### Critical Scenarios Where This Changes Everything

**New machine, same project.** Clone the repo, open a new AI chat, ask: *"What's the project status?"* The agent reads your spec files and delivers a full briefing — what's built, what's pending, every architectural decision and why. Zero re-explaining. Zero context reconstruction.

| Scenario | Without Kit | With Kit |
|----------|------------|---------|
| New machine / fresh install | Re-explain entire project from scratch | Clone repo → agent reads context → continue instantly |
| Returning after weeks | "Wait, where were we?" — rebuild context manually | Agent reads AGENT_CONTEXT.md → full picture in seconds |
| Forced agent switch | Context lost — Claude → Copilot means starting over | All agents read same files → zero loss |
| Computer crash or wipe | Project context gone | Push to git → pull → fully restored |
| Team member leaves | Knowledge walks out the door | All decisions, reasoning, scope changes preserved in PLANS.md |
| New developer onboards | Weeks of code archaeology | Clone → read agent files → full history understood in minutes |
| Client hands off project | New team guesses at intent | R→F traceability: every requirement → feature → decision recorded |
| Context window fills | Start new chat, lose all context | New chat → agent reads files → continues seamlessly |

### Empirical Kit Evolution — the kit learns from every adopter

The kit does not improve by maintainer self-testing alone. Every user who runs the built-in adversarial QA/Dev loop (**Reflex / AVACR**) on their own project contributes — automatically and optionally — to kit improvement.

Every finding surfaced by the QA-Agent carries a `scope:` classifier: `target-project` (fix belongs in the user's repo), `kit` (fix belongs in kit scripts, prompts, skills, templates), or `meta` (fix belongs in kit research/positioning/methodology claims). Findings with scope `kit` / `meta` are routed upstream as kit-repo tasks (`agent/tasks/Gxx-<slug>.md`); findings with `target-project` stay local and are auto-fixed by the Dev-Agent.

This means: **the kit is continuously stress-tested by real-world projects, not just by the maintainer**. Each approved upstream fix must pass a *genericness bar* — it must hold true for any user, not just the one that surfaced it. Rejected fixes keep their rationale in `agent/tasks/rejected/` as an audit trail of "why not." The result is an empirical feedback loop: the more projects that run AVACR, the faster the kit converges on a generic, user-agnostic core.

---

## The Problem

AI coding agents are powerful but inconsistent. Every new conversation starts from zero — no context, no standards, no memory of decisions. You end up repeating yourself: "use TypeScript", "test everything", "don't commit secrets", "track tasks in markdown"...

**Existing approaches vary.** GitHub's [spec-kit](https://github.com/github/spec-kit) is a comprehensive spec-first solution requiring Python 3.11+, a CLI tool, and package managers. It follows a structured 6-phase workflow. Portable Spec Kit takes a different approach — lighter, more flexible, and personalized.

## The Solution

**One markdown file. Zero dependencies. Zero install. Works with every AI agent.**

After running the [Quick Start](#quick-start) install, the kit takes over:

1. **Personalized profile** — fetches your GitHub identity, asks 3 quick preferences, adapts to your expertise
2. **Project setup** — scans your codebase, creates 9 management files in `agent/` (6-stage pipeline + 3 support), detects your stack, installs PreCommit hook + PostToolUse hook
3. **Guided tour** — 4-step interactive walkthrough (under 1 minute): your project, how to work, your settings, getting help
4. **Ready to build** — just describe what you want. The kit tracks requirements, specs, plans, designs, tasks, tests, and releases automatically, with 3-layer enforcement preventing drift

After setup, the kit stays present:
- **Every session** — greets you by name, shows pending tasks, flags scope issues
- **At every milestone** — acknowledges progress, suggests next steps
- **When you're stuck** — say `"help"` and the kit shows exactly what you can do right now
- **When you need guidance** — say `"how do I...?"` and it walks you through step by step
- **You never memorize commands** — the kit knows what's relevant and surfaces it contextually

### Advanced install options

**Verify before running** (inspect the installer first):
```
curl -fsSL https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/install.sh -o install.sh
cat install.sh && bash install.sh
```

**Non-interactive** (CI, scripts):
```
curl -fsSL https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/install.sh | bash -s -- --yes
```

---

## How It Compares

| | **spec-kit** (GitHub) | **portable-spec-kit** |
|---|:---:|:---:|
| **Setup** | Python 3.11+, `uv`, CLI install, config | **Drop 1 file** |
| **Dependencies** | Python, uv, templates, extensions | **None** |
| **Install time** | Minutes (download Chromium, Python packages) | **Seconds** (one curl) |
| **Files generated** | 2,500+ lines per feature | **6 lean files** |
| **Learning curve** | Moderate — 6-phase workflow | **Zero** — start coding, agent tracks |
| **Rigidity** | Sequential, spec-before-code | **Flexible** — code first, specs retroactively |
| **Blocking** | Must complete specs before implementation | **Never blocks** — work however you want |
| **AI agents** | 30+ with config per agent | **Any AI** — zero-config symlinks for all |
| **Execution time** | 33+ min agent + hours review | **Instant** — read file, start working |
| **Context persistence** | Per-session | **Cross-session** — AGENT_CONTEXT.md |
| **Portability** | Per-project setup required | **One file across all projects** |
| **Spec overhead** | Thousands of lines of formal spec | **Lightweight specs** — as detailed as you need |

---

## Gates, Not Review — Why the Kit Actually Reduces Human Hours

Every AI coding tool promises autonomy. Most deliver relocation.

Agent-native IDEs like Cursor, Windsurf, and Google Antigravity adopt an **agents + evidence + review** model: the agent acts, emits artifacts (diffs, logs, screenshots, test runs), and you approve, revert, or redirect. It's marketed as autonomy through transparency. Operationally, it shifts human work from *writing code* to *reading agent output*. Every browser action, every diff, every log is an artifact you must approve, revert, or redirect.

**The ceiling is human reading speed. You sit at the screen longer, not shorter. You just read different things.**

For most developers, reading speed is roughly equal to typing speed. Total hours do not decrease — the bottleneck moves from authoring to auditing, and the biological constraint is the same.

### The Portable Spec Kit's answer: mechanical gates, not human attention

Where agent-native IDEs put validation in **your attention**, PSK puts it in **enforced code**. You read one verdict line per workflow — pass or fail — not N artifacts per task.

| Validation concern | Agent-evidence-review IDE | Portable Spec Kit |
|---|---|---|
| Spec consistency with code | You read every file after agent edits | `psk-sync-check.sh` runs 18 checks; exits non-zero on drift |
| Test coverage of every feature | You inspect each PR for test presence | R→F→T gate refuses to mark a feature done without tests |
| Release artifact correctness | You read CHANGELOG, RELEASES, version bumps | 10-step release pipeline enforced by named-file critic verdicts |
| Functional behavior matches SPECS | You exercise the built system yourself | AVACR loop (Reflex) runs autonomous QA-Agent + Dev-Agent |
| Cross-file count agreement | You spot-check between releases | PostToolUse hook runs sync-check after every Write/Edit |

Each gate is **code, not attention**. It cannot skim. It cannot have a distracted day. It either passes or blocks — the pre-commit hook physically prevents a bad state from landing on disk.

### The scaling law changes

In an agent-review model, supervisory load scales linearly with agent actions — more features, more artifacts, more reading. In PSK, supervisory load scales with workflow verdicts, which is roughly constant regardless of project size. The ceiling in an agent-review IDE is **human reading hours** (a fixed biological constant no framework can raise). The ceiling in PSK is **gate coverage** — which you can extend. Adding check #19 to `psk-sync-check.sh` is a one-time cost that eliminates a category of review work forever.

| | Agent-native IDEs | Portable Spec Kit |
|---|---|---|
| Agent writes code | ✓ | ✓ |
| Human time is reduced | ✗ — shifted from writing to reading | ✓ — gates replace review |
| Reviewer attention scales with project size | Linearly — more tasks = more artifacts | Sub-linearly — more features = same verdict lines |
| Bad output can slip past gates | If you skim — your judgment is the only gate | Only with explicit bypass — gates are mechanical |
| What happens on a distracted day | Risk rises — attention is the gate | No risk — gates don't get distracted |

**The correct pitch is not "agents do the work." It is "gates do the review."**

> **Scope honesty:** This reduction applies cleanly from SPECS.md through release. Left-of-SPECS stages (requirement elicitation, architecture choice, UI design) still involve human effort today; extending gates-not-review to those stages is the v0.6 research direction. For the portion the kit covers, you read verdicts, not artifacts.

---

## Multi-Agent Support

One source file — `portable-spec-kit.md` — works with every AI coding agent:

| Agent | File Created | How |
|-------|-------------|-----|
| **Claude Code** | `CLAUDE.md` | Symlink → portable-spec-kit.md |
| **GitHub Copilot** | `.github/copilot-instructions.md` | Symlink → portable-spec-kit.md |
| **Cursor** | `.cursorrules` | Symlink → portable-spec-kit.md |
| **Windsurf** | `.windsurfrules` | Symlink → portable-spec-kit.md |
| **Cline** | `.clinerules` | Symlink → portable-spec-kit.md |

Edit `portable-spec-kit.md` once — all agents read the update instantly (via symlinks on Mac/Linux, copies on Windows).

---

## Complete Flow

### Step 1: Install (one command)

See setup commands above (macOS/Linux or Windows). Downloads `portable-spec-kit.md` and creates symlinks for all agents.

**Result:**
```
your-project/
├── portable-spec-kit.md                  ← Source (edit this one)
├── CLAUDE.md → portable-spec-kit.md      ← Claude Code
├── .cursorrules → portable-spec-kit.md   ← Cursor
├── .windsurfrules → portable-spec-kit.md ← Windsurf
├── .clinerules → portable-spec-kit.md    ← Cline
└── .github/copilot-instructions.md → portable-spec-kit.md ← Copilot
```

### Step 2: Open any AI agent — the kit takes you through setup

The agent reads the framework and guides you through everything:

```
✓ Profile setup — GitHub auto-detect + 3 quick preferences
✓ Project scan — detects stack, creates agent/ files, README, .gitignore
✓ Config created — .portable-spec-kit/config.md with defaults
✓ Guided tour — 4-step interactive walkthrough:
    1. Your project (what's set up, what's tracked)
    2. How to work (just talk naturally — the kit handles the rest)
    3. Your settings (what's enabled, how to change)
    4. Getting help (say "help" anytime — the kit guides you)
✓ Ready to build!
```

### Step 3: Just work — the kit stays with you

```
You: "Build me a login page"
Kit: Plans it → builds it → tests it → tracks it → done ✓

You: "What should I do next?"
Kit: Shows your pending tasks and suggests the next action

You: "help"
Kit: Shows exactly what you can do right now, based on your project state

You: "How do I release?"
Kit: Walks you through step by step — one step at a time
```

The kit never gets in your way. It tracks silently, helps when asked, and suggests features when relevant — all derived from your current project state, always up to date.

### Step 4: Context stays current

The agent updates `agent/AGENT_CONTEXT.md` at three natural checkpoints — not on a timer:

```
✓ After significant work (feature built, tests passing)
✓ After committing — commit is a natural checkpoint
✓ Before any push — context must be current before code reaches remote
```

### Step 5: Come back later (days, weeks, months)

```
✓ Agent reads agent/AGENT.md + agent/AGENT_CONTEXT.md
✓ "Here's where we left off — v0.1 has 8/12 tasks done. Next: payment integration."
✓ Continues exactly where you stopped
```

### Step 6: Edit the framework

```
✓ Edit portable-spec-kit.md — all 5 agent symlinks read the update instantly
✓ Your standards evolve with you across all projects
```

---

## The Framework

### The Agent Directory (auto-created in `agent/`)

**9 agent files** form the Persistent Memory: a 6-stage pipeline + 3 support files.

| Tier | File / Dir | Purpose | Updated When |
|------|------------|---------|-------------|
| Pipeline | `REQS.md` | Business requirements in client language (raw input in `reqs/`) | First — when requirements gathered + when scope changes |
| Pipeline | `SPECS.md` | Features mapped from requirements (R→F), acceptance criteria, Tests column | Before dev + when scope changes |
| Pipeline | `PLANS.md` | Architecture, stack, ADL with Plan Ref column | Before dev + when architecture evolves |
| Pipeline | `DESIGN.md` | Design overview + per-feature plans index | When features designed |
| Pipeline | `TASKS.md` | Version-based task tracking with checkboxes | Before and after every task |
| Pipeline | `RELEASES.md` | Version changelog, test results, R→F→T traceability | End of each release |
| Support | `RESEARCH.md` | Research index across all stages | When decisions need data |
| Support | `AGENT.md` | Project rules, stack, brand, AI config, Jira config | Setup, when stack/config changes |
| Support | `AGENT_CONTEXT.md` | Living state — done, next, decisions, blockers | Every session + after significant work |
| Dirs | `design/` | Per-feature design plans (`f{N}-name.md`) | Auto-created per feature |
| Dirs | `scripts/` | All bash scripts (sync, release, Jira, tracker, 5 workflow orchestrators) | Created during setup |
| Local | `.release-state/` | Release state + bypass log + critic protocol files (gitignored) | During workflow execution |

### Project Structure

```
your-project/
├── portable-spec-kit.md    ← The framework (source file)
├── .portable-spec-kit/     ← Kit config (committed)
│   ├── config.md           ← Project config (CI/CD, Jira, toggles)
│   ├── skills/             ← Skill files (lazy loaded on demand)
│   └── user-profile/
│       └── user-profile-{username}.md
├── CLAUDE.md               ← Symlink (Claude Code)
├── .cursorrules            ← Symlink (Cursor)
├── WORKSPACE_CONTEXT.md    ← Auto-created (workspace state)
├── README.md               ← Auto-created (standard structure)
│
├── agent/                  ← Auto-created (project management)
│   ├── REQS.md             ← Requirements (pipeline stage 1)
│   ├── SPECS.md            ← Features + R→F mapping (stage 2)
│   ├── PLANS.md            ← Architecture + ADL (stage 3)
│   ├── DESIGN.md           ← Design overview (stage 4)
│   ├── TASKS.md            ← Task tracking (stage 5)
│   ├── RELEASES.md         ← Version log (stage 6)
│   ├── RESEARCH.md         ← Research overview (support)
│   ├── AGENT.md            ← Project config (support)
│   ├── AGENT_CONTEXT.md    ← Living state (support)
│   ├── reqs/               ← Raw client input
│   ├── specs/              ← Detailed acceptance criteria
│   ├── plans/              ← Detailed architecture docs
│   ├── design/             ← Per-feature design plans
│   ├── tasks/              ← Sprint plans
│   ├── releases/           ← Release traceability summaries
│   ├── research/           ← Research (6 stage subdirs)
│   └── scripts/            ← Bash automation
│
├── src/                    ← Your code
├── tests/
│   ├── test-release-check.sh ← R→F→T validator (auto-created by kit)
│   └── ...                 ← Your tests
└── ...
```

---

## Development Guidelines

### The Pipeline

```
SPECS.md  →  agent/design/  →  PLANS.md  →  TASKS.md  →  RELEASES.md
 Define       Design            Architect     Build         Release
```

| Step | File | What it does |
|------|------|-------------|
| **Define** | `SPECS.md` | What to build — features, requirements, acceptance criteria |
| **Design** | `agent/design/f{N}.md` | How to build each feature — approach, decisions, edge cases, scope exclusions |
| **Architect** | `PLANS.md` | Project-wide architecture — stack, data model, ADL index (links back to design files) |
| **Build** | `TASKS.md` | Execute — track work, assign owners, mark done |
| **Release** | `RELEASES.md` | Record what shipped — version, changes, test results |

Every decision traceable backwards: Release → Task → Design → Feature → Requirement.

Enter at any point. Start from specs, start from code, or start mid-project — the agent fills whatever's missing.

### Which Agent File Updates When

| File | Updates When |
|------|-------------|
| `agent/AGENT.md` | Stack changes, new project rules, config changes (port, API provider, brand) |
| `agent/AGENT_CONTEXT.md` | After significant work, after committing, before any push |
| `agent/SPECS.md` | New feature added, scope change (DROP/ADD/MODIFY/REPLACE), feature marked done (fill Tests column) |
| `agent/PLANS.md` | Architecture changes — new tech chosen, data model updated, API endpoints added/modified. ADL updated when feature plans record decisions |
| `agent/design/f{N}.md` | Auto-created when feature added to SPECS.md. Filled during design. Marked "Done" when feature complete |
| `agent/TASKS.md` | Before every task (add it first), after every task (mark [x] when done) |
| `agent/RELEASES.md` | When all tasks under a version heading are [x] — entry added immediately, same session |

### Spec Kit Orchestration

Everything the agent does — automatically or on command. All natural language, no slash commands needed.

| Category | Command | What happens | Trigger |
|----------|---------|-------------|---------|
| | | **Setup & Context** | |
| **Project Setup** | `"init"` | Deep scan → create/fill all agent/ files → optional changes checklist | Explicit |
| | `"reinit"` | Re-scan → sync stale agent files → SPECS/PLANS staleness check | Explicit |
| **Config** | `"show config"` / `"config"` | Show all toggles + interactive toggle by number or name | Explicit |
| | `"enable [name]"` / `"disable [name]"` | Quick toggle any setting: ci, jira, code review, scope check | Explicit |
| **Help** | `"help"` / `"what can I do?"` | Contextual help based on current project state | Explicit |
| | `"how do I [action]?"` | Step-by-step walkthrough of any process | Explicit |
| | `"tour"` | Re-run the onboarding tour as a refresher | Explicit |
| | *(auto)* First session | 4-step interactive onboarding tour | Auto (once) |
| | *(auto)* Every session start | Session greeting: name + project + pending tasks | Auto |
| | *(auto)* At milestones | Brief acknowledgment + next step suggestion | Auto |
| | | **Define & Design** | |
| **Development** | `"build X"` / `"add feature X"` | Added to TASKS.md → built → tested → marked done | Explicit |
| | `"fix X"` | Added to TASKS.md → fixed → marked done | Explicit |
| | `"what's the status?"` | Reads TASKS.md + AGENT_CONTEXT.md → full progress report | Explicit |
| | `"keep noted"` / `"note this"` | Saved to correct agent/ file — never lost | Explicit |
| **Feature Design** | `"plan F3"` / `"design F3"` | Creates/opens `agent/design/f3-name.md` — fills from conversation | Explicit |
| | *(auto)* Feature added to SPECS.md | Design stub auto-created in `agent/design/f{N}-name.md` | Auto |
| | `"implement F3"` / `"start F3"` | **Gate:** checks design exists → if not, creates + fills first → then builds | Explicit + Gate |
| **Test Generation** | *(auto)* Acceptance criteria written | Test stubs generated from SPECS.md criteria (stack-aware) | Auto |
| | | **Continuous (always running)** | |
| **Task Tracking** | *(auto)* Every user message | No-slip rule: scan for tasks, add to TASKS.md, never let anything slip | Continuous |
| **Time Tracking** | *(auto)* Every agent response | Track A (session time) updated per-response in AGENT_CONTEXT.md | Continuous |
| **Context Updates** | *(auto)* After significant work | AGENT_CONTEXT.md updated: version, phase, what's done, what's next | Auto |
| **Spec Staleness** | *(auto)* On detection | If TASKS.md [x] count > SPECS.md features → update SPECS.md | Auto |
| **ADL Sync** | *(auto)* Design decisions made | Decisions from agent/design/ auto-flow to PLANS.md ADL with Plan Ref | Auto |
| **Rename Check** | *(auto)* During rename/refactor | `grep -r` entire repo for old term → every instance updated | Auto |
| | | **Quality Gates** | |
| **Code Review** | *(auto)* Feature completed | Two-layer review (script + AI) before marking [x] — advisory | Auto |
| | `"review code"` / `"code review"` | Run review manually on current state | Explicit |
| **Scope Check** | *(auto)* Session start | Quick drift check (feature drift + plan staleness) | Auto |
| | `"check scope"` / `"scope check"` | Full 5-dimension drift check on demand | Explicit |
| | | **Progress & Team** | |
| **Dashboard** | `"progress"` / `"dashboard"` / `"burndown"` | Progress dashboard: overall · by version · current tasks · blockers | Explicit |
| **Team Tasks** | `"my tasks"` / `"what do I have"` | Per-user task view filtered by @username | Explicit |
| | `"assign [task] to @username"` | Adds @username tag to task in TASKS.md | Explicit |
| | `"unassign @username from [task]"` | Removes @username tag from task | Explicit |
| | | **Release Pipeline** | |
| **Testing** | `"run tests"` | Run all suites → show failure summary + fix plan. No commits. | Explicit |
| **Release** | `"prepare release"` | 9-step pipeline: tests → code review → scope check → flows → counts → version bump → PDFs → RELEASES → CHANGELOG. **No commit. No push.** | Explicit |
| | `"refresh release"` | Same as prepare release — **no version bump** | Explicit |
| | `"prepare release and push"` | Full pipeline → commit → push → GitHub release. One command. | Explicit |
| | `"refresh release and push"` | Same as above but no version bump | Explicit |
| **Git** | `"commit"` | Stage + commit with descriptive message + `Co-Authored-By` | Explicit |
| | `"push"` | Pre-push gate (runs tests if changes since last release) → push | Explicit |
| | | **Jira Integration (optional)** — Jira Cloud integration via REST API v3 | |
| **Jira Sync** | `"sync to jira"` | Full 8-step sync: hours confirmation → push to Jira Cloud | Explicit |
| | `"jira status"` | Show tasks pending sync + hours (no API calls, read-only) | Explicit |
| | `"jira setup"` | Test connection, map issue types, configure mappings | Explicit |
| | `"link jira PROJ-123"` | Tag active task with Jira ticket ID | Explicit |
| | `"unlink jira from [task]"` | Remove Jira ticket tag from task | Explicit |
| **Time Tracking** | `"install tracker"` | Install psk-tracker OS daemon + register project | Explicit |
| | `"uninstall tracker"` | Stop daemon, remove OS service (logs preserved) | Explicit |
| | `"tracker status"` | Show daemon running/stopped, last event, today's minutes | Explicit |
| | `"start working on [task]"` | Explicit task-start marker — improves time attribution | Explicit |
| | `"hours summary"` | Show Track A + Track B breakdown for current session | Explicit |

**Every `prepare release` / `refresh release` ends with this summary:**
```
══════════════════════════════════════════════
  RELEASE SUMMARY — v0.N.x
══════════════════════════════════════════════
  1. Tests        Framework: X passed ✅  Benchmarking: X passed ✅
                  R→F→T: X/X features release-ready ✅
                  Total: X/X passing ✅
  2. Code Review  X passed, Y issues (advisory) ✅/⚠
  3. Scope Check  drift score: N ✅/⚠
  4. Flows        docs/work-flows/ current ✅
  5. Counts       README, ARD, RELEASES, CHANGELOG ✅
  6. Version      v0.N.x-1 → v0.N.x ✅           (prepare/update only)
                  unchanged — v0.N.x —             (refresh only)
  7. PDFs         all ard/*.pdf regenerated ✅
  8. RELEASES.md  updated ✅
  9. CHANGELOG.md updated ✅
  10. GitHub      ⏳ pending — run: commit and push   (prepare release)
                  published ✅                        (prepare release and push)
  11. Tag         ⏳ pending — run: commit and push   (prepare release)
                  updated ✅                          (prepare release and push)
══════════════════════════════════════════════
```
The release is only finalized if all test suites pass. Any failure → show failure summary + fix plan → fix → re-run.

### Key Principles

| Principle | What it means |
|-----------|--------------|
| **Never blocks** | Start coding immediately — specs can be written before, during, or filled retroactively |
| **Context never lost** | `AGENT_CONTEXT.md` tracks what's done, what's next, and every decision. Come back after weeks and pick up instantly |
| **Tasks first** | Every task gets added to TASKS.md before work starts — nothing slips |
| **Self-validating** | Agent writes tests, runs them, fixes failures before presenting results. You should never discover a broken feature |
| **90/10 split** | Agent does 90% — specs, plans, tasks, tests, docs. You review and approve |
| **One file, all projects** | `portable-spec-kit.md` carries your standards across every project. Project-specific rules go in `agent/AGENT.md` |

### File Management Rule

| Scenario | Action |
|----------|--------|
| Agent file doesn't exist | Created from template, known details filled in |
| Agent file exists but wrong structure | Restructured to match template — **all content preserved** |
| Agent file matches template | Left as-is |

Content is never lost. Existing files are reorganized, not overwritten.

---

## What's Inside portable-spec-kit.md

| Section | What It Governs |
|---------|----------------|
| **Reliability Architecture** | 3-layer enforcement: Layer 2A bash critic (12 checks), Layer 2B sub-agent critic (verbatim-quote gate), Layer 3 hooks (PostToolUse warn, PreCommit BLOCK). Dual gate at end of all 6 executable workflows. Error codes PSK001–PSK011. |
| **Skill-Based Architecture** | Core brain (behavioral rules, always loaded) + 17 skill files loaded JIT on demand. Core file under 1000 lines. |
| **User Profile** | Personalized AI — GitHub auto-detect, communication style, working pattern, AI delegation |
| **Project Config** | `.portable-spec-kit/config.md` — CI/CD, Jira, code review, scope drift toggles. Disabled-by-default CI. Review anytime. |
| **Git & GitHub** | Commit rules, push rules, critical ops requiring approval |
| **Security** | .env handling, secret management, PSK011 secret scanning blocks commits with 12 credential patterns (AWS, GitHub PAT, Anthropic, Google, Slack, Stripe, private keys) |
| **Versioning** | Two-level: framework patches + release milestones, auto-restructure on pull |
| **Task Tracking** | Tasks-first workflow, version-based organization (v0.x headings + backlog) |
| **Feature Planning** | Every feature gets a plan (`agent/design/f{N}.md`), 3 triggers (explicit/auto/gate), decisions auto-flow to ADL, R→F→Plan→ADR→T traceability |
| **Auto Code Review** | Two-layer review (psk-code-review.sh + AI judgment) after feature completion — security, naming, TODO, secrets, architecture compliance; advisory not blocking |
| **Scope Drift Detection** | 5 dimensions (feature drift, requirement gaps, scope creep, architecture drift, plan staleness), drift score, proactive at session start |
| **Testing** | Coverage targets, edge case checklist, mock rules, self-validation |
| **Spec-Based Test Generation** | SPECS origin detection (forward vs retroactive), per-feature acceptance criteria, stub generation, stack-aware formats, stub completion gate |
| **Code Quality** | Review checklist, naming conventions, deployment checklist |
| **Error Handling** | Structured errors, logging, error boundaries, user-friendly messages |
| **Branch & PR** | Feature branches, PR format, squash merge, clean history |
| **CI & Community Contributions** | CI badge rule, branch protection guidance, PR workflow, contribution validation, ci.yml template with stack-aware commands (Jest/pytest/Go/Bash) |
| **Python Environment** | Conda env per project (respects existing venv), environment selection flow, pyproject.toml/environment.yml support, 9 edge cases |
| **Dependencies** | Bundle size checks, lock files, audit, avoid unnecessary deps |
| **Project Templates** | 9 agent files + README + 8 source code structures (Web, Python, Mobile, Android, iOS, Full Stack, Full Stack + Mobile, Document) + 4 stack-aware CI templates |
| **Auto-Scan** | Detects projects, creates/restructures files, preserves existing content |
| **Self-Help + Onboarding** | Guided tour on first install, contextual help on `"help"`, step-by-step walkthroughs, session greetings, milestone acknowledgments, proactive nudges — all dynamic, version-resilient |
| **Agent Behavior** | Guide don't enforce, silent tracking, retroactive spec-filling |

---

## Customization

### User Profile — Personalized AI Experience

On first session, the agent creates your profile by fetching your GitHub identity and asking 3 quick questions. Press Enter to use recommended, or type your own:

```
Agent: "Welcome, Jane Smith! Let me set up your development profile."

Communication style?
  (a) direct and concise ← RECOMMENDED
  (b) direct, data-driven, comprehensive with tables and evidence
  (c) conversational and collaborative
  (or type your own)
  Press Enter to use recommended (a)

Working pattern?
  (a) iterative — starts brief, expands scope, builds ambitiously ← RECOMMENDED
  (b) plan-first — full specs and architecture before writing code
  (c) prototype-fast — get something working, then refine
  (or type your own)
  Press Enter to use recommended (a)

AI delegation?
  (a) AI does 70%, user guides 30% ← RECOMMENDED
  (b) AI does 90%, user reviews 10%
  (c) 50/50 collaboration
  (or type your own)
  Press Enter to use recommended (a)

Your profile:
┌─────────────────────────────────────┐
│ Jane Smith — B.S. CS. Full-stack.   │
│ Communication: direct and concise   │
│ Working pattern: iterative          │
│ AI delegation: AI does 70%          │
└─────────────────────────────────────┘
Looks good? (Enter = yes, or type changes)
```

**Saved to:**
- `~/.portable-spec-kit/user-profile/user-profile-janesmith.md` (global — asked once)
- `workspace/.portable-spec-kit/user-profile/user-profile-janesmith.md` (committed — persists across pulls)

**On new projects:** profile is shown, keep or customize per project. Customized profiles save to workspace only.

| What You Set | How the Agent Adapts |
|---|---|
| **Your expertise** (e.g., "PhD in AI" vs "first-time coder") | Adjusts technical depth, skips/explains concepts |
| **Communication style** | Uses tables & evidence vs. conversational |
| **Working pattern** | Adapts planning granularity |
| **AI delegation** | Controls autonomy vs. asking for approval |

Skip all questions? Press Enter through everything — recommended defaults applied.

### For Your Projects

Project-specific details go in `agent/AGENT.md` (auto-created per project):

```markdown
## Stack
| Layer | Technology |
|-------|-----------|
| Frontend | Next.js + TypeScript |
| Backend | FastAPI |

## Brand
- Primary: #1B2A4A
- Accent: #4a6fa5
```

---

## Syncing Across Projects

### Pull Latest

```bash
# In any project
curl -sO https://raw.githubusercontent.com/aqibmumtaz/portable-spec-kit/main/portable-spec-kit.md
```

### Push Updates Back

When you improve portable-spec-kit.md from any project:

```bash
# Copy to your fork
cp portable-spec-kit.md ~/portable-spec-kit/
cd ~/portable-spec-kit
git add . && git commit -m "Add new testing rule" && git push
```

### For Teams

Fork this repo → customize portable-spec-kit.md for your team → everyone pulls from your fork.

---

## Usage Examples

### New Project Setup

```
You: "Create a new project called my-app"

Agent:
✓ Created my-app/agent/ with 9 files (6-stage pipeline + 3 support)
✓ Created my-app/README.md
✓ Created my-app/.gitignore + .env.example
✓ Created directories: src/, tests/, ard/, docs/

What would you like to build?
```

### Resuming After Weeks

```
You: "Let's continue working on my-app"

Agent: (reads agent/AGENT_CONTEXT.md)
Here's where we left off:
- v0.2 in progress — 3 of 8 tasks complete
- Last session: built auth system, 45 tests passing
- Next: payment integration (blocked on Stripe key)
- Decision pending: PostgreSQL vs MongoDB

Want to continue with payment integration?
```

### Spec-Persistent Flow (When Asked)

```
You: "How should I approach this project?"

Agent:
Let's follow the spec-persistent process (6-stage pipeline):

1. REQS.md — WHY (business requirements in client language)
   → What problem does this solve? Who's the user?

2. SPECS.md — WHAT (features mapped from requirements, R→F)
   → Acceptance criteria, Tests column, scope boundaries

3. PLANS.md — HOW (architecture, stack, ADL)
   → Data model, tech choices, decision log with Plan Ref

4. DESIGN.md — per-feature design plans in agent/design/f{N}.md
   → 12-section plan template, decisions auto-flow to PLANS ADL

5. TASKS.md — breakdown with checkboxes, version-grouped
   → Organized under v0.1 / v0.2 / Backlog

6. RELEASES.md — end-of-version summary + R→F→T traceability

Throughout: AGENT_CONTEXT.md tracks living state, RESEARCH.md
investigations feed decisions, dual-gate validates each workflow.

Let's start — what's the core problem this project solves?
```

---

## Contributing

Contributions welcome! This framework improves through real-world usage.

1. Fork the repo
2. Customize portable-spec-kit.md for your workflow
3. Submit a PR with improvements that benefit everyone

**What makes a good contribution:**
- New testing patterns or edge case checklists
- Better project templates
- Agent behavior improvements
- Documentation fixes

---

## Example Projects

### [`examples/starter/`](examples/starter/) — Fresh Project (Start Here)

What your project looks like right after setup. The README explains every file, every directory, and why it exists. **Read this first** to understand how the framework works.

```
examples/starter/
├── portable-spec-kit.md    ← Framework file (source)
├── .portable-spec-kit/     ← Kit config (user profiles)
│   └── user-profile/
├── CLAUDE.md               ← Symlink (Claude Code)
├── .cursorrules            ← Symlink (Cursor)
├── WORKSPACE_CONTEXT.md    ← Auto-created workspace state
├── README.md               ← Self-documenting — explains the entire structure
├── agent/
│   ├── AGENT.md           ← Stack: TBD (waiting for your specs)
│   ├── AGENT_CONTEXT.md   ← Status: "Setup — waiting for specs"
│   ├── SPECS.md           ← Empty template — ready for your requirements
│   ├── PLANS.md        ← Empty template — ready for architecture
│   ├── TASKS.md           ← 1/5 tasks done (project initialized)
│   └── RELEASES.md         ← v0.1 placeholder
```

### [`examples/my-app/`](examples/my-app/) — Mid-Development Project

A realistic Next.js + Supabase project with 11/16 tasks complete. Shows what the framework looks like when you're actively building — filled specs, architecture plan, module-based tasks.

```
examples/my-app/
├── portable-spec-kit.md    ← Framework file (source)
├── .portable-spec-kit/     ← Kit config (user profiles)
│   └── user-profile/
│       └── user-profile-alexchen.md
├── WORKSPACE_CONTEXT.md    ← Workspace state
├── agent/
│   ├── AGENT.md           ← Next.js + Supabase + Vercel configured
│   ├── AGENT_CONTEXT.md   ← v0.1 with 11/16 tasks, 24 tests at 92%
│   ├── SPECS.md           ← 8 features with priorities + acceptance criteria
│   ├── PLANS.md        ← Data model, API endpoints, 3 build phases
│   ├── TASKS.md           ← 5 modules, progress summary table
│   └── RELEASES.md         ← v0.1 changelog with categorized changes
```

---

## Flows

Detailed step-by-step diagrams for every work flow:

| # | Flow | When It Triggers |
|---|------|-----------------|
| 01 | **[First Session in New Workspace](docs/work-flows/01-first-session-workspace.md)** | First time in a workspace — environment detection, auto-scan |
| 02 | **[User Profile Setup](docs/work-flows/02-user-profile-setup.md)** | First time using the kit — GitHub fetch + 3 questions |
| 03 | **[New Project Setup](docs/work-flows/03-new-project-setup.md)** | Creating a new project — profile shown, scaffold created |
| 04 | **[Existing Project Setup](docs/work-flows/04-existing-project-setup.md)** | First-time kit onboarding on a codebase that already exists |
| 05 | **[Project Init & Reinit](docs/work-flows/05-project-init.md)** | `init` / `reinit` commands — explicit scan, agent file sync, staleness check |
| 06 | **[CI/CD Setup](docs/work-flows/06-cicd-setup.md)** | ci.yml generation — stack detection, badge, branch protection |
| 07 | **[Returning Session](docs/work-flows/07-returning-session.md)** | Coming back after days/weeks — context loaded, no questions |
| 08 | **[Agent Switching](docs/work-flows/08-agent-switching.md)** | Switching Claude → Cursor → Copilot — zero data loss |
| 09 | **[Profile Customization](docs/work-flows/09-profile-customization.md)** | Different preferences per project — local override |
| 10 | **[File Management](docs/work-flows/10-file-management.md)** | Create/update/restructure rule — never lose content |
| 11 | **[Spec-Persistent Development](docs/work-flows/11-spec-persistent-development.md)** | SPECS → PLAN → TASKS → TRACK — living specs, any workflow |
| 12 | **[Project Lifecycle](docs/work-flows/12-project-lifecycle.md)** | Full lifecycle — client requirements through handoff |
| 13 | **[Release Workflow](docs/work-flows/13-release-workflow.md)** | prepare release — tests, flow docs, counts, version bump, PDFs, RELEASES.md, CHANGELOG.md + summary (no commit/push) |
| 14 | **[Team Collaboration](docs/work-flows/14-team-collaboration.md)** | Multi-agent task tracking, progress dashboard, @username ownership |
| 15 | **[Jira Integration](docs/work-flows/15-jira-integration.md)** | 8-step sync flow — credentials, hours reconciliation, hierarchy creation, confirmation UI |
| 16 | **[Feature Design](docs/work-flows/16-feature-design.md)** | Per-feature design plans, 3 triggers, ADL integration, R→F→Plan→ADR→T traceability |
| 17 | **[Reflex](docs/work-flows/17-reflex.md)** | Post-prep-release Actor-Critic loop — QA-Agent (black-box) finds gaps, Dev-Agent fixes atomically with per-commit gates; installable into any speckit project |
| 18 | **[Project Orchestration](docs/work-flows/18-project-orchestration.md)** | Natural-language entry point — turns loose requirements into a polished, secure, audited working product via 10 phases (capture → research → expand REQS → SPECS+PLANS → UI design system → secure scaffold → feature impl → release-prep → reflex audit → handoff) |

---

## Documentation

- **[Quick Guide (PDF)](ard/Portable_Spec_Kit_Guide.pdf)** — Visual overview of the framework
- **[Technical Overview (PDF)](ard/Portable_Spec_Kit_Technical_Overview.pdf)** — Architecture reference document
- **[Work Flows](docs/work-flows/)** — 16 step-by-step flow diagrams
- **SPD Concept Paper** — Methodology paper with evaluation *(coming soon)*
- **[Benchmarking Report](tests/spd-benchmarking-report.md)** — 5 projects × 3 methodologies compared
- **[Starter Example](examples/starter/)** — Fresh project with self-documenting README
- **[My App Example](examples/my-app/)** — Mid-development project
- **[portable-spec-kit.md](portable-spec-kit.md)** — The complete framework file

---

## License

MIT License — use it, fork it, customize it, share it.

---

## Author

**Dr. Aqib Mumtaz, Ph.D.**
Specialization: Computer Science — Artificial Intelligence
Research: Multimodal AI, Healthcare AI, Autonomous Surveillance

- [LinkedIn](https://linkedin.com/in/aqibmumtaz)
- [GitHub](https://github.com/aqibmumtaz)
- [Google Scholar](https://scholar.google.com/citations?user=zL4pvBgAAAAJ)

---

<p align="center">
  <strong>Portable Spec Kit — One file. Any project. Your standards. Personalized.</strong><br>
  <em>Spec-Persistent Development — specs always exist, always current, never block</em>
</p>
