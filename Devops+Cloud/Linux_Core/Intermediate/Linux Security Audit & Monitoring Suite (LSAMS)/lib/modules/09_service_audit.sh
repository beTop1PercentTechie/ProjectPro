#!/usr/bin/env bash
# 09_service_audit.sh - Reviews running/enabled services for unnecessary
# attack surface (services commonly left on by default but rarely needed
# on a hardened server).

run_service_audit() {
    section "Running Services Audit"
    _report_active_services
    _check_unnecessary_services
}

_report_active_services() {
    command_exists systemctl || { log_warn "systemctl not found - skipping service audit"; return; }

    local count
    count=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l)
    add_finding "INFO" "ServiceAudit" "Active services" "$count service(s) currently running" ""
}

_check_unnecessary_services() {
    command_exists systemctl || return

    # service:reason pairs - commonly unnecessary on a headless/hardened server.
    local candidates=(
        "avahi-daemon:mDNS/zeroconf discovery, rarely needed on servers"
        "cups:printing service, not needed on servers"
        "isc-dhcp-server:DHCP server, only needed if this host serves DHCP"
        "nfs-server:NFS export service, only needed if this host serves NFS"
        "rpcbind:legacy RPC portmapper required only by NFS/NIS"
        "snapd:Snap package daemon, disable if Snap packages are unused"
        "bluetooth:Bluetooth stack, rarely needed on servers"
    )

    local entry svc reason
    for entry in "${candidates[@]}"; do
        svc="${entry%%:*}"
        reason="${entry#*:}"
        if is_service_active "$svc"; then
            add_finding "LOW" "ServiceAudit" "Potentially unnecessary service running: $svc" \
                "$reason" "Disable with 'systemctl disable --now $svc' if not required."
        fi
    done
}
