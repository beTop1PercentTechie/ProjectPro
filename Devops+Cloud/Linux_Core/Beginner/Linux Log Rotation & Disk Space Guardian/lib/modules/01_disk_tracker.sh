#!/usr/bin/env bash
# 01_disk_tracker.sh - Requirement #1: real-time disk usage tracking with
# growth-rate trend detection (not just a static "% used" threshold).
#
# Every run samples current usage per monitored mount, persists it to the
# history store, then derives a growth rate (KB/hour) and a projected
# "hours until full" from that history. Other modules (04_alerting) act on
# these numbers; this module's job is purely to observe and record them.

run_disk_tracker() {
    section "Disk Usage Tracking"

    local mounts mount
    mounts="$(get_monitored_mounts)"

    if [[ -z "$mounts" ]]; then
        log_warn "No mount points resolved from MONITORED_MOUNTS='$MONITORED_MOUNTS'"
        return
    fi

    while IFS= read -r mount; do
        [[ -z "$mount" ]] && continue
        _track_mount "$mount"
    done <<< "$mounts"

    prune_history
}

# get_monitored_mounts - prints one mount point per line. "auto" resolves to
# every real, local filesystem df reports (pseudo-filesystems excluded);
# otherwise MONITORED_MOUNTS is treated as a comma-separated explicit list.
# Shared with lib/modules/04_alerting.sh.
get_monitored_mounts() {
    if [[ "$MONITORED_MOUNTS" == "auto" ]]; then
        df -x tmpfs -x devtmpfs -x squashfs -x overlay -x proc -x sysfs -x tracefs -P 2>/dev/null \
            | tail -n +2 | awk '{print $6}'
    else
        local IFS=','
        local m
        for m in $MONITORED_MOUNTS; do
            printf '%s\n' "$(trim "$m")"
        done
    fi
}

# df_stats_for_mount <mount> - prints "used_kb avail_kb total_kb use_pct" for
# one mount point, or nothing if df has no entry for it. Shared with
# lib/modules/04_alerting.sh.
df_stats_for_mount() {
    local mount="$1"
    df -P "$mount" 2>/dev/null | tail -n +2 | awk -v m="$mount" '
        { total=$2; used=$3; avail=$4; pct=$5; sub(/%/,"",pct); print used, avail, total, pct; exit }
    '
}

_track_mount() {
    local mount="$1"
    local stats used_kb avail_kb total_kb use_pct
    stats="$(df_stats_for_mount "$mount")"

    if [[ -z "$stats" ]]; then
        log_warn "Could not read df stats for mount: $mount"
        return
    fi

    read -r used_kb avail_kb total_kb use_pct <<< "$stats"
    record_disk_sample "$mount" "$used_kb" "$avail_kb" "$total_kb" "$use_pct"

    local rate hours_to_full sample_count trend
    rate="$(growth_rate_kb_per_hour "$mount" "$GROWTH_SAMPLE_WINDOW_MIN")"
    sample_count="$(sample_count_in_window "$mount" "$GROWTH_SAMPLE_WINDOW_MIN")"
    hours_to_full="$(forecast_hours_to_full "$avail_kb" "$rate")"

    if (( sample_count < MIN_SAMPLES_FOR_FORECAST )); then
        trend="LEARNING"
    elif (( rate <= 0 )); then
        trend="STABLE"
    else
        trend="GROWING"
    fi

    local detail
    detail="used=$(kb_to_human "$used_kb") / $(kb_to_human "$total_kb") (${use_pct}%), "
    detail+="growth=$(kb_to_human "$rate")/hour over ${GROWTH_SAMPLE_WINDOW_MIN}m (${sample_count} samples)"
    if [[ "$trend" == "GROWING" && "$hours_to_full" != "inf" ]]; then
        detail+=", projected full in $(seconds_to_human "$(awk -v h="$hours_to_full" 'BEGIN{printf "%.0f", h*3600}')")"
    fi

    add_event "INFO" "DiskUsage" "[$trend] $mount at ${use_pct}%" "$detail"

    # Cache this mount's freshly computed numbers so 04_alerting.sh doesn't
    # need to recompute df/history queries it already has the answer to.
    _cache_mount_metrics "$mount" "$use_pct" "$avail_kb" "$rate" "$hours_to_full" "$trend"
}

# _cache_mount_metrics - stores this run's per-mount results in a temp file
# so the alerting module can read them without re-querying df/history.
_cache_mount_metrics() {
    local mount="$1" use_pct="$2" avail_kb="$3" rate="$4" hours_to_full="$5" trend="$6"
    : "${MOUNT_METRICS_FILE:=$(mktemp "${GUARDIAN_TMP_DIR:-/tmp}/guardian_metrics.XXXXXX")}"
    export MOUNT_METRICS_FILE
    printf '%s|%s|%s|%s|%s|%s\n' "$mount" "$use_pct" "$avail_kb" "$rate" "$hours_to_full" "$trend" >> "$MOUNT_METRICS_FILE"
}

cleanup_mount_metrics() {
    [[ -n "${MOUNT_METRICS_FILE:-}" && -f "$MOUNT_METRICS_FILE" ]] && rm -f "$MOUNT_METRICS_FILE"
}
