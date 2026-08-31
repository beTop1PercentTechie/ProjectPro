#!/usr/bin/env bash
# logger.sh - Unified logging for the Backup Automation Tool. Writes
# timestamped lines to the run's log file and mirrors them to the console
# with severity colors.
#
# Requires: LOG_FILE set by the caller before any log_* function is used.

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    readonly C_RESET='\033[0m'
    readonly C_BOLD='\033[1m'
    readonly C_RED='\033[0;31m'
    readonly C_GREEN='\033[0;32m'
    readonly C_YELLOW='\033[0;33m'
    readonly C_BLUE='\033[0;34m'
    readonly C_CYAN='\033[0;36m'
else
    readonly C_RESET='' C_BOLD='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_CYAN=''
fi

_log_write() {
    local level="$1" color="$2" message="$3" ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    printf '[%s] [%s] %s\n' "$ts" "$level" "$message" >> "$LOG_FILE"
    # Console output goes to stderr, deliberately - not stdout. Several
    # functions in this project (e.g. stage_with_rsync) both log AND
    # return a value via 'echo' captured through $(...); if log lines went
    # to stdout they'd be swept into that capture and corrupt the return
    # value. Stderr keeps diagnostics visible in the terminal without
    # ever being captured by a caller doing var="$(some_function)".
    printf '%b[%s]%b %s\n' "$color" "$level" "$C_RESET" "$message" >&2
}

log_info()     { _log_write "INFO"    "$C_BLUE"  "$1"; }
log_success()  { _log_write "OK"      "$C_GREEN" "$1"; }
log_warn()     { _log_write "WARNING" "$C_YELLOW" "$1"; }
log_error()    { _log_write "ERROR"   "$C_RED"   "$1"; }

section() {
    local title="$1" line
    line=$(printf '%.0s-' {1..60})
    printf '\n%b%s\n  %s\n%s%b\n' "$C_CYAN$C_BOLD" "$line" "$title" "$line" "$C_RESET" >&2
    printf '\n[%s] ==== %s ====\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$title" >> "$LOG_FILE"
}
