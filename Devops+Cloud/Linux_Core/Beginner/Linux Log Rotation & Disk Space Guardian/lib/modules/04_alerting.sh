#!/usr/bin/env bash
# 04_alerting.sh - Requirement #4: preemptive alerting before disk hits a
# critical threshold, backed by the remediation action log.
#
# Two signals can trigger an alert, independently:
#   1. Static threshold  - current usage% >= DISK_WARN/CRIT_THRESHOLD
#   2. Growth-rate trend - projected "hours until full" <= FORECAST_WARN/
#      CRITICAL_HOURS, even while usage% is still comfortably low
#
# Every alert is written to the event store (so it always shows up in the
# report) and to the remediation action log (so "an alert fired" is part of
# the same audit trail as rotations/deletions). External notification
# (email/Slack/Telegram) is cooldown-gated per mount so a 5-minute cron
# cadence doesn't spam the channel - see ALERT_COOLDOWN_MIN.

run_alerting() {
    section "Preemptive Alerting"

    if [[ -z "${MOUNT_METRICS_FILE:-}" || ! -f "$MOUNT_METRICS_FILE" ]]; then
        log_warn "No mount metrics available - run the disk tracker module first"
        return
    fi

    NOTIFY_FILE="$(mktemp "${GUARDIAN_TMP_DIR:-/tmp}/guardian_notify.XXXXXX")"
    export NOTIFY_FILE

    local mount use_pct avail_kb rate hours_to_full trend
    while IFS='|' read -r mount use_pct avail_kb rate hours_to_full trend; do
        [[ -z "$mount" ]] && continue
        _evaluate_mount_alert "$mount" "$use_pct" "$avail_kb" "$hours_to_full"
    done < "$MOUNT_METRICS_FILE"

    cleanup_mount_metrics
}

# _forecast_at_or_below <hours_to_full> <threshold_hours> - numeric compare
# that correctly treats "inf" (not growing) as never triggering.
_forecast_at_or_below() {
    local hours="$1" threshold="$2"
    [[ "$hours" == "inf" ]] && return 1
    awk -v h="$hours" -v t="$threshold" 'BEGIN { exit !(h <= t) }'
}

_evaluate_mount_alert() {
    local mount="$1" use_pct="$2" avail_kb="$3" hours_to_full="$4"
    local severity="" reason=""

    if (( use_pct >= DISK_CRIT_THRESHOLD )); then
        severity="CRITICAL"
        reason="usage at ${use_pct}% (critical threshold ${DISK_CRIT_THRESHOLD}%)"
    elif _forecast_at_or_below "$hours_to_full" "$FORECAST_CRITICAL_HOURS"; then
        severity="CRITICAL"
        reason="projected to fill in ${hours_to_full}h (critical forecast threshold ${FORECAST_CRITICAL_HOURS}h)"
    elif (( use_pct >= DISK_WARN_THRESHOLD )); then
        severity="WARNING"
        reason="usage at ${use_pct}% (warning threshold ${DISK_WARN_THRESHOLD}%)"
    elif _forecast_at_or_below "$hours_to_full" "$FORECAST_WARN_HOURS"; then
        severity="WARNING"
        reason="projected to fill in ${hours_to_full}h (warning forecast threshold ${FORECAST_WARN_HOURS}h)"
    fi

    [[ -z "$severity" ]] && return

    add_event "$severity" "Alert" "$mount: $severity" "$reason (${avail_kb} KB free)"

    local avail_bytes=$(( avail_kb * 1024 ))
    log_action "ALERT" "$mount" "$avail_bytes" "$avail_bytes" "$severity: $reason"

    if _cooldown_elapsed "$mount"; then
        echo "${mount}|${severity}|${reason}" >> "$NOTIFY_FILE"
        _update_cooldown "$mount"
    else
        log_debug "Alert for $mount suppressed by cooldown (< ${ALERT_COOLDOWN_MIN}m since last notification)"
    fi
}

# --- Per-mount notification cooldown, persisted across runs ------------------
_cooldown_file() {
    echo "$DATA_DIR/alert_cooldown.state"
}

_cooldown_elapsed() {
    local mount="$1" file last_epoch now
    file="$(_cooldown_file)"
    [[ -f "$file" ]] || return 0

    last_epoch=$(awk -F'|' -v m="$mount" '$1==m { print $2 }' "$file" | tail -n1)
    [[ -z "$last_epoch" ]] && return 0

    now=$(epoch_now)
    (( (now - last_epoch) >= (ALERT_COOLDOWN_MIN * 60) ))
}

_update_cooldown() {
    local mount="$1" file tmp_file
    file="$(_cooldown_file)"
    tmp_file="$(mktemp "${DATA_DIR}/.cooldown.XXXXXX")"

    [[ -f "$file" ]] && awk -F'|' -v m="$mount" '$1!=m' "$file" > "$tmp_file" || : > "$tmp_file"
    printf '%s|%s\n' "$mount" "$(epoch_now)" >> "$tmp_file"
    mv "$tmp_file" "$file"
}

cleanup_notify_file() {
    [[ -n "${NOTIFY_FILE:-}" && -f "$NOTIFY_FILE" ]] && rm -f "$NOTIFY_FILE"
}
