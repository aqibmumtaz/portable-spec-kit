#!/usr/bin/env bash
# mechanical-script: psk-chunked-run.sh — chunk a long op into agent-drivable pieces (no-silent-wait)
# ─────────────────────────────────────────────────────────────────────────────
# WHY THIS EXISTS (no-silent-wait, KIT-GAP-0113):
#   psk-progress.sh + --status + --statusline make a long op's progress READABLE,
#   but the chat is turn-based: the agent prints ONLY on a turn (a user message or
#   a task-COMPLETION notification). A long op run as ONE background task gives the
#   user NOTHING in the chat until it finishes — ScheduleWakeup cannot fire while the
#   session is busy with that task. The proven workaround (empirically confirmed): run
#   the long op as a SERIES of short background tasks. Each chunk's completion
#   notification reliably re-invokes the agent, which prints that chunk's RESULT and
#   launches the next chunk. The user gets periodic, real, frontend-visible updates
#   DURING the run — without ScheduleWakeup, without tail -f.
#
# WHAT THIS IS — THE CENTRALIZED progress driver for the whole kit:
#   A position tracker + chunk enumerator. It does NOT run the agent (a script can't
#   re-invoke the agent). It enumerates the chunks of a long op, tracks which chunk is
#   next, records each chunk's result, and prints the command for the agent to run as
#   the next background task. The AGENT drives: plan → (next → run-as-bg-task →
#   on-completion record+next)* → done. See §No-Silent-Wait for the agent protocol.
#   Every long op in the kit is chunked-by-default THROUGH this one script — message-based
#   progress is the DEFAULT, not opt-in. A status bar (statusLine) is best-effort (CLI
#   only); chat MESSAGES are the universal surface, and chunked-drive is how they happen.
#   To make a new long op chunked-by-default, add a case to _derive_suite_chunks — the
#   agent drives it identically. The known suites (--suite) are:
#     test-spec-kit         → one chunk per tests/sections/*.sh + one chunk for all feature files
#     test-spd-benchmarking → single chunk (monolithic suite)
#     all-tests | tests     → full Test Execution Flow (all sections + feature files + benchmarking + release-check)
#     prepare-release       → one chunk per release phase (prepare + next×N from phases.yml)
#     refresh-release       → one chunk per release phase (refresh + next×N)
#
# CONTRACT (fail-safe):
#   - State lives in the same TMPDIR-independent dir as psk-progress.sh live files
#     (/tmp/psk-progress-<uid>/), so the chunk plan survives across agent turns and
#     is co-located with the per-chunk progress heartbeats.
#   - Every chunk command is opaque text — this script never executes it. The agent
#     runs it (as a background task). Stack-agnostic: a chunk can be any shell command.
#   - Re-runnable: `plan` overwrites the state for that label; `reset` clears it.
#
# Usage:
#   psk-chunked-run.sh plan  --label L (--suite SUITE | --chunks 'cmd1|||cmd2|||...')
#   psk-chunked-run.sh next  --label L [--result "<prev chunk result>"]
#   psk-chunked-run.sh status --label L [--table]   # --table → canonical markdown progress table
#   psk-chunked-run.sh reset --label L
#   psk-chunked-run.sh list                       # all active chunk plans
#
#   --label   plan name (default: "chunked"); also the progress-monitor label per chunk
#   --suite   auto-derive chunks from a known kit suite (see the suite list above:
#               test-spec-kit | test-spd-benchmarking | all-tests | prepare-release | refresh-release)
#   --chunks  explicit '|||'-separated list of chunk commands (any stack, any command)
#   --result  record the just-finished chunk's one-line result before advancing
#
# Agent protocol (the proven chunked-drive recipe — §No-Silent-Wait):
#   1. plan  --label test-spec-kit --suite test-spec-kit      # enumerate chunks
#   2. next  --label test-spec-kit                            # → prints "CHUNK 1/10: <cmd>"
#   3. run <cmd> as a BACKGROUND task (run_in_background)
#   4. on the completion notification: print the chunk RESULT, then
#      next --label test-spec-kit --result "<that result>"    # → prints "CHUNK 2/10: <cmd>"
#   5. each turn, render progress by relaying `status --table` VERBATIM (the canonical
#      | Chunk | Unit | Result | table). Repeat 3-4 until `next` prints "DONE"; then relay
#      the final `status --table`.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

PROGRESS_DIR="${PSK_PROGRESS_DIR:-/tmp/psk-progress-$(id -u 2>/dev/null || echo u)}"
mkdir -p "$PROGRESS_DIR" 2>/dev/null || true

_safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'; }
_state_file() { printf '%s/%s.chunks' "$PROGRESS_DIR" "$(_safe "${1:-chunked}")"; }

# ── arg parse ────────────────────────────────────────────────────────────────
CMD="${1:-}"; shift || true
LABEL="chunked"; SUITE=""; CHUNKS=""; RESULT=""; TABLE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --label)  LABEL="${2:-chunked}"; shift 2 ;;
    --suite)  SUITE="${2:-}"; shift 2 ;;
    --chunks) CHUNKS="${2:-}"; shift 2 ;;
    --result) RESULT="${2:-}"; shift 2 ;;
    --table)  TABLE=1; shift ;;
    --label=*)  LABEL="${1#*=}"; shift ;;
    --suite=*)  SUITE="${1#*=}"; shift ;;
    --chunks=*) CHUNKS="${1#*=}"; shift ;;
    --result=*) RESULT="${1#*=}"; shift ;;
    -h|--help) grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "psk-chunked-run.sh: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

STATE="$(_state_file "$LABEL")"

# Resolve the kit root (this script lives in agent/scripts/) so --suite commands are
# repo-relative-correct regardless of the caller's CWD.
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_KIT_ROOT="$(cd "$_SCRIPT_DIR/../.." 2>/dev/null && pwd)"

# ── derive chunk commands for a known suite ──────────────────────────────────
# Emits one chunk command per line on stdout. Stack-agnostic at the call site —
# only the suite-specific derivation knows the command shape. This is the
# CENTRALIZED registry of every kit long op: to make a new long op chunked-by-default,
# add a case here (and nothing else changes — the agent drives it the same way).

# test-spec-kit → one chunk per tests/sections/*.sh (NN-name.sh → --section NN), PLUS a final
# chunk running ALL feature files (tests/features/*.sh) via --features-only. Together these
# cover the WHOLE suite — sections AND features — i.e. exactly what `bash test-spec-kit.sh` runs.
# (Without the features chunk the section sum under-counts the suite — the gap that hid ~350
# feature tests before KIT-GAP-0114.)
_tsk_chunks() {
  # Each chunk carries a `# stage:<name>` label (KIT-GAP-0141) — a bash comment (harmless
  # when executed) that the status --table renderer surfaces in the Stage column, so the
  # operator sees which top-level suite each chunk belongs to. Mirrors the `# phase:` label
  # convention used by release chunks. Default stage "test-spec-kit"; the all-tests caller
  # keeps it so benchmarking + release-check stand out as their own stages.
  local _stage="${1:-test-spec-kit}" _sfx
  _sfx=" # stage:$_stage"
  local _list
  _list="$(cd "$_KIT_ROOT" 2>/dev/null && PSK_PROGRESS_DISABLED=1 bash tests/test-spec-kit.sh --list-sections 2>/dev/null)" || return 1
  printf '%s\n' "$_list" \
    | awk '/^Sections/{insec=1;next} /^Features/{insec=0} insec && /^  [0-9]/{gsub(/^  /,"");print}' \
    | while IFS= read -r _f; do
        [ -n "$_f" ] || continue
        _nn="${_f%%-*}"
        printf 'bash tests/test-spec-kit.sh --section %s%s\n' "$_nn" "$_sfx"
      done
  # All feature files as ONE chunk (85 files in one run; per-file would be 85 chunks).
  printf 'bash tests/test-spec-kit.sh --features-only%s\n' "$_sfx"
}

# release → one chunk per declared phase (dynamic count from phases.yml). Chunk 1 is
# the prepare/refresh kickoff; the rest are `next` advances. Each chunk is the agent
# driving one phase of psk-release.sh; an interactive phase that pauses (AWAITING_*)
# is handled by the agent as that chunk's work, then chunked-run advances.
_release_chunks() {
  # KIT-GAP-0118: label each chunk with its ACTUAL release phase (tests,
  # code-review, version, pdfs…) instead of an opaque "release: next" ×N. The
  # phase names come from release/phases.yml (step-1-tests → "tests"); each is
  # appended as a `# phase:<name>` comment — harmless to bash (a comment), read
  # by the status --table renderer so the operator sees what each stage does.
  local _kick="$1"
  local _pf="$_KIT_ROOT/.portable-spec-kit/workflows/release/phases.yml"
  local _labels
  _labels=$(grep -E '^[[:space:]]*-[[:space:]]*id:[[:space:]]*step-' "$_pf" 2>/dev/null | sed -E 's/.*id:[[:space:]]*step-[0-9]+-//')
  [ -n "$_labels" ] || _labels=$(printf 'tests\ncode-review\nscope-check\nflow-docs\ncounts\nversion\npdfs\nreleases\nvalidation\nsummary')
  local _i=1 _lbl
  while IFS= read -r _lbl; do
    [ -n "$_lbl" ] || continue
    if [ "$_i" -eq 1 ]; then
      printf 'bash agent/scripts/psk-release.sh %s # phase:%s\n' "$_kick" "$_lbl"
    else
      printf 'bash agent/scripts/psk-release.sh next # phase:%s\n' "$_lbl"
    fi
    _i=$((_i+1))
  done <<EOF
$_labels
EOF
}

# Latest reflex pass dir (cycle-NN/pass-NNN most recently modified), or empty.
_reflex_pass_dir() {
  ls -dt "$_KIT_ROOT"/reflex/history/cycle-*/pass-* "$_KIT_ROOT"/reflex/history/standalone/pass-* 2>/dev/null | head -1
}

# reflex-qa-dims → one SPAWN-MARKER chunk per wave-manifest dim-range. reflex-dev →
# one per finding in findings.yaml. The chunk "command" is a no-op `:` marker that
# DOCUMENTS the spawn — for reflex the agent spawns a Task sub-agent (§Spawn Fidelity),
# it does NOT bash-exec the marker. psk-chunked-run is the centralized progress
# tracker + `status --table` renderer (same template as tests/release); the agent
# drives the actual sub-agent spawn per chunk and reports its result. (KIT-GAP-0116.)
_reflex_qa_chunks() {
  local _pd; _pd="$(_reflex_pass_dir)"; [ -n "$_pd" ] || return 1
  local _man="$_pd/wave-manifest.yaml"; [ -f "$_man" ] || return 1
  awk '
    /^spawns:/{s=1;next} s&&/^[a-zA-Z_]+:/{s=0}
    s&&/^[[:space:]]*-[[:space:]]*id:/{if(d!="")print d; d=""}
    s&&/^[[:space:]]*assigned_dims:/{d=$0;sub(/.*assigned_dims:[[:space:]]*/,"",d);gsub(/"|[[:space:]]/,"",d)}
    END{if(d!="")print d}
  ' "$_man" | while IFS= read -r _r; do
      [ -n "$_r" ] || continue
      printf ': reflex QA dim-agent - dims %s (spawn Task, model=sonnet)\n' "$_r"
    done
}
# Dev is a per-finding progress TRACKER, NOT a spawn-splitter. The Dev phase stays
# ONE monolithic Dev-Agent (§Spawn Fidelity: fix by root-cause in a single coherent
# agent — a root fix closes multiple symptom-findings; splitting the spawn fragments
# that). The chunks here are TRACKING rows: one per finding id, marked ✓ as the one
# Dev-Agent commits each fix (the driver maps dev-trace.md / git-log onto `next
# --result`). Granular tracking is fine; granular SPAWNING is not. (KIT-GAP-0116.)
_reflex_dev_chunks() {
  local _pd; _pd="$(_reflex_pass_dir)"; [ -n "$_pd" ] || return 1
  local _f="$_pd/findings.yaml"; [ -f "$_f" ] || return 1
  grep -oE '^[[:space:]]*-?[[:space:]]*id:[[:space:]]*[A-Za-z0-9._-]+' "$_f" \
    | sed -E 's/.*id:[[:space:]]*//' | while IFS= read -r _id; do
      [ -n "$_id" ] || continue
      printf ': reflex Dev-Agent fix %s (one monolithic agent, tracker row)\n' "$_id"
    done
}

# reflex-preflight → the reflex pre-QA STARTUP window (KIT-GAP-0134): the steps a fresh
# `reflex/run.sh` pass runs BEFORE the first QA dim-agent spawns — preconditions, the
# preflight test suite (~14min cold cache), and QA sandbox + dim-agent dispatch. Without
# this the startup window was chat-silent: the agent backgrounded `reflex/run.sh` and the
# user saw nothing until QA dims appeared (the reflex-qa table, KIT-GAP-0133). These are
# `:` no-op MARKER rows (same convention as reflex-qa / reflex-dev) — run.sh advances them
# via `next` as each step completes and the agent relays `status --table`; the fine
# sub-stage during the long preflight is surfaced live via psk-progress.sh --mark / the
# preflight's own heartbeat. Workload is FIXED (the startup pipeline is the same every
# pass), so the chunk list is static — not derived from a pass-dir artifact.
_reflex_preflight_chunks() {
  printf ': reflex pre-QA - preconditions (clean-tree + prep-release ancestor)\n'
  printf ': reflex pre-QA - preflight test suite + QA sandbox + dim-agent dispatch\n'
}

_derive_suite_chunks() {
  case "$1" in
    test-spec-kit)
      _tsk_chunks ;;
    reflex-preflight)
      _reflex_preflight_chunks ;;
    reflex-qa-dims|reflex-qa)
      _reflex_qa_chunks ;;
    reflex-dev)
      _reflex_dev_chunks ;;
    test-spd-benchmarking|benchmarking)
      # Monolithic suite (no sections) → a single chunk. Still message-surfaced.
      printf 'bash tests/test-spd-benchmarking.sh # stage:benchmarking\n' ;;
    all-tests|tests|test-execution-flow)
      # The full Test Execution Flow (§Git & GitHub Rules): every test-spec-kit section +
      # the feature files, then the benchmarking suite, then the R→F→T release-check.
      # Each chunk's `# stage:<name>` label drives the Stage column (KIT-GAP-0141) so the
      # three top-level suites read as distinct stages: test-spec-kit · benchmarking · release-check.
      _tsk_chunks test-spec-kit || return 1
      printf 'bash tests/test-spd-benchmarking.sh # stage:benchmarking\n'
      printf 'bash tests/test-release-check.sh agent/SPECS.md # stage:release-check\n' ;;
    prepare-release|release)
      _release_chunks prepare ;;
    refresh-release)
      _release_chunks refresh ;;
    *)
      return 1 ;;
  esac
}

case "$CMD" in
  plan)
    # Build the chunk list.
    _tmp="$(mktemp 2>/dev/null || echo "/tmp/psk-chunk.$$.tmp")"
    if [ -n "$SUITE" ]; then
      _derive_suite_chunks "$SUITE" > "$_tmp" || { echo "psk-chunked-run.sh: cannot derive chunks for suite '$SUITE'" >&2; rm -f "$_tmp"; exit 2; }
    elif [ -n "$CHUNKS" ]; then
      # Split on the '|||' separator, one chunk per line.
      printf '%s' "$CHUNKS" | awk 'BEGIN{RS="\\|\\|\\|"} {gsub(/^[[:space:]]+|[[:space:]]+$/,""); if(length($0))print}' > "$_tmp"
    else
      echo "psk-chunked-run.sh plan: need --suite or --chunks" >&2; rm -f "$_tmp"; exit 2
    fi
    _total=$(grep -c . "$_tmp" 2>/dev/null | head -1); _total="${_total:-0}"
    if [ "$_total" -eq 0 ] 2>/dev/null; then
      echo "psk-chunked-run.sh plan: zero chunks derived (nothing to run)" >&2; rm -f "$_tmp"; exit 2
    fi
    {
      printf 'LABEL\t%s\n' "$LABEL"
      printf 'SUITE\t%s\n' "$SUITE"
      printf 'TOTAL\t%s\n' "$_total"
      printf 'CURRENT\t0\n'
      _i=0
      while IFS= read -r _c; do
        [ -n "$_c" ] || continue
        _i=$((_i+1))
        printf 'C\t%s\t%s\n' "$_i" "$_c"
      done < "$_tmp"
    } > "$STATE"
    rm -f "$_tmp"
    echo "Planned $_total chunk(s) for '$LABEL'. Drive with: psk-chunked-run.sh next --label $LABEL"
    echo "(each 'next' prints the next chunk command; run it as a background task, then call next --result ...)"
    ;;

  next)
    [ -f "$STATE" ] || { echo "psk-chunked-run.sh next: no plan for '$LABEL' (run plan first)" >&2; exit 2; }
    _total=$(awk -F'\t' '$1=="TOTAL"{print $2}' "$STATE"); _total="${_total:-0}"
    _cur=$(awk -F'\t' '$1=="CURRENT"{print $2}' "$STATE"); _cur="${_cur:-0}"
    # Record the just-finished chunk's result, if provided and a chunk is in flight.
    if [ -n "$RESULT" ] && [ "$_cur" -ge 1 ] 2>/dev/null; then
      printf 'R\t%s\t%s\n' "$_cur" "$RESULT" >> "$STATE"
    fi
    _next=$((_cur + 1))
    if [ "$_next" -gt "$_total" ] 2>/dev/null; then
      echo "DONE: all $_total chunk(s) of '$LABEL' dispatched."
      # KIT-GAP-0123: when a TESTS suite finishes, attempt to seal the pre-verify marker
      # so a subsequent `psk-release.sh prepare` skips its opaque inline step-1-tests
      # (the suite already ran per-section with in-chat progress). Best-effort — never
      # blocks DONE. The seal is fail-CLOSED: it writes the marker ONLY if every suite
      # unit has a REAL exit-0 stamp (written by the test process itself, not the agent's
      # free-text result) at the CURRENT tree fingerprint. A failed/benignly-summarised/
      # un-run unit, or any dirty-tree change, leaves a unit unstamped → no seal → tests run.
      _suite=$(awk -F'\t' '$1=="SUITE"{print $2}' "$STATE" 2>/dev/null)
      case "$_suite" in
        test-spec-kit|all-tests|tests|test-execution-flow)
          _gate="$_KIT_ROOT/agent/scripts/psk-tests-gate.sh"
          if [ -x "$_gate" ]; then
            bash "$_gate" seal --suite "$_suite" 2>/dev/null \
              && echo "  (sealed tests pre-verify marker — next prepare skips step-1-tests)" \
              || echo "  (note: pre-verify marker NOT sealed — a suite unit lacks a real exit-0 stamp at this tree)" >&2
          fi ;;
      esac
      exit 0
    fi
    _cmd=$(awk -F'\t' -v n="$_next" '$1=="C" && $2==n{ sub(/^C\t[0-9]+\t/,""); print }' "$STATE")
    # Advance the pointer (atomic rewrite).
    _t2="$(mktemp 2>/dev/null || echo "$STATE.tmp")"
    awk -F'\t' -v n="$_next" 'BEGIN{OFS="\t"} $1=="CURRENT"{print "CURRENT",n;next} {print}' "$STATE" > "$_t2" && mv "$_t2" "$STATE"
    printf 'CHUNK %s/%s: %s\n' "$_next" "$_total" "$_cmd"
    ;;

  status)
    [ -f "$STATE" ] || { echo "psk-chunked-run.sh status: no plan for '$LABEL'" >&2; exit 2; }
    _total=$(awk -F'\t' '$1=="TOTAL"{print $2}' "$STATE"); _cur=$(awk -F'\t' '$1=="CURRENT"{print $2}' "$STATE")
    if [ "$TABLE" = "1" ]; then
      # Canonical progress table — the ONE format the agent relays verbatim each chunk turn,
      # so progress renders identically across EVERY long op (tests, prepare, reflex QA/Dev) —
      # no hand-built tables that drift. A well-aligned box table: columns padded to content
      # width so borders line up in any monospace view. Markers are all SINGLE display-width
      # (Unicode EAW Narrow) so alignment holds: ✓ done · ► running (in-flight) · · queued.
      # (The old ⏳ was Wide/double-width and broke the right border.) Width math runs on the
      # ASCII label/result text only — never on the multibyte glyph — so it's awk-portable.
      # KIT-GAP-0119: surface the in-flight op's LIVE heartbeat (elapsed · count)
      # in the running row, so a chunk that wraps a long self-wrapped op — e.g. the
      # test suite inside prepare's tests phase — shows the SAME live sub-progress
      # the standalone op emits, IN the table, not an opaque "running". Reads the
      # freshest *.live in PROGRESS_DIR (psk-progress writes them there); a 90s
      # freshness guard avoids showing a prior op's stale line for a new chunk.
      _live=""
      _lf=$(ls -t "$PROGRESS_DIR"/*.live 2>/dev/null | head -1)
      if [ -n "$_lf" ] && [ -f "$_lf" ]; then
        _now=$(date +%s 2>/dev/null || echo 0)
        _lfm=$(stat -f %m "$_lf" 2>/dev/null || stat -c %Y "$_lf" 2>/dev/null || echo 0)
        _age=$(( _now - _lfm ))
        if [ "$_age" -ge 0 ] && [ "$_age" -le 90 ]; then
          _live=$(tail -n1 "$_lf" 2>/dev/null | sed -E 's/^\[progress\][[:space:]]*//; s/[[:space:]]*$//')
          # The heartbeat uses a multibyte middot separator (·, U+00B7) which
          # byte-counting awk mis-measures → misaligned border. Swap it for ASCII
          # so the running row's width math (length() on bytes) stays correct.
          _live=${_live//·/-}
        fi
      fi
      # KIT-GAP-0122: split the op's current STAGE (e.g. "sec 04") out of the live
      # heartbeat into its OWN narrow column next to Chunk, so a long sectioned op
      # shows WHICH section is running without bloating Result + keeping width tight.
      # Generic: ANY op that declares psk-progress --stage surfaces here; ops without
      # a stage show "-". This is the ONE central renderer, so every monitor inherits it.
      _stage=""
      if [ -n "$_live" ]; then
        _stage=$(printf '%s' "$_live" | grep -oE 'sec [0-9]+[a-z]?' | head -1)
        _live=$(printf '%s' "$_live" | sed -E 's/[[:space:]]*-?[[:space:]]*sec [0-9]+[a-z]?//')
      fi
      awk -F'\t' -v total="${_total:-0}" -v cur="${_cur:-0}" -v live="$_live" -v stage="$_stage" '
        function pad(s,w,  d){ d=w-length(s); if(d<0)d=0; return s sprintf("%*s",d,"") }
        function dash(n,  i,s){ s=""; for(i=0;i<n;i++) s=s "─"; return s }
        $1=="C"{cmd[$2]=$3}
        $1=="R"{res[$2]=$3}
        END{
          # Pre-pass (KIT-GAP-0141): read the per-chunk static `# stage:<name>` label and count
          # DISTINCT stages. The Stage column is INFORMATIVE only when the plan groups chunks
          # into >=2 stages (e.g. all-tests → test-spec-kit · benchmarking · release-check). With
          # <=1 distinct stage (a single-suite drive, e.g. standalone test-spec-kit) the column
          # would just repeat one value on every row, so it is suppressed (shown as "-"). This is
          # the generic "use the Stage column as needed" rule, defined ONCE in this central renderer.
          for(i=1;i<=total;i++){
            cstg[i]="";
            if (match(cmd[i], /# stage:[A-Za-z0-9._-]+/)) { cstg[i] = substr(cmd[i], RSTART+8, RLENGTH-8) }
            if (cstg[i]!="" && !(cstg[i] in seenstg)) { seenstg[cstg[i]]=1; nstg++ }
          }
          multistage = (nstg >= 2);
          wc=length("Chunk"); ws=length("Stage"); wu=length("Unit"); wr=length("Result");
          for(i=1;i<=total;i++){
            c=cmd[i]; u=c;
            if (match(c, /--section [0-9A-Za-z._-]+/)) { u="section " substr(c,RSTART+10,RLENGTH-10) }
            else if (c ~ /--features-only/)       { u="feature files" }
            else if (c ~ /test-spd-benchmarking/) { u="benchmarking" }
            else if (c ~ /test-release-check/)    { u="release-check" }
            else if (match(c, /# phase:[A-Za-z0-9._-]+/)) { u="release: " substr(c, RSTART+8, RLENGTH-8) }
            else if (c ~ /psk-release\.sh prepare/){ u="release: prepare" }
            else if (c ~ /psk-release\.sh refresh/){ u="release: refresh" }
            else if (c ~ /psk-release\.sh next/)   { u="release: next" }
            else if (c ~ /QA dim-agent/) { u=c; sub(/.* dims /,"",u); sub(/ \(.*/,"",u); u="QA dims " u }
            else if (c ~ /Dev-Agent fix/){ u=c; sub(/.*Dev-Agent fix /,"",u); sub(/ \(.*/,"",u); u="Dev fix " u }
            gsub(/[|│]/,"/",u);
            # Stage shown only in a multi-stage plan; otherwise "-". The running chunk live
            # sub-stage (sec NN) still fills it for an op that internally iterates sub-units
            # (e.g. the prepare "tests" phase running the whole suite) even with no static stage.
            ch=i "/" total; st=(multistage && cstg[i]!="" ? cstg[i] : "-");
            if (i in res)    { g="✓"; n=res[i] }
            else if (i<cur)  { g="✓"; n="done" }
            else if (i==cur) { g="►"; n=(live!="" ? "running - " live : "running"); if(st=="-" && stage!="" && u !~ /^section /) st=stage }
            else             { g="·"; n="queued" }
            gsub(/[|│]/,"/",n); gsub(/[|│]/,"/",st);
            chunk[i]=ch; stg[i]=st; unit[i]=u; glyph[i]=g; note[i]=n;
            if(length(ch)>wc)wc=length(ch);
            if(length(st)>ws)ws=length(st);
            if(length(u)>wu)wu=length(u);
            if(2+length(n)>wr)wr=2+length(n);   # glyph(1)+space(1)+text
          }
          printf "┌%s┬%s┬%s┬%s┐\n", dash(wc+2), dash(ws+2), dash(wu+2), dash(wr+2);
          printf "│ %s │ %s │ %s │ %s │\n", pad("Chunk",wc), pad("Stage",ws), pad("Unit",wu), pad("Result",wr);
          printf "├%s┼%s┼%s┼%s┤\n", dash(wc+2), dash(ws+2), dash(wu+2), dash(wr+2);
          for(i=1;i<=total;i++)
            printf "│ %s │ %s │ %s │ %s %s │\n", pad(chunk[i],wc), pad(stg[i],ws), pad(unit[i],wu), glyph[i], pad(note[i], wr-2);
          printf "└%s┴%s┴%s┴%s┘\n", dash(wc+2), dash(ws+2), dash(wu+2), dash(wr+2);
        }' "$STATE"
    else
      echo "Chunk plan '$LABEL': ${_cur:-0}/${_total:-0} dispatched"
      awk -F'\t' '$1=="C"{cmd[$2]=$3} $1=="R"{res[$2]=$3} END{for(i=1;i<=length(cmd);i++){printf "  %s. %s", i, cmd[i]; if(i in res) printf "  →  %s", res[i]; print ""}}' "$STATE"
    fi
    ;;

  reset)
    rm -f "$STATE" 2>/dev/null || true
    echo "Chunk plan '$LABEL' reset."
    ;;

  list)
    _any=0
    for f in "$PROGRESS_DIR"/*.chunks; do
      [ -f "$f" ] || continue
      _any=1
      _l=$(awk -F'\t' '$1=="LABEL"{print $2}' "$f"); _t=$(awk -F'\t' '$1=="TOTAL"{print $2}' "$f"); _c=$(awk -F'\t' '$1=="CURRENT"{print $2}' "$f")
      printf '  %s — %s/%s dispatched\n' "${_l:-?}" "${_c:-0}" "${_t:-0}"
    done
    [ "$_any" -eq 0 ] && echo "(no active chunk plans in $PROGRESS_DIR)"
    ;;

  ""|-h|--help)
    grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "psk-chunked-run.sh: unknown command '$CMD' (plan|next|status|reset|list)" >&2
    exit 2 ;;
esac
