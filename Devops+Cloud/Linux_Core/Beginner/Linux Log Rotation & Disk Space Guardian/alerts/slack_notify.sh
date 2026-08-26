#!/usr/bin/env bash
# slack_notify.sh - Posts an alert summary to a Slack Incoming Webhook.

# send_slack_alert <status> <report_path> <summary_text>
send_slack_alert() {
    local status="$1" report_path="$2" summary="$3"

    [[ "$ENABLE_SLACK_ALERT" == "true" ]] || return 0

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
    case "$status" in
        CRITICAL) emoji=":red_circle:" ;;
        WARNING)  emoji=":large_yellow_circle:" ;;
        *)        emoji=":large_green_circle:" ;;
    esac

    text="${emoji} *Disk Space Guardian* on \`${host}\` - *${status}*\n${summary}\n*Report:* \`${report_path}\`"
    # Escape backslashes/quotes for JSON, then turn any real newline in the
    # summary into a literal \n sequence - raw newlines are not valid inside
    # a JSON string.
    text=$(printf '%s' "$text" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk '{ printf "%s\\n", $0 }')
    text="${text%\\n}"
    payload=$(printf '{"text":"%s"}' "$text")

    if curl -fsS -X POST -H 'Content-Type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL" >/dev/null 2>>"$LOG_FILE"; then
        log_success "Slack alert sent"
    else
        log_error "Failed to send Slack alert"
        return 1
    fi
}
