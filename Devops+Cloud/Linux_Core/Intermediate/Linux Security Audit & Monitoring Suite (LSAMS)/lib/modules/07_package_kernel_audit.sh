#!/usr/bin/env bash
# 07_package_kernel_audit.sh - Checks for pending package/security updates,
# kernel version currency, unattended-upgrades status, and pending reboots.

run_package_kernel_audit() {
    section "Package & Kernel Audit"
    _check_pending_updates
    _check_unattended_upgrades
    _check_kernel_version
    _check_reboot_required
}

_check_pending_updates() {
    command_exists apt-get || { log_warn "apt-get not found - skipping package update check"; return; }

    local updates security_updates
    updates=$(apt list --upgradable 2>/dev/null | grep -c -v '^Listing')
    security_updates=$(apt list --upgradable 2>/dev/null | grep -c -i '\-security')

    if (( security_updates > 0 )); then
        add_finding "HIGH" "PackageAudit" "Security update(s) available" \
            "$security_updates security update(s), $updates total upgradable package(s)" \
            "Run 'apt-get update && apt-get upgrade' during the next maintenance window."
    elif (( updates > 0 )); then
        add_finding "MEDIUM" "PackageAudit" "Package update(s) available" \
            "$updates upgradable package(s)" \
            "Schedule routine patching to keep packages current."
    else
        add_finding "INFO" "PackageAudit" "System packages are up to date" "" ""
    fi
}

_check_unattended_upgrades() {
    if dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii'; then
        if is_service_enabled unattended-upgrades || [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
            add_finding "INFO" "PackageAudit" "Unattended-upgrades is installed and configured" "" ""
        else
            add_finding "LOW" "PackageAudit" "unattended-upgrades installed but not configured" "" \
                "Run 'dpkg-reconfigure unattended-upgrades' to enable automatic security patching."
        fi
    else
        add_finding "MEDIUM" "PackageAudit" "unattended-upgrades is not installed" "" \
            "Install with 'apt-get install unattended-upgrades' to automate security patching."
    fi
}

_check_kernel_version() {
    local running_kernel latest_installed
    running_kernel=$(uname -r)

    if command_exists dpkg; then
        latest_installed=$(dpkg -l 'linux-image-*' 2>/dev/null | awk '/^ii/ {print $2}' | sort -V | tail -n1)
        if [[ -n "$latest_installed" && "$latest_installed" != *"$running_kernel"* ]]; then
            add_finding "MEDIUM" "PackageAudit" "A newer kernel is installed but not running" \
                "Running: $running_kernel; Latest installed package: $latest_installed" \
                "Reboot the system to load the newer kernel."
            return
        fi
    fi

    add_finding "INFO" "PackageAudit" "Running the latest installed kernel ($running_kernel)" "" ""
}

_check_reboot_required() {
    if [[ -f /var/run/reboot-required ]]; then
        local pkgs
        pkgs=$(cat /var/run/reboot-required.pkgs 2>/dev/null | tr '\n' ' ')
        add_finding "MEDIUM" "PackageAudit" "System reboot required" "Triggered by: ${pkgs:-see /var/run/reboot-required}" \
            "Schedule a reboot during the next maintenance window."
    else
        add_finding "INFO" "PackageAudit" "No pending reboot required" "" ""
    fi
}
