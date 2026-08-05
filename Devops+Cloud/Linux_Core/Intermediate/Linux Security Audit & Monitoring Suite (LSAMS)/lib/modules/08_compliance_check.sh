#!/usr/bin/env bash
# 08_compliance_check.sh - Runs a CIS-benchmark-style pass/fail checklist.
# Each check is individually toggled on/off in config/compliance_rules.conf,
# so operators can adapt the checklist to their own security policy without
# touching code.

readonly COMPLIANCE_RULES_FILE="${LSAMS_HOME}/config/compliance_rules.conf"

run_compliance_check() {
    section "Security Compliance Checklist"

    if [[ -f "$COMPLIANCE_RULES_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$COMPLIANCE_RULES_FILE"
    else
        log_warn "Compliance rules file not found: $COMPLIANCE_RULES_FILE (all checks skipped)"
        return
    fi

    _run_rule "CHECK_PASSWORD_MAX_DAYS"        _rule_password_max_days        "MEDIUM"
    _run_rule "CHECK_PASSWORD_MIN_LENGTH"      _rule_password_min_length      "MEDIUM"
    _run_rule "CHECK_PASSWORD_COMPLEXITY"      _rule_password_complexity      "MEDIUM"
    _run_rule "CHECK_EMPTY_PASSWORDS"          _rule_no_empty_passwords       "CRITICAL"
    _run_rule "CHECK_ROOT_LOGIN_RESTRICTED"    _rule_root_login_restricted   "CRITICAL"
    _run_rule "CHECK_WORLD_WRITABLE_FILES"     _rule_etc_world_writable      "HIGH"
    _run_rule "CHECK_SUID_SGID_FILES"          _rule_suid_baseline            "LOW"
    _run_rule "CHECK_CRITICAL_FILE_PERMISSIONS" _rule_shadow_permissions      "HIGH"
    _run_rule "CHECK_UNOWNED_FILES"            _rule_etc_unowned             "LOW"
    _run_rule "CHECK_FIREWALL_ENABLED"         _rule_firewall_enabled        "HIGH"
    _run_rule "CHECK_UNNECESSARY_SERVICES"     _rule_unnecessary_services    "MEDIUM"
    _run_rule "CHECK_SSH_HARDENING"            _rule_ssh_password_auth_off   "HIGH"
    _run_rule "CHECK_AUDITD_RUNNING"           _rule_auditd_running          "LOW"
    _run_rule "CHECK_LOG_PERMISSIONS"          _rule_log_permissions         "MEDIUM"
    _run_rule "CHECK_AUTOMATIC_UPDATES"        _rule_automatic_updates       "MEDIUM"
    _run_rule "CHECK_UNUSED_ACCOUNTS"          _rule_system_accounts_locked  "LOW"
}

# _run_rule <toggle_var_name> <check_function> <fail_severity>
# The check function must echo a one-line message and return 0 (pass) or 1 (fail).
_run_rule() {
    local toggle_var="$1" check_fn="$2" fail_severity="$3"
    local enabled="${!toggle_var:-false}"

    [[ "$enabled" != "true" ]] && return

    local message
    if message="$($check_fn)"; then
        add_finding "INFO" "Compliance" "PASS: ${toggle_var#CHECK_}" "$message" ""
    else
        add_finding "$fail_severity" "Compliance" "FAIL: ${toggle_var#CHECK_}" "$message" \
            "See docs/MODULES.md for the remediation guidance for this rule."
    fi
}

_rule_password_max_days() {
    local max_days
    max_days=$(awk '/^PASS_MAX_DAYS/ {print $2}' /etc/login.defs 2>/dev/null)
    if [[ -n "$max_days" && "$max_days" -le 90 ]]; then
        echo "PASS_MAX_DAYS=$max_days (<=90)"; return 0
    fi
    echo "PASS_MAX_DAYS=${max_days:-unset}, expected <=90 in /etc/login.defs"; return 1
}

_rule_password_min_length() {
    local minlen
    minlen=$(grep -rE '^\s*minlen' /etc/security/pwquality.conf 2>/dev/null | awk -F= '{print $2}' | tr -d ' ')
    if [[ -n "$minlen" && "$minlen" -ge 8 ]]; then
        echo "minlen=$minlen (>=8)"; return 0
    fi
    echo "minlen=${minlen:-unset} in /etc/security/pwquality.conf, expected >=8"; return 1
}

_rule_password_complexity() {
    if grep -qE 'pam_pwquality\.so' /etc/pam.d/common-password 2>/dev/null; then
        echo "pam_pwquality.so is enabled in common-password"; return 0
    fi
    echo "pam_pwquality.so not found in /etc/pam.d/common-password"; return 1
}

_rule_no_empty_passwords() {
    [[ -r /etc/shadow ]] || { echo "cannot read /etc/shadow"; return 1; }
    local empty
    empty=$(awk -F: '$2 == ""' /etc/shadow | wc -l)
    if (( empty == 0 )); then echo "0 accounts with empty password"; return 0; fi
    echo "$empty account(s) with empty password"; return 1
}

_rule_root_login_restricted() {
    # Uses the effective config (sshd -T), not a raw grep of sshd_config -
    # modern OpenSSH defaults PermitRootLogin to prohibit-password even when
    # the file doesn't set it explicitly, so a raw grep would misreport a
    # secure default as a failure. See lib/core/utils.sh:sshd_effective_value.
    local value
    value=$(sshd_effective_value "PermitRootLogin")
    value="${value,,}"
    if [[ "$value" == "no" || "$value" == "prohibit-password" ]]; then
        echo "PermitRootLogin=$value"; return 0
    fi
    echo "PermitRootLogin=${value:-unknown}, expected no/prohibit-password"; return 1
}

_rule_etc_world_writable() {
    local found
    found=$(find /etc -type f -perm -0002 2>/dev/null)
    if [[ -z "$found" ]]; then echo "no world-writable files under /etc"; return 0; fi
    echo "world-writable file(s) under /etc: $(echo "$found" | tr '\n' ' ')"; return 1
}

_rule_suid_baseline() {
    local count
    count=$(find / -xdev -type f -perm -4000 2>/dev/null | wc -l)
    if (( count <= 40 )); then echo "$count SUID binaries on root filesystem (baseline)"; return 0; fi
    echo "$count SUID binaries found, higher than the expected baseline of 40"; return 1
}

_rule_shadow_permissions() {
    local perms
    perms=$(stat -c '%a' /etc/shadow 2>/dev/null)
    if [[ -n "$perms" ]] && (( 10#$perms <= 640 )); then echo "/etc/shadow mode $perms"; return 0; fi
    echo "/etc/shadow mode ${perms:-unknown}, expected 640 or stricter"; return 1
}

_rule_etc_unowned() {
    local found
    found=$(find /etc \( -nouser -o -nogroup \) 2>/dev/null)
    if [[ -z "$found" ]]; then echo "no unowned files under /etc"; return 0; fi
    echo "unowned file(s) under /etc: $(echo "$found" | tr '\n' ' ')"; return 1
}

_rule_firewall_enabled() {
    if command_exists ufw && ufw status 2>/dev/null | grep -q "Status: active"; then
        echo "ufw is active"; return 0
    fi
    if command_exists firewall-cmd && [[ "$(firewall-cmd --state 2>/dev/null)" == "running" ]]; then
        echo "firewalld is running"; return 0
    fi
    echo "no active firewall detected (ufw/firewalld)"; return 1
}

_rule_unnecessary_services() {
    local svc found=""
    for svc in telnet rsh nis tftp xinetd; do
        is_service_active "$svc" && found+="$svc "
    done
    if [[ -z "$found" ]]; then echo "no legacy insecure services active"; return 0; fi
    echo "insecure service(s) active: $found"; return 1
}

_rule_ssh_password_auth_off() {
    # Effective config (sshd -T) rather than a raw grep - see
    # lib/core/utils.sh:sshd_effective_value and _rule_root_login_restricted
    # above for why: sshd_config may not set this directive explicitly (e.g.
    # via an Include file), and a raw grep would miss it.
    local value
    value=$(sshd_effective_value "PasswordAuthentication")
    value="${value,,}"
    if [[ "$value" == "no" ]]; then echo "PasswordAuthentication=no"; return 0; fi
    echo "PasswordAuthentication=${value:-unknown}, expected no"; return 1
}

_rule_auditd_running() {
    if is_service_active auditd; then echo "auditd is active"; return 0; fi
    echo "auditd is not active"; return 1
}

_rule_log_permissions() {
    [[ -f /var/log/auth.log ]] || { echo "/var/log/auth.log not present (journald-only system)"; return 0; }
    local perms
    perms=$(stat -c '%a' /var/log/auth.log 2>/dev/null)
    if [[ -n "$perms" ]] && (( 10#$perms <= 640 )); then echo "/var/log/auth.log mode $perms"; return 0; fi
    echo "/var/log/auth.log mode ${perms:-unknown}, expected 640 or stricter"; return 1
}

_rule_automatic_updates() {
    if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]] && grep -q '"1"' /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null; then
        echo "automatic updates configured"; return 0
    fi
    echo "automatic updates not configured (/etc/apt/apt.conf.d/20auto-upgrades)"; return 1
}

_rule_system_accounts_locked() {
    local offenders=""
    local user uid shell
    while IFS=: read -r user _ uid _ _ _ shell; do
        [[ "$user" == "root" ]] && continue
        (( uid >= 1 && uid < 1000 )) || continue
        [[ "$shell" == */nologin || "$shell" == */false || -z "$shell" ]] && continue
        offenders+="$user "
    done < /etc/passwd

    if [[ -z "$offenders" ]]; then echo "all system accounts have a locked shell"; return 0; fi
    echo "system account(s) with an interactive shell: $offenders"; return 1
}
