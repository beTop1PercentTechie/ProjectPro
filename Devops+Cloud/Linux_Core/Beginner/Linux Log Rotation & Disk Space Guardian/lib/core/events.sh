#!/usr/bin/env bash
# events.sh - Central store for this run's observations (disk snapshots,
# trend/forecast results, space-hog findings, alerts). Modules report
# through add_event() instead of building report fragments themselves - the
# report engine is the only place that renders output.
#
# Findings are appended to a pipe-delimited data file (rather than a bash
# array) so state survives across sourced modules and any subshells they
# spawn via pipelines.
#
# Line format: SEVERITY|CATEGORY|TITLE|DETAIL
# Pipe characters inside fields are replaced with the @PIPE@ placeholder
# (see lib/core/action_log.sh for why plain 'tr' is unsafe here).

init_event_store() {
    EVENTS_FILE="$(mktemp "${GUARDIAN_TMP_DIR:-/tmp}/guardian_events.XXXXXX")"
    : > "$EVENTS_FILE"
}

_ev_escape() {
    local s="$1"
    s="${s//|/@PIPE@}"
    s="${s//$'\n'/ }"
    printf '%s' "$s"
}

_ev_unescape() {
    printf '%s' "${1//@PIPE@/|}"
}

# add_event <SEVERITY> <CATEGORY> <TITLE> <DETAIL>
# SEVERITY one of: CRITICAL WARNING INFO
add_event() {
    local severity="$1" category="$2" title="$3" detail="$4"

    printf '%s|%s|%s|%s\n' \
        "$severity" "$(_ev_escape "$category")" "$(_ev_escape "$title")" "$(_ev_escape "$detail")" >> "$EVENTS_FILE"

    case "$severity" in
        CRITICAL) log_critical "[$category] $title" ;;
        WARNING)  log_warn     "[$category] $title" ;;
        *)        log_info     "[$category] $title" ;;
    esac
}

count_events_by_severity() {
    local severity="$1"
    [[ -f "$EVENTS_FILE" ]] || { echo 0; return; }
    awk -F'|' -v s="$severity" '$1 == s { c++ } END { print c+0 }' "$EVENTS_FILE"
}

# events_rows <severity> [category] - prints matching rows (raw, escaped).
events_rows() {
    local severity="$1" category="${2:-}"
    [[ -f "$EVENTS_FILE" ]] || return 0
    if [[ -z "$category" ]]; then
        awk -F'|' -v s="$severity" '$1 == s' "$EVENTS_FILE"
    else
        awk -F'|' -v s="$severity" -v c="$category" '$1 == s && $2 == c' "$EVENTS_FILE"
    fi
}

# overall_status - CRITICAL if any CRITICAL event was recorded, else WARNING
# if any WARNING event was recorded, else OK.
overall_status() {
    if (( $(count_events_by_severity CRITICAL) > 0 )); then
        echo "CRITICAL"
    elif (( $(count_events_by_severity WARNING) > 0 )); then
        echo "WARNING"
    else
        echo "OK"
    fi
}

cleanup_event_store() {
    [[ -n "${EVENTS_FILE:-}" && -f "$EVENTS_FILE" ]] && rm -f "$EVENTS_FILE"
}
