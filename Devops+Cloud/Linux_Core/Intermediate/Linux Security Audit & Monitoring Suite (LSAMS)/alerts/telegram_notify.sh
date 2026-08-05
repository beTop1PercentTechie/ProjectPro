#!/usr/bin/env bash
# telegram_notify.sh - Sends an audit summary via the Telegram Bot API.

send_telegram_alert() {
    local score="$1" risk="$2" report_path="$3"

    if [[ "$ENABLE_TELEGRAM_ALERT" != "true" ]]; then
        return 0
    fi

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
        --data-urlencode "text=LSAMS Security Audit on ${host}
Score: ${score}/100
Risk: ${risk}
Report: ${report_path}" \
        >/dev/null 2>>"$LOG_FILE"; then
        log_success "Telegram alert sent"
    else
        log_error "Failed to send Telegram alert"
        return 1
    fi
}
