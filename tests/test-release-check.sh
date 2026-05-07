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
IRRELEVANT_TESTS=0  # v0.6.29 G21 — count of test files that don't mention their feature

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
  # QA-KIT-RUNNER-DETECT-01 (searchsocialtruth-cycle-05): explicit
  # vitest / mocha / tap detection — used to fall through to "jest" for
  # any vitest project, which broke npx invocation. Match in priority
  # order: vitest > mocha > tap > jest > pytest > go > extension fallback.
  if [ -f "package.json" ]; then
    if grep -q '"vitest"' "package.json" 2>/dev/null; then
      echo "vitest"; return 0
    elif grep -q '"mocha"' "package.json" 2>/dev/null; then
      echo "mocha"; return 0
    elif grep -q '"tap"' "package.json" 2>/dev/null; then
      echo "tap"; return 0
    elif grep -q '"jest"' "package.json" 2>/dev/null; then
      echo "jest"; return 0
    fi
  fi
  if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -f "setup.cfg" ]; then
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
  # Closes QA-KIT-CACHE-POISON-01 (cycle-05): only PASS results (result=0)
  # are cached. Failures (result=1) and unknowns (result=2) are NOT cached
  # and will be re-run on the next invocation. Rationale: a transient
  # failure (flaky test, race condition, environment glitch) used to stick
  # in the cache forever — even after the test starts passing — because
  # the upstream invalidation logic only triggers on test-file mtime change
  # or HEAD/cwd change. Tests that pass without source modification but
  # had a prior transient fail were stuck reporting failure.
  # Net effect: passes still cached (the common case, full perf benefit);
  # failures always re-run (cheap because rare). No false-positive sticky
  # failures.
  local cached
  cached=$(grep "^${test_ref}:" "$TEST_CACHE_FILE" 2>/dev/null | tail -1 | cut -d: -f2)
  if [ "$cached" = "0" ]; then return 0; fi
  # On any non-zero or empty cached entry, fall through to re-run.
  # If a stale failure was cached, remove it so the new (potentially
  # passing) result has a clean slot to write into.
  if [ -n "$cached" ] && [ "$cached" != "0" ]; then
    # Strip the stale entry from the cache file in-place (BSD/GNU compatible).
    if [ -f "$TEST_CACHE_FILE" ]; then
      grep -v "^${test_ref}:" "$TEST_CACHE_FILE" > "${TEST_CACHE_FILE}.tmp" 2>/dev/null \
        && mv "${TEST_CACHE_FILE}.tmp" "$TEST_CACHE_FILE" \
        || rm -f "${TEST_CACHE_FILE}.tmp" 2>/dev/null
    fi
  fi

  local runner result
  runner=$(detect_runner "$test_ref")

  case "$runner" in
    jest)
      if command -v npx >/dev/null 2>&1; then
        npx jest "$test_ref" --passWithNoTests 2>/dev/null && result=0 || result=1
      else result=2; fi ;;
    vitest)
      if command -v npx >/dev/null 2>&1; then
        npx vitest run "$test_ref" --passWithNoTests 2>/dev/null && result=0 || result=1
      else result=2; fi ;;
    mocha)
      if command -v npx >/dev/null 2>&1; then
        npx mocha "$test_ref" 2>/dev/null && result=0 || result=1
      else result=2; fi ;;
    tap)
      if command -v npx >/dev/null 2>&1; then
        npx tap "$test_ref" 2>/dev/null && result=0 || result=1
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
      # M1 (Loop-3) — explicit env propagation into nested test invocation.
      # `bash "$test_ref"` would inherit only exported env vars from the
      # caller; some kit-bypass flags (set by gates / Phase 0 helpers) are
      # consumed by test-spec-kit.sh + sibling runners and need to be
      # forwarded deterministically. Wrap with `env` so the bypass-flag
      # contract holds across sub-shells regardless of how the parent
      # exported (or didn't export) them. Defaults preserve "off" semantics
      # when the caller didn't set the flag.
      env \
        PSK_REQS_COVERAGE_DISABLED="${PSK_REQS_COVERAGE_DISABLED:-0}" \
        PSK_FEATURE_CRITERIA_STRICT="${PSK_FEATURE_CRITERIA_STRICT:-0}" \
        PSK_TEST_REF_NO_CACHE="${PSK_TEST_REF_NO_CACHE:-0}" \
        PSK_UI_REQS_COVERAGE_DISABLED="${PSK_UI_REQS_COVERAGE_DISABLED:-0}" \
        PSK_RFT_KEEP_CACHE="${PSK_RFT_KEEP_CACHE:-0}" \
        bash "$test_ref" >/dev/null 2>&1 && result=0 || result=1 ;;
    python)
      python3 "$test_ref" 2>/dev/null && result=0 || result=1 ;;
    *)
      result=2 ;;
  esac

  # Store in cache ONLY if the test passed.
  # Closes QA-KIT-CACHE-POISON-01: failures/unknowns are not persisted
  # so the next invocation will re-attempt them.
  if [ "$result" = "0" ]; then
    echo "${test_ref}:${result}" >> "$TEST_CACHE_FILE"
  fi
  return $result
}

check_test_relevance() {
  # v0.6.29 fix (G21 — QA-KIT-RELEASE-CHECK-01): verify the cited test file
  # actually exercises the named feature. Previously release-check validated
  # only "file exists + tests pass" — projects could cite any green test for
  # any feature and pass with ✅ RELEASE READY. Now we require the test file
  # to reference the feature ID (case-insensitive, e.g. "F1" / "f1") OR a
  # feature-specific symbol the agent extracts from the SPECS row.
  #
  # H4 / QA-KIT-RELEVANCE-NOISE-01 (searchsocialtruth-cycle-05): the F{N}
  # heuristic flagged 59/70 kit features as "possibly irrelevant" because
  # kit-self maps every feature to tests/test-spec-kit.sh (a comprehensive
  # orchestrator) where individual F-IDs are not literal tokens — sections
  # carry N{N} identifiers instead. Mode-aware fix: detect kit-self via
  # the v0.6.28 discriminator (examples/ + tests/sections/ + install.sh +
  # agent/PHILOSOPHY.md) and accept N{N} section references OR feature
  # keyword matches as evidence of relevance.
  #
  # Strategy: pass if the test file contains either:
  #   1. The feature ID literally (`F1`, `f1`)            — projects + kit
  #   2. (Kit-self only) any N{N} section reference        — kit
  #   3. A keyword from the feature description            — projects + kit
  local test_ref="$1"
  local fn="$2"        # feature ID e.g. F1
  local feature="$3"   # feature description for keyword match
  if [ -z "$fn" ] || [ -z "$test_ref" ]; then return 0; fi
  # Quick win: feature ID literal
  if grep -qiE "\\b${fn}\\b" "$test_ref" 2>/dev/null; then return 0; fi
  # H4: kit-self mode — accept N{N} section presence as relevance evidence.
  # Detect kit-self via v0.6.28 discriminator: examples/ + tests/sections/
  # + install.sh + agent/PHILOSOPHY.md all present at PWD.
  if [ -d "examples" ] && [ -d "tests/sections" ] && [ -f "install.sh" ] && [ -f "agent/PHILOSOPHY.md" ]; then
    if grep -qE "\\bN[0-9]+\\b" "$test_ref" 2>/dev/null; then return 0; fi
  fi
  # Fallback: keyword match (any meaningful 4+-char word from feature description)
  local keyword
  keyword=$(echo "$feature" | grep -oE '[A-Za-z]{4,}' | head -1)
  if [ -n "$keyword" ] && grep -qiE "\\b${keyword}\\b" "$test_ref" 2>/dev/null; then
    return 0
  fi
  return 1
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

    # QA-AUDIT-GAP-01 (v0.6.29) — Tests column may contain multiple comma-separated
    # references, e.g. `tests/a.test.js, tests/b.test.js`. Extract the last cell
    # of the row, then split on commas; validate each entry independently.
    # Test refs: no spaces, contain a dot or slash, look like file paths.
    # e.g. tests/auth.test.js  tests/auth.sh  section-2
    raw_cell=$(echo "$line" | awk -F'|' '{
      # Walk fields right-to-left; pick the last non-empty cell that contains
      # at least one path-shaped token (file with extension or starting with tests/).
      for (i=NF; i>1; i--) {
        cell = $i
        gsub(/^ +| +$/, "", cell)
        if (length(cell) > 0 && (cell ~ /tests\// || cell ~ /\.test\.|\.spec\.|\.sh|\.py|\.ts|\.js/)) {
          print cell; exit
        }
      }
    }')

    # Split raw_cell on commas, trim each, drop empties and non-path tokens.
    test_refs=()
    if [ -n "$raw_cell" ]; then
      OLDIFS="$IFS"
      IFS=','
      for tok in $raw_cell; do
        tok="${tok#"${tok%%[![:space:]]*}"}"   # ltrim
        tok="${tok%"${tok##*[![:space:]]}"}"   # rtrim
        # Reject tokens with internal whitespace or that don't look like paths
        if [ -n "$tok" ] && ! echo "$tok" | grep -q ' '; then
          if echo "$tok" | grep -qE '^tests/|\.test\.|\.spec\.|\.sh$|\.py$|\.ts$|\.js$'; then
            test_refs+=("$tok")
          fi
        fi
      done
      IFS="$OLDIFS"
    fi

    TOTAL_DONE=$((TOTAL_DONE + 1))

    if [ "${#test_refs[@]}" -eq 0 ]; then
      printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "⚠  NO TEST REFERENCE"
      MISSING_REFS=$((MISSING_REFS + 1))
    else
      # Per-feature aggregate: if ANY ref fails, the feature fails. Counters
      # accumulate per-ref so REF_PRESENT/FILE_EXISTS track total individual
      # references — preserves existing semantics for single-ref rows.
      feature_pass=true
      for test_ref in "${test_refs[@]}"; do
        REF_PRESENT=$((REF_PRESENT + 1))

        if [ ! -f "$test_ref" ] && [ ! -d "$test_ref" ]; then
          printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "✗  FILE NOT FOUND: $test_ref"
          MISSING_FILES=$((MISSING_FILES + 1))
          feature_pass=false
          continue
        fi
        FILE_EXISTS=$((FILE_EXISTS + 1))

        if ! check_stub_complete "$test_ref"; then
          stub_count=$(grep "^${test_ref}:stubs_incomplete:" "$TEST_CACHE_FILE" | cut -d: -f3)
          printf "  %-5s %-32s %-8s %s\n" "$fn" "$feature" "[x]" "✗  STUBS NOT FILLED ($stub_count TODO markers): $test_ref"
          TESTS_FAILED=$((TESTS_FAILED + 1))
          feature_pass=false
          continue
        fi

        # v0.6.29 G21 — relevance check: warn (not fail)
        if ! check_test_relevance "$test_ref" "$fn" "$feature"; then
          IRRELEVANT_TESTS=$((IRRELEVANT_TESTS + 1))
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
          feature_pass=false
        fi
      done
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
if [ "$IRRELEVANT_TESTS" -gt 0 ]; then
  printf "  ⚠  Possibly-irrelevant:    %d (test file doesn't reference feature ID or keyword)\n" "$IRRELEVANT_TESTS"
fi
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
