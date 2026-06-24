# No-Silent-Wait & Centralized Progress — Flow Doc 34 (v0.6.93+)

> **Purpose:** Document the no-silent-wait system — every long blocking kit operation
> (full test suite, `sync-check --full`, the reflex gate set, a multi-minute build, the
> release ceremony) surfaces progress, so *running-slow* is never indistinguishable from
> *hung*. Two layers: a generic heartbeat **monitor** (`psk-progress.sh`) that writes a
> live-progress file readable any time, and a centralized **chunked-drive** driver
> (`psk-chunked-run.sh`) that lets the agent run a long op as a series of short background
> tasks so each chunk-completion becomes a chat message. Chat messages are the universal
> progress surface — the statusLine bar is a CLI-terminal-only complement.

## Overview

| Field | Value |
|---|---|
| Heartbeat monitor | `agent/scripts/psk-progress.sh` — runs a command, mirrors a heartbeat to stderr AND a live file every N seconds (default 30s) |
| Self-wrap | `agent/scripts/psk-progress-selfwrap.sh` — the ONE shared helper a long-op script sources to wire itself to the monitor (no per-script copy-paste) |
| Centralized chunk driver | `agent/scripts/psk-chunked-run.sh` — position tracker + chunk enumerator; the agent drives each chunk as a background task → a message per chunk |
| Framework rule | `portable-spec-kit.md` §No-Silent-Wait |
| Structural enforcement | sync-check rule **PSK047** — the monitor + self-wrap + chunk driver must be present+executable, and every `# long-op:` script must wire the monitor; sync-check rule **PSK048** — the chunked-suite pre-verify protocol (gate present + release step-1 routed through it + reflex Phase-1 chunk-driven) must stay wired |
| Tests pre-verify gate | `agent/scripts/psk-tests-gate.sh` (KIT-GAP-0123) — decouples the long suite from the opaque release step-1-tests. The agent drives the suite CHUNKED first (per-section chat progress); each test process writes a real exit-0 STAMP; on all-green the gate SEALS a fail-closed marker keyed to a full tree fingerprint (HEAD + working tree); release `step-1-tests` routes through `psk-tests-gate.sh run`, which SKIPS the inline re-run only when the marker proves the current tree. Any code/test change, dirty tree, missing/failed unit, or non-git → no skip → tests run. Marker + stamps gitignored. |
| Live file | `$PSK_PROGRESS_DIR/<label>.live` (default `/tmp/psk-progress-<uid>/` — TMPDIR-independent so writer + statusLine reader resolve the same dir) |
| Read paths | `psk-progress.sh --status [label]` (latest heartbeat) · `--statusline` (`run:` readout for the active op) · `tail -f` the live file |
| Chunk suites (`--suite`) | `test-spec-kit` (one chunk per section + one for all feature files) · `test-spd-benchmarking` · `all-tests` (full Test Execution Flow) · `prepare-release` / `refresh-release` (one chunk per release phase); else `--chunks 'a|||b|||c'` |
| Canonical render | `psk-chunked-run.sh status --table` → the one aligned box `\| Chunk \| Stage \| Unit \| Result \|` progress table (single-width markers `✓` done · `►` running · `·` queued), relayed verbatim each chunk turn |
| Bypass / tune | `PSK_PROGRESS_DISABLED=1` · `PSK_PROGRESS_INTERVAL` · `PSK_PROGRESS_STATUSLINE_WINDOW` · `PSK_PSK047_DISABLED=1` |
| Driving history | KIT-GAP-0105 (live file survives redirection) · 0109 (statusLine surface) · 0110 (TMPDIR-independent dir) · 0111 (instant live-file write) · 0112 (no mid-run auto-stream — chat is turn-based) · 0113 (chunked-drive) · 0114 (chunk the whole suite — sections AND feature files) · 0118 (real phase names) · 0119 (in-table live sub-progress) · 0120 (aligned box table) · 0122 (Stage column) · 0123 (chunked-suite pre-verify gate — `psk-tests-gate.sh` + PSK048, decouples release step-1 + reflex Phase-1) · 0124 (section-109 gate-state isolation) |
| Related layers | §Session Health Indicator (companion `ctx:` badge, flow doc 33) · §Verification Fidelity |

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ A long op starts (suite / gate / build / release phase)     │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────▼──────────────────────────────┐
│ HEARTBEAT  psk-progress.sh                                  │
│   live file + --status + --statusline (CLI bar)             │
│   instant write, heartbeat every 30s                        │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────▼──────────────────────────────┐
│ CHUNKED-DRIVE  psk-chunked-run.sh  (the default)            │
│   agent runs each chunk as a background task                │
│   each completion = a chat turn = a message                 │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────▼──────────────────────────────┐
│ routing:                                                    │
│   indivisible op  -> one bg task + --status per turn        │
│   sub-units (default) -> plan --suite -> next -> run        │
│                       -> (on completion) result + next      │
└──────────────────────────────┬──────────────────────────────┘
┌──────────────────────────────▼──────────────────────────────┐
│ progress reaches the CHAT (universal surface)               │
│   chunked: one message per chunk (status --table)           │
│   heartbeat: --status relayed each turn                     │
│   statusLine (ctx . opt . run) = CLI-only bonus             │
└─────────────────────────────────────────────────────────────┘
```

## Key Rules

1. **Chat messages are the universal surface.** The statusLine (`ctx · opt · run`) renders
   only in the Claude Code CLI terminal — the VS Code extension / app UI does not render it.
   So the agent surfaces long-op progress as chat MESSAGES, by default, via chunked-drive.
   The statusLine is a best-effort complement, not the guarantee.
2. **Chunked-drive is the default for every long op with sub-units.** A test suite, the
   release ceremony, a multi-step build — the agent drives it through `psk-chunked-run.sh`
   so each chunk-completion is a chat turn. Not opt-in, never asking per-run. The ONLY
   exception is a genuinely indivisible op (one background task + `--status` relayed each
   turn). Ops with a native phase/pass tracker (release phases, a reflex pass) emit a
   message per unit and need no separate chunk plan.
3. **One centralized driver.** `psk-chunked-run.sh` is the single chunk tracker + render
   source. To make a NEW long op chunked-by-default, add a case to `_derive_suite_chunks` —
   nothing else changes. A suite derivation MUST cover the WHOLE suite (e.g. `test-spec-kit`
   chunks sections AND feature files — a sections-only derivation silently under-runs the
   suite, the KIT-GAP-0114 root cause).
4. **The script enumerates; the agent emits.** A bash script cannot print to the chat or
   re-invoke the agent. So `psk-chunked-run.sh` tracks chunks + emits the canonical table;
   the message emission is agent behavior governed by the §No-Silent-Wait rule. The chunk
   command is opaque text the script never executes — the agent runs it as a background task.
5. **Canonical render — `status --table`.** Progress is rendered by relaying
   `psk-chunked-run.sh status --table` verbatim, so the format never drifts and the agent
   never hand-builds a table. Markers: `✓` done · `⏳` running · `· queued`.
6. **The chat cannot live-stream a background op (KIT-GAP-0112).** The chat is turn-based —
   the agent prints only on a turn (a user message or a task-COMPLETION notification). A
   `ScheduleWakeup` does NOT fire while a background task keeps the session busy. So the only
   live surfaces DURING a single background op are the statusLine (CLI only) and `tail -f`
   the live file; chunked-drive is what turns progress into actual chat messages.
7. **TMPDIR-independent live file (KIT-GAP-0110) + instant write (KIT-GAP-0111).** The live
   file lives at a fixed `/tmp/psk-progress-<uid>/` path (not `$TMPDIR`-derived) so the
   op-writer and the statusLine reader always resolve the same dir, and it is written the
   instant the op starts (not after the first heartbeat interval).
8. **Structural enforcement (PSK047).** The monitor + self-wrap + chunk driver must be
   present+executable, and every `# long-op:` script must wire the monitor. A new blocking
   bash op that can exceed ~15s is a No-Silent-Wait violation until it carries `# long-op:`
   + a self-wrap AND is reachable by chunked-drive. See the §No-Silent-Wait coverage map.

## Manual Probes

```bash
# Heartbeat monitor
bash agent/scripts/psk-progress.sh --status            # latest heartbeat (any redirection)
bash agent/scripts/psk-progress.sh --statusline        # "run: <label> · <elapsed> · <count>" (active op)
tail -f /tmp/psk-progress-$(id -u)/<label>.live        # continuous live view (terminal)

# Centralized chunk driver
bash agent/scripts/psk-chunked-run.sh plan --label demo --suite all-tests   # enumerate chunks
bash agent/scripts/psk-chunked-run.sh next --label demo                     # -> "CHUNK k/N: <cmd>"
bash agent/scripts/psk-chunked-run.sh status --table --label demo           # canonical progress table
bash agent/scripts/psk-chunked-run.sh reset --label demo

# Enforcement
bash agent/scripts/psk-sync-check.sh --full | grep PSK047                   # monitor + driver wiring intact
```
