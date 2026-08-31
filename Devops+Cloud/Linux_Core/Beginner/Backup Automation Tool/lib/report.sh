#!/usr/bin/env bash
# report.sh - Renders a short, human-readable summary after each backup
# run. This is deliberately different from the log file: the log is a
# detailed diary meant for troubleshooting one specific problem; the
# report is a glance-and-move-on answer to "did last night's backup work?"

# generate_summary_report - reads the run's accumulated counters (set by
# bin/backup.sh: TOTAL_DIRS, SUCCESS_COUNT, FAIL_COUNT, TOTAL_SIZE_BYTES,
# REMOVED_COUNT, RUN_STATUS, DURATION_SECONDS) and writes a report file,
# printing the same content to the console.
generate_summary_report() {
    local report_file="${REPORT_DIR}/backup_report_$(timestamp_now).txt"
    local total_dirs="${TOTAL_DIRS:-0}"
    local success_count="${SUCCESS_COUNT:-0}"
    local fail_count="${FAIL_COUNT:-0}"
    local removed_count="${REMOVED_COUNT:-0}"
    local status="${RUN_STATUS:-UNKNOWN}"
    local duration="${DURATION_SECONDS:-0}"
    local size_human
    size_human="$(human_readable_size "${TOTAL_SIZE_BYTES:-0}")"

    {
        echo "========================================"
        echo "         BACKUP SUMMARY REPORT"
        echo "========================================"
        echo ""
        echo "Date:              $(human_date)"
        echo "Status:            $status"
        echo ""
        echo "Directories:       $total_dirs"
        echo "Successful:        $success_count"
        echo "Failed:            $fail_count"
        echo ""
        echo "Total Backup Size: $size_human"
        echo "Duration:          $(human_duration "$duration")"
        echo ""
        echo "Old Backups Removed: $removed_count"
        echo ""
        echo "========================================"
    } | tee "$report_file"

    log_info "Report written: $report_file"
    LAST_REPORT_PATH="$report_file"
}
