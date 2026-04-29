<!-- Section Version: v0.5.6 -->**tests/test-release-check.sh:**
```bash
#!/bin/bash
# =============================================================
# release-check.sh — Pre-Release R→F→T Validation
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

TOTAL_DONE=0
REF_PRESENT=0
FILE_EXISTS=0
TESTS_PASSED=0
MISSING_REFS=0
MISSING_FILES=0
TESTS_FAILED=0

# Cache: each unique test file is run only once — result reused for all features referencing it
TEST_CACHE_FILE=$(mktemp)
trap "rm -f $TEST_CACHE_FILE" EXIT

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

  echo "${test_ref}:${result}" >> "$TEST_CACHE_FILE"
  return $result
}

check_stub_complete() {
  local test_ref="$1"
  local todo_count
  # Match standalone TODO comments and skip/placeholder assertions at line start
  # All patterns anchored to avoid false positives inside grep pattern strings
  todo_count=$(grep -cE "^[[:space:]]*(#[[:space:]]*TODO|//[[:space:]]*TODO|test\.skip\(|it\.skip\(|xit\(|xtest\(|expect\(true\)\.toBe\(false\)|assert False|t\.Skip\()" "$test_ref" 2>/dev/null || echo 0)
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
  if echo "$line" | grep -q "^| F[0-9]" && echo "$line" | grep -q "\[x\]"; then
    fn=$(echo "$line" | awk -F'|' '{gsub(/ /,"",$2); print $2}')
    feature=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}' | cut -c1-30)
    test_ref=$(echo "$line" | awk -F'|' '{
      for (i=NF; i>1; i--) {
        gsub(/^ +| +$/, "", $i)
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
      run_test "$test_ref"; run_result=$?
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
  echo "  ⚠  No completed features found in SPECS.md"; echo ""; exit 1
elif [ "$ISSUES" -eq 0 ]; then
  echo "  ✅ RELEASE READY — $TOTAL_DONE features, 100% test coverage"; echo ""; exit 0
else
  COVERAGE=$(( (FILE_EXISTS * 100) / TOTAL_DONE ))
  echo "  ❌ NOT READY — $ISSUES issue(s) found ($COVERAGE% coverage)"
  [ "$MISSING_REFS" -gt 0 ] && echo "     → Add test references in SPECS.md Tests column for $MISSING_REFS feature(s)"
  [ "$MISSING_FILES" -gt 0 ] && echo "     → Create missing test files for $MISSING_FILES reference(s)"
  [ "$TESTS_FAILED" -gt 0 ]  && echo "     → Fix $TESTS_FAILED failing test(s) before release"
  echo ""; exit 1
fi
```
