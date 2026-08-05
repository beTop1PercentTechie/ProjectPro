#!/usr/bin/env bash
# 05_network_audit.sh - Audits open ports, active connections, firewall
# status, and known-risky listening services.

run_network_audit() {
    section "Network & Firewall Audit"
    _check_listening_ports
    _check_risky_services
    _check_firewall_status
    _check_active_connections
}

_check_listening_ports() {
    command_exists ss || { log_warn "'ss' not found - skipping listening port scan"; return; }

    local listening
    listening=$(ss -tulnp 2>/dev/null | tail -n +2)

    if [[ -n "$listening" ]]; then
        local count
        count=$(echo "$listening" | wc -l)
        add_finding "INFO" "NetworkAudit" "Listening sockets detected ($count)" \
            "$(echo "$listening" | awk '{print $1,$5}' | tr '\n' ';')" \
            "Confirm every listening service is required and firewalled appropriately."
    fi
}

_check_risky_services() {
    command_exists ss || return

    # port:service-name pairs that are almost never appropriate on a hardened server.
    local risky_ports=("21:FTP" "23:Telnet" "512:rexec" "513:rlogin" "514:rsh" "2049:NFS" "6000:X11")
    local entry port name hit

    for entry in "${risky_ports[@]}"; do
        port="${entry%%:*}"
        name="${entry##*:}"
        hit=$(ss -tulnH 2>/dev/null | awk -v p=":$port" '$5 ~ p {print; exit}')
        if [[ -n "$hit" ]]; then
            add_finding "HIGH" "NetworkAudit" "Legacy/insecure service listening: $name (port $port)" \
                "$hit" "Disable $name unless there is a documented business need; prefer SSH/SFTP/NFSv4 with Kerberos."
        fi
    done
}

_check_firewall_status() {
    if command_exists ufw; then
        local status
        status=$(ufw status 2>/dev/null | head -n1)
        if [[ "$status" == *"inactive"* ]]; then
            add_finding "HIGH" "NetworkAudit" "UFW firewall is inactive" "$status" \
                "Enable UFW ('ufw enable') and define rules for required ports only."
        else
            add_finding "INFO" "NetworkAudit" "UFW firewall is active" "$status" ""
        fi
        return
    fi

    if command_exists firewall-cmd; then
        local state
        state=$(firewall-cmd --state 2>/dev/null)
        if [[ "$state" != "running" ]]; then
            add_finding "HIGH" "NetworkAudit" "firewalld is not running" "" "Start and enable firewalld."
        else
            add_finding "INFO" "NetworkAudit" "firewalld is running" "" ""
        fi
        return
    fi

    if command_exists iptables; then
        local rule_count
        rule_count=$(iptables -S 2>/dev/null | wc -l)
        if (( rule_count <= 3 )); then
            add_finding "MEDIUM" "NetworkAudit" "iptables has little or no custom ruleset" \
                "$rule_count rule lines present (default chains only)" \
                "Define explicit iptables rules, or install ufw/firewalld for easier management."
        else
            add_finding "INFO" "NetworkAudit" "iptables has a custom ruleset ($rule_count lines)" "" ""
        fi
        return
    fi

    add_finding "MEDIUM" "NetworkAudit" "No recognized firewall tool found" \
        "Checked for: ufw, firewalld, iptables" "Install and configure a firewall (ufw recommended for Ubuntu)."
}

_check_active_connections() {
    command_exists ss || return

    local established
    established=$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)
    add_finding "INFO" "NetworkAudit" "Active established TCP connections" "$established connection(s)" ""
}
