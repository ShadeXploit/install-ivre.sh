#!/usr/bin/env bash

set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/install-ivre.sh"

PASSED=0
FAILED=0

assert_eq() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    if [ "$expected" = "$actual" ]; then
        printf 'PASS: %s\n' "$test_name"
        PASSED=$((PASSED + 1))
    else
        printf 'FAIL: %s (expected "%s", got "%s")\n' "$test_name" "$expected" "$actual"
        FAILED=$((FAILED + 1))
    fi
}

assert_match() {
    local pattern="$1"
    local actual="$2"
    local test_name="$3"
    if [[ "$actual" =~ $pattern ]]; then
        printf 'PASS: %s\n' "$test_name"
        PASSED=$((PASSED + 1))
    else
        printf 'FAIL: %s (pattern "%s" not found in output)\n' "$test_name" "$pattern"
        FAILED=$((FAILED + 1))
    fi
}

printf '=== Running Tests for install-ivre.sh ===\n\n'

# Test 1: Bash syntax check
printf '[Test 1] Bash syntax check...\n'
if bash -n "$SCRIPT"; then
    assert_eq 0 0 "Bash syntax check passes"
else
    assert_eq 0 1 "Bash syntax check failed"
fi

# Test 2: Shellcheck check
printf '[Test 2] Shellcheck linting...\n'
if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck "$SCRIPT"; then
        assert_eq 0 0 "Shellcheck passes with zero errors/warnings"
    else
        assert_eq 0 1 "Shellcheck found errors"
    fi
else
    printf 'SKIP: shellcheck not installed\n'
fi

# Test 3: Help message contains all options
printf '[Test 3] Help message...\n'
help_out=$("$SCRIPT" --help)
assert_match "Usage: install-ivre.sh" "$help_out" "Help output contains usage header"
assert_match "\-\-directory" "$help_out" "Help output contains --directory option"
assert_match "\-\-skip-init" "$help_out" "Help output contains --skip-init option"
assert_match "\-\-update-db" "$help_out" "Help output contains --update-db option"
assert_match "\-\-open" "$help_out" "Help output contains --open option"
assert_match "\-\-help" "$help_out" "Help output contains --help option"

# Test 4: Short help flag -h
help_short=$("$SCRIPT" -h)
assert_match "Usage: install-ivre.sh" "$help_short" "Short flag -h displays usage"

# Test 5: Unknown option handling
printf '[Test 4] Unknown option rejection...\n'
set +e
err_out=$("$SCRIPT" --invalid-flag 2>&1)
err_code=$?
set -e
assert_eq 1 "$err_code" "Unknown option returns exit code 1"
assert_match "unknown option: --invalid-flag" "$err_out" "Unknown option returns descriptive error"

# Test 6: Missing argument for --directory
printf '[Test 5] Missing argument for --directory...\n'
set +e
missing_arg_out=$("$SCRIPT" --directory 2>&1)
missing_arg_code=$?
set -e
assert_eq 1 "$missing_arg_code" "Missing directory argument returns exit code 1"
assert_match "missing path for --directory" "$missing_arg_out" "Missing directory argument error message"

# Test 6: --open option
printf '[Test 6] --open option execution...\n'
open_out=$("$SCRIPT" --open 2>&1 || true)
assert_match "Opening IVRE web interface" "$open_out" "--open acknowledges opening web interface"

# Test 7: Non-empty invalid directory rejection
printf '[Test 7] Non-empty non-IVRE directory rejection...\n'
dummy_dir=$(mktemp -d /tmp/dummy-dir-XXXXXX)
touch "$dummy_dir/somefile.txt"
set +e
invalid_dir_out=$("$SCRIPT" --directory "$dummy_dir" --skip-init 2>&1)
invalid_dir_code=$?
set -e
rm -rf "$dummy_dir"
assert_eq 1 "$invalid_dir_code" "Non-empty non-IVRE directory returns exit code 1"
assert_match "exists and is not empty, but is not an IVRE installation" "$invalid_dir_out" "Descriptive error for non-empty non-IVRE directory"

# Test 8: --update-db when compose file and container missing
printf '[Test 8] --update-db with nonexistent path...\n'
set +e
missing_db_out=$("$SCRIPT" --directory "/tmp/nonexistent-ivre-dir" --update-db 2>&1)
missing_db_code=$?
set -e
assert_eq 1 "$missing_db_code" "--update-db returns exit code 1 when container and compose file missing"
assert_match "Container 'ivreclient' is not running and compose file" "$missing_db_out" "Descriptive error for missing container/compose file"

printf '\n=== Test Summary: %d passed, %d failed ===\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ] || exit 1
