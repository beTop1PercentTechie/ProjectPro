#!/usr/bin/env bash
# slack_notify.sh - Posts an audit summary to a Slack Incoming Webhook.

send_slack_alert() {
    local score="$1" risk="$2" report_path="$3"

    if [[ "$ENABLE_SLACK_ALERT" != "true" ]]; then
        return 0
    fi

    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        log_warn "Slack alert enabled but SLACK_WEBHOOK_URL is not set - skipping"
        return 1
    fi

    if ! command_exists curl; then
        log_warn "Slack alert enabled but curl not found - skipping"
        return 1
    fi

    local host emoji text payload
    host="$(hostname -f 2>/dev/null || hostname)"
    case "$risk" in
        LOW) emoji=":large_green_circle:" ;;
        MEDIUM) emoji=":large_yellow_circle:" ;;
        HIGH) emoji=":large_orange_circle:" ;;
        *) emoji=":red_circle:" ;;
    esac

    text="${emoji} *LSAMS Security Audit* on \`${host}\`\n*Score:* ${score}/100  *Risk:* ${risk}\n*Report:* \`${report_path}\`"
    text=$(printf '%s' "$text" | sed 's/"/\\"/g')
    payload=$(printf '{"text":"%s"}' "$text")

    if curl -fsS -X POST -H 'Content-Type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL" >/dev/null 2>>"$LOG_FILE"; then
        log_success "Slack alert sent"
    else
        log_error "Failed to send Slack alert"
        return 1
    fi
}
