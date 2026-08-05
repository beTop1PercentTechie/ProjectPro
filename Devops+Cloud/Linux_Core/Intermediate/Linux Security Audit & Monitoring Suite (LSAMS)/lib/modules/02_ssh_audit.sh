#!/usr/bin/env bash
# 02_ssh_audit.sh - Audits the OpenSSH server configuration for common
# hardening gaps and checks host/private key file permissions.

readonly SSHD_CONFIG="/etc/ssh/sshd_config"

run_ssh_audit() {
    section "SSH Configuration Audit"

    if ! [[ -f "$SSHD_CONFIG" ]]; then
        add_finding "INFO" "SSHAudit" "OpenSSH server not installed" "No $SSHD_CONFIG found" ""
        return
    fi

    _check_ssh_setting "PermitRootLogin" "no" "CRITICAL" \
        "Root can log in directly over SSH." \
        "Set 'PermitRootLogin no' (or 'prohibit-password') in $SSHD_CONFIG."

    _check_ssh_setting "PasswordAuthentication" "no" "HIGH" \
        "Password authentication is allowed, making the server susceptible to brute-force attacks." \
        "Set 'PasswordAuthentication no' and use key-based authentication instead."

    _check_ssh_setting "PermitEmptyPasswords" "no" "CRITICAL" \
        "Empty passwords are permitted for SSH login." \
        "Set 'PermitEmptyPasswords no' in $SSHD_CONFIG."

    _check_ssh_setting "X11Forwarding" "no" "LOW" \
        "X11 forwarding is enabled, increasing attack surface." \
        "Set 'X11Forwarding no' unless required."

    _check_ssh_setting "PermitUserEnvironment" "no" "MEDIUM" \
        "Users can set environment variables that affect the SSH session, a known privilege-escalation vector." \
        "Set 'PermitUserEnvironment no'."

    _check_max_auth_tries
    _check_ssh_protocol
    _check_key_permissions
}

_check_ssh_setting() {
    local key="$1" expected="$2" severity="$3" bad_detail="$4" recommendation="$5"
    local actual
    actual=$(sshd_effective_value "$key")
    actual="${actual,,}"

    if [[ -z "$actual" ]]; then
        add_finding "LOW" "SSHAudit" "Could not determine '$key' setting" \
            "Neither 'sshd -T' nor $SSHD_CONFIG returned a value." "Verify manually."
        return
    fi

    if [[ "$actual" == "$expected" || ( "$expected" == "no" && "$actual" == "prohibit-password" ) ]]; then
        add_finding "INFO" "SSHAudit" "$key is configured securely ($actual)" "" ""
    else
        add_finding "$severity" "SSHAudit" "$key is set to '$actual'" "$bad_detail" "$recommendation"
    fi
}

_check_max_auth_tries() {
    local value
    value=$(sshd_effective_value "MaxAuthTries")
    if [[ -n "$value" && "$value" -gt 4 ]] 2>/dev/null; then
        add_finding "MEDIUM" "SSHAudit" "MaxAuthTries is set high ($value)" \
            "A high retry limit makes online password guessing easier." \
            "Lower MaxAuthTries to 3-4 in $SSHD_CONFIG."
    else
        add_finding "INFO" "SSHAudit" "MaxAuthTries is reasonably restrictive" "" ""
    fi
}

_check_ssh_protocol() {
    local value
    value=$(sshd_effective_value "Protocol")
    if [[ -n "$value" && "$value" != "2" ]]; then
        add_finding "CRITICAL" "SSHAudit" "Legacy SSH protocol version in use ($value)" \
            "SSH protocol 1 has known cryptographic weaknesses." \
            "Force 'Protocol 2' in $SSHD_CONFIG."
    fi
}

_check_key_permissions() {
    local key perms
    for key in /etc/ssh/ssh_host_*_key; do
        [[ -f "$key" ]] || continue
        perms=$(stat -c '%a' "$key" 2>/dev/null)
        if [[ -n "$perms" && "$perms" -gt 600 ]]; then
            add_finding "HIGH" "SSHAudit" "Host private key has loose permissions" \
                "$key is mode $perms (expected 600 or stricter)" \
                "Run: chmod 600 $key"
        fi
    done

    local conf_perms
    conf_perms=$(stat -c '%a' "$SSHD_CONFIG" 2>/dev/null)
    if [[ -n "$conf_perms" && "$conf_perms" -gt 644 ]]; then
        add_finding "MEDIUM" "SSHAudit" "$SSHD_CONFIG has loose permissions ($conf_perms)" \
            "" "Run: chmod 644 $SSHD_CONFIG"
    fi
}
