#!/usr/bin/env bash
# email_notify.sh - Sends an alert summary by email via the local 'mail'
# (mailutils/bsd-mailx) command. Requires a configured MTA (e.g. postfix in
# satellite mode) or a working sendmail on the host.

# send_email_alert <status> <report_path> <summary_text>
send_email_alert() {
    local status="$1" report_path="$2" summary="$3"

    [[ "$ENABLE_EMAIL_ALERT" == "true" ]] || return 0

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
    subject="[Guardian] Disk alert on ${host} - ${status}"
    body="Disk Space Guardian raised a ${status} alert on ${host}.

${summary}

Full report: ${report_path}

This is an automated message from the Linux Log Rotation & Disk Space Guardian."

    if echo "$body" | mail -s "$subject" -r "$ALERT_EMAIL_FROM" "$ALERT_EMAIL_TO" 2>>"$LOG_FILE"; then
        log_success "Email alert sent to $ALERT_EMAIL_TO"
    else
        log_error "Failed to send email alert to $ALERT_EMAIL_TO"
        return 1
    fi
}
