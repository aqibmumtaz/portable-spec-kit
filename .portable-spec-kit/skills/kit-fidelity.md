# Skill: Kit Fidelity (8th reliability layer)

> **JIT-loaded when:** any kit command pauses with `AWAITING_RATIONALE`, the user mentions kit deviations, an agent hits friction with a canonical kit command, or PSK040 sync-check fires.

This skill is the operational complement to `portable-spec-kit.md` §Kit Fidelity and `docs/work-flows/30-kit-fidelity.md`. It carries the exact protocols an agent follows when invoking kit commands.

## The two principles (memorize)

1. **Canonical default form.** Every kit command runs in its canonical default form unless the user has explicitly authorized a deviation. Deviations require `--rationale "<text>"` (≥20 chars) committed to `agent/.kit-deviation-log`.

2. **Friction = kit bug.** Workarounds are forbidden. When you hit friction with a canonical command, file a `KIT-GAP-NNNN` in `agent/.kit-gap-log` FIRST. Then either fix the kit inline or escalate to user. Never the workaround.

## The wrapper protocol

```
ALL canonical kit commands → bash agent/scripts/psk-kit-cmd.sh <command> [args]
```

The wrapper reads `.portable-spec-kit/kit-commands.yml`, classifies argv against the canonical default, and either:
- **Executes** the underlying script (canonical path), OR
- **Pauses with AWAITING_RATIONALE** (non-canonical without `--rationale`), OR
- **Logs deviation + executes** (non-canonical with `--rationale "<text>"`)

## Wrapper subcommands you need

| Subcommand | When to use |
|---|---|
| `bash agent/scripts/psk-kit-cmd.sh <cmd>` | Canonical run — your default for every kit command |
| `bash agent/scripts/psk-kit-cmd.sh <cmd> <args> --rationale "<text>"` | Non-canonical run — only with user-authored rationale |
| `bash agent/scripts/psk-kit-cmd.sh --list` | Show full canonical-command inventory |
| `bash agent/scripts/psk-kit-cmd.sh --check <cmd> <args>` | Dry-run: would this require --rationale? |
| `bash agent/scripts/psk-kit-cmd.sh --log-gap "<cmd>" "<friction>" "<fix>"` | Record a KIT-GAP without running |

## Decision tree on every kit-command invocation

```
Want to run a kit command?
        │
        ▼
Is the canonical default what you actually need?
        │
   ┌────┴────┐
   YES        NO
   │          │
   ▼          ▼
Run via    Do you have user-authored rationale text?
wrapper           │
canonical    ┌────┴────┐
form         YES        NO
             │          │
             ▼          ▼
        Run via      Does the canonical form
        wrapper      have friction that's
        with         making you reach for
        --rationale  the non-canonical?
                          │
                     ┌────┴────┐
                     YES        NO
                     │          │
                     ▼          ▼
                Log KIT-GAP   Ask user
                first.        for rationale
                Then fix kit  OR run canonical
                OR escalate
```

## When you hit AWAITING_RATIONALE

```
⏸ AWAITING_RATIONALE — non-canonical invocation requires explicit user rationale
  command:        reflex
  args:           single
  non-canonical:  single
  why:            exits after one pass regardless of verdict; loses convergence-driving behavior

  Two forward paths (pick ONE):
  1. Run the CANONICAL form (recommended):
       bash agent/scripts/psk-kit-cmd.sh reflex

  2. Provide --rationale with user-authored justification:
       bash agent/scripts/psk-kit-cmd.sh reflex single --rationale "<user-authored text>"
```

Your protocol:
1. **Default to path 1 (canonical).** This is the kit-fidelity-correct path 95% of the time.
2. **If user authorized non-canonical**, use path 2 with their authored rationale text (not your own paraphrase).
3. **If canonical has friction blocking you**, log a KIT-GAP first, then either fix the kit or escalate. Do NOT use rationale to sidestep a kit bug.

## When you encounter friction with a canonical command

```bash
bash agent/scripts/psk-kit-cmd.sh --log-gap \
  "<command>" \
  "<one-line description of friction>" \
  "<one-line proposed fix to the kit>"
```

Example:
```bash
bash agent/scripts/psk-kit-cmd.sh --log-gap \
  "reflex" \
  "autoloop iter-1 prep-release bumps version too aggressively after manual release" \
  "add --bump-after-grant flag so version bump moves to convergence-final ceremony instead of iter-1"
```

This appends a `KIT-GAP-NNNN` entry. Then your next action is ONE of:

- **(a) Fix the kit inline.** Implement the proposed fix, commit it (regular `git commit`), then proceed with the canonical command which is now improved.
- **(b) Escalate to user.** Surface the KIT-GAP id + your proposed fix. Ask whether to implement now or queue for later. Wait for direction.

**NEVER (c) work around silently.** That's the failure mode this layer exists to prevent.

## Worked examples

### Example 1 — Canonical reflex run

User: *"run reflex"*

Agent action:
```bash
bash agent/scripts/psk-kit-cmd.sh reflex
```

That's it. The wrapper exec's `bash reflex/run.sh` (canonical autoloop). Done.

### Example 2 — User authorizes single-pass for debug

User: *"run a single reflex pass — i want to inspect findings before iterating"*

Agent action:
```bash
bash agent/scripts/psk-kit-cmd.sh reflex single \
  --rationale "user requested single-pass for finding inspection before iterating"
```

Wrapper logs deviation to `.kit-deviation-log`, then exec's `bash reflex/run.sh single`. Done.

### Example 3 — Friction: autoloop wants to bump too soon

Agent invokes:
```bash
bash agent/scripts/psk-kit-cmd.sh reflex
```

Reflex starts autoloop, iter-1 = prepare-release, which would bump v0.6.63 → v0.6.64. But v0.6.63 was just published manually 1 hour ago. This is friction.

WRONG response (the failure mode this layer prevents):
```bash
# Switch to single-pass to avoid the bump
bash agent/scripts/psk-kit-cmd.sh reflex single --rationale "avoid version bump"
```

RIGHT response:
```bash
# Step 1: Log the KIT-GAP
bash agent/scripts/psk-kit-cmd.sh --log-gap \
  "reflex" \
  "autoloop iter-1 prep-release bumps version too aggressively after manual release" \
  "add --bump-after-grant flag so version bump moves to convergence-final ceremony"

# Step 2: Escalate to user — surface the gap, propose fix, ask direction
# Agent text to user:
# "Logged KIT-GAP-NNNN. The canonical autoloop would bump v0.6.63 → v0.6.64
#  in iter-1 even though we just published v0.6.63. Two options:
#   (a) implement --bump-after-grant now (~30 min) so version bump moves to
#       the final ceremony, then run canonical autoloop
#   (b) accept the bump as designed and run canonical autoloop
#  Which?"

# Step 3: Per user direction, either implement the fix and proceed canonically,
# OR run canonical with their explicit acceptance of the bump.
```

### Example 4 — PSK040 fires on a marker commit

Pre-commit hook reports:
```
✗ PSK040: kit-fidelity-coverage — 1 marker-shaped commit(s) since §Kit Fidelity
   intro have no matching agent/.kit-deviation-log entry:
   abc123def: v0.6.65: reflex single-pass precondition marker
```

This means a previous agent invocation bypassed `psk-kit-cmd.sh` and committed a non-canonical command directly. The fix:

1. Decide: was the deviation actually justified? If not, revert the commit.
2. If justified, retroactively log it:
   ```bash
   echo -e "$(date -u +%Y-%m-%dT%H:%M:%SZ)\treflex\tmarker-commit\tretroactive-log\toperator approved single-pass for debug — this commit was made before §Kit Fidelity layer landed" >> agent/.kit-deviation-log
   git add agent/.kit-deviation-log
   git commit -m "kit-fidelity: retroactive deviation-log entry for abc123def"
   ```
3. The marker-commit pattern in `.portable-spec-kit/kit-commands.yml` should also be reviewed — if such commits are common operational shape, the canonical-inventory may need to widen.

## Self-check before every kit-command invocation

Before you write `bash agent/scripts/psk-...` ANYWHERE in your reply:

| Question | If YES | If NO |
|---|---|---|
| Is this a canonical kit command (listed in inventory)? | Continue → | Use direct invocation (mechanical scripts like `psk-sync-check.sh`, `psk-env.sh` are exempt — they're not in the canonical-command inventory) |
| Am I invoking it via `psk-kit-cmd.sh`? | Continue → | **STOP.** Route through the wrapper. |
| Is the form canonical default? | Run it | Have user-authored rationale → use --rationale flag. Otherwise STOP and either run canonical or escalate. |
| Did I hit any friction with the canonical form? | **STOP.** Log KIT-GAP first. Then fix kit or escalate. Never workaround. | Run it normally. |

## Bypass discipline

`PSK_KIT_FIDELITY_DISABLED=1` exists but is logged to `.bypass-log`. PSK027 sync-check surfaces 24h bypass count. Treat bypass as nuclear option — every invocation removes the structural guarantee.

If you find yourself reaching for bypass more than once per release cycle, that's a signal that:
- The canonical-inventory needs to widen (add a new variant entry), OR
- The kit has a friction that needs fixing (file KIT-GAP), OR
- You're rationalizing your way past the layer (revisit your reasoning)

## Cross-references

- `portable-spec-kit.md` §Kit Fidelity — canonical rule (8th reliability layer)
- `docs/work-flows/30-kit-fidelity.md` — full flow doc
- `agent/scripts/psk-kit-cmd.sh` — wrapper
- `.portable-spec-kit/kit-commands.yml` — canonical inventory
- `agent/.kit-deviation-log` — committed deviation audit trail
- `agent/.kit-gap-log` — committed friction ledger
- `agent/scripts/psk-sync-check.sh::check_psk040_kit_fidelity_coverage` — defense-in-depth detection
