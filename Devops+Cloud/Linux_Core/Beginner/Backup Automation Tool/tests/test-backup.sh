#!/usr/bin/env bash
# test-backup.sh - Integration tests for the core backup engine: actually
# creating archives with tar/gzip, and the retention/rotation policy.
# Uses real files in a temp sandbox - not mocked.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
BAT_HOME="$(cd -P "$TEST_DIR/.." >/dev/null 2>&1 && pwd)"

LOG_FILE="$(mktemp)"
# shellcheck source=../lib/logger.sh
source "$BAT_HOME/lib/logger.sh"
# shellcheck source=../lib/validation.sh
source "$BAT_HOME/lib/validation.sh"
# shellcheck source=../lib/backup-functions.sh
source "$BAT_HOME/lib/backup-functions.sh"

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

SANDBOX="$(mktemp -d)"
SOURCE_DIR="$SANDBOX/source/my-app"
mkdir -p "$SOURCE_DIR"
echo "hello world" > "$SOURCE_DIR/file1.txt"
echo "some config" > "$SOURCE_DIR/config.yml"
mkdir -p "$SOURCE_DIR/subdir"
echo "nested file" > "$SOURCE_DIR/subdir/nested.txt"

BACKUP_ROOT="$SANDBOX/backups"
TAR_EXCLUDES=""
mkdir -p "$BACKUP_ROOT"

echo "== backup_single_directory: creates a real, valid, extractable archive =="
if backup_single_directory "$SOURCE_DIR" "2026-01-01_00-00-00"; then
    echo "  ok - backup_single_directory reported success"
else
    echo "  FAIL - backup_single_directory reported failure"
fi
TESTS_RUN=$((TESTS_RUN + 1))

expected_name="$(sanitize_source_name "$SOURCE_DIR")"
archive="$BACKUP_ROOT/${expected_name}_2026-01-01_00-00-00.tar.gz"
assert_eq "yes" "$([[ -f "$archive" ]] && echo yes || echo no)" "archive file exists on disk"

extract_dir="$SANDBOX/extracted"
mkdir -p "$extract_dir"
tar -xzf "$archive" -C "$extract_dir" >/dev/null 2>&1
assert_eq "hello world" "$(cat "$extract_dir/my-app/file1.txt" 2>/dev/null)" "extracted file content matches the original"
assert_eq "nested file" "$(cat "$extract_dir/my-app/subdir/nested.txt" 2>/dev/null)" "nested subdirectory content survives round-trip"

echo
echo "== apply_retention: 10 backups, RETENTION_COUNT=7 -> 3 removed, 7 remain =="
RETENTION_COUNT=7
RET_ROOT="$SANDBOX/retention-backups"
mkdir -p "$RET_ROOT"
BACKUP_ROOT="$RET_ROOT"

# Create 10 fake archives for the same source, with strictly increasing
# modification times so "oldest" is unambiguous.
for i in 1 2 3 4 5 6 7 8 9 10; do
    fname="$RET_ROOT/widget_2026-01-$(printf '%02d' "$i")_00-00-00.tar.gz"
    tar -czf "$fname" -C "$SOURCE_DIR" . >/dev/null 2>&1
    touch -d "2026-01-$(printf '%02d' "$i") 00:00:00" "$fname" 2>/dev/null || touch "$fname"
    sleep 0.01
done

before_count=$(find "$RET_ROOT" -maxdepth 1 -name 'widget_*.tar.gz' | wc -l)
assert_eq "10" "$before_count" "sandbox actually has 10 archives before retention runs"

REMOVED_COUNT=0
apply_retention "widget"

after_count=$(find "$RET_ROOT" -maxdepth 1 -name 'widget_*.tar.gz' | wc -l)
assert_eq "7" "$after_count" "exactly 7 archives remain after retention"
assert_eq "3" "$REMOVED_COUNT" "exactly 3 archives were counted as removed"

# The 3 oldest (Jan 1, 2, 3) must be the ones gone; the 7 newest must remain.
assert_eq "no" "$([[ -f "$RET_ROOT/widget_2026-01-01_00-00-00.tar.gz" ]] && echo yes || echo no)" "oldest archive (Jan 1) was deleted"
assert_eq "no" "$([[ -f "$RET_ROOT/widget_2026-01-03_00-00-00.tar.gz" ]] && echo yes || echo no)" "3rd-oldest archive (Jan 3) was deleted"
assert_eq "yes" "$([[ -f "$RET_ROOT/widget_2026-01-10_00-00-00.tar.gz" ]] && echo yes || echo no)" "newest archive (Jan 10) was kept"
assert_eq "yes" "$([[ -f "$RET_ROOT/widget_2026-01-04_00-00-00.tar.gz" ]] && echo yes || echo no)" "the 7th-newest archive (Jan 4) was kept, not deleted"

echo
echo "== stage_with_rsync's return value must be clean, even when it also logs =="
# Regression test: stage_with_rsync is called as tar_source_dir="$(stage_with_rsync ...)".
# If a log_* call inside it ever writes to stdout instead of stderr, that
# log line gets glued onto the captured path and silently corrupts every
# tar command downstream. This asserts the captured value is exactly the
# path/warning-free single line it's supposed to be.
RSYNC_STAGING_DIR="$SANDBOX/rsync-staging"
mkdir -p "$RSYNC_STAGING_DIR"
staged_result="$(stage_with_rsync "$SOURCE_DIR" "regression-check" 2>/dev/null)"
# wc -l counts newline *characters*, and command substitution strips the
# trailing one - so check for an *embedded* newline instead of counting.
if [[ "$staged_result" == *$'\n'* ]]; then
    assert_eq "single line" "multiple lines" "stage_with_rsync's captured stdout is a single line"
else
    assert_eq "single line" "single line" "stage_with_rsync's captured stdout is a single line"
fi
case "$staged_result" in
    *WARNING*|*"[INFO]"*|*"[ERROR]"*)
        echo "  FAIL - captured return value contains a log line: $staged_result"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        ;;
    *)
        echo "  ok - captured return value contains no log-line text"
        ;;
esac
TESTS_RUN=$((TESTS_RUN + 1))

echo
echo "== A failed backup attempt must not run retention =="
BACKUP_ROOT="$RET_ROOT"
count_before_failed_attempt=$(find "$RET_ROOT" -maxdepth 1 -name 'widget_*.tar.gz' | wc -l)
backup_single_directory "$SANDBOX/does-not-exist" "2026-02-01_00-00-00" >/dev/null 2>&1
rc=$?
count_after_failed_attempt=$(find "$RET_ROOT" -maxdepth 1 -name 'widget_*.tar.gz' | wc -l)
assert_eq "1" "$rc" "backing up a nonexistent source directory returns failure"
assert_eq "$count_before_failed_attempt" "$count_after_failed_attempt" "existing 'widget' backups were untouched by the failed attempt"

rm -rf "$SANDBOX"
rm -f "$LOG_FILE"

echo
echo "Tests run: $TESTS_RUN, failed: $TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
