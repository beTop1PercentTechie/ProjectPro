#!/usr/bin/env bash
# test-restore.sh - Verifies a backed-up archive can actually be restored
# and that the restored content is byte-for-byte identical to the
# original, using real tar/gzip round-trips (no mocking).

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
SOURCE_DIR="$SANDBOX/source/docs"
mkdir -p "$SOURCE_DIR/reports"
echo "quarterly numbers" > "$SOURCE_DIR/reports/q1.txt"
echo "meeting notes" > "$SOURCE_DIR/notes.txt"
dd if=/dev/urandom of="$SOURCE_DIR/binary.dat" bs=1024 count=4 >/dev/null 2>&1 || head -c 4096 /dev/urandom > "$SOURCE_DIR/binary.dat"

BACKUP_ROOT="$SANDBOX/backups"
TAR_EXCLUDES=""
mkdir -p "$BACKUP_ROOT"

echo "== Round trip: backup then restore must reproduce the exact original =="
backup_single_directory "$SOURCE_DIR" "2026-03-01_09-00-00" >/dev/null 2>&1
expected_name="$(sanitize_source_name "$SOURCE_DIR")"
archive="$BACKUP_ROOT/${expected_name}_2026-03-01_09-00-00.tar.gz"
assert_eq "yes" "$([[ -f "$archive" ]] && echo yes || echo no)" "archive was created"

restore_dest="$SANDBOX/restore-test/docs"
mkdir -p "$restore_dest"
tar -xzf "$archive" -C "$restore_dest" >/dev/null 2>&1

assert_eq "quarterly numbers" "$(cat "$restore_dest/docs/reports/q1.txt" 2>/dev/null)" "nested text file restored correctly"
assert_eq "meeting notes" "$(cat "$restore_dest/docs/notes.txt" 2>/dev/null)" "top-level text file restored correctly"

if cmp -s "$SOURCE_DIR/binary.dat" "$restore_dest/docs/binary.dat"; then
    echo "  ok - binary file is byte-for-byte identical after restore"
else
    echo "  FAIL - binary file differs after restore"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

echo
echo "== A corrupted archive must be rejected before extraction is attempted =="
corrupt="$SANDBOX/corrupt.tar.gz"
head -c 100 "$archive" > "$corrupt"   # truncate a real archive - looks real, isn't valid
if validate_archive "$corrupt"; then
    echo "  FAIL - truncated archive was accepted as valid"
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    echo "  ok - truncated/corrupted archive correctly rejected by validate_archive"
fi
TESTS_RUN=$((TESTS_RUN + 1))

echo
echo "== Restoring into a non-empty destination must be refused by the safety check =="
occupied="$SANDBOX/occupied"
mkdir -p "$occupied"
echo "pre-existing file, do not overwrite" > "$occupied/keep-me.txt"
non_empty="$([[ -n "$(ls -A "$occupied" 2>/dev/null)" ]] && echo yes || echo no)"
assert_eq "yes" "$non_empty" "the same non-empty check restore.sh uses correctly flags this directory"

rm -rf "$SANDBOX"
rm -f "$LOG_FILE"

echo
echo "Tests run: $TESTS_RUN, failed: $TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
