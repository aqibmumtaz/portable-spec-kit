# Session Health Indicator — Flow Doc 33 (v0.6.90+)

> **Purpose:** Document the context-window health indicator — a 3-level drift signal
> that counters the lost-in-the-middle effect (transformer attention is U-shaped, so a
> session's early rules dilute as the context fills). `agent/scripts/psk-session-monitor.sh`
> measures live context occupancy and maps it to a color badge, surfaced two ways:
> a structural Claude Code `statusLine` (always-on, agent-independent) and an
> agent-mirrored `ctx:` badge in the breadcrumb header.

## Overview

| Field | Value |
|---|---|
| Mechanism | `agent/scripts/psk-session-monitor.sh` |
| Framework rule | `portable-spec-kit.md` §Session Health Indicator |
| Skill | `.portable-spec-kit/skills/hooks-and-critics.md` |
| Two surfaces | (1) structural `statusLine` (`--statusline`), rendered every turn by Claude Code independent of the agent; (2) agent-mirrored `ctx:` badge in the breadcrumb header |
| Data source | most recent assistant turn's `.message.usage` (`input_tokens + cache_creation_input_tokens + cache_read_input_tokens`) in the Claude Code transcript |
| Levels | 🟢 green (`<50%`) · 🟡 yellow (`50–79%`, badge-only) · 🔴 red (`≥80%`, badge + one-time `/clear` banner) |
| Wiring | `psk-install-hooks.sh` installs both surfaces (statusLine + UserPromptSubmit hook); nested-kit installs mirror into the parent workspace settings |
| Bypass | `PSK_SESSION_MONITOR_DISABLED=1` (whole monitor); thresholds via `PSK_SESSION_YELLOW_PCT` / `PSK_SESSION_WARN_PCT` / `PSK_SESSION_URGE_PCT`; window via `PSK_SESSION_CONTEXT_LIMIT` |
| Driving failure | KIT-GAP-0097 — the monitor first shipped (v0.6.90) as a `Stop` hook, but a Stop hook returning `additionalContext` re-invokes the agent every turn (infinite loop). Migrated to `UserPromptSubmit` (fires once per real user turn) + a `statusLine`. |
| Related layers | §Optimization Health Indicator (companion breadcrumb badge `opt:`); §Reliability Architecture (hooks layer) |

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ Each turn: Claude Code reads the transcript                 │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ statusLine command:                                         │
│   psk-session-monitor.sh --statusline                       │
│   reads .message.usage of the latest assistant turn         │
│   -> ctx % -> color badge -> "ctx: <badge> · opt: <badge>"  │
│   (always-on, structural, agent-independent)                │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ UserPromptSubmit hook (once per real user turn):            │
│   injects SESSION_HEALTH: line as additionalContext         │
│   -> agent mirrors the ctx: badge in its breadcrumb         │
│   red zone (>=80%) -> de-duped one-time /clear banner       │
└──────────────────────────────┬──────────────────────────────┘
                               │
                  ┌────────────┴────────────┐
                  │  band?                   │
                  │  green  -> badge only    │
                  │  yellow -> badge only    │
                  │  red    -> badge+banner  │
                  └──────────────────────────┘
```

## Key Rules

1. **Two surfaces, one source.** The `statusLine` is the structural guarantee (renders
   every turn independent of the agent, exactly when the agent's attention dilutes). The
   breadcrumb `ctx:` badge is the agent-mirrored convenience. Both read the same
   `.message.usage` data; they never disagree.
2. **Measured or nothing.** When no transcript usage is available (monitor not installed,
   non-Claude-Code agent), both surfaces suppress the badge entirely rather than rendering
   a guessed percentage. The badge shows a measured value or nothing.
3. **Passive badge, active banner.** The badge is continuous and glanceable (every reply).
   The `/clear` banner is reserved for the red zone (`≥80%`) and fires once per band, never
   every turn, re-arming only after a `/clear` or auto-compaction drops context. Yellow is
   badge-only on purpose — awareness without nagging.
4. **Authoritative limit derivation.** When `PSK_SESSION_CONTEXT_LIMIT` is unset, the limit
   is derived authoritatively, not guessed: a `compact_boundary`'s `compactMetadata.preTokens`
   proves the true window (a 200k window cannot hold a larger pre-compact size, so it
   establishes a ≥1M window); otherwise the standard tier ladder (200k → 1M → round up).
   This removes the pre-v0.6.93 `>220k` guess that caused a badge inversion and post-compact
   mis-tiering.
5. **UserPromptSubmit, not Stop.** The injection hook MUST be a `UserPromptSubmit` hook. A
   `Stop` hook that returns `additionalContext` re-invokes the agent every turn (infinite
   loop) — the KIT-GAP-0097 root cause. `psk-install-hooks.sh` migrate-and-add strips any
   legacy `.hooks.Stop` wiring and never clobbers an operator's existing `statusLine`.
6. **Fail-safe.** Both surfaces exit 0 silently on any error or missing data — they never
   block a turn.

## Manual Probes

```bash
bash agent/scripts/psk-session-monitor.sh --check       # full reading: tokens / limit / % / color / banner state
bash agent/scripts/psk-session-monitor.sh --badge       # just the badge string
bash agent/scripts/psk-session-monitor.sh --statusline  # the status-bar line: "ctx: <badge> · opt: <badge>"
```
