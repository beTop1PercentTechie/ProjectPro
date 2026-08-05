#!/usr/bin/env bash
# email_notify.sh - Sends an audit summary by email via the local 'mail'
# (GNU Mailutils) command, with the actual report file attached rather than
# just referenced by path. Requires a configured MTA (e.g. postfix in
# satellite mode) or a working sendmail on the host.

# send_email_alert <score> <risk> <report_path> [attachment_path]
# report_path is referenced in the email body as "Full report: ...".
# attachment_path, if given and readable, is attached to the message via
# GNU Mailutils' '-A' flag (verified present: 'mail (GNU Mailutils 3.20)').
send_email_alert() {
    local score="$1" risk="$2" report_path="$3" attachment_path="${4:-}"

    if [[ "$ENABLE_EMAIL_ALERT" != "true" ]]; then
        return 0
    fi

    if [[ -z "$ALERT_EMAIL_TO" ]]; then
        log_warn "Email alert enabled but ALERT_EMAIL_TO is not set - skipping"
        return 1
    fi

    if ! command_exists mail; then
        log_warn "Email alert enabled but 'mail' command not found (install mailutils) - skipping"
        return 1
    fi

    local subject body host
    host="$(hostname -f 2>/dev/null || hostname)"
    subject="[LSAMS] Security audit for ${host} - Score ${score}/100 (${risk})"
    body="Security audit completed on ${host}.

Security Score : ${score}/100
Risk Rating    : ${risk}
Full report    : ${report_path}

The full report is attached to this email.

This is an automated message from the Linux Security Audit & Monitoring Suite."

    local mail_args=(-s "$subject" -r "$ALERT_EMAIL_FROM")
    if [[ -n "$attachment_path" && -f "$attachment_path" ]]; then
        mail_args=(-A "$attachment_path" "${mail_args[@]}")
    else
        log_warn "No attachment file found for email alert - sending without one"
    fi

    if echo "$body" | mail "${mail_args[@]}" "$ALERT_EMAIL_TO" 2>>"$LOG_FILE"; then
        log_success "Email alert sent to $ALERT_EMAIL_TO$([[ -n "$attachment_path" && -f "$attachment_path" ]] && echo " with $(basename "$attachment_path") attached")"
    else
        log_error "Failed to send email alert to $ALERT_EMAIL_TO"
        return 1
    fi
}
