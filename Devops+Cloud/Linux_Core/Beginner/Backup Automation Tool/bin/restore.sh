#!/usr/bin/env bash
# restore.sh - Backup Automation Tool: restore a backup archive.
#
# Flow: list available backups -> pick one -> validate the archive ->
# choose a destination -> extract -> verify the extraction.
#
# Safety: the default restore destination is always a new folder under
# restore-test/, never a real system path - you must pass --dest
# explicitly and deliberately to restore anywhere else.
#
# Usage: restore.sh [OPTIONS]
# Run 'restore.sh --help' for the full option list.

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

for _arg in "$@"; do
    [[ "$_arg" == "--no-color" ]] && export NO_COLOR=1
done

print_usage() {
    cat <<USAGE
Usage: $(basename "$0") [OPTIONS]

Options:
  --file=NAME     Archive to restore, by filename or full path (skips the
                   interactive list if given)
  --dest=DIR      Where to extract the archive (default: a new folder
                   under restore-test/ - never a real system path unless
                   you set this explicitly)
  --config=FILE   Use an alternate config file (default: config/backup.conf)
  --no-color      Disable colored console output
  -h, --help      Show this help message

Examples:
  $(basename "$0")                                   # interactive: pick from a list
  $(basename "$0") --file=home_2026-08-27_02-00-00.tar.gz
  $(basename "$0") --file=home_2026-08-27_02-00-00.tar.gz --dest=/home/ubuntu/restore-test/home
USAGE
}

CONFIG_FILE="$BAT_HOME/config/backup.conf"
ARCHIVE_ARG=""
DEST_ARG=""

for arg in "$@"; do
    case "$arg" in
        --config=*) CONFIG_FILE="${arg#*=}" ;;
        --file=*) ARCHIVE_ARG="${arg#*=}" ;;
        --dest=*) DEST_ARG="${arg#*=}" ;;
        --no-color) : ;;
        -h|--help) print_usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; print_usage; exit 1 ;;
    esac
done

# shellcheck source=../lib/logger.sh
source "$BAT_HOME/lib/logger.sh"
# shellcheck source=../lib/validation.sh
source "$BAT_HOME/lib/validation.sh"
# shellcheck source=../lib/backup-functions.sh
source "$BAT_HOME/lib/backup-functions.sh"

load_config "$CONFIG_FILE"

ensure_dir "$LOG_DIR"
LOG_FILE="${LOG_DIR}/restore_$(timestamp_now).log"
: > "$LOG_FILE"

section "Available Backups"

mapfile -t archives < <(find "$BACKUP_ROOT" -maxdepth 1 -type f -name '*.tar.gz' -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk '{print $2}')

if [[ ${#archives[@]} -eq 0 ]]; then
    log_error "No backups found in $BACKUP_ROOT"
    exit 1
fi

selected=""
if [[ -n "$ARCHIVE_ARG" ]]; then
    for a in "${archives[@]}"; do
        if [[ "$a" == "$ARCHIVE_ARG" || "$(basename "$a")" == "$ARCHIVE_ARG" ]]; then
            selected="$a"
            break
        fi
    done
    if [[ -z "$selected" ]]; then
        log_error "No backup matches: $ARCHIVE_ARG"
        exit 1
    fi
else
    idx=0
    for a in "${archives[@]}"; do
        idx=$((idx + 1))
        size_h="$(human_readable_size "$(stat -c '%s' "$a" 2>/dev/null || echo 0)")"
        printf '  %2d) %-55s %10s\n' "$idx" "$(basename "$a")" "$size_h"
    done
    echo ""
    read -r -p "Enter the number of the backup to restore: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#archives[@]} )); then
        log_error "Invalid selection: $choice"
        exit 1
    fi
    selected="${archives[$((choice - 1))]}"
fi

log_info "Selected: $(basename "$selected")"

section "Validating Archive"
if ! validate_archive "$selected"; then
    log_error "This archive is corrupt and cannot be restored: $selected"
    exit 1
fi
log_success "Archive integrity check passed"

section "Choosing Destination"
if [[ -z "$DEST_ARG" ]]; then
    base_name="$(basename "$selected" .tar.gz)"
    DEST_ARG="${BAT_HOME}/restore-test/${base_name}"
    log_info "No --dest given - defaulting to a safe location: $DEST_ARG"
fi

if [[ -e "$DEST_ARG" && -n "$(ls -A "$DEST_ARG" 2>/dev/null)" ]]; then
    log_error "Destination already exists and is not empty: $DEST_ARG"
    log_error "Choose an empty destination with --dest to avoid mixing files from two different restores."
    exit 1
fi
ensure_dir "$DEST_ARG" || exit 1

section "Extracting"
if ! tar -xzf "$selected" -C "$DEST_ARG" 2>>"$LOG_FILE"; then
    log_error "Extraction failed - see $LOG_FILE"
    exit 1
fi
log_success "Extracted to $DEST_ARG"

section "Verifying"
restored_files=$(find "$DEST_ARG" -type f 2>/dev/null | wc -l)
if (( restored_files == 0 )); then
    log_error "Extraction produced no files - something is wrong"
    exit 1
fi
log_success "Restore verified: $restored_files file(s) found under $DEST_ARG"

log_info "Restore complete. Log file: $LOG_FILE"
