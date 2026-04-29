# Skill: Optimize — Token-Bloat Sweep

**Trigger:** user says `/optimize` · `optimize tokens` · `psk optimize` · `token sweep` · `clean up bloat` · `optimize the kit`.

**Purpose:** safe, reversible token-optimization sweep that detects accumulated bloat in framework + agent files and removes it without losing rules or functionality. Built on the kit's existing test gates as the safety net.

---

## Safety contract — non-negotiable

The agent MUST follow this protocol on every prune run. **No cut lands unless every gate passes.**

1. **Pre-flight snapshot.** Before any cut:
   - Run `bash agent/scripts/psk-optimize.sh --safety-check`. Suite must be green.
   - Record current HEAD: `git rev-parse HEAD` (revert anchor).
   - Count `MANDATORY` + `MUST` mentions in `portable-spec-kit.md`. This count CANNOT decrease without explicit user approval.

2. **Per-cut atomic commit.** Every proposed cut becomes exactly one git commit:
   - One file's bloat → one commit.
   - Commit message format: `chore(prune): <category> in <file> — <one-line summary>`.
   - Never bundle cuts across multiple files in one commit.

3. **Per-cut gate verification.** After each cut, run the full gate suite:
   - `bash tests/test-spec-kit.sh` (kit-side) OR project's equivalent test runner.
   - `bash tests/test-release-check.sh` if present (R→F→T preservation).
   - `bash agent/scripts/psk-sync-check.sh --full` if present.
   - **If any gate fails:** `git reset --hard HEAD~1`, mark the candidate `[~]` skipped, move on. Do not continue trying.

4. **MANDATORY-line preservation.** After each cut:
   - Re-count `MANDATORY` + `MUST` in framework files.
   - New count must be ≥ pre-flight count.
   - If count dropped → cut violated rule preservation → revert immediately.

5. **No auto-apply.** The agent walks each candidate one at a time and asks the user before applying. Never apply all candidates in one batch without confirmation.

6. **Resume-safe.** If the prune sweep is interrupted, the kit's git history shows exactly which cuts landed. Re-running the sweep skips already-cleaned candidates.

---

## Workflow (each invocation)

1. **Detect bloat candidates** — run `bash agent/scripts/psk-optimize.sh --scan`. Output: punch list grouped by category (duplicate version blocks, stale numeric badges, superseded-ADR rationale bloat).

2. **Pre-flight gate check** — run `bash agent/scripts/psk-optimize.sh --safety-check`. If gate suite is red, stop and tell the user to fix the failing tests first; do not start a prune sweep on a broken baseline.

3. **Walk candidates one at a time:**
   - Show the candidate with file path + line numbers + before/after preview.
   - Ask user: `Apply this cut? (y/n/skip)`.
   - On `y`: apply the cut → run gate suite → if green, commit; if red, revert + log + move on.
   - On `n` or `skip`: log the candidate as deferred and move on.

4. **Final report** — summarize: candidates found, candidates applied, candidates skipped (with reasons), token reduction (lines/chars), commits created, gate suite final status.

---

## Categories the script flags (and how to handle each)

The script detects **9 categories** of bloat across 4 surfaces:

| Surface | Categories | Risk profile |
|---|---|---|
| **Documentation bloat** (CHANGELOG / RELEASES / PLANS / ADL) | 1, 2, 3 | low — text-only, gate-verified |
| **Project hygiene** (markdown links, env vars, oversized sections) | 4, 5, 6 | low-medium — semantic care needed for some cuts |
| **Reflex token cost** (per-pass prompts, retention violations) | 7, 8 | low — diagnostic + cleanup, no rule changes |
| **Rule duplication** (stub sections — single-line skill-link with no body) | 9 | medium — requires judgment per stub (legacy vs load-bearing context anchor) |

### Category 1 — Duplicate version-iteration entries

**Pattern:** multiple `### vX.Y.Z — Title (Date)` headers for the same version inside one CHANGELOG/RELEASES file. Usually an artifact of writing the same release across iterations (v1 narrative, then v2 narrative, then v3 narrative — never collapsed).

**Cut strategy:** keep the most recent / final entry, delete earlier iteration narratives. Preserve any unique factual content from earlier blocks (commit SHAs, test counts, dates) by merging into the kept block.

**Verification:** the kept block must still describe what shipped in that version. No release-history loss.

### Category 2 — Stale numeric badges

**Pattern:** test counts, section counts, feature counts that drift from the actual test runner output.

**Cut strategy:** the kit's existing `count sync` tests in `tests/sections/01-infrastructure.sh` already enforce this — if numbers drift, those tests fail. The prune script just surfaces the drift early. **Fix the badges, do not remove them.**

**Verification:** `bash tests/test-spec-kit.sh` must pass after the update.

### Category 3 — Superseded-ADR rationale bloat

**Pattern:** an ADR row in `agent/PLANS.md` is marked `(superseded by ADR-N)` but still carries the full options-considered + why narrative. Once superseded, only the supersedence note + 1-line summary need stay; the full rationale lives in the new (superseding) ADR.

**Cut strategy:** trim Options Considered / Chosen / Why columns to one short sentence each. Add or keep `(superseded by ADR-N)` reference. The full rationale remains in the superseding ADR row.

**Verification:** ADR numbering is unbroken; supersedence chain remains traceable. The trimmed row must still allow a reader to find the superseding ADR.

### Category 4 — Stale file references in markdown

**Pattern:** markdown files (PLANS / AGENT / CHANGELOG / RELEASES / framework) link to `.md / .sh / .yml / .yaml / .json / .html` paths that don't exist. Often happens after a rename or a deletion that left dangling references.

**Cut strategy:** open each flagged file → for each broken link: either restore the missing file (if it was deleted by mistake), update the link to the correct path, or remove the link if the referenced doc is genuinely gone. Never silently delete the surrounding paragraph.

**Verification:** re-run `psk-optimize.sh --scan`; cat 4 should show 0 broken links. The file the link was inside still reads coherently.

### Category 5 — Unused env vars in `.env.example`

**Pattern:** vars declared in `.env.example` but never referenced in `src/` / `app/` / `lib/` / `server/`. Detector skips `PSK_*` (kit infra), `NEXT_PUBLIC_*` (Next.js convention often referenced via build-time injection), and lines marked `# RUNTIME:` (explicitly runtime-only).

**Cut strategy:** for each flagged var, decide: (a) was it never wired up? Remove from `.env.example`. (b) Is it used via dynamic lookup or by an external runtime (CI, deployment platform)? Add `# RUNTIME:` comment to suppress the warning.

**Verification:** `.env.example` no longer ships dead vars. Runtime-injected vars carry explicit `# RUNTIME:` markers so future contributors know.

### Category 6 — Oversized framework sections (skill candidates)

**Pattern:** a `##` or `###` section in `portable-spec-kit.md` runs >200 lines under one heading. The kit's design has skill files for exactly this — large sections should be extracted to `.portable-spec-kit/skills/<topic>.md` and loaded on demand.

**Cut strategy:** for each oversized section, decide: (a) is it foundational behavior every session needs? Keep inline. (b) Is it procedural detail loaded only on a trigger? Move to a skill file, leave a one-line `> **Skill: X** — full procedure in skills/X.md` reference in the framework.

**Verification:** every rule in the moved section is still discoverable via the trigger phrase + skill lookup; framework file is shorter; per-session token load drops.

### Category 7 — Reflex prompt bloat (token-cost optimization)

**Pattern:** `reflex/prompts/qa-agent.md` or `reflex/prompts/dev-agent.md` exceeds 500 lines. Every reflex pass loads the full prompt into a fresh sub-agent context — verbose narrative, repeated examples, or accumulated v1/v2/v3 layers cost tokens on every single pass across every project that runs reflex.

**Cut strategy:** treat reflex prompts like the framework file — keep the rules, drop the narrative. Move long examples to a footer or to a separate reference file. Replace v1/v2/v3 evolution stories with the final-form rule + a one-line ADL pointer.

**Verification:** prompt still produces correct QA behavior on a representative pass. Run a single-pass on a known-state project before committing the trim.

### Category 8 — Reflex history retention bloat

**Pattern:** per-pass directories accumulated beyond 2× the `pass_dirs_keep` limit in `reflex/config.yml`, or `REFLEX_EVAL_TRACE.md` register exceeds 100KB.

**Cut strategy:** run `bash reflex/lib/prune-history.sh` to apply the configured retention policy. For oversize register, archive fully-closed cycles to `reflex/history/archive/cycle-NN.md` with a one-line stub remaining in the live register.

**Verification:** disk usage drops; pruned passes still resolvable through `agent/TASKS.md` finding-id lookup; archived cycles still reachable via the stub.

### Category 9 — Cross-file rule duplication (semantic, agent-judged)

**Pattern:** the same rule is paraphrased in `portable-spec-kit.md` and `agent/AGENT.md` (or in the framework file twice). The script doesn't auto-detect this — it requires reading and judgment.

**Cut strategy:** keep the rule in its authoritative location per `portable-spec-kit.md` §Kit-vs-Project Scope Separation. In the duplicate location, replace the full text with a one-line cross-reference (`see portable-spec-kit.md §X`).

**Verification:** every behavioral rule still has exactly one authoritative location. A reader looking for the rule still finds it.

### Category 9 — Rule-duplication via stub-section pattern

**Pattern:** a `### ` heading whose entire body is a single skill-link blockquote (`> **Skill: X** — ... .md`) with no other substantive content. These are usually legacy stubs left during refactoring — when content moved into a canonical section, the original stub got forgotten. Examples caught earlier: §Python Environment (superseded by §Environment Selection), §New Project Setup Procedure (duplicate of §New Project Setup).

**Cut strategy:** for each flagged stub, decide:
- **Legacy stub** (the rule is now better-stated under another section's content) → remove the stub, leave only an HTML comment marker explaining the consolidation
- **Load-bearing context anchor** (the stub provides narrative placement that the skill-table at top can't) → keep the stub but verify it's not duplicating another section's content

**Verification:** after each cut, the skill-table at the top of `portable-spec-kit.md` must still load every used skill via at least one trigger entry. The cut should reduce framework size without losing skill-discoverability.

### Category 10 — Iteration-narrative leakage from ADL into release notes

**Pattern:** CHANGELOG / RELEASES describe the v1 → v2 → v3 evolution of a single rule. That evolution belongs in `agent/PLANS.md` ADL only; release notes should describe the **final** state.

**Cut strategy:** rewrite the CHANGELOG / RELEASES entry to describe what landed (final form), with one sentence acknowledging revisions and a pointer to the ADL.

**Verification:** the entry still tells a future reader what shipped in this version.

---

## What this skill does NOT do

- **Does NOT modify rules.** Cuts only remove bloat; they never weaken or remove a rule. If a cut would change rule semantics, the agent refuses and asks the user to escalate.
- **Does NOT touch test code.** Test files are sacred — pruning them would mask regressions.
- **Does NOT touch source code (e.g. `src/`, `reflex/lib/`).** Code optimization is out of scope; this skill only prunes documentation + framework + agent files.
- **Does NOT run on user projects without confirmation.** End-user projects use this skill on their own `agent/AGENT.md` / `agent/AGENT_CONTEXT.md` — the safety contract is identical, just scoped to those files.

---

## Output format

After each prune run, produce a summary:

```
══════════════════════════════════════════════════════
  PRUNE SWEEP SUMMARY
══════════════════════════════════════════════════════
  Pre-flight HEAD:    abc1234
  Final HEAD:         def5678
  Candidates found:   N
  Candidates applied: M (with K commits)
  Candidates skipped: N-M (reasons listed below)
  Lines removed:      ~X (-Y%)
  Gate suite final:   ✓ all green / ✗ stopped at <gate>
══════════════════════════════════════════════════════
```

Then list each skipped candidate with the reason (gate failure, user declined, semantic risk).

---

## Cadence — when to re-run

| Trigger | Why |
|---|---|
| **After every prep-release** | `psk-release.sh` Step 10 runs `psk-optimize.sh --scan` automatically (advisory). If it flags ≥1 candidate, schedule a sweep before the next release. |
| **Every 5-10 versions** | Iteration narrative accumulates linearly; periodic prune keeps CHANGELOG/RELEASES readable. |
| **After a multi-iteration session** | If a single rule was revised v1 → v2 → v3 in one session, run the sweep next session to collapse the iteration narrative into final form. |
| **When `agent/RELEASES.md` exceeds ~1500 lines** | Ad-hoc trigger. Long release notes hide important content. |
| **Before any wide-audience release** (paper, public docs) | Ensure the docs others read are token-optimized — they're now your portfolio. |

**Disable for a release:** set `PSK_OPTIMIZE_SCAN_DISABLED=1` in the environment before running prep-release. The scan is non-blocking by design; this just suppresses the advisory output.

**Avoid running on a "live" branch under active development** — wait for a quiet moment so gate noise stays low. The scan itself is read-only and safe to run anytime, but actual cuts (via the skill) need a stable baseline.

---

## Feature-preservation guarantee — verified across all categories

The end-goal of the kit is delivered **without losing developed features** because every cut runs through these enforcement points:

| Layer | Mechanism | Catches |
|---|---|---|
| 1 | `--scan` mode (default) is **read-only** — never modifies files | Accidental application |
| 2 | Skill walks candidates **one at a time**, asks user before each cut | Batch application of risky cuts |
| 3 | Each applied cut becomes **one atomic git commit** | Bisectable; revertable in isolation |
| 4 | After each cut, runs the full gate suite: `tests/test-spec-kit.sh` + `tests/test-release-check.sh` (R→F→T) + `psk-sync-check.sh --full` | Regression in framework or feature coverage |
| 5 | If any gate fails → `git reset --hard HEAD~1` automatically + skip candidate + log reason | Silent rule weakening |
| 6 | Pre/post `MANDATORY` + `MUST` line count must not decrease | Mandatory rule loss |
| 7 | `test-release-check.sh` enforces every done feature has a test reference | Untested-feature drift |
| 8 | Re-entrancy guard `PSK_OPTIMIZE_SKIP_TESTRUN=1` for nested invocations | Infinite-loop on nested test runs |

**The end-goal contract:** if you re-run optimization next week, next month, next quarter, the kit will still deliver what it's meant to deliver. The kit's existing reliability infrastructure (sync-check, doc-sync, R→F→T gate, reflex audit) is the safety net underneath every cut. Bloat goes; rules stay.

**What to do if you suspect a cut weakened something:**
1. `git log --oneline | head -20` — find the cut commit (`chore(prune): ...`)
2. `git revert <sha>` — undoes just that cut
3. Re-run `bash tests/test-spec-kit.sh` to confirm gate is green again
4. Open an issue at the kit repo describing the regression so the safety contract can be tightened

Each cut is structurally a single revertable commit, so recovery is one command.
