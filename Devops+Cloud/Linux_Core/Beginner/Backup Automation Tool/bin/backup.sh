#!/usr/bin/env bash
# backup.sh - Backup Automation Tool: main entry point.
#
# Flow: load config -> acquire lock -> validate destination -> for each
# configured source directory, validate -> tar+gzip -> verify -> apply
# retention -> write logs throughout -> write a summary report -> exit.
#
# Usage: backup.sh [OPTIONS]
# Run 'backup.sh --help' for the full option list.

set -uo pipefail

_resolve_home() {
    local src="${BASH_SOURCE[0]}"
    while [[ -h "$src" ]]; do
        local dir
        dir="$(cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd)"
        src="$(readlink "$src")"
        [[ "$src" != /* ]] && src="$dir/$src"
    done
    cd -P "$(dirname "$(dirname "$src")")" >/dev/null 2>&1 && pwd
}
readonly BAT_HOME="$(_resolve_home)"
readonly BAT_VERSION="1.0.0"

for _arg in "$@"; do
    [[ "$_arg" == "--no-color" ]] && export NO_COLOR=1
done

print_usage() {
    cat <<USAGE
Backup Automation Tool v${BAT_VERSION}

Usage: $(basename "$0") [OPTIONS]

Options:
  --config=FILE     Use an alternate config file (default: config/backup.conf)
  --dry-run         Validate everything and show what would happen, without
                     creating, deleting, or modifying any file
  --verbose         Show the exact tar command run for each source
  --no-color        Disable colored console output
  -h, --help        Show this help message
  -V, --version     Show version information

Exit codes:
  0  every configured source backed up successfully
  1  invalid arguments, lock held, or destination could not be prepared
  2  one or more sources failed to back up (partial or total failure)
USAGE
}

CONFIG_FILE="$BAT_HOME/config/backup.conf"
DRY_RUN=false
VERBOSE=false

for arg in "$@"; do
    case "$arg" in
        --config=*) CONFIG_FILE="${arg#*=}" ;;
        --dry-run) DRY_RUN=true ;;
        --verbose) VERBOSE=true ;;
        --no-color) : ;;
        -h|--help) print_usage; exit 0 ;;
        -V|--version) echo "Backup Automation Tool v${BAT_VERSION}"; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; print_usage; exit 1 ;;
    esac
done

# shellcheck source=../lib/logger.sh
source "$BAT_HOME/lib/logger.sh"
# shellcheck source=../lib/validation.sh
source "$BAT_HOME/lib/validation.sh"
# shellcheck source=../lib/backup-functions.sh
source "$BAT_HOME/lib/backup-functions.sh"
# shellcheck source=../lib/report.sh
source "$BAT_HOME/lib/report.sh"

load_config "$CONFIG_FILE"
export VERBOSE DRY_RUN

ensure_dir "$LOG_DIR"
LOG_FILE="${LOG_DIR}/backup_$(timestamp_now).log"
: > "$LOG_FILE"

log_info "Backup Automation Tool v${BAT_VERSION} starting$([[ "$DRY_RUN" == "true" ]] && echo " (DRY RUN)")"

if [[ "$DRY_RUN" != "true" ]]; then
    acquire_lock || exit 1
    trap release_lock EXIT
fi

section "Preparing"
if ! validate_backup_root "$BACKUP_ROOT"; then
    log_error "Cannot proceed without a usable backup destination"
    exit 1
fi
if ! check_disk_space "$BACKUP_ROOT" "$MIN_FREE_DISK_MB"; then
    exit 1
fi
ensure_dir "$REPORT_DIR"

if [[ -z "$SOURCE_DIRS" ]]; then
    log_error "SOURCE_DIRS is empty - nothing configured to back up. Edit config/backup.conf."
    exit 1
fi

TOTAL_DIRS=0
SUCCESS_COUNT=0
FAIL_COUNT=0
REMOVED_COUNT=0
TOTAL_SIZE_BYTES=0
START_EPOCH=$(date +%s)
TIMESTAMP="$(timestamp_now)"

if [[ "$DRY_RUN" == "true" ]]; then
    section "Backing Up Sources (dry run)"
else
    section "Backing Up Sources"
fi

IFS=',' read -ra sources <<< "$SOURCE_DIRS"
for source_dir in "${sources[@]}"; do
    source_dir="$(echo "$source_dir" | sed 's/^ *//;s/ *$//')"
    [[ -z "$source_dir" ]] && continue
    TOTAL_DIRS=$((TOTAL_DIRS + 1))

    if [[ "$DRY_RUN" == "true" ]]; then
        if validate_source_dir "$source_dir"; then
            name="$(sanitize_source_name "$source_dir")"
            log_info "[DRY-RUN] Would back up $source_dir -> ${name}_${TIMESTAMP}.tar.gz"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
        continue
    fi

    if backup_single_directory "$source_dir" "$TIMESTAMP"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        TOTAL_SIZE_BYTES=$((TOTAL_SIZE_BYTES + SOURCE_ARCHIVE_SIZE_BYTES))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

END_EPOCH=$(date +%s)
DURATION_SECONDS=$((END_EPOCH - START_EPOCH))

if (( FAIL_COUNT == 0 )); then
    RUN_STATUS="SUCCESS"
elif (( SUCCESS_COUNT > 0 )); then
    RUN_STATUS="PARTIAL"
else
    RUN_STATUS="FAILED"
fi

section "Summary"
if [[ "$DRY_RUN" != "true" ]]; then
    generate_summary_report
else
    log_info "[DRY-RUN] ${SUCCESS_COUNT}/${TOTAL_DIRS} source(s) would back up successfully; no files were created or removed"
fi

log_info "Backup run complete. Log file: $LOG_FILE"

case "$RUN_STATUS" in
    SUCCESS) exit 0 ;;
    *) exit 2 ;;
esac
