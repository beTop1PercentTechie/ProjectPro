#!/usr/bin/env bash
# test-validation.sh - Unit tests for lib/validation.sh and the small
# helpers in lib/backup-functions.sh. Pure bash, no external framework.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
BAT_HOME="$(cd -P "$TEST_DIR/.." >/dev/null 2>&1 && pwd)"

LOG_FILE="$(mktemp)"
# shellcheck source=../lib/logger.sh
source "$BAT_HOME/lib/logger.sh"
# shellcheck source=../lib/backup-functions.sh
source "$BAT_HOME/lib/backup-functions.sh"
# shellcheck source=../lib/validation.sh
source "$BAT_HOME/lib/validation.sh"

TESTS_RUN=0
TESTS_FAILED=0

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo "  ok - $label"
    else
        echo "  FAIL - $label (expected '$expected', got '$actual')"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_true() {
    local label="$1"; shift
    TESTS_RUN=$((TESTS_RUN + 1))
    if "$@" >/dev/null 2>&1; then
        echo "  ok - $label"
    else
        echo "  FAIL - $label"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_false() {
    local label="$1"; shift
    TESTS_RUN=$((TESTS_RUN + 1))
    if ! "$@" >/dev/null 2>&1; then
        echo "  ok - $label"
    else
        echo "  FAIL - $label (expected failure, but it succeeded)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

SANDBOX="$(mktemp -d)"

echo "== sanitize_source_name =="
assert_eq "var-www" "$(sanitize_source_name "/var/www")" "strips leading slash, joins with dashes"
assert_eq "home" "$(sanitize_source_name "/home")" "single-segment path"
assert_eq "root" "$(sanitize_source_name "/")" "root path falls back to 'root'"
assert_eq "etc" "$(sanitize_source_name "/etc/")" "trailing slash is stripped"

echo "== human_readable_size =="
assert_eq "512 B" "$(human_readable_size 512)" "sub-1KB renders as bytes"
assert_eq "2.00 KB" "$(human_readable_size 2048)" "KB rendered correctly"
assert_eq "1.50 MB" "$(human_readable_size 1572864)" "MB rendered correctly"

echo "== human_duration =="
assert_eq "45s" "$(human_duration 45)" "seconds only"
assert_eq "2m 5s" "$(human_duration 125)" "minutes and seconds"

echo "== validate_source_dir =="
mkdir -p "$SANDBOX/real_source"
assert_true  "an existing, readable directory passes"      validate_source_dir "$SANDBOX/real_source"
assert_false "a missing directory fails"                    validate_source_dir "$SANDBOX/does_not_exist"
assert_false "an empty path fails"                           validate_source_dir ""
touch "$SANDBOX/not_a_dir.txt"
assert_false "a file (not a directory) fails"                validate_source_dir "$SANDBOX/not_a_dir.txt"

echo "== validate_backup_root =="
assert_true "a destination that doesn't exist yet gets created" validate_backup_root "$SANDBOX/new_backup_root"
assert_true "the newly created destination now exists"           test -d "$SANDBOX/new_backup_root"
assert_false "an empty BACKUP_ROOT fails"                          validate_backup_root ""

echo "== validate_archive =="
good_archive="$SANDBOX/good.tar.gz"
tar -czf "$good_archive" -C "$SANDBOX" real_source
assert_true "a real, freshly created archive passes"        validate_archive "$good_archive"
assert_false "a missing archive fails"                        validate_archive "$SANDBOX/missing.tar.gz"
: > "$SANDBOX/empty.tar.gz"
assert_false "a zero-byte archive fails"                       validate_archive "$SANDBOX/empty.tar.gz"
echo "not a real archive" > "$SANDBOX/corrupt.tar.gz"
assert_false "a corrupt (non-gzip) archive fails"               validate_archive "$SANDBOX/corrupt.tar.gz"

echo "== check_disk_space =="
assert_true "0 required MB always passes" check_disk_space "$SANDBOX" 0
assert_true "a modest requirement passes on a real disk" check_disk_space "$SANDBOX" 1
assert_false "an absurd requirement fails" check_disk_space "$SANDBOX" 999999999

rm -rf "$SANDBOX"
rm -f "$LOG_FILE"

echo
echo "Tests run: $TESTS_RUN, failed: $TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
