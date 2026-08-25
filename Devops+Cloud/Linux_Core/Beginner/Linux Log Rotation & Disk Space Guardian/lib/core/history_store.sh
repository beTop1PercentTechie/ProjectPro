#!/usr/bin/env bash
# history_store.sh - Persists periodic disk-usage samples and derives growth
# trends from them. This is what makes Guardian a *trend* detector instead of
# a plain "df and compare to a threshold" script.
#
# Storage: a flat, append-only CSV at $DATA_DIR/disk_history.csv
#   epoch,mount,used_kb,avail_kb,total_kb,use_pct
#
# A flat file (rather than a real database) keeps the project dependency-free
# and trivially inspectable with awk/grep - appropriate for a single-host
# monitoring agent sampling every few minutes.

init_history_store() {
    ensure_dir "$DATA_DIR"
    HISTORY_FILE="$DATA_DIR/disk_history.csv"
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo "epoch,mount,used_kb,avail_kb,total_kb,use_pct" > "$HISTORY_FILE"
    fi
}

# record_disk_sample <mount> <used_kb> <avail_kb> <total_kb> <use_pct>
record_disk_sample() {
    local mount="$1" used_kb="$2" avail_kb="$3" total_kb="$4" use_pct="$5"
    printf '%s,%s,%s,%s,%s,%s\n' "$(epoch_now)" "$mount" "$used_kb" "$avail_kb" "$total_kb" "$use_pct" >> "$HISTORY_FILE"
}

# prune_history - drops samples older than HISTORY_RETENTION_DAYS so the
# CSV doesn't grow unbounded on a long-running host.
prune_history() {
    [[ -f "$HISTORY_FILE" ]] || return 0
    local cutoff tmp_file
    cutoff=$(( $(epoch_now) - (HISTORY_RETENTION_DAYS * 86400) ))
    tmp_file="$(mktemp "${DATA_DIR}/.history_prune.XXXXXX")"

    awk -F',' -v cutoff="$cutoff" 'NR==1 || ($1+0) >= cutoff' "$HISTORY_FILE" > "$tmp_file"
    mv "$tmp_file" "$HISTORY_FILE"
}

# _samples_for_mount <mount> <window_minutes> - prints matching CSV rows
# (header excluded), oldest first.
_samples_for_mount() {
    local mount="$1" window_min="$2" cutoff
    cutoff=$(( $(epoch_now) - (window_min * 60) ))
    awk -F',' -v m="$mount" -v cutoff="$cutoff" \
        'NR>1 && $2==m && ($1+0)>=cutoff { print }' "$HISTORY_FILE" | sort -t',' -k1,1n
}

# latest_sample_line <mount> - the single most recent row for a mount.
latest_sample_line() {
    local mount="$1"
    awk -F',' -v m="$mount" 'NR>1 && $2==m { line=$0 } END { print line }' "$HISTORY_FILE"
}

# sample_count_in_window <mount> <window_minutes>
sample_count_in_window() {
    local mount="$1" window_min="$2"
    _samples_for_mount "$mount" "$window_min" | grep -c . || true
}

# growth_rate_kb_per_hour <mount> <window_minutes>
# Compares the oldest and newest sample within the window and returns the
# used-space growth rate in KB/hour (can be negative if space was freed).
# Prints 0 when fewer than 2 samples are available in the window.
growth_rate_kb_per_hour() {
    local mount="$1" window_min="$2"
    local rows first last
    rows="$(_samples_for_mount "$mount" "$window_min")"

    if [[ -z "$rows" ]]; then echo 0; return; fi

    first="$(head -n1 <<< "$rows")"
    last="$(tail -n1 <<< "$rows")"
    [[ "$first" == "$last" ]] && { echo 0; return; }

    awk -F',' -v first="$first" -v last="$last" '
        BEGIN {
            split(first, f, ",");
            split(last, l, ",");
            delta_used = l[3] - f[3];
            delta_hours = (l[1] - f[1]) / 3600.0;
            if (delta_hours <= 0) { print 0; exit }
            printf "%.0f", delta_used / delta_hours;
        }'
}

# forecast_hours_to_full <avail_kb> <growth_kb_per_hour>
# Returns "inf" when the mount is not growing (rate <= 0), otherwise the
# projected number of hours until available space reaches zero.
forecast_hours_to_full() {
    local avail_kb="$1" rate_kb_per_hour="$2"
    if (( rate_kb_per_hour <= 0 )); then
        echo "inf"
        return
    fi
    awk -v a="$avail_kb" -v r="$rate_kb_per_hour" 'BEGIN { printf "%.1f", a / r }'
}
