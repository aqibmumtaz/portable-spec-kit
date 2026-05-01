#!/bin/bash
# =============================================================
# test-release-check.sh — Pre-Release R→F→T Validation
#
# Reads SPECS.md → for every done feature (Fn marked [x]):
#   1. Checks a test reference exists in the Tests column
#   2. Checks the referenced test file exists on disk
#   3. Attempts to run the tests (auto-detects runner)
#   4. Reports: feature → test coverage + pass/fail
#
# Usage:
#   bash tests/test-release-check.sh                  # uses agent/SPECS.md
#   bash tests/test-release-check.sh path/to/SPECS.md # custom path
#
# Exit codes:
#   0 = all done features have passing tests (release ready)
#   1 = missing test refs, missing files, or test failures
# =============================================================

SPECS="${1:-agent/SPECS.md}"

if [ ! -f "$SPECS" ]; then
  echo "Error: SPECS.md not found at $SPECS"
  echo "Usage: bash tests/test-release-check.sh [path/to/SPECS.md]"
  exit 1
fi

# Closes QA-REL-NONDETERM-01 (v0.6.11): self-cleaning rft-cache invalidation.
# Without this, sequential invocations could read a stale cache value written
# by an earlier run and report different results on the same HEAD. gates.sh
# already clears the cache for its own callsites; this makes the script
# self-cleaning for ALL callers regardless of context. Bypass via
# PSK_RFT_KEEP_CACHE=1 when intentionally testing cached path.
if [ "${PSK_RFT_KEEP_CACHE:-0}" != "1" ]; then
  rm -f agent/.release-state/rft-cache.txt 2>/dev/null
fi

TOTAL_DONE=0
REF_PRESENT=0
FILE_EXISTS=0
TESTS_PASSED=0
MISSING_REFS=0
MISSING_FILES=0
TESTS_FAILED=0

# Cache: each unique test file is run only once — result reused for all features referencing it.
# Closes QA-PERF-PHASE0-01 (v0.6.11): persisted across invocations (was mktemp-per-call,
# meaning every call re-ran every referenced test from scratch). Now uses a persistent
# cache file that gets mtime-invalidated when any tests/*.sh changes. Effect: back-to-back
# invocations of this script in Phase 0 + sync-check no longer re-run the whole test suite,
# dropping Phase 0 wall-clock from ~74s to <10s on the kit. Bypass via PSK_TEST_REF_NO_CACHE=1.
TEST_REF_CACHE="agent/.release-state/test-ref-cache.txt"
TEST_REF_CACHE_KEY="agent/.release-state/test-ref-cache.key"
TEST_CACHE_FILE="$TEST_REF_CACHE"
mkdir -p "$(dirname "$TEST_REF_CACHE")" 2>/dev/null || true
# Cache invalidation (v0.6.25 + ADR-037 — closes QA-KIT-CACHE-01):
# Cache key = git HEAD SHA + cwd. Cache invalidates whenever HEAD changes OR
# cwd changes (closes QA-REL-NONDETERM-02 v0.6.28: previously running this
# script from a non-PROJ_ROOT cwd polluted the cache with cwd-relative test
# results that then "won" against canonical PROJ_ROOT runs) OR any tests/* /
# agent/scripts/* / src/ file is newer. Previous logic (v0.6.11) only
# checked tests/*.sh mtime; v0.6.25 added HEAD-SHA gating; v0.6.28 added cwd
# component to the cache key so per-cwd results don't cross-pollinate.
current_head=$(git rev-parse HEAD 2>/dev/null || echo "no-git")
current_cwd=$(pwd 2>/dev/null || echo "no-cwd")
current_key="${current_head}|${current_cwd}"
if [ -f "$TEST_REF_CACHE" ] && [ "${PSK_TEST_REF_NO_CACHE:-0}" != "1" ]; then
  cached_key=""
  [ -f "$TEST_REF_CACHE_KEY" ] && cached_key=$(cat "$TEST_REF_CACHE_KEY" 2>/dev/null || echo "")
  if [ "$current_key" != "$cached_key" ]; then
    rm -f "$TEST_REF_CACHE"
  else
    newer=$(find tests agent/scripts src 2>/dev/null -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.js" \) -newer "$TEST_REF_CACHE" 2>/dev/null | head -1)
    [ -n "$newer" ] && rm -f "$TEST_REF_CACHE"
  fi
elif [ "${PSK_TEST_REF_NO_CACHE:-0}" = "1" ]; then
  rm -f "$TEST_REF_CACHE"
fi
touch "$TEST_REF_CACHE" 2>/dev/null || true
echo "$current_key" > "$TEST_REF_CACHE_KEY" 2>/dev/null || true
# No EXIT trap — file persists for next invocation by design

# Detect test runner from project root
detect_runner() {
  local test_file="$1"
  if [ -f "package.json" ] && grep -q "jest\|vitest" "package.json" 2>/dev/null; then
    echo "jest"
  elif [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -f "setup.cfg" ]; then
    echo "pytest"
  elif [ -f "go.mod" ]; then
    echo "go"
  elif echo "$test_file" | grep -q "\.sh$"; then
    echo "bash"
  elif echo "$test_file" | grep -q "\.py$"; then
    echo "python"
  elif echo "$test_file" | grep -q "\.test\.js$\|\.spec\.js$\|\.test\.ts$\|\.spec\.ts$"; then
    echo "jest"
  else
    echo "unknown"
  fi
}

run_test() {
  local test_ref="$1"

  # Return cached result if this file was already run
  local cached
  cached=$(grep "^${test_ref}:" "$TEST_CACHE_FILE" 2>/dev/null | tail -1 | cut -d: -f2)
  if [ -n "$cached" ]; then return "$cached"; fi

  local runner result
  runner=$(detect_runner "$test_ref")

  case "$runner" in
    jest)
      if command -v npx >/dev/null 2>&1; then
        npx jest "$test_ref" --passWithNoTests 2>/dev/null && result=0 || result=1
      else result=2; fi ;;
    pytest)
      if command -v pytest >/dev/null 2>&1; then
        pytest "$test_ref" -q 2>/dev/null && result=0 || result=1
      elif command -v python3 >/dev/null 2>&1; then
        python3 -m pytest "$test_ref" -q 2>/dev/null && result=0 || result=1
      else result=2; fi ;;
    go)
      if command -v go >/dev/null 2>&1; then
        go test "./$test_ref/..." 2>/dev/null && result=0 || result=1
      else result=2; fi ;;
    bash)
      bash "$test_ref" >/dev/null 2>&1 && result=0 || result=1 ;;
    python)
      python3 "$test_ref" 2>/dev/null && result=0 || result=1 ;;
    *)
      result=2 ;;
  esac

  # Store in cache
  echo "${test_ref}:${result}" >> "$TEST_CACHE_FILE"
  return $result
}

check_stub_complete() {
  local test_ref="$1"
  local todo_count
  # Match standalone TODO comments and skip/placeholder assertions at line start
  # All patterns anchored to avoid false positives inside grep pattern strings
  todo_count=$(grep -E "^[[:space:]]*(#[[:space:]]*TODO|//[[:space:]]*TODO|test\.skip\(|it\.skip\(|xit\(|xtest\(|expect\(true\)\.toBe\(false\)|assert False|t\.Skip\()" "$test_ref" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$todo_count" -gt 0 ]; then
    echo "${test_ref}:stubs_incomplete:${todo_count}" >> "$TEST_CACHE_FILE"
    return 1
  fi
  return 0
}

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  RELEASE READINESS — R→F→T Coverage Check"
echo "  Specs: $SPECS"
echo "════════════════════════════════════════════════════════════"
echo ""
printf "  %-5s %-32s %-8s %s\n" "Fn" "Feature" "Status" "Tests"
printf "  %-5s %-32s %-8s %s\n" "-----" "--------------------------------" "--------" "-------"

while IFS= read -r line; do
  # Match feature rows with [x] done status
  if echo "$line" | grep -q "^| F[0-9]" && echo "$line" | grep -q "\[x\]"; then
    fn=$(echo "$line" | awk -F'|' '{gsub(/ /,"",$2); print $2}')
    feature=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}' | cut -c1-30)

    # Extract Tests column — last field that looks like a test file path
    # Test refs: no spaces, contain a dot or slash, look like file paths
    # e.g. tests/auth.test.js  tests/auth.sh  section-2
    test_ref=$(echo "$line" | awk -F'|' '{
      for (i=NF; i>1; i--) {
        gsub(/^ +| +$/, "", $i)
        # Must have no spaces AND look like a path (has / or . or starts with "tests" or "section")
        if ($i !~ / / && length($i) > 0 && ($i ~ /^tests\// || $i ~ /\.test\.|\.spec\.|\.sh$|\.py$|\.ts$|\.js$/)) {
          print $i; exit
        }
      }
    }')

    TOTAL_DONE=$((TOTAL_DONE + 1))

    if [ -z "$test_ref" ]; then
      printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "⚠  NO TEST REFERENCE"
      MISSING_REFS=$((MISSING_REFS + 1))

    elif [ ! -f "$test_ref" ] && [ ! -d "$test_ref" ]; then
      printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "✗  FILE NOT FOUND: $test_ref"
      REF_PRESENT=$((REF_PRESENT + 1))
      MISSING_FILES=$((MISSING_FILES + 1))

    else
      REF_PRESENT=$((REF_PRESENT + 1))
      FILE_EXISTS=$((FILE_EXISTS + 1))

      if ! check_stub_complete "$test_ref"; then
        stub_count=$(grep "^${test_ref}:stubs_incomplete:" "$TEST_CACHE_FILE" | cut -d: -f3)
        printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "✗  STUBS NOT FILLED ($stub_count TODO markers): $test_ref"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        continue
      fi

      run_test "$test_ref"
      run_result=$?

      if [ "$run_result" -eq 0 ]; then
        printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "✓  $test_ref"
        TESTS_PASSED=$((TESTS_PASSED + 1))
      elif [ "$run_result" -eq 2 ]; then
        printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "~  $test_ref (exists, run manually)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
      else
        printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "✗  FAILED: $test_ref"
        TESTS_FAILED=$((TESTS_FAILED + 1))
      fi
    fi
  fi
done < "$SPECS"

echo ""
echo "────────────────────────────────────────────────────────────"
printf "  Features complete:       %d\n" "$TOTAL_DONE"
printf "  With test references:    %d / %d\n" "$REF_PRESENT" "$TOTAL_DONE"
printf "  Test files found:        %d / %d\n" "$FILE_EXISTS" "$TOTAL_DONE"
printf "  Tests passing:           %d\n" "$TESTS_PASSED"
printf "  Tests failing:           %d\n" "$TESTS_FAILED"
printf "  Missing test refs:       %d\n" "$MISSING_REFS"
printf "  Missing test files:      %d\n" "$MISSING_FILES"
echo "────────────────────────────────────────────────────────────"

ISSUES=$((MISSING_REFS + MISSING_FILES + TESTS_FAILED))

if [ "$TOTAL_DONE" -eq 0 ]; then
  echo "  ⚠  No completed features found in SPECS.md"
  echo ""
  exit 1
elif [ "$ISSUES" -eq 0 ]; then
  COVERAGE=100
  echo "  ✅ RELEASE READY — $TOTAL_DONE features, 100% test coverage"
  echo ""
  exit 0
else
  COVERAGE=$(( (FILE_EXISTS * 100) / TOTAL_DONE ))
  echo "  ❌ NOT READY — $ISSUES issue(s) found ($COVERAGE% coverage)"
  [ "$MISSING_REFS" -gt 0 ] && echo "     → Add test references in SPECS.md Tests column for $MISSING_REFS feature(s)"
  [ "$MISSING_FILES" -gt 0 ] && echo "     → Create missing test files for $MISSING_FILES reference(s)"
  [ "$TESTS_FAILED" -gt 0 ]  && echo "     → Fix $TESTS_FAILED failing test(s) before release"
  echo ""
  exit 1
fi
