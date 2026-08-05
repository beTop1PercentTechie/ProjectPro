#!/usr/bin/env bash
# 04_system_health.sh - Monitors CPU load, memory, disk usage, top resource
# consumers, and failed systemd units.

run_system_health_audit() {
    section "System Health Monitoring"
    _check_cpu_load
    _check_memory_usage
    _check_disk_usage
    _report_top_processes
    _check_failed_services
}

_check_cpu_load() {
    local load1 nproc_val load_pct
    load1=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)
    nproc_val=$(nproc 2>/dev/null || echo 1)

    [[ -z "$load1" ]] && { log_warn "Could not read /proc/loadavg"; return; }

    load_pct=$(awk -v l="$load1" -v n="$nproc_val" 'BEGIN { printf "%.0f", (l/n)*100 }')

    if (( load_pct >= CPU_WARN_THRESHOLD )); then
        add_finding "MEDIUM" "SystemHealth" "High system load average" \
            "1-min load: $load1 across $nproc_val core(s) (~${load_pct}% utilization)" \
            "Investigate top CPU consumers; consider scaling resources."
    else
        add_finding "INFO" "SystemHealth" "System load is normal" "1-min load: $load1 (${load_pct}% of ${nproc_val} cores)" ""
    fi
}

_check_memory_usage() {
    command_exists free || { log_warn "'free' not found - skipping memory check"; return; }

    local mem_pct
    mem_pct=$(free | awk '/^Mem:/ { printf "%.0f", ($3/$2)*100 }')
    [[ -z "$mem_pct" ]] && return

    if (( mem_pct >= MEM_WARN_THRESHOLD )); then
        add_finding "MEDIUM" "SystemHealth" "High memory utilization (${mem_pct}%)" \
            "$(free -h | awk 'NR==1 || NR==2')" \
            "Identify memory-heavy processes and consider adding swap or RAM."
    else
        add_finding "INFO" "SystemHealth" "Memory utilization is normal (${mem_pct}%)" "" ""
    fi
}

_check_disk_usage() {
    command_exists df || return

    local line fs pct mount severity
    while read -r line; do
        fs=$(echo "$line" | awk '{print $1}')
        pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
        mount=$(echo "$line" | awk '{print $6}')
        [[ -z "$pct" ]] && continue

        if (( pct >= DISK_CRIT_THRESHOLD )); then
            add_finding "HIGH" "SystemHealth" "Disk usage critical on $mount (${pct}%)" \
                "Filesystem: $fs" "Free up space or expand the volume immediately."
        elif (( pct >= DISK_WARN_THRESHOLD )); then
            add_finding "MEDIUM" "SystemHealth" "Disk usage high on $mount (${pct}%)" \
                "Filesystem: $fs" "Monitor growth and plan for cleanup or expansion."
        fi
    done < <(df -hP -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | tail -n +2)

    add_finding "INFO" "SystemHealth" "Disk usage scan complete" "$(df -hP -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | tail -n +2 | tr '\n' ';')" ""
}

_report_top_processes() {
    command_exists ps || return

    local top_cpu top_mem
    top_cpu=$(ps -eo pid,comm,%cpu --sort=-%cpu --no-headers 2>/dev/null | head -n 5 | awk '{printf "%s(%s%%) ", $2, $3}')
    top_mem=$(ps -eo pid,comm,%mem --sort=-%mem --no-headers 2>/dev/null | head -n 5 | awk '{printf "%s(%s%%) ", $2, $3}')

    add_finding "INFO" "SystemHealth" "Top CPU consumers" "$top_cpu" ""
    add_finding "INFO" "SystemHealth" "Top memory consumers" "$top_mem" ""
}

_check_failed_services() {
    command_exists systemctl || return

    local failed
    failed=$(systemctl --failed --no-legend 2>/dev/null | awk '{print $1}')

    if [[ -n "$failed" ]]; then
        add_finding "MEDIUM" "SystemHealth" "Systemd unit(s) in a failed state" \
            "Units: $(echo "$failed" | tr '\n' ' ')" \
            "Run 'systemctl status <unit>' and 'journalctl -u <unit>' to diagnose."
    else
        add_finding "INFO" "SystemHealth" "No failed systemd units" "" ""
    fi
}
