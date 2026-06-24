#!/usr/bin/env bash
# mechanical-script: psk-chunked-drive-guard.sh — PostToolUse long-op chunked-drive nudge (no AI prompts, Dim 28 allowlist)
# psk-chunked-drive-guard.sh — KIT-GAP-0147 structural enforcement (Layer-3 hook).
#
# THE GAP: the chat-visible progress surface (the psk-chunked-run.sh `status --table`
# box table) is the ONLY progress surface every client renders — the live file is
# pull-only and the statusLine is CLI-terminal-only. But driving a long op through
# chunked-run is AGENT-DRIVEN: nothing stops the agent from running a long op as a
# plain Bash invocation, in which case the chat shows ZERO progress. §No-Silent-Wait
# says "the agent is driven, not trusted" — this guard supplies the missing structural
# nudge so the guarantee no longer depends on agent memory.
#
# GENERIC BY DESIGN (covers ALL monitor/long-op calls, present + future): the guard does
# NOT hardcode a list of long ops. It detects ANY invoked script that carries the
# canonical `# long-op:` header (the same authoritative marker PSK047 enforces + PSK051
# requires to be chunk-reachable), plus the two long orchestrators (reflex/run.sh,
# psk-release.sh) and the indivisible psk-sync-check.sh --full. A new long-op script is
# covered automatically the moment it gets its `# long-op:` header — no edit here.
#
# HOW: wired as a PostToolUse(Bash) hook by psk-install-hooks.sh. After every Bash tool
# call, it inspects the command. If the command invokes a long op DIRECTLY (not via
# psk-chunked-run.sh, not the monitor itself), it returns `additionalContext`
# (chat-surfaced, injected into the agent's next turn) telling the agent to drive the op
# through the centralized monitor / relay the table. Fires regardless of agent intent.
#
# Contract: reads the PostToolUse event JSON on stdin, ALWAYS exits 0 (never blocks a turn),
# silent unless a bypassed long-op is detected. Bypass: PSK_CHUNKED_GUARD_DISABLED=1.

set -uo pipefail

[ "${PSK_CHUNKED_GUARD_DISABLED:-0}" = "1" ] && exit 0

_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
_KIT_ROOT="$(cd "$_SELF_DIR/../.." 2>/dev/null && pwd)"

# Read the hook event JSON from stdin (fail-safe: empty → exit silently).
_input="$(cat 2>/dev/null || true)"
[ -z "$_input" ] && exit 0

# Extract the Bash command without jq (python3 is the kit's JSON tool).
_cmd="$(printf '%s' "$_input" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ti = d.get("tool_input") or {}
sys.stdout.write(str(ti.get("command", "")))
' 2>/dev/null || true)"
[ -z "$_cmd" ] && exit 0

# Already driven through the centralized monitor, or it IS the monitor / a status relay,
# or the guard itself — no nudge (these ARE the correct surfaces).
case "$_cmd" in
  *psk-chunked-run.sh*|*psk-progress.sh*|*psk-progress-selfwrap.sh*|*progress-surface.sh*|*psk-chunked-drive-guard.sh*) exit 0 ;;
esac

# Cheap pre-filter: only proceed if the command even references a shell script.
case "$_cmd" in *.sh*) : ;; *) exit 0 ;; esac

_suite=""; _kind=""

# 1) GENERIC long-op detection — does the command invoke a script carrying `# long-op:`?
#    Extract candidate *.sh tokens from the command, resolve against the kit, and check the
#    canonical marker on that file. Fully data-driven: any current/future long-op is covered.
for _tok in $_cmd; do
  case "$_tok" in
    *.sh)
      _base="${_tok##*/}"
      _path=""
      [ -f "$_tok" ] && _path="$_tok"
      [ -z "$_path" ] && [ -f "$_KIT_ROOT/$_tok" ] && _path="$_KIT_ROOT/$_tok"
      if [ -z "$_path" ]; then
        # resolve by basename under the long-op-bearing dirs
        _path="$(find "$_KIT_ROOT/tests" "$_KIT_ROOT/agent/scripts" "$_KIT_ROOT/reflex" -name "$_base" -type f 2>/dev/null | head -1)"
      fi
      if [ -n "$_path" ] && [ -f "$_path" ] && grep -qE '^# long-op:' "$_path" 2>/dev/null; then
        # Derive the suite name by convention (basename minus .sh); chunked-run resolves it.
        _suite="${_base%.sh}"
        _kind="chunkable"
        break
      fi
      ;;
  esac
done

# 2) The two long ORCHESTRATORS + the indivisible full check (not `# long-op:`-headered but
#    long-running). Kept as named cases because they are singular, well-known surfaces.
if [ -z "$_kind" ]; then
  case "$_cmd" in
    *"reflex/run.sh"*)                 _kind="reflex" ;;
    *"psk-release.sh"*[Pp]repare*)     _suite="prepare-release"; _kind="chunkable" ;;
    *"psk-release.sh"*[Rr]efresh*)     _suite="refresh-release"; _kind="chunkable" ;;
    *"psk-sync-check.sh"*--full*)      _kind="indivisible" ;;
    *) exit 0 ;;
  esac
fi

# Emit a chat-surfaced reminder via additionalContext (the agent sees it next turn and
# self-corrects by rendering the table / relaying --status). Never blocks.
_msg=""
case "$_kind" in
  chunkable)
    _msg="§No-Silent-Wait (KIT-GAP-0147 guard): you invoked a long op DIRECTLY (${_suite}). The chat-visible progress table is NOT showing. Re-run it CHUNKED so each unit is a chat message — bash agent/scripts/psk-chunked-run.sh plan --label ${_suite} --suite ${_suite} — then relay 'psk-chunked-run.sh status --table --label ${_suite}' each turn." ;;
  reflex)
    _msg="§No-Silent-Wait (KIT-GAP-0147 guard): reflex/run.sh surfaces progress via its OWN per-pass + chunked tables (reflex-qa-dims / reflex-dev), auto-rendered by run.sh. Relay 'psk-chunked-run.sh status --table' each turn so the chat shows progress." ;;
  indivisible)
    _msg="§No-Silent-Wait (KIT-GAP-0147 guard): 'psk-sync-check.sh --full' is an indivisible long op (no sub-units). Relay its live heartbeat each turn so the chat is not silent — bash agent/scripts/psk-progress.sh --status." ;;
esac
[ -z "$_msg" ] && exit 0

printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":%s}}\n' \
  "$(printf '%s' "$_msg" | python3 -c 'import sys,json; sys.stdout.write(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '""')"
exit 0
