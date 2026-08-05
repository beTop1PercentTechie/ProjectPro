#!/usr/bin/env bash
# 01_user_audit.sh - Audits local user accounts: privileged UIDs, empty
# passwords, password aging, sudo/wheel membership, and inactive accounts.

run_user_audit() {
    section "User Account Audit"
    _check_uid_zero_accounts
    _check_empty_passwords
    _check_sudo_group_members
    _check_password_aging
    _check_inactive_accounts
    _check_duplicate_uids
}

_check_uid_zero_accounts() {
    local extra_root_accounts
    extra_root_accounts=$(awk -F: '$3 == 0 && $1 != "root" { print $1 }' /etc/passwd)

    if [[ -n "$extra_root_accounts" ]]; then
        add_finding "CRITICAL" "UserAudit" "Non-root account(s) with UID 0 found" \
            "Accounts: $(echo "$extra_root_accounts" | tr '\n' ' ')" \
            "Remove UID 0 from these accounts unless intentionally root-equivalent."
    else
        add_finding "INFO" "UserAudit" "Only root has UID 0" "" ""
    fi
}

_check_empty_passwords() {
    [[ -r /etc/shadow ]] || { log_warn "Cannot read /etc/shadow (need root) - skipping empty password check"; return; }

    local empty_pw_accounts
    empty_pw_accounts=$(awk -F: '$2 == "" { print $1 }' /etc/shadow)

    if [[ -n "$empty_pw_accounts" ]]; then
        add_finding "CRITICAL" "UserAudit" "Account(s) with empty password" \
            "Accounts: $(echo "$empty_pw_accounts" | tr '\n' ' ')" \
            "Lock these accounts (passwd -l <user>) or set a strong password immediately."
    else
        add_finding "INFO" "UserAudit" "No accounts with empty passwords" "" ""
    fi
}

_check_sudo_group_members() {
    local sudo_members admin_members all_members

    sudo_members=$(getent group sudo 2>/dev/null | awk -F: '{print $4}')
    admin_members=$(getent group admin 2>/dev/null | awk -F: '{print $4}')
    all_members="${sudo_members}${admin_members:+,${admin_members}}"
    all_members="${all_members#,}"

    if [[ -n "$all_members" ]]; then
        add_finding "INFO" "UserAudit" "Users with sudo privileges" "Members: $all_members" \
            "Review this list periodically and remove access no longer needed."
    else
        add_finding "LOW" "UserAudit" "No members in sudo/admin group" \
            "Privileged access may be granted via /etc/sudoers directly." \
            "Confirm privileged access is intentionally restricted."
    fi
}

_check_password_aging() {
    [[ -r /etc/shadow ]] || return

    local no_expiry_accounts=""
    local user max_days
    while IFS=: read -r user _ _ _ max_days _; do
        [[ "$user" == "root" ]] && continue
        # System/service accounts (UID < 1000) typically have no login shell; skip them.
        local uid
        uid=$(id -u "$user" 2>/dev/null) || continue
        (( uid < 1000 )) && continue

        if [[ -z "$max_days" || "$max_days" == "99999" ]]; then
            no_expiry_accounts+="${user} "
        fi
    done < /etc/shadow

    if [[ -n "$no_expiry_accounts" ]]; then
        add_finding "MEDIUM" "UserAudit" "Account(s) without password expiry policy" \
            "Accounts: ${no_expiry_accounts}" \
            "Set a maximum password age with 'chage -M 90 <user>' per your password policy."
    else
        add_finding "INFO" "UserAudit" "All human accounts have password expiry configured" "" ""
    fi
}

_check_inactive_accounts() {
    command_exists lastlog || return

    local inactive_accounts=""
    local now_epoch cutoff_epoch
    now_epoch=$(date +%s)
    cutoff_epoch=$(( now_epoch - (ACCOUNT_INACTIVE_DAYS * 86400) ))

    while IFS=: read -r user _ uid _; do
        (( uid < 1000 )) && continue
        local last_line last_date last_epoch
        last_line=$(lastlog -u "$user" 2>/dev/null | tail -n1)
        [[ "$last_line" == *"Never logged in"* ]] && continue

        last_date=$(echo "$last_line" | awk '{ for(i=4;i<=NF-3;i++) printf "%s ", $i }')
        [[ -z "$last_date" ]] && continue
        last_epoch=$(date -d "$last_date" +%s 2>/dev/null) || continue

        if (( last_epoch < cutoff_epoch )); then
            inactive_accounts+="${user} "
        fi
    done < /etc/passwd

    if [[ -n "$inactive_accounts" ]]; then
        add_finding "LOW" "UserAudit" "Account(s) inactive for over ${ACCOUNT_INACTIVE_DAYS} days" \
            "Accounts: ${inactive_accounts}" \
            "Disable or remove accounts that no longer require access."
    else
        add_finding "INFO" "UserAudit" "No long-term inactive accounts detected" "" ""
    fi
}

_check_duplicate_uids() {
    local dupes
    dupes=$(awk -F: '{ print $3 }' /etc/passwd | sort | uniq -d)

    if [[ -n "$dupes" ]]; then
        add_finding "HIGH" "UserAudit" "Duplicate UID(s) found in /etc/passwd" \
            "UIDs: $(echo "$dupes" | tr '\n' ' ')" \
            "Ensure every account has a unique UID to avoid privilege confusion."
    else
        add_finding "INFO" "UserAudit" "No duplicate UIDs found" "" ""
    fi
}
