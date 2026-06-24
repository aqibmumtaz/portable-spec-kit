#!/bin/bash
# mechanical-script: deterministic YAML queue manipulator; no AI invocation
# psk-retry-queue.sh — Persistent retry queue for sub-agent spawn failures.
#
# Implements §Spawn Fidelity HF3 (portable-spec-kit.md / v0.6.60). The queue
# is a YAML file committed to git so spawn-failure state survives any session
# end / context-compact / machine switch. Reload-and-resume is automatic.
#
# Integration with psk-spawn.sh:
#   - On spawn failure → psk-spawn.sh writes AWAITING_SUBAGENT_RETRY:<phase>
#     to the workflow state file AND calls `psk-retry-queue.sh add ...` to
#     persist the retry intent. The in-state marker is fast-path; this queue
#     is the durable record.
#   - On `psk-spawn.sh retry <workflow> <phase>` the script consults this
#     queue's `next_attempt_at` for the matching entry and refuses to retry
#     before the backoff elapses (exit 5). PSK_RETRY_FORCE=1 overrides.
#   - On successful sub-agent completion → caller invokes `complete <id>`
#     to drop the entry.
#
# Commands:
#   list                          — pretty table of current queue
#   add <wf> <phase> <target> <prompt> <artifact> "<error>"
#                                 — append entry (idempotent on same key)
#   drain                         — emit SPAWN: signals for entries past
#                                   next_attempt_at; bumps status=dispatching
#   complete <id>                 — remove entry on sub-agent success
#   fail <id> "<error>"           — bump retry_count, recompute backoff
#   clear [<id>]                  — clear completed entries (no arg) or
#                                   specific id (operator override)
#   inspect <id>                  — print full YAML for one entry
#   evict [<days>]                — age-out pending entries whose `created`
#                                   timestamp is older than <days> (default
#                                   from PSK_RETRY_MAX_AGE_DAYS, else 3) to
#                                   .retry-queue-archive.yml with a tombstone.
#                                   Keeps the queue from accumulating stale
#                                   cross-cycle HUNG entries unboundedly.
#
# Auto-eviction: `drain` runs the same age-out FIRST, so stale entries are
# never re-dispatched and the session-start drain self-prunes. Configure the
# age threshold via PSK_RETRY_MAX_AGE_DAYS (or reflex/config.yml
# retry_queue.max_age_days, read by the caller and exported). 0 disables
# auto-eviction in drain.
#
# Backoff schedule (minutes, indexed by retry_count BEFORE increment):
#   0 → +5min · 1 → +15min · 2 → +45min · 3 → +120min · 4 → +360min
#   ≥5 → status=AWAITING_HUMAN_ARBITRATION (no further auto-retry)
#
# Exit codes:
#   0  success
#   1  generic error
#   2  entry not found
#   3  queue file missing / corrupt
#   4  AWAITING_HUMAN_ARBITRATION reached (informational)
#   5  (unused here; psk-spawn.sh uses it for backoff-not-elapsed)

set -uo pipefail

PROJ_ROOT="${PROJ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
QUEUE_FILE="${PSK_RETRY_QUEUE_FILE:-$PROJ_ROOT/agent/.workflow-state/retry-queue.yml}"
# Archive sits beside the live queue (same dir) so eviction is local + greppable.
ARCHIVE_FILE="${PSK_RETRY_ARCHIVE_FILE:-${QUEUE_FILE%/*}/.retry-queue-archive.yml}"
# Age-out threshold in days for `evict` / drain auto-prune. 0 = disable auto-prune.
MAX_AGE_DAYS="${PSK_RETRY_MAX_AGE_DAYS:-3}"
LOCK_DIR="$PROJ_ROOT/agent/.workflow-state/.retry-queue.lock"

_now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }
_now_epoch() { date -u +%s; }

_acquire_lock() {
  local tries=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 50 ]; then
      echo "psk-retry-queue: could not acquire lock $LOCK_DIR after 50 tries" >&2
      return 1
    fi
    sleep 0.1
  done
  return 0
}

_release_lock() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

_ensure_queue() {
  if [ ! -f "$QUEUE_FILE" ]; then
    mkdir -p "$(dirname "$QUEUE_FILE")"
    cat > "$QUEUE_FILE" <<'EOF'
# agent/.workflow-state/retry-queue.yml
# Persistent retry queue for sub-agent spawn failures. Survives session ends.
# Schema v1. Managed by psk-retry-queue.sh — do not hand-edit.
schema_version: 1
entries: []
EOF
  fi
}

# Python helper — single embedded driver that handles every command.
# Reads the queue file, applies the mutation, and writes it back atomically.
# Stays a pure stdlib script (no PyYAML dep) — uses a tiny line-based parser
# specifically for our flat schema. The queue file format is deterministic
# and managed only by this script, so a hand-rolled parser is safe.
_run_py() {
  local action="$1"; shift
  PSK_QUEUE_FILE="$QUEUE_FILE" \
  PSK_ARCHIVE_FILE="$ARCHIVE_FILE" \
  PSK_MAX_AGE_DAYS="$MAX_AGE_DAYS" \
  PSK_ACTION="$action" \
  PSK_ARG1="${1:-}" \
  PSK_ARG2="${2:-}" \
  PSK_ARG3="${3:-}" \
  PSK_ARG4="${4:-}" \
  PSK_ARG5="${5:-}" \
  PSK_ARG6="${6:-}" \
  PSK_NOW_ISO="$(_now_iso)" \
  PSK_NOW_EPOCH="$(_now_epoch)" \
  python3 - <<'PYEOF'
import os, sys, re

QF        = os.environ['PSK_QUEUE_FILE']
ARCHIVE   = os.environ.get('PSK_ARCHIVE_FILE', '')
MAX_AGE_DAYS = int(os.environ.get('PSK_MAX_AGE_DAYS', '3') or '3')
ACTION    = os.environ['PSK_ACTION']
A1        = os.environ.get('PSK_ARG1', '')
A2        = os.environ.get('PSK_ARG2', '')
A3        = os.environ.get('PSK_ARG3', '')
A4        = os.environ.get('PSK_ARG4', '')
A5        = os.environ.get('PSK_ARG5', '')
A6        = os.environ.get('PSK_ARG6', '')
NOW_ISO   = os.environ['PSK_NOW_ISO']
NOW_EPOCH = int(os.environ['PSK_NOW_EPOCH'])

MAX_RETRIES = 5
BACKOFF_MIN = [5, 15, 45, 120, 360]   # retry_count BEFORE increment → wait

def load_queue():
    """Read the queue file. Returns (header_lines, entries_list).
    Each entry is a dict of string fields. Robust to comments above
    `entries:` and to the empty `entries: []` form."""
    if not os.path.exists(QF):
        return ([
            "# agent/.workflow-state/retry-queue.yml",
            "# Persistent retry queue for sub-agent spawn failures. Survives session ends.",
            "# Schema v1. Managed by psk-retry-queue.sh — do not hand-edit.",
            "schema_version: 1",
        ], [])
    with open(QF, 'r') as f:
        lines = [l.rstrip('\n') for l in f.readlines()]
    # Split header (everything up to and including `schema_version:`) from entries.
    header = []
    entries_started = False
    entries_inline_empty = False
    body = []
    for line in lines:
        stripped = line.strip()
        if not entries_started:
            if stripped.startswith('entries:'):
                entries_started = True
                rest = stripped[len('entries:'):].strip()
                if rest == '[]':
                    entries_inline_empty = True
                continue
            header.append(line)
        else:
            body.append(line)
    entries = []
    cur = None
    for line in body:
        # Skip empty + pure-comment lines
        s = line.strip()
        if not s or s.startswith('#'):
            continue
        if s.startswith('- '):
            if cur is not None:
                entries.append(cur)
            cur = {}
            kv = s[2:].strip()
            if ':' in kv:
                k, v = kv.split(':', 1)
                cur[k.strip()] = v.strip()
        elif ':' in s and cur is not None:
            k, v = s.split(':', 1)
            cur[k.strip()] = v.strip()
    if cur is not None:
        entries.append(cur)
    return (header, entries)

def quote_yaml(s):
    """Conservative YAML scalar — single-quote, escape single quotes.
    Idempotent: if the value is already single-quoted, strip first so we
    don't compound-quote on re-save."""
    if s is None:
        s = ''
    s = str(s)
    if len(s) >= 2 and s.startswith("'") and s.endswith("'"):
        s = s[1:-1].replace("''", "'")
    return "'" + s.replace("'", "''") + "'"

def write_queue(header, entries):
    out = []
    for line in header:
        out.append(line)
    if entries:
        out.append('entries:')
        # 8 fields we track (in stable order); only emit fields that exist.
        FIELDS = ['id', 'workflow', 'phase', 'spawn_target',
                  'prompt_file', 'artifact_file',
                  'retry_count', 'max_retries', 'status',
                  'next_attempt_at', 'last_error',
                  'created', 'updated']
        for e in entries:
            first = True
            for f in FIELDS:
                if f not in e:
                    continue
                v = e[f]
                if f in ('retry_count', 'max_retries'):
                    val = str(v)
                else:
                    val = quote_yaml(v)
                if first:
                    out.append(f"  - {f}: {val}")
                    first = False
                else:
                    out.append(f"    {f}: {val}")
    else:
        out.append('entries: []')
    with open(QF, 'w') as f:
        f.write('\n'.join(out) + '\n')

def parse_iso(iso):
    """Parse 'YYYY-MM-DDTHH:MM:SSZ' → epoch seconds. Stdlib only."""
    m = re.match(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$', (iso or '').strip())
    if not m:
        return 0
    import calendar
    parts = [int(x) for x in m.groups()]
    return calendar.timegm((parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], 0, 0, 0))

def iso_at(epoch):
    """epoch → ISO-8601 UTC string."""
    import time
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(epoch))

def compute_next_attempt(retry_count):
    """retry_count is the count BEFORE this attempt (0 on first failure)."""
    if retry_count >= MAX_RETRIES:
        return None    # AWAITING_HUMAN_ARBITRATION
    idx = min(retry_count, len(BACKOFF_MIN) - 1)
    wait_seconds = BACKOFF_MIN[idx] * 60
    return iso_at(NOW_EPOCH + wait_seconds)

def truncate200(s):
    s = (s or '').replace('\n', ' ').replace('\r', ' ')
    return s[:200]

def _unq(s):
    """Strip YAML single-quote wrapping, decoding doubled quotes."""
    if s is None:
        return ''
    s = str(s)
    if len(s) >= 2 and s.startswith("'") and s.endswith("'"):
        return s[1:-1].replace("''", "'")
    return s

def cmd_list(entries):
    if not entries:
        print("(retry queue empty)")
        return 0
    # Header
    print("ID                                        WORKFLOW              PHASE                  RETRY  NEXT_ATTEMPT_AT       LAST_ERROR")
    print("-" * 140)
    for e in entries:
        eid     = _unq(e.get('id', ''))[:40]
        wf      = _unq(e.get('workflow', ''))[:20]
        ph      = _unq(e.get('phase', ''))[:22]
        rc      = e.get('retry_count', '0')
        mr      = e.get('max_retries', str(MAX_RETRIES))
        retry_s = f"{rc}/{mr}"
        nxt     = _unq(e.get('next_attempt_at', ''))[:20]
        err     = _unq(e.get('last_error', ''))[:40]
        status  = _unq(e.get('status', ''))
        if status == 'AWAITING_HUMAN_ARBITRATION':
            retry_s = retry_s + "!"
        print(f"{eid:<40}  {wf:<20}  {ph:<22}  {retry_s:<5}  {nxt:<20}  {err}")
    return 0

def find_by_key(entries, wf, phase, target):
    """Idempotency lookup — match on (workflow, phase, spawn_target).
    Compares against unquoted values because file storage is YAML-quoted."""
    for i, e in enumerate(entries):
        if (_unq(e.get('workflow')) == wf
            and _unq(e.get('phase')) == phase
            and _unq(e.get('spawn_target')) == target):
            return i
    return -1

def find_by_id(entries, eid):
    for i, e in enumerate(entries):
        if _unq(e.get('id')) == eid:
            return i
    return -1

def cmd_add(header, entries):
    """add <wf> <phase> <target> <prompt> <artifact> "<err>" """
    wf, ph, target, prompt, artifact, err = A1, A2, A3, A4, A5, A6
    if not (wf and ph and target and prompt and artifact):
        print("usage: add <workflow> <phase> <spawn_target> <prompt_file> <artifact_file> \"<error>\"", file=sys.stderr)
        return 1
    idx = find_by_key(entries, wf, ph, target)
    if idx >= 0:
        e = entries[idx]
        rc = int(e.get('retry_count', '0'))
        rc += 1
        e['retry_count']    = str(rc)
        e['last_error']     = truncate200(err)
        e['updated']        = NOW_ISO
        nxt = compute_next_attempt(rc)
        if nxt is None:
            e['status']           = 'AWAITING_HUMAN_ARBITRATION'
            e['next_attempt_at']  = ''
        else:
            e['status']           = 'pending'
            e['next_attempt_at']  = nxt
        write_queue(header, entries)
        print(f"updated existing entry {_unq(e.get('id'))} retry_count={rc}")
        return 0
    # New entry
    eid = f"{wf}-{ph}-{NOW_EPOCH}"
    nxt = compute_next_attempt(0)
    new = {
        'id'             : eid,
        'workflow'       : wf,
        'phase'          : ph,
        'spawn_target'   : target,
        'prompt_file'    : prompt,
        'artifact_file'  : artifact,
        'retry_count'    : '0',
        'max_retries'    : str(MAX_RETRIES),
        'status'         : 'pending',
        'next_attempt_at': nxt if nxt is not None else '',
        'last_error'     : truncate200(err),
        'created'        : NOW_ISO,
        'updated'        : NOW_ISO,
    }
    entries.append(new)
    write_queue(header, entries)
    print(f"added entry {eid} next_attempt_at={new['next_attempt_at']}")
    return 0

def cmd_drain(header, entries):
    """Emit SPAWN: signals for due entries; mark them dispatching.
    Auto-prunes stale entries FIRST so a stale cross-cycle HUNG entry is
    never re-dispatched and the session-start drain self-cleans."""
    evicted = _evict_stale(header, entries, MAX_AGE_DAYS)
    if evicted:
        print("-- auto-evicted %d stale entr%s (>%dd) before drain"
              % (evicted, 'y' if evicted == 1 else 'ies', MAX_AGE_DAYS))
    if not entries:
        print("no entries due (queue empty)")
        return 0
    due = 0
    changed = False
    for e in entries:
        status = _unq(e.get('status', ''))
        if status == 'completed':
            continue
        if status == 'AWAITING_HUMAN_ARBITRATION':
            continue
        nxt = _unq(e.get('next_attempt_at', ''))
        if not nxt:
            continue
        if parse_iso(nxt) <= NOW_EPOCH:
            print(f"SPAWN: phase={_unq(e.get('phase'))} "
                  f"prompt={_unq(e.get('prompt_file'))} "
                  f"artifact={_unq(e.get('artifact_file'))}")
            e['status']  = 'dispatching'
            e['updated'] = NOW_ISO
            due += 1
            changed = True
    if due == 0:
        print("no entries due")
    else:
        print(f"-- {due} entr{'y' if due == 1 else 'ies'} due, marked dispatching")
    if changed:
        write_queue(header, entries)
    return 0

def cmd_complete(header, entries):
    eid = A1
    if not eid:
        print("usage: complete <id>", file=sys.stderr); return 1
    idx = find_by_id(entries, eid)
    if idx < 0:
        print(f"entry not found: {eid}", file=sys.stderr); return 2
    removed = entries.pop(idx)
    write_queue(header, entries)
    print(f"removed entry {eid}")
    return 0

def cmd_fail(header, entries):
    eid = A1; err = A2
    if not eid:
        print("usage: fail <id> \"<error>\"", file=sys.stderr); return 1
    idx = find_by_id(entries, eid)
    if idx < 0:
        print(f"entry not found: {eid}", file=sys.stderr); return 2
    e = entries[idx]
    rc = int(e.get('retry_count', '0'))
    # Use the BEFORE-increment retry_count to pick the wait, then increment.
    new_rc = rc + 1
    e['retry_count'] = str(new_rc)
    e['last_error']  = truncate200(err)
    e['updated']     = NOW_ISO
    nxt = compute_next_attempt(new_rc)
    if nxt is None or new_rc > MAX_RETRIES:
        e['status']          = 'AWAITING_HUMAN_ARBITRATION'
        e['next_attempt_at'] = ''
        write_queue(header, entries)
        print(f"entry {eid} → AWAITING_HUMAN_ARBITRATION (retry_count={new_rc})", file=sys.stderr)
        return 4
    e['status']          = 'pending'
    e['next_attempt_at'] = nxt
    write_queue(header, entries)
    print(f"entry {eid} retry_count={new_rc} next_attempt_at={nxt}")
    return 0

def cmd_clear(header, entries):
    eid = A1
    if eid:
        idx = find_by_id(entries, eid)
        if idx < 0:
            print(f"entry not found: {eid}", file=sys.stderr); return 2
        entries.pop(idx)
        write_queue(header, entries)
        print(f"cleared entry {eid}")
        return 0
    # No id → drop all completed entries
    before = len(entries)
    entries[:] = [e for e in entries if e.get('status') != 'completed']
    write_queue(header, entries)
    print(f"cleared {before - len(entries)} completed entr{'y' if before - len(entries) == 1 else 'ies'}")
    return 0

def _append_archive(removed):
    """Append evicted entries to the archive file with a tombstone reason.
    Best-effort — a missing/unwritable archive path never blocks eviction."""
    if not ARCHIVE or not removed:
        return
    try:
        new_file = not os.path.exists(ARCHIVE)
        with open(ARCHIVE, 'a') as f:
            if new_file:
                f.write("# agent/.workflow-state/.retry-queue-archive.yml\n")
                f.write("# Auto-evicted stale retry-queue entries. Append-only tombstone log.\n")
                f.write("# Managed by psk-retry-queue.sh evict / drain auto-prune.\n")
            for e in removed:
                f.write("- evicted_at: %s\n" % quote_yaml(NOW_ISO))
                f.write("  reason: %s\n" % quote_yaml("auto-evicted: stale cross-cycle entry"))
                f.write("  id: %s\n" % quote_yaml(_unq(e.get('id', ''))))
                f.write("  workflow: %s\n" % quote_yaml(_unq(e.get('workflow', ''))))
                f.write("  phase: %s\n" % quote_yaml(_unq(e.get('phase', ''))))
                f.write("  created: %s\n" % quote_yaml(_unq(e.get('created', ''))))
                f.write("  last_error: %s\n" % quote_yaml(_unq(e.get('last_error', ''))))
    except (OSError, IOError):
        pass

def _evict_stale(header, entries, days):
    """Remove pending/dispatching entries whose `created` is older than <days>.
    AWAITING_HUMAN_ARBITRATION entries are NEVER auto-evicted (they need a human,
    not a timer). Returns the count evicted. days<=0 → no-op."""
    if days <= 0:
        return 0
    cutoff = NOW_EPOCH - days * 86400
    kept, removed = [], []
    for e in entries:
        status = _unq(e.get('status', ''))
        created_epoch = parse_iso(_unq(e.get('created', '')))
        # Discriminate "drain me" from "evict me" for an old entry — both can be DUE:
        #  - A NEVER-attempted due entry (retry_count 0, next_attempt elapsed) is awaiting
        #    its FIRST dispatch → it must DRAIN→SPAWN, never be evicted (the 72.8 contract).
        #  - A retried-but-stale entry (retry_count > 0, old), OR an old NON-due entry, is
        #    genuinely stuck/abandoned → evict it (the f80 cross-cycle-HUNG contract).
        # So evict only when old AND (already attempted OR not currently due).
        nxt = _unq(e.get('next_attempt_at', ''))
        is_due = bool(nxt) and parse_iso(nxt) <= NOW_EPOCH
        try:
            rc = int(_unq(e.get('retry_count', '0')) or '0')
        except (ValueError, TypeError):
            rc = 0
        if status not in ('AWAITING_HUMAN_ARBITRATION', 'completed') \
           and (rc > 0 or not is_due) \
           and created_epoch > 0 and created_epoch < cutoff:
            removed.append(e)
        else:
            kept.append(e)
    if removed:
        _append_archive(removed)
        entries[:] = kept
        write_queue(header, entries)
    return len(removed)

def cmd_evict(header, entries):
    """evict [<days>] — age-out stale pending entries to the archive."""
    days = MAX_AGE_DAYS
    if A1:
        try:
            days = int(A1)
        except ValueError:
            print("usage: evict [<days>]  (days must be an integer)", file=sys.stderr)
            return 1
    n = _evict_stale(header, entries, days)
    if n == 0:
        print("no stale entries to evict (threshold=%dd)" % days)
    else:
        print("evicted %d stale entr%s (older than %dd) → archive" % (n, 'y' if n == 1 else 'ies', days))
    return 0

def cmd_inspect(header, entries):
    eid = A1
    if not eid:
        print("usage: inspect <id>", file=sys.stderr); return 1
    idx = find_by_id(entries, eid)
    if idx < 0:
        print(f"entry not found: {eid}", file=sys.stderr); return 2
    e = entries[idx]
    print(f"# entry {eid}")
    FIELDS = ['id', 'workflow', 'phase', 'spawn_target',
              'prompt_file', 'artifact_file',
              'retry_count', 'max_retries', 'status',
              'next_attempt_at', 'last_error',
              'created', 'updated']
    for f in FIELDS:
        if f in e:
            print(f"{f}: {_unq(e[f])}")
    return 0

header, entries = load_queue()
if ACTION == 'list':
    sys.exit(cmd_list(entries))
elif ACTION == 'add':
    sys.exit(cmd_add(header, entries))
elif ACTION == 'drain':
    sys.exit(cmd_drain(header, entries))
elif ACTION == 'complete':
    sys.exit(cmd_complete(header, entries))
elif ACTION == 'fail':
    sys.exit(cmd_fail(header, entries))
elif ACTION == 'clear':
    sys.exit(cmd_clear(header, entries))
elif ACTION == 'evict':
    sys.exit(cmd_evict(header, entries))
elif ACTION == 'inspect':
    sys.exit(cmd_inspect(header, entries))
else:
    print(f"unknown action: {ACTION}", file=sys.stderr)
    sys.exit(1)
PYEOF
}

_with_lock() {
  _acquire_lock || return 1
  trap '_release_lock' EXIT INT TERM
  "$@"
  local rc=$?
  _release_lock
  trap - EXIT INT TERM
  return $rc
}

# ---- subcommand dispatchers ----

cmd_list() {
  _ensure_queue
  _run_py list
}

cmd_add() {
  if [ $# -lt 5 ]; then
    echo "usage: psk-retry-queue.sh add <workflow> <phase> <spawn_target> <prompt_file> <artifact_file> [\"<error>\"]" >&2
    return 1
  fi
  _ensure_queue
  _with_lock _run_py add "$1" "$2" "$3" "$4" "$5" "${6:-}"
}

cmd_drain() {
  _ensure_queue
  _with_lock _run_py drain
}

cmd_complete() {
  if [ $# -lt 1 ]; then
    echo "usage: psk-retry-queue.sh complete <id>" >&2; return 1
  fi
  _ensure_queue
  _with_lock _run_py complete "$1"
}

cmd_fail() {
  if [ $# -lt 1 ]; then
    echo "usage: psk-retry-queue.sh fail <id> \"<error>\"" >&2; return 1
  fi
  _ensure_queue
  _with_lock _run_py fail "$1" "${2:-}"
}

cmd_clear() {
  _ensure_queue
  _with_lock _run_py clear "${1:-}"
}

cmd_evict() {
  _ensure_queue
  _with_lock _run_py evict "${1:-}"
}

cmd_inspect() {
  if [ $# -lt 1 ]; then
    echo "usage: psk-retry-queue.sh inspect <id>" >&2; return 1
  fi
  _ensure_queue
  _run_py inspect "$1"
}

case "${1:-}" in
  list)     shift; cmd_list "$@" ;;
  add)      shift; cmd_add "$@" ;;
  drain)    shift; cmd_drain "$@" ;;
  complete) shift; cmd_complete "$@" ;;
  fail)     shift; cmd_fail "$@" ;;
  clear)    shift; cmd_clear "$@" ;;
  evict)    shift; cmd_evict "$@" ;;
  inspect)  shift; cmd_inspect "$@" ;;
  -h|--help|"") sed -n '2,47p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "unknown subcommand: $1" >&2; exit 2 ;;
esac
