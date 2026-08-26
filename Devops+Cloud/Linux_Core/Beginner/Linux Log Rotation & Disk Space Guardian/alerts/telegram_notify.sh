#!/usr/bin/env bash
# telegram_notify.sh - Sends an alert summary via the Telegram Bot API.

# send_telegram_alert <status> <report_path> <summary_text>
send_telegram_alert() {
    local status="$1" report_path="$2" summary="$3"

    [[ "$ENABLE_TELEGRAM_ALERT" == "true" ]] || return 0

    if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
        log_warn "Telegram alert enabled but TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID is not set - skipping"
        return 1
    fi

    if ! command_exists curl; then
        log_warn "Telegram alert enabled but curl not found - skipping"
        return 1
    fi

    local host api_url
    host="$(hostname -f 2>/dev/null || hostname)"
    api_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

    if curl -fsS "$api_url" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=Disk Space Guardian - ${status} on ${host}
${summary}
Report: ${report_path}" \
        >/dev/null 2>>"$LOG_FILE"; then
        log_success "Telegram alert sent"
    else
        log_error "Failed to send Telegram alert"
        return 1
    fi
}
