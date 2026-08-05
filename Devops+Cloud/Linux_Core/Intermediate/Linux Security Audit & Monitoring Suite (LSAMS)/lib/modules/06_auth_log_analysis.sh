#!/usr/bin/env bash
# 06_auth_log_analysis.sh - Parses authentication logs (journalctl or
# /var/log/auth.log) for failed logins, brute-force patterns, and sudo usage.

run_auth_log_analysis() {
    section "Authentication Log Analysis"

    local auth_lines
    auth_lines="$(_read_auth_log)"

    if [[ -z "$auth_lines" ]]; then
        add_finding "INFO" "AuthLogAnalysis" "No authentication log data available" \
            "Checked journalctl and /var/log/auth.log" ""
        return
    fi

    _check_failed_logins "$auth_lines"
    _check_brute_force "$auth_lines"
    _check_sudo_activity "$auth_lines"
    _check_invalid_users "$auth_lines"
}

# _read_auth_log - prints recent auth-related log lines from whichever
# source is available, newest ~5000 lines, so this stays fast on busy hosts.
_read_auth_log() {
    if command_exists journalctl; then
        journalctl -u ssh -u sshd --no-pager -n 5000 2>/dev/null && return
    fi
    if [[ -r /var/log/auth.log ]]; then
        tail -n 5000 /var/log/auth.log
        return
    fi
    if [[ -r /var/log/secure ]]; then
        tail -n 5000 /var/log/secure
        return
    fi
}

_check_failed_logins() {
    local logs="$1" count
    count=$(grep -c -E "Failed password|authentication failure" <<< "$logs")

    if (( count > 0 )); then
        add_finding "MEDIUM" "AuthLogAnalysis" "Failed login attempts recorded" \
            "$count failed attempt(s) in the scanned log window" \
            "Review source IPs below; consider fail2ban if not already installed."
    else
        add_finding "INFO" "AuthLogAnalysis" "No failed login attempts in scanned window" "" ""
    fi
}

_check_brute_force() {
    local logs="$1"
    local offenders
    offenders=$(grep -E "Failed password" <<< "$logs" \
        | grep -oE 'from [0-9]{1,3}(\.[0-9]{1,3}){3}' \
        | awk '{print $2}' \
        | sort | uniq -c | sort -rn \
        | awk -v thresh="$FAILED_LOGIN_THRESHOLD" '$1 >= thresh { printf "%s(%s attempts) ", $2, $1 }')

    if [[ -n "$offenders" ]]; then
        add_finding "HIGH" "AuthLogAnalysis" "Possible brute-force source IP(s) detected" \
            "$offenders (threshold: ${FAILED_LOGIN_THRESHOLD} attempts)" \
            "Block offending IPs via firewall/fail2ban and verify no successful login occurred from them."
    else
        add_finding "INFO" "AuthLogAnalysis" "No brute-force pattern detected" \
            "Threshold: ${FAILED_LOGIN_THRESHOLD} failed attempts per source" ""
    fi
}

_check_sudo_activity() {
    local logs="$1" sudo_count
    sudo_count=$(grep -c -E "sudo:.*COMMAND=" <<< "$logs")
    add_finding "INFO" "AuthLogAnalysis" "Sudo command invocations recorded" "$sudo_count invocation(s) in scanned window" ""

    local sudo_failures
    sudo_failures=$(grep -c -E "sudo:.*authentication failure" <<< "$logs")
    if (( sudo_failures > 0 )); then
        add_finding "MEDIUM" "AuthLogAnalysis" "Failed sudo authentication attempts recorded" \
            "$sudo_failures failure(s)" "Investigate which accounts attempted privilege escalation."
    fi
}

_check_invalid_users() {
    local logs="$1" invalid_count invalid_names
    invalid_count=$(grep -c -E "Invalid user" <<< "$logs")

    if (( invalid_count > 0 )); then
        invalid_names=$(grep -oE "Invalid user [^ ]+" <<< "$logs" | awk '{print $3}' | sort -u | head -n 10 | tr '\n' ' ')
        add_finding "MEDIUM" "AuthLogAnalysis" "Login attempts for non-existent users" \
            "$invalid_count attempt(s); sample usernames: $invalid_names" \
            "Typical of automated scanning; ensure PasswordAuthentication is disabled and fail2ban is active."
    fi
}
