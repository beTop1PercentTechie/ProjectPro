#!/usr/bin/env bash
# logger.sh - Unified logging for LSAMS. Writes timestamped lines to the
# run's log file and mirrors them to the console with severity colors.
#
# Requires: colors.sh sourced first, LOG_FILE set by the caller.

_log_write() {
    local level="$1" color="$2" message="$3"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    printf '[%s] [%s] %s\n' "$ts" "$level" "$message" >> "$LOG_FILE"
    printf '%b[%s]%b %s\n' "$color" "$level" "$C_RESET" "$message"
}

log_info()     { _log_write "INFO"     "$C_BLUE"   "$1"; }
log_success()  { _log_write "SUCCESS"  "$C_GREEN"  "$1"; }
log_warn()     { _log_write "WARNING"  "$C_YELLOW" "$1"; }
log_error()    { _log_write "ERROR"    "$C_RED"    "$1"; }
log_critical() { _log_write "CRITICAL" "$C_RED$C_BOLD" "$1"; }

section() {
    local title="$1"
    local line
    line=$(printf '%.0s-' {1..60})
    printf '\n%b%s\n  %s\n%s%b\n' "$C_CYAN$C_BOLD" "$line" "$title" "$line" "$C_RESET"
    printf '\n[%s] ==== %s ====\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$title" >> "$LOG_FILE"
}
