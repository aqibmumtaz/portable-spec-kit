#!/bin/bash
# mechanical-script: deterministic, no AI prompts (Dim 28 allowlist — v0.6.60 HF7b)
# =============================================================
# psk-install-hooks.sh — Install Claude Code + Git Hooks
#
# Installs reliability architecture hooks:
#   - .claude/settings.json (PostToolUse warning hook)
#   - .git/hooks/pre-commit (blocking hook — runs psk-sync-check.sh --quick; KIT-GAP-0075)
#   - .git/hooks/pre-push   (blocking hook — runs psk-sync-check.sh --full)
#   - .git/hooks/post-commit (refreshes PSK029 resume-bootstrap marker)
#
# Wraps existing hooks, never overwrites:
#   - Existing .git/hooks/pre-commit → chains our check before it
#   - Husky detected → adds our check to .husky/pre-commit
#   - pre-commit framework → suggests adding our check
#
# Usage:
#   bash agent/scripts/psk-install-hooks.sh          # install if missing
#   bash agent/scripts/psk-install-hooks.sh --force  # reinstall even if present
#   bash agent/scripts/psk-install-hooks.sh --status # check what's installed
#
# Exit codes:
#   0 = installed successfully (or already installed)
#   1 = installation failed
#   2 = configuration error (not in a git repo)
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
PROJ_ROOT="$(cd "$AGENT_DIR/.." 2>/dev/null && pwd)"

# --- Colors ---
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; CYAN=''; NC=''
fi

# --- Options ---
FORCE=false
STATUS_ONLY=false
while [ $# -gt 0 ]; do
  case "$1" in
    --force)   FORCE=true; shift ;;
    --status)  STATUS_ONLY=true; shift ;;
    *)         shift ;;
  esac
done

# --- Validate environment ---
GIT_ROOT=$(git -C "$PROJ_ROOT" rev-parse --show-toplevel 2>/dev/null)
if [ -z "$GIT_ROOT" ]; then
  echo -e "${RED}Error: Not inside a git repository (cd to project first)${NC}"
  exit 2
fi

if [ ! -f "$AGENT_DIR/scripts/psk-sync-check.sh" ]; then
  echo -e "${RED}Error: psk-sync-check.sh not found at $AGENT_DIR/scripts/${NC}"
  echo -e "${RED}       Install scripts first, then run this installer.${NC}"
  exit 2
fi

# Claude settings live in project dir; git hooks live in actual git root
CLAUDE_SETTINGS="$PROJ_ROOT/.claude/settings.json"
GIT_HOOK="$GIT_ROOT/.git/hooks/pre-commit"
GIT_POST_COMMIT_HOOK="$GIT_ROOT/.git/hooks/post-commit"
HUSKY_HOOK="$PROJ_ROOT/.husky/pre-commit"
PRE_COMMIT_CONFIG="$PROJ_ROOT/.pre-commit-config.yaml"

# --- Status check ---
show_status() {
  echo ""
  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  PSK HOOKS STATUS${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"

  if [ -f "$CLAUDE_SETTINGS" ]; then
    if grep -q "psk-sync-check" "$CLAUDE_SETTINGS" 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} Claude Code hook: .claude/settings.json (PostToolUse wired)"
    else
      echo -e "  ${YELLOW}⚠${NC} Claude Code settings exist but PSK hook not wired"
    fi
  else
    echo -e "  ${RED}✗${NC} Claude Code hook: .claude/settings.json (not installed)"
  fi

  if [ -f "$GIT_HOOK" ]; then
    if grep -q "psk-sync-check" "$GIT_HOOK" 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} Git pre-commit hook: .git/hooks/pre-commit (PSK wired)"
    else
      echo -e "  ${YELLOW}⚠${NC} Git pre-commit hook exists but PSK check not wired"
    fi
  else
    echo -e "  ${RED}✗${NC} Git pre-commit hook: .git/hooks/pre-commit (not installed)"
  fi

  if [ -f "$GIT_POST_COMMIT_HOOK" ]; then
    if grep -q "psk-resume-bootstrap-marker-refresh" "$GIT_POST_COMMIT_HOOK" 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} Git post-commit hook: .git/hooks/post-commit (PSK029 marker-refresh wired)"
    else
      echo -e "  ${YELLOW}⚠${NC} Git post-commit hook exists but PSK marker-refresh not wired"
    fi
  else
    echo -e "  ${RED}✗${NC} Git post-commit hook: .git/hooks/post-commit (not installed)"
  fi

  if [ -f "$HUSKY_HOOK" ]; then
    echo -e "  ${CYAN}ℹ${NC} Husky detected: .husky/pre-commit exists"
  fi

  if [ -f "$PRE_COMMIT_CONFIG" ]; then
    echo -e "  ${CYAN}ℹ${NC} pre-commit framework detected: .pre-commit-config.yaml exists"
  fi

  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
}

if [ "$STATUS_ONLY" = true ]; then
  show_status
  exit 0
fi

# --- Nested-workspace hook mirror (KIT-GAP / cycle-01/pass-002) ---
# When the kit is installed as a SUB-PROJECT of a larger git workspace (e.g.
# <workspace>/Projects/portable-spec-kit), the agent session runs at the workspace
# root, so Claude Code resolves hooks from <workspace>/.claude/settings.json — NOT
# the kit's own .claude/. Result: the UserPromptSubmit session-monitor + PostToolUse drift-check
# never fire, so the ctx:/opt: indicators have no data and silently suppress. Mirror
# the hooks into the workspace settings (paths RELATIVE TO THE WORKSPACE so they
# resolve from that cwd), merging into any existing settings via a python3 JSON merge
# (idempotent, never clobbers the operator's permissions/other keys). Runs regardless of
# whether the kit's own project-level hooks are already installed.
_wire_workspace_hooks() {
  [ -z "$GIT_ROOT" ] && return 0
  [ "$GIT_ROOT" = "$PROJ_ROOT" ] && return 0    # not nested — project hooks already apply
  local rel ws_settings mon_cmd base tmp_ws
  rel="${PROJ_ROOT#"$GIT_ROOT"/}"               # e.g. Projects/portable-spec-kit
  ws_settings="$GIT_ROOT/.claude/settings.json"
  # Mirror the UserPromptSubmit session-monitor (context-health is session-level, applies to any
  # session in the workspace) PLUS the statusLine — the STRUCTURAL always-on ctx badge that Claude
  # Code renders every turn regardless of the agent. The PostToolUse drift-check is kit-specific and
  # is deliberately NOT mirrored (it must not run the kit's sync-check on every edit to an unrelated
  # project in the same workspace).
  mon_cmd="bash $rel/agent/scripts/psk-session-monitor.sh"
  sl_cmd="$mon_cmd --statusline"
  # KIT-GAP-0147: mirror the chunked-drive guard too. Unlike the kit's sync-check drift-check,
  # the guard is SAFE in a shared workspace — it no-ops on any Bash command that is not a kit
  # long-op, and it MUST live in the workspace settings to fire (the session runs at the
  # workspace root, so Claude Code resolves PostToolUse from there, not the kit's own .claude/).
  guard_cmd="bash $rel/agent/scripts/psk-chunked-drive-guard.sh"
  # The merge runs through python3 — an established kit dependency (see psk-env.sh /
  # psk-spawn.sh / psk-sync-check.sh) that ships on macOS and every mainstream Linux. The
  # earlier implementation depended on a JSON CLI that is NOT universally present, and silently
  # left the workspace hooks unmirrored on any host that lacked it. python3 closes that gap so
  # the nested-workspace wiring now works everywhere without an extra tool install.
  if ! command -v python3 >/dev/null 2>&1; then
    echo -e "  ${YELLOW}⚠${NC} python3 not found — wire workspace settings manually in $ws_settings (UserPromptSubmit hook + statusLine → $mon_cmd)" >&2
    return 0
  fi
  mkdir -p "$GIT_ROOT/.claude"
  # One python3 invocation does BOTH the wired-state check AND the migrate-and-merge, so the
  # JSON is parsed once. Contract (exit codes):
  #   0  = merged + written (or would-write); stdout = status keyword
  #   10 = already fully wired (monitor under UserPromptSubmit, none under Stop, statusLine set)
  #         → skip unless --force
  #   1  = parse / write error → leave file unchanged
  # The merge is idempotent and never clobbers an operator's custom statusLine or other keys:
  #   - strip the monitor from any legacy .hooks.Stop wiring (the loop bug from an old build)
  #   - ensure the monitor is present exactly once under .hooks.UserPromptSubmit
  #   - set .statusLine only if absent
  local force_flag="0"; [ "$FORCE" = true ] && force_flag="1"
  local py_status
  py_status=$(MON="$mon_cmd" SL="$sl_cmd" GUARD="$guard_cmd" WS="$ws_settings" FORCE_FLAG="$force_flag" python3 - <<'PY'
import json, os, sys, time, shutil

mon   = os.environ["MON"]
sl    = os.environ["SL"]
guard = os.environ["GUARD"]
ws    = os.environ["WS"]
force = os.environ.get("FORCE_FLAG", "0") == "1"

data = {}
if os.path.exists(ws):
    try:
        with open(ws, "r") as f:
            txt = f.read().strip()
        data = json.loads(txt) if txt else {}
        if not isinstance(data, dict):
            data = {}
    except Exception:
        # unparseable existing settings — treat as empty base, but back it up below
        data = {}

def cmds(event):
    out = []
    for grp in data.get("hooks", {}).get(event, []) or []:
        if isinstance(grp, dict):
            for h in grp.get("hooks", []) or []:
                if isinstance(h, dict) and "command" in h:
                    out.append(h["command"])
    return out

fully_wired = (mon in cmds("UserPromptSubmit")
               and mon not in cmds("Stop")
               and guard in cmds("PostToolUse")
               and data.get("statusLine") is not None)

if fully_wired and not force and os.path.exists(ws):
    print("already-wired")
    sys.exit(10)

# --- migrate + merge (idempotent) ---
data.setdefault("hooks", {})
hooks = data["hooks"]

# 1. strip the monitor from any legacy Stop wiring; drop now-empty Stop groups / key
if isinstance(hooks.get("Stop"), list):
    new_stop = []
    for grp in hooks["Stop"]:
        if isinstance(grp, dict):
            grp = dict(grp)
            grp["hooks"] = [h for h in (grp.get("hooks") or [])
                            if not (isinstance(h, dict) and h.get("command") == mon)]
            if grp.get("hooks"):
                new_stop.append(grp)
        else:
            new_stop.append(grp)
    if new_stop:
        hooks["Stop"] = new_stop
    else:
        hooks.pop("Stop", None)

# 2. ensure monitor present exactly once under UserPromptSubmit
ups = hooks.setdefault("UserPromptSubmit", [])
if mon not in cmds("UserPromptSubmit"):
    ups.append({"hooks": [{"type": "command", "command": mon}]})

# 3. set statusLine only if absent (never clobber an operator's custom one)
if data.get("statusLine") is None:
    data["statusLine"] = {"type": "command", "command": sl, "padding": 0}

# 4. KIT-GAP-0147: ensure the chunked-drive guard is present exactly once under a
#    PostToolUse Bash matcher (idempotent; safe — no-ops on non-kit commands).
if guard not in cmds("PostToolUse"):
    ptu = hooks.setdefault("PostToolUse", [])
    ptu.append({"matcher": "Bash", "hooks": [{"type": "command", "command": guard}]})

# back up an existing file before overwrite
if os.path.exists(ws):
    try:
        shutil.copy2(ws, ws + ".psk-backup." + str(int(time.time())))
    except Exception:
        pass

tmp = ws + ".tmp." + str(os.getpid())
try:
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    json.loads(open(tmp).read())   # validate before swap
    os.replace(tmp, ws)            # atomic
except Exception as e:
    try:
        os.remove(tmp)
    except Exception:
        pass
    sys.stderr.write("merge error: %s\n" % e)
    sys.exit(1)
print("merged")
sys.exit(0)
PY
)
  local py_rc=$?
  if [ "$py_rc" -eq 10 ]; then
    echo -e "  ${YELLOW}⚠${NC} Workspace session-monitor + statusLine already wired ($ws_settings) — use --force"
    return 0
  elif [ "$py_rc" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Mirrored session-monitor (UserPromptSubmit) + statusLine into workspace settings (nested kit): $ws_settings"
  else
    echo -e "  ${RED}✗${NC} Could not merge workspace settings — left unchanged: $ws_settings" >&2
  fi
}

# --- Install Claude Code hooks ---
install_claude_hook() {
  echo -e "${CYAN}Installing Claude Code hooks...${NC}"

  # Mirror hooks into the workspace settings first — this must run even when the
  # kit's own project-level settings are already installed (the early-return below).
  _wire_workspace_hooks

  mkdir -p "$PROJ_ROOT/.claude"

  if [ -f "$CLAUDE_SETTINGS" ]; then
    if grep -q "psk-sync-check" "$CLAUDE_SETTINGS" 2>/dev/null && [ "$FORCE" = false ]; then
      echo -e "  ${YELLOW}⚠${NC} Already installed. Use --force to reinstall."
      return 0
    fi

    # Back up existing settings
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.psk-backup.$(date +%s)" 2>/dev/null || true
    echo -e "  ${CYAN}ℹ${NC} Backed up existing .claude/settings.json"
  fi

  # Write new settings: statusLine (structural always-on ctx badge) + PostToolUse drift-check
  # + UserPromptSubmit session-monitor. The statusLine renders the ctx (+opt) badge in the Claude
  # Code status bar EVERY turn, agent-independent — the user always sees ctx even if the agent skips
  # its breadcrumb. The UserPromptSubmit hook (psk-session-monitor.sh) reads the live transcript,
  # injects the ctx: badge as additionalContext each user turn (so the agent can also render it in the
  # breadcrumb), and recommends /clear ONLY when context is genuinely high (stateful de-dup — one
  # notice per band, never nags, re-arms after a clear). It is NOT a Stop hook: a Stop hook returning
  # additionalContext would re-invoke the agent every turn (infinite loop). Fail-safe: silent on any error.
  cat > "$CLAUDE_SETTINGS" <<'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "bash agent/scripts/psk-session-monitor.sh --statusline",
    "padding": 0
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash agent/scripts/psk-sync-check.sh --quick"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash agent/scripts/psk-chunked-drive-guard.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash agent/scripts/psk-session-monitor.sh"
          }
        ]
      }
    ]
  }
}
EOF

  echo -e "  ${GREEN}✓${NC} Created .claude/settings.json"
}

# --- Safe hook write helper (KIT-GAP-0013 fix, v0.6.67) ---
# Writes a hook atomically with a bash -n syntax check before committing.
# If syntax check fails, restores from .psk-backup (if any) and exits 1.
#
# Usage: safe_install_hook <dest> <tmp_content_file>
safe_install_hook() {
  local dest="$1"
  local tmp="$2"

  # Syntax check the proposed content BEFORE moving into place
  if ! bash -n "$tmp" 2>/tmp/psk-hook-syntax.err; then
    echo -e "  ${RED}✗${NC} Generated hook has syntax errors — aborting install:" >&2
    sed 's/^/    /' < /tmp/psk-hook-syntax.err >&2
    # Restore latest backup if exists
    local latest_backup
    latest_backup=$(ls -t "${dest}.psk-backup."* 2>/dev/null | head -1)
    if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
      cp "$latest_backup" "$dest" 2>/dev/null || true
      echo -e "  ${YELLOW}⚠${NC} Restored from $latest_backup" >&2
    fi
    rm -f "$tmp"
    return 1
  fi

  # Atomic move
  mv "$tmp" "$dest"
  chmod +x "$dest"
  return 0
}

# --- Install git pre-commit hook ---
install_git_hook() {
  # QA-D31-001 (cycle-01 follow-up — FIXED): the hook bodies emitted below (and
  # in install_git_pre_push_hook / install_git_post_commit_hook) anchor the repo
  # root DETERMINISTICALLY rather than relying on ambient CWD. The prior bodies
  # used a bare `git rev-parse --show-toplevel`, which resolves correctly only
  # because git invokes hooks with CWD at the worktree top — a true but fragile
  # assumption (a hook sourced/exec'd from another tool, a `cd` earlier in a
  # wrapped/preserved hook body, or a future caller breaks it silently). The
  # installer already KNOWS the git root at install time ($GIT_ROOT), so each
  # generated hook now bakes `PSK_REPO_ROOT='<git-root>'` as the primary anchor
  # and falls back to `git rev-parse --show-toplevel` only if that baked path no
  # longer exists (repo moved post-install). No dependence on the hook's CWD.
  echo -e "${CYAN}Installing git pre-commit hook...${NC}"

  local tmp
  tmp=$(mktemp)

  if [ -f "$GIT_HOOK" ]; then
    if grep -q "psk-sync-check" "$GIT_HOOK" 2>/dev/null && [ "$FORCE" = false ]; then
      echo -e "  ${YELLOW}⚠${NC} Already installed. Use --force to reinstall."
      rm -f "$tmp"
      return 0
    fi

    # Back up existing hook
    cp "$GIT_HOOK" "$GIT_HOOK.psk-backup.$(date +%s)" 2>/dev/null || true
    echo -e "  ${CYAN}ℹ${NC} Backed up existing .git/hooks/pre-commit"

    # Wrap existing hook: extract original content, drop shebang + any prior PSK marker line
    local existing_content
    existing_content=$(grep -v "^#!" "$GIT_HOOK" 2>/dev/null | grep -v "psk-sync-check")

    # KIT-GAP-0013 fix: validate existing_content before splicing. If the
    # extracted body is non-trivial but has unbalanced quotes / backticks /
    # unterminated heredocs, splicing it into our template will produce a
    # broken hook. Test the body in isolation first.
    if [ -n "$existing_content" ]; then
      local body_check
      body_check=$(mktemp)
      printf '#!/bin/bash\n%s\nexit 0\n' "$existing_content" > "$body_check"
      if ! bash -n "$body_check" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} Existing hook body has syntax issues — skipping preservation, installing PSK-only hook" >&2
        existing_content=""
      fi
      rm -f "$body_check"
    fi

    cat > "$tmp" <<EOF
#!/bin/bash
# PSK pre-commit hook (installed by psk-install-hooks.sh)
# Emergency bypass: PSK_SYNC_CHECK_DISABLED=1 git commit ...
# Or: git commit --no-verify

# KIT-GAP-0015 fix (v0.6.68): skip sync-check during merge commits.
# Big merges (100+ files) caused sync-check's internal git operations to
# fan out into hundreds of parallel sub-processes that exhausted system
# resources before completing. Merge commits don't introduce logical
# drift on their own — the constituent commits already ran the check.
# QA-D31-001: repo root baked at install time (deterministic, no CWD dependence);
# runtime rev-parse is a fallback only if the baked path moved post-install.
PSK_REPO_ROOT="$GIT_ROOT"
if [ ! -d "\$PSK_REPO_ROOT" ]; then PSK_REPO_ROOT="\$(git rev-parse --show-toplevel 2>/dev/null)"; fi
REPO_ROOT="\$PSK_REPO_ROOT"
if [ -n "\$REPO_ROOT" ] && [ -f "\$REPO_ROOT/.git/MERGE_HEAD" ]; then
  echo "PSK pre-commit: skipping sync-check during merge commit (KIT-GAP-0015)" >&2
  exit 0
fi

SCRIPT="\$REPO_ROOT/agent/scripts/psk-sync-check.sh"
if [ -x "\$SCRIPT" ]; then
  # KIT-GAP-0075 (v0.6.83): pre-commit runs the FAST --quick gate (sub-second)
  # so commits stay fast and agents never reach for --no-verify. The deep
  # --full sweep runs in the pre-push hook + prep-release + reflex gates + CI.
  bash "\$SCRIPT" --quick || exit 1
fi

# --- Original pre-commit hook content (preserved) ---
$existing_content
exit 0
EOF
  else
    # Fresh install. Heredoc is unquoted (<<EOF) so $GIT_ROOT bakes the repo
    # root at install time (QA-D31-001 deterministic anchor); all RUNTIME shell
    # refs are escaped (\$) so they expand when the hook runs, not now.
    cat > "$tmp" <<EOF
#!/bin/bash
# PSK pre-commit hook (installed by psk-install-hooks.sh)
# Emergency bypass: PSK_SYNC_CHECK_DISABLED=1 git commit ...
# Or: git commit --no-verify

# KIT-GAP-0015 fix (v0.6.68): skip sync-check during merge commits.
# Big merges (100+ files) caused sync-check's internal git operations to
# fan out into hundreds of parallel sub-processes that exhausted system
# resources before completing. Merge commits don't introduce logical
# drift on their own — the constituent commits already ran the check.
# QA-D31-001: repo root baked at install time (deterministic, no CWD dependence);
# runtime rev-parse is a fallback only if the baked path moved post-install.
PSK_REPO_ROOT="$GIT_ROOT"
if [ ! -d "\$PSK_REPO_ROOT" ]; then PSK_REPO_ROOT="\$(git rev-parse --show-toplevel 2>/dev/null)"; fi
REPO_ROOT="\$PSK_REPO_ROOT"
if [ -n "\$REPO_ROOT" ] && [ -f "\$REPO_ROOT/.git/MERGE_HEAD" ]; then
  echo "PSK pre-commit: skipping sync-check during merge commit (KIT-GAP-0015)" >&2
  exit 0
fi

SCRIPT="\$REPO_ROOT/agent/scripts/psk-sync-check.sh"
if [ -x "\$SCRIPT" ]; then
  # KIT-GAP-0075 (v0.6.83): fast --quick gate on commit; --full at pre-push.
  bash "\$SCRIPT" --quick || exit 1
fi
exit 0
EOF
  fi

  if safe_install_hook "$GIT_HOOK" "$tmp"; then
    echo -e "  ${GREEN}✓${NC} Created .git/hooks/pre-commit"
  else
    return 1
  fi
}

# --- Install git pre-push hook (KIT-GAP-0075 — deep --full gate before remote) ---
# pre-commit runs --quick (fast, every commit). The full PSK-rule sweep runs
# here, before anything reaches the remote — so slow checks don't gate every
# commit (which drove --no-verify usage) but bad commits are still caught
# pre-push, in addition to prep-release + reflex gates + CI.
install_git_pre_push_hook() {
  echo -e "${CYAN}Installing git pre-push hook (--full deep gate)...${NC}"
  local pp_hook="$GIT_ROOT/.git/hooks/pre-push"
  if [ -f "$pp_hook" ] && grep -q "psk-sync-check" "$pp_hook" 2>/dev/null && [ "$FORCE" = false ]; then
    echo -e "  ${YELLOW}⚠${NC} Already installed. Use --force to reinstall."
    return 0
  fi
  local tmp
  tmp=$(mktemp)
  # Unquoted heredoc (<<EOF): $GIT_ROOT bakes the repo root at install time
  # (QA-D31-001 deterministic anchor); runtime shell refs are escaped (\$).
  cat > "$tmp" <<EOF
#!/bin/bash
# PSK pre-push hook (installed by psk-install-hooks.sh) — KIT-GAP-0075.
# Deep --full sync-check before anything reaches the remote.
# Emergency bypass: PSK_SYNC_CHECK_DISABLED=1 git push  (or: git push --no-verify)
if [ "\${PSK_SYNC_CHECK_DISABLED:-0}" = "1" ]; then exit 0; fi
# QA-D31-001: repo root baked at install time (no CWD dependence); rev-parse fallback only.
PSK_REPO_ROOT="$GIT_ROOT"
if [ ! -d "\$PSK_REPO_ROOT" ]; then PSK_REPO_ROOT="\$(git rev-parse --show-toplevel 2>/dev/null)"; fi
REPO_ROOT="\$PSK_REPO_ROOT"
SCRIPT="\$REPO_ROOT/agent/scripts/psk-sync-check.sh"
if [ -x "\$SCRIPT" ]; then
  bash "\$SCRIPT" --full || exit 1
fi
exit 0
EOF
  if safe_install_hook "$pp_hook" "$tmp"; then
    echo -e "  ${GREEN}✓${NC} Created .git/hooks/pre-push"
  else
    return 1
  fi
}

# --- Install git post-commit hook (refreshes PSK029 resume-bootstrap marker) ---
# QA-D15 fix: PSK029 re-stales after every commit. The marker is meant to
# detect "session started without resume-bootstrap", not "commit landed
# without resume-bootstrap". A post-commit hook refreshes the marker
# automatically so normal kit activity keeps PSK029 clean.
install_git_post_commit_hook() {
  echo -e "${CYAN}Installing git post-commit hook (PSK029 marker refresh)...${NC}"

  local tmp
  tmp=$(mktemp)

  if [ -f "$GIT_POST_COMMIT_HOOK" ]; then
    if grep -q "psk-resume-bootstrap-marker-refresh" "$GIT_POST_COMMIT_HOOK" 2>/dev/null && [ "$FORCE" = false ]; then
      echo -e "  ${YELLOW}⚠${NC} Already installed. Use --force to reinstall."
      rm -f "$tmp"
      return 0
    fi

    # Back up existing hook
    cp "$GIT_POST_COMMIT_HOOK" "$GIT_POST_COMMIT_HOOK.psk-backup.$(date +%s)" 2>/dev/null || true
    echo -e "  ${CYAN}ℹ${NC} Backed up existing .git/hooks/post-commit"

    # Wrap existing hook: add our marker refresh before it
    local existing_content
    existing_content=$(grep -v "^#!" "$GIT_POST_COMMIT_HOOK" 2>/dev/null | grep -v "psk-resume-bootstrap-marker-refresh")

    # KIT-GAP-0013 fix: validate existing_content syntax before splicing.
    if [ -n "$existing_content" ]; then
      local body_check
      body_check=$(mktemp)
      printf '#!/bin/bash\n%s\nexit 0\n' "$existing_content" > "$body_check"
      if ! bash -n "$body_check" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} Existing hook body has syntax issues — skipping preservation, installing PSK-only hook" >&2
        existing_content=""
      fi
      rm -f "$body_check"
    fi

    cat > "$tmp" <<EOF
#!/bin/bash
# PSK post-commit hook (installed by psk-install-hooks.sh)
# Marker: psk-resume-bootstrap-marker-refresh
# Refreshes session-audit.log marker so PSK029 stays clean on every commit.
# Emergency bypass: PSK_POST_COMMIT_DISABLED=1 git commit ...

if [ "\${PSK_POST_COMMIT_DISABLED:-0}" != "1" ]; then
  # QA-D31-001: repo root baked at install time (deterministic, no CWD dependence);
  # runtime rev-parse is a fallback only if the baked path moved post-install.
  ROOT="$GIT_ROOT"
  if [ ! -d "\$ROOT" ]; then ROOT="\$(git rev-parse --show-toplevel 2>/dev/null)"; fi
  if [ -n "\$ROOT" ] && [ -d "\$ROOT" ]; then
    LOG_DIR="\$ROOT/agent/.workflow-state"
    if [ -d "\$LOG_DIR" ]; then
      LOG_FILE="\$LOG_DIR/session-audit.log"
      TS=\$(date -u +%Y-%m-%dT%H:%M:%SZ)
      echo "\$TS session-start-resume-check ran (auto: post-commit hook)" >> "\$LOG_FILE"
    fi
  fi
fi

# --- Original post-commit hook content (preserved) ---
$existing_content
exit 0
EOF
  else
    # Fresh install. Unquoted heredoc (<<EOF): $GIT_ROOT bakes the repo root at
    # install time (QA-D31-001 deterministic anchor); runtime refs escaped (\$).
    cat > "$tmp" <<EOF
#!/bin/bash
# PSK post-commit hook (installed by psk-install-hooks.sh)
# Marker: psk-resume-bootstrap-marker-refresh
# Refreshes session-audit.log marker so PSK029 stays clean on every commit.
# Emergency bypass: PSK_POST_COMMIT_DISABLED=1 git commit ...

if [ "\${PSK_POST_COMMIT_DISABLED:-0}" != "1" ]; then
  # QA-D31-001: repo root baked at install time (no CWD dependence); rev-parse fallback only.
  ROOT="$GIT_ROOT"
  if [ ! -d "\$ROOT" ]; then ROOT="\$(git rev-parse --show-toplevel 2>/dev/null)"; fi
  if [ -n "\$ROOT" ] && [ -d "\$ROOT" ]; then
    LOG_DIR="\$ROOT/agent/.workflow-state"
    if [ -d "\$LOG_DIR" ]; then
      LOG_FILE="\$LOG_DIR/session-audit.log"
      TS=\$(date -u +%Y-%m-%dT%H:%M:%SZ)
      echo "\$TS session-start-resume-check ran (auto: post-commit hook)" >> "\$LOG_FILE"
    fi
  fi
fi
exit 0
EOF
  fi

  if safe_install_hook "$GIT_POST_COMMIT_HOOK" "$tmp"; then
    echo -e "  ${GREEN}✓${NC} Created .git/hooks/post-commit"
  else
    return 1
  fi
}

# --- Detect Husky and advise ---
check_husky() {
  if [ -f "$HUSKY_HOOK" ]; then
    echo ""
    echo -e "${YELLOW}⚠ Husky detected at .husky/pre-commit${NC}"
    echo -e "  PSK installed a git hook at .git/hooks/pre-commit."
    echo -e "  If Husky manages your hooks, add this line to .husky/pre-commit:"
    echo ""
    echo -e "    ${CYAN}bash agent/scripts/psk-sync-check.sh --full || exit 1${NC}"
    echo ""
  fi
}

# --- Detect pre-commit framework and advise ---
check_pre_commit_framework() {
  if [ -f "$PRE_COMMIT_CONFIG" ]; then
    echo ""
    echo -e "${YELLOW}⚠ pre-commit framework detected at .pre-commit-config.yaml${NC}"
    echo -e "  PSK installed a git hook at .git/hooks/pre-commit."
    echo -e "  If pre-commit framework manages your hooks, add this to .pre-commit-config.yaml:"
    echo ""
    echo -e "    ${CYAN}- repo: local${NC}"
    echo -e "    ${CYAN}  hooks:${NC}"
    echo -e "    ${CYAN}    - id: psk-sync-check${NC}"
    echo -e "    ${CYAN}      name: psk-sync-check${NC}"
    echo -e "    ${CYAN}      entry: bash agent/scripts/psk-sync-check.sh --full${NC}"
    echo -e "    ${CYAN}      language: system${NC}"
    echo -e "    ${CYAN}      pass_filenames: false${NC}"
    echo ""
  fi
}

# --- Smoke test: run sync-check ---
smoke_test() {
  echo ""
  echo -e "${CYAN}Smoke test: running psk-sync-check.sh --quick...${NC}"
  if bash "$AGENT_DIR/scripts/psk-sync-check.sh" --quick 2>&1; then
    echo -e "  ${GREEN}✓${NC} Sync-check passes — hooks are ready"
  else
    echo -e "  ${YELLOW}⚠${NC} Sync-check reported issues (not a failure — hooks still installed)"
  fi
}

# --- Main ---
main() {
  echo ""
  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  PSK HOOKS INSTALLER${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"

  install_claude_hook
  install_git_hook
  install_git_pre_push_hook
  install_git_post_commit_hook
  check_husky
  check_pre_commit_framework
  smoke_test

  echo ""
  echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✓ HOOKS INSTALLED${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  Your commits are now protected by psk-sync-check.sh."
  echo -e "  Edit notifications via PostToolUse in Claude Code."
  echo -e ""
  echo -e "  Emergency bypass: ${YELLOW}PSK_SYNC_CHECK_DISABLED=1 git commit ...${NC}"
  echo -e "  Full bypass:      ${YELLOW}git commit --no-verify${NC}"
  echo ""
}

main
