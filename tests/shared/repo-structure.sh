#!/usr/bin/env bash
# tests/shared/repo-structure.sh — assertion helpers for kit repo structure.
#
# Phase T4.1 (Loop 4) — extracted from sections/01-infrastructure.sh §1-§2.
# Sourced by features that assert kit-root file/dir presence:
#   features/f01-framework-file.sh    (portable-spec-kit.md, .gitignore)
#   features/f05-readme-template.sh   (README.md)
#   features/f08-opensource-readme.sh (CONTRIBUTING.md, LICENSE)
#   features/f09-sync-script.sh       (sync.sh, install.sh)
#   features/f22-version-format.sh    (CHANGELOG.md, RELEASES.md)
#
# All functions wrap pass/fail from lib.sh and operate on the global $PROJ
# (set by lib.sh to the kit-repo root). No state required from caller.
# Idempotent — safe to source multiple times.

# Guard against re-sourcing.
[ -n "${SHARED_REPO_STRUCTURE_LOADED:-}" ] && return 0
SHARED_REPO_STRUCTURE_LOADED=1

# assert_kit_root_file <file> [description]
# Asserts <file> exists at $PROJ/<file>.
assert_kit_root_file() {
  local file="$1"
  local desc="${2:-$file}"
  if [ -f "$PROJ/$file" ]; then
    pass "$desc exists"
  else
    fail "$desc MISSING"
  fi
}

# assert_kit_root_dir <dir> [description]
# Asserts <dir> exists as a directory at $PROJ/<dir>.
assert_kit_root_dir() {
  local dir="$1"
  local desc="${2:-$dir/}"
  if [ -d "$PROJ/$dir" ]; then
    pass "$desc dir exists"
  else
    fail "$desc dir MISSING"
  fi
}

# assert_in_gitignore <pattern>
# Asserts <pattern> appears as a line (with optional trailing slash) in $PROJ/.gitignore.
assert_in_gitignore() {
  local pattern="$1"
  if [ ! -f "$PROJ/.gitignore" ]; then
    fail ".gitignore missing — cannot check pattern $pattern"
    return
  fi
  if grep -qE "^${pattern}$|^${pattern}/$" "$PROJ/.gitignore"; then
    pass ".gitignore contains $pattern"
  else
    fail ".gitignore missing $pattern"
  fi
}

# assert_file_contains <relative-path> <regex> [description]
# Asserts $PROJ/<relative-path> exists AND contains <regex> (grep -E).
assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local desc="${3:-$file contains pattern}"
  if [ ! -f "$PROJ/$file" ]; then
    fail "$file missing for content check"
    return
  fi
  if grep -qE "$pattern" "$PROJ/$file"; then
    pass "$desc"
  else
    fail "$desc — pattern not found"
  fi
}

# assert_file_not_contains <relative-path> <regex> [description]
# Asserts $PROJ/<relative-path> exists AND does NOT contain <regex>.
assert_file_not_contains() {
  local file="$1"
  local pattern="$2"
  local desc="${3:-$file does not contain pattern}"
  if [ ! -f "$PROJ/$file" ]; then
    fail "$file missing for content check"
    return
  fi
  if grep -qE "$pattern" "$PROJ/$file"; then
    fail "$desc — pattern unexpectedly found"
  else
    pass "$desc"
  fi
}
